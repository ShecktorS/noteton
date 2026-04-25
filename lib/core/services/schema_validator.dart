import '../exceptions/backup_exceptions.dart';

/// Validatore strutturale del `backup.json` contenuto in un `.ntb`.
///
/// Eseguito in FASE 1 dell'import (read-only, nessun side-effect). Se il
/// backup ha una struttura non accettabile, solleva un
/// [BackupSchemaInvalidException] con il campo responsabile, oppure un
/// [BackupVersionUnsupportedException] se la versione del formato è
/// successiva a [maxSupportedVersion].
///
/// Regole:
/// * `version` se presente deve essere un intero ≤ [maxSupportedVersion]
///   (backup v1/v2/v3 sono tutti accettati; un v4 futuro verrebbe rifiutato)
/// * `songs` DEVE essere una List; ogni elemento DEVE avere `id` (int) e
///   `title` (String non vuota). `filePath` può essere stringa vuota.
/// * `setlists`, `collections`, `annotations`, `tags`, `songTags` se
///   presenti DEVONO essere List. Elementi malformati al loro interno
///   generano un warning silenzioso (gestito dall'import, non qui).
///
/// NON verifica la presenza dei PDF nello ZIP: quello è compito
/// dell'import step 2 (stage file).
class SchemaValidator {
  static const int maxSupportedVersion = 3;

  const SchemaValidator();

  /// Valida `backupData` (il JSON decoded). Solleva se invalido.
  void validate(Map<String, dynamic> backupData) {
    // Version check.
    final version = backupData['version'];
    if (version != null) {
      if (version is! int) {
        throw const BackupSchemaInvalidException('version', 'deve essere un intero');
      }
      if (version > maxSupportedVersion) {
        throw BackupVersionUnsupportedException(version, maxSupportedVersion);
      }
    }

    // songs è obbligatorio.
    final songs = backupData['songs'];
    if (songs == null) {
      throw const BackupSchemaInvalidException('songs', 'campo mancante');
    }
    if (songs is! List) {
      throw const BackupSchemaInvalidException('songs', 'deve essere un array');
    }
    for (var i = 0; i < songs.length; i++) {
      final s = songs[i];
      if (s is! Map) {
        throw BackupSchemaInvalidException('songs[$i]', 'deve essere un oggetto');
      }
      if (s['id'] is! int) {
        throw BackupSchemaInvalidException(
            'songs[$i].id', 'manca o non è un intero');
      }
      final title = s['title'];
      if (title is! String || title.isEmpty) {
        throw BackupSchemaInvalidException(
            'songs[$i].title', 'manca o vuoto');
      }
    }

    // setlists: se presente deve essere List.
    _requireListOrNull(backupData, 'setlists');
    _requireListOrNull(backupData, 'collections');
    _requireListOrNull(backupData, 'annotations');
    _requireListOrNull(backupData, 'tags');
    _requireListOrNull(backupData, 'songTags');
  }

  void _requireListOrNull(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value == null) return;
    if (value is! List) {
      throw BackupSchemaInvalidException(field, 'deve essere un array');
    }
  }
}
