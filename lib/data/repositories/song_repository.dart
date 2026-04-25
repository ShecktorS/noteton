import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/utils/song_path.dart';
import '../../domain/models/song.dart';
import '../../domain/models/tag.dart';
import '../database/database_helper.dart';

class SongRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Song>> getAll({String? searchQuery, int? tagId}) async {
    final db = await _db;

    String sql = '''
      SELECT s.*, c.name AS composer_name
      FROM songs s
      LEFT JOIN composers c ON s.composer_id = c.id
    ''';
    final args = <dynamic>[];
    final conditions = <String>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add(
          '(s.title LIKE ? OR c.name LIKE ? OR s.key_signature LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }

    if (tagId != null) {
      conditions.add(
          's.id IN (SELECT song_id FROM song_tags WHERE tag_id = ?)');
      args.add(tagId);
    }

    if (conditions.isNotEmpty) {
      sql += ' WHERE ${conditions.join(' AND ')}';
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

  /// Cancella un brano in modo atomico rispetto al filesystem.
  ///
  /// Sequenza:
  /// 1. risolvi path del PDF
  /// 2. **rinomina** il PDF in `<path>.tombstone` (rename è atomico sullo
  ///    stesso filesystem — Android ext4, non fallisce a metà)
  /// 3. esegui `DELETE` sul DB
  /// 4. cancella il tombstone (fire-and-forget)
  ///
  /// Se il passo 3 fallisce, ripristiniamo il nome originale del file in
  /// modo che lo stato utente resti coerente (PDF presente + riga DB).
  Future<void> delete(int id) async {
    final db = await _db;
    final song = await getById(id);

    File? pdfFile;
    File? tombstone;

    if (song != null && !kIsWeb) {
      try {
        final resolved = await SongPath.resolveDetailed(song.filePath);
        if (resolved.exists) {
          pdfFile = File(resolved.path);
          tombstone = File('${resolved.path}.tombstone');
          await pdfFile.rename(tombstone.path);
        }
      } catch (_) {
        // Se la rename fallisce procediamo comunque con la delete DB —
        // lasceremo un file orfano che il health check potrà ripulire.
        tombstone = null;
      }
    }

    try {
      await db.delete('songs', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      // Rollback: ripristina il PDF al nome originale, se esiste il tombstone.
      if (tombstone != null && pdfFile != null) {
        try {
          if (await tombstone.exists()) {
            await tombstone.rename(pdfFile.path);
          }
        } catch (_) {}
      }
      rethrow;
    }

    // DB OK → elimina definitivamente il tombstone (best-effort).
    if (tombstone != null) {
      try {
        if (await tombstone.exists()) await tombstone.delete();
      } catch (_) {}
    }
  }

  /// Returns the song whose PDF has the given SHA-256 hash, or null.
  Future<Song?> getByHash(String hash) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT s.*, c.name AS composer_name
      FROM songs s
      LEFT JOIN composers c ON s.composer_id = c.id
      WHERE s.file_hash = ?
      LIMIT 1
      ''',
      [hash],
    );
    if (rows.isEmpty) return null;
    return Song.fromMap(rows.first);
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
