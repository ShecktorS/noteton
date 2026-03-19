import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

class PdfViewerPage extends ConsumerWidget {
  final int songId;

  const PdfViewerPage({super.key, required this.songId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songAsync = ref.watch(songsProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text('Spartito')),
      body: songAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (songs) {
          final song = songs.where((s) => s.id == songId).firstOrNull;
          if (song == null) {
            return const Center(child: Text('Spartito non trovato'));
          }
          // TODO: render PDF with pdfx (Fase 1)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf, size: 80,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(song.title,
                    style: Theme.of(context).textTheme.headlineSmall),
                if (song.composerName != null)
                  Text(song.composerName!,
                      style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 24),
                const Text('Rendering PDF — in arrivo nella Fase 1',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }
}
