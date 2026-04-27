/// Converter `.msb` (backup MobileSheets) → `.ntb` (backup Noteton v3).
///
/// Differenze rispetto al converter standalone msb2ntb_app:
/// - Mappa **Composer + Artists** entrambi su composers Noteton (MS distingue
///   classico/pop, Noteton no).
/// - Estrae **Setlists + SetlistSong** in items con position derivata
///   dall'ordine SetlistSong.Id.
/// - Estrae **Collections + CollectionSong** in songIds.
/// - Estrae **Key + KeySongs** mappando il nome chiave in formato Noteton.
/// - Estrae **Genres + GenresSongs** in `period`.
/// - Estrae **Tempos** primario per ogni song in `bpm`.
/// - Output `backup.json` schema v3 compatibile con `BackupRepository.importBackup`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelli
// ─────────────────────────────────────────────────────────────────────────────

class _MsbSongRow {
  final int id;
  final String title;
  final String? composerName;
  final String? keySignature;
  final String? period;
  final int? bpm;
  final int lastPage;
  final int totalPages;
  final int fileSize;
  final String originalPath;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Riempiti dopo l'estrazione PDF
  Uint8List? pdfBytes;
  String? pdfSha256;
  String? storedFilename; // UUID.pdf o nome safe

  _MsbSongRow({
    required this.id,
    required this.title,
    this.composerName,
    this.keySignature,
    this.period,
    this.bpm,
    required this.lastPage,
    required this.totalPages,
    required this.fileSize,
    required this.originalPath,
    this.createdAt,
    this.updatedAt,
  });
}

class _MsbSetlistRow {
  final int id;
  final String name;
  final List<int> songIds; // in ordine
  _MsbSetlistRow(this.id, this.name, this.songIds);
}

class _MsbCollectionRow {
  final int id;
  final String name;
  final List<int> songIds;
  _MsbCollectionRow(this.id, this.name, this.songIds);
}

/// Risultato dell'intera conversione.
class MsbConversionResult {
  final String ntbPath;
  final int songsImported;
  final int setlistsImported;
  final int collectionsImported;
  final List<String> warnings;

  const MsbConversionResult({
    required this.ntbPath,
    required this.songsImported,
    required this.setlistsImported,
    required this.collectionsImported,
    required this.warnings,
  });
}

class MsbConversionException implements Exception {
  final String message;
  const MsbConversionException(this.message);
  @override
  String toString() => 'MsbConversionException: $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Costanti
// ─────────────────────────────────────────────────────────────────────────────

final _sqliteMagic = Uint8List.fromList([
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, 0x6f, 0x72, 0x6d, 0x61,
  0x74, 0x20, 0x33, 0x00,
]);
final _pdfMagic = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d]);

int _findSequence(Uint8List data, Uint8List pattern, {int start = 0}) {
  final pLen = pattern.length;
  final dLen = data.length;
  outer:
  for (var i = start; i <= dLen - pLen; i++) {
    for (var j = 0; j < pLen; j++) {
      if (data[i + j] != pattern[j]) continue outer;
    }
    return i;
  }
  return -1;
}

(Uint8List, int) _extractSqliteBytes(Uint8List data) {
  final start = _findSequence(data, _sqliteMagic);
  if (start < 0) {
    throw const MsbConversionException(
        'Nessun header SQLite trovato — file non è un backup MobileSheets valido.');
  }
  int pageSize = (data[start + 16] << 8) | data[start + 17];
  if (pageSize == 1) pageSize = 65536;
  final pageCount = (data[start + 28] << 24) |
      (data[start + 29] << 16) |
      (data[start + 30] << 8) |
      data[start + 31];
  if (pageCount == 0) {
    throw const MsbConversionException(
        'Header SQLite riporta 0 pagine — backup non leggibile.');
  }
  final size = pageSize * pageCount;
  final end = start + size;
  if (end > data.length) {
    throw const MsbConversionException(
        'DB SQLite eccede la lunghezza del file — backup troncato.');
  }
  return (Uint8List.sublistView(data, start, end), end);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mapping nomi chiave MobileSheets → formato Noteton
// ─────────────────────────────────────────────────────────────────────────────

/// MobileSheets memorizza tonalità come stringhe libere (es. "C major",
/// "A minor", "Cm", "F#"). Converte nei nostri 26 valori canonici Noteton.
String? _normalizeKey(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;

  // Già in formato Noteton?
  const valid = {
    'C', 'C#', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
    'Cm', 'C#m', 'Dm', 'Ebm', 'Em', 'Fm', 'F#m', 'Gm', 'Abm', 'Am', 'Bbm', 'Bm',
  };
  if (valid.contains(s)) return s;

  // Pattern "X major", "X minor"
  final low = s.toLowerCase();
  String? note;
  bool isMinor = false;

  // Estrazione nota base
  final noteMatch = RegExp(r'^([a-g])([#♯b♭]?)').firstMatch(low);
  if (noteMatch == null) return null;
  final noteName = noteMatch.group(1)!.toUpperCase();
  final accidental = noteMatch.group(2) ?? '';
  if (accidental == '#' || accidental == '♯') {
    note = '$noteName#';
  } else if (accidental == 'b' || accidental == '♭') {
    note = '${noteName}b';
  } else {
    note = noteName;
  }

  if (low.contains('minor') || low.contains('min ') || low.endsWith('m')) {
    isMinor = true;
  }

  final result = isMinor ? '${note}m' : note;
  return valid.contains(result) ? result : null;
}

DateTime? _epochMsToDateTime(int? epochMs) {
  if (epochMs == null || epochMs <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(epochMs).toUtc();
}

// ─────────────────────────────────────────────────────────────────────────────
// Query SQLite
// ─────────────────────────────────────────────────────────────────────────────

Future<List<_MsbSongRow>> _querySongs(Database db) async {
  // composerName: prima Composer, poi Artist (semantica MS: classico vs pop).
  // keySignature: dalla tabella Key tramite KeySongs.
  // period: dalla tabella Genres tramite GenresSongs (primo).
  // bpm: Tempos primario.
  final rows = await db.rawQuery('''
    SELECT
      s.Id        AS song_id,
      s.Title     AS title,
      s.LastPage  AS last_page,
      s.CreationDate AS creation_date,
      s.LastModified AS last_modified,
      f.Path      AS path,
      f.FileSize  AS file_size,
      f.SourceFilePageCount AS total_pages,
      COALESCE(
        (SELECT c.Name FROM Composer c
         JOIN ComposerSongs cs ON cs.ComposerId = c.Id
         WHERE cs.SongId = s.Id ORDER BY cs.Id LIMIT 1),
        (SELECT a.Name FROM Artists a
         JOIN ArtistsSongs ars ON ars.ArtistId = a.Id
         WHERE ars.SongId = s.Id ORDER BY ars.Id LIMIT 1)
      ) AS composer_name,
      (SELECT k.Name FROM Key k
        JOIN KeySongs ks ON ks.KeyId = k.Id
        WHERE ks.SongId = s.Id LIMIT 1) AS key_name,
      (SELECT g.Type FROM Genres g
        JOIN GenresSongs gs ON gs.GenreId = g.Id
        WHERE gs.SongId = s.Id ORDER BY gs.Id LIMIT 1) AS genre_name,
      (SELECT t.Tempo FROM Tempos t
        WHERE t.SongId = s.Id ORDER BY t.TempoIndex LIMIT 1) AS tempo
    FROM Songs s
    JOIN Files f ON f.SongId = s.Id
    WHERE LOWER(f.Path) LIKE '%.pdf'
      AND f.FileSize > 0
    ORDER BY f.Id
  ''');

  return rows.map((r) {
    final composerName = (r['composer_name'] as String?)?.trim();
    final keyName = (r['key_name'] as String?)?.trim();
    final genreName = (r['genre_name'] as String?)?.trim();
    final tempoRaw = r['tempo'];
    int? bpm;
    if (tempoRaw is int) {
      bpm = tempoRaw;
    } else if (tempoRaw is String) {
      bpm = int.tryParse(tempoRaw);
    }
    return _MsbSongRow(
      id: (r['song_id'] as int?) ?? 0,
      title: ((r['title'] as String?)?.trim().isNotEmpty ?? false)
          ? (r['title'] as String)
          : 'Brano ${r['song_id']}',
      composerName:
          (composerName?.isNotEmpty ?? false) ? composerName : null,
      keySignature: _normalizeKey(keyName),
      period: (genreName?.isNotEmpty ?? false) ? genreName : null,
      bpm: bpm,
      lastPage: (r['last_page'] as int?) ?? 0,
      totalPages: (r['total_pages'] as int?) ?? 0,
      fileSize: (r['file_size'] as int?) ?? 0,
      originalPath: (r['path'] as String?) ?? '${r['song_id']}.pdf',
      createdAt: _epochMsToDateTime(r['creation_date'] as int?),
      updatedAt: _epochMsToDateTime(r['last_modified'] as int?),
    );
  }).toList();
}

Future<List<_MsbSetlistRow>> _querySetlists(Database db) async {
  final setRows =
      await db.rawQuery('SELECT Id, Name FROM Setlists ORDER BY Id');
  final result = <_MsbSetlistRow>[];
  for (final r in setRows) {
    final id = r['Id'] as int;
    final name =
        ((r['Name'] as String?)?.trim().isNotEmpty ?? false) ? r['Name'] as String : 'Setlist $id';
    final items = await db.rawQuery(
      'SELECT SongId FROM SetlistSong WHERE SetlistId = ? ORDER BY Id',
      [id],
    );
    result.add(_MsbSetlistRow(
      id,
      name,
      items.map((m) => m['SongId'] as int).toList(),
    ));
  }
  return result;
}

Future<List<_MsbCollectionRow>> _queryCollections(Database db) async {
  final colRows =
      await db.rawQuery('SELECT Id, Name FROM Collections ORDER BY Id');
  final result = <_MsbCollectionRow>[];
  for (final r in colRows) {
    final id = r['Id'] as int;
    final name = ((r['Name'] as String?)?.trim().isNotEmpty ?? false)
        ? r['Name'] as String
        : 'Raccolta $id';
    final items = await db.rawQuery(
      'SELECT SongId FROM CollectionSong WHERE CollectionId = ? ORDER BY Id',
      [id],
    );
    final songIds = items.map((m) => m['SongId'] as int).toSet().toList();
    result.add(_MsbCollectionRow(id, name, songIds));
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Estrazione PDF
// ─────────────────────────────────────────────────────────────────────────────

typedef _ExtractResult = ({List<_MsbSongRow> songs, List<String> warnings});

_ExtractResult _extractPdfs(
  Uint8List data,
  int dbEnd,
  List<_MsbSongRow> songs,
) {
  final warnings = <String>[];
  final ok = <_MsbSongRow>[];
  var cursor = dbEnd;

  for (final s in songs) {
    if (s.fileSize <= 0 || s.fileSize > 200 * 1024 * 1024) {
      warnings.add(
          'Saltato "${s.title}" (id=${s.id}): FileSize=${s.fileSize} non valido.');
      continue;
    }
    final pdfStart = _findSequence(data, _pdfMagic, start: cursor);
    if (pdfStart < 0) {
      warnings.add(
          'Interrotto a "${s.title}": nessun PDF oltre offset $cursor. '
          'I brani successivi potrebbero essere file collegati esternamente, non inclusi nel backup.');
      break;
    }
    final pdfEnd = pdfStart + s.fileSize;
    if (pdfEnd > data.length) {
      warnings.add(
          'Saltato "${s.title}": FileSize eccede la fine del file.');
      cursor = pdfStart + _pdfMagic.length;
      continue;
    }
    s.pdfBytes = Uint8List.sublistView(data, pdfStart, pdfEnd);
    s.pdfSha256 = sha256.convert(s.pdfBytes!).toString();
    ok.add(s);
    cursor = pdfEnd;
  }
  return (songs: ok, warnings: warnings);
}

// ─────────────────────────────────────────────────────────────────────────────
// Build .ntb
// ─────────────────────────────────────────────────────────────────────────────

final _unsafeChars = RegExp(r'[^A-Za-z0-9._-]+');
String _safePdfFilename(String original, int songId, Set<String> used) {
  var name = original.split('/').last.split('\\').last;
  final dotIdx = name.lastIndexOf('.');
  final stem = dotIdx > 0 ? name.substring(0, dotIdx) : name;
  var cleaned =
      stem.replaceAll(_unsafeChars, '_').replaceAll(RegExp(r'^_+|_+$'), '');
  if (cleaned.isEmpty) cleaned = 'song_$songId';
  var candidate = '$cleaned.pdf';
  var i = 1;
  while (used.contains(candidate)) {
    i++;
    candidate = '${cleaned}_$i.pdf';
  }
  used.add(candidate);
  return candidate;
}

Uint8List _buildNtb({
  required List<_MsbSongRow> songs,
  required List<_MsbSetlistRow> setlists,
  required List<_MsbCollectionRow> collections,
}) {
  final nowIso = DateTime.now().toUtc().toIso8601String();
  final usedFilenames = <String>{};
  final archive = Archive();
  final validSongIds = <int>{};

  // Songs JSON
  final songsJson = <Map<String, dynamic>>[];
  for (final s in songs) {
    if (s.pdfBytes == null) continue;
    final stored = _safePdfFilename(s.originalPath, s.id, usedFilenames);
    s.storedFilename = stored;
    archive.addFile(
        ArchiveFile('pdfs/$stored', s.pdfBytes!.length, s.pdfBytes!));
    songsJson.add({
      'id': s.id,
      'title': s.title,
      'composerName': s.composerName,
      'filePath': stored,
      'totalPages': s.totalPages,
      'lastPage': s.lastPage,
      'status': 'none',
      'keySignature': s.keySignature,
      'bpm': s.bpm,
      'instrument': null,
      'album': null,
      'period': s.period,
      'fileHash': s.pdfSha256,
      'createdAt': (s.createdAt ?? DateTime.now().toUtc()).toIso8601String(),
      'updatedAt': (s.updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
    });
    validSongIds.add(s.id);
  }

  // Setlists JSON — filtra song id non importati
  final setlistsJson = <Map<String, dynamic>>[];
  for (final sl in setlists) {
    final filteredItems = <Map<String, dynamic>>[];
    var pos = 0;
    for (final sid in sl.songIds) {
      if (!validSongIds.contains(sid)) continue;
      filteredItems.add({
        'songId': sid,
        'position': pos++,
        'customStartPage': 0,
      });
    }
    if (filteredItems.isEmpty) continue;
    setlistsJson.add({
      'id': sl.id,
      'title': sl.name,
      'performanceDate': null,
      'createdAt': nowIso,
      'items': filteredItems,
    });
  }

  // Collections JSON — filtra song id non importati
  final collectionsJson = <Map<String, dynamic>>[];
  for (final c in collections) {
    final filtered = c.songIds.where(validSongIds.contains).toList();
    if (filtered.isEmpty) continue;
    collectionsJson.add({
      'id': c.id,
      'name': c.name,
      'color': '#2196F3',
      'createdAt': nowIso,
      'songIds': filtered,
    });
  }

  final backupJson = {
    'version': 3,
    'exportedAt': nowIso,
    'source': 'msb2ntb',
    'songs': songsJson,
    'setlists': setlistsJson,
    'collections': collectionsJson,
    'annotations': <Map<String, dynamic>>[],
    'tags': <Map<String, dynamic>>[],
    'songTags': <Map<String, dynamic>>[],
  };

  final jsonBytes = utf8.encode(json.encode(backupJson));
  archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

  final zipBytes = ZipEncoder().encode(archive);
  if (zipBytes == null) {
    throw const MsbConversionException('Errore creazione ZIP del .ntb');
  }
  return Uint8List.fromList(zipBytes);
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry point pubblico
// ─────────────────────────────────────────────────────────────────────────────

/// Converte un file `.msb` in un `.ntb` temporaneo. Ritorna il path.
/// Chiama [onProgress] con messaggi di avanzamento.
Future<MsbConversionResult> convertMsb(
  String msbPath, {
  void Function(String message)? onProgress,
}) async {
  onProgress?.call('Lettura file .msb…');
  final data = await File(msbPath).readAsBytes();

  onProgress?.call('Estrazione database SQLite…');
  final (dbBytes, dbEnd) = _extractSqliteBytes(data);

  // Apri DB in tmp e fa le query
  final tmpDir = await getTemporaryDirectory();
  final tmpDbPath = p.join(tmpDir.path, '${const Uuid().v4()}.db');
  await File(tmpDbPath).writeAsBytes(dbBytes);

  late final List<_MsbSongRow> songs;
  late final List<_MsbSetlistRow> setlists;
  late final List<_MsbCollectionRow> collections;

  try {
    final db = await openDatabase(tmpDbPath, readOnly: true);
    try {
      onProgress?.call('Lettura metadati brani…');
      songs = await _querySongs(db);
      if (songs.isEmpty) {
        throw const MsbConversionException(
            'Nessun brano PDF trovato nel database MobileSheets.');
      }
      onProgress?.call('Lettura setlist…');
      setlists = await _querySetlists(db);
      onProgress?.call('Lettura raccolte…');
      collections = await _queryCollections(db);
    } finally {
      await db.close();
    }
  } finally {
    try {
      await File(tmpDbPath).delete();
    } catch (_) {}
  }

  onProgress?.call('Estrazione PDF (${songs.length} brani)…');
  final extracted = _extractPdfs(data, dbEnd, songs);
  if (extracted.songs.isEmpty) {
    throw const MsbConversionException(
        'Nessun PDF estratto. I file potrebbero essere "collegati" non inclusi nel backup.');
  }

  onProgress?.call(
      'Costruzione archivio .ntb (${extracted.songs.length} brani, ${setlists.length} setlist, ${collections.length} raccolte)…');
  final ntbBytes = _buildNtb(
    songs: extracted.songs,
    setlists: setlists,
    collections: collections,
  );

  final baseName = p.basenameWithoutExtension(msbPath);
  final ntbPath = p.join(tmpDir.path, '$baseName.ntb');
  await File(ntbPath).writeAsBytes(ntbBytes);

  onProgress?.call('Conversione completata.');
  return MsbConversionResult(
    ntbPath: ntbPath,
    songsImported: extracted.songs.length,
    setlistsImported: setlists.where((s) {
      return s.songIds.any((id) =>
          extracted.songs.any((es) => es.id == id));
    }).length,
    collectionsImported: collections.where((c) {
      return c.songIds.any((id) =>
          extracted.songs.any((es) => es.id == id));
    }).length,
    warnings: extracted.warnings,
  );
}
