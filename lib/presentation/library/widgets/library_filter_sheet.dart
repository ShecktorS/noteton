import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/song.dart';
import '../../../domain/models/tag.dart';
import '../../../providers/providers.dart';
import '../dialogs/tag_picker_dialog.dart';

/// Bottom sheet dei filtri. Lo stato è locale alla libreria, quindi arriva
/// come [statusFilter] e torna con [onStatusSelected]; il filtro per tag
/// vive in [tagFilterProvider].
Future<void> showLibraryFilterSheet(
  BuildContext context,
  WidgetRef ref, {
  required SongStatus? statusFilter,
  required ValueChanged<SongStatus?> onStatusSelected,
}) async {
  List<Tag> tags;
  try {
    tags = await ref.read(tagsProvider.future);
  } catch (_) {
    tags = [];
  }
  if (!context.mounted) return;

  final currentTagFilter = ref.read(tagFilterProvider);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        int? localTagId = currentTagFilter;
        // Re-read on rebuild
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status section ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Stato',
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                          color: Theme.of(ctx).colorScheme.primary)),
                ),
                ListTile(
                  leading: const Icon(Icons.all_inclusive),
                  title: const Text('Tutti gli stati'),
                  trailing: statusFilter == null
                      ? Icon(Icons.check,
                          color: Theme.of(ctx).colorScheme.primary, size: 18)
                      : null,
                  onTap: () {
                    onStatusSelected(null);
                    Navigator.pop(ctx);
                  },
                ),
                ...SongStatus.values
                    .where((s) => s != SongStatus.none)
                    .map((status) => ListTile(
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: status.color,
                                shape: BoxShape.circle),
                          ),
                          title: Text(status.label),
                          trailing: statusFilter == status
                              ? Icon(Icons.check,
                                  color: Theme.of(ctx).colorScheme.primary,
                                  size: 18)
                              : null,
                          onTap: () {
                            onStatusSelected(status);
                            Navigator.pop(ctx);
                          },
                        )),

                if (tags.isNotEmpty) ...[
                  const Divider(height: 1),
                  // ── Tag section ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Tag',
                        style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            color: Theme.of(ctx).colorScheme.primary)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.label_off_outlined),
                    title: const Text('Tutti i tag'),
                    trailing: localTagId == null
                        ? Icon(Icons.check,
                            color: Theme.of(ctx).colorScheme.primary, size: 18)
                        : null,
                    onTap: () {
                      ref.read(tagFilterProvider.notifier).state = null;
                      Navigator.pop(ctx);
                    },
                  ),
                  Consumer(builder: (consumerCtx, consumerRef, _) {
                    final countsAsync =
                        consumerRef.watch(tagCountsProvider);
                    final counts = countsAsync.valueOrNull ?? const {};
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: tags.map((tag) {
                        final tagColor =
                            parseTagColor(tag.color);
                        final tagId = tag.id;
                        final count = counts[tagId] ?? 0;
                        final selected = localTagId == tagId;
                        return ListTile(
                          leading: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                                color: tagColor, shape: BoxShape.circle),
                          ),
                          title: Text(tag.name),
                          subtitle: Text(
                              count == 1 ? '1 brano' : '$count brani',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .outline)),
                          trailing: selected
                              ? Icon(Icons.check,
                                  color: Theme.of(ctx).colorScheme.primary,
                                  size: 20)
                              : null,
                          onTap: () {
                            setSheetState(() => localTagId = tagId);
                            ref.read(tagFilterProvider.notifier).state =
                                tagId;
                            Navigator.pop(ctx);
                          },
                        );
                      }).toList(),
                    );
                  }),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    ),
  );
}
