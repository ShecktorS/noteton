import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/domain/models/song.dart';
import 'package:noteton/presentation/library/dialogs/tag_picker_dialog.dart';
import 'package:noteton/presentation/library/widgets/alpha_scroll_bar.dart';
import 'package:noteton/presentation/library/widgets/library_sort.dart';
import 'package:noteton/providers/providers.dart';

Song song(String title, {DateTime? created, DateTime? updated}) => Song(
      id: title.hashCode,
      title: title,
      filePath: '$title.pdf',
      totalPages: 1,
      lastPage: 0,
      createdAt: created ?? DateTime(2024),
      updatedAt: updated ?? DateTime(2024),
    );

void main() {
  group('sortSongs', () {
    final a =
        song('alba', created: DateTime(2024, 1), updated: DateTime(2024, 6));
    final b =
        song('Bolero', created: DateTime(2024, 3), updated: DateTime(2024, 2));
    final c =
        song('canone', created: DateTime(2024, 2), updated: DateTime(2024, 9));

    test('titolo A → Z ignora maiuscole', () {
      expect(sortSongs([c, b, a], SortOrder.titleAZ), [a, b, c]);
    });

    test('titolo Z → A', () {
      expect(sortSongs([a, c, b], SortOrder.titleZA), [c, b, a]);
    });

    test('più recenti per data di creazione', () {
      expect(sortSongs([a, b, c], SortOrder.newestFirst), [b, c, a]);
    });

    test('ultima apertura per data di aggiornamento', () {
      expect(sortSongs([a, b, c], SortOrder.lastOpened), [c, a, b]);
    });

    test('non modifica la lista originale', () {
      final input = [c, a];
      sortSongs(input, SortOrder.titleAZ);
      expect(input, [c, a]);
    });
  });

  group('indice A-Z', () {
    test('alphaIndexLetter usa la prima lettera maiuscola', () {
      expect(alphaIndexLetter('  bach'), 'B');
      expect(alphaIndexLetter('Zeta'), 'Z');
    });

    test('alphaIndexLetter manda a # numeri, simboli, accenti e vuoti', () {
      expect(alphaIndexLetter('9 sinfonie'), '#');
      expect(alphaIndexLetter('¡Olé!'), '#');
      expect(alphaIndexLetter('Étude'), '#');
      expect(alphaIndexLetter('   '), '#');
    });

    test('indexOfAlphaLetter trova il primo brano della lettera', () {
      final songs = [
        song('1812'),
        song('Aria'),
        song('Adagio'),
        song('Bolero')
      ];
      expect(indexOfAlphaLetter(songs, '#'), 0);
      expect(indexOfAlphaLetter(songs, 'A'), 1);
      expect(indexOfAlphaLetter(songs, 'B'), 3);
      expect(indexOfAlphaLetter(songs, 'C'), -1);
    });

    testWidgets('AlphaScrollBar segnala la lettera toccata', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(children: [
            const Expanded(child: SizedBox()),
            AlphaScrollBar(
              songs: [song('Aria')],
              onLetterSelected: selected.add,
            ),
          ]),
        ),
      ));

      await tester.tap(find.text('A'));
      expect(selected, ['A']);
    });
  });

  test('parseTagColor legge #RRGGBB e ripiega sul grigio', () {
    expect(parseTagColor('#FF0000'), const Color(0xFFFF0000));
    expect(parseTagColor('rosso'), Colors.grey);
  });
}
