import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/release_info.dart';
import '../constants/app_constants.dart';

class WhatsNewInfo {
  final String version;
  final ReleaseInfo? release;

  const WhatsNewInfo({
    required this.version,
    this.release,
  });

  bool get isPrerelease =>
      release?.prerelease ??
      RegExp(r'-(alpha|beta|rc)\.?', caseSensitive: false).hasMatch(version);

  String get changelog {
    final body = release?.changelog.trim() ?? '';
    if (body.isNotEmpty) return body;
    return 'Aggiornamento completato. Stai usando Noteton v$version.';
  }

  DateTime? get publishedAt => release?.publishedAt;
}

class WhatsNewService {
  static const prefSeenVersion = 'whats_new_seen_version';

  const WhatsNewService();

  static bool shouldShow({
    required String currentVersion,
    String? seenVersion,
  }) {
    return currentVersion.trim().isNotEmpty && seenVersion != currentVersion;
  }

  Future<WhatsNewInfo?> getPendingWhatsNew() async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    final prefs = await SharedPreferences.getInstance();
    final seenVersion = prefs.getString(prefSeenVersion);

    if (!shouldShow(
      currentVersion: currentVersion,
      seenVersion: seenVersion,
    )) {
      return null;
    }

    return getCurrentWhatsNew(versionOverride: currentVersion);
  }

  Future<WhatsNewInfo> getCurrentWhatsNew({String? versionOverride}) async {
    final version =
        versionOverride ?? (await PackageInfo.fromPlatform()).version;
    final release = await _fetchReleaseForVersion(version);
    return WhatsNewInfo(version: version, release: release);
  }

  Future<void> markSeen(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefSeenVersion, version);
  }

  Future<ReleaseInfo?> _fetchReleaseForVersion(String version) async {
    try {
      final response = await http.get(
        Uri.parse(AppConstants.githubApiReleaseByTag('v$version')),
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ReleaseInfo.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
