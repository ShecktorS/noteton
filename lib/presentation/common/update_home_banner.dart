import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/release_info.dart';
import '../../providers/providers.dart';

/// Card "aggiornamento disponibile" da mostrare in cima alla libreria.
/// Visibile solo quando:
///   - lo stato update è [UpdateAvailable]
///   - il toggle auto-update è ON (altrimenti l'utente non vuole essere
///     disturbato fuori da Settings)
///   - l'utente non ha dismesso questa versione nella sessione corrente
///
/// Tap su X → dismiss per la sessione (ricompare al prossimo lancio).
/// Tap su "Aggiorna ora" → avvia download + apre progress dialog.
/// Tap su "Leggi tutto" → mostra dialog completo con changelog.
class UpdateHomeBanner extends ConsumerWidget {
  const UpdateHomeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    final autoEnabled = ref.watch(autoUpdateEnabledProvider);
    final dismissed = ref.watch(dismissedBannerVersionsProvider);

    if (state is! UpdateAvailable ||
        !autoEnabled ||
        dismissed.contains(state.release.version)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: _BannerCard(
        release: state.release,
        onDismiss: () {
          ref.read(dismissedBannerVersionsProvider.notifier).update(
                (s) => {...s, state.release.version},
              );
        },
        onUpdate: () {
          ref.read(updateProvider.notifier).downloadAndInstall(state.release);
          _showDownloadDialog(context, ref);
        },
        onReadMore: () => _showFullDialog(context, ref, state.release),
      ),
    );
  }

  // ── Dialog completo (clone leggero del gate dialog) ─────────────────────────

  void _showFullDialog(BuildContext context, WidgetRef ref, ReleaseInfo r) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text('Aggiornamento v${r.version}')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360, maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pubblicato il ${r.formattedDate}',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    r.changelog.trim().isEmpty
                        ? 'Nessuna nota di rilascio fornita.'
                        : r.changelog.trim(),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Aggiorna ora'),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(updateProvider.notifier).downloadAndInstall(r);
              _showDownloadDialog(context, ref);
            },
          ),
        ],
      ),
    );
  }

  void _showDownloadDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final state = ref.watch(updateProvider);
          if (state is! UpdateDownloading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(ctx)) Navigator.pop(ctx);
            });
          }
          final progress =
              state is UpdateDownloading ? state.progress : 0.0;
          return AlertDialog(
            title: const Text('Download in corso'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final ReleaseInfo release;
  final VoidCallback onDismiss;
  final VoidCallback onUpdate;
  final VoidCallback onReadMore;

  const _BannerCard({
    required this.release,
    required this.onDismiss,
    required this.onUpdate,
    required this.onReadMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Anteprima changelog: max 3 righe del body markdown (puliamo i ###)
    final preview = _previewChangelog(release.changelog);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.system_update_outlined,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aggiornamento v${release.version} disponibile',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Pubblicato il ${release.formattedDate}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: theme.colorScheme.onPrimaryContainer,
                  tooltip: 'Più tardi',
                  onPressed: onDismiss,
                ),
              ],
            ),
            // Anteprima changelog
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 8),
                child: Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ),
            ],
            // Actions
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                children: [
                  TextButton(
                    onPressed: onReadMore,
                    style: TextButton.styleFrom(
                      foregroundColor:
                          theme.colorScheme.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Leggi tutto'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Aggiorna ora'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.onPrimaryContainer,
                      foregroundColor: theme.colorScheme.primaryContainer,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onUpdate,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Estrae un'anteprima leggibile dal changelog markdown della release.
  /// Rimuove header `##`, `###`, blockquote `>`, prende le prime righe non vuote.
  String _previewChangelog(String md) {
    final lines = md
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .where((l) => !l.startsWith('#'))
        .where((l) => !l.startsWith('>'))
        .where((l) => !l.startsWith('---'))
        .toList();
    if (lines.isEmpty) return '';
    final preview = lines.take(4).join(' ');
    return preview;
  }
}
