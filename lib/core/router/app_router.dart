import 'package:go_router/go_router.dart';
import '../../presentation/library/library_screen.dart';
import '../../presentation/viewer/pdf_viewer_page.dart';
import '../../presentation/setlist/setlist_screen.dart';
import '../../presentation/performance/performance_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../core/constants/app_constants.dart';

final appRouter = GoRouter(
  initialLocation: AppConstants.routeLibrary,
  routes: [
    GoRoute(
      path: AppConstants.routeLibrary,
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '${AppConstants.routeViewer}/:songId',
      builder: (context, state) {
        final songId = int.parse(state.pathParameters['songId']!);
        return PdfViewerPage(songId: songId);
      },
    ),
    GoRoute(
      path: AppConstants.routeSetlists,
      builder: (context, state) => const SetlistScreen(),
    ),
    GoRoute(
      path: '${AppConstants.routePerformance}/:setlistId',
      builder: (context, state) {
        final setlistId = int.parse(state.pathParameters['setlistId']!);
        return PerformanceScreen(setlistId: setlistId);
      },
    ),
    GoRoute(
      path: AppConstants.routeSettings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
