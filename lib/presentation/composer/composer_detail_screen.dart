import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/song.dart';
import '../../providers/providers.dart';
import '../common/pdf_thumbnail.dart';

final _composerSongsProvider =
    FutureProvider.family<List<Song>, int>((ref, composerId) async {
  return ref.read(songRepositoryProvider).getByComposerId(composerId);
});

class ComposerDetailScreen extends ConsumerWidget {
  final int composerId;
  const ComposerDetailScreen({super.key, required this.composerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composerAsync = ref.watch(composersProvider);
    final songsAsync = ref.watch(_composerSongsProvider(composerId));

    final composerName = composerAsync.maybeWhen(
      data: (list) =>
          list.where((c) => c.id == composerId).firstOrNull?.name ?? '—',
      orElse: () => '…',
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Compositore', style: TextStyle(fontSize: 12)),
            Text(composerName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (songs) {
          if (songs.isEmpty) {
            return const Center(child: Text('Nessuno spartito trovato.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                leading: PdfThumbnail(
                  key: ValueKey(song.filePath),
                  filePath: song.filePath,
                  size: 48,
                ),
                title: Text(song.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: song.keySignature != null
                    ? Text(song.keySignature!,
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.tertiary))
                    : null,
                trailing: song.lastPage > 0 && song.totalPages > 0
                    ? Text('${song.lastPage}/${song.totalPages}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary))
                    : null,
                onTap: () =>
                    context.push('${AppConstants.routeViewer}/${song.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
