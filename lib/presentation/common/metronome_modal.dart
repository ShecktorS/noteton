import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/metronome_service.dart';
import '../../providers/providers.dart';
import 'metronome_pendulum.dart';

/// Apre la modale del metronomo come bottom sheet draggable.
/// Il servizio è singleton globale: chiudere la modale NON ferma il metronomo.
Future<void> showMetronomeModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MetronomeModalContent(),
  );
}

class _MetronomeModalContent extends ConsumerWidget {
  const _MetronomeModalContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(metronomeServiceProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('Metronomo',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  // ── Pendolo + beat dots ───────────────────────────────────
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: MetronomePendulum(
                      bpm: m.bpm,
                      isRunning: m.isRunning,
                      isDownbeat: m.isDownbeat,
                      beatIndex: m.beatIndex,
                      beatsPerBar: m.timeSignature.beats,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── BPM display + slider ──────────────────────────────────
                  _BpmControl(service: m),

                  const SizedBox(height: 12),
                  // ── Time signature ────────────────────────────────────────
                  Text('Tempo',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: TimeSignature.presets.map((ts) {
                      final selected = m.timeSignature == ts;
                      return ChoiceChip(
                        label: Text(ts.label),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) =>
                            ref.read(metronomeServiceProvider).setTimeSignature(ts),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  // ── Sound + volume ────────────────────────────────────────
                  Text('Suono',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: MetronomeSound.values.map((s) {
                      final selected = m.sound == s;
                      return ChoiceChip(
                        label: Text(s.label),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) =>
                            ref.read(metronomeServiceProvider).setSound(s),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.volume_down,
                          size: 22, color: theme.colorScheme.outline),
                      Expanded(
                        child: Slider(
                          value: m.volume,
                          onChanged: (v) =>
                              ref.read(metronomeServiceProvider).setVolume(v),
                        ),
                      ),
                      Icon(Icons.volume_up,
                          size: 22, color: theme.colorScheme.outline),
                    ],
                  ),

                  const SizedBox(height: 24),
                  // ── Play / Pause ──────────────────────────────────────────
                  Center(
                    child: _PlayButton(service: m),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BpmControl extends ConsumerWidget {
  final MetronomeService service;
  const _BpmControl({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.remove),
              onPressed: () =>
                  ref.read(metronomeServiceProvider).adjustBpm(-1),
            ),
            const SizedBox(width: 24),
            Column(
              children: [
                Text(
                  '${service.bpm}',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text('BPM',
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 1.5,
                      color: theme.colorScheme.outline,
                    )),
              ],
            ),
            const SizedBox(width: 24),
            IconButton.filledTonal(
              icon: const Icon(Icons.add),
              onPressed: () =>
                  ref.read(metronomeServiceProvider).adjustBpm(1),
            ),
          ],
        ),
        Slider(
          value: service.bpm.toDouble(),
          min: 40,
          max: 240,
          divisions: 200,
          label: '${service.bpm}',
          onChanged: (v) =>
              ref.read(metronomeServiceProvider).setBpm(v.round()),
        ),
      ],
    );
  }
}

class _PlayButton extends ConsumerWidget {
  final MetronomeService service;
  const _PlayButton({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => ref.read(metronomeServiceProvider).toggle(),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              spreadRadius: service.isRunning ? 4 : 0,
            ),
          ],
        ),
        child: Icon(
          service.isRunning ? Icons.pause : Icons.play_arrow,
          size: 38,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}
