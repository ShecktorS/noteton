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

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final songsAsync = ref.watch(songsProvider(query.isEmpty ? null : query));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context, ref),
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

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: songs.length,
            itemBuilder: (context, i) {
              final song = songs[i];
              return _SongCard(
                song: song,
                onTap: () =>
                    context.push('${AppConstants.routeViewer}/${song.id}'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startImport(context, ref),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Future<void> _startImport(BuildContext context, WidgetRef ref) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Importazione PDF non disponibile su web — usa la app mobile')),
      );
      return;
    }

    // 1. Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;
    if (!context.mounted) return;

    // 2. Choice: import directly or customize
    final customize = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importa spartito'),
        content: const Text(
            'Vuoi importare subito o aggiungere titolo, autore e lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Importa subito'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Personalizza'),
          ),
        ],
      ),
    );
    if (customize == null || !context.mounted) return;

    // 3. If customize, show details dialog
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

    // 4. Do the actual import
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Importazione in corso…')),
    );

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

      final title = importResult?.title ?? p.basenameWithoutExtension(picked.name);
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

  void _showSearch(BuildContext context, WidgetRef ref) {
    showSearch(
      context: context,
      delegate: _SongSearchDelegate(ref),
    );
  }
}

// ── Import result ─────────────────────────────────────────────────────────────

class _ImportResult {
  final String title;
  final String? authorName;
  final List<int> setlistIds;

  const _ImportResult({
    required this.title,
    this.authorName,
    required this.setlistIds,
  });
}

// ── Import details dialog (2 steps) ──────────────────────────────────────────

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
          child: const Text('Annulla'),
        ),
        if (_step == 1)
          TextButton(
            onPressed: () => setState(() => _step = 0),
            child: const Text('Indietro'),
          ),
        FilledButton(
          onPressed: _next,
          child: Text(_step == 0 ? 'Avanti' : 'Importa'),
        ),
      ],
    );
  }

  Widget _buildStep0() {
    return Column(
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
          decoration: const InputDecoration(labelText: 'Autore (opzionale)'),
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  Widget _buildStep1() {
    if (_loadingSetlists) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
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
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedSetlistIds.add(s.id!);
                      } else {
                        _selectedSetlistIds.remove(s.id);
                      }
                    });
                  },
                ))
            .toList(),
      ),
    );
  }
}

// ── Song card with PDF thumbnail ─────────────────────────────────────────────

class _SongCard extends ConsumerWidget {
  final Song song;
  final VoidCallback onTap;

  const _SongCard({required this.song, required this.onTap});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina spartito'),
        content: Text(
            'Vuoi eliminare "${song.title}"?\nIl file PDF verrà rimosso dal dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _confirmDelete(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _PdfThumbnail(filePath: song.filePath)),
            Padding(
              padding: const EdgeInsets.all(8),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PDF thumbnail widget ──────────────────────────────────────────────────────

class _PdfThumbnail extends StatefulWidget {
  final String filePath;
  const _PdfThumbnail({required this.filePath});

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

  Future<void> _load() async {
    if (kIsWeb) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
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
      if (mounted) {
        setState(() {
          _bytes = image?.bytes;
          _loaded = true;
        });
      }
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
        child: Center(
          child: Icon(Icons.picture_as_pdf,
              size: 48, color: Theme.of(context).colorScheme.primary),
        ),
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
