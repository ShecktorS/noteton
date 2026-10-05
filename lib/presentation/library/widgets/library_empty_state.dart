import 'package:flutter/material.dart';

import '../../../domain/models/song.dart';

/// Messaggio mostrato quando la libreria (o il filtro di stato) è vuota.
class LibraryEmptyState extends StatelessWidget {
  final SongStatus? statusFilter;

  const LibraryEmptyState({super.key, this.statusFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(statusFilter != null
              ? 'Nessuno spartito con stato "${statusFilter!.label}"'
              : 'Nessuno spartito nella libreria'),
          const SizedBox(height: 8),
          if (statusFilter == null)
            const Text('Tocca + per importare un PDF',
                style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
