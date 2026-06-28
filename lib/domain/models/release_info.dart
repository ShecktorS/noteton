/// Informazioni su una release GitHub.
class ReleaseInfo {
  final String version;      // es. '0.5.1' (tag_name senza prefisso 'v')
  final String downloadUrl;  // browser_download_url dell'asset .apk
  final String changelog;    // body markdown della release
  final DateTime publishedAt;
  final bool prerelease;     // true se è una pre-release (beta, alpha, rc)

  const ReleaseInfo({
    required this.version,
    required this.downloadUrl,
    required this.changelog,
    required this.publishedAt,
    this.prerelease = false,
  });

  /// Costruisce da risposta JSON dell'API GitHub Releases.
  /// Ritorna null se la struttura è inattesa o manca l'asset APK.
  static ReleaseInfo? fromJson(Map<String, dynamic> json) {
    try {
      final rawTag = json['tag_name'] as String? ?? '';
      final version = _stripPrefix(rawTag);
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
        prerelease: json['prerelease'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  /// true se questa versione è più recente di [currentVersion].
  /// Gestisce semantic versioning con pre-release:
  /// 0.11.0 > 0.11.0-beta.10 > 0.11.0-beta.2 > 0.10.3.
  bool isNewerThan(String currentVersion) {
    final a = _parseSemanticVersion(version);
    final b = _parseSemanticVersion(currentVersion);

    final numberCompare = _compareNumbers(a.numbers, b.numbers);
    if (numberCompare != 0) return numberCompare > 0;

    return _comparePrerelease(a.prerelease, b.prerelease) > 0;
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

  /// Rimuove un eventuale prefisso 'v' del tag (es. 'v0.10.1' → '0.10.1')
  /// senza toccare altre 'v' né suffissi di build ('+20').
  static String _stripPrefix(String tag) {
    return tag.replaceFirst(RegExp(r'^v'), '').trim();
  }

  static ({List<int> numbers, List<String>? prerelease})
      _parseSemanticVersion(String v) {
    final cleaned = _stripPrefix(v).split('+').first; // rimuove build number
    final parts = cleaned.split('-'); // separa versione da pre-release

    final numbers = parts[0]
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    // Padding minimo major.minor.patch, senza perdere eventuali componenti
    // extra già supportati dai test esistenti (es. 0.10.1.1).
    while (numbers.length < 3) {
      numbers.add(0);
    }

    final prerelease = parts.length > 1
        ? parts.sublist(1).join('-').split('.')
        : null;

    return (numbers: numbers, prerelease: prerelease);
  }

  static int _compareNumbers(List<int> a, List<int> b) {
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  static int _comparePrerelease(List<String>? a, List<String>? b) {
    // Stable (nessun suffisso) ha precedenza maggiore della pre-release.
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      if (i >= a.length) return -1;
      if (i >= b.length) return 1;

      final av = a[i];
      final bv = b[i];
      final ai = int.tryParse(av);
      final bi = int.tryParse(bv);

      if (ai != null && bi != null) {
        if (ai != bi) return ai.compareTo(bi);
        continue;
      }
      if (ai != null) return -1;
      if (bi != null) return 1;

      final textCompare = av.compareTo(bv);
      if (textCompare != 0) return textCompare;
    }
    return 0;
  }
}
