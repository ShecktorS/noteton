/// Aggregazioni della libreria per la card "La tua libreria" in Settings.
class LibraryStats {
  final int totalSongs;
  final int totalComposers;
  final int totalSetlists;
  final int totalCollections;
  final int totalTags;

  /// Top 5 tonalità per frequenza, in formato (chiave_storage, count).
  final List<({String key, int count})> topKeys;

  /// Distribuzione per periodo musicale (periodo, count). Solo brani con
  /// periodo assegnato.
  final List<({String period, int count})> periodDistribution;

  const LibraryStats({
    required this.totalSongs,
    required this.totalComposers,
    required this.totalSetlists,
    required this.totalCollections,
    required this.totalTags,
    required this.topKeys,
    required this.periodDistribution,
  });

  static const empty = LibraryStats(
    totalSongs: 0,
    totalComposers: 0,
    totalSetlists: 0,
    totalCollections: 0,
    totalTags: 0,
    topKeys: [],
    periodDistribution: [],
  );
}
