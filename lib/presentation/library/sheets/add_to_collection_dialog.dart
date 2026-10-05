import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/song.dart';
import '../../../providers/providers.dart';

/// Dialogo per aggiungere/rimuovere un brano dalle raccolte.
Future<void> showAddToCollectionDialog(
    BuildContext context, WidgetRef ref, Song song) async {
  final collections = await ref.read(collectionRepositoryProvider).getAll();
  if (!context.mounted) return;
  if (collections.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nessuna raccolta disponibile. Creane una nella sezione Raccolte.'),
      ),
    );
    return;
  }
  final currentIds = await ref.read(collectionRepositoryProvider).getCollectionIdsForSong(song.id!);
  if (!context.mounted) return;
  final selectedIds = Set<int>.from(currentIds);
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Aggiungi a raccolta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: collections
                .map((c) => CheckboxListTile(
                      title: Text(c.name),
                      value: selectedIds.contains(c.id),
                      onChanged: (checked) => setDialogState(() {
                        if (checked == true) {
                          selectedIds.add(c.id!);
                        } else {
                          selectedIds.remove(c.id);
                        }
                      }),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(collectionRepositoryProvider);
              // Add to newly selected
              for (final id in selectedIds.difference(Set<int>.from(currentIds))) {
                await repo.addSong(id, song.id!);
              }
              // Remove from deselected
              for (final id in Set<int>.from(currentIds).difference(selectedIds)) {
                await repo.removeSong(id, song.id!);
              }
              ref.invalidate(collectionsProvider);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    ),
  );
}
