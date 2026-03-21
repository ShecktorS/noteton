import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/collection.dart';
import '../../providers/providers.dart';
import '../common/app_bottom_nav.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(collectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Raccolte')),
      body: collectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (collections) {
          if (collections.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_special_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('Nessuna raccolta'),
                  const SizedBox(height: 8),
                  const Text('Tocca + per creare una raccolta',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => _showInfoDialog(context),
                    child: const Text('Cosa sono le Raccolte?'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: collections.length,
            itemBuilder: (context, i) {
              final collection = collections[i];
              return _CollectionTile(
                collection: collection,
                onTap: () => context.push(
                    '${AppConstants.routeCollections}/${collection.id}'),
                onLongPress: () =>
                    _showOptions(context, ref, collection),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cosa sono le Raccolte?'),
        content: const Text(
          'Le Raccolte sono cartelle colorate per organizzare i tuoi spartiti per genere, strumento o qualsiasi categoria tu voglia — indipendentemente dalle setlist.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Capito'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_CollectionFormResult>(
      context: context,
      builder: (ctx) => const _CollectionFormDialog(),
    );
    if (result == null) return;
    final repo = ref.read(collectionRepositoryProvider);
    await repo.insert(Collection(
      name: result.name,
      color: result.color,
      createdAt: DateTime.now(),
    ));
    ref.invalidate(collectionsProvider);
  }

  Future<void> _showOptions(
      BuildContext context, WidgetRef ref, Collection collection) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rinomina'),
            onTap: () {
              Navigator.pop(ctx);
              _showRenameDialog(context, ref, collection);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text('Elimina',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDelete(context, ref, collection);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref, Collection collection) async {
    final result = await showDialog<_CollectionFormResult>(
      context: context,
      builder: (ctx) => _CollectionFormDialog(
        initialName: collection.name,
        initialColor: collection.color,
      ),
    );
    if (result == null) return;
    final repo = ref.read(collectionRepositoryProvider);
    await repo.update(collection.copyWith(
      name: result.name,
      color: result.color,
    ));
    ref.invalidate(collectionsProvider);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Collection collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina raccolta'),
        content: Text(
            'Vuoi eliminare "${collection.name}"?\nI brani non verranno eliminati dalla libreria.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(collectionRepositoryProvider).delete(collection.id!);
    ref.invalidate(collectionsProvider);
  }
}

// ── Collection tile ───────────────────────────────────────────────────────────

class _CollectionTile extends StatelessWidget {
  final Collection collection;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CollectionTile({
    required this.collection,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(collection.color);
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(Icons.folder_special, color: color, size: 22),
      ),
      title: Text(collection.name,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${collection.songCount} bran${collection.songCount == 1 ? 'o' : 'i'}',
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blueGrey;
    }
  }
}

// ── Collection form result ────────────────────────────────────────────────────

class _CollectionFormResult {
  final String name;
  final String color;
  const _CollectionFormResult({required this.name, required this.color});
}

// ── Collection form dialog (create / rename) ──────────────────────────────────

class _CollectionFormDialog extends StatefulWidget {
  final String? initialName;
  final String? initialColor;
  const _CollectionFormDialog({this.initialName, this.initialColor});

  @override
  State<_CollectionFormDialog> createState() => _CollectionFormDialogState();
}

class _CollectionFormDialogState extends State<_CollectionFormDialog> {
  late final TextEditingController _nameCtrl;
  late String _selectedColor;

  static const _palette = AppConstants.defaultTagColors;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _selectedColor = widget.initialColor ?? _palette[4]; // default blue
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName == null ? 'Nuova raccolta' : 'Rinomina raccolta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome raccolta'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          Text('Colore',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _palette.map((hex) {
              final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
              final selected = _selectedColor == hex;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = hex),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 2.5)
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla')),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _CollectionFormResult(name: name, color: _selectedColor),
            );
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
