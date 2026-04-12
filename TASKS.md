# Noteton — Task List

## Alta priorità

- [x] **Backup annotations** — `BackupRepository` ora include la tabella `annotations` nell'export/import. Versione backup: 2.
- [x] **Ricerca globale** — `_SongSearchDelegate` con risultati live (titolo / compositore / tonalità), toccando il brano si apre direttamente il viewer.
- [x] **Metronomo integrato** — barra con play/stop, ±5 BPM, tap-tempo, indicatore visivo pulsante. BPM caricato dal brano. Presente in viewer e performance mode.
- [x] **Tag personalizzati (UI)** — creazione (con palette colori) e gestione in Impostazioni → Tag; assegnazione ai brani dal menu opzioni; filtro in libreria (icona filtro, sezione Tag).

## Media priorità

- [x] **Performance mode: swipe per cambiare brano** — swipe orizzontale sulla barra dot in basso cambia brano. Haptic feedback differenziato.
- [x] **Drag & drop nella setlist** — già implementato con `ReorderableListView` + handle. Confermato funzionante.
- [x] **Import batch** — selezione multipla di PDF con un unico gesto, importati in sequenza.
- [x] **Schermata compositore più ricca** — header con avatar, anni di vita, contatore brani. Tasto edit per modificare nome + anni.

## Bassa priorità / Futuro

- [ ] **Bluetooth page turner** — `flutter_blue_plus` già in pubspec. Da implementare quando disponibile hardware.
- [ ] **Statistiche** — schermata con numero brani, distribuzione per tonalità, brani per stato (daStudiare/pronto…).
- [ ] **Widget dark/light** — il `ThemeModeNotifier` c'è, renderlo più visibile nelle impostazioni.

## Completato

- [x] Import PDF + thumbnail
- [x] Viewer PDF con navigazione pagine
- [x] Annotazioni S Pen (pen / highlighter / eraser, persistenza SQLite)
- [x] Compositore: schermata dettaglio + filtro libreria
- [x] Setlist + Performance mode (con annotazioni read-only)
- [x] Collections (cartelle)
- [x] Key signature + status brano
- [x] Backup `.ntb` (ZIP con JSON + PDF)
- [x] Ordinamento libreria (A-Z, Z-A, recenti, ultima apertura)
- [x] Suite TDD base (modelli + repository)
- [x] Bug fix: totalPages aggiornato subito dopo import
