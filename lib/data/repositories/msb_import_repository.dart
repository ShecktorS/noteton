import 'dart:io';

import '../../domain/models/import_report.dart';
import '../converters/msb_converter.dart';
import 'backup_repository.dart';

/// Wrapper che:
///   1. converte un `.msb` in `.ntb` temporaneo
///   2. delega a [BackupRepository.importBackup] per l'import vero
///   3. cancella il `.ntb` temporaneo
///
/// Espone [importMsb] come unica API, con stesse garanzie di atomicità
/// di un import backup standard (transazione DB, staging PDF, rollback su
/// errore).
class MsbImportRepository {
  final BackupRepository _backupRepo;

  MsbImportRepository(this._backupRepo);

  /// Importa un backup MobileSheets.
  ///
  /// [onProgress] viene chiamato con messaggi user-facing durante:
  /// - conversione .msb → .ntb
  /// - import .ntb → DB
  ///
  /// Ritorna [MsbImportOutcome] con il report di import + i warning della
  /// conversione MSB (es. PDF "collegati" non inclusi).
  Future<MsbImportOutcome> importMsb(
    String msbPath, {
    void Function(String message)? onProgress,
  }) async {
    final conversion = await convertMsb(msbPath, onProgress: onProgress);

    try {
      onProgress?.call('Importazione in libreria…');
      final report = await _backupRepo.importBackup(conversion.ntbPath);
      return MsbImportOutcome(
        report: report,
        conversionWarnings: conversion.warnings,
      );
    } finally {
      try {
        await File(conversion.ntbPath).delete();
      } catch (_) {}
    }
  }
}

/// Esito dell'import MS — accoppia [ImportReport] del backup standard
/// con gli avvisi specifici della conversione MobileSheets.
class MsbImportOutcome {
  final ImportReport report;
  final List<String> conversionWarnings;

  const MsbImportOutcome({
    required this.report,
    required this.conversionWarnings,
  });
}
