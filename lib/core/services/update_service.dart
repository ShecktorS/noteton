import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../../domain/models/release_info.dart';

/// Controlla GitHub Releases, scarica l'APK e lancia il package installer.
class UpdateService {
  const UpdateService();

  static const _channel = MethodChannel('com.example.noteton/update');

  /// Controlla se esiste una versione più recente su GitHub.
  /// Ritorna null se già aggiornati o se il repo non ha asset APK.
  Future<ReleaseInfo?> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version; // es. '0.5.0'

    final response = await http
        .get(
          Uri.parse(AppConstants.githubApiLatestRelease),
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('GitHub API: HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final release = ReleaseInfo.fromJson(json);
    if (release == null || !release.isNewerThan(current)) return null;
    return release;
  }

  /// Scarica l'APK nella cartella temporanea, emettendo progresso (0.0–1.0).
  Future<String> downloadApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    final cacheDir = await getTemporaryDirectory();
    final apkPath = '${cacheDir.path}/noteton-update.apk';

    final request = http.Request('GET', Uri.parse(url));
    final streamedResponse = await request.send();
    final total = streamedResponse.contentLength ?? 0;
    int received = 0;

    final sink = File(apkPath).openWrite();
    try {
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
    } finally {
      await sink.close();
    }

    return apkPath;
  }

  /// Lancia il package installer Android tramite platform channel.
  Future<void> installApk(String apkPath) async {
    await _channel.invokeMethod<void>('installApk', {'path': apkPath});
  }
}
