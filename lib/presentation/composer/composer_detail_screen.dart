import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/composer.dart';
import '../../domain/models/song.dart';
import '../../providers/providers.dart';
import '../common/pdf_thumbnail.dart';

final _composerSongsProvider =
    FutureProvider.family<List<Song>, int>((ref, composerId) async {
  return ref.read(songRepositoryProvider).getByComposerId(composerId);
});

final _composerByIdProvider =
    FutureProvider.family<Composer?, int>((ref, composerId) async {
  return ref.read(composerRepositoryProvider).getById(composerId);
});

class ComposerDetailScreen extends ConsumerWidget {
  final int composerId;
  const ComposerDetailScreen({super.key, required this.composerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composerAsync = ref.watch(_composerByIdProvider(composerId));
    final songsAsync = ref.watch(_composerSongsProvider(composerId));

    final composer = composerAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Compositore', style: TextStyle(fontSize: 12)),
            Text(composer?.name ?? '…',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (composer != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifica',
              onPressed: () =>
                  _showEditDialog(context, ref, composer),
            ),
        ],
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (songs) {
          return CustomScrollView(
            slivers: [
              // ── Header card ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _ComposerHeader(
                    composer: composer, songCount: songs.length),
              ),

              // ── Song list ────────────────────────────────────────────────
              if (songs.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('Nessuno spartito trovato.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 24),
                  sliver: SliverList.builder(
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: song.keySignature != null
                            ? Text(song.keySignature!,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .tertiary))
                            : null,
                        trailing: song.lastPage > 0 && song.totalPages > 0
                            ? Text('${song.lastPage}/${song.totalPages}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary))
                            : null,
                        onTap: () => context.push(
                            '${AppConstants.routeViewer}/${song.id}'),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, Composer composer) async {
    final nameCtrl = TextEditingController(text: composer.name);
    final bornCtrl = TextEditingController(
        text: composer.bornYear != null ? '${composer.bornYear}' : '');
    final diedCtrl = TextEditingController(
        text: composer.diedYear != null ? '${composer.diedYear}' : '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifica compositore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome'),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: bornCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Anno nascita'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: diedCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Anno morte'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salva')),
        ],
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;

    final updated = composer.copyWith(
      name: nameCtrl.text.trim(),
      bornYear: int.tryParse(bornCtrl.text.trim()),
      diedYear: int.tryParse(diedCtrl.text.trim()),
    );
    await ref.read(composerRepositoryProvider).update(updated);
    ref.invalidate(_composerByIdProvider(composerId));
    ref.invalidate(composersProvider);
  }
}

// ── Header card ───────────────────────────────────────────────────────────────

class _ComposerHeader extends StatelessWidget {
  final Composer? composer;
  final int songCount;

  const _ComposerHeader({required this.composer, required this.songCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final c = composer;

    // Life span string
    String? lifespan;
    if (c != null) {
      if (c.bornYear != null && c.diedYear != null) {
        lifespan = '${c.bornYear} – ${c.diedYear}';
      } else if (c.bornYear != null) {
        lifespan = 'Nato nel ${c.bornYear}';
      } else if (c.diedYear != null) {
        lifespan = '† ${c.diedYear}';
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Avatar iniziale
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                c?.name.isNotEmpty == true
                    ? c!.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: accent),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c?.name ?? '…',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (lifespan != null) ...[
                  const SizedBox(height: 4),
                  Text(lifespan,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
                const SizedBox(height: 8),
                _StatChip(
                  icon: Icons.music_note,
                  label: '$songCount bran${songCount == 1 ? 'o' : 'i'}',
                  color: accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}
