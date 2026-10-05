import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/core/services/update_service.dart';
import 'package:noteton/core/theme/app_theme.dart';
import 'package:noteton/domain/models/release_info.dart';
import 'package:noteton/presentation/common/update_home_banner.dart';
import 'package:noteton/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AvailableNotifier extends UpdateNotifier {
  _AvailableNotifier(ReleaseInfo r) : super(const UpdateService()) {
    // ignore: invalid_use_of_protected_member
    state = UpdateAvailable(r);
  }
}

final _release = ReleaseInfo(
  version: '0.13.0-beta.1',
  downloadUrl: 'https://example.com/n.apk',
  changelog: '## Novità\n- Voce uno\n- Voce due\n- Voce tre\n- Voce quattro\n',
  publishedAt: DateTime(2026, 10, 4),
  prerelease: true,
);

Widget _app(ThemeData theme) => ProviderScope(
      overrides: [
        updateProvider.overrideWith((ref) => _AvailableNotifier(_release)),
      ],
      child: MaterialApp(
        theme: theme,
        home: const Scaffold(body: UpdateHomeBanner()),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final variant in ColorVariant.values) {
    for (final dark in [true, false]) {
      testWidgets('banner ${variant.name} ${dark ? 'dark' : 'light'}',
          (tester) async {
        await tester.pumpWidget(
            _app(dark ? AppTheme.dark(variant) : AppTheme.light(variant)));
        await tester.pumpAndSettle();

        expect(find.text('NUOVA VERSIONE'), findsOneWidget);
        expect(find.text('BETA'), findsOneWidget);
        expect(find.text('Noteton 0.13.0-beta.1'), findsOneWidget);
        // Anteprima: due voci + contatore delle restanti.
        expect(find.text('Voce uno'), findsOneWidget);
        expect(find.text('Voce due'), findsOneWidget);
        expect(find.text('Voce tre'), findsNothing);
        expect(find.text('+2 altre novità'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('"Leggi tutto" apre il changelog completo', (tester) async {
    await tester.pumpWidget(_app(AppTheme.dark()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leggi tutto'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('NOVITÀ'), findsOneWidget);
    expect(find.text('Voce quattro'), findsOneWidget);
  });

  testWidgets('la X nasconde il banner per la sessione', (tester) async {
    await tester.pumpWidget(_app(AppTheme.dark()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Più tardi'));
    await tester.pumpAndSettle();

    expect(find.text('NUOVA VERSIONE'), findsNothing);
  });
}
