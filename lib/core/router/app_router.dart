import 'package:flutter/material.dart';
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

// Fade istantaneo per le route tab (no slide)
Page<void> _fadePage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );

final appRouter = GoRouter(
  initialLocation: AppConstants.routeLibrary,
  routes: [
    GoRoute(
      path: AppConstants.routeLibrary,
      pageBuilder: (context, state) => _fadePage(state, const LibraryScreen()),
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
      pageBuilder: (context, state) => _fadePage(state, const SetlistScreen()),
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
      pageBuilder: (context, state) => _fadePage(state, const CollectionsScreen()),
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
      pageBuilder: (context, state) => _fadePage(state, const SettingsScreen()),
    ),
  ],
);
