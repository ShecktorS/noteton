import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/collection.dart';
import '../../domain/models/setlist.dart';
import '../../domain/models/setlist_item.dart';
import '../../domain/models/song.dart';
import 'annotation_repository.dart';
import 'collection_repository.dart';
import 'setlist_repository.dart';
import 'song_repository.dart';

class BackupRepository {
  final _songRepo = SongRepository();
  final _setlistRepo = SetlistRepository();
  final _collectionRepo = CollectionRepository();
  final _annotationRepo = AnnotationRepository();
  final _uuid = const Uuid();

  /// Creates the .ntb backup ZIP and returns its temp file path.
  /// The caller decides what to do with it (save / share).
  Future<String> createBackupFile() async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();

    // 1. Fetch all data
    final songs = await _songRepo.getAll();
    final setlists = await _setlistRepo.getAll();
    final collections = await _collectionRepo.getAll();

    // 2. Build setlists with items
    final setlistsJson = <Map<String, dynamic>>[];
    for (final setlist in setlists) {
      final items = await _setlistRepo.getItemsForSetlist(setlist.id!);
      setlistsJson.add({
        'id': setlist.id,
        'title': setlist.title,
        'performanceDate': setlist.performanceDate?.toIso8601String(),
        'createdAt': setlist.createdAt.toIso8601String(),
        'items': items
            .map((item) => {
                  'songId': item.songId,
                  'position': item.position,
                  'customStartPage': item.customStartPage,
                })
            .toList(),
      });
    }

    // 3. Build collections with song IDs
    final collectionsJson = <Map<String, dynamic>>[];
    for (final collection in collections) {
      final collSongs = await _collectionRepo.getSongs(collection.id!);
      collectionsJson.add({
        'id': collection.id,
        'name': collection.name,
        'color': collection.color,
        'createdAt': collection.createdAt.toIso8601String(),
        'songIds': collSongs.map((s) => s.id).toList(),
      });
    }

    // 4. Fetch all annotations
    final annotationRows = await _annotationRepo.getAllRaw();
    final annotationsJson = annotationRows
        .map((row) => {
              'songId': row['song_id'] as int,
              'page': row['page_number'] as int,
              'data': row['annotation_data'] as String,
            })
        .toList();

    // 5. Build songs JSON
    final songsJson = songs
        .map((s) => {
              'id': s.id,
              'title': s.title,
              'composerName': s.composerName,
              'filePath': s.filePath,
              'totalPages': s.totalPages,
              'lastPage': s.lastPage,
              'status': s.status.dbValue,
              'createdAt': s.createdAt.toIso8601String(),
              'updatedAt': s.updatedAt.toIso8601String(),
            })
        .toList();

    // 6. Assemble final JSON
    final backupJson = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'songs': songsJson,
      'setlists': setlistsJson,
      'collections': collectionsJson,
      'annotations': annotationsJson,
    };

    // 7. Create ZIP archive in memory
    final archive = Archive();

    // Add backup.json
    final jsonBytes = utf8.encode(jsonEncode(backupJson));
    archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

    // Add PDF files
    for (final song in songs) {
      final pdfFile = File('${appDocsDir.path}/${song.filePath}');
      if (await pdfFile.exists()) {
        final pdfBytes = await pdfFile.readAsBytes();
        // filePath is like "uuid.pdf" — just use the filename
        final filename = song.filePath.split('/').last;
        archive.addFile(
            ArchiveFile('pdfs/$filename', pdfBytes.length, pdfBytes));
      }
    }

    // 8. Encode and write ZIP to temp file
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes == null) throw Exception('Errore nella creazione del backup');

    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final zipPath = '${tempDir.path}/noteton_backup_$timestamp.ntb';
    await File(zipPath).writeAsBytes(zipBytes);

    // 9. Return path — caller handles save/share
    return zipPath;
  }

  Future<String> importBackup(String ntbFilePath) async {
    final appDocsDir = await getApplicationDocumentsDirectory();

    // 1. Extract ZIP
    final zipBytes = await File(ntbFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes);

    // 2. Parse backup.json
    final jsonEntry = archive.findFile('backup.json');
    if (jsonEntry == null) throw Exception('File backup.json non trovato');
    final jsonStr = utf8.decode(jsonEntry.content as List<int>);
    final backupData = jsonDecode(jsonStr) as Map<String, dynamic>;

    final songsData = (backupData['songs'] as List).cast<Map<String, dynamic>>();
    final setlistsData =
        (backupData['setlists'] as List).cast<Map<String, dynamic>>();
    final collectionsData =
        (backupData['collections'] as List).cast<Map<String, dynamic>>();

    // 3. Import songs — copy PDFs + insert into DB
    final Map<int, int> oldIdToNewId = {};

    for (final songData in songsData) {
      final oldId = songData['id'] as int;
      final originalFilename = (songData['filePath'] as String).split('/').last;

      // Find PDF in archive
      final pdfEntry = archive.findFile('pdfs/$originalFilename');
      String newRelativePath;

      if (pdfEntry != null) {
        // Generate new UUID filename to avoid conflicts
        final newFilename = '${_uuid.v4()}.pdf';
        final destFile = File('${appDocsDir.path}/$newFilename');
        await destFile.writeAsBytes(pdfEntry.content as List<int>);
        newRelativePath = newFilename;
      } else {
        // PDF not found in archive — keep original path reference
        newRelativePath = songData['filePath'] as String;
      }

      final now = DateTime.now();
      final song = Song(
        title: songData['title'] as String,
        composerName: songData['composerName'] as String?,
        filePath: newRelativePath,
        totalPages: (songData['totalPages'] as int?) ?? 0,
        lastPage: (songData['lastPage'] as int?) ?? 0,
        status: SongStatus.fromDb(songData['status'] as String?),
        createdAt: songData['createdAt'] != null
            ? DateTime.parse(songData['createdAt'] as String)
            : now,
        updatedAt: songData['updatedAt'] != null
            ? DateTime.parse(songData['updatedAt'] as String)
            : now,
      );

      final inserted = await _songRepo.insert(song);
      oldIdToNewId[oldId] = inserted.id!;
    }

    // 4. Import setlists
    for (final setlistData in setlistsData) {
      final setlist = Setlist(
        title: setlistData['title'] as String,
        createdAt: setlistData['createdAt'] != null
            ? DateTime.parse(setlistData['createdAt'] as String)
            : DateTime.now(),
        performanceDate: setlistData['performanceDate'] != null
            ? DateTime.parse(setlistData['performanceDate'] as String)
            : null,
      );
      final insertedSetlist = await _setlistRepo.insert(setlist);

      final items =
          (setlistData['items'] as List).cast<Map<String, dynamic>>();
      for (final itemData in items) {
        final oldSongId = itemData['songId'] as int;
        final newSongId = oldIdToNewId[oldSongId];
        if (newSongId == null) continue; // skip if song wasn't imported

        final item = SetlistItem(
          setlistId: insertedSetlist.id!,
          songId: newSongId,
          position: (itemData['position'] as int?) ?? 0,
          customStartPage: (itemData['customStartPage'] as int?) ?? 0,
        );
        await _setlistRepo.addItem(item);
      }
    }

    // 5. Import collections
    for (final collData in collectionsData) {
      final collection = Collection(
        name: collData['name'] as String,
        color: (collData['color'] as String?) ?? '#2196F3',
        createdAt: collData['createdAt'] != null
            ? DateTime.parse(collData['createdAt'] as String)
            : DateTime.now(),
      );
      final insertedColl = await _collectionRepo.insert(collection);

      final songIds = (collData['songIds'] as List).cast<int>();
      for (final oldSongId in songIds) {
        final newSongId = oldIdToNewId[oldSongId];
        if (newSongId == null) continue;
        await _collectionRepo.addSong(insertedColl.id!, newSongId);
      }
    }

    // 6. Import annotations (v2+ backups only)
    final annotationsData = backupData['annotations'] as List? ?? [];
    int annotationsImported = 0;
    for (final annData in annotationsData.cast<Map<String, dynamic>>()) {
      final oldSongId = annData['songId'] as int;
      final newSongId = oldIdToNewId[oldSongId];
      if (newSongId == null) continue;
      final page = annData['page'] as int;
      final data = annData['data'] as String;
      await _annotationRepo.saveRaw(newSongId, page, data);
      annotationsImported++;
    }

    final annotationsNote =
        annotationsImported > 0 ? ', $annotationsImported annotazioni' : '';
    return 'Importati ${songsData.length} brani, ${setlistsData.length} setlist, ${collectionsData.length} raccolte$annotationsNote';
  }
}
