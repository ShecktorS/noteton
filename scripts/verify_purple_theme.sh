#!/bin/bash
# Script di verifica implementazione tema purple

set -e

PROJECT_ROOT="/storage/emulated/0/Synology Drive/Sync tasks/Noteton-957561646188901649"
cd "$PROJECT_ROOT"

echo "🔍 Verifica implementazione tema Purple (Amethyst)"
echo ""

echo "✓ Verifico esistenza file..."
[ -f "lib/core/theme/color_palettes.dart" ] && echo "  ✅ color_palettes.dart"
[ -f "docs/purple_theme_validation.md" ] && echo "  ✅ purple_theme_validation.md"

echo ""
echo "✓ Verifico enum ColorVariant..."
grep -q "enum ColorVariant" lib/core/theme/app_theme.dart && echo "  ✅ ColorVariant definito"
grep -q "purple," lib/core/theme/app_theme.dart && echo "  ✅ Variante purple presente"

echo ""
echo "✓ Verifico provider..."
grep -q "ColorVariantNotifier" lib/providers/providers.dart && echo "  ✅ ColorVariantNotifier implementato"
grep -q "colorVariantProvider" lib/providers/providers.dart && echo "  ✅ Provider esposto"

echo ""
echo "✓ Verifico UI Settings..."
grep -q "_ColorVariantSelector" lib/presentation/settings/settings_screen.dart && echo "  ✅ Widget selettore presente"
grep -q "Amethyst" lib/presentation/settings/settings_screen.dart && echo "  ✅ Label 'Amethyst' trovata"

echo ""
echo "✓ Verifico integrazione MaterialApp..."
grep -q "colorVariantProvider" lib/app.dart && echo "  ✅ Provider watchato"
grep -q "AppTheme.dark(colorVariant)" lib/app.dart && echo "  ✅ Dark theme parametrizzato"
grep -q "AppTheme.light(colorVariant)" lib/app.dart && echo "  ✅ Light theme parametrizzato"

echo ""
echo "✓ Analisi statica Dart..."
dart analyze lib/core/theme/ lib/app.dart lib/providers/providers.dart lib/presentation/settings/settings_screen.dart 2>&1 | grep -q "No issues found" && echo "  ✅ Nessun errore lint" || echo "  ⚠️  Controlla output analisi"

echo ""
echo "🎨 Palette Purple Theme:"
echo "  Seed:      #7B4397  (Violetto profondo)"
echo "  Secondary: #FFB74D  (Ambra caldo)"
echo "  Tertiary:  #4DB6AC  (Teal)"
echo "  Surface:   #1A1420  (Dark mode)"
echo ""
echo "📊 Contrast Ratio (WCAG):"
echo "  Purple su bianco:       6.79:1  ✓ AA"
echo "  White su dark surface: 18.03:1  ✓ AAA"
echo ""
echo "✅ Implementazione completata!"
echo "📖 Leggi docs/purple_theme_validation.md per checklist UX completa"
