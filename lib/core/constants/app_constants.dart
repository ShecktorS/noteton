class AppConstants {
  AppConstants._();

  static const String appName = 'Noteton';
  static const String appVersion = '0.7.0';
  static const int databaseVersion = 7;

  // Periodi storici/generi musicali per organizzazione brani
  static const List<String> musicalPeriods = [
    'Medievale',
    'Rinascimento',
    'Barocco',
    'Classico',
    'Romantico',
    'Moderno',
    'Contemporaneo',
    'Jazz',
    'Pop/Rock',
    'Folk',
    'Colonna sonora',
  ];

  // GitHub Releases
  static const String githubOwner = 'ShecktorS';
  static const String githubRepo = 'noteton';
  static const String githubApiLatestRelease =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  // Route names
  static const String routeLibrary = '/';
  static const String routeViewer = '/viewer';
  static const String routeSetlists = '/setlists';
  static const String routePerformance = '/performance';
  static const String routeCollections = '/collections';
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
