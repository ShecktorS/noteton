# Noteton

Un'app mobile moderna e open source per la gestione e visualizzazione di spartiti musicali.
Alternativa cross-platform a MobileSheets — costruita con Flutter.

## Stack

| Componente | Tecnologia |
|---|---|
| Framework | Flutter + Dart |
| Database locale | SQLite (sqflite) |
| Rendering PDF | pdfx |
| State management | Riverpod |
| Navigazione | GoRouter |
| Bluetooth | flutter_blue_plus |
| File picking | file_picker |

## Setup iniziale

> Prerequisiti: Flutter SDK installato ([flutter.dev](https://flutter.dev/docs/get-started/install))

```powershell
# 1. Installa le dipendenze
flutter pub get

# 2. Verifica il codice
flutter analyze

# 3. Lancia l'app su emulatore o dispositivo connesso
flutter run
```

## Struttura del progetto

```
lib/
  main.dart                     # Entry point
  app.dart                      # MaterialApp + tema + routing
  core/
    constants/app_constants.dart
    theme/app_theme.dart
    router/app_router.dart
  data/
    database/database_helper.dart   # Schema SQLite (7 tabelle)
    repositories/
      song_repository.dart
      setlist_repository.dart
      composer_repository.dart
  domain/
    models/
      song.dart | composer.dart | tag.dart
      setlist.dart | setlist_item.dart | annotation.dart
  presentation/
    library/library_screen.dart
    viewer/pdf_viewer_page.dart
    setlist/setlist_screen.dart
    performance/performance_screen.dart
    settings/settings_screen.dart
    common/app_bottom_nav.dart
  providers/providers.dart
```

## Fasi di sviluppo

| Fase | Obiettivo | Stato |
|---|---|---|
| 0 | Setup e apprendimento Flutter | Scaffold pronto |
| 1 | MVP — Libreria + Viewer PDF | In attesa |
| 2 | Setlist + Modalità performance | In attesa |
| 3 | Bluetooth page turning | In attesa |
| 4 | Annotazioni + rifinitura UI | In attesa |
| 5 | Pubblicazione store + sync cloud | In attesa |

## Database SQLite

Schema con 7 tabelle:
- `songs` — spartiti con metadati
- `composers` — compositori
- `tags` — etichette colorate
- `song_tags` — relazione N:N canzoni/tag
- `setlists` — scalette
- `setlist_items` — brani in una setlist (con posizione e pagina iniziale)
- `annotations` — annotazioni SVG per pagina

## Licenza

MIT / GPL — Open Source
