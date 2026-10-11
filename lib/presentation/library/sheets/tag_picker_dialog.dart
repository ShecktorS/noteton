import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/song.dart';
import '../../../domain/models/tag.dart';
import '../../../providers/providers.dart';
import 'tag_color.dart';

/// Tag picker per un singolo brano: sostituisce i tag assegnati.
Future<void> showSongTagPicker(
    BuildContext context, WidgetRef ref, Song song) async {
  ref.invalidate(tagsProvider);
  final List<Tag> allTags;
  try {
    allTags = await ref.read(tagsProvider.future);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Errore caricamento tag: $e')),
    );
    return;
  }
  if (!context.mounted) return;

  if (allTags.isEmpty) {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nessun tag'),
        content: const Text(
            'Non hai ancora creato nessun tag.\nVai in Impostazioni → Tag per crearne uno.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
    return;
  }

  final currentTags =
      await ref.read(tagRepositoryProvider).getTagsForSong(song.id!);
  if (!context.mounted) return;

  final selectedIds = Set<int>.from(currentTags.map((t) => t.id!));
  await _tagPickerDialog(context, allTags, selectedIds,
      onSave: (ids) async {
    await ref.read(tagRepositoryProvider).setTagsForSong(song.id!, ids);
    ref.invalidate(songTagsProvider(song.id!));
  });
}

/// Tag picker per selezione massiva (più brani selezionati).
///
/// I tag scelti vengono aggiunti a quelli già presenti su ogni brano;
/// [onDone] viene chiamato dopo il salvataggio.
Future<void> showBulkTagPicker(
  BuildContext context,
  WidgetRef ref,
  Set<int> songIds, {
  required VoidCallback onDone,
}) async {
  ref.invalidate(tagsProvider);
  final List<dynamic> allTags;
  try {
    allTags = await ref.read(tagsProvider.future);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Errore caricamento tag: $e')),
    );
    return;
  }
  if (!context.mounted) return;

  if (allTags.isEmpty) {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nessun tag'),
        content: const Text(
            'Non hai ancora creato nessun tag.\nVai in Impostazioni → Tag per crearne uno.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    return;
  }

  final selectedIds = <int>{};
  await _tagPickerDialog(context, allTags, selectedIds,
      title: 'Assegna tag ai ${songIds.length} brani selezionati',
      onSave: (ids) async {
    final repo = ref.read(tagRepositoryProvider);
    for (final songId in songIds) {
      // Merge: aggiungo i tag selezionati senza rimuovere quelli esistenti
      final existing = await repo.getTagsForSong(songId);
      final merged = {...existing.map((t) => t.id!), ...ids}.toList();
      await repo.setTagsForSong(songId, merged);
    }
    onDone();
  });
}

/// Dialogo generico per selezionare tag da una lista.
Future<void> _tagPickerDialog(
  BuildContext context,
  List<dynamic> allTags,
  Set<int> initialIds, {
  String title = 'Tag',
  required Future<void> Function(List<int>) onSave,
}) async {
  final selectedIds = Set<int>.from(initialIds);

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: allTags.map((tag) {
              final color = parseTagColor(tag.color as String);
              return CheckboxListTile(
                secondary: Container(
                  width: 14,
                  height: 14,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                title: Text(tag.name as String),
                value: selectedIds.contains(tag.id as int?),
                onChanged: (checked) => setDialogState(() {
                  if (checked == true) {
                    selectedIds.add(tag.id as int);
                  } else {
                    selectedIds.remove(tag.id as int?);
                  }
                }),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await onSave(selectedIds.toList());
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    ),
  );
}
