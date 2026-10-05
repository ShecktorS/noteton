import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/core/exceptions/backup_exceptions.dart';
import 'package:noteton/data/repositories/backup_repository.dart';
import 'package:noteton/data/repositories/collection_repository.dart';
import 'package:noteton/data/repositories/setlist_repository.dart';
import 'package:noteton/data/repositories/song_repository.dart';
import 'package:noteton/data/repositories/tag_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_path_provider.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_database.dart';

/// Contenuto minimo che basta a far passare i controlli sui PDF.
List<int> fakePdf(String marker) => utf8.encode('%PDF-1.4\n$marker\n%%EOF\n');

/// Scrive un `.ntb` costruito a mano: utile per i casi limite che
/// l'export non produce mai (PDF mancanti, schema rotto, versioni future).
Future<String> writeNtb(
  String dir,
  Map<String, dynamic>? backupJson, {
  Map<String, List<int>> pdfs = const {},
}) async {
  final archive = Archive();
  if (backupJson != null) {
    final bytes = utf8.encode(jsonEncode(backupJson));
    archive.addFile(ArchiveFile('backup.json', bytes.length, bytes));
  }
  pdfs.forEach((name, bytes) {
    archive.addFile(ArchiveFile('pdfs/$name', bytes.length, bytes));
  });
  final path =
      p.join(dir, 'manuale_${DateTime.now().microsecondsSinceEpoch}.ntb');
  await File(path).writeAsBytes(ZipEncoder().encode(archive)!);
  return path;
}

Map<String, dynamic> songJson(int id, String title,
        {String? filePath, String? hash, String? composerName}) =>
    {
      'id': id,
      'title': title,
      'composerName': composerName,
      'filePath': filePath ?? 'brano_$id.pdf',
      'totalPages': 2,
      'lastPage': 1,
      'status': 'none',
      'fileHash': hash,
      'createdAt': '2025-01-01T10:00:00.000',
      'updatedAt': '2025-01-02T10:00:00.000',
    };

void main() {
  initTestDatabase();

  late FakePathProvider paths;
  late Database db;
  late BackupRepository repo;

  setUp(() async {
    paths = await installFakePathProvider();
    db = await openTestDatabase();
    repo = BackupRepository();
  });

  /// Popola una libreria completa: 2 brani con PDF, compositore, tag,
  /// setlist, raccolta e annotazione.
  Future<void> seedLibrary() async {
    final composerId = await insertComposer(db, name: 'Chopin');
    await File(p.join(paths.documentsPath, 'notturno.pdf'))
        .writeAsBytes(fakePdf('notturno'));
    await File(p.join(paths.documentsPath, 'valzer.pdf'))
        .writeAsBytes(fakePdf('valzer'));
    final s1 = await insertSong(db,
        title: 'Notturno',
        composerId: composerId,
        filePath: 'notturno.pdf',
        extra: {'file_hash': 'hash-notturno', 'key_signature': 'Ebm'});
    final s2 = await insertSong(db,
        title: 'Valzer',
        filePath: 'valzer.pdf',
        extra: {'file_hash': 'hash-valzer', 'bpm': 90});

    final tagId =
        await db.insert('tags', {'name': 'Romantico', 'color': '#FF0000'});
    await db.insert('song_tags', {'song_id': s1, 'tag_id': tagId});

    final setlistId = await db.insert('setlists', {
      'title': 'Concerto',
      'created_at': '2025-01-01T10:00:00.000',
    });
    await db.insert('setlist_items', {
      'setlist_id': setlistId,
      'song_id': s2,
      'position': 0,
      'custom_start_page': 0,
    });
    await db.insert('setlist_items', {
      'setlist_id': setlistId,
      'song_id': s1,
      'position': 1,
      'custom_start_page': 2,
    });

    final collId = await db.insert('collections', {
      'name': 'Preferiti',
      'color': '#00FF00',
      'created_at': '2025-01-01T10:00:00.000',
    });
    await db
        .insert('song_collections', {'collection_id': collId, 'song_id': s2});

    await db.insert('annotations', {
      'song_id': s1,
      'page_number': 1,
      'annotation_data': '{"strokes":[]}',
      'created_at': '2025-01-01T10:00:00.000',
    });
  }

  /// Simula un dispositivo nuovo: DB vuoto e cartella documenti senza PDF.
  Future<void> resetDevice() async {
    db = await openTestDatabase();
    await for (final f in Directory(paths.documentsPath).list()) {
      if (f is File) await f.delete();
    }
  }

  group('createBackupFile', () {
    test('produce uno ZIP v3 con backup.json e i PDF', () async {
      await seedLibrary();

      final path = await repo.createBackupFile();

      expect(path, endsWith('.ntb'));
      expect(p.isWithin(paths.temporaryPath, path), isTrue);
      final archive = ZipDecoder()
          .decodeBytes(await File(path).readAsBytes(), verify: true);
      expect(
        archive.files.map((f) => f.name),
        containsAll(['backup.json', 'pdfs/notturno.pdf', 'pdfs/valzer.pdf']),
      );

      final json = jsonDecode(utf8
              .decode(archive.findFile('backup.json')!.content as List<int>))
          as Map<String, dynamic>;
      expect(json['version'], 3);
      expect(json['songs'], hasLength(2));
      expect(json['tags'], hasLength(1));
      expect(json['songTags'], hasLength(1));
      expect(json['setlists'], hasLength(1));
      expect((json['setlists'] as List).first['items'], hasLength(2));
      expect(json['collections'], hasLength(1));
      expect(json['annotations'], hasLength(1));

      final notturno = (json['songs'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((s) => s['title'] == 'Notturno');
      expect(notturno['composerName'], 'Chopin');
      expect(notturno['keySignature'], 'Ebm');
    });

    test('salta i brani il cui PDF non esiste più', () async {
      await insertSong(db, title: 'Fantasma', filePath: 'sparito.pdf');

      final path = await repo.createBackupFile();
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());

      expect(archive.files.map((f) => f.name), ['backup.json']);
    });
  });

  group('importBackup: ripristino completo', () {
    test('export → import su dispositivo nuovo ricostruisce la libreria',
        () async {
      await seedLibrary();
      final ntb = await repo.createBackupFile();
      await resetDevice();

      final report = await repo.importBackup(ntb);

      expect(report.songsImported, 2);
      expect(report.songsSkippedDuplicate, 0);
      expect(report.songsMissingPdf, 0);
      expect(report.tagsImported, 1);
      expect(report.setlistsImported, 1);
      expect(report.collectionsImported, 1);
      expect(report.annotationsImported, 1);
      expect(report.warnings, isEmpty);
      expect(report.wipedBeforeImport, isFalse);

      final songs = await SongRepository().getAll();
      expect(songs.map((s) => s.title), containsAll(['Notturno', 'Valzer']));
      final notturno = songs.firstWhere((s) => s.title == 'Notturno');
      final valzer = songs.firstWhere((s) => s.title == 'Valzer');

      // I metadati sopravvivono, compreso il compositore.
      expect(notturno.keySignature, 'Ebm');
      expect(notturno.composerName, 'Chopin');
      expect(valzer.bpm, 90);

      // I PDF finiscono nella cartella documenti con un nome nuovo e
      // il path salvato resta relativo.
      expect(p.isRelative(notturno.filePath), isTrue);
      final restored = File(p.join(paths.documentsPath, notturno.filePath));
      expect(await restored.readAsBytes(), fakePdf('notturno'));

      // Relazioni rimappate sui nuovi id.
      final tags = await TagRepository().getTagsForSong(notturno.id!);
      expect(tags.map((t) => t.name), ['Romantico']);

      final setlist = (await SetlistRepository().getAll()).single;
      final items = await SetlistRepository().getItemsForSetlist(setlist.id!);
      items.sort((a, b) => a.position.compareTo(b.position));
      expect(items.map((i) => i.songId), [valzer.id, notturno.id]);
      expect(items.last.customStartPage, 2);

      final collection = (await CollectionRepository().getAll()).single;
      final collSongs = await CollectionRepository().getSongs(collection.id!);
      expect(collSongs.map((s) => s.id), [valzer.id]);

      final annotations = await db.query('annotations');
      expect(annotations.single['song_id'], notturno.id);

      // Nessun residuo di staging.
      expect(
        await Directory(p.join(paths.documentsPath, '.import_staging'))
            .list()
            .isEmpty,
        isTrue,
      );
    });

    test('riusa un compositore già presente invece di duplicarlo', () async {
      await insertComposer(db, name: 'chopin');
      final ntb = await writeNtb(paths.temporaryPath, {
        'version': 3,
        'songs': [
          songJson(1, 'Notturno', composerName: 'Chopin'),
          songJson(2, 'Polacca', composerName: 'Chopin'),
        ],
      }, pdfs: {
        'brano_1.pdf': fakePdf('1'),
        'brano_2.pdf': fakePdf('2'),
      });

      await repo.importBackup(ntb);

      final composers = await db.query('composers');
      expect(composers, hasLength(1));
      final songs = await SongRepository().getAll();
      expect(songs.map((s) => s.composerId).toSet(), {composers.single['id']});
    });
  });

  group('importBackup: modalità unisci', () {
    test('salta i brani con hash già presente e ricollega le relazioni',
        () async {
      await seedLibrary();
      final ntb = await repo.createBackupFile();

      final report = await repo.importBackup(ntb);

      expect(report.songsImported, 0);
      expect(report.songsSkippedDuplicate, 2);
      expect(await SongRepository().getAll(), hasLength(2));
      // Tag per nome: nessun duplicato.
      expect(await TagRepository().getAll(), hasLength(1));
      // Le setlist invece vengono sempre aggiunte, puntando ai brani esistenti.
      expect(await SetlistRepository().getAll(), hasLength(2));
    });

    test('registra il brano anche se il PDF manca nell\'archivio', () async {
      final ntb = await writeNtb(paths.temporaryPath, {
        'version': 3,
        'songs': [songJson(1, 'Senza PDF')],
      });

      final report = await repo.importBackup(ntb);

      expect(report.songsImported, 1);
      expect(report.songsMissingPdf, 1);
      expect(report.warnings.single, contains('Senza PDF'));
    });

    test('segnala gli elementi di setlist e raccolte orfani', () async {
      final ntb = await writeNtb(paths.temporaryPath, {
        'version': 3,
        'songs': [songJson(1, 'Unico')],
        'setlists': [
          {
            'id': 1,
            'title': 'Serata',
            'items': [
              {'songId': 1, 'position': 0},
              {'songId': 99, 'position': 1},
            ],
          },
          {'id': 2, 'title': ''},
        ],
        'collections': [
          {
            'id': 1,
            'name': 'Mista',
            'songIds': [1, 98],
          },
        ],
      }, pdfs: {
        'brano_1.pdf': fakePdf('1'),
      });

      final report = await repo.importBackup(ntb);

      expect(report.setlistsImported, 1);
      expect(report.collectionsImported, 1);
      expect(
        report.warnings,
        containsAll([
          contains('Setlist "Serata": 1 brani saltati'),
          contains('Setlist con titolo mancante'),
          contains('Raccolta "Mista": 1 brani saltati'),
        ]),
      );
    });
  });

  group('importBackup: modalità sostituisci', () {
    test('cancella la libreria precedente e i PDF non più usati', () async {
      final oldPdf = File(p.join(paths.documentsPath, 'vecchio.pdf'));
      await oldPdf.writeAsBytes(fakePdf('vecchio'));
      await insertSong(db, title: 'Vecchio', filePath: 'vecchio.pdf');
      await db.insert('tags', {'name': 'Da buttare'});

      final ntb = await writeNtb(paths.temporaryPath, {
        'version': 3,
        'songs': [songJson(1, 'Nuovo')],
      }, pdfs: {
        'brano_1.pdf': fakePdf('nuovo'),
      });

      final report = await repo.importBackup(ntb, wipeBeforeImport: true);

      expect(report.wipedBeforeImport, isTrue);
      final songs = await SongRepository().getAll();
      expect(songs.map((s) => s.title), ['Nuovo']);
      expect(await TagRepository().getAll(), isEmpty);
      expect(await oldPdf.exists(), isFalse);
      expect(
        await File(p.join(paths.documentsPath, songs.single.filePath)).exists(),
        isTrue,
      );
    });

    test('non deduplica per hash: reimporta tutto', () async {
      await seedLibrary();
      final ntb = await repo.createBackupFile();

      final report = await repo.importBackup(ntb, wipeBeforeImport: true);

      expect(report.songsImported, 2);
      expect(report.songsSkippedDuplicate, 0);
      expect(await SongRepository().getAll(), hasLength(2));
    });
  });

  group('importBackup: file non validi lasciano la libreria intatta', () {
    Future<void> expectLibraryUntouched() async {
      final songs = await SongRepository().getAll();
      expect(songs.map((s) => s.title), ['Esistente']);
      final staging = Directory(p.join(paths.documentsPath, '.import_staging'));
      if (await staging.exists()) {
        expect(await staging.list().isEmpty, isTrue);
      }
    }

    setUp(() async {
      await insertSong(db, title: 'Esistente');
    });

    test('file inesistente', () async {
      await expectLater(
        repo.importBackup(p.join(paths.temporaryPath, 'nope.ntb')),
        throwsA(isA<BackupFileSystemException>()),
      );
      await expectLibraryUntouched();
    });

    test('file che non è uno ZIP', () async {
      final path = p.join(paths.temporaryPath, 'rotto.ntb');
      await File(path).writeAsBytes(List.generate(256, (i) => i));

      await expectLater(
        repo.importBackup(path),
        throwsA(isA<BackupCorruptedZipException>()),
      );
      await expectLibraryUntouched();
    });

    test('archivio senza backup.json', () async {
      final path = await writeNtb(paths.temporaryPath, null,
          pdfs: {'a.pdf': fakePdf('a')});

      await expectLater(
        repo.importBackup(path),
        throwsA(isA<BackupSchemaInvalidException>()
            .having((e) => e.field, 'field', 'backup.json')),
      );
      await expectLibraryUntouched();
    });

    test('backup di una versione futura', () async {
      final path = await writeNtb(paths.temporaryPath, {
        'version': 4,
        'songs': [songJson(1, 'Dal futuro')],
      });

      await expectLater(
        repo.importBackup(path, wipeBeforeImport: true),
        throwsA(isA<BackupVersionUnsupportedException>()),
      );
      await expectLibraryUntouched();
    });

    test('schema non valido', () async {
      final path = await writeNtb(paths.temporaryPath, {
        'version': 3,
        'songs': [
          {'id': 1, 'title': ''},
        ],
      });

      await expectLater(
        repo.importBackup(path, wipeBeforeImport: true),
        throwsA(isA<BackupSchemaInvalidException>()),
      );
      await expectLibraryUntouched();
    });
  });
}
