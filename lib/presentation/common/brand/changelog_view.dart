import 'package:flutter/material.dart';

import '../../../core/theme/brand.dart';
import '../../../core/utils/changelog_parser.dart';
import 'brand_motifs.dart';

/// Voce di elenco con testa di nota come punto elenco.
class NoteBulletItem extends StatelessWidget {
  final String text;
  final int? maxLines;
  final TextStyle? style;

  const NoteBulletItem(this.text, {super.key, this.maxLines, this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = style ?? theme.textTheme.bodyMedium;
    final lineHeight = (textStyle?.fontSize ?? 14) * (textStyle?.height ?? 1.4);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: lineHeight,
          child: Center(
            child: NoteHeadBullet(
              color: NotetonBrand.accent(theme.colorScheme),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );
  }
}

/// Changelog completo: titoli di sezione come occhielli, voci con
/// testa di nota, paragrafi come testo semplice.
class ChangelogView extends StatelessWidget {
  final String markdown;
  final String emptyText;

  const ChangelogView(
    this.markdown, {
    super.key,
    this.emptyText = 'Nessuna nota di rilascio fornita.',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = ChangelogParser.parse(markdown);
    if (blocks.isEmpty) {
      return Text(emptyText, style: theme.textTheme.bodyMedium);
    }
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.4);
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final gap = i == 0
          ? 0.0
          : b.kind == ChangelogBlockKind.heading
              ? NotetonBrand.space4
              : NotetonBrand.space2;
      if (gap > 0) children.add(SizedBox(height: gap));
      children.add(switch (b.kind) {
        ChangelogBlockKind.heading => BrandEyebrow(b.text),
        ChangelogBlockKind.item => NoteBulletItem(b.text, style: bodyStyle),
        ChangelogBlockKind.text => Text(b.text, style: bodyStyle),
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
