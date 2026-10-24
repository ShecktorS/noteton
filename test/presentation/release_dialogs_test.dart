import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/core/services/whats_new_service.dart';
import 'package:noteton/core/theme/app_theme.dart';
import 'package:noteton/domain/models/release_info.dart';
import 'package:noteton/presentation/common/release_dialogs.dart';

Future<void> _open(WidgetTester tester, ThemeData theme,
    void Function(BuildContext) show) async {
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(onPressed: () => show(context), child: const Text('apri')),
      ),
    ),
  ));
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
}

void main() {
  final release = ReleaseInfo(
    version: '0.13.0',
    downloadUrl: 'https://example.com/n.apk',
    changelog: '## Correzioni\n- Fix viewer\n',
    publishedAt: DateTime(2026, 10, 4),
  );

  testWidgets('Novità: intestazione di brand e changelog strutturato',
      (tester) async {
    await _open(
      tester,
      AppTheme.light(ColorVariant.purple),
      (c) => showWhatsNewDialog(
        c,
        WhatsNewInfo(version: '0.13.0', release: release),
        confirmLabel: 'Ho capito',
      ),
    );
    expect(find.text('VERSIONE INSTALLATA'), findsOneWidget);
    expect(find.text('Noteton 0.13.0'), findsOneWidget);
    expect(find.text('CORREZIONI'), findsOneWidget);
    expect(find.text('Fix viewer'), findsOneWidget);
    expect(find.text('BETA'), findsNothing);

    await tester.tap(find.text('Ho capito'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Novità senza release: testo di ripiego, niente data',
      (tester) async {
    await _open(
      tester,
      AppTheme.dark(),
      (c) => showWhatsNewDialog(c, const WhatsNewInfo(version: '0.13.0-beta.1')),
    );
    expect(find.text('BETA'), findsOneWidget);
    expect(find.textContaining('Pubblicata'), findsNothing);
    expect(find.textContaining('Stai usando Noteton'), findsOneWidget);
  });

  testWidgets('Aggiornamento: "Aggiorna ora" chiude e avvia onUpdate',
      (tester) async {
    var updated = false;
    await _open(
      tester,
      AppTheme.dark(),
      (c) => showReleaseDialog(c,
          release: release,
          dismissLabel: 'Più tardi',
          onUpdate: () => updated = true),
    );
    expect(find.text('NUOVA VERSIONE'), findsOneWidget);
    expect(find.text('Più tardi'), findsOneWidget);
    await tester.tap(find.text('Aggiorna ora'));
    await tester.pumpAndSettle();
    expect(updated, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
