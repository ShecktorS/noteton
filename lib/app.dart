import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/whats_new_service.dart';
import 'core/theme/app_theme.dart';
import 'domain/models/release_info.dart';
import 'providers/providers.dart';

class NotetonApp extends ConsumerWidget {
  const NotetonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorVariant = ref.watch(colorVariantProvider);

    return MaterialApp.router(
      title: 'Noteton',
      theme: AppTheme.light(colorVariant),
      darkTheme: AppTheme.dark(colorVariant),
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          _UpdateGate(child: child ?? const SizedBox()),
    );
  }
}

/// Mostra un dialog con changelog quando viene rilevato un aggiornamento.
/// "Più tardi" chiude il dialog senza persistere — verrà riproposto al
/// prossimo avvio. La X in Settings invece nasconde la versione per sempre.
class _UpdateGate extends ConsumerStatefulWidget {
  final Widget child;
  const _UpdateGate({required this.child});

  @override
  ConsumerState<_UpdateGate> createState() => _UpdateGateState();
}

class _BetaBadge extends StatelessWidget {
  final Color foreground;
  final Color background;

  const _BetaBadge({
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          'BETA',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
        ),
      ),
    );
  }
}

class _UpdateGateState extends ConsumerState<_UpdateGate>
    with WidgetsBindingObserver {
  bool _dialogShownThisSession = false;
  bool _startupFlowRunning = false;
  bool _updateCheckStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupFlow());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupFlow());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateState>(updateProvider, (prev, next) {
      if (next is UpdateAvailable && !_dialogShownThisSession) {
        _dialogShownThisSession = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showUpdateDialog(next.release);
        });
      }
    });
    return widget.child;
  }

  Future<void> _runStartupFlow() async {
    if (_startupFlowRunning || !mounted) return;
    _startupFlowRunning = true;

    try {
      const whatsNewService = WhatsNewService();
      final whatsNew = await whatsNewService.getPendingWhatsNew();
      if (!mounted) return;

      if (whatsNew != null) {
        // Lascia completare il primo layout: su alcuni device Android il
        // rientro dall'installer avviene mentre la route iniziale si sta ancora
        // stabilizzando e un dialog immediato può non essere percepibile.
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        await _showWhatsNewDialog(whatsNew);
        await whatsNewService.markSeen(whatsNew.version);
      }

      if (!mounted || _updateCheckStarted) return;
      _updateCheckStarted = true;
      // Bypass throttle al lancio: vogliamo info fresche per il dialog.
      // Rispetta il toggle "Abilita aggiornamento" (off → niente check).
      final enabled = await UpdateNotifier.isAutoUpdateEnabled();
      if (!enabled || !mounted) return;
      ref.read(updateProvider.notifier).check(force: true);
    } finally {
      _startupFlowRunning = false;
    }
  }

  Future<void> _showWhatsNewDialog(WhatsNewInfo info) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Novità in Noteton v${info.version}'),
                  if (info.isPrerelease)
                    _BetaBadge(
                      foreground: Theme.of(ctx).colorScheme.onTertiaryContainer,
                      background: Theme.of(ctx).colorScheme.tertiaryContainer,
                    ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360, maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (info.publishedAt != null) ...[
                Text(
                  'Pubblicato il ${info.release!.formattedDate}',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 12),
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    info.changelog,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ho capito'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdateDialog(ReleaseInfo release) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Aggiornamento v${release.version}'),
                  if (release.prerelease)
                    _BetaBadge(
                      foreground: Theme.of(ctx).colorScheme.onTertiaryContainer,
                      background: Theme.of(ctx).colorScheme.tertiaryContainer,
                    ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360, maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pubblicato il ${release.formattedDate}',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    release.changelog.trim().isEmpty
                        ? 'Nessuna nota di rilascio fornita.'
                        : release.changelog.trim(),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Più tardi'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Aggiorna ora'),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(updateProvider.notifier).downloadAndInstall(release);
              _showDownloadDialog();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDownloadDialog() async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final state = ref.watch(updateProvider);
          // Auto-chiusura quando il download è finito (l'installer parte da solo)
          // o in caso di errore.
          if (state is! UpdateDownloading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(ctx)) Navigator.pop(ctx);
            });
          }
          final progress = state is UpdateDownloading ? state.progress : 0.0;
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
