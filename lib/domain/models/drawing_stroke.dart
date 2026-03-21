import 'dart:convert';
import 'package:flutter/material.dart';

// ── Tool enum ────────────────────────────────────────────────────────────────

enum DrawingTool { pen, highlighter, eraser }

// ── Single point ─────────────────────────────────────────────────────────────

class DrawingPoint {
  /// Normalized [0.0–1.0] coordinates relative to DrawingLayer bounds.
  final double x;
  final double y;

  /// Pressure [0.0–1.0]. Use 0.5 for finger touch, real value for stylus.
  final double p;

  const DrawingPoint({required this.x, required this.y, required this.p});

  factory DrawingPoint.fromMap(Map<String, dynamic> m) => DrawingPoint(
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        p: (m['p'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {'x': x, 'y': y, 'p': p};
}

// ── Single stroke ─────────────────────────────────────────────────────────────

class DrawingStroke {
  final String id;
  final DrawingTool tool;

  /// Hex color string e.g. "#FF0000"
  final String color;

  /// Opacity [0.0–1.0]. Highlighter uses ~0.4, pen uses 1.0.
  final double opacity;

  /// Base stroke size in logical pixels.
  final double size;

  final List<DrawingPoint> points;

  const DrawingStroke({
    required this.id,
    required this.tool,
    required this.color,
    required this.opacity,
    required this.size,
    required this.points,
  });

  Color get parsedColor {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  DrawingStroke copyWith({List<DrawingPoint>? points}) => DrawingStroke(
        id: id,
        tool: tool,
        color: color,
        opacity: opacity,
        size: size,
        points: points ?? this.points,
      );

  factory DrawingStroke.fromMap(Map<String, dynamic> m) => DrawingStroke(
        id: m['id'] as String,
        tool: DrawingTool.values.firstWhere(
          (t) => t.name == m['tool'],
          orElse: () => DrawingTool.pen,
        ),
        color: m['color'] as String,
        opacity: (m['opacity'] as num).toDouble(),
        size: (m['size'] as num).toDouble(),
        points: (m['points'] as List)
            .map((p) => DrawingPoint.fromMap(p as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'tool': tool.name,
        'color': color,
        'opacity': opacity,
        'size': size,
        'points': points.map((p) => p.toMap()).toList(),
      };
}

// ── Per-page annotations ──────────────────────────────────────────────────────

class PageAnnotations {
  static const int currentVersion = 1;

  final int version;
  final List<DrawingStroke> strokes;

  const PageAnnotations({
    this.version = currentVersion,
    required this.strokes,
  });

  static PageAnnotations empty() =>
      const PageAnnotations(strokes: []);

  factory PageAnnotations.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return PageAnnotations(
      version: map['version'] as int? ?? 1,
      strokes: (map['strokes'] as List)
          .map((s) => DrawingStroke.fromMap(s as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJson() => jsonEncode({
        'version': version,
        'strokes': strokes.map((s) => s.toMap()).toList(),
      });
}

// ── Toolbar state ─────────────────────────────────────────────────────────────

class DrawingToolState {
  final DrawingTool tool;
  final Color color;
  final double size;

  const DrawingToolState({
    this.tool = DrawingTool.pen,
    this.color = Colors.black,
    this.size = 4.0,
  });

  DrawingToolState copyWith({
    DrawingTool? tool,
    Color? color,
    double? size,
  }) =>
      DrawingToolState(
        tool: tool ?? this.tool,
        color: color ?? this.color,
        size: size ?? this.size,
      );
}
