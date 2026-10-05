import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/key_signature_localization.dart';
import '../../../domain/models/song.dart';
import '../../common/pdf_thumbnail.dart';
import 'meta_badge.dart';

/// Riga della vista lista: miniatura (o checkbox in selezione), titolo,
/// autore e badge dei metadati.
class SongListTile extends StatelessWidget {
  final Song song;
  final bool isSelected;
  final bool inSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelection;
  final VoidCallback onOptions;

  const SongListTile({
    super.key,
    required this.song,
    required this.isSelected,
    required this.inSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: inSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onToggleSelection(),
            )
          : PdfThumbnail(
              key: ValueKey(song.filePath),
              filePath: song.filePath,
              size: 48,
            ),
      title: Text(song.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (song.composerName != null)
            GestureDetector(
              onTap: () => context.push('/composers/${song.composerId}'),
              child: Text(
                song.composerName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              if (song.totalPages > 0)
                Text(
                  song.lastPage > 0
                      ? 'Pag. ${song.lastPage}/${song.totalPages}'
                      : '${song.totalPages} pag.',
                  style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.primary),
                ),
              if (song.status != SongStatus.none)
                MetaBadge(label: song.status.label, color: song.status.color),
              if (song.keySignature != null)
                MetaBadge(
                  label: KeySignatureLocalization.display(
                      song.keySignature!,
                      Localizations.localeOf(context)),
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              if (song.bpm != null)
                MetaBadge(
                  label: '${song.bpm} BPM',
                  color: Theme.of(context).colorScheme.secondary,
                ),
              if (song.instrument != null)
                MetaBadge(
                  label: song.instrument!,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ],
      ),
      trailing: inSelectionMode
          ? null
          : IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: onOptions,
            ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
