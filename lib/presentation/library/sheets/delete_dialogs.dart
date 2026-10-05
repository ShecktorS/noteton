import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/song.dart';
import '../../../providers/providers.dart';

/// Chiede conferma ed elimina un singolo brano (con il suo PDF).
Future<void> confirmDeleteSong(
    BuildContext context, WidgetRef ref, Song song) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Elimina spartito'),
      content: Text(
          'Vuoi eliminare "${song.title}"?\nIl file PDF verrà rimosso dal dispositivo.'),
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
  if (!context.mounted) return;
  await ref.read(songRepositoryProvider).delete(song.id!);
  ref.invalidate(songsProvider);
}

/// Chiede conferma ed elimina tutti i brani in [songIds].
/// Restituisce `true` se l'eliminazione è stata eseguita.
Future<bool> confirmDeleteSongs(
    BuildContext context, WidgetRef ref, Set<int> songIds) async {
  final count = songIds.length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Elimina $count spartit${count == 1 ? 'o' : 'i'}'),
      content: Text(
          'Verranno eliminati $count spartit${count == 1 ? 'o' : 'i'} e i relativi file PDF.'),
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
  if (confirmed != true) return false;
  if (!context.mounted) return false;
  final repo = ref.read(songRepositoryProvider);
  for (final id in songIds.toList()) {
    await repo.delete(id);
  }
  return true;
}
