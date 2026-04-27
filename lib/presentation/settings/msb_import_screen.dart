import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/msb_import_repository.dart';
import '../../providers/providers.dart';

/// Schermata dedicata all'import di backup MobileSheets `.msb`.
/// Stile coerente con `AutoUpdateScreen`: card stato + footer informativo.
class MsbImportScreen extends ConsumerStatefulWidget {
  const MsbImportScreen({super.key});

  @override
  ConsumerState<MsbImportScreen> createState() => _MsbImportScreenState();
}

class _MsbImportScreenState extends ConsumerState<MsbImportScreen> {
  bool _busy = false;
  String? _status;
  MsbImportOutcome? _outcome;
  Object? _error;

  Future<void> _pickAndImport() async {
    if (_busy) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      dialogTitle: 'Seleziona backup MobileSheets (.msb)',
    );
    if (picked == null || picked.files.single.path == null) return;
    final path = picked.files.single.path!;

    setState(() {
      _busy = true;
      _status = 'Avvio import…';
      _outcome = null;
      _error = null;
    });

    try {
      final repo = ref.read(msbImportRepositoryProvider);
      final outcome = await repo.importMsb(
        path,
        onProgress: (msg) {
          if (mounted) setState(() => _status = msg);
        },
      );
      if (!mounted) return;
      setState(() => _outcome = outcome);
      // Forza refresh dei provider che dipendono dal DB.
      ref.invalidate(songsProvider);
      ref.invalidate(setlistsProvider);
      ref.invalidate(collectionsProvider);
      ref.invalidate(composersProvider);
      ref.invalidate(libraryStatsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Importa da MobileSheets')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Header card ─────────────────────────────────────────────────
          _HeaderCard(theme: theme),
          const SizedBox(height: 16),

          // ── Stato corrente / risultato ─────────────────────────────────
          if (_busy) _ProgressCard(message: _status ?? 'Elaborazione…'),
          if (_error != null) _ErrorCard(error: _error!),
          if (_outcome != null) _OutcomeCard(outcome: _outcome!),

          const SizedBox(height: 16),
          // ── Bottone import ──────────────────────────────────────────────
          FilledButton.icon(
            onPressed: _busy ? null : _pickAndImport,
            icon: const Icon(Icons.file_upload_outlined),
            label: Text(_outcome != null
                ? 'Importa un altro backup'
                : 'Seleziona file .msb'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),

          const SizedBox(height: 24),

          // ── Footer informativo ──────────────────────────────────────────
          _FooterInfo(theme: theme),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final ThemeData theme;
  const _HeaderCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.swap_horiz,
                      size: 22, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Migra la tua libreria',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Seleziona un file backup .msb esportato da MobileSheets. '
              'Vengono importati: brani PDF, autori, setlist, raccolte, '
              'tonalità, generi e BPM (quando disponibili).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String message;
  const _ProgressCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(message,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  final MsbImportOutcome outcome;
  const _OutcomeCard({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = outcome.report;
    final ok = r.songsImported > 0;
    return Card(
      color: ok
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.check_circle : Icons.warning_amber_outlined,
                  color: ok
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ok ? 'Import completato' : 'Nessun brano importato',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ok
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              r.shortSummary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ok
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onErrorContainer,
              ),
            ),
            if (r.songsSkippedDuplicate > 0) ...[
              const SizedBox(height: 6),
              Text(
                '${r.songsSkippedDuplicate} brani già presenti saltati.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ok
                      ? theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.8)
                      : theme.colorScheme.onErrorContainer,
                ),
              ),
            ],
            if (outcome.conversionWarnings.isNotEmpty ||
                r.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(
                  'Dettagli (${outcome.conversionWarnings.length + r.warnings.length} avvisi)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ok
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onErrorContainer,
                  ),
                ),
                children: [
                  ...outcome.conversionWarnings.map((w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $w',
                            style: theme.textTheme.bodySmall),
                      )),
                  ...r.warnings.map((w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $w',
                            style: theme.textTheme.bodySmall),
                      )),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object error;
  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 10),
                Text('Errore durante l\'import',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterInfo extends StatelessWidget {
  final ThemeData theme;
  const _FooterInfo({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: theme.colorScheme.outline),
              const SizedBox(width: 8),
              Text('Come ottenere il backup',
                  style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Apri MobileSheets sul tuo dispositivo originale → Impostazioni → '
            'Backup → "Backup spartiti". Verrà creato un file con estensione '
            '.msb. Trasferiscilo qui (Drive, AirDrop, USB) e poi seleziona '
            'il file da questa schermata.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'I brani duplicati (stesso PDF) vengono saltati automaticamente. '
            'I brani che in MobileSheets sono "collegati" a file esterni '
            '(non incorporati nel backup) non vengono importati.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
