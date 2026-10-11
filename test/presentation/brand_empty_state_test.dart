import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/core/theme/app_theme.dart';
import 'package:noteton/core/theme/brand.dart';
import 'package:noteton/presentation/common/brand/brand_empty_state.dart';

void main() {
  for (final dark in [true, false]) {
    testWidgets('stato vuoto ${dark ? 'scuro' : 'chiaro'}', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: Scaffold(
          body: BrandEmptyState(
            icon: Icons.queue_music_rounded,
            title: 'Nessuna setlist',
            message: 'Tocca + per crearne una',
            action: TextButton(
              onPressed: () => tapped = true,
              child: const Text('Cosa sono le Setlist?'),
            ),
          ),
        ),
      ));

      expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
      expect(find.text('Nessuna setlist'), findsOneWidget);
      expect(find.text('Tocca + per crearne una'), findsOneWidget);
      await tester.tap(find.text('Cosa sono le Setlist?'));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('stato vuoto senza messaggio né azione', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(
        body: BrandEmptyState(icon: Icons.music_note_rounded, title: 'Vuoto'),
      ),
    ));
    expect(find.text('Vuoto'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  group('AppTheme: stessa grammatica in chiaro e scuro', () {
    for (final variant in ColorVariant.values) {
      test(variant.name, () {
        for (final t in [AppTheme.dark(variant), AppTheme.light(variant)]) {
          final card = t.cardTheme.shape as RoundedRectangleBorder;
          final dialog = t.dialogTheme.shape as RoundedRectangleBorder;
          expect(card.borderRadius,
              BorderRadius.circular(NotetonBrand.radiusLg));
          expect(dialog.borderRadius,
              BorderRadius.circular(NotetonBrand.radiusXl));
          expect(t.navigationBarTheme.height, 68);
          expect(t.bottomSheetTheme.showDragHandle, isTrue);
          expect(t.snackBarTheme.behavior, SnackBarBehavior.floating);
        }
        // Nel chiaro le card si staccano dal fondo con un bordo.
        final lightCard =
            AppTheme.light(variant).cardTheme.shape as RoundedRectangleBorder;
        expect(lightCard.side.style, BorderStyle.solid);
      });
    }
  });
}
