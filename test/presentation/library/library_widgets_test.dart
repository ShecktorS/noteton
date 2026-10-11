import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/domain/models/song.dart';
import 'package:noteton/presentation/library/sheets/sort_sheet.dart';
import 'package:noteton/presentation/library/sheets/tag_color.dart';
import 'package:noteton/presentation/library/widgets/library_empty_state.dart';
import 'package:noteton/providers/providers.dart';

Song _song(String title, {required int created, required int updated}) =>
    Song(
      title: title,
      filePath: 'pdfs/$title.pdf',
      totalPages: 1,
      lastPage: 0,
      createdAt: DateTime(2024, 1, created),
      updatedAt: DateTime(2024, 1, updated),
    );

void main() {
  final songs = [
    _song('beta', created: 2, updated: 3),
    _song('Alfa', created: 1, updated: 1),
    _song('gamma', created: 3, updated: 2),
  ];

  List<String> titles(List<Song> l) => l.map((s) => s.title).toList();

  group('sortSongs', () {
    test('titolo A → Z ignora maiuscole', () {
      expect(titles(sortSongs(songs, SortOrder.titleAZ)),
          ['Alfa', 'beta', 'gamma']);
    });
    test('titolo Z → A', () {
      expect(titles(sortSongs(songs, SortOrder.titleZA)),
          ['gamma', 'beta', 'Alfa']);
    });
    test('più recenti', () {
      expect(titles(sortSongs(songs, SortOrder.newestFirst)),
          ['gamma', 'beta', 'Alfa']);
    });
    test('ultima apertura', () {
      expect(titles(sortSongs(songs, SortOrder.lastOpened)),
          ['beta', 'gamma', 'Alfa']);
    });
    test('non modifica la lista originale', () {
      sortSongs(songs, SortOrder.titleAZ);
      expect(titles(songs), ['beta', 'Alfa', 'gamma']);
    });
  });

  group('parseTagColor', () {
    test('hex valido', () {
      expect(parseTagColor('#FF5733'), const Color(0xFFFF5733));
    });
    test('hex non valido ripiega su grigio', () {
      expect(parseTagColor('rosso'), Colors.grey);
    });
  });

  group('LibraryEmptyState', () {
    testWidgets('libreria vuota suggerisce l\'import', (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: LibraryEmptyState())));
      expect(find.text('Nessuno spartito nella libreria'), findsOneWidget);
      expect(find.text('Tocca + per importare un PDF'), findsOneWidget);
    });
    testWidgets('filtro di stato attivo', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: LibraryEmptyState(statusFilter: SongStatus.values.last))));
      expect(find.textContaining('Nessuno spartito con stato'), findsOneWidget);
      expect(find.text('Tocca + per importare un PDF'), findsNothing);
    });
  });
}
