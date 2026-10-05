import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/song.dart';
import '../../../providers/providers.dart';

/// Bottom sheet per cambiare lo stato di studio di un brano.
Future<void> showStatusPicker(
    BuildContext context, WidgetRef ref, Song song) async {
  final result = await showModalBottomSheet<SongStatus>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Stato di "${song.title}"',
              style: Theme.of(ctx).textTheme.titleMedium),
        ),
        ...SongStatus.values.map((status) => ListTile(
          leading: status == SongStatus.none
              ? const Icon(Icons.remove_circle_outline)
              : Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: status.color, shape: BoxShape.circle),
                ),
          title: Text(status == SongStatus.none ? 'Nessuno stato' : status.label),
          trailing: song.status == status
              ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
              : null,
          onTap: () => Navigator.pop(ctx, status),
        )),
        const SizedBox(height: 8),
      ],
    ),
  );
  if (result == null || !context.mounted) return;
  await ref.read(songRepositoryProvider).update(
    song.copyWith(status: result, updatedAt: DateTime.now()),
  );
  ref.invalidate(songsProvider);
}
