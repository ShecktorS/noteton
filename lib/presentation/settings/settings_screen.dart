import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final backup = ref.read(backupRepositoryProvider);
    try {
      await backup.exportBackup();
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
