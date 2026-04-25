import 'package:flutter/widgets.dart';

/// Converts stored key signature values (English notation: C, C#, Db…)
/// to the display string for the current locale.
///
/// Italian locale uses solfège names: Do, Do♯, Re♭, Re, Mi♭, Mi, Fa, Fa♯,
/// Sol♭, Sol, La♭, La, Si♭, Si.
/// All other locales keep the original English notation.
class KeySignatureLocalization {
  KeySignatureLocalization._();

  static const Map<String, String> _enToIt = {
    'C': 'Do',
    'C#': 'Do♯',
    'Db': 'Re♭',
    'D': 'Re',
    'Eb': 'Mi♭',
    'E': 'Mi',
    'F': 'Fa',
    'F#': 'Fa♯',
    'Gb': 'Sol♭',
    'G': 'Sol',
    'Ab': 'La♭',
    'A': 'La',
    'Bb': 'Si♭',
    'B': 'Si',
  };

  /// Returns the display string for [stored] key (as saved in DB)
  /// according to [locale]. Falls back to [stored] if no mapping found.
  static String display(String stored, Locale locale) {
    if (locale.languageCode != 'it') return stored;

    // Minor keys end with 'm': 'Cm', 'C#m', 'Ebm'…
    if (stored.endsWith('m')) {
      final noteKey = stored.substring(0, stored.length - 1);
      final it = _enToIt[noteKey];
      return it != null ? '$it m' : stored;
    }

    return _enToIt[stored] ?? stored;
  }

  /// The canonical list of storable key signature values (English notation).
  static const List<String> values = [
    'C', 'C#', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
    'Cm', 'C#m', 'Dm', 'Ebm', 'Em', 'Fm', 'F#m', 'Gm', 'Abm', 'Am', 'Bbm', 'Bm',
  ];

  /// Returns dropdown item pairs [{stored, display}] for the given locale.
  static List<({String stored, String label})> items(Locale locale) {
    return values
        .map((v) => (stored: v, label: display(v, locale)))
        .toList();
  }

  // ── Split / Join per il picker "Modo + Nota" ─────────────────────────────
  //
  // Il KeySignaturePicker mostra due selettori indipendenti:
  //   • Modo: maggiore / minore
  //   • Nota: una delle 14 note distinte presenti nelle tonalità maggiori
  //
  // Il DB continua a memorizzare la stringa singola ('C', 'C#m', ...).
  // Questi helper convertono fra le due rappresentazioni.

  /// Note distinte usate dal picker, in ordine di lettura "circolo":
  /// Do, Do♯, Re♭, Re, Mi♭, Mi, Fa, Fa♯, Sol♭, Sol, La♭, La, Si♭, Si.
  /// Ogni elemento è la rappresentazione "nota" in notazione inglese
  /// (senza la 'm' del modo minore).
  static const List<String> notesEnglish = [
    'C', 'C#', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
  ];

  /// Estrae (nota, modoMinore) da una stringa storage tipo 'C', 'Cm', 'F#m'.
  /// Ritorna null se la stringa non è una tonalità riconosciuta.
  static ({String note, bool isMinor})? splitKey(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    final isMinor = stored.endsWith('m');
    final note = isMinor ? stored.substring(0, stored.length - 1) : stored;
    if (!notesEnglish.contains(note)) return null;
    return (note: note, isMinor: isMinor);
  }

  /// Compone la stringa storage da nota e modo.
  /// Esempio: joinKey('F#', isMinor: true) → 'F#m'.
  static String joinKey(String note, {required bool isMinor}) {
    return isMinor ? '${note}m' : note;
  }

  /// Etichetta breve della nota nella locale fornita
  /// (es. 'C' → 'Do', 'F#' → 'Fa♯' in italiano).
  static String displayNote(String note, Locale locale) {
    if (locale.languageCode != 'it') return note;
    return _enToIt[note] ?? note;
  }
}
