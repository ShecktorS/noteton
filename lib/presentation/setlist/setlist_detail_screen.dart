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
  final Set<int> _selectedIds = {};

  bool get _inSelectionMode => _selectedIds.isNotEmpty;

  void _toggleSelection(int itemId) {
    setState(() {
      if (_selectedIds.contains(itemId)) {
        _selectedIds.remove(itemId);
      } else {
        _selectedIds.add(itemId);
      }
    });
  }

  void _exitSelectionMode() => setState(() => _selectedIds.clear());

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
    ref.read(setlistRepositoryProvider).reorderItems(widget.setlistId, _items);
  }

  // ── Remove single ────────────────────────────────────────────────────────────

  Future<void> _removeItem(SetlistItem item) async {
    await ref.read(setlistRepositoryProvider).removeItem(item.id!);
    await _reload();
    ref.read(setlistRepositoryProvider).reorderItems(widget.setlistId, _items);
  }

  // ── Remove selected ──────────────────────────────────────────────────────────

  Future<void> _removeSelected(BuildContext context) async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rimuovi $count bran${count == 1 ? 'o' : 'i'}'),
        content: Text(
            'Vuoi rimuovere $count bran${count == 1 ? 'o' : 'i'} dalla setlist?\nGli spartiti rimarranno nella libreria.'),
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

    final repo = ref.read(setlistRepositoryProvider);
    for (final id in List.from(_selectedIds)) {
      await repo.removeItem(id);
    }
    _exitSelectionMode();
    await _reload();
    repo.reorderItems(widget.setlistId, _items);
  }

  // ── Add songs ────────────────────────────────────────────────────────────────

  Future<void> _showAddSongSheet(BuildContext context) async {
    final allSongs = await ref.read(songRepositoryProvider).getAll();
    final existingIds = _items.map((i) => i.songId).toSet();
    final available =
        allSongs.where((s) => !existingIds.contains(s.id)).toList();

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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _inSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
              title: Text(
                  '${_selectedIds.length} selezionat${_selectedIds.length == 1 ? 'o' : 'i'}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Rimuovi selezionati',
                  onPressed: () => _removeSelected(context),
                ),
              ],
            )
          : AppBar(
              title: Text(_title),
              actions: [
                if (_items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.icon(
                      onPressed: () => context.push(
                          '${AppConstants.routePerformance}/${widget.setlistId}'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Esegui'),
                    ),
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
                  onReorder: _inSelectionMode ? (_, __) {} : _onReorder,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    final song = item.song!;
                    final isSelected = _selectedIds.contains(item.id);

                    return ListTile(
                      key: ValueKey(item.id ?? i),
                      leading: _inSelectionMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(item.id!),
                            )
                          : CircleAvatar(
                              child: Text('${i + 1}',
                                  style: const TextStyle(fontSize: 13)),
                            ),
                      title: Text(song.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: song.composerName != null
                          ? Text(song.composerName!)
                          : null,
                      trailing: _inSelectionMode
                          ? null
                          : ReorderableDragStartListener(
                              index: i,
                              child: const Icon(Icons.drag_handle),
                            ),
                      onTap: _inSelectionMode
                          ? () => _toggleSelection(item.id!)
                          : () => context.push(
                                '${AppConstants.routePerformance}/${widget.setlistId}?songIndex=$i',
                              ),
                      onLongPress: _inSelectionMode
                          ? null
                          : () => _toggleSelection(item.id!),
                    );
                  },
                ),
      floatingActionButton: _inSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddSongSheet(context),
              child: const Icon(Icons.add),
            ),
    );
  }
}
