import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/song_repository.dart';
import '../data/repositories/setlist_repository.dart';
import '../data/repositories/composer_repository.dart';
import '../data/repositories/collection_repository.dart';
import '../domain/models/song.dart';
import '../domain/models/setlist.dart';
import '../domain/models/setlist_item.dart';
import '../domain/models/composer.dart';
import '../domain/models/collection.dart';

// Repositories (singletons)
final songRepositoryProvider = Provider<SongRepository>((_) => SongRepository());
final setlistRepositoryProvider = Provider<SetlistRepository>((_) => SetlistRepository());
final composerRepositoryProvider = Provider<ComposerRepository>((_) => ComposerRepository());
final collectionRepositoryProvider = Provider<CollectionRepository>((_) => CollectionRepository());

// Songs
final songsProvider = FutureProvider.family<List<Song>, String?>((ref, query) async {
  return ref.read(songRepositoryProvider).getAll(searchQuery: query);
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
