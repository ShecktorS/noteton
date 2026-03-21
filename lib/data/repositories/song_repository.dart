import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/models/song.dart';
import '../../domain/models/tag.dart';
import '../database/database_helper.dart';

class SongRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Song>> getAll({String? searchQuery}) async {
    final db = await _db;

    String sql = '''
      SELECT s.*, c.name AS composer_name
      FROM songs s
      LEFT JOIN composers c ON s.composer_id = c.id
    ''';
    final args = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      sql += ' WHERE s.title LIKE ? OR c.name LIKE ?';
      args.addAll(['%$searchQuery%', '%$searchQuery%']);
    }

    sql += ' ORDER BY s.title ASC';
    final rows = await db.rawQuery(sql, args);
    return rows.map(Song.fromMap).toList();
  }

  Future<Song?> getById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT s.*, c.name AS composer_name
      FROM songs s
      LEFT JOIN composers c ON s.composer_id = c.id
      WHERE s.id = ?
      ''',
      [id],
    );
    if (rows.isEmpty) return null;
    return Song.fromMap(rows.first);
  }

  Future<Song> insert(Song song) async {
    final db = await _db;
    final id = await db.insert('songs', song.toMap());
    return song.copyWith(id: id);
  }

  Future<void> update(Song song) async {
    final db = await _db;
    await db.update(
      'songs',
      song.toMap(),
      where: 'id = ?',
      whereArgs: [song.id],
    );
  }

  Future<List<Song>> getByComposerId(int composerId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT s.*, c.name AS composer_name
      FROM songs s
      LEFT JOIN composers c ON s.composer_id = c.id
      WHERE s.composer_id = ?
      ORDER BY s.title ASC
      ''',
      [composerId],
    );
    return rows.map(Song.fromMap).toList();
  }

  Future<void> updateLastPage(int songId, int page) async {
    final db = await _db;
    await db.update(
      'songs',
      {'last_page': page, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [songId],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    final song = await getById(id);
    await db.delete('songs', where: 'id = ?', whereArgs: [id]);
    if (song != null && !kIsWeb) {
      try {
        final file = File(song.filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  // Tags
  Future<List<Tag>> getTagsForSong(int songId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT t.* FROM tags t
      INNER JOIN song_tags st ON t.id = st.tag_id
      WHERE st.song_id = ?
      ''',
      [songId],
    );
    return rows.map(Tag.fromMap).toList();
  }

  Future<void> setTagsForSong(int songId, List<int> tagIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('song_tags', where: 'song_id = ?', whereArgs: [songId]);
      for (final tagId in tagIds) {
        await txn.insert('song_tags', {'song_id': songId, 'tag_id': tagId});
      }
    });
  }
}
