import 'package:sqflite/sqflite.dart';
import '../../domain/models/composer.dart';
import '../database/database_helper.dart';

class ComposerRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Composer>> getAll() async {
    final db = await _db;
    final rows = await db.query('composers', orderBy: 'name ASC');
    return rows.map(Composer.fromMap).toList();
  }

  Future<Composer?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('composers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Composer.fromMap(rows.first);
  }

  Future<Composer> insert(Composer composer) async {
    final db = await _db;
    final id = await db.insert('composers', composer.toMap());
    return composer.copyWith(id: id);
  }

  Future<void> update(Composer composer) async {
    final db = await _db;
    await db.update(
      'composers',
      composer.toMap(),
      where: 'id = ?',
      whereArgs: [composer.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('composers', where: 'id = ?', whereArgs: [id]);
  }

  Future<Composer?> findByName(String name) async {
    final db = await _db;
    final rows = await db.query(
      'composers',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [name],
    );
    if (rows.isEmpty) return null;
    return Composer.fromMap(rows.first);
  }

  Future<Composer> findOrCreate(String name) async {
    final existing = await findByName(name);
    if (existing != null) return existing;
    return insert(Composer(name: name));
  }
}
