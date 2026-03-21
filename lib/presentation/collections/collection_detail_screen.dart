import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/collection.dart';
import '../../domain/models/song.dart';
import '../../providers/providers.dart';
import '../common/pdf_thumbnail.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  final int collectionId;
  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  final Set<int> _selectedSongIds = {};

  bool get _inSelectionMode => _selectedSongIds.isNotEmpty;

  void _toggleSelection(int songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  void _exitSelectionMode() => setState(() => _selectedSongIds.clear());

  @override
  Widget build(BuildContext context) {
    final collectionAsync = ref.watch(collectionByIdProvider(widget.collectionId));
    final songsAsync = ref.watch(collectionSongsProvider(widget.collectionId));

    return collectionAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Errore: $e'))),
      data: (collection) {
        if (collection == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Raccolta non trovata')));
        }
        final color = _parseColor(collection.color);
        return Scaffold(
          appBar: _inSelectionMode
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _exitSelectionMode,
                  ),
                  title: Text('${_selectedSongIds.length} selezionat${_selectedSongIds.length == 1 ? 'o' : 'i'}'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: 'Rimuovi dalla raccolta',
                      onPressed: () => _removeSelected(context),
                    ),
                  ],
                )
              : AppBar(
                  title: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(collection.name,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
          body: songsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Errore: $e')),
            data: (songs) {
              if (songs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_note,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      const Text('Nessun brano in questa raccolta'),
                      const SizedBox(height: 8),
                      const Text('Tocca + per aggiungere brani',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: songs.length,
                itemBuilder: (context, i) {
                  final song = songs[i];
                  final isSelected = _selectedSongIds.contains(song.id);
                  return ListTile(
                    leading: _inSelectionMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(song.id!),
                          )
                        : PdfThumbnail(
                            key: ValueKey(song.filePath),
                            filePath: song.filePath,
                            size: 48,
                          ),
                    title: Text(song.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: song.composerName != null
                        ? Text(song.composerName!,
                            maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: _inSelectionMode
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () => _showSongOptions(context, song),
                          ),
                    onTap: _inSelectionMode
                        ? () => _toggleSelection(song.id!)
                        : () => context.push(
                            '${AppConstants.routeViewer}/${song.id}'),
                    onLongPress: () {
                      if (!_inSelectionMode) _toggleSelection(song.id!);
                    },
                  );
                },
              );
            },
          ),
          floatingActionButton: _inSelectionMode
              ? null
              : FloatingActionButton(
                  onPressed: () => _showAddSongsDialog(context, collection),
                  tooltip: 'Aggiungi brani',
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  Future<void> _showSongOptions(BuildContext context, Song song) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Apri spartito'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('${AppConstants.routeViewer}/${song.id}');
            },
          ),
          ListTile(
            leading: Icon(Icons.remove_circle_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text('Rimuovi dalla raccolta',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(ctx);
              _removeSong(context, song);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _removeSong(BuildContext context, Song song) async {
    await ref
        .read(collectionRepositoryProvider)
        .removeSong(widget.collectionId, song.id!);
    ref.invalidate(collectionSongsProvider(widget.collectionId));
    ref.invalidate(collectionByIdProvider(widget.collectionId));
    ref.invalidate(collectionsProvider);
  }

  Future<void> _removeSelected(BuildContext context) async {
    final count = _selectedSongIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Rimuovi $count bran${count == 1 ? 'o' : 'i'}'),
        content: Text(
            '$count bran${count == 1 ? 'o' : 'i'} ${count == 1 ? 'verrà rimosso' : 'verranno rimossi'} dalla raccolta. I file non verranno eliminati.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(collectionRepositoryProvider);
    for (final songId in List.from(_selectedSongIds)) {
      await repo.removeSong(widget.collectionId, songId);
    }
    _exitSelectionMode();
    ref.invalidate(collectionSongsProvider(widget.collectionId));
    ref.invalidate(collectionByIdProvider(widget.collectionId));
    ref.invalidate(collectionsProvider);
  }

  Future<void> _showAddSongsDialog(
      BuildContext context, Collection collection) async {
    await showDialog(
      context: context,
      builder: (ctx) => _AddSongsDialog(
        collectionId: widget.collectionId,
        collectionName: collection.name,
        onAdded: () {
          ref.invalidate(collectionSongsProvider(widget.collectionId));
          ref.invalidate(collectionByIdProvider(widget.collectionId));
          ref.invalidate(collectionsProvider);
        },
      ),
    );
  }
}

// ── Add songs dialog ──────────────────────────────────────────────────────────

class _AddSongsDialog extends ConsumerStatefulWidget {
  final int collectionId;
  final String collectionName;
  final VoidCallback onAdded;

  const _AddSongsDialog({
    required this.collectionId,
    required this.collectionName,
    required this.onAdded,
  });

  @override
  ConsumerState<_AddSongsDialog> createState() => _AddSongsDialogState();
}

class _AddSongsDialogState extends ConsumerState<_AddSongsDialog> {
  List<Song> _availableSongs = [];
  final Set<int> _selectedIds = {};
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _searchVisible = false;

  List<Song> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _availableSongs;
    return _availableSongs.where((s) =>
        s.title.toLowerCase().contains(q) ||
        (s.composerName?.toLowerCase().contains(q) ?? false)).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final allSongs = await ref.read(songRepositoryProvider).getAll();
    final inCollection =
        await ref.read(collectionRepositoryProvider).getSongs(widget.collectionId);
    final inIds = inCollection.map((s) => s.id!).toSet();
    if (mounted) {
      setState(() {
        _availableSongs = allSongs.where((s) => !inIds.contains(s.id)).toList();
        _loading = false;
      });
    }
  }

  Future<void> _confirm() async {
    if (_selectedIds.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final repo = ref.read(collectionRepositoryProvider);
    for (final songId in _selectedIds) {
      await repo.addSong(widget.collectionId, songId);
    }
    widget.onAdded();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('Aggiungi a "${widget.collectionName}"')),
          IconButton(
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            tooltip: 'Cerca',
            onPressed: () => setState(() {
              _searchVisible = !_searchVisible;
              if (!_searchVisible) _searchCtrl.clear();
            }),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()))
            : _availableSongs.isEmpty
                ? const Text('Tutti i brani sono già in questa raccolta.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchVisible) ...[
                      TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Cerca brano...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => _searchCtrl.clear(),
                                )
                              : null,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ],
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('Nessun risultato',
                              style: TextStyle(color: Colors.grey)),
                        )
                      else
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final song = _filtered[i];
                              return CheckboxListTile(
                                title: Text(song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: song.composerName != null
                                    ? Text(song.composerName!)
                                    : null,
                                value: _selectedIds.contains(song.id),
                                onChanged: (checked) => setState(() {
                                  if (checked == true) {
                                    _selectedIds.add(song.id!);
                                  } else {
                                    _selectedIds.remove(song.id);
                                  }
                                }),
                                dense: true,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla')),
        FilledButton(
          onPressed: _selectedIds.isEmpty ? null : _confirm,
          child: Text(_selectedIds.isEmpty
              ? 'Aggiungi'
              : 'Aggiungi (${_selectedIds.length})'),
        ),
      ],
    );
  }
}

