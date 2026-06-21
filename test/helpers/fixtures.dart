import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Inserisce un compositore di supporto e ne restituisce l'id.
Future<int> insertComposer(
  Database db, {
  String name = 'Bach',
  int? bornYear,
  int? diedYear,
}) {
  return db.insert('composers', {
    'name': name,
    'born_year': bornYear,
    'died_year': diedYear,
  });
}

/// Inserisce un brano di supporto e ne restituisce l'id.
/// I campi sono volutamente minimi: i test che hanno bisogno di colonne
/// specifiche (album, file_hash, ...) le passano via [extra].
Future<int> insertSong(
  Database db, {
  String title = 'Brano',
  int? composerId,
  String filePath = 'pdfs/brano.pdf',
  Map<String, Object?> extra = const {},
}) {
  final now = DateTime(2024, 1, 1).toIso8601String();
  return db.insert('songs', {
    'title': title,
    'composer_id': composerId,
    'file_path': filePath,
    'total_pages': 1,
    'last_page': 0,
    'created_at': now,
    'updated_at': now,
    'status': 'none',
    ...extra,
  });
}
