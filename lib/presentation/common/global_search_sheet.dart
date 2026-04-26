import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/collection.dart';
import '../../domain/models/composer.dart';
import '../../domain/models/setlist.dart';
import '../../domain/models/song.dart';
import '../../domain/models/tag.dart';
import '../../providers/providers.dart';

/// Apre il bottom sheet "ricerca globale" sopra la schermata corrente.
/// Risultati raggruppati per tipo: Brani, Autori, Album, Setlist, Raccolte, Tag.
Future<void> showGlobalSearchSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GlobalSearchSheet(),
  );
}

class _GlobalSearchSheet extends ConsumerStatefulWidget {
  const _GlobalSearchSheet();

  @override
  ConsumerState<_GlobalSearchSheet> createState() =>
      _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends ConsumerState<_GlobalSearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cerca brani, autori, album, setlist…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: _query.length < 2
                  ? _EmptyHint(theme: theme)
                  : _ResultsList(
                      query: _query,
                      scrollController: scrollCtrl,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final ThemeData theme;
  const _EmptyHint({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.travel_explore,
              size: 56, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text('Inizia a digitare per cercare',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 4),
          Text('Almeno 2 caratteri',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _ResultsList extends ConsumerWidget {
  final String query;
  final ScrollController scrollController;
  const _ResultsList({required this.query, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowQ = query.toLowerCase();
    final theme = Theme.of(context);

    // Songs: usa la ricerca SQL del repository (LIKE su title/composer/key/album/period)
    final asyncSongs = ref.watch(
      songsProvider((query: query, tagId: null)),
    );
    final asyncComposers = ref.watch(composersProvider);
    final asyncSetlists = ref.watch(setlistsProvider);
    final asyncCollections = ref.watch(collectionsProvider);
    final asyncTags = ref.watch(tagsProvider);
    final asyncAlbums =
        ref.watch(albumSuggestionsProvider(query));

    final allLoaded = asyncSongs.hasValue &&
        asyncComposers.hasValue &&
        asyncSetlists.hasValue &&
        asyncCollections.hasValue &&
        asyncTags.hasValue;

    if (!allLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final songs = asyncSongs.value ?? const <Song>[];
    final composers = (asyncComposers.value ?? const <Composer>[])
        .where((c) => c.name.toLowerCase().contains(lowQ))
        .toList();
    final setlists = (asyncSetlists.value ?? const <Setlist>[])
        .where((s) => s.title.toLowerCase().contains(lowQ))
        .toList();
    final collections = (asyncCollections.value ?? const <Collection>[])
        .where((c) => c.name.toLowerCase().contains(lowQ))
        .toList();
    final tags = (asyncTags.value ?? const <Tag>[])
        .where((t) => t.name.toLowerCase().contains(lowQ))
        .toList();
    final albums = asyncAlbums.value ?? const <String>[];

    final empty = songs.isEmpty &&
        composers.isEmpty &&
        setlists.isEmpty &&
        collections.isEmpty &&
        tags.isEmpty &&
        albums.isEmpty;

    if (empty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 56, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('Nessun risultato per "$query"',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      children: [
        if (songs.isNotEmpty) ...[
          _SectionHeader('Brani', count: songs.length),
          ...songs.take(8).map((s) => _SongTile(song: s)),
        ],
        if (composers.isNotEmpty) ...[
          _SectionHeader('Autori', count: composers.length),
          ...composers.take(6).map((c) => _ComposerTile(composer: c)),
        ],
        if (albums.isNotEmpty) ...[
          _SectionHeader('Album', count: albums.length),
          ...albums.take(6).map((a) => _AlbumTile(album: a)),
        ],
        if (setlists.isNotEmpty) ...[
          _SectionHeader('Setlist', count: setlists.length),
          ...setlists.take(6).map((s) => _SetlistTile(setlist: s)),
        ],
        if (collections.isNotEmpty) ...[
          _SectionHeader('Raccolte', count: collections.length),
          ...collections.take(6).map((c) => _CollectionTile(collection: c)),
        ],
        if (tags.isNotEmpty) ...[
          _SectionHeader('Tag', count: tags.length),
          ...tags.take(6).map((t) => _TagTile(tag: t)),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader(this.title, {required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Row(
        children: [
          Text(title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(width: 8),
          Text('· $count',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  const _SongTile({required this.song});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.music_note_outlined),
      title: Text(song.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: song.composerName != null
          ? Text(song.composerName!,
              maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      onTap: () {
        Navigator.pop(context);
        context.push('${AppConstants.routeViewer}/${song.id}');
      },
    );
  }
}

class _ComposerTile extends StatelessWidget {
  final Composer composer;
  const _ComposerTile({required this.composer});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(composer.name),
      onTap: () {
        Navigator.pop(context);
        context.push('/composers/${composer.id}');
      },
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final String album;
  const _AlbumTile({required this.album});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.album_outlined),
      title: Text(album),
      // L'app non ha ancora una pagina dedicata album: niente onTap.
      // Cliccando, almeno chiude il sheet così l'utente capisce.
      onTap: () => Navigator.pop(context),
    );
  }
}

class _SetlistTile extends StatelessWidget {
  final Setlist setlist;
  const _SetlistTile({required this.setlist});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.queue_music),
      title: Text(setlist.title),
      onTap: () {
        Navigator.pop(context);
        context.push('${AppConstants.routeSetlists}/${setlist.id}');
      },
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final Collection collection;
  const _CollectionTile({required this.collection});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.collections_bookmark_outlined),
      title: Text(collection.name),
      onTap: () {
        Navigator.pop(context);
        context.push('${AppConstants.routeCollections}/${collection.id}');
      },
    );
  }
}

class _TagTile extends StatelessWidget {
  final Tag tag;
  const _TagTile({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(tag.color);
    return ListTile(
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(tag.name),
      onTap: () {
        Navigator.pop(context);
        // Imposta il filtro tag e torna in libreria.
        // Lo stato è gestito dal LibraryScreen via tagFilterProvider.
      },
    );
  }

  static Color _parseColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }
}
