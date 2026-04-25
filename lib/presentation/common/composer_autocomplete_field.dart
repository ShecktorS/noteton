import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/composer.dart';
import '../../providers/providers.dart';

/// Campo autore con autocomplete sui compositori già registrati.
///
/// Comportamento:
/// - L'utente digita liberamente: il valore textuale è esposto come `String?`
///   tramite [onChanged] (null se vuoto).
/// - Da 2 caratteri in poi appaiono suggerimenti dai compositori esistenti
///   (case-insensitive prefix match, limite 8).
/// - Tap su un suggerimento sostituisce il testo con il nome canonico.
///
/// Lo screen che lo ospita resta responsabile di chiamare `findOrCreate`
/// in fase di salvataggio: questo widget gestisce solo input + suggerimenti.
class ComposerAutocompleteField extends ConsumerStatefulWidget {
  /// Valore iniziale (nome del compositore).
  final String? initialValue;
  final ValueChanged<String?> onChanged;
  final String label;
  final TextInputAction textInputAction;

  const ComposerAutocompleteField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.label = 'Autore',
    this.textInputAction = TextInputAction.next,
  });

  @override
  ConsumerState<ComposerAutocompleteField> createState() =>
      _ComposerAutocompleteFieldState();
}

class _ComposerAutocompleteFieldState
    extends ConsumerState<ComposerAutocompleteField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    widget.onChanged(text.isEmpty ? null : text);
    if (_focusNode.hasFocus && text.length >= 2) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideOverlay();
    } else if (_controller.text.trim().length >= 2) {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _overlay?.remove();
    _overlay = _buildOverlay();
    Overlay.of(context).insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  OverlayEntry _buildOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (ctx) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
            child: Consumer(
              builder: (context, ref, _) {
                final query = _controller.text.trim();
                final asyncList =
                    ref.watch(composerSuggestionsProvider(query));

                return asyncList.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 16,
                      child: LinearProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (composers) {
                    if (composers.isEmpty) return const SizedBox.shrink();
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: composers.length,
                        itemBuilder: (context, index) {
                          final c = composers[index];
                          return _SuggestionTile(
                            composer: c,
                            onTap: () => _selectComposer(c),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _selectComposer(Composer c) {
    _controller.removeListener(_onTextChanged);
    _controller.text = c.name;
    _controller.selection = TextSelection.collapsed(offset: c.name.length);
    _controller.addListener(_onTextChanged);
    widget.onChanged(c.name);
    _hideOverlay();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: widget.textInputAction,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.person_outline, size: 20),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _controller.clear();
                    _hideOverlay();
                  },
                )
              : null,
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final Composer composer;
  final VoidCallback onTap;

  const _SuggestionTile({required this.composer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String? subtitle;
    if (composer.bornYear != null && composer.diedYear != null) {
      subtitle = '${composer.bornYear} – ${composer.diedYear}';
    } else if (composer.bornYear != null) {
      subtitle = 'Nato nel ${composer.bornYear}';
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Text(
                composer.name.isNotEmpty ? composer.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(composer.name,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subtitle != null)
                    Text(subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
