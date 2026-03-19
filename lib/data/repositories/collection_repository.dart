import 'package:sqflite/sqflite.dart';
import '../../domain/models/collection.dart';
import '../../domain/models/song.dart';
import '../database/database_helper.dart';

class CollectionRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Collection>> getAll() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT c.*, COUNT(sc.song_id) AS song_count
      FROM collections c
      LEFT JOIN song_collections sc ON sc.collection_id = c.id
      GROUP BY c.id
      ORDER BY c.name COLLATE NOCASE ASC
    ''');
    return rows.map(Collection.fromMap).toList();
  }

  Future<Collection?> getById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT c.*, COUNT(sc.song_id) AS song_count
      FROM collections c
      LEFT JOIN song_collections sc ON sc.collection_id = c.id
      WHERE c.id = ?
      GROUP BY c.id
    ''', [id]);
    if (rows.isEmpty) return null;
    return Collection.fromMap(rows.first);
  }

  Future<Collection> insert(Collection collection) async {
    final db = await _db;
    final id = await db.insert('collections', collection.toMap());
    return collection.copyWith(id: id);
  }

  Future<void> update(Collection collection) async {
    final db = await _db;
    await db.update(
      'collections',
      collection.toMap(),
      where: 'id = ?',
      whereArgs: [collection.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('collections', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addSong(int collectionId, int songId) async {
    final db = await _db;
    await db.insert(
      'song_collections',
      {'collection_id': collectionId, 'song_id': songId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeSong(int collectionId, int songId) async {
    final db = await _db;
    await db.delete(
      'song_collections',
      where: 'collection_id = ? AND song_id = ?',
      whereArgs: [collectionId, songId],
    );
  }

  Future<List<Song>> getSongs(int collectionId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT s.*, c.name AS composer_name
      FROM songs s
      LEFT JOIN composers c ON c.id = s.composer_id
      INNER JOIN song_collections sc ON sc.song_id = s.id
      WHERE sc.collection_id = ?
      ORDER BY s.title COLLATE NOCASE ASC
    ''', [collectionId]);
    return rows.map(Song.fromMap).toList();
  }

  Future<List<int>> getCollectionIdsForSong(int songId) async {
    final db = await _db;
    final rows = await db.query(
      'song_collections',
      columns: ['collection_id'],
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    return rows.map((r) => r['collection_id'] as int).toList();
  }
}
