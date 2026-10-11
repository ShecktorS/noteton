import 'package:flutter/material.dart';

import '../../../domain/models/song.dart';
import '../../common/brand/brand_empty_state.dart';

/// Messaggio mostrato quando la libreria (o il filtro di stato) è vuota.
class LibraryEmptyState extends StatelessWidget {
  final SongStatus? statusFilter;

  const LibraryEmptyState({super.key, this.statusFilter});

  @override
  Widget build(BuildContext context) {
    return BrandEmptyState(
      icon: statusFilter != null
          ? Icons.filter_list_rounded
          : Icons.library_music_rounded,
      title: statusFilter != null
          ? 'Nessuno spartito con stato "${statusFilter!.label}"'
          : 'Nessuno spartito nella libreria',
      message: statusFilter == null ? 'Tocca + per importare un PDF' : null,
    );
  }
}
