import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/core/services/whats_new_service.dart';
import 'package:noteton/domain/models/release_info.dart';

void main() {
  group('WhatsNewService.shouldShow', () {
    test('mostra le novità se la versione corrente non è stata vista', () {
      expect(
        WhatsNewService.shouldShow(
          currentVersion: '0.12.0-beta.1',
          seenVersion: '0.11.1',
        ),
        isTrue,
      );
    });

    test('non mostra le novità se la versione corrente è già stata vista', () {
      expect(
        WhatsNewService.shouldShow(
          currentVersion: '0.12.0-beta.1',
          seenVersion: '0.12.0-beta.1',
        ),
        isFalse,
      );
    });

    test('non mostra nulla con versione corrente vuota', () {
      expect(
        WhatsNewService.shouldShow(currentVersion: '', seenVersion: null),
        isFalse,
      );
    });
  });

  group('WhatsNewInfo', () {
    test('usa il changelog della release quando presente', () {
      final info = WhatsNewInfo(
        version: '0.12.0',
        release: ReleaseInfo(
          version: '0.12.0',
          downloadUrl: 'https://example.com/app.apk',
          changelog: 'Nuove funzioni',
          publishedAt: DateTime.utc(2026, 6, 28),
        ),
      );

      expect(info.changelog, 'Nuove funzioni');
      expect(info.isPrerelease, isFalse);
    });

    test('usa fallback e riconosce prerelease dal version name', () {
      const info = WhatsNewInfo(version: '0.12.0-beta.1');

      expect(info.isPrerelease, isTrue);
      expect(info.changelog, contains('Noteton v0.12.0-beta.1'));
    });
  });
}
