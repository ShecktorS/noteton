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

  // ── Item options ─────────────────────────────────────────────────────────────

  Future<void> _showItemOptions(
      BuildContext context, SetlistItem item, int index) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.first_page_outlined),
            title: const Text('Imposta pagina iniziale'),
            subtitle: item.customStartPage > 0
                ? Text('Attuale: pagina ${item.customStartPage}')
                : const Text('Inizia dalla prima pagina'),
            onTap: () {
              Navigator.pop(ctx);
              _showSetStartPageDialog(context, item);
            },
          ),
          ListTile(
            leading: Icon(Icons.remove_circle_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text('Rimuovi dalla setlist',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              Navigator.pop(ctx);
              await ref
                  .read(setlistRepositoryProvider)
                  .removeItem(item.id!);
              await _reload();
              ref
                  .read(setlistRepositoryProvider)
                  .reorderItems(widget.setlistId, _items);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _showSetStartPageDialog(
      BuildContext context, SetlistItem item) async {
    final song = item.song!;
    final maxPage = song.totalPages > 0 ? song.totalPages : 999;
    final ctrl = TextEditingController(
      text: item.customStartPage > 0 ? '${item.customStartPage}' : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagina iniziale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(song.title,
                style: Theme.of(ctx).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Pagina (1–$maxPage)',
                hintText: '1',
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Usa ultima pagina letta'),
            ),
          ],
        ),
        actions: [
          if (item.customStartPage > 0)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx, false);
                final updated = item.copyWith(customStartPage: 0);
                await ref
                    .read(setlistRepositoryProvider)
                    .updateItem(updated);
                await _reload();
              },
              child: const Text('Reimposta'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salva')),
        ],
      ),
    );

    if (confirmed != true) return;

    int page = int.tryParse(ctrl.text.trim()) ?? 0;
    // Se campo vuoto usa lastPage
    if (ctrl.text.trim().isEmpty && song.lastPage > 0) {
      page = song.lastPage;
    }
    page = page.clamp(0, maxPage);

    final updated = item.copyWith(customStartPage: page);
    await ref.read(setlistRepositoryProvider).updateItem(updated);
    await _reload();
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

    final selected = <int>{};
    final searchCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final q = searchCtrl.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? available
              : available.where((s) =>
                  s.title.toLowerCase().contains(q) ||
                  (s.composerName?.toLowerCase().contains(q) ?? false)).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        selected.isEmpty
                            ? 'Aggiungi spartiti'
                            : '${selected.length} selezionat${selected.length == 1 ? 'o' : 'i'}',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: false,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cerca brano...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                setSheetState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('Nessun risultato',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final song = filtered[i];
                            final isSelected = selected.contains(song.id);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (_) => setSheetState(() {
                                if (isSelected) {
                                  selected.remove(song.id);
                                } else {
                                  selected.add(song.id!);
                                }
                              }),
                              title: Text(song.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: song.composerName != null
                                  ? Text(song.composerName!)
                                  : null,
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                  child: FilledButton.icon(
                    onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx),
                    icon: const Icon(Icons.add),
                    label: Text(selected.isEmpty
                        ? 'Seleziona brani'
                        : 'Aggiungi ${selected.length} bran${selected.length == 1 ? 'o' : 'i'}'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    searchCtrl.dispose();

    if (selected.isEmpty) return;
    final repo = ref.read(setlistRepositoryProvider);
    int count = await repo.getItemCount(widget.setlistId);
    for (final songId in selected) {
      await repo.addItem(SetlistItem(
        setlistId: widget.setlistId,
        songId: songId,
        position: count++,
      ));
    }
    await _reload();
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
                      subtitle: Row(
                        children: [
                          if (song.composerName != null)
                            Expanded(
                              child: Text(song.composerName!,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          if (item.customStartPage > 0)
                            Container(
                              margin: EdgeInsets.only(
                                  left: song.composerName != null ? 6 : 0),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Da pag. ${item.customStartPage}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: _inSelectionMode
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onPressed: () =>
                                      _showItemOptions(context, item, i),
                                ),
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Icon(Icons.drag_handle),
                                ),
                              ],
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
