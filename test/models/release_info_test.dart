import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteton/domain/models/release_info.dart';

/// JSON minimale stile API GitHub Releases con un asset .apk.
///
/// Costruito via [jsonDecode] per riprodurre fedelmente i tipi che arrivano
/// dalla rete (`List<dynamic>` / `Map<String, dynamic>`): i literal Dart
/// verrebbero inferiti con tipi più stretti, non rappresentativi.
Map<String, dynamic> _releaseJson({
  String tag = 'v0.10.1',
  List<Map<String, dynamic>>? assets,
  String published = '2026-06-20T10:00:00Z',
  String body = 'note di rilascio',
}) {
  final defaultAssets = [
    {
      'name': 'Noteton-0.10.1.apk',
      'browser_download_url': 'https://example.com/Noteton-0.10.1.apk',
    },
  ];
  return jsonDecode(jsonEncode({
    'tag_name': tag,
    'published_at': published,
    'body': body,
    'assets': assets ?? defaultAssets,
  })) as Map<String, dynamic>;
}

void main() {
  group('ReleaseInfo.fromJson', () {
    test('estrae versione, url e changelog da un release valido', () {
      final r = ReleaseInfo.fromJson(_releaseJson());
      expect(r, isNotNull);
      expect(r!.version, '0.10.1'); // prefisso 'v' rimosso
      expect(r.downloadUrl, 'https://example.com/Noteton-0.10.1.apk');
      expect(r.changelog, 'note di rilascio');
    });

    test('rimuove solo il prefisso v, non altre v nel tag', () {
      // Bug regressione: replaceAll('v','') avrebbe prodotto '0.10.1-dev'.
      final r = ReleaseInfo.fromJson(_releaseJson(tag: 'v0.10.1-devv'));
      expect(r, isNotNull);
      expect(r!.version, '0.10.1-devv');
    });

    test('ritorna null se nessun asset è un .apk', () {
      final r = ReleaseInfo.fromJson(_releaseJson(assets: [
        {
          'name': 'Noteton-0.10.1.aab',
          'browser_download_url': 'https://example.com/x.aab',
        },
      ]));
      expect(r, isNull);
    });

    test('sceglie l’asset .apk ignorando gli altri', () {
      final r = ReleaseInfo.fromJson(_releaseJson(assets: [
        {
          'name': 'source.zip',
          'browser_download_url': 'https://example.com/source.zip',
        },
        {
          'name': 'Noteton.apk',
          'browser_download_url': 'https://example.com/Noteton.apk',
        },
      ]));
      expect(r, isNotNull);
      expect(r!.downloadUrl, 'https://example.com/Noteton.apk');
    });

    test('ritorna null su tag mancante', () {
      final json = _releaseJson()..remove('tag_name');
      expect(ReleaseInfo.fromJson(json), isNull);
    });
  });

  group('ReleaseInfo.isNewerThan', () {
    ReleaseInfo withVersion(String v) =>
        ReleaseInfo.fromJson(_releaseJson(tag: 'v$v'))!;

    test('confronto numerico, non lessicografico (0.10 > 0.9)', () {
      // Il bug classico: '10' < '9' in confronto stringa, ma 10 > 9 numerico.
      expect(withVersion('0.10.0').isNewerThan('0.9.0'), isTrue);
      expect(withVersion('0.9.0').isNewerThan('0.10.0'), isFalse);
    });

    test('stessa versione NON è più recente (no update offerto)', () {
      // Scenario dell’utente: l’app è già aggiornata → niente prompt.
      expect(withVersion('0.10.1').isNewerThan('0.10.1'), isFalse);
    });

    test('patch più alta è più recente', () {
      expect(withVersion('0.10.1').isNewerThan('0.10.0'), isTrue);
    });

    test('versione più vecchia non è più recente', () {
      expect(withVersion('0.10.0').isNewerThan('0.10.1'), isFalse);
    });

    test('ignora il build number nella versione corrente (0.10.1+20)', () {
      expect(withVersion('0.10.1').isNewerThan('0.10.1+20'), isFalse);
      expect(withVersion('0.10.2').isNewerThan('0.10.1+20'), isTrue);
    });

    test('versione corrente con più componenti', () {
      expect(withVersion('0.10.1').isNewerThan('0.10.1.0'), isFalse);
      expect(withVersion('0.10.1.1').isNewerThan('0.10.1'), isTrue);
    });
  });
}
