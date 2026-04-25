import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';

/// Campo album con autocomplete su album già usati nei brani esistenti.
/// Da 2 caratteri in poi suggerisce match prefix da `SELECT DISTINCT album`.
class AlbumAutocompleteField extends ConsumerStatefulWidget {
  final String? initialValue;
  final ValueChanged<String?> onChanged;
  final String label;

  const AlbumAutocompleteField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.label = 'Album / Raccolta',
  });

  @override
  ConsumerState<AlbumAutocompleteField> createState() =>
      _AlbumAutocompleteFieldState();
}

class _AlbumAutocompleteFieldState
    extends ConsumerState<AlbumAutocompleteField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.initialValue ?? ''),
      optionsBuilder: (textEditingValue) async {
        final query = textEditingValue.text.trim();
        if (query.length < 2) return const Iterable<String>.empty();
        final results =
            await ref.read(albumSuggestionsProvider(query).future);
        return results;
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        // Sincronizziamo il nostro controller con quello di Autocomplete
        // così possiamo gestire lo stato (clear, label, ecc.)
        controller.addListener(() {
          final text = controller.text.trim();
          widget.onChanged(text.isEmpty ? null : text);
        });
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.album_outlined, size: 20),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      controller.clear();
                      widget.onChanged(null);
                    },
                  )
                : null,
          ),
          onSubmitted: (_) => onSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 380),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.album_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.outline),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(option,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (selected) => widget.onChanged(selected),
    );
  }
}
