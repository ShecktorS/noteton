# Piano implementazione — Canale aggiornamenti Stable/Beta

## Obiettivo

Consentire all'utente di scegliere, dalla schermata aggiornamenti dell'app, se ricevere solo release stabili o anche release beta.

## UX finale

Percorso:

```text
Impostazioni → Aggiornamento automatico → Canale aggiornamenti
```

Controllo UI:

```text
[ Stabile ] [ Beta ]
```

- **Stabile**: scelta predefinita, consigliata per l'uso quotidiano.
- **Beta**: abilita versioni di prova. Alla prima selezione mostra un dialog di conferma con disclaimer.

La tile principale in `Impostazioni` riassume lo stato:

```text
Attivo · canale stabile
Attivo · canale beta
Disattivato · canale stabile
Disattivato · canale beta
```

## Flusso tecnico

1. `UpdateChannelNotifier` carica il canale da `SharedPreferences`.
2. `UpdateNotifier.check()` legge il canale corrente.
3. `UpdateService.checkForUpdate(channel: ...)` seleziona l'endpoint GitHub:
   - `stable` → `/releases/latest`
   - `beta` → `/releases`
4. Il modello `ReleaseInfo` valuta se una release è più recente della versione installata.
5. Se la release è una pre-release, banner e dialog mostrano badge `BETA`.

## Checklist completata

- [x] Enum `UpdateChannel` dedicato.
- [x] Persistenza `update_channel` in `SharedPreferences`.
- [x] Migrazione della precedente chiave booleana `beta_channel_enabled`.
- [x] Endpoint GitHub `/releases` per canale beta.
- [x] Confronto semver corretto con suffissi pre-release.
- [x] Selettore Stable/Beta nella schermata update.
- [x] Dialog di conferma quando si abilita Beta.
- [x] Badge `BETA` in banner home e dialog aggiornamento.
- [x] Test regressione per versioni beta.

## Note operative release

Una beta va pubblicata come GitHub pre-release con tag tipo:

```text
v0.11.0-beta.1
```

La stable finale usa:

```text
v0.11.0
```

L'auto-update stabile continua a non mostrare le beta perché usa `/releases/latest`.
