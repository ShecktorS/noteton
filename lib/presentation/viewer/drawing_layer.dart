import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/drawing_stroke.dart';
import '../../providers/providers.dart';

// ── Public API ────────────────────────────────────────────────────────────────

class DrawingLayer extends ConsumerStatefulWidget {
  final int songId;
  final int pageNumber;

  /// true = cattura input e permette disegno; false = sola lettura (IgnorePointer)
  final bool isActive;

  final DrawingToolState toolState;

  const DrawingLayer({
    super.key,
    required this.songId,
    required this.pageNumber,
    required this.isActive,
    required this.toolState,
  });

  @override
  ConsumerState<DrawingLayer> createState() => DrawingLayerState();
}

// ── State (public so GlobalKey can call undo/clearPage) ───────────────────────

class DrawingLayerState extends ConsumerState<DrawingLayer> {
  List<DrawingStroke> _savedStrokes = [];
  DrawingStroke? _currentStroke;
  final List<DrawingStroke> _undoStack = [];
  static const int _maxUndo = 20;
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _loadStrokes();
  }

  @override
  void didUpdateWidget(DrawingLayer old) {
    super.didUpdateWidget(old);
    if (old.pageNumber != widget.pageNumber || old.songId != widget.songId) {
      _loadStrokes();
    }
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadStrokes() async {
    setState(() {
      _savedStrokes = [];
      _currentStroke = null;
      _undoStack.clear();
    });
    final data = await ref
        .read(annotationRepositoryProvider)
        .getPage(widget.songId, widget.pageNumber);
    if (mounted) {
      setState(() => _savedStrokes = data?.strokes ?? []);
    }
  }

  Future<void> _persist() async {
    final data = PageAnnotations(strokes: _savedStrokes);
    await ref
        .read(annotationRepositoryProvider)
        .savePage(widget.songId, widget.pageNumber, data);
  }

  // ── Public commands ───────────────────────────────────────────────────────

  void undo() {
    if (_savedStrokes.isEmpty) return;
    final last = _savedStrokes.last;
    setState(() {
      _savedStrokes = _savedStrokes.sublist(0, _savedStrokes.length - 1);
      _undoStack.add(last);
      if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    });
    _persist();
  }

  void clearPage() {
    setState(() {
      _savedStrokes = [];
      _undoStack.clear();
      _currentStroke = null;
    });
    _persist();
  }

  bool get hasStrokes => _savedStrokes.isNotEmpty;

  // ── Input handling ────────────────────────────────────────────────────────

  DrawingPoint _toNormalized(Offset local, double pressure) {
    final size = context.size ?? const Size(1, 1);
    return DrawingPoint(
      x: (local.dx / size.width).clamp(0.0, 1.0),
      y: (local.dy / size.height).clamp(0.0, 1.0),
      p: pressure.clamp(0.0, 1.0),
    );
  }

  String _colorToHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}';

  void _onPointerDown(PointerDownEvent e) {
    final isStylus = e.kind == PointerDeviceKind.stylus ||
        e.kind == PointerDeviceKind.invertedStylus;
    final isEraser = e.kind == PointerDeviceKind.invertedStylus ||
        widget.toolState.tool == DrawingTool.eraser;
    final pressure = isStylus ? e.pressure : 0.5;

    final tool = isEraser ? DrawingTool.eraser : widget.toolState.tool;
    final color = _colorToHex(widget.toolState.color);
    final opacity = tool == DrawingTool.highlighter ? 0.4 : 1.0;
    final size = tool == DrawingTool.highlighter
        ? widget.toolState.size * 3.5
        : widget.toolState.size;

    setState(() {
      _currentStroke = DrawingStroke(
        id: _uuid.v4(),
        tool: tool,
        color: color,
        opacity: opacity,
        size: size,
        points: [_toNormalized(e.localPosition, pressure)],
      );
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_currentStroke == null) return;
    final isStylus = e.kind == PointerDeviceKind.stylus ||
        e.kind == PointerDeviceKind.invertedStylus;
    final pressure = isStylus ? e.pressure : 0.5;

    setState(() {
      _currentStroke = _currentStroke!.copyWith(
        points: [
          ..._currentStroke!.points,
          _toNormalized(e.localPosition, pressure),
        ],
      );
    });
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_currentStroke == null) return;
    final stroke = _currentStroke!;
    setState(() => _currentStroke = null);

    if (stroke.points.isEmpty) return;

    if (stroke.tool == DrawingTool.eraser) {
      _applyEraser(stroke);
    } else {
      setState(() {
        _savedStrokes = [..._savedStrokes, stroke];
        _undoStack.clear(); // new stroke clears redo
      });
    }
    _persist();
  }

  void _applyEraser(DrawingStroke eraser) {
    const threshold = 0.04; // 4% of widget size
    setState(() {
      _savedStrokes = _savedStrokes.where((stroke) {
        for (final ep in eraser.points) {
          for (final sp in stroke.points) {
            final dx = ep.x - sp.x;
            final dy = ep.y - sp.y;
            if (dx * dx + dy * dy < threshold * threshold) return false;
          }
        }
        return true;
      }).toList();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final painter = _AnnotationPainter(
      savedStrokes: _savedStrokes,
      currentStroke: _currentStroke,
    );

    if (!widget.isActive) {
      return IgnorePointer(
        child: CustomPaint(painter: painter, size: Size.infinite),
      );
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: CustomPaint(painter: painter, size: Size.infinite),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _AnnotationPainter extends CustomPainter {
  final List<DrawingStroke> savedStrokes;
  final DrawingStroke? currentStroke;

  const _AnnotationPainter({
    required this.savedStrokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final all = [
      ...savedStrokes,
      if (currentStroke != null) currentStroke!,
    ];
    for (final stroke in all) {
      _paintStroke(canvas, size, stroke, isComplete: stroke != currentStroke);
    }
  }

  void _paintStroke(
      Canvas canvas, Size size, DrawingStroke stroke,
      {required bool isComplete}) {
    if (stroke.points.isEmpty) return;

    // Denormalize points
    final inputPoints = stroke.points
        .map((p) => PointVector(p.x * size.width, p.y * size.height, p.p))
        .toList();

    final outlinePoints = getStroke(
      inputPoints,
      options: StrokeOptions(
        size: stroke.size,
        thinning: stroke.tool == DrawingTool.highlighter ? 0.0 : 0.5,
        smoothing: 0.5,
        streamline: 0.4,
        isComplete: isComplete,
      ),
    );

    if (outlinePoints.isEmpty) return;

    final path = Path();
    path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
    for (final pt in outlinePoints.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }
    path.close();

    final paint = Paint()
      ..color = stroke.parsedColor.withOpacity(stroke.opacity)
      ..style = PaintingStyle.fill
      ..blendMode = stroke.tool == DrawingTool.highlighter
          ? BlendMode.multiply
          : BlendMode.srcOver;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) =>
      old.savedStrokes != savedStrokes || old.currentStroke != currentStroke;
}
