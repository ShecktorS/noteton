import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../../domain/models/drawing_stroke.dart';

class AnnotationRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<PageAnnotations?> getPage(int songId, int pageNumber) async {
    final db = await _db;
    final rows = await db.query(
      'annotations',
      columns: ['annotation_data'],
      where: 'song_id = ? AND page_number = ?',
      whereArgs: [songId, pageNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final data = rows.first['annotation_data'] as String?;
    if (data == null || data.isEmpty) return null;
    try {
      return PageAnnotations.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePage(
      int songId, int pageNumber, PageAnnotations data) async {
    final db = await _db;
    // Delete existing then insert — cleaner than INSERT OR REPLACE
    await db.delete(
      'annotations',
      where: 'song_id = ? AND page_number = ?',
      whereArgs: [songId, pageNumber],
    );
    await db.insert('annotations', {
      'song_id': songId,
      'page_number': pageNumber,
      'annotation_data': data.toJson(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deletePage(int songId, int pageNumber) async {
    final db = await _db;
    await db.delete(
      'annotations',
      where: 'song_id = ? AND page_number = ?',
      whereArgs: [songId, pageNumber],
    );
  }

  Future<void> deleteAllForSong(int songId) async {
    final db = await _db;
    await db.delete('annotations', where: 'song_id = ?', whereArgs: [songId]);
  }

  /// Returns all annotation rows as raw maps {song_id, page_number, annotation_data}.
  /// Used by backup export.
  Future<List<Map<String, dynamic>>> getAllRaw() async {
    final db = await _db;
    return db.query(
      'annotations',
      columns: ['song_id', 'page_number', 'annotation_data'],
    );
  }

  /// Inserts a raw annotation row. Used by backup import to avoid double JSON parsing.
  Future<void> saveRaw(
      int songId, int pageNumber, String annotationData) async {
    final db = await _db;
    await db.delete(
      'annotations',
      where: 'song_id = ? AND page_number = ?',
      whereArgs: [songId, pageNumber],
    );
    await db.insert('annotations', {
      'song_id': songId,
      'page_number': pageNumber,
      'annotation_data': annotationData,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
