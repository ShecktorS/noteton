import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../common/app_bottom_nav.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
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
            subtitle: const Text('Sync cloud — in arrivo nella Fase 5'),
            onTap: null,
          ),
          const Divider(),
          const _SectionHeader('Info'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versione'),
            subtitle: const Text('Noteton 0.1.0'),
          ),
          ListTile(
            leading: const Icon(Icons.balance),
            title: const Text('Licenza'),
            subtitle: const Text('MIT / GPL — Open Source'),
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
