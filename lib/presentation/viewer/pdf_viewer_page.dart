import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/utils/song_path.dart';
import '../../domain/models/song.dart';
import '../../domain/models/drawing_stroke.dart';
import '../../providers/providers.dart';
import '../common/metronome_modal.dart';
import 'drawing_layer.dart';

class PdfViewerPage extends ConsumerStatefulWidget {
  final int songId;
  const PdfViewerPage({super.key, required this.songId});

  @override
  ConsumerState<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends ConsumerState<PdfViewerPage> {
  PdfController? _pdfController;
  bool _loading = true;
  String? _error;
  String _title = 'Spartito';
  int _currentPage = 1;
  int _totalPages = 0;
  bool _appBarVisible = true;
  bool _standMode = false;
  Song? _songCache;

  // ── Annotation state ──────────────────────────────────────────────────────
  bool _drawingMode = false;
  DrawingToolState _toolState = const DrawingToolState();
  final GlobalKey<DrawingLayerState> _drawingLayerKey = GlobalKey();

  static const _colorPresets = [
    Colors.black,
    Color(0xFFE53935), // rosso
    Color(0xFF1E88E5), // blu
    Color(0xFF43A047), // verde
    Color(0xFFFFD600), // giallo (evidenziatore)
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      final song =
          await ref.read(songRepositoryProvider).getById(widget.songId);
      if (song == null) {
        if (mounted) {
          setState(() {
            _error = 'Spartito non trovato';
            _loading = false;
          });
        }
        return;
      }

      _songCache = song;
      if (song.bpm != null && song.bpm! > 0) {
        ref.read(metronomeServiceProvider).setBpm(song.bpm!);
      }
      final initialPage = song.lastPage > 0 ? song.lastPage : 1;
      final resolved = await SongPath.resolveDetailed(song.filePath);
      if (!resolved.exists) {
        if (mounted) {
          setState(() {
            _error =
                'PDF non disponibile sul dispositivo.\nPotrebbe essere stato spostato o eliminato. Controlla "Salute libreria" nelle impostazioni.';
            _loading = false;
          });
        }
        return;
      }
      final doc = await PdfDocument.openFile(resolved.path);
      final actualTotalPages = doc.pagesCount;

      // Persist totalPages immediately if it differs from the stored value.
      // This fixes the case where import saved 0 (PDF not yet readable at
      // copy time) — the library shows the correct count as soon as you
      // navigate back, without needing a full app restart.
      if (actualTotalPages > 0 && actualTotalPages != song.totalPages) {
        unawaited(ref
            .read(songRepositoryProvider)
            .update(song.copyWith(totalPages: actualTotalPages)));
        ref.invalidate(songsProvider);
      }

      final controller = PdfController(
        document: Future.value(doc),
        initialPage: initialPage,
      );

      if (mounted) {
        setState(() {
          _title = song.title;
          _pdfController = controller;
          _currentPage = initialPage;
          _totalPages = actualTotalPages > 0 ? actualTotalPages : song.totalPages;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore apertura PDF: $e';
          _loading = false;
        });
      }
    }
  }

  void _onDocumentLoaded(PdfDocument doc) {
    final realPages = doc.pagesCount;
    if (_totalPages != realPages && realPages > 0) {
      setState(() => _totalPages = realPages);
    }
    final song = _songCache;
    if (song != null && song.totalPages != realPages && realPages > 0) {
      ref.read(songRepositoryProvider).update(
            song.copyWith(totalPages: realPages),
          );
      ref.invalidate(songsProvider);
    }
  }

  @override
  void dispose() {
    if (_standMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _pdfController?.dispose();
    super.dispose();
  }

  void _toggleAppBar() => setState(() => _appBarVisible = !_appBarVisible);
  void _toggleDrawingMode() =>
      setState(() => _drawingMode = !_drawingMode);

  void _previousPage() {
    if (_currentPage > 1) {
      _pdfController?.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      _pdfController?.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    ref.read(songRepositoryProvider).updateLastPage(widget.songId, page);
  }

  Future<void> _confirmClearPage() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancella annotazioni'),
        content:
            const Text('Rimuovere tutte le annotazioni di questa pagina?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancella',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) _drawingLayerKey.currentState?.clearPage();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _appBarVisible
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title,
                      style: const TextStyle(
                          fontSize: 16, color: Colors.white)),
                  if (_totalPages > 0)
                    Text('$_currentPage / $_totalPages',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                ],
              ),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                // Metronome — apre modale
                Consumer(builder: (context, ref, _) {
                  final m = ref.watch(metronomeServiceProvider);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.music_note,
                          color: m.isRunning
                              ? (m.isDownbeat
                                  ? accent
                                  : accent.withValues(alpha: 0.7))
                              : Colors.white70,
                        ),
                        tooltip: 'Metronomo',
                        onPressed: () => showMetronomeModal(context),
                      ),
                      if (m.isRunning)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 80),
                            width: m.isDownbeat ? 9 : 6,
                            height: m.isDownbeat ? 9 : 6,
                            decoration: BoxDecoration(
                              color: m.isDownbeat ? accent : Colors.white54,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                // Annotation toggle
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: _drawingMode ? accent : Colors.white70,
                  ),
                  tooltip: _drawingMode
                      ? 'Esci da modalità annotazione'
                      : 'Modalità annotazione',
                  onPressed: _toggleDrawingMode,
                ),
                // Stand mode
                IconButton(
                  icon: Icon(_standMode
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen),
                  tooltip: _standMode
                      ? 'Esci da modalità leggio'
                      : 'Modalità leggio',
                  onPressed: () {
                    setState(() => _standMode = !_standMode);
                    if (_standMode) {
                      SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.immersiveSticky);
                    } else {
                      SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.edgeToEdge);
                    }
                  },
                ),
              ],
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Text(_error!,
              style: const TextStyle(color: Colors.white)));
    }
    if (_pdfController == null) return const SizedBox.shrink();

    return Stack(
      children: [
        // 1 — PDF viewer
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: _standMode ? Colors.white : Colors.transparent,
          child: PdfView(
            controller: _pdfController!,
            onPageChanged: _onPageChanged,
            onDocumentLoaded: _onDocumentLoaded,
            scrollDirection: Axis.horizontal,
            pageSnapping: true,
          ),
        ),

        // 2 — Drawing layer (always present; isActive drives input capture)
        DrawingLayer(
          key: _drawingLayerKey,
          songId: widget.songId,
          pageNumber: _currentPage,
          isActive: _drawingMode,
          toolState: _toolState,
        ),

        // 3 — Navigation zones (hidden in drawing mode — use AppBar buttons)
        if (!_drawingMode) ...[
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.25,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _currentPage > 1 ? _previousPage : _toggleAppBar,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.25,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap:
                  _currentPage < _totalPages ? _nextPage : _toggleAppBar,
            ),
          ),
          Positioned.fill(
            left: MediaQuery.of(context).size.width * 0.25,
            right: MediaQuery.of(context).size.width * 0.25,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleAppBar,
            ),
          ),
        ],

        // 4 — Annotation toolbar (visible in drawing mode + appbar visible)
        if (_drawingMode && _appBarVisible)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: _buildAnnotationToolbar(),
          ),

      ],
    );
  }

  // ── Annotation toolbar ────────────────────────────────────────────────────

  Widget _buildAnnotationToolbar() {
    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.80),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tools
            _toolBtn(DrawingTool.pen, Icons.edit, 'Penna'),
            _toolBtn(DrawingTool.highlighter, Icons.highlight,
                'Evidenziatore'),
            _toolBtn(DrawingTool.eraser, Icons.auto_fix_normal, 'Gomma'),

            const _ToolbarDivider(),

            // Color presets
            ..._colorPresets.map(_colorDot),

            const _ToolbarDivider(),

            // Undo
            _iconBtn(Icons.undo, 'Annulla',
                () => _drawingLayerKey.currentState?.undo()),

            // Clear page
            _iconBtn(Icons.delete_sweep_outlined, 'Cancella pagina',
                _confirmClearPage, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(DrawingTool tool, IconData icon, String tooltip) {
    final selected = _toolState.tool == tool;
    final accent = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () =>
            setState(() => _toolState = _toolState.copyWith(tool: tool)),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.all(6),
          decoration: selected
              ? BoxDecoration(
                  color: accent.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Icon(icon,
              size: 22,
              color: selected ? accent : Colors.white70),
        ),
      ),
    );
  }

  Widget _colorDot(Color color) {
    final selected = _toolState.color.value == color.value;
    return GestureDetector(
      onTap: () =>
          setState(() => _toolState = _toolState.copyWith(color: color)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Colors.white, width: 2)
              : Border.all(color: Colors.white24, width: 1),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap,
      {Color? color}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon, size: 22, color: color ?? Colors.white70),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 22,
        color: Colors.white24,
        margin: const EdgeInsets.symmetric(horizontal: 8),
      );
}
