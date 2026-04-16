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
}
