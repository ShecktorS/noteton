class AppConstants {
  AppConstants._();

  static const String appName = 'Noteton';
  static const String appVersion = '0.1.0';
  static const int databaseVersion = 1;

  // Route names
  static const String routeLibrary = '/';
  static const String routeViewer = '/viewer';
  static const String routeSetlists = '/setlists';
  static const String routePerformance = '/performance';
  static const String routeSettings = '/settings';
  static const String routeSongDetail = '/song';

  // Default tag colors
  static const List<String> defaultTagColors = [
    '#F44336', // red
    '#E91E63', // pink
    '#9C27B0', // purple
    '#3F51B5', // indigo
    '#2196F3', // blue
    '#009688', // teal
    '#4CAF50', // green
    '#FF9800', // orange
    '#607D8B', // blue-grey
  ];
}
