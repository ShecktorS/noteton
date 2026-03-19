import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = 'noteton.db';
  static const _databaseVersion = 1;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    String path;
    try {
      final dbPath = await getDatabasesPath();
      path = join(dbPath ?? '.', _databaseName);
    } catch (_) {
      path = _databaseName;
    }
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE composers (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        name      TEXT NOT NULL,
        born_year INTEGER,
        died_year INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE songs (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        title        TEXT NOT NULL,
        composer_id  INTEGER REFERENCES composers(id) ON DELETE SET NULL,
        file_path    TEXT NOT NULL,
        total_pages  INTEGER NOT NULL DEFAULT 0,
        last_page    INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL
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
        song_id INTEGER NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
        tag_id  INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        PRIMARY KEY (song_id, tag_id)
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
        setlist_id        INTEGER NOT NULL REFERENCES setlists(id) ON DELETE CASCADE,
        song_id           INTEGER NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
        position          INTEGER NOT NULL,
        custom_start_page INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE annotations (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id         INTEGER NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
        page_number     INTEGER NOT NULL,
        annotation_data TEXT NOT NULL,
        created_at      TEXT NOT NULL
      )
    ''');

    // Indexes for common queries
    await db.execute('CREATE INDEX idx_songs_composer ON songs(composer_id)');
    await db.execute('CREATE INDEX idx_song_tags_song ON song_tags(song_id)');
    await db.execute('CREATE INDEX idx_setlist_items_setlist ON setlist_items(setlist_id)');
    await db.execute('CREATE INDEX idx_annotations_song ON annotations(song_id, page_number)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
  }
}
