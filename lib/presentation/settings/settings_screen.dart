import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/providers.dart';
import '../common/app_bottom_nav.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isImporting = false;

  Future<void> _exportBackup() async {
    if (!mounted) return;

    // Ask the user how they want to save the backup
    final choice = await showModalBottomSheet<_ExportChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Salva sul dispositivo'),
              subtitle: const Text('Scegli dove salvare il file .ntb'),
              onTap: () => Navigator.pop(ctx, _ExportChoice.save),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Condividi…'),
              subtitle: const Text('Invia via email, Drive, WhatsApp…'),
              onTap: () => Navigator.pop(ctx, _ExportChoice.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    final backup = ref.read(backupRepositoryProvider);
    try {
      final tempPath = await backup.createBackupFile();
      final fileName = tempPath.split('/').last;

      if (choice == _ExportChoice.save) {
        final destPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Salva backup Noteton',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['ntb'],
        );
        if (destPath == null) return; // user cancelled
        await File(tempPath).copy(destPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup salvato sul dispositivo')),
          );
        }
      } else {
        await Share.shareXFiles(
          [XFile(tempPath, mimeType: 'application/octet-stream')],
          subject: 'Noteton Backup',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore backup: $e')),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ntb'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isImporting = true);

    final backup = ref.read(backupRepositoryProvider);
    try {
      final summary = await backup.importBackup(result.files.single.path!);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ripristino completato'),
            content: Text(summary),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
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
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: Stack(
        children: [
          ListView(
            children: [
              const _SectionHeader('Aspetto'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Chiaro'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('Sistema'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Scuro'),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selection) =>
                      ref.read(themeModeProvider.notifier).setMode(selection.first),
                ),
              ),
              const Divider(),
              const _SectionHeader('Bluetooth'),
              ListTile(
                leading: const Icon(Icons.bluetooth),
                title: const Text('Pedale page-turner'),
                subtitle: const Text('Nessun dispositivo connesso'),
                onTap: () {
                  // TODO: implement Bluetooth settings (Fase 3)
                },
              ),
              const Divider(),
              const _SectionHeader('Dati'),
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Backup libreria'),
                subtitle: const Text('Esporta brani, setlist e raccolte in un file .ntb'),
                onTap: _isImporting ? null : _exportBackup,
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Ripristina backup'),
                subtitle: const Text('Importa da un file .ntb'),
                onTap: _isImporting ? null : _importBackup,
              ),
              const Divider(),
              const _SectionHeader('Info'),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Versione'),
                subtitle: Text('Noteton 0.2.0'),
              ),
              const ListTile(
                leading: Icon(Icons.balance),
                title: Text('Licenza'),
                subtitle: Text('MIT / GPL — Open Source'),
              ),
            ],
          ),
          if (_isImporting)
            const ColoredBox(
              color: Colors.black45,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

enum _ExportChoice { save, share }
