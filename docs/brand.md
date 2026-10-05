# Linea di brand Noteton — "Inchiostro e accento"

Noteton è uno strumento da leggio: deve sparire dietro la musica. La linea di
brand prende in prestito dallo spartito solo ciò che serve a orientarsi
(righe, stanghette, teste di nota, indicazioni in maiuscoletto) e lo usa con
parsimonia, sempre sopra superfici calme.

Principi:

1. **La musica prima della UI.** Colori tenui, niente decorazioni nel viewer;
   i motivi grafici vivono solo nei momenti "di servizio" (avvisi, novità,
   stati vuoti, onboarding).
2. **Un solo accento.** L'oro/ambra (`secondary`) è la "dinamica" della UI:
   segnala ciò che merita attenzione. Mai più di un elemento d'accento forte
   per schermata.
3. **Stessa grammatica in ogni tema.** Le varianti colore cambiano i toni,
   non forme, spaziature o motivi.

Token in codice: `lib/core/theme/brand.dart` (`NotetonBrand`).
Motivi riutilizzabili: `lib/presentation/common/brand/`.

## Palette

I colori arrivano sempre dal `ColorScheme` del tema: non usare esadecimali
nei widget. Ruoli:

| Ruolo | Uso | Midnight Ink | Amethyst |
|---|---|---|---|
| `primary` / `primaryContainer` | Azioni principali, simboli, indicatore nav | blu inchiostro `#1A2F4A` (seed) | violetto `#7B4397` (seed) |
| `secondary` → `NotetonBrand.accent()` | Accento: stanghetta, occhielli, teste di nota, badge | oro `#D4A853` | ambra `#FFB74D` |
| `tertiary` | Stati positivi / "in chiave" | verde `#8BC9A0` | teal `#4DB6AC` |
| `surfaceContainer*` | Card e fogli (dark: superfici custom) | blu notte | viola notte |
| `onSurfaceVariant` | Testo secondario, date, azioni di chiusura | — | — |

**Accento nel tema chiaro.** L'oro puro sul bianco non è leggibile (≈2:1).
`NotetonBrand.accent()` restituisce `secondary` nel dark e una versione
scurita del 45% verso l'inchiostro nel light. Contrasti verificati sulle card:

| | Dark | Light |
|---|---|---|
| Oro (Midnight Ink) | 6.1:1 | 5.7:1 |
| Ambra (Amethyst) | 8.5:1 | 4.7:1 |

## Tipografia

Font di sistema (Roboto su Android, SF su iOS): niente font esterni, lettura
rapida sul leggio. La gerarchia si costruisce con peso e spaziatura:

| Stile | Base | Uso |
|---|---|---|
| Occhiello | `labelSmall`, w700, maiuscolo, `letterSpacing 1.4`, colore accento | Etichette sopra i titoli ("NUOVA VERSIONE", sezioni del changelog). Richiama le indicazioni agogiche sullo spartito. |
| Titolo | `titleMedium`, w600, `letterSpacing -0.2` | Titolo di card e dialog |
| Corpo | `bodyMedium`, `height 1.4` | Testi e voci di elenco |
| Meta | `bodySmall`, `onSurfaceVariant` | Date, contatori, note |

Numeri di versione, BPM e numeri di pagina usano le cifre tabellari
(`FontFeature.tabularFigures()`), così non "ballano".

## Forma e spaziatura

- Griglia da 4: `space1`…`space6` = 4, 8, 12, 16, 20, 24.
- Raggi: `radiusSm` 10 (campi), `radiusMd` 14 (tile, chip, simboli),
  `radiusLg` 18 (card), `radiusXl` 24 (dialog, fogli).
- Card: nessuna ombra. Nel dark si distinguono per tono di superficie,
  nel light con un bordo `outlineVariant`.

## Motivi musicali

| Motivo | Widget | Quando |
|---|---|---|
| **Stanghetta d'accento** | barra verticale `barlineWidth` 4 in colore accento sul bordo sinistro | Card che portano un messaggio (aggiornamento, novità, avviso). Una sola per schermata. |
| **Pentagramma** | `StaffLines` | Texture sotto un simbolo o in uno stato vuoto. Opacità bassa (`staffOpacity` 0.10, fino a ~0.22 su container colorati); mai sotto del testo. |
| **Testa di nota** | `NoteHeadBullet`, `NoteBulletItem` | Punto elenco per changelog, novità, elenchi di funzioni. |
| **Occhiello** | `BrandEyebrow`, `BrandBetaBadge` | Etichetta di contesto sopra un titolo; badge a pillola contornata per stati (BETA). |

I motivi sono decorativi: sono esclusi dalla semantica di accessibilità.

## Iconografia

- Famiglia unica: Material Icons in variante **rounded** (`Icons.*_rounded`)
  per le nuove schermate; migrare gradualmente le varianti filled/outlined.
- Icone musicali come simboli di sezione: `music_note_rounded`
  (brano/aggiornamento), `queue_music_rounded` (setlist),
  `library_music_rounded` (libreria/collezioni), `av_timer_rounded`
  (metronomo).
- Un simbolo di sezione vive in un tile `radiusMd` su `primaryContainer`;
  un eventuale segno di stato è un piccolo cerchio in colore accento
  nell'angolo (es. freccia ↑ per "nuova versione").

## Applicazione

| Area | Stato |
|---|---|
| Banner aggiornamento in libreria + dialog "Leggi tutto" | ✅ fatto |
| Dialog "Novità" (avvio e Impostazioni) e dialog di aggiornamento all'avvio | ✅ fatto (`release_dialogs.dart`) |
| Tema light: raggi card 18 e dialog 24 come nel dark | ✅ fatto |
| Tema light: superfici e bordi allineati al dark | da fare |
| Stati vuoti (libreria, setlist, collezioni) con pentagramma | da fare |
| Navigation bar, Impostazioni, icone rounded | da fare |
| Viewer PDF e modalità performance | invariati per scelta: niente decorazioni sulla musica |
