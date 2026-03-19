import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/setlist.dart';
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
                  Icon(Icons.queue_music,
                      size: 64,
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: setlists.length,
            itemBuilder: (context, i) {
              final setlist = setlists[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.queue_music)),
                title: Text(setlist.title),
                subtitle: setlist.performanceDate != null
                    ? Text(_formatDate(setlist.performanceDate!))
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showOptions(context, ref, setlist),
                ),
                onTap: () => context
                    .push('${AppConstants.routeSetlists}/${setlist.id}'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    DateTime? performanceDate;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Nuova setlist'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  performanceDate != null
                      ? _formatDate(performanceDate!)
                      : 'Data concerto (opzionale)',
                  style: performanceDate == null
                      ? const TextStyle(color: Colors.grey)
                      : null,
                ),
                trailing: performanceDate != null
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            setStateDialog(() => performanceDate = null),
                      )
                    : null,
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setStateDialog(() => performanceDate = date);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Crea')),
          ],
        ),
      ),
    );

    if (confirmed != true || titleCtrl.text.trim().isEmpty) return;
    await ref.read(setlistRepositoryProvider).insert(Setlist(
          title: titleCtrl.text.trim(),
          createdAt: DateTime.now(),
          performanceDate: performanceDate,
        ));
    ref.invalidate(setlistsProvider);
  }

  Future<void> _showOptions(
      BuildContext context, WidgetRef ref, Setlist setlist) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rinomina'),
            onTap: () {
              Navigator.pop(ctx);
              _showRenameDialog(context, ref, setlist);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text('Elimina',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDelete(context, ref, setlist);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref, Setlist setlist) async {
    final titleCtrl = TextEditingController(text: setlist.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rinomina setlist'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'Nome'),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salva')),
        ],
      ),
    );
    if (confirmed != true || titleCtrl.text.trim().isEmpty) return;
    await ref
        .read(setlistRepositoryProvider)
        .update(setlist.copyWith(title: titleCtrl.text.trim()));
    ref.invalidate(setlistsProvider);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Setlist setlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina setlist'),
        content: Text(
            'Vuoi eliminare "${setlist.title}"?\nGli spartiti nella libreria non verranno rimossi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(setlistRepositoryProvider).delete(setlist.id!);
    ref.invalidate(setlistsProvider);
  }
}

String _formatDate(DateTime date) {
  const months = [
    'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
    'lug', 'ago', 'set', 'ott', 'nov', 'dic'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
