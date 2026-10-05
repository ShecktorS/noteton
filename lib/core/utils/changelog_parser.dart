/// Parsing minimale del changelog markdown delle release GitHub,
/// sufficiente per mostrarlo con i motivi del brand (niente dipendenze
/// markdown: le release usano solo titoli, elenchi e paragrafi).
enum ChangelogBlockKind { heading, item, text }

class ChangelogBlock {
  final ChangelogBlockKind kind;
  final String text;

  const ChangelogBlock(this.kind, this.text);

  @override
  bool operator ==(Object other) =>
      other is ChangelogBlock && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => 'ChangelogBlock($kind, $text)';
}

class ChangelogParser {
  ChangelogParser._();

  static final _bullet = RegExp(r'^([-*+]|\d+[.)])\s+');
  static final _heading = RegExp(r'^#{1,6}\s*');

  /// Divide il markdown in blocchi: titoli (`#`), voci di elenco
  /// (`-`, `*`, `+`, `1.`) e righe di testo. Ignora righe vuote,
  /// separatori `---` e citazioni `>`.
  static List<ChangelogBlock> parse(String md) {
    final blocks = <ChangelogBlock>[];
    for (final raw in md.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('---') || line.startsWith('>')) {
        continue;
      }
      if (_heading.hasMatch(line)) {
        final t = _clean(line.replaceFirst(_heading, ''));
        if (t.isNotEmpty) blocks.add(ChangelogBlock(ChangelogBlockKind.heading, t));
      } else if (_bullet.hasMatch(line)) {
        final t = _clean(line.replaceFirst(_bullet, ''));
        if (t.isNotEmpty) blocks.add(ChangelogBlock(ChangelogBlockKind.item, t));
      } else {
        blocks.add(ChangelogBlock(ChangelogBlockKind.text, _clean(line)));
      }
    }
    return blocks;
  }

  /// Le voci salienti per un'anteprima: prima le voci di elenco,
  /// in mancanza di queste le righe di testo.
  static List<String> highlights(String md) {
    final blocks = parse(md);
    final items = blocks
        .where((b) => b.kind == ChangelogBlockKind.item)
        .map((b) => b.text)
        .toList();
    if (items.isNotEmpty) return items;
    return blocks
        .where((b) => b.kind == ChangelogBlockKind.text)
        .map((b) => b.text)
        .toList();
  }

  /// Rimuove l'enfasi markdown più comune (`**`, `__`, `` ` ``).
  static String _clean(String s) =>
      s.replaceAll('**', '').replaceAll('__', '').replaceAll('`', '').trim();
}
