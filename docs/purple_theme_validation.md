# Validazione Tema Purple (Amethyst)

## ✅ Implementazione completata

### 1. Sistema di palette colori
- ✅ File `lib/core/theme/color_palettes.dart` con palette strutturate
- ✅ Seed color violetto: `#7B4397` (contrast ratio 6.79:1 su bianco - WCAG AA ✓)
- ✅ Accent ambra: `#FFB74D` (contrasto complementare caldo)
- ✅ Tertiary teal: `#4DB6AC` (palette triadica)
- ✅ Superfici dark personalizzate con tonalità viola desaturata

### 2. Architettura tema estensibile
- ✅ Enum `ColorVariant` con valori `defaultTheme` e `purple`
- ✅ Metodi `AppTheme.dark(variant)` e `AppTheme.light(variant)`
- ✅ Pattern matching per selezione palette dinamica
- ✅ Preservata tutta la personalizzazione componenti (AppBar, Card, Dialog, etc.)

### 3. State management
- ✅ `ColorVariantNotifier` con persistenza SharedPreferences
- ✅ Provider `colorVariantProvider` separato da `themeModeProvider`
- ✅ Supporto combinazioni: dark-purple, light-purple, dark-default, light-default

### 4. UI Settings
- ✅ Sezione "Variante colore" con chip selezionabili
- ✅ Anteprima colore circolare su ogni chip
- ✅ Label semantiche: "Midnight" (default) e "Amethyst" (purple)
- ✅ Feedback visivo selezione con bordo primary

### 5. Integrazione MaterialApp
- ✅ `app.dart` costruisce temi dinamicamente da entrambi i provider
- ✅ Hot reload supportato (cambio colore istantaneo)

---

## 🎨 Specifiche colore Purple Theme

### Dark Mode
```dart
Seed:       #7B4397  // Violetto profondo
Primary:    Auto-generated da Material Design 3
Secondary:  #FFB74D  // Ambra caldo
Tertiary:   #4DB6AC  // Teal

Surfaces:
  - surface:                  #1A1420  // Viola scurissimo
  - surfaceContainerLowest:   #110D15
  - surfaceContainerLow:      #1F1726
  - surfaceContainer:         #261E2F
  - surfaceContainerHigh:     #2D243A
  - surfaceContainerHighest:  #352B42
```

### Light Mode
```dart
Seed:       #7B4397  // Violetto profondo
Secondary:  #FFB74D  // Ambra caldo
Tertiary:   #4DB6AC  // Teal
(Superfici generate automaticamente da Material Design 3)
```

---

## 🔍 Checklist validazione UI/UX

### Accessibilità (WCAG AA)
- [x] Contrast ratio testo su background ≥ 4.5:1
- [x] Contrast ratio UI elements ≥ 3:1
- [x] Primary color visibile su tutte le superfici
- [x] Error color (#CF4545) preservato per coerenza

### Gerarchia visiva
- [ ] Testare su Library screen (lista brani)
- [ ] Testare su Setlist detail (reorder items)
- [ ] Testare su Viewer (annotazioni + toolbar)
- [ ] Testare su Settings (tutte le sezioni)
- [ ] Verificare NavigationBar (indicatore selezione)
- [ ] Verificare FAB (contrasto su background)

### Coerenza componenti
- [ ] Card elevation e bordi
- [ ] Dialog e BottomSheet
- [ ] TextField focus state
- [ ] Chip selected/unselected
- [ ] ListTile hover/pressed
- [ ] SnackBar su background dark

### Stati interattivi
- [ ] Pressed state su tutti i bottoni
- [ ] Hover state (desktop/web)
- [ ] Disabled state (opacity corretta)
- [ ] Selection overlay su liste

---

## 🎯 Principi design applicati

### 1. Material Design 3
- ✅ ColorScheme generato da seed (tonalità coerenti)
- ✅ Surface elevation system (container levels)
- ✅ Dynamic color support architecture

### 2. Separazione responsabilità
- ✅ Brightness (light/dark) separata da ColorVariant
- ✅ Palette colori isolate in modulo dedicato
- ✅ Theme logic centralizzata in AppTheme

### 3. Scalabilità
- ✅ Facile aggiunta nuove varianti (es: green, amber, blue)
- ✅ Pattern replicabile per customizzazioni future
- ✅ Zero breaking changes su codice esistente

### 4. Accessibilità by design
- ✅ Contrast ratio verificato in fase di selezione colori
- ✅ Superfici dark custom per preservare readability
- ✅ Error color non compromesso (safety-critical)

---

## 🚀 Come testare

1. **Avvia app in development:**
   ```bash
   flutter run -d linux  # o android/ios
   ```

2. **Naviga in Settings → Aspetto**

3. **Seleziona chip "Amethyst"** → tema cambia istantaneamente

4. **Verifica sezioni:**
   - Libreria → card brani, colore primary su FAB
   - Setlist → lista items, reorder handles
   - Viewer → toolbar, annotazioni overlay
   - Settings → tutte le ListTile, tag colors

5. **Toggle light/dark mode** per testare entrambe le varianti

---

## 📝 Note implementazione

### Perché Amethyst?
- Nome evocativo (gemma preziosa come "Gold Leaf" del tema default)
- Associato a creatività e concentrazione (UX musicale)
- Contrasto eccellente con oro/ambra (warmth balance)

### Perché superfici dark custom?
Le superfici default Material avrebbero un tint blu (dal seed). Custom surfaces con tint viola mantengono:
- Coerenza cromatica end-to-end
- Migliore distinzione visiva tra varianti
- Preserva l'"identità" del tema

### Perché teal come tertiary?
- Complementare cromatico del viola (ruota colori)
- Usato per indicatori "in chiave" (existing pattern)
- Non compete visivamente con primary/secondary

---

## 🔧 Manutenzione futura

### Aggiungere nuova variante colore:
1. Definire palette in `color_palettes.dart`
2. Aggiungere enum value in `ColorVariant`
3. Estendere switch expressions in `app_theme.dart`
4. Aggiungere label/preview in `_ColorVariantSelector`

### Modificare colori esistenti:
- **Superfici**: modificare `DarkSurfaceColors` constants
- **Accenti**: modificare seed/secondary/tertiary in palette
- **Error**: modificare in `app_theme.dart` (applicato globalmente)

### Test automatici (TODO):
```dart
testWidgets('Purple theme applies correctly', (tester) async {
  final container = ProviderContainer(
    overrides: [
      colorVariantProvider.overrideWith((_) => ColorVariantNotifier()
        ..state = ColorVariant.purple),
    ],
  );
  // Verify ColorScheme.primary matches expected purple tone
});
```
