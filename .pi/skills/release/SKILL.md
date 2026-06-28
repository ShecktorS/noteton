---
name: release
description: Bump della versione, verifica (analyze + test) e pubblicazione di una release Noteton tramite tag git v*. Usare quando si vuole rilasciare una nuova versione Android.
disable-model-invocation: true
---

# Release Noteton

Esegui il rituale di rilascio descritto in `CLAUDE.md`. Il push del tag `v*` avvia
`.github/workflows/release.yml`, che builda l'APK firmato e pubblica la GitHub Release.

## Argomenti

L'utente può passare la versione di destinazione: `/release 0.10.2`.
Se non la passa, leggi quella attuale da `pubspec.yaml` e proponi il prossimo patch.

## Procedura (segui in ordine, fermati a ogni errore)

1. **Leggi la versione attuale** in `pubspec.yaml` (riga `version: <name>+<code>`).
2. **Calcola i nuovi valori**:
   - `versionName`: quello richiesto dall'utente (o patch +1 se non specificato).
   - `versionCode` (il `+N`): **DEVE sempre crescere** di almeno 1, altrimenti Android
     rifiuta l'installazione. Non riusarlo mai.
3. **Aggiorna `pubspec.yaml`** con la nuova riga `version:`.
4. **Verifica** che la build sia sana — chiedi all'utente di eseguirli se Flutter non è
   su questa macchina, altrimenti lancia:
   - `flutter analyze`  → deve essere verde
   - `flutter test`     → deve essere verde
   Non proseguire se uno dei due fallisce.
5. **Commit**: `git commit -am "release: v<versionName>"`.
6. **Tag**: `git tag v<versionName>` — il tag DEVE essere `v<versionName>` esatto
   (è ciò che innesca la CI e guida il rilevamento update in-app).
7. **Push**: `git push origin master --tags`.
8. **Conferma** all'utente: ricorda che la CI ora builda l'APK firmato e pubblica
   `Noteton-<versione>.apk` nella GitHub Release. Suggerisci di controllare il workflow.

## Note critiche

- `versionName` guida il confronto update in-app (`ReleaseInfo.isNewerThan`).
- La firma vive nei GitHub Secrets: la release è firmata in modo costante da qualunque PC.
- Non inserire mai Claude come coautore del commit (preferenza utente globale).
