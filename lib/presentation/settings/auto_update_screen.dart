import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/release_info.dart';
import '../../domain/models/update_channel.dart';
import '../../providers/providers.dart';

/// Schermata dedicata "Aggiornamento automatico".
/// Stile Telegram: toggle on/off in alto, bottone "Controlla ora" in basso,
/// e card di stato (disponibile / download / errore) tra i due.
class AutoUpdateScreen extends ConsumerWidget {
  const AutoUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(autoUpdateEnabledProvider);
    final channel = ref.watch(updateChannelProvider);
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Canale aggiornamenti',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      channel == UpdateChannel.beta
                          ? 'Ricevi versioni stabili e beta di prova.'
                          : 'Ricevi solo versioni ufficiali consigliate.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<UpdateChannel>(
                        segments: const [
                          ButtonSegment(
                            value: UpdateChannel.stable,
                            icon: Icon(Icons.verified_outlined),
                            label: Text('Stabile'),
                          ),
                          ButtonSegment(
                            value: UpdateChannel.beta,
                            icon: Icon(Icons.science_outlined),
                            label: Text('Beta'),
                          ),
                        ],
                        selected: {channel},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) => _setChannel(
                          context,
                          ref,
                          selection.first,
                        ),
                      ),
                    ),
                    if (channel == UpdateChannel.beta) ...[
                      const SizedBox(height: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 18,
                                  color: colorScheme.onTertiaryContainer),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Le beta possono contenere bug. Puoi tornare '
                                  'al canale stabile in qualsiasi momento.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color:
                                            colorScheme.onTertiaryContainer,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

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
                        ? 'Quando esce una nuova versione nel canale scelto, '
                            'l\'app te lo segnala all\'avvio mostrando il '
                            'changelog. Puoi rimandare con "Più tardi" o '
                            'aggiornare subito.'
                        : 'Aggiornamenti automatici disattivati. Puoi comunque '
                            'controllare manualmente il canale scelto con il '
                            'bottone qui sopra.',
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

  Future<void> _setChannel(
    BuildContext context,
    WidgetRef ref,
    UpdateChannel next,
  ) async {
    final current = ref.read(updateChannelProvider);
    if (next == current) return;

    if (next == UpdateChannel.beta) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Abilitare il canale beta?'),
          content: const Text(
            'Riceverai anche versioni di prova con funzionalità nuove. '
            'Potrebbero contenere bug o regressioni: puoi tornare al canale '
            'stabile in qualsiasi momento.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abilita beta'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await ref.read(updateChannelProvider.notifier).setChannel(next);
    if (!context.mounted) return;
    final label = next == UpdateChannel.beta ? 'beta' : 'stabile';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Canale aggiornamenti impostato su $label.')),
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
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Aggiornamento disponibile',
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      if (release.prerelease)
                        _BetaBadge(
                          foreground: colorScheme.onPrimaryContainer,
                          background: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.12),
                        ),
                    ],
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

class _BetaBadge extends StatelessWidget {
  final Color foreground;
  final Color background;

  const _BetaBadge({
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          'BETA',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
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
