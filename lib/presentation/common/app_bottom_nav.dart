import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Libreria'),
    BottomNavigationBarItem(icon: Icon(Icons.queue_music), label: 'Setlist'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Impostazioni'),
  ];

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppConstants.routeLibrary);
      case 1:
        context.go(AppConstants.routeSetlists);
      case 2:
        context.go(AppConstants.routeSettings);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) => _onTap(context, i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.library_music), label: 'Libreria'),
        NavigationDestination(icon: Icon(Icons.queue_music), label: 'Setlist'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Impostazioni'),
      ],
    );
  }
}
