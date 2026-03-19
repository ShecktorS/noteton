import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/setlist.dart';
import '../../domain/models/setlist_item.dart';
import '../../domain/models/song.dart';
import '../../providers/providers.dart';
import '../common/app_bottom_nav.dart';

enum _ViewMode { grid, list }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _ViewMode _viewMode = _ViewMode.grid;
  final Set<int> _selectedIds = {};

  bool get _inSelectionMode => _selectedIds.isNotEmpty;

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
    final songsAsync = ref.watch(songsProvider(query.isEmpty ? null : query));

    return Scaffold(
      appBar: _inSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
              title: Text('${_selectedIds.length} selezionat${_selectedIds.length == 1 ? 'o' : 'i'}'),
              actions: [
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
              ],
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
                  const Text('Nessuno spartito nella libreria'),
                  const SizedBox(height: 8),
                  const Text('Tocca + per importare un PDF',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return _viewMode == _ViewMode.grid
              ? _buildGrid(songs)
              : _buildList(songs);
        },
      ),
      floatingActionButton: _inSelectionMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'view_toggle',
                  onPressed: () => setState(() => _viewMode = _viewMode == _ViewMode.grid
                      ? _ViewMode.list
                      : _ViewMode.grid),
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
    );
  }

  // ── Grid view ───────────────────────────────────────────────────────────────

  Widget _buildGrid(List<Song> songs) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: songs.length,
      itemBuilder: (context, i) {
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: songs.length,
      itemBuilder: (context, i) {
        final song = songs[i];
        final isSelected = _selectedIds.contains(song.id);
        return ListTile(
          leading: _inSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(song.id!),
                )
              : _SmallThumbnail(
                  key: ValueKey(song.filePath),
                  filePath: song.filePath,
                ),
          title: Text(song.title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (song.composerName != null)
                Text(song.composerName!,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              if (song.lastPage > 0 && song.totalPages > 0)
                Text(
                  'Pag. ${song.lastPage} / ${song.totalPages}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary),
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
            onTap: () {
              Navigator.pop(ctx);
              _showEditDialog(context, song);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text('Elimina',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDelete(context, song);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Edit dialog ─────────────────────────────────────────────────────────────

  Future<void> _showEditDialog(BuildContext context, Song song) async {
    final titleCtrl = TextEditingController(text: song.title);
    final authorCtrl = TextEditingController(text: song.composerName ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifica dettagli'),
        content: Column(
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
              decoration:
                  const InputDecoration(labelText: 'Autore (opzionale)'),
              textCapitalization: TextCapitalization.words,
            ),
          ],
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
    );

    if (confirmed != true || !context.mounted) return;

    final newTitle =
        titleCtrl.text.trim().isEmpty ? song.title : titleCtrl.text.trim();
    final newAuthor =
        authorCtrl.text.trim().isEmpty ? null : authorCtrl.text.trim();

    int? composerId;
    if (newAuthor != null) {
      final composer =
          await ref.read(composerRepositoryProvider).findOrCreate(newAuthor);
      composerId = composer.id;
    }

    await ref.read(songRepositoryProvider).update(Song(
          id: song.id,
          title: newTitle,
          composerId: composerId,
          filePath: song.filePath,
          totalPages: song.totalPages,
          lastPage: song.lastPage,
          createdAt: song.createdAt,
          updatedAt: DateTime.now(),
        ));
    ref.invalidate(songsProvider);
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
    await ref.read(songRepositoryProvider).delete(song.id!);
    ref.invalidate(songsProvider);
  }

  // ── Import ──────────────────────────────────────────────────────────────────

  Future<void> _startImport(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Importazione PDF non disponibile su web — usa la app mobile')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;
    if (!context.mounted) return;

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

  void _showSearch(BuildContext context) {
    showSearch(context: context, delegate: _SongSearchDelegate(ref));
  }
}

// ── Import result ─────────────────────────────────────────────────────────────

class _ImportResult {
  final String title;
  final String? authorName;
  final List<int> setlistIds;
  const _ImportResult(
      {required this.title, this.authorName, required this.setlistIds});
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

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.defaultTitle);
    _loadSetlists();
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

  void _next() {
    if (_step == 0) {
      if (_setlists.isEmpty && !_loadingSetlists) {
        _confirm();
      } else {
        setState(() => _step = 1);
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
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_step == 0 ? 'Dettagli spartito' : 'Aggiungi a una lista'),
      content: _step == 0 ? _buildStep0() : _buildStep1(),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla')),
        if (_step == 1)
          TextButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('Indietro')),
        FilledButton(
            onPressed: _next,
            child: Text(_step == 0 ? 'Avanti' : 'Importa')),
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
                  child: _PdfThumbnail(
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
                        Text(
                          song.composerName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (song.lastPage > 0 && song.totalPages > 0)
                        Text(
                          'Pag. ${song.lastPage} / ${song.totalPages}',
                          style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.primary),
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

// ── Small thumbnail for list view ─────────────────────────────────────────────

class _SmallThumbnail extends StatefulWidget {
  final String filePath;
  const _SmallThumbnail({super.key, required this.filePath});

  @override
  State<_SmallThumbnail> createState() => _SmallThumbnailState();
}

class _SmallThumbnailState extends State<_SmallThumbnail> {
  Uint8List? _bytes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_SmallThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      setState(() { _bytes = null; _loaded = false; });
      _load();
    }
  }

  Future<void> _load() async {
    if (kIsWeb) { if (mounted) setState(() => _loaded = true); return; }
    PdfDocument? doc;
    PdfPage? page;
    try {
      doc = await PdfDocument.openFile(widget.filePath);
      page = await doc.getPage(1);
      final image = await page.render(
          width: 80, height: 110, format: PdfPageImageFormat.jpeg);
      if (mounted) setState(() { _bytes = image?.bytes; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    } finally {
      await page?.close();
      await doc?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = 48.0;
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    if (!_loaded) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: const Center(child: SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5))),
      );
    }
    if (_bytes == null) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Icon(Icons.picture_as_pdf, size: 24,
            color: Theme.of(context).colorScheme.primary),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.memory(_bytes!, width: size, height: size, fit: BoxFit.cover),
    );
  }
}

// ── PDF thumbnail for grid ────────────────────────────────────────────────────

class _PdfThumbnail extends StatefulWidget {
  final String filePath;
  const _PdfThumbnail({super.key, required this.filePath});

  @override
  State<_PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<_PdfThumbnail> {
  Uint8List? _bytes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_PdfThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      setState(() { _bytes = null; _loaded = false; });
      _load();
    }
  }

  Future<void> _load() async {
    if (kIsWeb) { if (mounted) setState(() => _loaded = true); return; }
    PdfDocument? doc;
    PdfPage? page;
    try {
      doc = await PdfDocument.openFile(widget.filePath);
      page = await doc.getPage(1);
      final image = await page.render(
        width: page.width / 2,
        height: page.height / 2,
        format: PdfPageImageFormat.jpeg,
      );
      if (mounted) setState(() { _bytes = image?.bytes; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    } finally {
      await page?.close();
      await doc?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_bytes == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: Icon(Icons.picture_as_pdf,
            size: 48, color: Theme.of(context).colorScheme.primary)),
      );
    }
    return Image.memory(_bytes!, fit: BoxFit.cover, width: double.infinity);
  }
}

// ── Search delegate ───────────────────────────────────────────────────────────

class _SongSearchDelegate extends SearchDelegate<String> {
  final WidgetRef ref;
  _SongSearchDelegate(this.ref);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) {
    ref.read(searchQueryProvider.notifier).state = query;
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) => const SizedBox.shrink();
}
