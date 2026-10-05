import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/song.dart';
import 'add_to_collection_dialog.dart';
import 'delete_dialogs.dart';
import 'song_edit_sheet.dart';
import 'status_picker_sheet.dart';
import 'tag_picker_dialog.dart';

/// Menu azioni (⋮) di un singolo brano.
Future<void> showSongOptionsSheet(
    BuildContext context, WidgetRef ref, Song song) async {
  await showModalBottomSheet(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Modifica dettagli'),
          onTap: () async {
            Navigator.pop(ctx);
            await showSongEditSheet(context, ref, song);
          },
        ),
        ListTile(
          leading: const Icon(Icons.label_outline),
          title: const Text('Stato'),
          subtitle: song.status != SongStatus.none
              ? Text(song.status.label,
                  style: TextStyle(color: song.status.color, fontSize: 12))
              : null,
          onTap: () async {
            Navigator.pop(ctx);
            await showStatusPicker(context, ref, song);
          },
        ),
        ListTile(
          leading: const Icon(Icons.local_offer_outlined),
          title: const Text('Tag'),
          onTap: () async {
            Navigator.pop(ctx);
            await showSongTagPicker(context, ref, song);
          },
        ),
        ListTile(
          leading: const Icon(Icons.folder_special_outlined),
          title: const Text('Aggiungi a raccolta'),
          onTap: () async {
            Navigator.pop(ctx);
            await showAddToCollectionDialog(context, ref, song);
          },
        ),
        ListTile(
          leading: Icon(Icons.delete_outline,
              color: Theme.of(context).colorScheme.error),
          title: Text('Elimina',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error)),
          onTap: () async {
            Navigator.pop(ctx);
            await confirmDeleteSong(context, ref, song);
          },
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}
