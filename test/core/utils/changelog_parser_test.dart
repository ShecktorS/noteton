import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/core/utils/changelog_parser.dart';

void main() {
  group('ChangelogParser.parse', () {
    test('riconosce titoli, voci e testo, ignorando separatori e citazioni', () {
      const md = '## Novità\n'
          '- Prima voce\n'
          '* **Seconda** voce\n'
          '\n'
          '---\n'
          '> nota interna\n'
          '1. Voce numerata\n'
          'Paragrafo con `codice`\n';
      expect(ChangelogParser.parse(md), const [
        ChangelogBlock(ChangelogBlockKind.heading, 'Novità'),
        ChangelogBlock(ChangelogBlockKind.item, 'Prima voce'),
        ChangelogBlock(ChangelogBlockKind.item, 'Seconda voce'),
        ChangelogBlock(ChangelogBlockKind.item, 'Voce numerata'),
        ChangelogBlock(ChangelogBlockKind.text, 'Paragrafo con codice'),
      ]);
    });

    test('changelog vuoto → nessun blocco', () {
      expect(ChangelogParser.parse('  \n\n'), isEmpty);
    });
  });

  group('ChangelogParser.highlights', () {
    test('preferisce le voci di elenco', () {
      const md = 'Intro\n## Fix\n- Uno\n- Due\n';
      expect(ChangelogParser.highlights(md), ['Uno', 'Due']);
    });

    test('senza elenchi ripiega sulle righe di testo', () {
      const md = '# Titolo\nSolo testo\nAltra riga';
      expect(ChangelogParser.highlights(md), ['Solo testo', 'Altra riga']);
    });
  });
}
