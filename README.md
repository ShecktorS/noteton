# Noteton

Noteton è un'app Flutter per gestire e visualizzare spartiti musicali PDF.
Nasce come alternativa cross-platform a MobileSheets, con focus su libreria locale, setlist, annotazioni e modalità performance.

- Target di rilascio: **Android/iOS**
- Target Linux: supportato per sviluppo locale tramite `sqflite_common_ffi`
- Versione app attuale: **0.12.0-beta.2+27**
- Database SQLite: **schema v7**

---

## Funzionalità

### Libreria e metadati

- Import PDF con dialog guidato.
- Copia dei PDF nella libreria dell'app e salvataggio dei percorsi in formato relativo.
- Deduplicazione tramite hash SHA-256 del file PDF.
- Vista griglia/lista con preferenza persistente.
- Ricerca e filtri per testo, stato e tag.
- Ordinamenti per titolo, data, ultimo utilizzo e varianti A/Z.
- Selezione multipla con azioni massive.
- Stato brano: Da imparare, In studio, Pronto, In repertorio.
- Metadati musicali: compositore, album, periodo/genere, tonalità, BPM, strumento.
- Autocomplete per compositori e album.
- Scroll rapido alfabetico e indicatore progresso lettura.

### Viewer PDF

- Rendering PDF con `pdfx`.
- Navigazione tramite tap sui bordi e swipe.
- AppBar auto-hide.
- Salvataggio automatico dell'ultima pagina letta.
- Modalità leggio fullscreen/immersive.

### Annotazioni

- Disegno a mano libera sopra il PDF con `perfect_freehand`.
- Penna, evidenziatore, gomma e undo.
- Supporto coordinate normalizzate 0–1 per adattarsi al layout.
- Persistenza in SQLite per brano e pagina.

### Setlist e performance

- CRUD completo delle setlist.
- Data concerto e descrizione opzionali.
- Riordino brani drag-and-drop.
- Pagina iniziale personalizzata per ogni brano in setlist.
- Avvio performance da qualsiasi brano.
- Modalità performance fullscreen con navigazione tra brani e feedback aptico.
- Metronomo integrato con BPM, time signature, pendolo animato e preset audio.

### Raccolte, compositori e tag

- Raccolte colorate per organizzare i brani.
- Vista dettaglio raccolta con gestione dei brani associati.
- Scheda compositore con anni, conteggio e lista brani.
- Tag CRUD con colori e assegnazione transazionale ai brani.
- Conteggi tag e filtro diretto in libreria.

### Import, backup e diagnostica

- Import da backup MobileSheets `.msb`.
- Conversione di brani, autori, setlist, raccolte, tonalità, periodo/genere e BPM quando disponibili.
- Backup Noteton `.ntb` in formato ZIP v3 con validazione CRC32.
- Ripristino backup in modalità unione o sostituzione completa.
- Checkpoint automatico prima delle migrazioni database.
- Schermata diagnostica nascosta accessibile con 7 tap sulla versione.
- Health check libreria, gestione checkpoint e strumenti di manutenzione.

### Aggiornamenti e personalizzazione

- Controllo aggiornamenti da GitHub Releases.
- Canale aggiornamenti stabile/beta.
- Download APK con progresso e installazione tramite platform channel Android.
- Banner aggiornamento in home.
- Modale “Novità della versione” post aggiornamento.
- Tema Material 3 chiaro/scuro/sistema.
- Varianti colore: Midnight Ink e Amethyst.

### Non ancora implementato

- Bluetooth page-turner: la voce impostazioni esiste, ma la scansione/pairing e la mappatura eventi sono ancora da implementare.

---

## Stack tecnico

| Componente | Tecnologia |
|---|---|
| Framework | Flutter + Dart |
| State management | Riverpod |
| Navigazione | go_router |
| Database locale | SQLite con sqflite |
| Sviluppo desktop | sqflite_common_ffi |
| Rendering PDF | pdfx |
| File picking/storage | file_picker, path_provider |
| Annotazioni | perfect_freehand |
| Audio metronomo | audioplayers |
| Backup ZIP | archive |
| Hash/dedup PDF | crypto |
| Aggiornamenti | http, package_info_plus, MethodChannel Android |
| Condivisione backup | share_plus |

---

## Setup sviluppo

Prerequisiti:

- Flutter SDK installato
- Android SDK per build/run Android
- Xcode/macOS per build iOS

Comandi principali:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk
```

Per eseguire su Linux desktop in sviluppo, se la cartella `linux/` non è presente:

```bash
flutter create --platforms=linux .
flutter run -d linux
```

> Il target Linux è utile per sviluppo e debug, ma non è il target di rilascio principale.

---

## Architettura

Il progetto segue una clean architecture a 4 livelli:

```text
lib/domain/models  →  lib/data/repositories  →  lib/providers  →  lib/presentation
```

Struttura principale:

```text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── router/
│   ├── services/
│   ├── theme/
│   └── utils/
├── domain/models/
├── data/
│   ├── converters/
│   ├── database/
│   └── repositories/
├── providers/
└── presentation/
    ├── collections/
    ├── common/
    ├── composer/
    ├── library/
    ├── performance/
    ├── setlist/
    ├── settings/
    └── viewer/
```

Regole pratiche:

- I modelli sono immutabili e vivono in `domain/models`.
- I repository sono l'unico punto di accesso al database.
- Tutti i provider Riverpod sono centralizzati in `lib/providers/providers.dart`.
- La UI vive in `presentation` e usa il tema centralizzato.

---

## Database

SQLite con `PRAGMA foreign_keys = ON`.

Versione corrente: **7**.

Tabelle principali:

- `composers`
- `songs`
- `tags`
- `song_tags`
- `setlists`
- `setlist_items`
- `annotations`
- `collections`
- `song_collections`

Migrazioni:

| Versione | Cambiamento |
|---|---|
| 2 | Raccolte: `collections`, `song_collections` |
| 3 | Stato brano su `songs.status` |
| 4 | Metadati musicali: tonalità, BPM, strumento |
| 5 | Hash file PDF: `songs.file_hash` |
| 6 | Tag e annotazioni |
| 7 | Album e periodo/genere |

Prima di una migrazione su database esistente viene creato un checkpoint best-effort.

---

## Test

La suite usa `flutter_test` e database SQLite in-memory tramite `sqflite_common_ffi`.

Aree coperte:

- modelli principali
- repository annotation, collection, composer, setlist, song e tag
- servizi release/novità versione
- widget smoke test

Esecuzione:

```bash
flutter test
flutter test test/repositories/song_repository_test.dart
flutter test --plain-name "Song.copyWith"
```

---

## Release Android

Il flusso consigliato è tramite GitHub Actions.

Un push di tag `v*` avvia `.github/workflows/release.yml`, builda l'APK release firmato e pubblica una GitHub Release con asset:

```text
Noteton-<versione>.apk
```

Esempio:

```bash
# aggiornare versionName + versionCode in pubspec.yaml
flutter analyze && flutter test
git commit -am "release: v0.12.0"
git tag v0.12.0
git push origin master --tags
```

Le pre-release vengono rilevate automaticamente se la versione contiene `beta`, `alpha` o `rc`.

---

## Roadmap

| Priorità | Obiettivo |
|---|---|
| P1 | Bluetooth page-turner |
| P2 | Refactor progressivo di `library_screen.dart` |
| P2 | Aumentare la copertura test su backup, import MobileSheets e servizi |
| P3 | Ricerca full-text FTS5 |
| P3 | Sync cloud |
| P3 | Pubblicazione store e build iOS complete |

---

## Licenza

Open Source. Licenza da formalizzare nel repository.
