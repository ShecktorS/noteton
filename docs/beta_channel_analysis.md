# Canale aggiornamenti Stable/Beta — analisi

## Stato precedente

L'auto-update in-app usava solo l'endpoint GitHub:

```text
/repos/ShecktorS/noteton/releases/latest
```

Questo endpoint restituisce solo l'ultima release stabile e ignora automaticamente le pre-release. Era quindi impossibile far arrivare una beta a chi volesse provarla dall'app.

## Scelta implementativa

La preferenza utente è modellata come canale esplicito, non come toggle generico:

- **Stabile**: mostra solo release ufficiali consigliate.
- **Beta**: mostra anche pre-release GitHub (`beta`, `alpha`, `rc`) oltre alle stable.

Il default resta **Stabile**.

## File coinvolti

| File | Ruolo |
|---|---|
| `lib/domain/models/update_channel.dart` | Enum `UpdateChannel` (`stable`, `beta`) |
| `lib/core/constants/app_constants.dart` | Aggiunge endpoint `/releases` |
| `lib/core/services/update_service.dart` | Controlla `/latest` o `/releases` in base al canale |
| `lib/domain/models/release_info.dart` | Supporta `prerelease` e confronto semver con beta |
| `lib/providers/providers.dart` | Persiste il canale in `SharedPreferences` |
| `lib/presentation/settings/auto_update_screen.dart` | Selettore Stable/Beta nelle impostazioni update |
| `lib/presentation/common/update_home_banner.dart` | Badge `BETA` per pre-release |
| `lib/app.dart` | Badge `BETA` nel dialog di aggiornamento all'avvio |

## Persistenza

Nuova chiave:

```text
update_channel = stable | beta
```

La vecchia preferenza temporanea `beta_channel_enabled` viene migrata in lettura: se esiste ed è `true`, il canale diventa `beta`; al salvataggio viene rimossa.

## Regole versioning

Il confronto segue il semantic versioning:

```text
0.11.0 > 0.11.0-beta.10 > 0.11.0-beta.2 > 0.11.0-beta.1 > 0.10.3
```

Quindi:

- una beta nuova viene proposta agli utenti sul canale beta;
- una stable finale viene proposta anche a chi è su beta della stessa versione;
- `beta.10` è più recente di `beta.2` tramite confronto numerico, non lessicografico.
