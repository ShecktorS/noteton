import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/checkpoint_service.dart';
import '../../core/services/library_health_service.dart';
import '../../data/database/database_helper.dart';
import '../../providers/providers.dart';

/// Pannello diagnostico nascosto — accessibile solo via 7-tap sulla label
/// della versione in Settings. Non deve essere pubblicizzato nella UI.
class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  final _health = const LibraryHealthService();
  final _checkpoints = const CheckpointService();

  HealthReport? _lastReport;
  List<CheckpointInfo> _cps = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshCheckpoints();
  }

  Future<void> _refreshCheckpoints() async {
    final list = await _checkpoints.list();
    if (mounted) setState(() => _cps = list);
  }

  Future<void> _runHealthCheck() async {
    setState(() => _loading = true);
    try {
      final r = await _health.scan();
      if (mounted) setState(() => _lastReport = r);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _backfillHashes() async {
    setState(() => _loading = true);
    try {
      final n = await _health.backfillFileHashes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aggiornati $n brani con nuovo hash.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteOrphanRecords() async {
    final report = _lastReport;
    if (report == null || report.orphanRecords.isEmpty) return;
    final ok = await _confirm(
      'Eliminare ${report.orphanRecords.length} record orfani dal DB?',
      'I file PDF non sono presenti sul dispositivo, quindi queste righe non sono più utili.',
    );
    if (ok != true) return;
    final n = await _health.deleteOrphanRecords(report.orphanRecords);
    ref.invalidate(songsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eliminati $n record.')),
      );
    }
    await _runHealthCheck();
  }

  Future<void> _deleteOrphanFiles() async {
    final report = _lastReport;
    if (report == null || report.orphanFiles.isEmpty) return;
    final ok = await _confirm(
      'Eliminare ${report.orphanFiles.length} file PDF orfani?',
      'Questi file non sono referenziati da nessun brano in libreria.',
    );
    if (ok != true) return;
    final n = await _health.deleteOrphanFiles(report.orphanFiles);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eliminati $n file.')),
      );
    }
    await _runHealthCheck();
  }

  Future<void> _createCheckpoint() async {
    setState(() => _loading = true);
    try {
      await _checkpoints.create('manuale');
      await _refreshCheckpoints();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checkpoint creato.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore checkpoint: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreCheckpoint(CheckpointInfo cp) async {
    final ok = await _confirm(
      'Ripristinare da checkpoint?',
      'Lo stato attuale verrà sostituito da quello del checkpoint '
          '"${cp.displayName}". L\'app si chiuderà e dovrai riavviarla.',
      destructiveLabel: 'Ripristina',
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      await DatabaseHelper.instance.closeAndReset();
      await _checkpoints.restore(cp);
      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Ripristino completato'),
            content: const Text(
                'Premi "Chiudi app" per riavviarla e caricare i dati ripristinati.'),
            actions: [
              FilledButton.icon(
                icon: const Icon(Icons.power_settings_new, size: 18),
                label: const Text('Chiudi app'),
                onPressed: () => exit(0),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore ripristino: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteCheckpoint(CheckpointInfo cp) async {
    final ok = await _confirm(
      'Eliminare questo checkpoint?',
      cp.displayName,
    );
    if (ok != true) return;
    await _checkpoints.delete(cp);
    await _refreshCheckpoints();
  }

  Future<bool?> _confirm(
    String title,
    String body, {
    String destructiveLabel = 'Elimina',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(destructiveLabel,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostica')),
      body: Stack(
        children: [
          ListView(
            children: [
              const _H('Salute libreria'),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: const Text('Esegui controllo'),
                subtitle: const Text(
                    'Cerca record senza PDF e file PDF senza record'),
                onTap: _loading ? null : _runHealthCheck,
              ),
              if (_lastReport != null) _HealthReportCard(report: _lastReport!),
              if (_lastReport != null &&
                  _lastReport!.orphanRecords.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                  title: Text(
                      'Elimina ${_lastReport!.orphanRecords.length} record orfani'),
                  onTap: _loading ? null : _deleteOrphanRecords,
                ),
              if (_lastReport != null && _lastReport!.orphanFiles.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                  title: Text(
                      'Elimina ${_lastReport!.orphanFiles.length} file PDF orfani'),
                  onTap: _loading ? null : _deleteOrphanFiles,
                ),
              const Divider(),
              const _H('Manutenzione'),
              ListTile(
                leading: const Icon(Icons.fingerprint),
                title: const Text('Ricalcola hash mancanti'),
                subtitle: const Text(
                    'Utile per il dedup retroattivo dei backup importati'),
                onTap: _loading ? null : _backfillHashes,
              ),
              const Divider(),
              const _H('Checkpoint'),
              ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: const Text('Crea checkpoint manuale'),
                subtitle:
                    const Text('Salva uno snapshot dello stato attuale'),
                onTap: _loading ? null : _createCheckpoint,
              ),
              if (_cps.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nessun checkpoint disponibile.'),
                )
              else
                ..._cps.map((cp) => Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(cp.reason),
                        subtitle: Text(
                          '${cp.createdAt.toLocal().toIso8601String().substring(0, 19).replaceAll('T', ' ')}\n'
                          '${cp.pdfCount} PDF · ${_formatBytes(cp.totalBytes)}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Ripristina',
                              icon: const Icon(Icons.restore),
                              onPressed:
                                  _loading ? null : () => _restoreCheckpoint(cp),
                            ),
                            IconButton(
                              tooltip: 'Elimina',
                              icon: const Icon(Icons.delete_outline),
                              onPressed:
                                  _loading ? null : () => _deleteCheckpoint(cp),
                            ),
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 32),
            ],
          ),
          if (_loading)
            const ColoredBox(
              color: Colors.black45,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class _H extends StatelessWidget {
  final String title;
  const _H(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                )),
      );
}

class _HealthReportCard extends StatelessWidget {
  final HealthReport report;
  const _HealthReportCard({required this.report});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  report.isHealthy ? Icons.check_circle : Icons.warning_amber,
                  color: report.isHealthy ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  report.isHealthy ? 'Tutto in ordine' : 'Problemi rilevati',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Brani totali: ${report.totalSongs}'),
            Text('File PDF sul dispositivo: ${report.totalPdfFiles}'),
            Text('Record senza PDF (orfani DB): ${report.orphanRecords.length}'),
            Text('File PDF senza record (orfani FS): ${report.orphanFiles.length}'),
            Text('Brani senza hash: ${report.songsWithoutHash}'),
          ],
        ),
      ),
    );
  }
}
