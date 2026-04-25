import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/database/database_helper.dart';
import '../utils/song_path.dart';

/// Righe `songs` il cui PDF non si trova più sul filesystem.
class OrphanRecord {
  final int songId;
  final String title;
  final String storedPath;
  const OrphanRecord({
    required this.songId,
    required this.title,
    required this.storedPath,
  });
}

/// File PDF sul filesystem che non sono referenziati da nessuna riga `songs`.
class OrphanFile {
  final String path;
  final int bytes;
  const OrphanFile({required this.path, required this.bytes});
}

/// Esito di uno scan completo.
class HealthReport {
  final List<OrphanRecord> orphanRecords;
  final List<OrphanFile> orphanFiles;
  final int songsWithoutHash;
  final int totalSongs;
  final int totalPdfFiles;

  const HealthReport({
    required this.orphanRecords,
    required this.orphanFiles,
    required this.songsWithoutHash,
    required this.totalSongs,
    required this.totalPdfFiles,
  });

  bool get isHealthy =>
      orphanRecords.isEmpty && orphanFiles.isEmpty && songsWithoutHash == 0;
}

/// Scansione di integrità fra DB e filesystem, più utility di manutenzione.
///
/// Usato solo dal menu diagnostico nascosto (non deve apparire nella UI
/// pubblica).
class LibraryHealthService {
  const LibraryHealthService();

  Future<HealthReport> scan() async {
    final db = await DatabaseHelper.instance.database;
    final docs = await getApplicationDocumentsDirectory();

    // DB → set di path risolti effettivamente presenti + record orfani.
    final rows = await db.query('songs', columns: ['id', 'title', 'file_path', 'file_hash']);

    final orphanRecords = <OrphanRecord>[];
    final referencedAbsolutePaths = <String>{};
    int songsWithoutHash = 0;

    for (final row in rows) {
      final songId = row['id'] as int;
      final title = row['title'] as String;
      final storedPath = row['file_path'] as String;
      final hash = row['file_hash'] as String?;
      if (hash == null || hash.isEmpty) songsWithoutHash++;

      final resolved = await SongPath.resolveDetailed(storedPath);
      if (resolved.exists) {
        referencedAbsolutePaths.add(p.normalize(resolved.path));
      } else {
        orphanRecords.add(OrphanRecord(
            songId: songId, title: title, storedPath: storedPath));
      }
    }

    // Filesystem → tutti i PDF nella docs dir (root + `pdfs/`), esclusi
    // `.checkpoints` e `.import_staging`.
    final allPdfFiles = <File>[];
    await for (final entity in docs.list(recursive: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
        allPdfFiles.add(entity);
      }
    }
    final legacy = Directory(p.join(docs.path, 'pdfs'));
    if (await legacy.exists()) {
      await for (final entity in legacy.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          allPdfFiles.add(entity);
        }
      }
    }

    final orphanFiles = <OrphanFile>[];
    for (final f in allPdfFiles) {
      final normalized = p.normalize(f.path);
      if (!referencedAbsolutePaths.contains(normalized)) {
        final size = await f.length();
        orphanFiles.add(OrphanFile(path: normalized, bytes: size));
      }
    }

    return HealthReport(
      orphanRecords: orphanRecords,
      orphanFiles: orphanFiles,
      songsWithoutHash: songsWithoutHash,
      totalSongs: rows.length,
      totalPdfFiles: allPdfFiles.length,
    );
  }

  /// Calcola SHA-256 e aggiorna `songs.file_hash` per tutte le righe
  /// senza hash. Restituisce quante righe sono state aggiornate.
  Future<int> backfillFileHashes() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'songs',
      columns: ['id', 'file_path'],
      where: 'file_hash IS NULL OR file_hash = ?',
      whereArgs: [''],
    );
    int updated = 0;
    for (final row in rows) {
      final id = row['id'] as int;
      final storedPath = row['file_path'] as String;
      final resolved = await SongPath.resolveDetailed(storedPath);
      if (!resolved.exists) continue;
      try {
        final bytes = await File(resolved.path).readAsBytes();
        final hash = sha256.convert(bytes).toString();
        await db.update(
          'songs',
          {'file_hash': hash, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [id],
        );
        updated++;
      } catch (_) {
        // file non leggibile → skip
      }
    }
    return updated;
  }

  /// Elimina dal filesystem tutti gli [orphanFiles]. Ritorna il numero di
  /// file effettivamente cancellati.
  Future<int> deleteOrphanFiles(Iterable<OrphanFile> orphanFiles) async {
    int count = 0;
    for (final o in orphanFiles) {
      try {
        final f = File(o.path);
        if (await f.exists()) {
          await f.delete();
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  /// Elimina dal DB tutte le righe `songs` elencate in [orphanRecords].
  /// Ritorna il numero di righe cancellate. Non tocca il filesystem
  /// (i record sono orfani *perché* il file non c'è).
  Future<int> deleteOrphanRecords(Iterable<OrphanRecord> orphanRecords) async {
    final db = await DatabaseHelper.instance.database;
    int count = 0;
    for (final o in orphanRecords) {
      count += await db.delete('songs', where: 'id = ?', whereArgs: [o.songId]);
    }
    return count;
  }
}
