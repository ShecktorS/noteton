import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/utils/song_path.dart';

/// Thumbnail di un PDF. [size] è la dimensione del widget quadrato visualizzato.
/// [renderWidth] e [renderHeight] sono le dimensioni di rendering (qualità).
/// Se [renderWidth]/[renderHeight] non specificati, usa valori adeguati alla [size].
class PdfThumbnail extends StatefulWidget {
  final String filePath;
  final double size;
  final double? renderWidth;
  final double? renderHeight;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const PdfThumbnail({
    super.key,
    required this.filePath,
    this.size = 48,
    this.renderWidth,
    this.renderHeight,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  State<PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<PdfThumbnail> {
  Uint8List? _bytes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PdfThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      setState(() {
        _bytes = null;
        _loaded = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    if (kIsWeb) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    PdfDocument? doc;
    PdfPage? page;
    try {
      final resolved = await SongPath.resolveDetailed(widget.filePath);
      if (!resolved.exists) {
        if (mounted) setState(() => _loaded = true);
        return;
      }
      doc = await PdfDocument.openFile(resolved.path);
      page = await doc.getPage(1);
      final rw = widget.renderWidth ?? (widget.size * 2);
      final rh = widget.renderHeight ?? (widget.size * 2.5);
      final image = await page.render(
        width: rw,
        height: rh,
        format: PdfPageImageFormat.jpeg,
      );
      if (mounted) setState(() { _bytes = image?.bytes; _loaded = true; });
    } catch (e) {
      debugPrint('PdfThumbnail: failed to render ${widget.filePath}: $e');
      if (mounted) setState(() => _loaded = true);
    } finally {
      await page?.close();
      await doc?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(6);
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;

    if (!_loaded) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Center(
          child: SizedBox(
            width: widget.size * 0.33,
            height: widget.size * 0.33,
            child: const CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    if (_bytes == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Icon(
          Icons.picture_as_pdf,
          size: widget.size * 0.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: widget.fit,
      ),
    );
  }
}

/// Versione expanded che riempie tutto lo spazio disponibile (per grid card).
class PdfThumbnailExpanded extends StatefulWidget {
  final String filePath;

  const PdfThumbnailExpanded({super.key, required this.filePath});

  @override
  State<PdfThumbnailExpanded> createState() => _PdfThumbnailExpandedState();
}

class _PdfThumbnailExpandedState extends State<PdfThumbnailExpanded> {
  Uint8List? _bytes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PdfThumbnailExpanded oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      setState(() { _bytes = null; _loaded = false; });
      _load();
    }
  }

  Future<void> _load() async {
    if (kIsWeb) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    PdfDocument? doc;
    PdfPage? page;
    try {
      final resolved = await SongPath.resolveDetailed(widget.filePath);
      if (!resolved.exists) {
        if (mounted) setState(() => _loaded = true);
        return;
      }
      doc = await PdfDocument.openFile(resolved.path);
      page = await doc.getPage(1);
      final image = await page.render(
        width: page.width / 2,
        height: page.height / 2,
        format: PdfPageImageFormat.jpeg,
      );
      if (mounted) setState(() { _bytes = image?.bytes; _loaded = true; });
    } catch (e) {
      debugPrint('PdfThumbnailExpanded: failed to render ${widget.filePath}: $e');
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
