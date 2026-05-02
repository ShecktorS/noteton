class AppConstants {
  AppConstants._();

  static const String appName = 'Noteton';
  static const String appVersion = '0.10.1';
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

  // Palette tag — sfumature pastello soft, leggibili sia in dark che in light.
  // Sostituisce la vecchia palette Material satura.
  static const List<String> defaultTagColors = [
    '#E57373', // rosso pastello
    '#F4A261', // arancio caldo
    '#F4D35E', // giallo soft
    '#A8D5A2', // verde salvia
    '#7DCEA0', // menta
    '#7FB3D5', // azzurro polvere
    '#9FA8DA', // lavanda
    '#C39BD3', // lilla
    '#F1948A', // rosa antico
    '#B0BEC5', // grigio bluastro
    '#FFAB91', // pesca
    '#80CBC4', // acqua
  ];
}
