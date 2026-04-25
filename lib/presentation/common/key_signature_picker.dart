import 'package:flutter/material.dart';

import '../../core/utils/key_signature_localization.dart';

/// Picker tonalità diviso in due passaggi:
///   1. Selezione del modo (Maggiore / Minore) tramite SegmentedButton
///   2. Selezione della nota tramite Wrap di FilterChip
///
/// Memorizza il risultato come stringa singola compatibile col DB
/// (es. 'C', 'F♯m'). Espone [value] e [onChanged] tipo `String?`.
class KeySignaturePicker extends StatefulWidget {
  /// Valore attuale (storage format: 'C', 'C#m', null = nessuna).
  final String? value;
  final ValueChanged<String?> onChanged;

  /// Etichetta sopra il picker (default: "Tonalità").
  final String label;

  const KeySignaturePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Tonalità',
  });

  @override
  State<KeySignaturePicker> createState() => _KeySignaturePickerState();
}

class _KeySignaturePickerState extends State<KeySignaturePicker> {
  late bool _isMinor;
  late String? _note; // notazione inglese (es. 'C', 'F#')

  @override
  void initState() {
    super.initState();
    _hydrateFromValue(widget.value);
  }

  @override
  void didUpdateWidget(covariant KeySignaturePicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _hydrateFromValue(widget.value);
  }

  void _hydrateFromValue(String? stored) {
    final split = KeySignatureLocalization.splitKey(stored);
    _isMinor = split?.isMinor ?? false;
    _note = split?.note;
  }

  void _emit() {
    final note = _note;
    if (note == null) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(
      KeySignatureLocalization.joinKey(note, isMinor: _isMinor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_note != null)
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Pulisci'),
                onPressed: () {
                  setState(() => _note = null);
                  _emit();
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Modo
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Maggiore')),
            ButtonSegment(value: true, label: Text('Minore')),
          ],
          selected: {_isMinor},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            setState(() => _isMinor = s.first);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        // Nota
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: KeySignatureLocalization.notesEnglish.map((noteEn) {
            final selected = _note == noteEn;
            return FilterChip(
              label: Text(KeySignatureLocalization.displayNote(noteEn, locale)),
              selected: selected,
              showCheckmark: false,
              onSelected: (sel) {
                setState(() => _note = sel ? noteEn : null);
                _emit();
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
