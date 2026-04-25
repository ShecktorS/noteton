import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'domain/models/release_info.dart';
import 'providers/providers.dart';

class NotetonApp extends ConsumerWidget {
  const NotetonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Noteton',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => _UpdateGate(child: child ?? const SizedBox()),
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

class _UpdateGateState extends ConsumerState<_UpdateGate> {
  bool _dialogShownThisSession = false;

  @override
  void initState() {
    super.initState();
    // Bypass throttle al lancio: vogliamo info fresche per il dialog.
    // Rispetta il toggle "Abilita aggiornamento" (off → niente check).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final enabled = await UpdateNotifier.isAutoUpdateEnabled();
      if (!enabled || !mounted) return;
      ref.read(updateProvider.notifier).check(force: true);
    });
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
            Expanded(child: Text('Aggiornamento v${release.version}')),
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
