---
name: new-feature
description: Scaffolding di una nuova feature Noteton seguendo la clean architecture (model -> repository -> provider Riverpod -> screen). Usare quando si aggiunge una feature che tocca dati, stato e UI.
disable-model-invocation: true
---

# Nuova feature Noteton

Costruisci una feature rispettando la clean architecture a 4 livelli del progetto,
**in quest'ordine** (vedi `CLAUDE.md`). Considera l'uso del subagent `feature-builder`
per l'implementazione effettiva.

## Argomenti

L'utente descrive la feature: `/new-feature gestione preferiti per gli spartiti`.

## Ordine di costruzione (non saltare livelli)

### 1. `lib/domain/models/<nome>.dart`
Classe immutabile con:
- `fromMap(Map)` / `toMap()` per la persistenza SQLite.
- `copyWith(...)`; per i campi nullable usa il flag `clearX` (pattern in `song.dart`).
- Eventuali enum con `dbValue`.

### 2. `lib/data/repositories/<nome>_repository.dart`
- Unico punto d'accesso al DB via `DatabaseHelper`.
- Operazioni multiple **in transazione** (pattern in `tag_repository.dart` -> `setTagsForSong`).
- Se serve una nuova tabella o colonna: **NON** modificare lo schema a mano —
  usa il subagent `db-migration-guard` (incrementa `_databaseVersion`, blocco idempotente
  in `_onUpgrade`, schema replicato in `_onCreate`).

### 3. `lib/providers/providers.dart`
- Aggiungi qui TUTTI i provider (`FutureProvider` / `StateNotifierProvider`).
- Dopo ogni scrittura, **invalida** i provider dipendenti per aggiornare la UI.

### 4. `lib/presentation/<area>/`
- `ConsumerWidget` / `ConsumerStatefulWidget`.
- Usa il theme (`lib/core/theme/app_theme.dart`), **niente colori hardcoded**.
- Gestisci sempre `loading` ed `error` nei `.when(...)`.
- Registra la rotta in `go_router` se la feature ha una schermata propria.

### 5. Test
- Unit test per model e repository con `sqflite_common_ffi` (DB in-memory).
- Pattern di riferimento: `test/repositories/annotation_repository_test.dart` + `test/helpers/`.

## Chiusura
Termina con `flutter analyze` e `flutter test` verdi. Stringhe UI in italiano.
