import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../../domain/models/release_info.dart';
import '../../domain/models/update_channel.dart';

/// Controlla GitHub Releases, scarica l'APK e lancia il package installer.
class UpdateService {
  const UpdateService();

  static const _channel = MethodChannel('com.example.noteton/update');

  /// Controlla se esiste una versione più recente su GitHub.
  /// Ritorna null se già aggiornati o se il repo non ha asset APK.
  ///
  /// [channel]: canale stabile o beta scelto dall'utente.
  /// Il canale beta include anche pre-release (beta, alpha, rc).
  Future<ReleaseInfo?> checkForUpdate({
    UpdateChannel channel = UpdateChannel.stable,
  }) async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version; // es. '0.5.0'

    final url = channel.includesPrereleases
        ? AppConstants.githubApiAllReleases
        : AppConstants.githubApiLatestRelease;

    final response = await http
        .get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('GitHub API: HTTP ${response.statusCode}');
    }

    ReleaseInfo? release;

    if (channel.includesPrereleases) {
      // API /releases ritorna array ordinato per data DESC, ma scegliamo
      // comunque la versione semanticamente più nuova per evitare che una
      // release pubblicata più tardi ma numericamente più vecchia vinca.
      final jsonList = jsonDecode(response.body) as List<dynamic>;
      for (final item in jsonList) {
        if (item is! Map<String, dynamic> || item['draft'] == true) {
          continue;
        }
        final candidate = ReleaseInfo.fromJson(item);
        if (candidate == null || !candidate.isNewerThan(current)) continue;
        if (release == null || candidate.isNewerThan(release.version)) {
          release = candidate;
        }
      }
    } else {
      // API /latest ritorna singolo oggetto e GitHub esclude le pre-release.
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      release = ReleaseInfo.fromJson(json);
      if (release == null || !release.isNewerThan(current)) return null;
    }

    return release;
  }

  /// Host da cui è ammesso scaricare l'APK (asset delle GitHub Releases).
  static const _allowedDownloadHosts = {'github.com'};

  /// Scarica l'APK nella cartella temporanea, emettendo progresso (0.0–1.0).
  ///
  /// Accetta solo URL https verso GitHub, rifiuta risposte non 200 e
  /// download troncati. Se [expectedSha256] è noto (campo `digest`
  /// dell'asset), verifica l'hash del file prima di restituirlo.
  Future<String> downloadApk(
    String url,
    void Function(double progress) onProgress, {
    String? expectedSha256,
  }) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || !_allowedDownloadHosts.contains(uri.host)) {
      throw Exception('URL di download non ammesso: $url');
    }

    final cacheDir = await getTemporaryDirectory();
    final apkFile = File('${cacheDir.path}/noteton-update.apk');

    final request = http.Request('GET', uri);
    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 30));
    if (streamedResponse.statusCode != 200) {
      throw Exception('Download APK: HTTP ${streamedResponse.statusCode}');
    }
    final total = streamedResponse.contentLength ?? 0;
    int received = 0;

    final sink = apkFile.openWrite();
    try {
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
    } finally {
      await sink.close();
    }

    try {
      if (total > 0 && received != total) {
        throw Exception('Download APK incompleto: $received/$total byte');
      }
      if (expectedSha256 != null) {
        final digest = await sha256.bind(apkFile.openRead()).first;
        if (digest.toString() != expectedSha256.toLowerCase()) {
          throw Exception('Hash dell\'APK non corrisponde alla release');
        }
      }
    } catch (_) {
      if (await apkFile.exists()) await apkFile.delete();
      rethrow;
    }

    return apkFile.path;
  }

  /// Lancia il package installer Android tramite platform channel.
  Future<void> installApk(String apkPath) async {
    await _channel.invokeMethod<void>('installApk', {'path': apkPath});
  }
}
