import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';

import '../../providers/providers.dart';

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

      final initialPage = song.lastPage > 0 ? song.lastPage : 1;
      final controller = PdfController(
        document: PdfDocument.openFile(song.filePath),
        initialPage: initialPage,
      );

      if (mounted) {
        setState(() {
          _title = song.title;
          _pdfController = controller;
          _currentPage = initialPage;
          _totalPages = song.totalPages;
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

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  void _toggleAppBar() => setState(() => _appBarVisible = !_appBarVisible);

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

  @override
  Widget build(BuildContext context) {
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
                      style:
                          const TextStyle(fontSize: 16, color: Colors.white)),
                  if (_totalPages > 0)
                    Text('$_currentPage / $_totalPages',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                ],
              ),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child:
              Text(_error!, style: const TextStyle(color: Colors.white)));
    }
    if (_pdfController == null) return const SizedBox.shrink();

    return Stack(
      children: [
        // PDF viewer
        PdfView(
          controller: _pdfController!,
          onPageChanged: _onPageChanged,
          scrollDirection: Axis.horizontal,
          pageSnapping: true,
        ),

        // Left edge — previous page
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

        // Right edge — next page
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.25,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _currentPage < _totalPages ? _nextPage : _toggleAppBar,
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
      ],
    );
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    ref.read(songRepositoryProvider).updateLastPage(widget.songId, page);
  }
}
