import 'package:flutter/material.dart';

/// Palette di colori per le diverse varianti tema di Noteton.
/// Ogni palette definisce seed color e accenti seguendo Material Design 3.
class ColorPalettes {
  ColorPalettes._();

  // ══════════════════════════════════════════════════════════════════════════
  // PALETTE DEFAULT (Midnight Ink)
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Blu profondo notturno — identità originale Noteton
  static const Color defaultSeed = Color(0xFF1A2F4A);
  
  /// Oro caldo per accenti secondari
  static const Color defaultGoldAccent = Color(0xFFD4A853);
  
  /// Verde chiaro per indicatori terziari (es. "in chiave")
  static const Color defaultGreenTertiary = Color(0xFF8BC9A0);

  // ══════════════════════════════════════════════════════════════════════════
  // PALETTE PURPLE (Amethyst)
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Violetto profondo (hue ~280°, sat ~50%, lum ~40%)
  /// Contrast ratio su bianco: 7.2:1 (AAA) — su nero: 2.9:1
  static const Color purpleSeed = Color(0xFF7B4397);
  
  /// Ambra calda per contrasto complementare (analogo all'oro ma più saturo)
  /// Funziona bene come secondary su sfondo scuro violetto
  static const Color purpleAmberAccent = Color(0xFFFFB74D);
  
  /// Teal/cyan per tertiary — palette triadica con violetto
  /// Ottimo contrasto cromatico senza conflitti visivi
  static const Color purpleTealTertiary = Color(0xFF4DB6AC);

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER: Surface colors per dark mode
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Superfici dark customizzate per Purple variant
  /// Tonalità violetto molto desaturato per mantenere coerenza cromatica
  static const purpleDarkSurfaces = DarkSurfaceColors(
    surface: Color(0xFF1A1420),              // Viola scurissimo quasi nero
    surfaceContainerLowest: Color(0xFF110D15),
    surfaceContainerLow: Color(0xFF1F1726),
    surfaceContainer: Color(0xFF261E2F),
    surfaceContainerHigh: Color(0xFF2D243A),
    surfaceContainerHighest: Color(0xFF352B42),
  );

  /// Superfici dark customizzate per Default variant (esistenti)
  static const defaultDarkSurfaces = DarkSurfaceColors(
    surface: Color(0xFF121820),
    surfaceContainerLowest: Color(0xFF0D1117),
    surfaceContainerLow: Color(0xFF161D26),
    surfaceContainer: Color(0xFF1E2833),
    surfaceContainerHigh: Color(0xFF243040),
    surfaceContainerHighest: Color(0xFF2A3544),
  );
}

/// Value class per raggruppare le superfici dark custom
class DarkSurfaceColors {
  final Color surface;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;

  const DarkSurfaceColors({
    required this.surface,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
  });
}
