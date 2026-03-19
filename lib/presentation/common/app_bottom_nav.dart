import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppConstants.routeLibrary);
      case 1:
        context.go(AppConstants.routeSetlists);
      case 2:
        context.go(AppConstants.routeCollections);
      case 3:
        context.go(AppConstants.routeSettings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) => _onTap(context, i),
      animationDuration: const Duration(milliseconds: 300),
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.library_music_outlined,
              color: cs.onSurfaceVariant),
          selectedIcon: Icon(Icons.library_music, color: cs.onPrimaryContainer),
          label: 'Libreria',
        ),
        NavigationDestination(
          icon: Icon(Icons.queue_music_outlined,
              color: cs.onSurfaceVariant),
          selectedIcon: Icon(Icons.queue_music, color: cs.onPrimaryContainer),
          label: 'Setlist',
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_special_outlined,
              color: cs.onSurfaceVariant),
          selectedIcon: Icon(Icons.folder_special, color: cs.onPrimaryContainer),
          label: 'Raccolte',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined,
              color: cs.onSurfaceVariant),
          selectedIcon: Icon(Icons.settings, color: cs.onPrimaryContainer),
          label: 'Impostazioni',
        ),
      ],
    );
  }
}
