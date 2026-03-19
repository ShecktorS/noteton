import 'package:sqflite/sqflite.dart';
import '../../domain/models/setlist.dart';
import '../../domain/models/setlist_item.dart';
import '../../domain/models/song.dart';
import '../database/database_helper.dart';

class SetlistRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Setlist>> getAll() async {
    final db = await _db;
    final rows = await db.query('setlists', orderBy: 'created_at DESC');
    return rows.map(Setlist.fromMap).toList();
  }

  Future<Setlist?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('setlists', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Setlist.fromMap(rows.first);
  }

  Future<Setlist> insert(Setlist setlist) async {
    final db = await _db;
    final id = await db.insert('setlists', setlist.toMap());
    return setlist.copyWith(id: id);
  }

  Future<void> update(Setlist setlist) async {
    final db = await _db;
    await db.update(
      'setlists',
      setlist.toMap(),
      where: 'id = ?',
      whereArgs: [setlist.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('setlists', where: 'id = ?', whereArgs: [id]);
  }

  // Items
  Future<List<SetlistItem>> getItemsForSetlist(int setlistId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT si.*, s.title, s.file_path, s.total_pages, s.last_page,
             s.composer_id, s.created_at AS song_created_at,
             s.updated_at AS song_updated_at, c.name AS composer_name
      FROM setlist_items si
      INNER JOIN songs s ON si.song_id = s.id
      LEFT JOIN composers c ON s.composer_id = c.id
      WHERE si.setlist_id = ?
      ORDER BY si.position ASC
      ''',
      [setlistId],
    );

    return rows.map((row) {
      final song = Song(
        id: row['song_id'] as int,
        title: row['title'] as String,
        composerId: row['composer_id'] as int?,
        filePath: row['file_path'] as String,
        totalPages: (row['total_pages'] as int?) ?? 0,
        lastPage: (row['last_page'] as int?) ?? 0,
        createdAt: DateTime.parse(row['song_created_at'] as String),
        updatedAt: DateTime.parse(row['song_updated_at'] as String),
        composerName: row['composer_name'] as String?,
      );
      return SetlistItem(
        id: row['id'] as int?,
        setlistId: row['setlist_id'] as int,
        songId: row['song_id'] as int,
        position: row['position'] as int,
        customStartPage: (row['custom_start_page'] as int?) ?? 0,
        song: song,
      );
    }).toList();
  }

  Future<void> addItem(SetlistItem item) async {
    final db = await _db;
    await db.insert('setlist_items', item.toMap());
  }

  Future<void> removeItem(int itemId) async {
    final db = await _db;
    await db.delete('setlist_items', where: 'id = ?', whereArgs: [itemId]);
  }

  Future<int> getItemCount(int setlistId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM setlist_items WHERE setlist_id = ?',
      [setlistId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<void> reorderItems(int setlistId, List<SetlistItem> items) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (int i = 0; i < items.length; i++) {
        await txn.update(
          'setlist_items',
          {'position': i},
          where: 'id = ?',
          whereArgs: [items[i].id],
        );
      }
    });
  }
}
