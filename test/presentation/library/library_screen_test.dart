import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noteton/domain/models/song.dart';
import 'package:noteton/presentation/library/library_screen.dart';
import 'package:noteton/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song song(int id, String title, {SongStatus status = SongStatus.none}) => Song(
      id: id,
      title: title,
      filePath: 'mancante_$id.pdf',
      totalPages: 4,
      lastPage: 0,
      status: status,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

Future<void> pumpLibrary(WidgetTester tester, List<Song> songs) async {
  // Telefono verticale: la griglia ha card alte e a 800x600 i titoli
  // finirebbero sotto la barra di navigazione.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const LibraryScreen()),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      songsProvider.overrideWith((ref, filter) async => songs),
      tagsProvider.overrideWith((ref) async => []),
      tagCountsProvider.overrideWith((ref) async => {}),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  await tester.pump();
}

/// Le miniature in caricamento animano all'infinito, quindi niente
/// pumpAndSettle: bastano alcuni frame per aprire e chiudere un foglio.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('libreria vuota mostra l\'invito a importare', (tester) async {
    await pumpLibrary(tester, []);

    expect(find.text('Nessuno spartito nella libreria'), findsOneWidget);
    expect(find.text('Tocca + per importare un PDF'), findsOneWidget);
  });

  testWidgets('mostra i brani in griglia ordinati per titolo', (tester) async {
    await pumpLibrary(tester, [song(1, 'Bolero'), song(2, 'Aria')]);

    final aria = tester.getTopLeft(find.text('Aria'));
    final bolero = tester.getTopLeft(find.text('Bolero'));
    expect(aria.dx, lessThan(bolero.dx));
  });

  testWidgets('pressione lunga entra in selezione multipla', (tester) async {
    await pumpLibrary(tester, [song(1, 'Aria'), song(2, 'Bolero')]);

    await tester.longPress(find.text('Aria'));
    await tester.pump();

    expect(find.text('1 selezionato'), findsOneWidget);
    expect(find.byTooltip('Assegna tag'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('Noteton'), findsOneWidget);
  });

  testWidgets('il pulsante vista passa alla lista', (tester) async {
    await pumpLibrary(tester, [song(1, 'Aria', status: SongStatus.inProgress)]);

    await tester.tap(find.byTooltip('Vista lista'));
    await tester.pump();

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('4 pag.'), findsOneWidget);
    expect(find.text(SongStatus.inProgress.label), findsOneWidget);
  });

  testWidgets('il filtro per stato nasconde gli altri brani', (tester) async {
    await pumpLibrary(tester, [
      song(1, 'Aria', status: SongStatus.inProgress),
      song(2, 'Bolero'),
    ]);

    await tester.tap(find.byTooltip('Filtra'));
    await settle(tester);
    await tester.tap(find.text(SongStatus.inProgress.label).last);
    await settle(tester);

    expect(find.text('Aria'), findsOneWidget);
    expect(find.text('Bolero'), findsNothing);
  });
}
