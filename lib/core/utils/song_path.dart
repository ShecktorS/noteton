import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Esito della risoluzione di un `Song.filePath`.
///
/// A differenza di `SongPath.resolve()` (che restituisce solo una stringa e
/// in caso di fallimento torna un path inesistente), qui il chiamante sa
/// esplicitamente se il file è presente sul filesystem e da quale strategia
/// è stato trovato.
class ResolveResult {
  /// Path assoluto candidato. Se `exists == false` il file NON è lì.
  final String path;

  /// True se esiste effettivamente sul filesystem.
  final bool exists;

  /// Strategia vincente (o `'not_found'` se nessun tentativo ha trovato il file).
  final String reason;

  const ResolveResult({
    required this.path,
    required this.exists,
    required this.reason,
  });
}

/// Risoluzione centralizzata del `filePath` dei Song.
///
/// Nella storia della app il campo `Song.filePath` è stato salvato in modi
/// diversi:
///
/// * `_startImport` del pulsante `+` in libreria → path **assoluto**
///   (`/data/user/0/<pkg>/app_flutter/pdfs/<uuid>.pdf`)
/// * `_importFromZip` (migrazione da MobileSheets) → path **assoluto**
/// * `BackupRepository.importBackup` (ripristino `.ntb`) → path **relativo**
///   (`<uuid>.pdf`) rispetto alla app docs dir
///
/// Se lanci la app dopo un ripristino backup e provi ad aprire un PDF, il
/// viewer faceva `PdfDocument.openFile(song.filePath)` direttamente: con un
/// path relativo il plugin cercava nel working dir e ritornava "File not
/// found". Stesso problema potrebbe verificarsi dopo un reinstall della app,
/// perché Android non garantisce che il nome della cartella in
/// `/data/user/0/<pkg>/...` resti stabile tra versioni.
///
/// Da 0.3.4 in avanti tutti i nuovi import salvano path **relativi** alla
/// app docs dir. Questo helper:
///
/// * accetta entrambi i formati (assoluto legacy / relativo nuovo);
/// * al momento dell'apertura ricostruisce il path assoluto corrente;
/// * se il file non è al posto atteso, prova un paio di fallback basati sul
///   basename in modo che i dati importati prima del fix continuino a
///   funzionare senza bisogno di una migration bloccante.
class SongPath {
  SongPath._();

  /// Converte un path assoluto (quello ritornato da un import PDF) nel path
  /// "storabile" da mettere in `songs.file_path`: relativo alla app docs dir.
  ///
  /// Es: `/data/user/0/com.foo/app_flutter/pdfs/abcd.pdf`
  ///   → `pdfs/abcd.pdf`
  ///
  /// Se `absolutePath` non è dentro la docs dir (non dovrebbe succedere ma è
  /// meglio essere difensivi), ritorna il basename come ultima risorsa.
  static Future<String> toRelative(String absolutePath) async {
    if (kIsWeb) return p.basename(absolutePath);
    final docs = await getApplicationDocumentsDirectory();
    final normalizedPath = p.normalize(absolutePath);
    final normalizedDocs = p.normalize(docs.path);
    if (p.isWithin(normalizedDocs, normalizedPath) ||
        p.equals(normalizedDocs, p.dirname(normalizedPath))) {
      return p.relative(normalizedPath, from: normalizedDocs);
    }
    return p.basename(absolutePath);
  }

  /// Risolve il `storedPath` tentando in ordine quattro strategie:
  /// 1. `absolute` — `storedPath` è assoluto ed esiste (pre-0.3.4)
  /// 2. `relative` — `docsDir/storedPath` (caso normale nuovo)
  /// 3. `pdfs_basename` — `docsDir/pdfs/<basename>`
  /// 4. `basename` — `docsDir/<basename>` (backup repository)
  ///
  /// Se nessuno esiste il risultato ha `exists == false`, `reason ==
  /// 'not_found'` e `path` è comunque un candidato ragionevole (usato solo
  /// per messaggi di errore).
  static Future<ResolveResult> resolveDetailed(String storedPath) async {
    if (kIsWeb) {
      return ResolveResult(path: storedPath, exists: false, reason: 'not_found');
    }
    // 1. Assoluto esistente (dati pre-0.3.4) → pass-through.
    if (p.isAbsolute(storedPath)) {
      if (await File(storedPath).exists()) {
        return ResolveResult(
            path: storedPath, exists: true, reason: 'absolute');
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    // 2. Relativo normale.
    final candidateDirect = p.join(docs.path, storedPath);
    if (await File(candidateDirect).exists()) {
      return ResolveResult(
          path: candidateDirect, exists: true, reason: 'relative');
    }
    // 3. Stesso basename ma dentro `pdfs/` (import / import ZIP).
    final candidateInPdfs =
        p.join(docs.path, 'pdfs', p.basename(storedPath));
    if (await File(candidateInPdfs).exists()) {
      return ResolveResult(
          path: candidateInPdfs, exists: true, reason: 'pdfs_basename');
    }
    // 4. Stesso basename nella root della docs dir (backup repository).
    final candidateRoot = p.join(docs.path, p.basename(storedPath));
    if (await File(candidateRoot).exists()) {
      return ResolveResult(
          path: candidateRoot, exists: true, reason: 'basename');
    }
    // Nessuna strategia → candidato più probabile, ma segnaliamo l'assenza.
    return ResolveResult(
        path: candidateDirect, exists: false, reason: 'not_found');
  }

  /// Versione compatta: ritorna solo il path (esistente o migliore candidato).
  ///
  /// Mantenuta per retrocompatibilità con i call site che non distinguono
  /// il caso "file mancante". Dove serve sapere se esiste preferire
  /// [resolveDetailed].
  static Future<String> resolve(String storedPath) async {
    final r = await resolveDetailed(storedPath);
    return r.path;
  }
}
