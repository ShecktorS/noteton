import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/database/database_helper.dart';

/// Metadati di un singolo checkpoint, serializzati nel `manifest.json`.
class CheckpointInfo {
  /// Cartella assoluta del checkpoint su filesystem.
  final String path;
  final DateTime createdAt;

  /// Motivo della creazione (es. `"pre-import-wipe"`, `"pre-db-migration-v5-v6"`).
  final String reason;

  /// Numero di PDF inclusi nello snapshot.
  final int pdfCount;

  /// Dimensione totale snapshot in bytes (DB + PDF).
  final int totalBytes;

  const CheckpointInfo({
    required this.path,
    required this.createdAt,
    required this.reason,
    required this.pdfCount,
    required this.totalBytes,
  });

  String get displayName {
    final iso = createdAt.toIso8601String().substring(0, 19).replaceAll('T', ' ');
    return '$iso — $reason';
  }

  Map<String, dynamic> toJson() => {
        'createdAt': createdAt.toIso8601String(),
        'reason': reason,
        'pdfCount': pdfCount,
        'totalBytes': totalBytes,
      };

  static CheckpointInfo fromJson(String path, Map<String, dynamic> json) {
    return CheckpointInfo(
      path: path,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reason: json['reason'] as String,
      pdfCount: (json['pdfCount'] as int?) ?? 0,
      totalBytes: (json['totalBytes'] as int?) ?? 0,
    );
  }
}

/// Safety net prima di operazioni irreversibili (wipe-restore, DB migration).
///
/// Ogni checkpoint è una cartella sotto `<docs>/.checkpoints/<timestamp>/`
/// contenente:
/// * `noteton.db` — copia del database SQLite
/// * `pdfs/` — copia di tutti i PDF referenziati
/// * `manifest.json` — metadati (motivo, data, conteggi)
///
/// Max 3 checkpoint rotanti (LRU): il più vecchio viene eliminato quando
/// se ne crea uno nuovo.
class CheckpointService {
  static const int maxCheckpoints = 3;
  static const String _checkpointsDir = '.checkpoints';
  static const String _manifestFileName = 'manifest.json';

  const CheckpointService();

  /// Directory radice dei checkpoint (`<docs>/.checkpoints/`).
  Future<Directory> _rootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _checkpointsDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Crea un nuovo checkpoint. Restituisce il checkpoint creato.
  ///
  /// Copia `noteton.db` + tutti i file nella docs dir (esclusi `.checkpoints`
  /// stesso e `.import_staging`). Se la creazione fallisce a metà, elimina
  /// la cartella parziale per non lasciare rumore.
  Future<CheckpointInfo> create(String reason) async {
    final root = await _rootDir();
    final docs = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final cpDir = Directory(p.join(root.path, timestamp));

    try {
      await cpDir.create(recursive: true);

      // Chiudi DB per poter copiare il file consistente.
      final dbFile = await _findDbFile();
      int totalBytes = 0;
      if (dbFile != null && await dbFile.exists()) {
        final destDb = File(p.join(cpDir.path, p.basename(dbFile.path)));
        await dbFile.copy(destDb.path);
        totalBytes += await destDb.length();
      }

      // Copia PDF (tutti i file alla radice della docs dir + cartella `pdfs/`).
      final pdfsDest = Directory(p.join(cpDir.path, 'pdfs'));
      await pdfsDest.create(recursive: true);
      int pdfCount = 0;

      await for (final entity in docs.list(recursive: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          final copy = File(p.join(pdfsDest.path, p.basename(entity.path)));
          await entity.copy(copy.path);
          totalBytes += await copy.length();
          pdfCount++;
        }
      }
      final legacyPdfsDir = Directory(p.join(docs.path, 'pdfs'));
      if (await legacyPdfsDir.exists()) {
        await for (final entity in legacyPdfsDir.list(recursive: false)) {
          if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
            final copy = File(p.join(pdfsDest.path, p.basename(entity.path)));
            if (!await copy.exists()) {
              await entity.copy(copy.path);
              totalBytes += await copy.length();
              pdfCount++;
            }
          }
        }
      }

      final info = CheckpointInfo(
        path: cpDir.path,
        createdAt: DateTime.now(),
        reason: reason,
        pdfCount: pdfCount,
        totalBytes: totalBytes,
      );
      await File(p.join(cpDir.path, _manifestFileName))
          .writeAsString(jsonEncode(info.toJson()));

      await _enforceMaxCount();
      return info;
    } catch (e) {
      // Cleanup parziale
      if (await cpDir.exists()) {
        try {
          await cpDir.delete(recursive: true);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Elenca i checkpoint presenti, ordinati dal più recente al più vecchio.
  Future<List<CheckpointInfo>> list() async {
    final root = await _rootDir();
    final result = <CheckpointInfo>[];
    if (!await root.exists()) return result;
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final manifestFile = File(p.join(entity.path, _manifestFileName));
      if (!await manifestFile.exists()) continue;
      try {
        final json =
            jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
        result.add(CheckpointInfo.fromJson(entity.path, json));
      } catch (_) {
        // manifest corrotto → ignora
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// Ripristina un checkpoint: sovrascrive DB e PDF della docs dir con
  /// quelli del checkpoint. Cancella PRIMA i file correnti per partire
  /// pulito, poi copia. In caso di errore a metà, lo stato potrebbe
  /// restare parziale — da UI si consiglia di avvisare l'utente.
  ///
  /// NB: la app DEVE essere riavviata dopo il restore per ricaricare il DB.
  Future<void> restore(CheckpointInfo checkpoint) async {
    final docs = await getApplicationDocumentsDirectory();
    final cpDir = Directory(checkpoint.path);
    if (!await cpDir.exists()) {
      throw StateError('Checkpoint non trovato: ${checkpoint.path}');
    }

    // Chiudi la connessione DB corrente per poter sovrascrivere il file.
    final dh = DatabaseHelper.instance;
    // Ignora errori di close: se non è aperto, nulla da fare.
    try {
      final db = await dh.database;
      await db.close();
    } catch (_) {}

    // Ripristina DB
    final dbFileInCheckpoint = File(p.join(cpDir.path, _databaseFileName()));
    if (await dbFileInCheckpoint.exists()) {
      final destDb = await _dbDestinationPath();
      await dbFileInCheckpoint.copy(destDb);
    }

    // Ripristina PDF: cancella i PDF correnti e ricopia quelli del checkpoint.
    await _wipeCurrentPdfs(docs);

    final pdfsSrc = Directory(p.join(cpDir.path, 'pdfs'));
    if (await pdfsSrc.exists()) {
      await for (final entity in pdfsSrc.list()) {
        if (entity is File) {
          final dest = File(p.join(docs.path, p.basename(entity.path)));
          await entity.copy(dest.path);
        }
      }
    }
  }

  /// Cancella un singolo checkpoint.
  Future<void> delete(CheckpointInfo checkpoint) async {
    final dir = Directory(checkpoint.path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Cancella tutti i checkpoint (usato come "reset" dal menu diagnostico).
  Future<void> deleteAll() async {
    final all = await list();
    for (final cp in all) {
      await delete(cp);
    }
  }

  // ---- internals ---------------------------------------------------------

  Future<void> _enforceMaxCount() async {
    final all = await list();
    if (all.length <= maxCheckpoints) return;
    // Il sort di list() è desc → gli ultimi sono i più vecchi.
    for (final cp in all.sublist(maxCheckpoints)) {
      await delete(cp);
    }
  }

  String _databaseFileName() => 'noteton.db';

  Future<String> _dbDestinationPath() async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, _databaseFileName());
  }

  Future<File?> _findDbFile() async {
    try {
      final path = await _dbDestinationPath();
      final f = File(path);
      if (await f.exists()) return f;
    } catch (_) {}
    return null;
  }

  Future<void> _wipeCurrentPdfs(Directory docs) async {
    await for (final entity in docs.list(recursive: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
    final legacyPdfsDir = Directory(p.join(docs.path, 'pdfs'));
    if (await legacyPdfsDir.exists()) {
      await for (final entity in legacyPdfsDir.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    }
  }
}
