import 'package:flutter/material.dart';

import '../../../domain/models/song.dart';

/// Barra laterale A-Z per saltare ai brani che iniziano con una lettera.
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
  bool _hasLetter(String letter) {
    return widget.songs.any((s) {
      final first =
          s.title.trim().isNotEmpty ? s.title.trim()[0].toUpperCase() : '#';
      if (letter == '#') return !RegExp(r'[A-Z]').hasMatch(first);
      return first == letter;
    });
  }

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
