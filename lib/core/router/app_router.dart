import 'package:go_router/go_router.dart';
import '../../presentation/library/library_screen.dart';
import '../../presentation/viewer/pdf_viewer_page.dart';
import '../../presentation/setlist/setlist_screen.dart';
import '../../presentation/setlist/setlist_detail_screen.dart';
import '../../presentation/performance/performance_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/collections/collections_screen.dart';
import '../../presentation/collections/collection_detail_screen.dart';
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
        final songId = int.tryParse(state.pathParameters['songId'] ?? '') ?? 0;
        return PdfViewerPage(songId: songId);
      },
    ),
    GoRoute(
      path: AppConstants.routeSetlists,
      builder: (context, state) => const SetlistScreen(),
      routes: [
        GoRoute(
          path: ':setlistId',
          builder: (context, state) {
            final setlistId = int.tryParse(state.pathParameters['setlistId'] ?? '') ?? 0;
            return SetlistDetailScreen(setlistId: setlistId);
          },
        ),
      ],
    ),
    GoRoute(
      path: '${AppConstants.routePerformance}/:setlistId',
      builder: (context, state) {
        final setlistId = int.tryParse(state.pathParameters['setlistId'] ?? '') ?? 0;
        final songIndex = int.tryParse(state.uri.queryParameters['songIndex'] ?? '') ?? 0;
        return PerformanceScreen(setlistId: setlistId, initialSongIndex: songIndex);
      },
    ),
    GoRoute(
      path: AppConstants.routeCollections,
      builder: (context, state) => const CollectionsScreen(),
      routes: [
        GoRoute(
          path: ':collectionId',
          builder: (context, state) {
            final collectionId = int.tryParse(state.pathParameters['collectionId'] ?? '') ?? 0;
            return CollectionDetailScreen(collectionId: collectionId);
          },
        ),
      ],
    ),
    GoRoute(
      path: AppConstants.routeSettings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
