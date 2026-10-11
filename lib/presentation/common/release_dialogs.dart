import 'package:flutter/material.dart';

import '../../core/services/whats_new_service.dart';
import '../../core/theme/brand.dart';
import '../../domain/models/release_info.dart';
import 'brand/brand_motifs.dart';
import 'brand/changelog_view.dart';

/// Intestazione di brand per card e dialog legati alle release:
/// occhiello (+ BETA), titolo con cifre tabellari, sottotitolo opzionale.
class ReleaseHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool prerelease;

  const ReleaseHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.prerelease = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandEyebrow(
          eyebrow,
          trailing: prerelease ? const BrandBetaBadge() : null,
        ),
        const SizedBox(height: NotetonBrand.space1),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Dialog "nuova versione disponibile" con changelog completo.
/// [dismissLabel] chiude senza azioni; "Aggiorna ora" chiude e chiama
/// [onUpdate].
Future<void> showReleaseDialog(
  BuildContext context, {
  required ReleaseInfo release,
  required VoidCallback onUpdate,
  String dismissLabel = 'Chiudi',
  bool barrierDismissible = true,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AlertDialog(
      title: ReleaseHeading(
        eyebrow: 'Nuova versione',
        title: 'Noteton ${release.version}',
        subtitle: 'Pubblicata il ${release.formattedDate}',
        prerelease: release.prerelease,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360, maxWidth: 420),
        child: SingleChildScrollView(child: ChangelogView(release.changelog)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
          child: Text(dismissLabel),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Aggiorna ora'),
          onPressed: () {
            Navigator.pop(ctx);
            onUpdate();
          },
        ),
      ],
    ),
  );
}

/// Dialog "Novità" della versione installata (dopo un aggiornamento o
/// da Impostazioni).
Future<void> showWhatsNewDialog(
  BuildContext context,
  WhatsNewInfo info, {
  String confirmLabel = 'Chiudi',
  bool barrierDismissible = true,
}) {
  final release = info.release;
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AlertDialog(
      title: ReleaseHeading(
        eyebrow: 'Versione installata',
        title: 'Noteton ${info.version}',
        subtitle:
            release != null ? 'Pubblicata il ${release.formattedDate}' : null,
        prerelease: info.isPrerelease,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360, maxWidth: 420),
        child: SingleChildScrollView(child: ChangelogView(info.changelog)),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
