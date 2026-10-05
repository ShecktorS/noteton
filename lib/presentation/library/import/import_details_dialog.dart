import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/collection.dart';
import '../../../domain/models/setlist.dart';
import '../../../providers/providers.dart';
import '../../common/composer_autocomplete_field.dart';

/// Scelte fatte nel dialogo di importazione personalizzata.
class ImportDetails {
  final String title;
  final String? authorName;
  final List<int> setlistIds;
  final List<int> collectionIds;
  const ImportDetails({
    required this.title,
    this.authorName,
    required this.setlistIds,
    this.collectionIds = const [],
  });
}

/// Dialogo a passi per importare un PDF: titolo e autore, poi setlist e
/// raccolte in cui aggiungerlo (i passi vuoti vengono saltati).
class ImportDetailsDialog extends ConsumerStatefulWidget {
  final String defaultTitle;
  const ImportDetailsDialog({super.key, required this.defaultTitle});

  @override
  ConsumerState<ImportDetailsDialog> createState() =>
      _ImportDetailsDialogState();
}

class _ImportDetailsDialogState extends ConsumerState<ImportDetailsDialog> {
  int _step = 0;
  late final TextEditingController _titleCtrl;
  String? _authorName;
  List<Setlist> _setlists = [];
  final Set<int> _selectedSetlistIds = {};
  bool _loadingSetlists = true;
  List<Collection> _collections = [];
  final Set<int> _selectedCollectionIds = {};
  bool _loadingCollections = true;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.defaultTitle);
    _loadSetlists();
    _loadCollections();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSetlists() async {
    final setlists = await ref.read(setlistRepositoryProvider).getAll();
    if (mounted) {
      setState(() {
        _setlists = setlists;
        _loadingSetlists = false;
      });
    }
  }

  Future<void> _loadCollections() async {
    final collections = await ref.read(collectionRepositoryProvider).getAll();
    if (mounted) {
      setState(() {
        _collections = collections;
        _loadingCollections = false;
      });
    }
  }

  void _next() {
    if (_step == 0) {
      if (_setlists.isEmpty && !_loadingSetlists) {
        if (_collections.isEmpty && !_loadingCollections) {
          _confirm();
        } else {
          setState(() => _step = 2);
        }
      } else {
        setState(() => _step = 1);
      }
    } else if (_step == 1) {
      if (_collections.isEmpty && !_loadingCollections) {
        _confirm();
      } else {
        setState(() => _step = 2);
      }
    } else {
      _confirm();
    }
  }

  void _confirm() {
    final title = _titleCtrl.text.trim().isEmpty
        ? widget.defaultTitle
        : _titleCtrl.text.trim();
    final author = (_authorName?.trim().isEmpty ?? true)
        ? null
        : _authorName!.trim();
    Navigator.of(context).pop(ImportDetails(
      title: title,
      authorName: author,
      setlistIds: List.from(_selectedSetlistIds),
      collectionIds: List.from(_selectedCollectionIds),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_step == 0 ? 'Dettagli spartito' : _step == 1 ? 'Aggiungi a una lista' : 'Aggiungi a una raccolta'),
      content: _step == 0 ? _buildStep0() : _step == 1 ? _buildStep1() : _buildStep2(),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla')),
        if (_step == 1 || _step == 2)
          TextButton(
              onPressed: () => setState(() => _step = _step == 2 ? 1 : 0),
              child: const Text('Indietro')),
        FilledButton(
            onPressed: _next,
            child: Text(_step == 0 ? 'Avanti' : _step == 1 ? 'Avanti' : 'Importa')),
      ],
    );
  }

  Widget _buildStep0() => SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Titolo'),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            ComposerAutocompleteField(
              initialValue: _authorName,
              onChanged: (v) => _authorName = v,
              label: 'Autore (opzionale)',
            ),
          ],
        ),
      );

  Widget _buildStep1() {
    if (_loadingSetlists) {
      return const SizedBox(
          height: 80, child: Center(child: CircularProgressIndicator()));
    }
    if (_setlists.isEmpty) {
      return const Text(
          'Nessuna lista disponibile.\nPotrai aggiungere lo spartito a una lista in seguito.');
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _setlists
            .map((s) => CheckboxListTile(
                  title: Text(s.title),
                  value: _selectedSetlistIds.contains(s.id),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selectedSetlistIds.add(s.id!);
                    } else {
                      _selectedSetlistIds.remove(s.id);
                    }
                  }),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildStep2() {
    if (_loadingCollections) {
      return const SizedBox(
          height: 80, child: Center(child: CircularProgressIndicator()));
    }
    if (_collections.isEmpty) {
      return const Text(
          'Nessuna raccolta disponibile.\nPotrai aggiungere lo spartito a una raccolta in seguito.');
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _collections
            .map((c) => CheckboxListTile(
                  title: Text(c.name),
                  value: _selectedCollectionIds.contains(c.id),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selectedCollectionIds.add(c.id!);
                    } else {
                      _selectedCollectionIds.remove(c.id);
                    }
                  }),
                ))
            .toList(),
      ),
    );
  }
}
