import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/song.dart';
import '../../../domain/models/tag.dart';
import '../../../providers/providers.dart';

/// Converte il colore di un tag (`#RRGGBB`) in [Color]; grigio se non valido.
Color parseTagColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return Colors.grey;
  }
}

/// Assegna i tag a un singolo brano, partendo da quelli che ha già.
Future<void> showSongTagPicker(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  final allTags = await _loadTagsOrExplain(context, ref);
  if (allTags == null || !context.mounted) return;

  final currentTags =
      await ref.read(tagRepositoryProvider).getTagsForSong(song.id!);
  if (!context.mounted) return;

  final selectedIds = Set<int>.from(currentTags.map((t) => t.id!));
  await _tagPickerDialog(context, allTags, selectedIds, onSave: (ids) async {
    await ref.read(tagRepositoryProvider).setTagsForSong(song.id!, ids);
    ref.invalidate(songTagsProvider(song.id!));
  });
}

/// Tag picker per selezione massiva (più brani selezionati). I tag scelti
/// vengono aggiunti a quelli già presenti su ciascun brano; [onSaved] viene
/// chiamato dopo il salvataggio.
Future<void> showBulkTagPicker(
  BuildContext context,
  WidgetRef ref,
  Set<int> songIds, {
  required VoidCallback onSaved,
}) async {
  final allTags = await _loadTagsOrExplain(context, ref);
  if (allTags == null || !context.mounted) return;

  await _tagPickerDialog(context, allTags, <int>{},
      title: 'Assegna tag ai ${songIds.length} brani selezionati',
      onSave: (ids) async {
    final repo = ref.read(tagRepositoryProvider);
    for (final songId in songIds) {
      // Merge: aggiungo i tag selezionati senza rimuovere quelli esistenti
      final existing = await repo.getTagsForSong(songId);
      final merged = {...existing.map((t) => t.id!), ...ids}.toList();
      await repo.setTagsForSong(songId, merged);
    }
    onSaved();
  });
}

/// Ricarica i tag. Se non ce ne sono (o il caricamento fallisce) lo spiega
/// all'utente e ritorna null.
Future<List<Tag>?> _loadTagsOrExplain(
    BuildContext context, WidgetRef ref) async {
  ref.invalidate(tagsProvider);
  final List<Tag> allTags;
  try {
    allTags = await ref.read(tagsProvider.future);
  } catch (e) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Errore caricamento tag: $e')),
    );
    return null;
  }
  if (!context.mounted) return null;

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
    return null;
  }
  return allTags;
}

/// Dialogo generico per selezionare tag da una lista.
Future<void> _tagPickerDialog(
  BuildContext context,
  List<Tag> allTags,
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
              final color = parseTagColor(tag.color);
              return CheckboxListTile(
                secondary: Container(
                  width: 14,
                  height: 14,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                title: Text(tag.name),
                value: selectedIds.contains(tag.id),
                onChanged: (checked) => setDialogState(() {
                  if (checked == true) {
                    selectedIds.add(tag.id!);
                  } else {
                    selectedIds.remove(tag.id);
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
