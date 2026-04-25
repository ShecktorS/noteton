import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/utils/song_path.dart';
import '../../domain/models/setlist_item.dart';
import '../../domain/models/drawing_stroke.dart';
import '../../providers/providers.dart';
import '../viewer/drawing_layer.dart';
import '../viewer/metronome_controller.dart';

class PerformanceScreen extends ConsumerStatefulWidget {
  final int setlistId;
  final int initialSongIndex;
  const PerformanceScreen({
    super.key,
    required this.setlistId,
    this.initialSongIndex = 0,
  });

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  List<SetlistItem> _items = [];
  int _currentSongIndex = 0;
  PdfController? _pdfController;
  bool _loading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _appBarVisible = true;

  // Flash visivo per le zone tap
  bool _leftFlash = false;
  bool _rightFlash = false;

  // ── Metronome ─────────────────────────────────────────────────────────────
  late final MetronomeController _metronome;
  bool _metronomeVisible = false;
  bool _metronomeBeat = false;

  @override
  void initState() {
    super.initState();
    _metronome = MetronomeController()
      ..onBeat = () {
        if (mounted) setState(() => _metronomeBeat = !_metronomeBeat);
      }
      ..onStateChanged = () {
        if (mounted) setState(() {});
      };
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadSetlist();
  }

  @override
  void dispose() {
    _metronome.dispose();
    _pdfController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadSetlist() async {
    try {
      final items = await ref
          .read(setlistRepositoryProvider)
          .getItemsForSetlist(widget.setlistId);
      if (items.isEmpty) {
        if (mounted) setState(() { _error = 'Setlist vuota'; _loading = false; });
        return;
      }
      _items = items;
      final startIndex = widget.initialSongIndex.clamp(0, items.length - 1);
      await _loadSong(startIndex);
    } catch (e) {
      if (mounted) setState(() { _error = 'Errore: $e'; _loading = false; });
    }
  }

  Future<void> _loadSong(int index, {bool fromEnd = false}) async {
    _pdfController?.dispose();
    _pdfController = null;

    final item = _items[index];
    final song = item.song!;
    final initialPage = fromEnd && song.totalPages > 0
        ? song.totalPages
        : item.customStartPage > 0
            ? item.customStartPage
            : (song.lastPage > 0 ? song.lastPage : 1);

    final controller = PdfController(
      // Passa dal resolver: Song.filePath può essere assoluto (legacy) o
      // relativo alla docs dir (backup restore / import >= 0.3.4).
      // Se il file manca, `openFile` lancerà un errore catturato da
      // PdfView builder error.
      document: SongPath.resolveDetailed(song.filePath).then((r) {
        if (!r.exists) {
          throw StateError('PDF non disponibile sul dispositivo.');
        }
        return PdfDocument.openFile(r.path);
      }),
      initialPage: initialPage,
    );

    // Update metronome BPM when song changes
    if (song.bpm != null && song.bpm! > 0) {
      _metronome.setBpm(song.bpm!);
    }

    if (mounted) {
      setState(() {
        _currentSongIndex = index;
        _pdfController = controller;
        _currentPage = initialPage;
        _totalPages = song.totalPages;
        _loading = false;
      });
    }
  }

  void _nextAction() {
    HapticFeedback.lightImpact();
    if (_currentPage < _totalPages) {
      _pdfController?.nextPage(
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    } else {
      _nextSong();
    }
  }

  void _prevAction() {
    HapticFeedback.lightImpact();
    if (_currentPage > 1) {
      _pdfController?.previousPage(
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    } else {
      _prevSong();
    }
  }

  void _nextSong() {
    if (_currentSongIndex < _items.length - 1) {
      HapticFeedback.mediumImpact();
      _loadSong(_currentSongIndex + 1);
    }
  }

  void _prevSong() {
    if (_currentSongIndex > 0) {
      HapticFeedback.mediumImpact();
      _loadSong(_currentSongIndex - 1, fromEnd: true);
    }
  }

  void _toggleAppBar() => setState(() => _appBarVisible = !_appBarVisible);

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    final song = _items[_currentSongIndex].song!;
    ref.read(songRepositoryProvider).updateLastPage(song.id!, page);
  }

  String get _appBarTitle {
    if (_items.isEmpty) return 'Performance';
    final song = _items[_currentSongIndex].song!;
    return '${_currentSongIndex + 1}/${_items.length}  ${song.title}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // HUD sempre nel widget tree — usa AnimatedOpacity invece di rimuoverlo
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedOpacity(
          opacity: _appBarVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_appBarVisible,
            child: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_appBarTitle,
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (_totalPages > 0)
                    Text('$_currentPage / $_totalPages',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70)),
                ],
              ),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.music_note,
                        color: _metronomeVisible
                            ? (_metronome.isRunning && _metronomeBeat
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.7))
                            : Colors.white70,
                      ),
                      tooltip: 'Metronomo',
                      onPressed: () => setState(
                          () => _metronomeVisible = !_metronomeVisible),
                    ),
                    if (_metronome.isRunning)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          width: _metronomeBeat ? 8 : 6,
                          height: _metronomeBeat ? 8 : 6,
                          decoration: BoxDecoration(
                            color: _metronomeBeat
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white54,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Torna indietro',
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    }
    if (_pdfController == null) return const SizedBox.shrink();

    final song = _items[_currentSongIndex].song!;

    return Stack(
      children: [
        PdfView(
          controller: _pdfController!,
          onPageChanged: _onPageChanged,
          scrollDirection: Axis.horizontal,
          pageSnapping: true,
        ),

        // Annotation overlay — read-only, no input capture
        DrawingLayer(
          songId: song.id!,
          pageNumber: _currentPage,
          isActive: false,
          toolState: const DrawingToolState(),
        ),

        // Left edge — previous page / previous song
        Positioned(
          left: 0, top: 0, bottom: 0,
          child: GestureDetector(
            onTap: () async {
              setState(() => _leftFlash = true);
              await Future.delayed(const Duration(milliseconds: 120));
              if (mounted) setState(() => _leftFlash = false);
              _prevAction();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: MediaQuery.of(context).size.width * 0.25,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _leftFlash
                      ? [Colors.white.withOpacity(0.15), Colors.transparent]
                      : [Colors.transparent, Colors.transparent],
                ),
              ),
            ),
          ),
        ),

        // Right edge — next page / next song
        Positioned(
          right: 0, top: 0, bottom: 0,
          child: GestureDetector(
            onTap: () async {
              setState(() => _rightFlash = true);
              await Future.delayed(const Duration(milliseconds: 120));
              if (mounted) setState(() => _rightFlash = false);
              _nextAction();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: MediaQuery.of(context).size.width * 0.25,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: _rightFlash
                      ? [Colors.white.withOpacity(0.15), Colors.transparent]
                      : [Colors.transparent, Colors.transparent],
                ),
              ),
            ),
          ),
        ),

        // Center — toggle AppBar
        Positioned.fill(
          left: MediaQuery.of(context).size.width * 0.25,
          right: MediaQuery.of(context).size.width * 0.25,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleAppBar,
          ),
        ),

        // Metronome bar
        if (_metronomeVisible && _appBarVisible)
          Positioned(
            bottom: _items.length > 1 ? 40 : 20,
            left: 0,
            right: 0,
            child: _buildMetronomeBar(context),
          ),

        // Song indicator + swipe zone to change song
        if (_items.length > 1)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v < -300) _nextSong();   // swipe left → next song
                if (v > 300) _prevSong();    // swipe right → prev song
              },
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _items.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _currentSongIndex ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i == _currentSongIndex
                            ? Colors.white
                            : Colors.white38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetronomeBar(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => setState(() => _metronome.toggle()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  _metronome.isRunning ? Icons.pause : Icons.play_arrow,
                  size: 26,
                  color: _metronome.isRunning ? accent : Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _metronome.adjustBpm(-5)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.remove, size: 20, color: Colors.white70),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _metronome.tapTempo()),
              child: Container(
                width: 62,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_metronome.bpm}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _metronome.isRunning && _metronomeBeat
                            ? accent
                            : Colors.white,
                      ),
                    ),
                    Text(
                      'BPM',
                      style: TextStyle(
                          fontSize: 9, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _metronome.adjustBpm(5)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.add, size: 20, color: Colors.white70),
              ),
            ),
            Container(
              width: 1,
              height: 22,
              color: Colors.white24,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            GestureDetector(
              onTap: () => setState(() => _metronome.tapTempo()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'TAP',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
