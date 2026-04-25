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

  /// Cerca compositori il cui nome inizia con [prefix] (case-insensitive).
  /// Usato dall'autocomplete: richiamato a ogni keystroke ≥ 2 caratteri.
  Future<List<Composer>> findByPrefix(String prefix, {int limit = 8}) async {
    if (prefix.isEmpty) return const [];
    final db = await _db;
    final rows = await db.query(
      'composers',
      where: 'LOWER(name) LIKE ?',
      whereArgs: ['${prefix.toLowerCase()}%'],
      orderBy: 'name ASC',
      limit: limit,
    );
    return rows.map(Composer.fromMap).toList();
  }

  Future<Composer> findOrCreate(String name) async {
    final existing = await findByName(name);
    if (existing != null) return existing;
    return insert(Composer(name: name));
  }
}
