import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/setlist_item.dart';
import '../../providers/providers.dart';

class SetlistDetailScreen extends ConsumerStatefulWidget {
  final int setlistId;
  const SetlistDetailScreen({super.key, required this.setlistId});

  @override
  ConsumerState<SetlistDetailScreen> createState() =>
      _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends ConsumerState<SetlistDetailScreen> {
  List<SetlistItem> _items = [];
  String _title = 'Setlist';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final setlist =
        await ref.read(setlistRepositoryProvider).getById(widget.setlistId);
    final items = await ref
        .read(setlistRepositoryProvider)
        .getItemsForSetlist(widget.setlistId);
    if (mounted) {
      setState(() {
        _title = setlist?.title ?? 'Setlist';
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _reload() async {
    final items = await ref
        .read(setlistRepositoryProvider)
        .getItemsForSetlist(widget.setlistId);
    if (mounted) setState(() => _items = items);
  }

  // ── Reorder ─────────────────────────────────────────────────────────────────

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    ref
        .read(setlistRepositoryProvider)
        .reorderItems(widget.setlistId, _items);
  }

  // ── Remove item ─────────────────────────────────────────────────────────────

  Future<void> _removeItem(SetlistItem item) async {
    await ref.read(setlistRepositoryProvider).removeItem(item.id!);
    await _reload();
    // Reorder remaining items to keep positions consistent
    ref.read(setlistRepositoryProvider).reorderItems(widget.setlistId, _items);
  }

  // ── Add songs ───────────────────────────────────────────────────────────────

  Future<void> _showAddSongSheet(BuildContext context) async {
    final allSongs = await ref.read(songRepositoryProvider).getAll();
    final existingIds = _items.map((i) => i.songId).toSet();
    final available = allSongs.where((s) => !existingIds.contains(s.id)).toList();

    if (!context.mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tutti gli spartiti sono già in questa setlist')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text('Aggiungi spartito',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: available.length,
                itemBuilder: (ctx, i) {
                  final song = available[i];
                  return ListTile(
                    title: Text(song.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: song.composerName != null
                        ? Text(song.composerName!)
                        : null,
                    trailing: const Icon(Icons.add),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final count = await ref
                          .read(setlistRepositoryProvider)
                          .getItemCount(widget.setlistId);
                      await ref.read(setlistRepositoryProvider).addItem(
                            SetlistItem(
                              setlistId: widget.setlistId,
                              songId: song.id!,
                              position: count,
                            ),
                          );
                      await _reload();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Modalità performance',
              onPressed: () => context.push(
                  '${AppConstants.routePerformance}/${widget.setlistId}'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.library_music,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      const Text('Nessuno spartito in questa setlist'),
                      const SizedBox(height: 8),
                      const Text('Tocca + per aggiungerne uno',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _items.length,
                  onReorder: _onReorder,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    final song = item.song!;
                    return ListTile(
                      key: ValueKey(item.id ?? i),
                      leading: CircleAvatar(
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 13)),
                      ),
                      title: Text(song.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: song.composerName != null
                          ? Text(song.composerName!)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline,
                                color:
                                    Theme.of(context).colorScheme.error),
                            onPressed: () => _confirmRemove(context, item),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSongSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, SetlistItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rimuovi dalla setlist'),
        content:
            Text('Vuoi rimuovere "${item.song?.title}" da questa setlist?'),
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
    if (confirmed == true) await _removeItem(item);
  }
}
