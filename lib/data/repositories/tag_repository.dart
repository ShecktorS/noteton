import 'package:sqflite/sqflite.dart';
import '../../domain/models/tag.dart';
import '../database/database_helper.dart';

class TagRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Tag>> getAll() async {
    final db = await _db;
    final rows = await db.query('tags', orderBy: 'name ASC');
    return rows.map(Tag.fromMap).toList();
  }

  Future<Tag> insert(Tag tag) async {
    final db = await _db;
    final id = await db.insert('tags', tag.toMap());
    return tag.copyWith(id: id);
  }

  Future<void> update(Tag tag) async {
    final db = await _db;
    await db.update('tags', tag.toMap(),
        where: 'id = ?', whereArgs: [tag.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    // song_tags rows are removed via ON DELETE CASCADE
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Tag>> getTagsForSong(int songId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT t.* FROM tags t
      INNER JOIN song_tags st ON t.id = st.tag_id
      WHERE st.song_id = ?
      ORDER BY t.name ASC
      ''',
      [songId],
    );
    return rows.map(Tag.fromMap).toList();
  }

  Future<void> setTagsForSong(int songId, List<int> tagIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('song_tags',
          where: 'song_id = ?', whereArgs: [songId]);
      for (final tagId in tagIds) {
        await txn.insert('song_tags', {
          'song_id': songId,
          'tag_id': tagId,
        });
      }
    });
  }
}
