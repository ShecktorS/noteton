import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/domain/models/drawing_stroke.dart';

void main() {
  group('DrawingPoint', () {
    test('fromMap / toMap round-trip', () {
      const p = DrawingPoint(x: 0.25, y: 0.75, p: 0.8);
      final p2 = DrawingPoint.fromMap(p.toMap());
      expect(p2.x, p.x);
      expect(p2.y, p.y);
      expect(p2.p, p.p);
    });

    test('coordinates stay in [0,1] range', () {
      const p = DrawingPoint(x: 0.0, y: 1.0, p: 0.5);
      expect(p.x, inInclusiveRange(0.0, 1.0));
      expect(p.y, inInclusiveRange(0.0, 1.0));
      expect(p.p, inInclusiveRange(0.0, 1.0));
    });
  });

  group('DrawingStroke', () {
    final stroke = DrawingStroke(
      id: 'test-id',
      tool: DrawingTool.pen,
      color: '#FF0000',
      opacity: 1.0,
      size: 4.0,
      points: const [
        DrawingPoint(x: 0.1, y: 0.2, p: 0.5),
        DrawingPoint(x: 0.3, y: 0.4, p: 0.7),
      ],
    );

    test('fromMap / toMap round-trip preserves all fields', () {
      final s2 = DrawingStroke.fromMap(stroke.toMap());
      expect(s2.id, stroke.id);
      expect(s2.tool, stroke.tool);
      expect(s2.color, stroke.color);
      expect(s2.opacity, stroke.opacity);
      expect(s2.size, stroke.size);
      expect(s2.points.length, stroke.points.length);
      expect(s2.points.first.x, stroke.points.first.x);
    });

    test('parsedColor converts hex to Color correctly', () {
      expect(stroke.parsedColor, const Color(0xFFFF0000));
    });

    test('parsedColor handles lowercase hex', () {
      final s = DrawingStroke(
        id: 'x',
        tool: DrawingTool.pen,
        color: '#1e88e5',
        opacity: 1.0,
        size: 4.0,
        points: const [],
      );
      expect(s.parsedColor, const Color(0xFF1E88E5));
    });

    test('copyWith only replaces points', () {
      final updated = stroke.copyWith(
        points: const [DrawingPoint(x: 0.9, y: 0.9, p: 1.0)],
      );
      expect(updated.id, stroke.id);
      expect(updated.color, stroke.color);
      expect(updated.points.length, 1);
      expect(updated.points.first.x, 0.9);
    });

    test('unknown tool defaults to pen on fromMap', () {
      final map = stroke.toMap()..['tool'] = 'nonexistent_tool';
      final s2 = DrawingStroke.fromMap(map);
      expect(s2.tool, DrawingTool.pen);
    });
  });

  group('PageAnnotations', () {
    final strokes = [
      DrawingStroke(
        id: 'a',
        tool: DrawingTool.pen,
        color: '#000000',
        opacity: 1.0,
        size: 4.0,
        points: const [DrawingPoint(x: 0.5, y: 0.5, p: 0.6)],
      ),
      DrawingStroke(
        id: 'b',
        tool: DrawingTool.highlighter,
        color: '#FFD600',
        opacity: 0.4,
        size: 14.0,
        points: const [DrawingPoint(x: 0.1, y: 0.9, p: 0.5)],
      ),
    ];

    test('fromJson(toJson()) round-trip', () {
      final original = PageAnnotations(strokes: strokes);
      final json = original.toJson();
      final restored = PageAnnotations.fromJson(json);

      expect(restored.version, original.version);
      expect(restored.strokes.length, 2);
      expect(restored.strokes[0].id, 'a');
      expect(restored.strokes[1].tool, DrawingTool.highlighter);
      expect(restored.strokes[1].opacity, 0.4);
    });

    test('empty() has no strokes', () {
      final empty = PageAnnotations.empty();
      expect(empty.strokes, isEmpty);
    });

    test('toJson includes version field', () {
      final json = PageAnnotations(strokes: const []).toJson();
      expect(json, contains('"version"'));
      expect(json, contains('"strokes"'));
    });

    test('fromJson handles empty strokes list', () {
      const json = '{"version":1,"strokes":[]}';
      final pa = PageAnnotations.fromJson(json);
      expect(pa.strokes, isEmpty);
    });
  });

  group('DrawingToolState', () {
    test('copyWith only replaces specified fields', () {
      const state = DrawingToolState(
        tool: DrawingTool.pen,
        color: Colors.black,
        size: 4.0,
      );
      final updated = state.copyWith(tool: DrawingTool.eraser);
      expect(updated.tool, DrawingTool.eraser);
      expect(updated.color, Colors.black);
      expect(updated.size, 4.0);
    });
  });
}
