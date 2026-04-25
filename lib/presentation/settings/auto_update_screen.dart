import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/release_info.dart';
import '../../providers/providers.dart';

/// Schermata dedicata "Aggiornamento automatico".
/// Stile Telegram: toggle on/off in alto, bottone "Controlla ora" in basso,
/// e card di stato (disponibile / download / errore) tra i due.
class AutoUpdateScreen extends ConsumerWidget {
  const AutoUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(autoUpdateEnabledProvider);
    final updateState = ref.watch(updateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Aggiornamento automatico')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Toggle principale ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => ref
                    .read(autoUpdateEnabledProvider.notifier)
                    .setEnabled(!enabled),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Abilita l\'aggiornamento',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Switch(
                        value: enabled,
                        onChanged: (v) => ref
                            .read(autoUpdateEnabledProvider.notifier)
                            .setEnabled(v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Stato corrente ────────────────────────────────────────────────
          if (updateState is UpdateAvailable)
            _UpdateAvailableCard(
              release: updateState.release,
              onInstall: () => ref
                  .read(updateProvider.notifier)
                  .downloadAndInstall(updateState.release),
              onDismiss: () => ref
                  .read(updateProvider.notifier)
                  .dismiss(updateState.release.version),
            ),
          if (updateState is UpdateDownloading)
            _UpdateDownloadingCard(progress: updateState.progress),
          if (updateState is UpdateError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                tileColor: colorScheme.errorContainer.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                leading: Icon(Icons.warning_amber, color: colorScheme.error),
                title: Text(updateState.message),
                subtitle: updateState.detail != null
                    ? Text(
                        updateState.detail!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
              ),
            ),
          if (updateState is UpdateUpToDate)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                tileColor: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                leading: Icon(Icons.check_circle_outline,
                    color: colorScheme.primary),
                title: const Text('App aggiornata'),
                subtitle: const Text('Stai usando l\'ultima versione.'),
              ),
            ),

          // ── Bottone check manuale ─────────────────────────────────────────
          const SizedBox(height: 16),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: (updateState is UpdateChecking ||
                      updateState is UpdateDownloading)
                  ? null
                  : () => _checkNow(context, ref),
              icon: updateState is UpdateChecking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: const Text('Controlla gli aggiornamenti'),
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),

          // ── Info footer ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: colorScheme.outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    enabled
                        ? 'Quando esce una nuova versione, l\'app te lo segnala '
                            'all\'avvio mostrando il changelog. Puoi rimandare '
                            'con "Più tardi" o aggiornare subito.'
                        : 'Aggiornamenti automatici disattivati. Puoi comunque '
                            'controllare manualmente con il bottone qui sopra.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkNow(BuildContext context, WidgetRef ref) async {
    await ref.read(updateProvider.notifier).check(force: true);
    if (!context.mounted) return;
    final state = ref.read(updateProvider);
    if (state is UpdateUpToDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sei già aggiornato.')),
      );
    }
  }
}

// ── Update cards (private — riusate solo qui) ──────────────────────────────

class _UpdateAvailableCard extends StatelessWidget {
  final ReleaseInfo release;
  final VoidCallback onInstall;
  final VoidCallback onDismiss;

  const _UpdateAvailableCard({
    required this.release,
    required this.onInstall,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.system_update,
                    color: colorScheme.onPrimaryContainer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aggiornamento disponibile',
                    style: textTheme.titleSmall
                        ?.copyWith(color: colorScheme.onPrimaryContainer),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 18, color: colorScheme.onPrimaryContainer),
                  tooltip: 'Ignora questa versione',
                  onPressed: onDismiss,
                ),
              ],
            ),
            Text(
              'Versione ${release.version} · ${release.formattedDate}',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onInstall,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Scarica e installa'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateDownloadingCard extends StatelessWidget {
  final double progress;
  const _UpdateDownloadingCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: progress > 0 ? progress : null,
                    strokeWidth: 2,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Download in corso… '
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onPrimaryContainer),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              backgroundColor:
                  colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}
