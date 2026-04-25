import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visualizzazione del beat: pendolo che oscilla a tempo + cerchio centrale
/// che pulsa sul tick. Il downbeat è marcato con un colore di accento.
///
/// Pilotato dall'esterno: [bpm], [isRunning], [isDownbeat], [beatIndex],
/// [beatsPerBar]. Il widget calcola la propria animazione al cambio di [bpm]
/// senza richiedere un Ticker per ciascun click — un AnimationController
/// resta attivo finché il metronomo è in esecuzione.
class MetronomePendulum extends StatefulWidget {
  final int bpm;
  final bool isRunning;
  final bool isDownbeat;
  final int beatIndex;
  final int beatsPerBar;

  const MetronomePendulum({
    super.key,
    required this.bpm,
    required this.isRunning,
    required this.isDownbeat,
    required this.beatIndex,
    required this.beatsPerBar,
  });

  @override
  State<MetronomePendulum> createState() => _MetronomePendulumState();
}

class _MetronomePendulumState extends State<MetronomePendulum>
    with SingleTickerProviderStateMixin {
  late AnimationController _swing;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Periodo del pendolo = un beat (60s/bpm). Va da -1 a +1 e ritorna,
    // ma noi usiamo `value 0..1` per un'oscillazione completa (left → right → left).
    _swing = AnimationController(
      duration: _swingDuration(widget.bpm),
      vsync: this,
    );
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    if (widget.isRunning) _swing.repeat();
  }

  Duration _swingDuration(int bpm) {
    // Un'oscillazione completa = 2 beat (left→right + right→left)
    final ms = (60000 / bpm * 2).round();
    return Duration(milliseconds: ms);
  }

  @override
  void didUpdateWidget(covariant MetronomePendulum old) {
    super.didUpdateWidget(old);
    if (old.bpm != widget.bpm) {
      _swing.duration = _swingDuration(widget.bpm);
      if (widget.isRunning) _swing.repeat();
    }
    if (old.isRunning != widget.isRunning) {
      if (widget.isRunning) {
        _swing.repeat();
      } else {
        _swing.stop();
        _swing.value = 0;
      }
    }
    if (old.beatIndex != widget.beatIndex && widget.isRunning) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _swing.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final base = theme.colorScheme.outline.withValues(alpha: 0.5);

    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: Listenable.merge([_swing, _pulse]),
        builder: (context, _) {
          // 0..1 → mappa a -1..1 con seno per oscillazione fluida
          final swing = math.sin(_swing.value * 2 * math.pi);
          final pulse = 1 - _pulse.value;
          return CustomPaint(
            painter: _PendulumPainter(
              swing: swing,
              pulse: pulse,
              isDownbeat: widget.isDownbeat,
              accentColor: accent,
              baseColor: base,
              beatIndex: widget.beatIndex,
              beatsPerBar: widget.beatsPerBar,
              isRunning: widget.isRunning,
            ),
          );
        },
      ),
    );
  }
}

class _PendulumPainter extends CustomPainter {
  final double swing; // -1..+1
  final double pulse; // 0..1, 1 = appena tickato
  final bool isDownbeat;
  final int beatIndex;
  final int beatsPerBar;
  final bool isRunning;
  final Color accentColor;
  final Color baseColor;

  _PendulumPainter({
    required this.swing,
    required this.pulse,
    required this.isDownbeat,
    required this.beatIndex,
    required this.beatsPerBar,
    required this.isRunning,
    required this.accentColor,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final pendulumLength = size.height * 0.65;

    // ── Beat dots in alto ───────────────────────────────────────────────────
    final dotsY = size.height * 0.08;
    final dotSpacing = math.min(28.0, size.width / (beatsPerBar + 1));
    final dotsStartX = (size.width - dotSpacing * (beatsPerBar - 1)) / 2;
    for (int i = 0; i < beatsPerBar; i++) {
      final isActive = isRunning && i == beatIndex;
      final isFirst = i == 0;
      final dotPaint = Paint()
        ..color = isActive
            ? (isFirst ? accentColor : accentColor.withValues(alpha: 0.85))
            : baseColor.withValues(alpha: isFirst ? 0.6 : 0.35);
      canvas.drawCircle(
        Offset(dotsStartX + i * dotSpacing, dotsY),
        isFirst ? 4.5 : 3.5,
        dotPaint,
      );
    }

    // ── Pendolo ─────────────────────────────────────────────────────────────
    // Massimo angolo di oscillazione ±25° in radianti
    const maxAngle = 25 * math.pi / 180;
    final angle = swing * maxAngle * (isRunning ? 1 : 0);

    final pendulumEnd = Offset(
      center.dx + math.sin(angle) * pendulumLength,
      center.dy - math.cos(angle) * pendulumLength,
    );

    // Linea
    final linePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, pendulumEnd, linePaint);

    // Massa pendolo
    final bobColor = isRunning && pulse > 0.3
        ? (isDownbeat ? accentColor : accentColor.withValues(alpha: 0.9))
        : baseColor;
    final bobRadius = 12 + pulse * 4;
    canvas.drawCircle(pendulumEnd, bobRadius, Paint()..color = bobColor);

    // ── Cerchio centrale pulsante ───────────────────────────────────────────
    if (isRunning) {
      final pulseColor = (isDownbeat ? accentColor : accentColor.withValues(alpha: 0.7))
          .withValues(alpha: pulse * 0.4);
      canvas.drawCircle(
        center,
        14 + pulse * 22,
        Paint()..color = pulseColor,
      );
    }
    // Punto di ancoraggio
    canvas.drawCircle(
      center,
      4,
      Paint()..color = baseColor.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _PendulumPainter old) =>
      old.swing != swing ||
      old.pulse != pulse ||
      old.isDownbeat != isDownbeat ||
      old.beatIndex != beatIndex ||
      old.beatsPerBar != beatsPerBar ||
      old.isRunning != isRunning;
}
