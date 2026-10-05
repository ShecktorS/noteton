import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/brand.dart';
import '../../core/utils/changelog_parser.dart';
import '../../domain/models/release_info.dart';
import '../../providers/providers.dart';
import 'brand/brand_motifs.dart';
import 'brand/changelog_view.dart';

/// Card "aggiornamento disponibile" da mostrare in cima alla libreria.
/// Segue la linea di brand di `docs/brand.md`: stanghetta d'accento,
/// nota sul pentagramma, voci del changelog con testa di nota.
/// Visibile solo quando:
///   - lo stato update è [UpdateAvailable]
///   - il toggle auto-update è ON (altrimenti l'utente non vuole essere
///     disturbato fuori da Settings)
///   - l'utente non ha dismesso questa versione nella sessione corrente
///
/// Tap su X → dismiss per la sessione (ricompare al prossimo lancio).
/// Tap su "Aggiorna" → avvia download + apre progress dialog.
/// Tap su "Leggi tutto" → mostra dialog completo con changelog.
class UpdateHomeBanner extends ConsumerWidget {
  const UpdateHomeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    final autoEnabled = ref.watch(autoUpdateEnabledProvider);
    final dismissed = ref.watch(dismissedBannerVersionsProvider);

    if (state is! UpdateAvailable ||
        !autoEnabled ||
        dismissed.contains(state.release.version)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: _BannerCard(
        release: state.release,
        onDismiss: () {
          ref.read(dismissedBannerVersionsProvider.notifier).update(
                (s) => {...s, state.release.version},
              );
        },
        onUpdate: () {
          ref.read(updateProvider.notifier).downloadAndInstall(state.release);
          _showDownloadDialog(context, ref);
        },
        onReadMore: () => _showFullDialog(context, ref, state.release),
      ),
    );
  }

  // ── Dialog completo ─────────────────────────────────────────────────────────

  void _showFullDialog(BuildContext context, WidgetRef ref, ReleaseInfo r) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: _ReleaseHeading(release: r),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360, maxWidth: 420),
            child: SingleChildScrollView(child: ChangelogView(r.changelog)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
              child: const Text('Chiudi'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Aggiorna ora'),
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(updateProvider.notifier).downloadAndInstall(r);
                _showDownloadDialog(context, ref);
              },
            ),
          ],
        );
      },
    );
  }

  void _showDownloadDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final state = ref.watch(updateProvider);
          if (state is! UpdateDownloading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(ctx)) Navigator.pop(ctx);
            });
          }
          final progress =
              state is UpdateDownloading ? state.progress : 0.0;
          return AlertDialog(
            title: const Text('Download in corso'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Intestazione condivisa da banner e dialog: occhiello "Nuova versione"
/// (+ BETA), nome e versione, data di pubblicazione.
class _ReleaseHeading extends StatelessWidget {
  final ReleaseInfo release;

  const _ReleaseHeading({required this.release});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandEyebrow(
          'Nuova versione',
          trailing: release.prerelease ? const BrandBetaBadge() : null,
        ),
        const SizedBox(height: NotetonBrand.space1),
        Text(
          'Noteton ${release.version}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Pubblicata il ${release.formattedDate}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Simbolo del banner: nota musicale con una piccola freccia d'accento
/// ("la nota che sale" = nuova versione).
class _RisingNoteMark extends StatelessWidget {
  const _RisingNoteMark();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = NotetonBrand.accent(cs);
    return ExcludeSemantics(
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(NotetonBrand.radiusMd),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // La nota poggia su un frammento di pentagramma.
                  StaffLines(
                    gap: 6,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.22),
                  ),
                  Icon(
                    Icons.music_note_rounded,
                    size: 24,
                    color: cs.onPrimaryContainer,
                  ),
                ],
              ),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: _cardColor(cs), width: 2),
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 12,
                  color: cs.brightness == Brightness.dark
                      ? cs.onSecondary
                      : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _cardColor(ColorScheme cs) => cs.brightness == Brightness.dark
    ? cs.surfaceContainerHigh
    : cs.surfaceContainerLow;

class _BannerCard extends StatelessWidget {
  final ReleaseInfo release;
  final VoidCallback onDismiss;
  final VoidCallback onUpdate;
  final VoidCallback onReadMore;

  /// Voci del changelog mostrate in anteprima.
  static const _maxHighlights = 2;

  /// Rientro del contenuto: allineato al testo dell'intestazione.
  static const _contentIndent = 44.0 + NotetonBrand.space4;

  const _BannerCard({
    required this.release,
    required this.onDismiss,
    required this.onUpdate,
    required this.onReadMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = NotetonBrand.accent(cs);
    final highlights = ChangelogParser.highlights(release.changelog);
    final shown = highlights.take(_maxHighlights).toList();
    final hidden = highlights.length - shown.length;

    return Card(
      color: _cardColor(cs),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NotetonBrand.radiusLg),
        side: cs.brightness == Brightness.light
            ? BorderSide(color: cs.outlineVariant)
            : BorderSide.none,
      ),
      child: Stack(
        children: [
          // Stanghetta d'accento sul bordo sinistro.
          Positioned(
            left: 0,
            top: NotetonBrand.space4,
            bottom: NotetonBrand.space4,
            width: NotetonBrand.barlineWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(NotetonBrand.barlineWidth),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NotetonBrand.space5,
              NotetonBrand.space4,
              NotetonBrand.space2,
              NotetonBrand.space3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _RisingNoteMark(),
                    const SizedBox(width: NotetonBrand.space4),
                    Expanded(child: _ReleaseHeading(release: release)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: cs.onSurfaceVariant,
                      tooltip: 'Più tardi',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDismiss,
                    ),
                  ],
                ),
                if (shown.isNotEmpty) ...[
                  const SizedBox(height: NotetonBrand.space3),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: _contentIndent,
                      right: NotetonBrand.space3,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final h in shown) ...[
                          NoteBulletItem(
                            h,
                            maxLines: 1,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: NotetonBrand.space1),
                        ],
                        if (hidden > 0)
                          Text(
                            hidden == 1
                                ? '+1 altra novità'
                                : '+$hidden altre novità',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: NotetonBrand.space2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onReadMore,
                      style: TextButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                      ),
                      child: const Text('Leggi tutto'),
                    ),
                    const SizedBox(width: NotetonBrand.space2),
                    FilledButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Aggiorna'),
                      onPressed: onUpdate,
                    ),
                    const SizedBox(width: NotetonBrand.space2),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
