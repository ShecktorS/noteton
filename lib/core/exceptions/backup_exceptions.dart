/// Gerarchia di eccezioni per operazioni di backup/restore .ntb.
///
/// Ogni eccezione espone `userMessage` in italiano: il chiamante la mostra
/// direttamente in dialog/snackbar senza bisogno di interpretare lo stack.
sealed class BackupException implements Exception {
  const BackupException();

  /// Messaggio in italiano adatto a essere mostrato all'utente finale.
  String get userMessage;

  /// Dettaglio tecnico aggiuntivo (può essere mostrato in un expander).
  String? get technicalDetail => null;

  @override
  String toString() {
    final detail = technicalDetail;
    return detail == null
        ? 'BackupException: $userMessage'
        : 'BackupException: $userMessage ($detail)';
  }
}

/// Il file `.ntb` non è un archivio ZIP valido o il CRC di una entry non torna.
class BackupCorruptedZipException extends BackupException {
  @override
  final String? technicalDetail;

  const BackupCorruptedZipException([this.technicalDetail]);

  @override
  String get userMessage =>
      'Il file di backup sembra danneggiato. Prova a riscaricarlo o a usare un backup precedente.';
}

/// Il `backup.json` ha una struttura inattesa (campo mancante, tipo sbagliato,
/// chiave non riconosciuta in un punto critico).
class BackupSchemaInvalidException extends BackupException {
  /// Nome del campo che ha fallito la validazione (es. "songs[3].title").
  final String field;
  @override
  final String? technicalDetail;

  const BackupSchemaInvalidException(this.field, [this.technicalDetail]);

  @override
  String get userMessage =>
      'Il backup non è leggibile (campo non valido: "$field"). Il file potrebbe essere stato modificato o proveniente da una versione non supportata.';
}

/// La versione del formato backup è più recente di quella supportata da questa app.
class BackupVersionUnsupportedException extends BackupException {
  final int version;
  final int maxSupportedVersion;

  const BackupVersionUnsupportedException(this.version, this.maxSupportedVersion);

  @override
  String get userMessage =>
      'Questo backup è stato creato con una versione più recente di Noteton (formato v$version). Aggiorna l\'app per importarlo.';

  @override
  String? get technicalDetail =>
      'found=v$version supported<=v$maxSupportedVersion';
}

/// Errore durante operazioni filesystem (spazio esaurito, permessi, I/O).
class BackupFileSystemException extends BackupException {
  final String operation;
  @override
  final String? technicalDetail;

  const BackupFileSystemException(this.operation, [this.technicalDetail]);

  @override
  String get userMessage =>
      'Errore durante l\'accesso ai file ($operation). Controlla lo spazio disponibile sul dispositivo e riprova.';
}
