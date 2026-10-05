import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/key_signature_localization.dart';
import '../../../domain/models/song.dart';
import '../../common/pdf_thumbnail.dart';

/// Card della vista griglia: miniatura, stato, tonalità, titolo, autore e
/// avanzamento di lettura.
class SongGridCard extends StatelessWidget {
  final Song song;
  final bool isSelected;
  final bool inSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOptions;

  const SongGridCard({
    super.key,
    required this.song,
    required this.isSelected,
    required this.inSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: PdfThumbnailExpanded(
                          key: ValueKey(song.filePath),
                          filePath: song.filePath,
                        ),
                      ),
                      // Status dot (in alto a sinistra)
                      if (song.status != SongStatus.none)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Tooltip(
                            message: song.status.label,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: song.status.color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Tonalità pill (in basso a destra sulla thumbnail)
                      if (song.keySignature != null)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              KeySignatureLocalization.display(
                                  song.keySignature!,
                                  Localizations.localeOf(context)),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
                      ),
                      const SizedBox(height: 2),
                      if (song.composerName != null)
                        GestureDetector(
                          onTap: () =>
                              context.push('/composers/${song.composerId}'),
                          child: Text(
                            song.composerName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      if (song.totalPages > 0 && song.lastPage > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: song.lastPage / song.totalPages,
                              minHeight: 2,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(
                                  theme.colorScheme.primary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Three-dot menu (normal mode)
        if (!inSelectionMode)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onOptions,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.more_vert,
                      size: 20, color: Colors.white),
                ),
              ),
            ),
          ),
        // Selection overlay
        if (inSelectionMode)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white.withValues(alpha: 0.85),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}
