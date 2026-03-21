import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:noteton/data/database/database_helper.dart';

/// Call once per test file in setUpAll.
void initTestDatabase() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
}

/// Creates a fresh in-memory database with the full Noteton schema.
/// Inject it into DatabaseHelper.instance.setTestDatabase(db) in setUp.
Future<Database> openTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 4,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE composers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            born_year INTEGER,
            died_year INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE songs (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            title          TEXT NOT NULL,
            composer_id    INTEGER,
            file_path      TEXT NOT NULL,
            total_pages    INTEGER NOT NULL DEFAULT 0,
            last_page      INTEGER NOT NULL DEFAULT 0,
            created_at     TEXT NOT NULL,
            updated_at     TEXT NOT NULL,
            status         TEXT NOT NULL DEFAULT 'none',
            key_signature  TEXT,
            bpm            INTEGER,
            instrument     TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE annotations (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            song_id         INTEGER NOT NULL,
            page_number     INTEGER NOT NULL,
            annotation_data TEXT NOT NULL,
            created_at      TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE setlists (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            title            TEXT NOT NULL,
            description      TEXT,
            created_at       TEXT NOT NULL,
            performance_date TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE setlist_items (
            id                INTEGER PRIMARY KEY AUTOINCREMENT,
            setlist_id        INTEGER NOT NULL,
            song_id           INTEGER NOT NULL,
            position          INTEGER NOT NULL,
            custom_start_page INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE collections (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT NOT NULL,
            description TEXT,
            color       TEXT NOT NULL DEFAULT '#2196F3',
            created_at  TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE song_collections (
            collection_id INTEGER NOT NULL,
            song_id       INTEGER NOT NULL,
            PRIMARY KEY (collection_id, song_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE tags (
            id    INTEGER PRIMARY KEY AUTOINCREMENT,
            name  TEXT NOT NULL UNIQUE,
            color TEXT NOT NULL DEFAULT '#607D8B'
          )
        ''');
        await db.execute('''
          CREATE TABLE song_tags (
            song_id INTEGER NOT NULL,
            tag_id  INTEGER NOT NULL,
            PRIMARY KEY (song_id, tag_id)
          )
        ''');
      },
    ),
  );
  DatabaseHelper.instance.setTestDatabase(db);
  return db;
}
