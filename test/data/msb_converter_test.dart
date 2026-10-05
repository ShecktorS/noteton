import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/data/converters/msb_converter.dart';
import 'package:noteton/data/repositories/backup_repository.dart';
import 'package:noteton/data/repositories/msb_import_repository.dart';
import 'package:noteton/data/repositories/setlist_repository.dart';
import 'package:noteton/data/repositories/song_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_path_provider.dart';
import '../helpers/test_database.dart';

/// PDF finto più lungo di 4 KiB: il converter cerca l'ultimo `%%EOF` fino
/// a 4 KiB oltre `FileSize`, quindi brani più corti finirebbero per
/// inglobare il PDF successivo (non succede con spartiti reali).
List<int> _samplePdf(String title) => utf8
    .encode('%PDF-1.7\n${'contenuto $title '.padRight(5000, '.')}\n%%EOF\n');

/// Brano da mettere nel finto backup MobileSheets.
class MsbSong {
  final int id;
  final String title;
  final String? composer;
  final String? artist;
  final String? key;
  final String? genre;
  final int? tempo;
  final String path;

  /// PDF vero e proprio, terminato da `%%EOF`.
  final List<int> pdf;

  /// Byte che MobileSheets accoda al PDF (annotazioni): fanno parte del
  /// `FileSize` ma non devono finire nel PDF estratto.
  final List<int> trailer;

  /// Se false il brano compare nel DB ma i suoi byte non sono nel blob
  /// (file "collegato" esternamente).
  final bool embedded;

  MsbSong({
    required this.id,
    required this.title,
    this.composer,
    this.artist,
    this.key,
    this.genre,
    this.tempo,
    String? path,
    List<int>? pdf,
    this.trailer = const [],
    this.embedded = true,
  })  : path = path ?? '/storage/MobileSheets/$title.pdf',
        pdf = pdf ?? _samplePdf(title);

  int get fileSize => pdf.length + trailer.length;
}

/// Costruisce un `.msb` sintetico con la stessa struttura di quelli reali:
/// intestazione opaca, database SQLite, poi i file dei brani uno dopo
/// l'altro, ciascuno lungo esattamente `FileSize` byte.
Future<String> buildMsb(
  String dir,
  List<MsbSong> songs, {
  Map<String, List<int>> setlists = const {},
  Map<String, List<int>> collections = const {},
}) async {
  final dbPath = p.join(dir, 'ms_${DateTime.now().microsecondsSinceEpoch}.db');
  final db = await databaseFactoryFfi.openDatabase(dbPath);
  await db.execute('PRAGMA journal_mode = DELETE');
  for (final ddl in [
    'CREATE TABLE Songs (Id INTEGER PRIMARY KEY, Title TEXT, LastPage INTEGER, CreationDate INTEGER, LastModified INTEGER)',
    'CREATE TABLE Files (Id INTEGER PRIMARY KEY, SongId INTEGER, Path TEXT, FileSize INTEGER, SourceFilePageCount INTEGER)',
    'CREATE TABLE Composer (Id INTEGER PRIMARY KEY, Name TEXT)',
    'CREATE TABLE ComposerSongs (Id INTEGER PRIMARY KEY, ComposerId INTEGER, SongId INTEGER)',
    'CREATE TABLE Artists (Id INTEGER PRIMARY KEY, Name TEXT)',
    'CREATE TABLE ArtistsSongs (Id INTEGER PRIMARY KEY, ArtistId INTEGER, SongId INTEGER)',
    'CREATE TABLE Key (Id INTEGER PRIMARY KEY, Name TEXT)',
    'CREATE TABLE KeySongs (Id INTEGER PRIMARY KEY, KeyId INTEGER, SongId INTEGER)',
    'CREATE TABLE Genres (Id INTEGER PRIMARY KEY, Type TEXT)',
    'CREATE TABLE GenresSongs (Id INTEGER PRIMARY KEY, GenreId INTEGER, SongId INTEGER)',
    'CREATE TABLE Tempos (Id INTEGER PRIMARY KEY, SongId INTEGER, Tempo INTEGER, TempoIndex INTEGER)',
    'CREATE TABLE Setlists (Id INTEGER PRIMARY KEY, Name TEXT)',
    'CREATE TABLE SetlistSong (Id INTEGER PRIMARY KEY, SetlistId INTEGER, SongId INTEGER)',
    'CREATE TABLE Collections (Id INTEGER PRIMARY KEY, Name TEXT)',
    'CREATE TABLE CollectionSong (Id INTEGER PRIMARY KEY, CollectionId INTEGER, SongId INTEGER)',
  ]) {
    await db.execute(ddl);
  }

  for (final s in songs) {
    await db.insert('Songs', {
      'Id': s.id,
      'Title': s.title,
      'LastPage': 1,
      'CreationDate': 1700000000000,
      'LastModified': 1700000500000,
    });
    await db.insert('Files', {
      'SongId': s.id,
      'Path': s.path,
      'FileSize': s.fileSize,
      'SourceFilePageCount': 3,
    });
    if (s.composer != null) {
      final cid = await db.insert('Composer', {'Name': s.composer});
      await db.insert('ComposerSongs', {'ComposerId': cid, 'SongId': s.id});
    }
    if (s.artist != null) {
      final aid = await db.insert('Artists', {'Name': s.artist});
      await db.insert('ArtistsSongs', {'ArtistId': aid, 'SongId': s.id});
    }
    if (s.key != null) {
      final kid = await db.insert('Key', {'Name': s.key});
      await db.insert('KeySongs', {'KeyId': kid, 'SongId': s.id});
    }
    if (s.genre != null) {
      final gid = await db.insert('Genres', {'Type': s.genre});
      await db.insert('GenresSongs', {'GenreId': gid, 'SongId': s.id});
    }
    if (s.tempo != null) {
      await db.insert(
          'Tempos', {'SongId': s.id, 'Tempo': s.tempo, 'TempoIndex': 0});
    }
  }
  for (final entry in setlists.entries) {
    final id = await db.insert('Setlists', {'Name': entry.key});
    for (final songId in entry.value) {
      await db.insert('SetlistSong', {'SetlistId': id, 'SongId': songId});
    }
  }
  for (final entry in collections.entries) {
    final id = await db.insert('Collections', {'Name': entry.key});
    for (final songId in entry.value) {
      await db.insert('CollectionSong', {'CollectionId': id, 'SongId': songId});
    }
  }
  await db.close();

  final blob = BytesBuilder()
    ..add(utf8.encode('MSB-HEADER-OPACO'))
    ..add(await File(dbPath).readAsBytes());
  for (final s in songs.where((s) => s.embedded)) {
    blob
      ..add(s.pdf)
      ..add(s.trailer);
  }
  final msbPath = p.join(dir, 'backup_ms.msb');
  await File(msbPath).writeAsBytes(blob.toBytes());
  return msbPath;
}

/// Legge il `backup.json` dal `.ntb` prodotto dalla conversione.
({Map<String, dynamic> json, Archive archive}) readNtb(String path) {
  final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
  final json = jsonDecode(
          utf8.decode(archive.findFile('backup.json')!.content as List<int>))
      as Map<String, dynamic>;
  return (json: json, archive: archive);
}

void main() {
  initTestDatabase();

  late FakePathProvider paths;

  setUp(() async {
    paths = await installFakePathProvider();
    await openTestDatabase();
  });

  group('convertMsb', () {
    test('estrae brani, metadati, setlist e raccolte', () async {
      final songs = [
        MsbSong(
          id: 10,
          title: 'Notturno',
          composer: 'Chopin',
          artist: 'Ignorato',
          key: 'C# minor',
          genre: 'Romantico',
          tempo: 60,
          trailer: utf8.encode('annotazioni-ms'),
        ),
        MsbSong(id: 11, title: 'Imagine', artist: 'Lennon', key: 'C major'),
        MsbSong(id: 12, title: 'Bossa', key: 'Bb'),
      ];
      final msb = await buildMsb(paths.temporaryPath, songs, setlists: {
        'Serata': [12, 10]
      }, collections: {
        'Classica': [10, 10]
      });
      final progress = <String>[];

      final result = await convertMsb(msb, onProgress: progress.add);

      expect(result.songsImported, 3);
      expect(result.setlistsImported, 1);
      expect(result.collectionsImported, 1);
      expect(result.warnings, isEmpty);
      expect(progress.last, 'Conversione completata.');
      expect(p.basename(result.ntbPath), 'backup_ms.ntb');

      final ntb = readNtb(result.ntbPath);
      expect(ntb.json['version'], 3);
      final byTitle = {
        for (final s
            in (ntb.json['songs'] as List).cast<Map<String, dynamic>>())
          s['title']: s,
      };

      final notturno = byTitle['Notturno']!;
      expect(notturno['composerName'], 'Chopin'); // Composer prima di Artist
      expect(notturno['keySignature'], 'C#m');
      expect(notturno['period'], 'Romantico');
      expect(notturno['bpm'], 60);
      expect(notturno['totalPages'], 3);
      expect(notturno['filePath'], 'Notturno.pdf');
      // Il newline dopo %%EOF non fa parte del PDF estratto.
      final extracted = songs[0].pdf.sublist(0, songs[0].pdf.length - 1);
      expect(notturno['fileHash'], sha256.convert(extracted).toString());

      expect(byTitle['Imagine']!['composerName'], 'Lennon');
      expect(byTitle['Imagine']!['keySignature'], 'C');
      expect(byTitle['Bossa']!['keySignature'], 'Bb');

      // Il PDF estratto si ferma a %%EOF: le annotazioni MS restano fuori.
      final pdf =
          ntb.archive.findFile('pdfs/Notturno.pdf')!.content as List<int>;
      expect(utf8.decode(pdf), startsWith('%PDF-1.7'));
      expect(utf8.decode(pdf), endsWith('%%EOF'));

      final setlist = (ntb.json['setlists'] as List).single as Map;
      expect(setlist['title'], 'Serata');
      expect(
        (setlist['items'] as List).map((i) => (i as Map)['songId']),
        [12, 10],
      );
      final collection = (ntb.json['collections'] as List).single as Map;
      expect(collection['songIds'], [10]); // duplicati rimossi
    });

    test('ignora un finto "%PDF-" dentro le annotazioni', () async {
      final songs = [
        MsbSong(
          id: 1,
          title: 'Primo',
          trailer: utf8.encode('rumore %PDF-xx %PDF-9.9\n fine'),
        ),
        MsbSong(id: 2, title: 'Secondo'),
      ];
      final msb = await buildMsb(paths.temporaryPath, songs);

      final result = await convertMsb(msb);

      expect(result.songsImported, 2);
      final ntb = readNtb(result.ntbPath);
      final secondo =
          ntb.archive.findFile('pdfs/Secondo.pdf')!.content as List<int>;
      expect(secondo, songs[1].pdf.sublist(0, songs[1].pdf.length - 1));
    });

    test('si ferma ai file collegati non inclusi nel backup', () async {
      final msb = await buildMsb(paths.temporaryPath, [
        MsbSong(id: 1, title: 'Incluso'),
        MsbSong(id: 2, title: 'Collegato', embedded: false),
      ], setlists: {
        'Solo collegati': [2]
      });

      final result = await convertMsb(msb);

      expect(result.songsImported, 1);
      expect(result.setlistsImported, 0);
      expect(result.warnings.single, contains('Interrotto a "Collegato"'));
      expect(readNtb(result.ntbPath).json['setlists'], isEmpty);
    });

    test('rende sicuri e univoci i nomi dei file', () async {
      final msb = await buildMsb(paths.temporaryPath, [
        MsbSong(id: 1, title: 'A', path: r'C:\Spartiti\Für Elise (v2).pdf'),
        MsbSong(id: 2, title: 'B', path: '/sd/Für Elise (v2).pdf'),
      ]);

      final result = await convertMsb(msb);

      final names = (readNtb(result.ntbPath).json['songs'] as List)
          .map((s) => (s as Map)['filePath']);
      expect(names, ['F_r_Elise_v2.pdf', 'F_r_Elise_v2_2.pdf']);
    });

    test('rifiuta un file che non contiene un database', () async {
      final path = p.join(paths.temporaryPath, 'falso.msb');
      await File(path).writeAsBytes(utf8.encode('non sono un backup'));

      await expectLater(
        convertMsb(path),
        throwsA(isA<MsbConversionException>()
            .having((e) => e.message, 'message', contains('SQLite'))),
      );
    });

    test('rifiuta un backup senza brani PDF', () async {
      final msb = await buildMsb(paths.temporaryPath, []);

      await expectLater(
        convertMsb(msb),
        throwsA(isA<MsbConversionException>()
            .having((e) => e.message, 'message', contains('Nessun brano'))),
      );
    });
  });

  group('MsbImportRepository', () {
    test('importa in libreria e cancella il .ntb temporaneo', () async {
      final msb = await buildMsb(paths.temporaryPath, [
        MsbSong(id: 1, title: 'Notturno', composer: 'Chopin'),
        MsbSong(id: 2, title: 'Valzer', composer: 'Chopin'),
      ], setlists: {
        'Concerto': [2, 1]
      });

      final outcome =
          await MsbImportRepository(BackupRepository()).importMsb(msb);

      expect(outcome.report.songsImported, 2);
      expect(outcome.report.setlistsImported, 1);
      expect(outcome.conversionWarnings, isEmpty);
      expect(
        await File(p.join(paths.temporaryPath, 'backup_ms.ntb')).exists(),
        isFalse,
      );

      final songs = await SongRepository().getAll();
      expect(songs.map((s) => s.composerName).toSet(), {'Chopin'});
      final setlist = (await SetlistRepository().getAll()).single;
      expect(setlist.title, 'Concerto');
    });

    test('reimportare lo stesso backup non duplica i brani', () async {
      final msb = await buildMsb(paths.temporaryPath, [
        MsbSong(id: 1, title: 'Unico'),
      ]);
      final importer = MsbImportRepository(BackupRepository());

      await importer.importMsb(msb);
      final second = await importer.importMsb(msb);

      expect(second.report.songsImported, 0);
      expect(second.report.songsSkippedDuplicate, 1);
      expect(await SongRepository().getAll(), hasLength(1));
    });
  });
}
