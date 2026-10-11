import 'package:flutter/material.dart';

import '../../../core/theme/brand.dart';
import 'brand_motifs.dart';

/// Stato vuoto del brand: simbolo di sezione appoggiato su un pentagramma
/// sfumato ai lati, titolo, suggerimento e azione opzionale.
class BrandEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const BrandEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: NotetonBrand.space6 + NotetonBrand.space2,
          vertical: NotetonBrand.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (r) => const LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0, 0.3, 0.7, 1],
                    ).createShader(r),
                    child: StaffLines(
                      gap: 9,
                      color: cs.onSurface.withValues(alpha: 0.16),
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(NotetonBrand.radiusLg),
                    ),
                    child: Icon(icon, size: 32, color: cs.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NotetonBrand.space5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: NotetonBrand.space2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: NotetonBrand.space4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
