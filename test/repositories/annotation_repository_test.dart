import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/data/repositories/annotation_repository.dart';
import 'package:noteton/domain/models/drawing_stroke.dart';

import '../helpers/test_database.dart';

void main() {
  late AnnotationRepository repo;

  setUp(() async {
    await openTestDatabase();
    repo = AnnotationRepository();
  });

  group('AnnotationRepository', () {
    const songId = 1;
    const pageNumber = 3;

    PageAnnotations _sampleData() => PageAnnotations(
          strokes: [
            DrawingStroke(
              id: 'stroke-1',
              tool: DrawingTool.pen,
              color: '#000000',
              opacity: 1.0,
              size: 4.0,
              points: const [
                DrawingPoint(x: 0.1, y: 0.2, p: 0.5),
                DrawingPoint(x: 0.3, y: 0.4, p: 0.7),
              ],
            ),
          ],
        );

    test('getPage returns null when no data exists', () async {
      final result = await repo.getPage(songId, pageNumber);
      expect(result, isNull);
    });

    test('savePage then getPage returns correct data', () async {
      final data = _sampleData();
      await repo.savePage(songId, pageNumber, data);

      final result = await repo.getPage(songId, pageNumber);
      expect(result, isNotNull);
      expect(result!.strokes.length, 1);
      expect(result.strokes.first.id, 'stroke-1');
      expect(result.strokes.first.tool, DrawingTool.pen);
      expect(result.strokes.first.points.length, 2);
    });

    test('savePage overwrites previous data for same page', () async {
      await repo.savePage(songId, pageNumber, _sampleData());

      final updated = PageAnnotations(
        strokes: [
          DrawingStroke(
            id: 'stroke-new',
            tool: DrawingTool.highlighter,
            color: '#FFD600',
            opacity: 0.4,
            size: 14.0,
            points: const [DrawingPoint(x: 0.5, y: 0.5, p: 0.5)],
          ),
        ],
      );
      await repo.savePage(songId, pageNumber, updated);

      final result = await repo.getPage(songId, pageNumber);
      expect(result!.strokes.length, 1);
      expect(result.strokes.first.id, 'stroke-new');
      expect(result.strokes.first.tool, DrawingTool.highlighter);
    });

    test('different pages are stored independently', () async {
      final page1Data = PageAnnotations(
        strokes: [
          DrawingStroke(
            id: 'p1',
            tool: DrawingTool.pen,
            color: '#FF0000',
            opacity: 1.0,
            size: 4.0,
            points: const [],
          ),
        ],
      );
      final page2Data = PageAnnotations(
        strokes: [
          DrawingStroke(
            id: 'p2',
            tool: DrawingTool.highlighter,
            color: '#00FF00',
            opacity: 0.4,
            size: 14.0,
            points: const [],
          ),
        ],
      );

      await repo.savePage(songId, 1, page1Data);
      await repo.savePage(songId, 2, page2Data);

      final r1 = await repo.getPage(songId, 1);
      final r2 = await repo.getPage(songId, 2);

      expect(r1!.strokes.first.id, 'p1');
      expect(r2!.strokes.first.id, 'p2');
    });

    test('deletePage removes data for that page only', () async {
      await repo.savePage(songId, 1, _sampleData());
      await repo.savePage(songId, 2, _sampleData());

      await repo.deletePage(songId, 1);

      expect(await repo.getPage(songId, 1), isNull);
      expect(await repo.getPage(songId, 2), isNotNull);
    });

    test('savePage with empty strokes persists and returns empty list', () async {
      await repo.savePage(songId, pageNumber, PageAnnotations.empty());
      final result = await repo.getPage(songId, pageNumber);
      expect(result, isNotNull);
      expect(result!.strokes, isEmpty);
    });
  });
}
