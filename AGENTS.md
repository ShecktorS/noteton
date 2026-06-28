# AGENTS.md

Istruzioni per gli agenti AI che lavorano in questo repository.

## Cos'è

Noteton è un'app Flutter (Dart) per la gestione e visualizzazione di spartiti musicali PDF, alternativa cross-platform a MobileSheets. Target di rilascio: **Android/iOS**. Le stringhe UI sono in italiano.

## Comandi utili

```bash
flutter pub get                 # installa le dipendenze
flutter analyze                 # analisi statica (lint: package:flutter_lints)
flutter test                    # esegue tutta la suite di test
flutter test test/models/song_test.dart            # un singolo file di test
flutter test --plain-name "Song.copyWith"          # un singolo test per nome
flutter run                     # avvia su emulatore/dispositivo Android
flutter build apk               # build di rilascio Android
```

Sviluppo desktop: l'app gira su Linux desktop grazie a `sqflite_common_ffi`. Il target `/linux/` non è versionato perché è in `.gitignore`; rigeneralo con:

```bash
flutter create --platforms=linux .
flutter run -d linux
```

Chiudere sempre un task con `flutter analyze` e `flutter test` verdi.

## Architettura

Clean architecture a 4 livelli. Quando aggiungi una feature, costruisci **in quest'ordine**:

```text
domain/models  →  data/repositories  →  providers (Riverpod)  →  presentation (screens)
```

- **`lib/domain/models/`**: classi immutabili con `fromMap`/`toMap` e `copyWith`. I campi nullable usano flag `clearX` in `copyWith` (vedi `song.dart`). Gli enum espongono `dbValue`.
- **`lib/data/repositories/`**: unico punto di accesso al DB tramite `DatabaseHelper`. Operazioni multiple in transazione (pattern in `tag_repository.dart` → `setTagsForSong`).
- **`lib/providers/providers.dart`**: TUTTI i provider Riverpod stanno qui (`FutureProvider` / `StateNotifierProvider`). Dopo una scrittura, **invalida** i provider dipendenti per aggiornare la UI.
- **`lib/presentation/<area>/`**: `ConsumerWidget`/`ConsumerStatefulWidget`. Usa il theme (`lib/core/theme/app_theme.dart`), niente colori hardcoded. Gestisci sempre `loading`/`error` nei `.when(...)`.

`lib/core/` contiene router (`go_router`), theme, costanti, utility (`song_path.dart`, `key_signature_localization.dart`) e service (metronome, update, checkpoint, library_health, schema_validator).

## Database SQLite

Tutto in `lib/data/database/database_helper.dart`. **Schema versione 7.** Tabelle: `composers`, `songs`, `tags`, `song_tags`, `setlists`, `setlist_items`, `annotations`, `collections`, `song_collections` con `PRAGMA foreign_keys = ON`.

Modificare lo schema è delicato. Non toccare solo `_onCreate`:

1. Incrementa `_databaseVersion`.
2. Aggiungi un blocco in `_onUpgrade` (`oldVersion < N`) che applica **solo** il delta, idempotente.
3. Replica lo stesso schema in `_onCreate`: clean-install e post-upgrade devono coincidere.
4. Il checkpoint pre-migrazione automatico (righe ~44-82) deve coprire il nuovo target.

## Rilascio Android

Il flusso consigliato è via CI: il push di un tag `v*` avvia `.github/workflows/release.yml`, builda l'APK **firmato di release** e pubblica una GitHub Release con asset `Noteton-<versione>.apk`.

```bash
# 1. bump versione in pubspec.yaml: versionName + versionCode (il +N DEVE crescere)
# 2. flutter analyze && flutter test  → verdi
git commit -am "release: v0.10.2"
git tag v0.10.2          # il tag DEVE essere v<versionName>
git push origin master --tags
```

- **`versionCode` (`+N`)**: deve sempre aumentare, altrimenti Android rifiuta l'installazione.
- **`versionName`**: guida il rilevamento update in-app (`ReleaseInfo.isNewerThan`, confronto numerico).
- **Firma**: file non versionati: `android/noteton-release.p12` e `android/key.properties`. Senza `key.properties`, la build release ripiega sulla debug key, generando firma diversa.
- **Build locale**: richiede Android SDK + keystore ripristinata; usare `flutter build apk --release`.
- **Storico**: release ≤ v0.10.0 firmate con debug key; v0.10.1 è la prima con keystore definitiva.

## Convenzioni e flussi specifici

- **Import PDF**: dedup tramite hash SHA-256 (`file_hash`); i path PDF sono salvati **relativi** per portabilità.
- **Annotazioni**: disegno con `perfect_freehand`, coordinate normalizzate 0–1, persistite in `annotations` come JSON (`annotation_repository.dart` + `viewer/drawing_layer.dart`).
- **Backup**: file `.ntb` (ZIP v3 con validazione CRC32); import in 3 fasi: validazione schema → staging file → import transazionale.
- **Checkpoint**: snapshot DB+PDF in `docs/.checkpoints/<timestamp>/`, retention max 3.
- **Auto-update in-app**: controlla le release su GitHub, scarica l'APK e installa via platform channel (solo Android).
- **Diagnostica**: schermata nascosta, accessibile con 7 tap sull'etichetta versione in Impostazioni.

## Sicurezza, segreti e file `.env`

- Se servono credenziali/API key locali, tenerle in file `.env` non versionati.
- Considerare segreti anche file di firma Android come `android/key.properties`, `android/noteton-release.p12`, keystore `.jks`/`.keystore` e qualsiasi file con password/token.
- Gli agenti AI non devono leggere, stampare o riportare in chat il contenuto dei file `.env` o di altri file segreti: evitare `read`, `cat`, `grep` sul contenuto e comandi equivalenti.
- È consentito usare i file segreti localmente per operazioni necessarie (es. `cp`, `test -f`, `flutter build apk --release`, Gradle) purché i valori non vengano stampati nell'output.
- È consentito scrivere/usare script Python che leggono il `.env` localmente tramite nomi di variabili d'ambiente, senza esporre i valori.
- Per verifiche, mostrare solo informazioni non sensibili, ad esempio presenza del file/variabile, `bool(os.getenv('API_KEY'))`, status code o messaggi generici.
- Non inserire valori segreti nei comandi, nei log, nei test o negli output condivisi; evitare modalità verbose se possono stampare configurazioni o credenziali.
- Ricordare che modello e chat vedono comandi/output prodotti dagli strumenti: quindi i segreti devono restare nei file locali e non comparire mai in stdout/stderr.

## Note di lavoro

- Esiste un recap dettagliato dello stato di ogni feature e dei miglioramenti consigliati in `.claude/suggests.md` (non versionato). Consultalo come bussola se disponibile.
- Sono disponibili agenti dedicati in `.claude/agents/`: `feature-builder`, `test-writer`, `lint-fixer`, `db-migration-guard`. Usa sempre `db-migration-guard` quando tocchi lo schema DB.
- I test usano `sqflite_common_ffi` con DB in-memory; pattern di riferimento: `test/repositories/annotation_repository_test.dart` e helper in `test/helpers/`.
- Il README è disallineato rispetto al codice (dichiara DB v3 e omette feature complete): fidati del codice.
