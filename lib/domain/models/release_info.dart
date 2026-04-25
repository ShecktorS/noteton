/// Informazioni su una release GitHub.
class ReleaseInfo {
  final String version;      // es. '0.5.1' (tag_name senza prefisso 'v')
  final String downloadUrl;  // browser_download_url dell'asset .apk
  final String changelog;    // body markdown della release
  final DateTime publishedAt;

  const ReleaseInfo({
    required this.version,
    required this.downloadUrl,
    required this.changelog,
    required this.publishedAt,
  });

  /// Costruisce da risposta JSON dell'API GitHub Releases.
  /// Ritorna null se la struttura è inattesa o manca l'asset APK.
  static ReleaseInfo? fromJson(Map<String, dynamic> json) {
    try {
      final rawTag = json['tag_name'] as String? ?? '';
      final version = rawTag.replaceAll('v', '');
      if (version.isEmpty) return null;

      final assets = json['assets'] as List<dynamic>? ?? [];
      final apkAsset = assets.firstWhere(
        (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
        orElse: () => null,
      );
      if (apkAsset == null) return null;

      final downloadUrl =
          apkAsset['browser_download_url'] as String? ?? '';
      if (downloadUrl.isEmpty) return null;

      final publishedRaw = json['published_at'] as String? ?? '';
      final publishedAt = publishedRaw.isNotEmpty
          ? DateTime.tryParse(publishedRaw) ?? DateTime.now()
          : DateTime.now();

      return ReleaseInfo(
        version: version,
        downloadUrl: downloadUrl,
        changelog: (json['body'] as String?) ?? '',
        publishedAt: publishedAt,
      );
    } catch (_) {
      return null;
    }
  }

  /// true se questa versione è più recente di [currentVersion].
  bool isNewerThan(String currentVersion) {
    final a = _parseVersion(version);
    final b = _parseVersion(currentVersion);
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return a.length > b.length;
  }

  /// Data formattata in italiano senza dipendenze di locale.
  String get formattedDate {
    const months = [
      'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
      'lug', 'ago', 'set', 'ott', 'nov', 'dic',
    ];
    final d = publishedAt.toLocal();
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static List<int> _parseVersion(String v) {
    return v
        .replaceAll('v', '')
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
  }
}
