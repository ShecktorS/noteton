import 'package:flutter/material.dart';

/// Converte il colore esadecimale di un tag (es. "#FF5733") in [Color].
/// Ripiega su grigio se il valore non è valido.
Color parseTagColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return Colors.grey;
  }
}
