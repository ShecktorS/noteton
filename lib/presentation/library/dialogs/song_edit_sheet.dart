import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/models/song.dart';
import '../../../providers/providers.dart';
import '../../common/album_autocomplete_field.dart';
import '../../common/composer_autocomplete_field.dart';
import '../../common/key_signature_picker.dart';

const _instruments = [
  'Pianoforte', 'Organo', 'Chitarra', 'Chitarra Basso', 'Violino', 'Viola',
  'Violoncello', 'Contrabbasso', 'Flauto', 'Oboe', 'Clarinetto', 'Fagotto',
  'Sassofono', 'Tromba', 'Corno', 'Trombone', 'Tuba', 'Percussioni',
  'Voce', 'Ensemble', 'Altro',
];

/// Bottom sheet "Modifica dettagli" di un brano. Salva le modifiche e
/// invalida la libreria solo se l'utente conferma.
Future<void> showSongEditSheet(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  final titleCtrl = TextEditingController(text: song.title);
  final bpmCtrl = TextEditingController(text: song.bpm != null ? '${song.bpm}' : '');

  String? authorName = song.composerName;
  String? albumName = song.album;
  String? selectedPeriod = song.period;
  String? selectedKey = song.keySignature;
  String? selectedInstrument = song.instrument;

  try {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.55,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header sticky con titolo + Salva
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Modifica dettagli',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annulla'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Salva'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Titolo'),
                          autofocus: false,
                          textCapitalization:
                              TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 14),
                        ComposerAutocompleteField(
                          initialValue: authorName,
                          onChanged: (v) => authorName = v,
                          label: 'Autore (opzionale)',
                        ),
                        const SizedBox(height: 14),
                        AlbumAutocompleteField(
                          initialValue: albumName,
                          onChanged: (v) => albumName = v,
                          label: 'Album / Raccolta (opzionale)',
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedPeriod,
                          decoration: const InputDecoration(
                              labelText:
                                  'Periodo / Genere (opzionale)'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                                value: null,
                                child: Text('Nessuno',
                                    style: TextStyle(color: Colors.grey))),
                            ...AppConstants.musicalPeriods.map((p) =>
                                DropdownMenuItem(
                                    value: p, child: Text(p))),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => selectedPeriod = v),
                        ),
                        const SizedBox(height: 18),
                        KeySignaturePicker(
                          value: selectedKey,
                          onChanged: (v) =>
                              setDialogState(() => selectedKey = v),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: bpmCtrl,
                          decoration: const InputDecoration(
                              labelText: 'BPM (opzionale)'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedInstrument,
                          decoration: const InputDecoration(
                              labelText: 'Strumento'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                                value: null,
                                child: Text('Nessuno',
                                    style: TextStyle(color: Colors.grey))),
                            ..._instruments.map((s) =>
                                DropdownMenuItem(
                                    value: s, child: Text(s))),
                          ],
                          onChanged: (v) => setDialogState(
                              () => selectedInstrument = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final newTitle = titleCtrl.text.trim().isEmpty ? song.title : titleCtrl.text.trim();
    final newAuthor =
        (authorName?.trim().isEmpty ?? true) ? null : authorName!.trim();
    final newAlbum =
        (albumName?.trim().isEmpty ?? true) ? null : albumName!.trim();
    final newBpm = int.tryParse(bpmCtrl.text.trim());

    int? composerId;
    if (newAuthor != null) {
      final composer = await ref.read(composerRepositoryProvider).findOrCreate(newAuthor);
      composerId = composer.id;
    }
    if (!context.mounted) return;

    await ref.read(songRepositoryProvider).update(song.copyWith(
      title: newTitle,
      composerId: composerId,
      clearComposerId: newAuthor == null,
      keySignature: selectedKey,
      clearKeySignature: selectedKey == null,
      bpm: newBpm,
      clearBpm: newBpm == null,
      instrument: selectedInstrument,
      clearInstrument: selectedInstrument == null,
      album: newAlbum,
      clearAlbum: newAlbum == null,
      period: selectedPeriod,
      clearPeriod: selectedPeriod == null,
      updatedAt: DateTime.now(),
    ));
    ref.invalidate(songsProvider);
  } finally {
    titleCtrl.dispose();
    bpmCtrl.dispose();
  }
}
