import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
