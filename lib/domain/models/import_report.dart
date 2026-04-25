/// Report dettagliato di un'operazione di import `.ntb`.
///
/// Sostituisce la vecchia summary string. Viene mostrato in un dialog finale
/// con possibilità di copiare i dettagli tecnici (utile in caso di problemi).
class ImportReport {
  final int songsImported;
  final int songsSkippedDuplicate;
  final int songsMissingPdf;

  final int setlistsImported;
  final int collectionsImported;
  final int tagsImported;
  final int annotationsImported;

  /// Warning non-fatali incontrati durante l'import (es. setlist che
  /// referenziavano un brano mancante, tag duplicati per nome, ecc.).
  final List<String> warnings;

  /// Tempo totale impiegato dall'operazione.
  final Duration elapsed;

  /// True se il ripristino è avvenuto in modalità "Sostituisci tutto".
  final bool wipedBeforeImport;

  const ImportReport({
    required this.songsImported,
    required this.songsSkippedDuplicate,
    required this.songsMissingPdf,
    required this.setlistsImported,
    required this.collectionsImported,
    required this.tagsImported,
    required this.annotationsImported,
    required this.warnings,
    required this.elapsed,
    required this.wipedBeforeImport,
  });

  /// Riepilogo breve per snackbar o titolo dialog.
  String get shortSummary {
    final parts = <String>[];
    if (songsImported > 0) parts.add('$songsImported brani');
    if (setlistsImported > 0) parts.add('$setlistsImported setlist');
    if (collectionsImported > 0) parts.add('$collectionsImported raccolte');
    if (tagsImported > 0) parts.add('$tagsImported tag');
    if (annotationsImported > 0) {
      parts.add('$annotationsImported annotazioni');
    }
    if (parts.isEmpty) return 'Nessun elemento importato.';
    return 'Importati: ${parts.join(", ")}.';
  }

  /// Testo multi-riga con tutti i dettagli — copiabile dall'utente.
  String get fullText {
    final sb = StringBuffer()
      ..writeln('Ripristino ${wipedBeforeImport ? "completo (sostituzione)" : "unione"}')
      ..writeln('Durata: ${elapsed.inSeconds}s ${elapsed.inMilliseconds % 1000}ms')
      ..writeln('')
      ..writeln('Brani importati: $songsImported')
      ..writeln('Brani duplicati saltati: $songsSkippedDuplicate')
      ..writeln('Brani con PDF mancante: $songsMissingPdf')
      ..writeln('Setlist importate: $setlistsImported')
      ..writeln('Raccolte importate: $collectionsImported')
      ..writeln('Tag importati: $tagsImported')
      ..writeln('Annotazioni importate: $annotationsImported');

    if (warnings.isNotEmpty) {
      sb
        ..writeln('')
        ..writeln('Avvisi:');
      for (final w in warnings) {
        sb.writeln('• $w');
      }
    }
    return sb.toString();
  }

  bool get hasWarnings => warnings.isNotEmpty || songsMissingPdf > 0;
}
