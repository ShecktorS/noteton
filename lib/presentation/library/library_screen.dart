import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/song.dart';
import '../../providers/providers.dart';
import '../common/app_bottom_nav.dart';
import '../common/global_search_sheet.dart';
import '../common/update_home_banner.dart';
import 'import/pdf_import.dart';
import 'sheets/delete_dialogs.dart';
import 'sheets/filter_sheet.dart';
import 'sheets/song_options_sheet.dart';
import 'sheets/sort_sheet.dart';
import 'sheets/tag_picker_dialog.dart';
import 'widgets/alpha_scroll_bar.dart';
import 'widgets/library_empty_state.dart';
import 'widgets/song_grid_card.dart';
import 'widgets/song_list_tile.dart';

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
                  onPressed: () => showGlobalSearchSheet(context),
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Ordina',
                  onPressed: () => showSortSheet(context, ref),
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
      body: Column(
        children: [
          // Card "aggiornamento disponibile" — visibile solo se update available
          // + auto-update on + non dismessa in sessione. Auto-nascondibile.
          const UpdateHomeBanner(),
          Expanded(
            child: songsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Errore: $e')),
              data: (songs) {
          // Applica filtro status se attivo
          final statusFiltered = _statusFilter == null
              ? songs
              : songs.where((s) => s.status == _statusFilter).toList();
          // Applica ordinamento
          final filtered = sortSongs(statusFiltered, sortOrder);

          if (filtered.isEmpty) {
            return LibraryEmptyState(statusFilter: _statusFilter);
          }
          final content = _viewMode == _ViewMode.grid
              ? _buildGrid(filtered)
              : _buildList(filtered);
          return Row(
            children: [
              Expanded(child: content),
              AlphaScrollBar(
                songs: filtered,
                onLetterSelected: (letter) =>
                    _scrollToLetter(letter, filtered, context),
              ),
            ],
          );
              },
            ),
          ),
        ],
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
                  onPressed: () => startPdfImport(context, ref),
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
        return SongGridCard(
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
        return SongListTile(
          song: song,
          isSelected: _selectedIds.contains(song.id),
          inSelectionMode: _inSelectionMode,
          onToggleSelection: () => _toggleSelection(song.id!),
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

  // ── Azioni ──────────────────────────────────────────────────────────────────

  Future<void> _showOptions(BuildContext context, Song song) =>
      showSongOptionsSheet(context, ref, song);

  Future<void> _deleteSelected(BuildContext context) async {
    final deleted = await confirmDeleteSongs(context, ref, _selectedIds);
    if (!deleted) return;
    _exitSelectionMode();
    ref.invalidate(songsProvider);
  }

  Future<void> _showBulkTagPicker(BuildContext context) =>
      showBulkTagPicker(context, ref, _selectedIds,
          onDone: _exitSelectionMode);

  void _showFilterMenu(BuildContext context) {
    showLibraryFilterSheet(
      context,
      ref,
      currentStatus: _statusFilter,
      onStatusSelected: (status) => setState(() => _statusFilter = status),
    );
  }
}
