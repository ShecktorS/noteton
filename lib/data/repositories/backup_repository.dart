import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/exceptions/backup_exceptions.dart';
import '../../core/services/checkpoint_service.dart';
import '../../core/services/schema_validator.dart';
import '../../core/utils/song_path.dart';
import '../../domain/models/import_report.dart';
import '../../domain/models/song.dart';
import '../database/database_helper.dart';
import 'annotation_repository.dart';
import 'collection_repository.dart';
import 'setlist_repository.dart';
import 'song_repository.dart';
import 'tag_repository.dart';

class BackupRepository {
  final _songRepo = SongRepository();
  final _setlistRepo = SetlistRepository();
  final _collectionRepo = CollectionRepository();
  final _annotationRepo = AnnotationRepository();
  final _tagRepo = TagRepository();
  final _uuid = const Uuid();

  // =========================================================================
  // EXPORT
  // =========================================================================

  /// Crea il file `.ntb` di backup (ZIP v3) e ritorna il path del file
  /// temporaneo. Prima di ritornare verifica integrità CRC32 del file
  /// scritto — se c'è mismatch solleva [BackupCorruptedZipException].
  Future<String> createBackupFile() async {
    final tempDir = await getTemporaryDirectory();

    // 1. Fetch all data
    final songs = await _songRepo.getAll();
    final setlists = await _setlistRepo.getAll();
    final collections = await _collectionRepo.getAll();
    final allTags = await _tagRepo.getAll();

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

    // 5. Build songs JSON (v3)
    final songsJson = songs
        .map((s) => {
              'id': s.id,
              'title': s.title,
              'composerName': s.composerName,
              'filePath': s.filePath,
              'totalPages': s.totalPages,
              'lastPage': s.lastPage,
              'status': s.status.dbValue,
              'keySignature': s.keySignature,
              'bpm': s.bpm,
              'instrument': s.instrument,
              'album': s.album,
              'period': s.period,
              'fileHash': s.fileHash,
              'createdAt': s.createdAt.toIso8601String(),
              'updatedAt': s.updatedAt.toIso8601String(),
            })
        .toList();

    // 6. Tags + song_tags
    final tagsJson = allTags
        .map((t) => {'id': t.id, 'name': t.name, 'color': t.color})
        .toList();

    final songTagsJson = <Map<String, dynamic>>[];
    for (final song in songs) {
      if (song.id == null) continue;
      final songTags = await _tagRepo.getTagsForSong(song.id!);
      for (final tag in songTags) {
        songTagsJson.add({'songId': song.id, 'tagId': tag.id});
      }
    }

    // 7. Assemble final JSON
    final backupJson = {
      'version': 3,
      'exportedAt': DateTime.now().toIso8601String(),
      'songs': songsJson,
      'setlists': setlistsJson,
      'collections': collectionsJson,
      'annotations': annotationsJson,
      'tags': tagsJson,
      'songTags': songTagsJson,
    };

    // 8. Build ZIP in memory
    final archive = Archive();
    final jsonBytes = utf8.encode(jsonEncode(backupJson));
    archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

    for (final song in songs) {
      final resolved = await SongPath.resolveDetailed(song.filePath);
      if (!resolved.exists) continue;
      final pdfFile = File(resolved.path);
      final pdfBytes = await pdfFile.readAsBytes();
      final filename = p.basename(song.filePath);
      archive.addFile(
          ArchiveFile('pdfs/$filename', pdfBytes.length, pdfBytes));
    }

    // 9. Encode + write to disk
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw const BackupFileSystemException(
          'creazione archivio', 'ZipEncoder().encode() ha restituito null');
    }

    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final zipPath = '${tempDir.path}/noteton_backup_$timestamp.ntb';
    await File(zipPath).writeAsBytes(zipBytes);

    // 10. Integrity check: ri-apri lo ZIP e verifica CRC di ogni entry.
    try {
      final rereadBytes = await File(zipPath).readAsBytes();
      // `verify: true` ricalcola il CRC di ogni entry ed esplode se non torna.
      final reopened = ZipDecoder().decodeBytes(rereadBytes, verify: true);
      // Controllo sanità: la lista dei file deve matchare quella scritta.
      if (reopened.files.length != archive.files.length) {
        throw const BackupCorruptedZipException(
            'numero di file nell\'archivio non coincide dopo rilettura');
      }
    } on BackupException {
      rethrow;
    } catch (e) {
      // decodeBytes con verify:true lancia ArchiveException su CRC bad
      throw BackupCorruptedZipException(e.toString());
    }

    return zipPath;
  }

  // =========================================================================
  // IMPORT — 3-phase atomic
  // =========================================================================

  /// Ripristina un backup `.ntb` con le seguenti garanzie:
  ///
  /// * **FASE 1 (read-only)**: valida CRC ZIP, parsing JSON, schema →
  ///   eccezione su qualunque anomalia, stato utente intatto.
  /// * **FASE 2 (stage)**: crea checkpoint pre-wipe (se richiesto) ed
  ///   estrae i PDF in `<docs>/.import_staging/<importId>/` — nessun dato
  ///   utente sovrascritto ancora.
  /// * **FASE 3 (commit)**: scritture DB dentro una singola `db.transaction`
  ///   (rollback automatico in caso di errore). Solo se la transazione
  ///   commit-a, i PDF vengono spostati a destinazione finale e
  ///   (in modalità wipe) i vecchi PDF vengono rimossi.
  ///
  /// Se qualcosa fallisce a qualunque punto:
  /// * la directory di staging viene ripulita
  /// * lo stato DB rimane integro (pre-import)
  /// * l'utente può ripristinare dal checkpoint dal menu diagnostico
  ///
  /// Ritorna un [ImportReport] dettagliato.
  Future<ImportReport> importBackup(
    String ntbFilePath, {
    bool wipeBeforeImport = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    final appDocsDir = await getApplicationDocumentsDirectory();
    final stagingDir = Directory(p.join(
      appDocsDir.path,
      '.import_staging',
      _uuid.v4(),
    ));
    final warnings = <String>[];

    try {
      // ===================== FASE 1: decode + validate =====================
      final archive = await _decodeAndVerify(ntbFilePath);
      final backupData = _parseBackupJson(archive);
      const SchemaValidator().validate(backupData);

      final songsData =
          (backupData['songs'] as List).cast<Map<String, dynamic>>();
      final setlistsData = (backupData['setlists'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          const [];
      final collectionsData = (backupData['collections'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          const [];
      final annotationsData = (backupData['annotations'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          const [];
      final tagsData =
          (backupData['tags'] as List?)?.cast<Map<String, dynamic>>() ??
              const [];
      final songTagsData =
          (backupData['songTags'] as List?)?.cast<Map<String, dynamic>>() ??
              const [];

      // Costruisco il piano import per i song.
      final plan = await _buildSongPlan(archive, songsData, wipeBeforeImport);
      for (final missing in plan.missingPdfTitles) {
        warnings.add('PDF non presente nell\'archivio: "$missing"');
      }

      // ===================== FASE 2: staging + checkpoint ==================
      if (wipeBeforeImport) {
        try {
          await const CheckpointService().create('pre-import-wipe');
        } catch (e) {
          // Checkpoint non critico: loggato come warning, non blocca import.
          warnings.add('Checkpoint pre-ripristino non creato: $e');
        }
      }

      await stagingDir.create(recursive: true);
      await _stageAllPdfs(plan, stagingDir);

      // ===================== FASE 3: commit DB transazionale ===============
      final db = await DatabaseHelper.instance.database;
      final txReport = await db.transaction<_TxReport>((txn) async {
        return _commitInTransaction(
          txn: txn,
          wipeBeforeImport: wipeBeforeImport,
          plan: plan,
          songsData: songsData,
          setlistsData: setlistsData,
          collectionsData: collectionsData,
          tagsData: tagsData,
          songTagsData: songTagsData,
          annotationsData: annotationsData,
          warnings: warnings,
        );
      });

      // ===================== POST-COMMIT: move files ======================
      // Transazione committata: ora possiamo spostare i PDF dalla staging
      // alla docs root. In modalità wipe, dopo il move rimuoviamo i PDF
      // vecchi non più referenziati.
      final newFilenamesInFinalLocation = <String>{};
      for (final entry in plan.toStage) {
        final src = File(p.join(stagingDir.path, entry.newFilename));
        final dst = File(p.join(appDocsDir.path, entry.newFilename));
        if (await src.exists()) {
          await src.rename(dst.path);
          newFilenamesInFinalLocation.add(entry.newFilename);
        }
      }

      if (wipeBeforeImport) {
        await _cleanupOldPdfs(appDocsDir, keep: newFilenamesInFinalLocation);
      }

      stopwatch.stop();
      return ImportReport(
        songsImported: txReport.songsInserted,
        songsSkippedDuplicate: plan.dedupCount,
        songsMissingPdf: plan.missingPdfCount,
        setlistsImported: txReport.setlistsInserted,
        collectionsImported: txReport.collectionsInserted,
        tagsImported: txReport.tagsInserted,
        annotationsImported: txReport.annotationsInserted,
        warnings: warnings,
        elapsed: stopwatch.elapsed,
        wipedBeforeImport: wipeBeforeImport,
      );
    } on BackupException {
      rethrow;
    } on FileSystemException catch (e) {
      throw BackupFileSystemException(e.path ?? 'filesystem', e.message);
    } catch (e) {
      // Qualsiasi altra eccezione non prevista → segnala come filesystem/IO.
      throw BackupFileSystemException('import', e.toString());
    } finally {
      // Pulizia staging (success o failure)
      try {
        if (await stagingDir.exists()) {
          await stagingDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  // =========================================================================
  // FASE 1 helpers
  // =========================================================================

  Future<Archive> _decodeAndVerify(String ntbFilePath) async {
    final file = File(ntbFilePath);
    if (!await file.exists()) {
      throw const BackupFileSystemException(
          'lettura backup', 'file non trovato');
    }
    final bytes = await file.readAsBytes();
    try {
      // `verify: true` valida i CRC32 di ogni entry.
      return ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (e) {
      throw BackupCorruptedZipException(e.toString());
    }
  }

  Map<String, dynamic> _parseBackupJson(Archive archive) {
    final jsonEntry = archive.findFile('backup.json');
    if (jsonEntry == null) {
      throw const BackupSchemaInvalidException(
          'backup.json', 'manca dall\'archivio');
    }
    try {
      final jsonStr = utf8.decode(jsonEntry.content as List<int>);
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupSchemaInvalidException(
            'backup.json', 'root non è un oggetto');
      }
      return decoded;
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupSchemaInvalidException('backup.json', e.toString());
    }
  }

  Future<_ImportPlan> _buildSongPlan(
    Archive archive,
    List<Map<String, dynamic>> songsData,
    bool wipeBeforeImport,
  ) async {
    final toStage = <_PlannedSong>[];
    final dedupOldToExistingId = <int, int>{};
    final missingPdfTitles = <String>[];
    int missingPdfCount = 0;

    for (final songData in songsData) {
      final oldId = songData['id'] as int;
      final hash = songData['fileHash'] as String?;
      final title = songData['title'] as String;
      final storedFilePath = (songData['filePath'] as String?) ?? '';

      // Dedup: in modalità unisci, se hash già presente → skip insert.
      if (!wipeBeforeImport && hash != null && hash.isNotEmpty) {
        final existing = await _songRepo.getByHash(hash);
        if (existing != null) {
          dedupOldToExistingId[oldId] = existing.id!;
          continue;
        }
      }

      final originalFilename = p.basename(storedFilePath);
      final pdfEntry = originalFilename.isEmpty
          ? null
          : archive.findFile('pdfs/$originalFilename');
      if (pdfEntry == null) {
        missingPdfTitles.add(title);
        missingPdfCount++;
        // Registra comunque il brano, ma senza PDF fisico.
        toStage.add(_PlannedSong(
          oldId: oldId,
          data: songData,
          newFilename: '',
          pdfBytes: null,
        ));
        continue;
      }

      final newFilename = '${_uuid.v4()}.pdf';
      toStage.add(_PlannedSong(
        oldId: oldId,
        data: songData,
        newFilename: newFilename,
        pdfBytes: pdfEntry.content as List<int>,
      ));
    }

    return _ImportPlan(
      toStage: toStage,
      dedupOldToExistingId: dedupOldToExistingId,
      missingPdfCount: missingPdfCount,
      missingPdfTitles: missingPdfTitles,
    );
  }

  // =========================================================================
  // FASE 2 helpers
  // =========================================================================

  Future<void> _stageAllPdfs(_ImportPlan plan, Directory stagingDir) async {
    for (final entry in plan.toStage) {
      if (entry.pdfBytes == null) continue;
      final file = File(p.join(stagingDir.path, entry.newFilename));
      await file.writeAsBytes(entry.pdfBytes!);
    }
  }

  // =========================================================================
  // FASE 3: transaction body
  // =========================================================================

  Future<_TxReport> _commitInTransaction({
    required Transaction txn,
    required bool wipeBeforeImport,
    required _ImportPlan plan,
    required List<Map<String, dynamic>> songsData,
    required List<Map<String, dynamic>> setlistsData,
    required List<Map<String, dynamic>> collectionsData,
    required List<Map<String, dynamic>> tagsData,
    required List<Map<String, dynamic>> songTagsData,
    required List<Map<String, dynamic>> annotationsData,
    required List<String> warnings,
  }) async {
    // ---- Wipe -------------------------------------------------------------
    if (wipeBeforeImport) {
      // Ordine: figli prima, padri dopo (CASCADE coprirebbe ma siamo espliciti)
      await txn.delete('annotations');
      await txn.delete('song_tags');
      await txn.delete('song_collections');
      await txn.delete('setlist_items');
      await txn.delete('tags');
      await txn.delete('collections');
      await txn.delete('setlists');
      await txn.delete('songs');
    }

    // ---- Songs ------------------------------------------------------------
    final oldIdToNewId = <int, int>{...plan.dedupOldToExistingId};
    int songsInserted = 0;
    for (final planned in plan.toStage) {
      final songData = planned.data;
      final now = DateTime.now();
      final song = Song(
        title: songData['title'] as String,
        composerName: songData['composerName'] as String?,
        filePath: planned.newFilename.isNotEmpty
            ? planned.newFilename
            : (songData['filePath'] as String? ?? ''),
        totalPages: (songData['totalPages'] as int?) ?? 0,
        lastPage: (songData['lastPage'] as int?) ?? 0,
        status: SongStatus.fromDb(songData['status'] as String?),
        keySignature: songData['keySignature'] as String?,
        bpm: songData['bpm'] as int?,
        instrument: songData['instrument'] as String?,
        album: songData['album'] as String?,
        period: songData['period'] as String?,
        fileHash: songData['fileHash'] as String?,
        createdAt: songData['createdAt'] != null
            ? DateTime.parse(songData['createdAt'] as String)
            : now,
        updatedAt: songData['updatedAt'] != null
            ? DateTime.parse(songData['updatedAt'] as String)
            : now,
      );
      final newId = await txn.insert('songs', song.toMap());
      oldIdToNewId[planned.oldId] = newId;
      songsInserted++;
    }

    // ---- Tags -------------------------------------------------------------
    final oldTagIdToNewTagId = <int, int>{};
    int tagsInserted = 0;

    // Carica tag esistenti (prima della transazione o wipe? → la query è
    // dentro txn quindi vede lo stato post-wipe).
    final existingTagsRows = await txn.query('tags');
    final existingByName = <String, int>{
      for (final r in existingTagsRows) r['name'] as String: r['id'] as int,
    };

    for (final tagData in tagsData) {
      final oldTagId = tagData['id'];
      final name = tagData['name'];
      if (oldTagId is! int || name is! String || name.isEmpty) {
        warnings.add('Tag con dati non validi saltato.');
        continue;
      }
      final color = (tagData['color'] as String?) ?? '#607D8B';
      final existingId = existingByName[name];
      if (existingId != null) {
        oldTagIdToNewTagId[oldTagId] = existingId;
      } else {
        final newId = await txn.insert('tags', {'name': name, 'color': color});
        oldTagIdToNewTagId[oldTagId] = newId;
        existingByName[name] = newId;
        tagsInserted++;
      }
    }

    // Associazioni song-tag (merge additivo)
    final songIdToTagIds = <int, Set<int>>{};
    for (final st in songTagsData) {
      final oldSongId = st['songId'];
      final oldTagId = st['tagId'];
      if (oldSongId is! int || oldTagId is! int) continue;
      final newSongId = oldIdToNewId[oldSongId];
      final newTagId = oldTagIdToNewTagId[oldTagId];
      if (newSongId == null || newTagId == null) continue;
      songIdToTagIds.putIfAbsent(newSongId, () => <int>{}).add(newTagId);
    }
    for (final entry in songIdToTagIds.entries) {
      // Merge con associazioni esistenti (in wipe sono già state cancellate)
      final existingLinks = await txn.query('song_tags',
          columns: ['tag_id'], where: 'song_id = ?', whereArgs: [entry.key]);
      final existingSet = existingLinks.map((r) => r['tag_id'] as int).toSet();
      final toAdd = entry.value.difference(existingSet);
      for (final tagId in toAdd) {
        await txn.insert('song_tags',
            {'song_id': entry.key, 'tag_id': tagId},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    // ---- Setlists ---------------------------------------------------------
    int setlistsInserted = 0;
    for (final setlistData in setlistsData) {
      final title = setlistData['title'];
      if (title is! String || title.isEmpty) {
        warnings.add('Setlist con titolo mancante saltata.');
        continue;
      }
      final setlistMap = {
        'title': title,
        'description': setlistData['description'] as String?,
        'created_at': setlistData['createdAt'] as String? ??
            DateTime.now().toIso8601String(),
        'performance_date': setlistData['performanceDate'] as String?,
      };
      final setlistId = await txn.insert('setlists', setlistMap);
      setlistsInserted++;

      final items =
          (setlistData['items'] as List?)?.cast<Map<String, dynamic>>() ??
              const [];
      int skippedItems = 0;
      for (final itemData in items) {
        final oldSongId = itemData['songId'];
        if (oldSongId is! int) continue;
        final newSongId = oldIdToNewId[oldSongId];
        if (newSongId == null) {
          skippedItems++;
          continue;
        }
        await txn.insert('setlist_items', {
          'setlist_id': setlistId,
          'song_id': newSongId,
          'position': (itemData['position'] as int?) ?? 0,
          'custom_start_page': (itemData['customStartPage'] as int?) ?? 0,
        });
      }
      if (skippedItems > 0) {
        warnings.add(
            'Setlist "$title": $skippedItems brani saltati (riferimenti mancanti).');
      }
    }

    // ---- Collections ------------------------------------------------------
    int collectionsInserted = 0;
    for (final collData in collectionsData) {
      final name = collData['name'];
      if (name is! String || name.isEmpty) {
        warnings.add('Raccolta senza nome saltata.');
        continue;
      }
      final collId = await txn.insert('collections', {
        'name': name,
        'description': collData['description'] as String?,
        'color': (collData['color'] as String?) ?? '#2196F3',
        'created_at': collData['createdAt'] as String? ??
            DateTime.now().toIso8601String(),
      });
      collectionsInserted++;

      final songIds = (collData['songIds'] as List?)?.cast<int>() ?? const [];
      int skipped = 0;
      for (final oldSongId in songIds) {
        final newSongId = oldIdToNewId[oldSongId];
        if (newSongId == null) {
          skipped++;
          continue;
        }
        await txn.insert(
          'song_collections',
          {'collection_id': collId, 'song_id': newSongId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      if (skipped > 0) {
        warnings.add(
            'Raccolta "$name": $skipped brani saltati (riferimenti mancanti).');
      }
    }

    // ---- Annotations ------------------------------------------------------
    int annotationsInserted = 0;
    final nowIso = DateTime.now().toIso8601String();
    for (final ann in annotationsData) {
      final oldSongId = ann['songId'];
      final page = ann['page'];
      final data = ann['data'];
      if (oldSongId is! int || page is! int || data is! String) continue;
      final newSongId = oldIdToNewId[oldSongId];
      if (newSongId == null) continue;
      await txn.delete(
        'annotations',
        where: 'song_id = ? AND page_number = ?',
        whereArgs: [newSongId, page],
      );
      await txn.insert('annotations', {
        'song_id': newSongId,
        'page_number': page,
        'annotation_data': data,
        'created_at': nowIso,
      });
      annotationsInserted++;
    }

    return _TxReport(
      songsInserted: songsInserted,
      setlistsInserted: setlistsInserted,
      collectionsInserted: collectionsInserted,
      tagsInserted: tagsInserted,
      annotationsInserted: annotationsInserted,
    );
  }

  // =========================================================================
  // POST-COMMIT helpers
  // =========================================================================

  /// In modalità wipe, dopo il commit: rimuove dalla docs root tutti i PDF
  /// NON referenziati dal nuovo import. [keep] contiene i nomi dei file
  /// appena importati (basename) che non vanno toccati. Il cleanup è best-
  /// effort: eventuali errori singoli non propagano.
  Future<void> _cleanupOldPdfs(
    Directory appDocsDir, {
    required Set<String> keep,
  }) async {
    await for (final entity in appDocsDir.list(recursive: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!path.toLowerCase().endsWith('.pdf')) continue;
      if (keep.contains(p.basename(path))) continue;
      try {
        await entity.delete();
      } catch (_) {}
    }
    // Cartella legacy `pdfs/` (import pre-0.3.4): rimuovi tutto perché
    // la wipe deve lasciare solo i file dell'import attuale.
    final legacy = Directory(p.join(appDocsDir.path, 'pdfs'));
    if (await legacy.exists()) {
      await for (final entity in legacy.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    }
  }
}

// =========================================================================
// Internal value types
// =========================================================================

class _PlannedSong {
  final int oldId;
  final Map<String, dynamic> data;

  /// Nome file UUID generato per la destinazione finale. Vuoto se il PDF
  /// non era nell'archivio (il brano viene inserito senza file fisico).
  final String newFilename;

  /// Contenuto del PDF nell'archivio (null se assente).
  final List<int>? pdfBytes;

  const _PlannedSong({
    required this.oldId,
    required this.data,
    required this.newFilename,
    required this.pdfBytes,
  });
}

class _ImportPlan {
  final List<_PlannedSong> toStage;
  final Map<int, int> dedupOldToExistingId;
  final int missingPdfCount;
  final List<String> missingPdfTitles;

  const _ImportPlan({
    required this.toStage,
    required this.dedupOldToExistingId,
    required this.missingPdfCount,
    required this.missingPdfTitles,
  });

  int get dedupCount => dedupOldToExistingId.length;
}

class _TxReport {
  final int songsInserted;
  final int setlistsInserted;
  final int collectionsInserted;
  final int tagsInserted;
  final int annotationsInserted;
  const _TxReport({
    required this.songsInserted,
    required this.setlistsInserted,
    required this.collectionsInserted,
    required this.tagsInserted,
    required this.annotationsInserted,
  });
}
