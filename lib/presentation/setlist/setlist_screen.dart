import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../common/app_bottom_nav.dart';

class SetlistScreen extends ConsumerWidget {
  const SetlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistsAsync = ref.watch(setlistsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Setlist')),
      body: setlistsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (setlists) {
          if (setlists.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.queue_music, size: 64,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('Nessuna setlist'),
                  const SizedBox(height: 8),
                  const Text('Tocca + per crearne una',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: setlists.length,
            itemBuilder: (context, i) {
              final setlist = setlists[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(setlist.title),
                  subtitle: setlist.performanceDate != null
                      ? Text(setlist.performanceDate!.toLocal().toString().split(' ').first)
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: navigate to setlist detail / performance (Fase 2)
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: create new setlist (Fase 2)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Creazione setlist — in arrivo nella Fase 2')),
          );
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}
