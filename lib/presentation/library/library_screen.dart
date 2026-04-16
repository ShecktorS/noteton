import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/key_signature_localization.dart';
import '../../domain/models/collection.dart';
import '../../domain/models/setlist.dart';
import '../../domain/models/setlist_item.dart';
import '../../domain/models/song.dart';
import '../../domain/models/tag.dart';
import '../../providers/providers.dart';
import '../common/app_bottom_nav.dart';
import '../common/pdf_thumbnail.dart';

enum _ViewMode { grid, list }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _ViewMode _viewMode = _ViewMode.grid;
  final Set<int> _selectedIds = {};
  SongStatus? _statusFilter; // null = mostra tutti
  final ScrollController _scrollController = ScrollController();

  static const _prefKey = 'library_view_mode';

  bool get _inSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'list' && mounted) {
      setState(() => _viewMode = _ViewMode.list);
    }
  }

  Future<void> _saveViewMode(_ViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode == _ViewMode.list ? 'list' : 'grid');
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() => setState(() => _selectedIds.clear());

  List<Song> _applySortOrder(List<Song> songs, SortOrder order) {
    final list = List<Song>.from(songs);
    switch (order) {
      case SortOrder.titleAZ:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SortOrder.titleZA:
        list.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      case SortOrder.newestFirst:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortOrder.lastOpened:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return list;
  }

  void _showSortMenu(BuildContext context) {
    final current = ref.read(sortOrderProvider);
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Ordina per',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
            for (final option in SortOrder.values)
              ListTile(
                leading: Icon(_sortIcon(option)),
                title: Text(_sortLabel(option)),
                trailing: current == option
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () {
                  ref.read(sortOrderProvider.notifier).state = option;
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _sortIcon(SortOrder o) => switch (o) {
        SortOrder.titleAZ => Icons.sort_by_alpha,
        SortOrder.titleZA => Icons.sort_by_alpha,
        SortOrder.newestFirst => Icons.calendar_today,
        SortOrder.lastOpened => Icons.history,
      };

  String _sortLabel(SortOrder o) => switch (o) {
        SortOrder.titleAZ => 'Titolo A → Z',
        SortOrder.titleZA => 'Titolo Z → A',
        SortOrder.newestFirst => 'Più recenti',
        SortOrder.lastOpened => 'Ultima apertura',
      };

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final sortOrder = ref.watch(sortOrderProvider);
    final tagFilter = ref.watch(tagFilterProvider);
    final songsAsync = ref.watch(songsProvider((
      query: query.isEmpty ? null : query,
      tagId: tagFilter,
    )));

    return PopScope(
      canPop: !_inSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelectionMode();
      },
      child: Scaffold(
      appBar: _inSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
              title: Text('${_selectedIds.length} selezionat${_selectedIds.length == 1 ? 'o' : 'i'}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.local_offer_outlined),
                  tooltip: 'Assegna tag',
                  onPressed: () => _showBulkTagPicker(context),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Elimina selezionati',
                  onPressed: () => _deleteSelected(context),
                ),
              ],
            )
          : AppBar(
              title: const Text(AppConstants.appName),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _showSearch(context),
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Ordina',
                  onPressed: () => _showSortMenu(context),
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      tooltip: 'Filtra',
                      onPressed: () => _showFilterMenu(context),
                    ),
                    if (_statusFilter != null || ref.watch(tagFilterProvider) != null)
                      Positioned(
                        right: 6, top: 6,
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: _statusFilter?.color ??
                                Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (songs) {
          // Applica filtro status se attivo
          final statusFiltered = _statusFilter == null
              ? songs
              : songs.where((s) => s.status == _statusFilter).toList();
          // Applica ordinamento
          final filtered = _applySortOrder(statusFiltered, sortOrder);

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_note,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(_statusFilter != null
                      ? 'Nessuno spartito con stato "${_statusFilter!.label}"'
                      : 'Nessuno spartito nella libreria'),
                  const SizedBox(height: 8),
                  if (_statusFilter == null)
                    const Text('Tocca + per importare un PDF',
                        style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          final content = _viewMode == _ViewMode.grid
              ? _buildGrid(filtered)
              : _buildList(filtered);
          return Row(
            children: [
              Expanded(child: content),
              _AlphaScrollBar(
                songs: filtered,
                onLetterSelected: (letter) =>
                    _scrollToLetter(letter, filtered, context),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _inSelectionMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'view_toggle',
                  onPressed: () {
                    final next = _viewMode == _ViewMode.grid
                        ? _ViewMode.list
                        : _ViewMode.grid;
                    setState(() => _viewMode = next);
                    _saveViewMode(next);
                  },
                  tooltip: _viewMode == _ViewMode.grid ? 'Vista lista' : 'Vista griglia',
                  child: Icon(_viewMode == _ViewMode.grid
                      ? Icons.list
                      : Icons.grid_view),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'import',
                  onPressed: () => _startImport(context),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    ), // Scaffold
    ); // PopScope
  }

  // ── Alpha scroll ────────────────────────────────────────────────────────────

  void _scrollToLetter(String letter, List<Song> songs, BuildContext context) {
    int targetIndex = -1;
    for (int i = 0; i < songs.length; i++) {
      final title = songs[i].title.trim();
      final first =
          title.isNotEmpty ? title[0].toUpperCase() : '#';
      if (letter == '#') {
        if (!RegExp(r'[A-Z]').hasMatch(first)) {
          targetIndex = i;
          break;
        }
      } else if (first == letter) {
        targetIndex = i;
        break;
      }
    }
    if (targetIndex < 0 || !_scrollController.hasClients) return;

    double offset;
    if (_viewMode == _ViewMode.grid) {
      // 20px per la nav A-Z già sottratta dall'Expanded
      final screenWidth = MediaQuery.of(context).size.width - 20;
      final itemWidth = (screenWidth - 32 - 12) / 2;
      final itemHeight = itemWidth / 0.7;
      final rowIndex = targetIndex ~/ 2;
      offset = 16 + rowIndex * (itemHeight + 12);
    } else {
      // ListTile con subtitle ≈ 80px
      offset = targetIndex * 80.0;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      offset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  // ── Grid view ───────────────────────────────────────────────────────────────

  Widget _buildGrid(List<Song> songs) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: songs.length,
      itemBuilder: (_, i) {
        final song = songs[i];
        final isSelected = _selectedIds.contains(song.id);
        return _SongGridCard(
          key: ValueKey(song.id),
          song: song,
          isSelected: isSelected,
          inSelectionMode: _inSelectionMode,
          onTap: _inSelectionMode
              ? () => _toggleSelection(song.id!)
              : () => context.push('${AppConstants.routeViewer}/${song.id}'),
          onLongPress: () {
            if (!_inSelectionMode) _toggleSelection(song.id!);
          },
          onOptions: () => _showOptions(context, song),
        );
      },
    );
  }

  // ── List view ───────────────────────────────────────────────────────────────

  Widget _buildList(List<Song> songs) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: songs.length,
      itemBuilder: (_, i) {
        final song = songs[i];
        final isSelected = _selectedIds.contains(song.id);
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (song.composerName != null)
                GestureDetector(
                  onTap: () => context.push('/composers/${song.composerId}'),
                  child: Text(
                    song.composerName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  if (song.totalPages > 0)
                    Text(
                      song.lastPage > 0
                          ? 'Pag. ${song.lastPage}/${song.totalPages}'
                          : '${song.totalPages} pag.',
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  if (song.status != SongStatus.none)
                    _MetaBadge(label: song.status.label, color: song.status.color),
                  if (song.keySignature != null)
                    _MetaBadge(
                      label: KeySignatureLocalization.display(
                          song.keySignature!,
                          Localizations.localeOf(context)),
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  if (song.bpm != null)
                    _MetaBadge(
                      label: '${song.bpm} BPM',
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  if (song.instrument != null)
                    _MetaBadge(
                      label: song.instrument!,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          ),
          trailing: _inSelectionMode
              ? null
              : IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showOptions(context, song),
                ),
          onTap: _inSelectionMode
              ? () => _toggleSelection(song.id!)
              : () => context.push('${AppConstants.routeViewer}/${song.id}'),
          onLongPress: () {
            if (!_inSelectionMode) _toggleSelection(song.id!);
          },
        );
      },
    );
  }

  // ── Bulk delete ─────────────────────────────────────────────────────────────

  Future<void> _deleteSelected(BuildContext context) async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Elimina $count spartit${count == 1 ? 'o' : 'i'}'),
        content: Text(
            'Verranno eliminati $count spartit${count == 1 ? 'o' : 'i'} e i relativi file PDF.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final repo = ref.read(songRepositoryProvider);
    for (final id in List.from(_selectedIds)) {
      await repo.delete(id);
    }
    _exitSelectionMode();
    ref.invalidate(songsProvider);
  }

  // ── Options bottom sheet ────────────────────────────────────────────────────

  Future<void> _showOptions(BuildContext context, Song song) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Modifica dettagli'),
            onTap: () async {
              Navigator.pop(ctx);
              await _showEditDialog(context, song);
            },
          ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Stato'),
            subtitle: song.status != SongStatus.none
                ? Text(song.status.label,
                    style: TextStyle(color: song.status.color, fontSize: 12))
                : null,
            onTap: () async {
              Navigator.pop(ctx);
              await _showStatusPicker(context, song);
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_offer_outlined),
            title: const Text('Tag'),
            onTap: () async {
              Navigator.pop(ctx);
              await _showTagPicker(context, song);
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_special_outlined),
            title: const Text('Aggiungi a raccolta'),
            onTap: () async {
              Navigator.pop(ctx);
              await _showAddToCollectionDialog(context, song);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text('Elimina',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              Navigator.pop(ctx);
              await _confirmDelete(context, song);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Add to collection dialog ─────────────────────────────────────────────────

  Future<void> _showAddToCollectionDialog(BuildContext context, Song song) async {
    final collections = await ref.read(collectionRepositoryProvider).getAll();
    if (!context.mounted) return;
    if (collections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessuna raccolta disponibile. Creane una nella sezione Raccolte.'),
        ),
      );
      return;
    }
    final currentIds = await ref.read(collectionRepositoryProvider).getCollectionIdsForSong(song.id!);
    if (!context.mounted) return;
    final selectedIds = Set<int>.from(currentIds);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Aggiungi a raccolta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: collections
                  .map((c) => CheckboxListTile(
                        title: Text(c.name),
                        value: selectedIds.contains(c.id),
                        onChanged: (checked) => setDialogState(() {
                          if (checked == true) {
                            selectedIds.add(c.id!);
                          } else {
                            selectedIds.remove(c.id);
                          }
                        }),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final repo = ref.read(collectionRepositoryProvider);
                // Add to newly selected
                for (final id in selectedIds.difference(Set.from(currentIds))) {
                  await repo.addSong(id, song.id!);
                }
                // Remove from deselected
                for (final id in Set.from(currentIds).difference(selectedIds)) {
                  await repo.removeSong(id, song.id!);
                }
                ref.invalidate(collectionsProvider);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tag picker ───────────────────────────────────────────────────────────────

  Future<void> _showTagPicker(BuildContext context, Song song) async {
    ref.invalidate(tagsProvider);
    final List<Tag> allTags;
    try {
      allTags = await ref.read(tagsProvider.future);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore caricamento tag: $e')),
      );
      return;
    }
    if (!context.mounted) return;

    if (allTags.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nessun tag'),
          content: const Text(
              'Non hai ancora creato nessun tag.\nVai in Impostazioni → Tag per crearne uno.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final currentTags =
        await ref.read(tagRepositoryProvider).getTagsForSong(song.id!);
    if (!context.mounted) return;

    final selectedIds = Set<int>.from(currentTags.map((t) => t.id!));
    await _tagPickerDialog(context, allTags, selectedIds,
        onSave: (ids) async {
      await ref.read(tagRepositoryProvider).setTagsForSong(song.id!, ids);
      ref.invalidate(songTagsProvider(song.id!));
    });
  }

  /// Tag picker per selezione massiva (più brani selezionati).
  Future<void> _showBulkTagPicker(BuildContext context) async {
    ref.invalidate(tagsProvider);
    final List<dynamic> allTags;
    try {
      allTags = await ref.read(tagsProvider.future);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore caricamento tag: $e')),
      );
      return;
    }
    if (!context.mounted) return;

    if (allTags.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nessun tag'),
          content: const Text(
              'Non hai ancora creato nessun tag.\nVai in Impostazioni → Tag per crearne uno.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final selectedIds = <int>{};
    await _tagPickerDialog(context, allTags, selectedIds,
        title: 'Assegna tag ai ${_selectedIds.length} brani selezionati',
        onSave: (ids) async {
      final repo = ref.read(tagRepositoryProvider);
      for (final songId in _selectedIds) {
        // Merge: aggiungo i tag selezionati senza rimuovere quelli esistenti
        final existing = await repo.getTagsForSong(songId);
        final merged = {...existing.map((t) => t.id!), ...ids}.toList();
        await repo.setTagsForSong(songId, merged);
      }
      _exitSelectionMode();
    });
  }

  /// Dialogo generico per selezionare tag da una lista.
  Future<void> _tagPickerDialog(
    BuildContext context,
    List<dynamic> allTags,
    Set<int> initialIds, {
    String title = 'Tag',
    required Future<void> Function(List<int>) onSave,
  }) async {
    final selectedIds = Set<int>.from(initialIds);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: allTags.map((tag) {
                final color = _parseTagColor(tag.color as String);
                return CheckboxListTile(
                  secondary: Container(
                    width: 14,
                    height: 14,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  title: Text(tag.name as String),
                  value: selectedIds.contains(tag.id as int?),
                  onChanged: (checked) => setDialogState(() {
                    if (checked == true) {
                      selectedIds.add(tag.id as int);
                    } else {
                      selectedIds.remove(tag.id as int?);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await onSave(selectedIds.toList());
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit dialog ─────────────────────────────────────────────────────────────

  static const _keySignatures = [
    'C', 'C#', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
    'Cm', 'C#m', 'Dm', 'Ebm', 'Em', 'Fm', 'F#m', 'Gm', 'Abm', 'Am', 'Bbm', 'Bm',
  ];

  static const _instruments = [
    'Pianoforte', 'Organo', 'Chitarra', 'Chitarra Basso', 'Violino', 'Viola',
    'Violoncello', 'Contrabbasso', 'Flauto', 'Oboe', 'Clarinetto', 'Fagotto',
    'Sassofono', 'Tromba', 'Corno', 'Trombone', 'Tuba', 'Percussioni',
    'Voce', 'Ensemble', 'Altro',
  ];

  Future<void> _showEditDialog(BuildContext context, Song song) async {
    final titleCtrl = TextEditingController(text: song.title);
    final authorCtrl = TextEditingController(text: song.composerName ?? '');
    final bpmCtrl = TextEditingController(text: song.bpm != null ? '${song.bpm}' : '');
    String? selectedKey = song.keySignature;
    String? selectedInstrument = song.instrument;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Modifica dettagli'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Titolo'),
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: authorCtrl,
                    decoration: const InputDecoration(labelText: 'Autore (opzionale)'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  Builder(builder: (ctx) {
                    final locale = Localizations.localeOf(ctx);
                    final keyItems = KeySignatureLocalization.items(locale);
                    return DropdownButtonFormField<String>(
                      value: selectedKey,
                      decoration: const InputDecoration(labelText: 'Tonalità'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                            value: null,
                            child: Text('Nessuna',
                                style: TextStyle(color: Colors.grey))),
                        ...keyItems.map((item) => DropdownMenuItem(
                            value: item.stored, child: Text(item.label))),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedKey = v),
                    );
                  }),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bpmCtrl,
                    decoration: const InputDecoration(labelText: 'BPM (opzionale)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedInstrument,
                    decoration: const InputDecoration(labelText: 'Strumento'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                          value: null,
                          child: Text('Nessuno',
                              style: TextStyle(color: Colors.grey))),
                      ..._instruments.map((s) =>
                          DropdownMenuItem(value: s, child: Text(s))),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedInstrument = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annulla')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Salva')),
            ],
          ),
        ),
      );
      if (confirmed != true || !context.mounted) return;

      final newTitle = titleCtrl.text.trim().isEmpty ? song.title : titleCtrl.text.trim();
      final newAuthor = authorCtrl.text.trim().isEmpty ? null : authorCtrl.text.trim();
      final newBpm = int.tryParse(bpmCtrl.text.trim());

      int? composerId;
      if (newAuthor != null) {
        final composer = await ref.read(composerRepositoryProvider).findOrCreate(newAuthor);
        composerId = composer.id;
      }
      if (!context.mounted) return;

      await ref.read(songRepositoryProvider).update(song.copyWith(
        title: newTitle,
        composerId: composerId,
        clearComposerId: newAuthor == null,
        keySignature: selectedKey,
        clearKeySignature: selectedKey == null,
        bpm: newBpm,
        clearBpm: newBpm == null,
        instrument: selectedInstrument,
        clearInstrument: selectedInstrument == null,
        updatedAt: DateTime.now(),
      ));
      ref.invalidate(songsProvider);
    } finally {
      titleCtrl.dispose();
      authorCtrl.dispose();
      bpmCtrl.dispose();
    }
  }

  // ── Single delete ───────────────────────────────────────────────────────────

  Future<void> _confirmDelete(BuildContext context, Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina spartito'),
        content: Text(
            'Vuoi eliminare "${song.title}"?\nIl file PDF verrà rimosso dal dispositivo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await ref.read(songRepositoryProvider).delete(song.id!);
    ref.invalidate(songsProvider);
  }

  // ── Import ──────────────────────────────────────────────────────────────────

  Future<void> _startImport(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Importazione PDF non disponibile su web. Usa la app mobile.')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    if (!context.mounted) return;

    // ── Batch import (2+ files) ─────────────────────────────────────────────
    if (result.files.length > 1) {
      await _importBatch(context, result.files);
      return;
    }

    // ── Single import (existing flow) ───────────────────────────────────────
    final picked = result.files.first;
    if (picked.path == null) return;

    final customize = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importa spartito'),
        content: const Text(
            'Vuoi importare subito o aggiungere titolo, autore e lista?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Importa subito')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Personalizza')),
        ],
      ),
    );
    if (customize == null || !context.mounted) return;

    _ImportResult? importResult;
    if (customize) {
      importResult = await showDialog<_ImportResult>(
        context: context,
        builder: (ctx) => _ImportDetailsDialog(
          defaultTitle: p.basenameWithoutExtension(picked.name),
        ),
      );
      if (importResult == null || !context.mounted) return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Importazione in corso…')));

    try {
      // ── Hash check for duplicates ───────────────────────────────────────
      final fileHash = await _computeHash(picked.path!);
      if (context.mounted && fileHash != null) {
        final existing =
            await ref.read(songRepositoryProvider).getByHash(fileHash);
        if (existing != null && context.mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('File già presente'),
              content: Text(
                  'Questo PDF è già in libreria come:\n"${existing.title}"\n\nImportarlo comunque?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annulla')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Importa comunque')),
              ],
            ),
          );
          if (proceed != true || !context.mounted) return;
        }
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final pdfsDir = Directory(p.join(docsDir.path, 'pdfs'));
      await pdfsDir.create(recursive: true);
      final destPath = p.join(pdfsDir.path, '${const Uuid().v4()}.pdf');
      await File(picked.path!).copy(destPath);

      int totalPages = 0;
      try {
        final doc = await PdfDocument.openFile(destPath);
        totalPages = doc.pagesCount;
        await doc.close();
      } catch (_) {}

      int? composerId;
      if (importResult?.authorName != null) {
        final composer = await ref
            .read(composerRepositoryProvider)
            .findOrCreate(importResult!.authorName!);
        composerId = composer.id;
      }

      final title =
          importResult?.title ?? p.basenameWithoutExtension(picked.name);
      final now = DateTime.now();
      final savedSong = await ref.read(songRepositoryProvider).insert(Song(
            title: title,
            composerId: composerId,
            filePath: destPath,
            totalPages: totalPages,
            lastPage: 0,
            fileHash: fileHash,
            createdAt: now,
            updatedAt: now,
          ));

      if (importResult != null && importResult.setlistIds.isNotEmpty) {
        final setlistRepo = ref.read(setlistRepositoryProvider);
        for (final setlistId in importResult.setlistIds) {
          final count = await setlistRepo.getItemCount(setlistId);
          await setlistRepo.addItem(SetlistItem(
            setlistId: setlistId,
            songId: savedSong.id!,
            position: count,
          ));
        }
      }

      if (importResult != null && importResult.collectionIds.isNotEmpty) {
        final collectionRepo = ref.read(collectionRepositoryProvider);
        for (final collectionId in importResult.collectionIds) {
          await collectionRepo.addSong(collectionId, savedSong.id!);
        }
      }

      ref.invalidate(songsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$title" importato con successo')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore importazione: $e')),
        );
      }
    }
  }

  // ── Batch import ─────────────────────────────────────────────────────────────

  Future<void> _importBatch(
      BuildContext context, List<PlatformFile> files) async {
    final total = files.length;
    int done = 0;
    int failed = 0;
    int skipped = 0;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Importazione di $total PDF in corso…')),
    );

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final pdfsDir = Directory(p.join(docsDir.path, 'pdfs'));
      await pdfsDir.create(recursive: true);

      for (final file in files) {
        if (file.path == null) {
          failed++;
          continue;
        }
        try {
          // Hash check — skip silent duplicates in batch mode
          final fileHash = await _computeHash(file.path!);
          if (fileHash != null) {
            final existing =
                await ref.read(songRepositoryProvider).getByHash(fileHash);
            if (existing != null) {
              skipped++;
              continue;
            }
          }

          final destPath =
              p.join(pdfsDir.path, '${const Uuid().v4()}.pdf');
          await File(file.path!).copy(destPath);

          int totalPages = 0;
          try {
            final doc = await PdfDocument.openFile(destPath);
            totalPages = doc.pagesCount;
            await doc.close();
          } catch (_) {}

          final title = p.basenameWithoutExtension(file.name);
          final now = DateTime.now();
          await ref.read(songRepositoryProvider).insert(Song(
                title: title,
                filePath: destPath,
                totalPages: totalPages,
                lastPage: 0,
                fileHash: fileHash,
                createdAt: now,
                updatedAt: now,
              ));
          done++;
        } catch (_) {
          failed++;
        }
      }
    } catch (e) {
      failed = total - done - skipped;
    }

    ref.invalidate(songsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      final parts = <String>[];
      if (done > 0) parts.add('$done importati');
      if (skipped > 0) parts.add('$skipped già presenti');
      if (failed > 0) parts.add('$failed falliti');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(parts.join(', '))));
    }
  }

  // ── Hash computation ──────────────────────────────────────────────────────────

  Future<String?> _computeHash(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (_) {
      return null;
    }
  }

  void _showSearch(BuildContext context) {
    showSearch(context: context, delegate: _SongSearchDelegate(ref));
  }

  // ── Filter menu (status + tag) ───────────────────────────────────────────────

  void _showFilterMenu(BuildContext context) async {
    List<dynamic> tags;
    try {
      tags = await ref.read(tagsProvider.future);
    } catch (_) {
      tags = [];
    }
    if (!context.mounted) return;

    final currentTagFilter = ref.read(tagFilterProvider);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          SongStatus? localStatus = _statusFilter;
          int? localTagId = currentTagFilter;
          // Re-read on rebuild
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Status section ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Stato',
                        style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            color: Theme.of(ctx).colorScheme.primary)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.all_inclusive),
                    title: const Text('Tutti gli stati'),
                    trailing: _statusFilter == null
                        ? Icon(Icons.check,
                            color: Theme.of(ctx).colorScheme.primary, size: 18)
                        : null,
                    onTap: () {
                      setState(() => _statusFilter = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  ...SongStatus.values
                      .where((s) => s != SongStatus.none)
                      .map((status) => ListTile(
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: status.color,
                                  shape: BoxShape.circle),
                            ),
                            title: Text(status.label),
                            trailing: _statusFilter == status
                                ? Icon(Icons.check,
                                    color: Theme.of(ctx).colorScheme.primary,
                                    size: 18)
                                : null,
                            onTap: () {
                              setState(() => _statusFilter = status);
                              Navigator.pop(ctx);
                            },
                          )),

                  if (tags.isNotEmpty) ...[
                    const Divider(height: 1),
                    // ── Tag section ─────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('Tag',
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                              color: Theme.of(ctx).colorScheme.primary)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.label_off_outlined),
                      title: const Text('Tutti i tag'),
                      trailing: localTagId == null
                          ? Icon(Icons.check,
                              color: Theme.of(ctx).colorScheme.primary, size: 18)
                          : null,
                      onTap: () {
                        ref.read(tagFilterProvider.notifier).state = null;
                        Navigator.pop(ctx);
                      },
                    ),
                    ...tags.map((tag) {
                      final tagColor = _parseTagColor(tag.color as String);
                      return ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: tagColor, shape: BoxShape.circle),
                        ),
                        title: Text(tag.name as String),
                        trailing: localTagId == (tag.id as int?)
                            ? Icon(Icons.check,
                                color: Theme.of(ctx).colorScheme.primary,
                                size: 18)
                            : null,
                        onTap: () {
                          setSheetState(() => localTagId = tag.id as int?);
                          ref.read(tagFilterProvider.notifier).state =
                              tag.id as int?;
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _parseTagColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  // ── Status picker ────────────────────────────────────────────────────────────

  Future<void> _showStatusPicker(BuildContext context, Song song) async {
    final result = await showModalBottomSheet<SongStatus>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Stato di "${song.title}"',
                style: Theme.of(ctx).textTheme.titleMedium),
          ),
          ...SongStatus.values.map((status) => ListTile(
            leading: status == SongStatus.none
                ? const Icon(Icons.remove_circle_outline)
                : Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: status.color, shape: BoxShape.circle),
                  ),
            title: Text(status == SongStatus.none ? 'Nessuno stato' : status.label),
            trailing: song.status == status
                ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                : null,
            onTap: () => Navigator.pop(ctx, status),
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    await ref.read(songRepositoryProvider).update(
      song.copyWith(status: result, updatedAt: DateTime.now()),
    );
    ref.invalidate(songsProvider);
  }
}

// ── Import result ─────────────────────────────────────────────────────────────

class _ImportResult {
  final String title;
  final String? authorName;
  final List<int> setlistIds;
  final List<int> collectionIds;
  const _ImportResult({
    required this.title,
    this.authorName,
    required this.setlistIds,
    this.collectionIds = const [],
  });
}

// ── Import details dialog ─────────────────────────────────────────────────────

class _ImportDetailsDialog extends ConsumerStatefulWidget {
  final String defaultTitle;
  const _ImportDetailsDialog({required this.defaultTitle});

  @override
  ConsumerState<_ImportDetailsDialog> createState() =>
      _ImportDetailsDialogState();
}

class _ImportDetailsDialogState extends ConsumerState<_ImportDetailsDialog> {
  int _step = 0;
  late final TextEditingController _titleCtrl;
  final _authorCtrl = TextEditingController();
  List<Setlist> _setlists = [];
  final Set<int> _selectedSetlistIds = {};
  bool _loadingSetlists = true;
  List<Collection> _collections = [];
  final Set<int> _selectedCollectionIds = {};
  bool _loadingCollections = true;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.defaultTitle);
    _loadSetlists();
    _loadCollections();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSetlists() async {
    final setlists = await ref.read(setlistRepositoryProvider).getAll();
    if (mounted) {
      setState(() {
        _setlists = setlists;
        _loadingSetlists = false;
      });
    }
  }

  Future<void> _loadCollections() async {
    final collections = await ref.read(collectionRepositoryProvider).getAll();
    if (mounted) {
      setState(() {
        _collections = collections;
        _loadingCollections = false;
      });
    }
  }

  void _next() {
    if (_step == 0) {
      if (_setlists.isEmpty && !_loadingSetlists) {
        if (_collections.isEmpty && !_loadingCollections) {
          _confirm();
        } else {
          setState(() => _step = 2);
        }
      } else {
        setState(() => _step = 1);
      }
    } else if (_step == 1) {
      if (_collections.isEmpty && !_loadingCollections) {
        _confirm();
      } else {
        setState(() => _step = 2);
      }
    } else {
      _confirm();
    }
  }

  void _confirm() {
    final title = _titleCtrl.text.trim().isEmpty
        ? widget.defaultTitle
        : _titleCtrl.text.trim();
    final author =
        _authorCtrl.text.trim().isEmpty ? null : _authorCtrl.text.trim();
    Navigator.of(context).pop(_ImportResult(
      title: title,
      authorName: author,
      setlistIds: List.from(_selectedSetlistIds),
      collectionIds: List.from(_selectedCollectionIds),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_step == 0 ? 'Dettagli spartito' : _step == 1 ? 'Aggiungi a una lista' : 'Aggiungi a una raccolta'),
      content: _step == 0 ? _buildStep0() : _step == 1 ? _buildStep1() : _buildStep2(),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla')),
        if (_step == 1 || _step == 2)
          TextButton(
              onPressed: () => setState(() => _step = _step == 2 ? 1 : 0),
              child: const Text('Indietro')),
        FilledButton(
            onPressed: _next,
            child: Text(_step == 0 ? 'Avanti' : _step == 1 ? 'Avanti' : 'Importa')),
      ],
    );
  }

  Widget _buildStep0() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Titolo'),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _authorCtrl,
            decoration:
                const InputDecoration(labelText: 'Autore (opzionale)'),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      );

  Widget _buildStep1() {
    if (_loadingSetlists) {
      return const SizedBox(
          height: 80, child: Center(child: CircularProgressIndicator()));
    }
    if (_setlists.isEmpty) {
      return const Text(
          'Nessuna lista disponibile.\nPotrai aggiungere lo spartito a una lista in seguito.');
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _setlists
            .map((s) => CheckboxListTile(
                  title: Text(s.title),
                  value: _selectedSetlistIds.contains(s.id),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selectedSetlistIds.add(s.id!);
                    } else {
                      _selectedSetlistIds.remove(s.id);
                    }
                  }),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildStep2() {
    if (_loadingCollections) {
      return const SizedBox(
          height: 80, child: Center(child: CircularProgressIndicator()));
    }
    if (_collections.isEmpty) {
      return const Text(
          'Nessuna raccolta disponibile.\nPotrai aggiungere lo spartito a una raccolta in seguito.');
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _collections
            .map((c) => CheckboxListTile(
                  title: Text(c.name),
                  value: _selectedCollectionIds.contains(c.id),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selectedCollectionIds.add(c.id!);
                    } else {
                      _selectedCollectionIds.remove(c.id);
                    }
                  }),
                ))
            .toList(),
      ),
    );
  }
}

// ── Song grid card ────────────────────────────────────────────────────────────

class _SongGridCard extends StatelessWidget {
  final Song song;
  final bool isSelected;
  final bool inSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOptions;

  const _SongGridCard({
    super.key,
    required this.song,
    required this.isSelected,
    required this.inSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PdfThumbnailExpanded(
                    key: ValueKey(song.filePath),
                    filePath: song.filePath,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (song.composerName != null)
                        GestureDetector(
                          onTap: () =>
                              context.push('/composers/${song.composerId}'),
                          child: Text(
                            song.composerName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ),
                      if (song.totalPages > 0)
                        Text(
                          song.lastPage > 0
                              ? 'Pag. ${song.lastPage} / ${song.totalPages}'
                              : '${song.totalPages} pag.',
                          style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      if (song.status != SongStatus.none || song.keySignature != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              if (song.status != SongStatus.none)
                                _MetaBadge(label: song.status.label, color: song.status.color),
                              if (song.keySignature != null)
                                _MetaBadge(
                                    label: KeySignatureLocalization.display(
                                        song.keySignature!,
                                        Localizations.localeOf(context)),
                                    color: const Color(0xFF4A90D9)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Three-dot menu (normal mode)
        if (!inSelectionMode)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onOptions,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.more_vert,
                      size: 22, color: Colors.white),
                ),
              ),
            ),
          ),
        // Selection overlay
        if (inSelectionMode)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white.withOpacity(0.85),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}

// ── Search delegate ───────────────────────────────────────────────────────────

class _SongSearchDelegate extends SearchDelegate<String> {
  final WidgetRef ref;
  _SongSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Cerca per titolo, compositore, tonalità…';

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _buildResultsWidget(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildResultsWidget(context);

  Widget _buildResultsWidget(BuildContext context) {
    if (query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search,
                size: 64,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Digita per cercare'),
          ],
        ),
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final songsAsync = ref.watch(
            songsProvider((query: query.trim(), tagId: null)));
        return songsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Errore: $e')),
          data: (songs) {
            if (songs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_off,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('Nessun risultato per "$query"'),
                  ],
                ),
              );
            }
            return ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, i) {
                final song = songs[i];
                return ListTile(
                  leading: SizedBox(
                    width: 40,
                    height: 56,
                    child: PdfThumbnail(
                      key: ValueKey(song.filePath),
                      filePath: song.filePath,
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (song.composerName != null) song.composerName!,
                      if (song.keySignature != null)
                        KeySignatureLocalization.display(
                            song.keySignature!,
                            Localizations.localeOf(context)),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6)),
                  ),
                  onTap: () {
                    close(context, '');
                    context.push('${AppConstants.routeViewer}/${song.id}');
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── A-Z Scroll Bar ────────────────────────────────────────────────────────────

class _AlphaScrollBar extends StatefulWidget {
  final List<Song> songs;
  final void Function(String letter) onLetterSelected;

  const _AlphaScrollBar({
    required this.songs,
    required this.onLetterSelected,
  });

  @override
  State<_AlphaScrollBar> createState() => _AlphaScrollBarState();
}

class _AlphaScrollBarState extends State<_AlphaScrollBar> {
  static const _letters = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  String? _activeLetter;

  // Returns true if at least one song starts with this letter
  bool _hasLetter(String letter) {
    return widget.songs.any((s) {
      final first =
          s.title.trim().isNotEmpty ? s.title.trim()[0].toUpperCase() : '#';
      if (letter == '#') return !RegExp(r'[A-Z]').hasMatch(first);
      return first == letter;
    });
  }

  void _onDrag(Offset localPosition, BoxConstraints constraints) {
    final frac = (localPosition.dy / constraints.maxHeight).clamp(0.0, 0.999);
    final index = (frac * _letters.length).floor();
    final letter = _letters[index];
    if (letter != _activeLetter) {
      setState(() => _activeLetter = letter);
      widget.onLetterSelected(letter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (d) => _onDrag(d.localPosition, constraints),
          onVerticalDragUpdate: (d) => _onDrag(d.localPosition, constraints),
          onVerticalDragEnd: (_) => setState(() => _activeLetter = null),
          onTapDown: (d) {
            _onDrag(d.localPosition, constraints);
            setState(() => _activeLetter = null);
          },
          child: SizedBox(
            width: 20,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _letters.map((letter) {
                final active = _activeLetter == letter;
                final present = _hasLetter(letter);
                return Expanded(
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: active ? 13 : 9,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: present
                            ? (active ? cs.primary : cs.onSurfaceVariant)
                            : cs.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ── Meta badge ────────────────────────────────────────────────────────────────

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
