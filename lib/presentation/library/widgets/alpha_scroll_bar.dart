import 'package:flutter/material.dart';

import '../../../domain/models/song.dart';

/// Lettera con cui un titolo compare nella barra A-Z: la prima lettera
/// maiuscola, oppure `#` per titoli vuoti o che iniziano con altro.
String alphaIndexLetter(String title) {
  final trimmed = title.trim();
  final first = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '#';
  return RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
}

/// Indice del primo brano che inizia con [letter], o -1 se non c'è.
int indexOfAlphaLetter(List<Song> songs, String letter) =>
    songs.indexWhere((s) => alphaIndexLetter(s.title) == letter);

/// Barra verticale A-Z a destra della libreria: tocco o trascinamento
/// selezionano una lettera.
class AlphaScrollBar extends StatefulWidget {
  final List<Song> songs;
  final void Function(String letter) onLetterSelected;

  const AlphaScrollBar({
    super.key,
    required this.songs,
    required this.onLetterSelected,
  });

  @override
  State<AlphaScrollBar> createState() => _AlphaScrollBarState();
}

class _AlphaScrollBarState extends State<AlphaScrollBar> {
  static const _letters = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  String? _activeLetter;

  // Returns true if at least one song starts with this letter
  bool _hasLetter(String letter) =>
      indexOfAlphaLetter(widget.songs, letter) >= 0;

  void _onDrag(Offset localPosition, BoxConstraints constraints) {
    final frac = (localPosition.dy / constraints.maxHeight).clamp(0.0, 0.999);
    final index = (frac * _letters.length).floor();
    final letter = _letters[index];
    if (letter != _activeLetter) {
      setState(() => _activeLetter = letter);
      widget.onLetterSelected(letter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (d) => _onDrag(d.localPosition, constraints),
          onVerticalDragUpdate: (d) => _onDrag(d.localPosition, constraints),
          onVerticalDragEnd: (_) => setState(() => _activeLetter = null),
          onTapDown: (d) {
            _onDrag(d.localPosition, constraints);
            setState(() => _activeLetter = null);
          },
          child: SizedBox(
            width: 20,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _letters.map((letter) {
                final active = _activeLetter == letter;
                final present = _hasLetter(letter);
                return Expanded(
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: active ? 13 : 9,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: present
                            ? (active ? cs.primary : cs.onSurfaceVariant)
                            : cs.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
