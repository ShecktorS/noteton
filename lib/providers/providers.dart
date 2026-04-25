import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/update_service.dart';
import '../data/repositories/song_repository.dart';
import '../data/repositories/setlist_repository.dart';
import '../data/repositories/composer_repository.dart';
import '../data/repositories/collection_repository.dart';
import '../data/repositories/backup_repository.dart';
import '../data/repositories/annotation_repository.dart';
import '../data/repositories/tag_repository.dart';
import '../domain/models/song.dart';
import '../domain/models/setlist.dart';
import '../domain/models/setlist_item.dart';
import '../domain/models/composer.dart';
import '../domain/models/collection.dart';
import '../domain/models/release_info.dart';
import '../domain/models/tag.dart';

// Repositories (singletons)
final songRepositoryProvider = Provider<SongRepository>((_) => SongRepository());
final setlistRepositoryProvider = Provider<SetlistRepository>((_) => SetlistRepository());
final composerRepositoryProvider = Provider<ComposerRepository>((_) => ComposerRepository());
final collectionRepositoryProvider = Provider<CollectionRepository>((_) => CollectionRepository());
final backupRepositoryProvider = Provider<BackupRepository>((_) => BackupRepository());
final annotationRepositoryProvider = Provider<AnnotationRepository>((_) => AnnotationRepository());
final tagRepositoryProvider = Provider<TagRepository>((_) => TagRepository());

// Songs filter — combines text search + optional tag filter
typedef SongsFilter = ({String? query, int? tagId});

final songsProvider = FutureProvider.family<List<Song>, SongsFilter>(
    (ref, filter) async {
  return ref.read(songRepositoryProvider).getAll(
        searchQuery: filter.query,
        tagId: filter.tagId,
      );
});

// Tags
final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  return ref.read(tagRepositoryProvider).getAll();
});

final songTagsProvider = FutureProvider.family<List<Tag>, int>(
    (ref, songId) async {
  return ref.read(tagRepositoryProvider).getTagsForSong(songId);
});

// Setlists
final setlistsProvider = FutureProvider<List<Setlist>>((ref) async {
  return ref.read(setlistRepositoryProvider).getAll();
});

// Setlist items
final setlistItemsProvider = FutureProvider.family<List<SetlistItem>, int>((ref, setlistId) async {
  return ref.read(setlistRepositoryProvider).getItemsForSetlist(setlistId);
});

// Composers
final composersProvider = FutureProvider<List<Composer>>((ref) async {
  return ref.read(composerRepositoryProvider).getAll();
});

/// Suggerimenti compositori per autocomplete autore (≥ 2 caratteri).
/// autoDispose: la cache si scarta appena il widget esce dallo scope.
final composerSuggestionsProvider =
    FutureProvider.autoDispose.family<List<Composer>, String>(
        (ref, prefix) async {
  if (prefix.length < 2) return const [];
  return ref.read(composerRepositoryProvider).findByPrefix(prefix);
});

/// Suggerimenti album per autocomplete (≥ 2 caratteri).
final albumSuggestionsProvider =
    FutureProvider.autoDispose.family<List<String>, String>(
        (ref, prefix) async {
  if (prefix.length < 2) return const [];
  return ref.read(songRepositoryProvider).findAlbumsByPrefix(prefix);
});

// Collections
final collectionsProvider = FutureProvider<List<Collection>>((ref) async {
  return ref.read(collectionRepositoryProvider).getAll();
});

final collectionSongsProvider = FutureProvider.family<List<Song>, int>((ref, collectionId) async {
  return ref.read(collectionRepositoryProvider).getSongs(collectionId);
});

final collectionByIdProvider = FutureProvider.family<Collection?, int>((ref, collectionId) async {
  return ref.read(collectionRepositoryProvider).getById(collectionId);
});

// Search query state
final searchQueryProvider = StateProvider<String>((ref) => '');

// Tag filter state (null = no filter)
final tagFilterProvider = StateProvider<int?>((ref) => null);

// Sort order
enum SortOrder { titleAZ, titleZA, newestFirst, lastOpened }

final sortOrderProvider = StateProvider<SortOrder>((ref) => SortOrder.titleAZ);

// ── Theme mode ───────────────────────────────────────────────────────────────
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => ThemeMode.dark,
      );
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (_) => ThemeModeNotifier(),
);

// ── Update state ──────────────────────────────────────────────────────────────

sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate();
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.release);
  final ReleaseInfo release;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.progress);
  final double progress; // 0.0–1.0
}

class UpdateReadyToInstall extends UpdateState {
  const UpdateReadyToInstall(this.apkPath);
  final String apkPath;
}

class UpdateError extends UpdateState {
  const UpdateError(this.message, {this.detail});
  final String message;
  final String? detail;
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier(this._service) : super(const UpdateIdle());
  final UpdateService _service;

  static const _prefDismissed = 'dismissed_update_version';
  static const _prefLastCheck = 'update_last_check_ms';
  static const _prefAutoUpdateEnabled = 'auto_update_enabled';
  static const _checkIntervalMs = 6 * 60 * 60 * 1000; // 6 ore

  /// Restituisce true se l'utente ha abilitato gli aggiornamenti automatici
  /// (default: true). Usato sia da `_UpdateGate` al boot sia dalla schermata
  /// "Aggiornamento automatico".
  static Future<bool> isAutoUpdateEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefAutoUpdateEnabled) ?? true;
  }

  static Future<void> setAutoUpdateEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoUpdateEnabled, enabled);
  }

  /// Controlla aggiornamenti.
  /// [force] bypassa il throttle di 6h (usato dal tasto manuale).
  /// Se [force] è false e l'utente ha disabilitato gli aggiornamenti
  /// automatici, il check non parte.
  Future<void> check({bool force = false}) async {
    if (state is UpdateChecking || state is UpdateDownloading) return;

    if (!force) {
      final enabled = await isAutoUpdateEnabled();
      if (!enabled) return;
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_prefLastCheck) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - last < _checkIntervalMs) {
        return;
      }
    }

    state = const UpdateChecking();
    try {
      final prefs = await SharedPreferences.getInstance();
      final release = await _service.checkForUpdate();
      await prefs.setInt(
          _prefLastCheck, DateTime.now().millisecondsSinceEpoch);

      if (release == null) {
        if (mounted) state = const UpdateUpToDate();
        return;
      }
      final dismissed = prefs.getString(_prefDismissed);
      if (dismissed == release.version) {
        if (mounted) state = const UpdateIdle();
        return;
      }
      if (mounted) state = UpdateAvailable(release);
    } catch (e) {
      if (mounted) {
        state = UpdateError(
          'Impossibile verificare aggiornamenti.',
          detail: e.toString(),
        );
      }
    }
  }

  /// Scarica e installa l'aggiornamento.
  Future<void> downloadAndInstall(ReleaseInfo release) async {
    state = const UpdateDownloading(0);
    try {
      final path = await _service.downloadApk(
        release.downloadUrl,
        (p) {
          if (mounted) state = UpdateDownloading(p);
        },
      );
      if (mounted) state = UpdateReadyToInstall(path);
      await _service.installApk(path);
    } catch (_) {
      if (mounted) state = const UpdateError('Download fallito. Riprova.');
    }
  }

  /// Ignora questa versione — non verrà più mostrata fino alla successiva.
  Future<void> dismiss(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDismissed, version);
    if (mounted) state = const UpdateIdle();
  }
}

final updateServiceProvider =
    Provider<UpdateService>((_) => const UpdateService());

final updateProvider =
    StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier(ref.read(updateServiceProvider));
});

/// Stato del toggle "Abilita aggiornamento" (persiste in SharedPreferences).
/// Default: true.
class AutoUpdateEnabledNotifier extends StateNotifier<bool> {
  AutoUpdateEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    state = await UpdateNotifier.isAutoUpdateEnabled();
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    await UpdateNotifier.setAutoUpdateEnabled(value);
  }
}

final autoUpdateEnabledProvider =
    StateNotifierProvider<AutoUpdateEnabledNotifier, bool>(
        (_) => AutoUpdateEnabledNotifier());
