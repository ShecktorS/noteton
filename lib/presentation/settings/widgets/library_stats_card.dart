import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/key_signature_localization.dart';
import '../../../domain/models/library_stats.dart';
import '../../../providers/providers.dart';

/// Card "La tua libreria" — riassunto numerico + grafici minimali.
class LibraryStatsCard extends ConsumerWidget {
  const LibraryStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(libraryStatsProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: asyncStats.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Errore caricamento statistiche: $e',
              style: theme.textTheme.bodySmall),
          data: (s) => _StatsContent(stats: s),
        ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  final LibraryStats stats;
  const _StatsContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.insights_outlined,
                size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text('La tua libreria',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 16),
        // Grid 2x2 di numeri principali
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: [
            _StatCell(
                icon: Icons.library_music_outlined,
                label: 'Spartiti',
                value: stats.totalSongs),
            _StatCell(
                icon: Icons.person_outline,
                label: 'Compositori',
                value: stats.totalComposers),
            _StatCell(
                icon: Icons.queue_music,
                label: 'Setlist',
                value: stats.totalSetlists),
            _StatCell(
                icon: Icons.collections_bookmark_outlined,
                label: 'Raccolte',
                value: stats.totalCollections),
          ],
        ),

        // Top tonalità
        if (stats.topKeys.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Tonalità più usate',
              style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          ..._buildKeyBars(context, stats, locale),
        ],

        // Distribuzione periodi
        if (stats.periodDistribution.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Per periodo',
              style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          _PeriodStackedBar(periods: stats.periodDistribution),
        ],
      ],
    );
  }

  List<Widget> _buildKeyBars(
      BuildContext context, LibraryStats s, Locale locale) {
    final maxCount = s.topKeys.first.count;
    final theme = Theme.of(context);
    return s.topKeys.map((entry) {
      final ratio = entry.count / maxCount;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                KeySignatureLocalization.display(entry.key, locale),
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  valueColor:
                      AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 24,
              child: Text('${entry.count}',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline)),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$value',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    )),
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        height: 1.1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodStackedBar extends StatelessWidget {
  final List<({String period, int count})> periods;
  const _PeriodStackedBar({required this.periods});

  static const _palette = [
    Color(0xFF7DCEA0), // menta
    Color(0xFF7FB3D5), // azzurro polvere
    Color(0xFFF4A261), // arancio caldo
    Color(0xFF9FA8DA), // lavanda
    Color(0xFFE57373), // rosso pastello
    Color(0xFFF4D35E), // giallo soft
    Color(0xFFC39BD3), // lilla
    Color(0xFF80CBC4), // acqua
    Color(0xFFFFAB91), // pesca
    Color(0xFFA8D5A2), // verde salvia
    Color(0xFFB0BEC5), // grigio bluastro
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = periods.fold<int>(0, (a, b) => a + b.count);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra stacked
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: List.generate(periods.length, (i) {
                final color = _palette[i % _palette.length];
                return Expanded(
                  flex: periods[i].count,
                  child: Container(color: color),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: List.generate(periods.length, (i) {
            final color = _palette[i % _palette.length];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '${periods[i].period} · ${periods[i].count}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}
