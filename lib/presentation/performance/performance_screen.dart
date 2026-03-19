import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';

import '../../domain/models/setlist_item.dart';
import '../../providers/providers.dart';

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

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadSetlist();
  }

  @override
  void dispose() {
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

    final song = _items[index].song!;
    final initialPage = fromEnd && song.totalPages > 0
        ? song.totalPages
        : (song.lastPage > 0 ? song.lastPage : 1);

    final controller = PdfController(
      document: PdfDocument.openFile(song.filePath),
      initialPage: initialPage,
    );

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
    } else if (_currentSongIndex < _items.length - 1) {
      _loadSong(_currentSongIndex + 1);
    }
  }

  void _prevAction() {
    HapticFeedback.lightImpact();
    if (_currentPage > 1) {
      _pdfController?.previousPage(
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    } else if (_currentSongIndex > 0) {
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

    return Stack(
      children: [
        PdfView(
          controller: _pdfController!,
          onPageChanged: _onPageChanged,
          scrollDirection: Axis.horizontal,
          pageSnapping: true,
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

        // Song transition indicator
        if (_items.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
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
      ],
    );
  }
}
