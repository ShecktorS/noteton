import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/brand.dart';

/// Pentagramma decorativo: cinque righe orizzontali sottili.
/// Va usato come texture di sfondo (es. dentro uno [Stack]) e non
/// porta informazione, quindi è escluso dalla semantica.
class StaffLines extends StatelessWidget {
  final Color? color;
  final double gap;

  const StaffLines({super.key, this.color, this.gap = NotetonBrand.staffGap});

  @override
  Widget build(BuildContext context) {
    final c = color ??
        Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: NotetonBrand.staffOpacity);
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _StaffPainter(color: c, gap: gap),
        size: Size(double.infinity, gap * 4 + 1),
      ),
    );
  }
}

class _StaffPainter extends CustomPainter {
  final Color color;
  final double gap;

  _StaffPainter({required this.color, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final top = (size.height - gap * 4) / 2;
    for (var i = 0; i < 5; i++) {
      final y = top + i * gap + 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_StaffPainter old) =>
      old.color != color || old.gap != gap;
}

/// Testa di nota (ovale inclinato pieno) usata come punto elenco.
class NoteHeadBullet extends StatelessWidget {
  final Color color;
  final double size;

  const NoteHeadBullet({super.key, required this.color, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(size * 1.3, size),
        painter: _NoteHeadPainter(color),
      ),
    );
  }
}

class _NoteHeadPainter extends CustomPainter {
  final Color color;

  _NoteHeadPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-20 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset.zero, width: size.width, height: size.height * 0.78),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NoteHeadPainter old) => old.color != color;
}

/// Etichetta "occhiello" del brand, eventualmente seguita da un badge.
class BrandEyebrow extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const BrandEyebrow(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text.toUpperCase(), style: NotetonBrand.eyebrow(Theme.of(context))),
        if (trailing != null) ...[
          const SizedBox(width: NotetonBrand.space2),
          trailing!,
        ],
      ],
    );
  }
}

/// Badge "BETA" a pillola, con i colori dell'accento del brand.
class BrandBetaBadge extends StatelessWidget {
  const BrandBetaBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = NotetonBrand.accent(theme.colorScheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          'BETA',
          style: NotetonBrand.eyebrow(theme).copyWith(
            fontSize: 9.5,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
