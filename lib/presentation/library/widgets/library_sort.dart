import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/song.dart';
import '../../../providers/providers.dart';

/// Ordina una copia di [songs] secondo [order].
List<Song> sortSongs(List<Song> songs, SortOrder order) {
  final list = List<Song>.from(songs);
  switch (order) {
    case SortOrder.titleAZ:
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    case SortOrder.titleZA:
      list.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
    case SortOrder.newestFirst:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case SortOrder.lastOpened:
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
  return list;
}

/// Bottom sheet "Ordina per": aggiorna [sortOrderProvider].
void showLibrarySortSheet(BuildContext context, WidgetRef ref) {
  final current = ref.read(sortOrderProvider);
  showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Ordina per',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
          for (final option in SortOrder.values)
            ListTile(
              leading: Icon(_sortIcon(option)),
              title: Text(_sortLabel(option)),
              trailing: current == option
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () {
                ref.read(sortOrderProvider.notifier).state = option;
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

IconData _sortIcon(SortOrder o) => switch (o) {
      SortOrder.titleAZ => Icons.sort_by_alpha,
      SortOrder.titleZA => Icons.sort_by_alpha,
      SortOrder.newestFirst => Icons.calendar_today,
      SortOrder.lastOpened => Icons.history,
    };

String _sortLabel(SortOrder o) => switch (o) {
      SortOrder.titleAZ => 'Titolo A → Z',
      SortOrder.titleZA => 'Titolo Z → A',
      SortOrder.newestFirst => 'Più recenti',
      SortOrder.lastOpened => 'Ultima apertura',
    };
