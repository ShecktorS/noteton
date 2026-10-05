import 'package:flutter/material.dart';

/// Token della linea di brand Noteton ("Inchiostro e accento").
///
/// Sono valori che non dipendono dalla variante colore: tutte le palette
/// (Midnight Ink, Amethyst, …) condividono forme, spaziature e motivi.
/// I colori arrivano sempre dal [ColorScheme] corrente.
/// Riferimento completo: `docs/brand.md`.
class NotetonBrand {
  NotetonBrand._();

  // ── Spaziature (griglia da 4) ──────────────────────────────────────────────
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;

  // ── Raggi ──────────────────────────────────────────────────────────────────
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;

  // ── Motivi ─────────────────────────────────────────────────────────────────
  /// Spessore della "stanghetta" d'accento sul bordo sinistro delle card
  /// che portano un messaggio (aggiornamenti, novità, avvisi).
  static const double barlineWidth = 4;

  /// Distanza tra le righe del pentagramma decorativo.
  static const double staffGap = 7;

  /// Opacità delle righe del pentagramma: deve restare una texture,
  /// mai competere con il testo.
  static const double staffOpacity = 0.10;

  /// Colore d'accento del brand (oro / ambra) leggibile sul tema corrente.
  ///
  /// Nel dark usa direttamente `secondary`. Nel light l'oro puro non ha
  /// contrasto sufficiente sul bianco, quindi viene scurito verso
  /// l'inchiostro fino a superare 4.5:1.
  static Color accent(ColorScheme cs) {
    if (cs.brightness == Brightness.dark) return cs.secondary;
    return Color.lerp(cs.secondary, Colors.black, 0.45)!;
  }

  /// Stile "occhiello": etichetta maiuscola spaziata sopra i titoli
  /// (es. NUOVA VERSIONE). Richiama le indicazioni agogiche sullo spartito.
  static TextStyle eyebrow(ThemeData theme) {
    final base = theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11);
    return base.copyWith(
      color: accent(theme.colorScheme),
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
      height: 1.2,
    );
  }
}
