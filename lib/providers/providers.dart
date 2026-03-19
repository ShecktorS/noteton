import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/song_repository.dart';
import '../data/repositories/setlist_repository.dart';
import '../data/repositories/composer_repository.dart';
import '../domain/models/song.dart';
import '../domain/models/setlist.dart';
import '../domain/models/setlist_item.dart';
import '../domain/models/composer.dart';

// Repositories (singletons)
final songRepositoryProvider = Provider<SongRepository>((_) => SongRepository());
final setlistRepositoryProvider = Provider<SetlistRepository>((_) => SetlistRepository());
final composerRepositoryProvider = Provider<ComposerRepository>((_) => ComposerRepository());

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

// Search query state
final searchQueryProvider = StateProvider<String>((ref) => '');
