# Noteton

Un'app mobile moderna e open source per la gestione e visualizzazione di spartiti musicali.
Alternativa cross-platform a MobileSheets — costruita con Flutter.

---

## Funzionalità implementate

### Libreria
- Import PDF con dialog guidato (titolo, autore, assegna a setlist o raccolta)
- Visualizzazione a griglia (thumbnail) e lista, con preferenza persistente
- Badge stato brano: Da imparare / In studio / Pronto / In repertorio
- Filtro per stato, ordinamento per titolo / autore / data aggiunta
- Selezione multipla con long-press → eliminazione massiva
- Indicatore di progresso lettura (ultima pagina / totale)

### Viewer PDF
- Navigazione pagine con tap bordo sinistro/destro
- AppBar che scompare al tap centrale
- Salvataggio automatico ultima pagina letta
- Modalità Leggio: schermo pieno, sfondo bianco, immersiveSticky

### Setlist
- CRUD completo (crea, rinomina, elimina con data concerto opzionale)
- Riordino brani via drag-and-drop
- Selezione multipla → rimozione massiva
- Avvio performance da qualsiasi brano della lista

### Raccolte (Collections)
- Organizzazione brani in cartelle colorate
- Vista griglia con card colorate e contatore brani
- Assegnazione a raccolta durante l'import o dal menu brano

### Modalità Performance
- Viewer fullscreen immersive
- Navigazione tra i brani della setlist
- Feedback aptico al cambio pagina
- Partenza da un brano specifico della setlist

---

## Stack tecnico

| Componente | Tecnologia |
|---|---|
| Framework | Flutter + Dart |
| State management | Riverpod ^2.5.1 |
| Navigazione | GoRouter ^14.2.0 |
| Database locale | SQLite via sqflite |
| Rendering PDF | pdfx ^2.6.0 |
| File picking | file_picker ^8.1.2 |
| Preferenze UI | shared_preferences ^2.3.2 |
| Bluetooth (future) | flutter_blue_plus ^1.32.12 |

---

## Setup

Prerequisiti: Flutter SDK installato (https://flutter.dev/docs/get-started/install)

```bash
flutter pub get       # Installa le dipendenze
flutter analyze       # Analisi statica
flutter run           # Avvia su emulatore o dispositivo connesso
flutter build apk     # Build APK Android
```

---

## Struttura del progetto

```
lib/
├── main.dart
├── app.dart                          # MaterialApp + GoRouter + ProviderScope
├── core/
│   ├── constants/app_constants.dart
│   ├── router/app_router.dart
│   └── theme/app_theme.dart          # Dark theme: Midnight Ink + Gold Leaf
├── domain/models/
│   ├── song.dart                     # Song + SongStatus enum
│   ├── setlist.dart / setlist_item.dart
│   └── collection.dart
├── data/
│   ├── database/database_helper.dart # SQLite singleton, versione 3
│   └── repositories/
│       ├── song_repository.dart
│       ├── setlist_repository.dart
│       └── collection_repository.dart
├── providers/providers.dart
└── presentation/
    ├── common/
    │   ├── app_bottom_nav.dart
    │   └── pdf_thumbnail.dart
    ├── library/library_screen.dart
    ├── viewer/pdf_viewer_page.dart
    ├── performance/performance_screen.dart
    ├── setlist/setlist_screen.dart + setlist_detail_screen.dart
    ├── collections/collections_screen.dart + collection_detail_screen.dart
    └── settings/settings_screen.dart
```

---

## Database

SQLite con PRAGMA foreign_keys = ON. Versione corrente: 3.

Migrazioni: 1 -> 2 (collections) -> 3 (colonna status su songs).

Tabelle: songs, setlists, setlist_items, collections, song_collections.

---

## Roadmap

| Fase | Obiettivo | Stato |
|---|---|---|
| 1 | MVP — Libreria + Viewer PDF | Completata |
| 2 | Setlist + Modalità performance | Completata |
| 2.5 | Raccolte + redesign UI + sistema stato | Completata |
| 3 | Bluetooth page-turner | Prossima |
| 4 | Annotazioni, ricerca full-text, metadata avanzati | Pianificata |
| 5 | Pubblicazione store + sync cloud | Pianificata |

---

## Licenza

MIT — Open Source
