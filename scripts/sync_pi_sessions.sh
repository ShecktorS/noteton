#!/bin/bash
# Script per sincronizzare le sessioni pi nella cartella progetto
# Esegui dopo ogni conversazione importante per averle su Synology Drive

set -e

PROJECT_ROOT="/storage/emulated/0/Synology Drive/Sync tasks/Noteton-957561646188901649"
PI_SESSIONS_SOURCE=~/.pi/agent/sessions/--storage-emulated-0-Synology\ Drive-Sync\ tasks-Noteton-957561646188901649--/
PI_SESSIONS_DEST="$PROJECT_ROOT/.pi-sessions"

echo "📋 Sincronizzazione sessioni pi..."
echo ""
echo "Sorgente: $PI_SESSIONS_SOURCE"
echo "Destinazione: $PI_SESSIONS_DEST"
echo ""

# Crea la cartella se non esiste
mkdir -p "$PI_SESSIONS_DEST"

# Copia tutte le sessioni (sovrascrive quelle esistenti)
rsync -av --delete "$PI_SESSIONS_SOURCE" "$PI_SESSIONS_DEST/" 2>/dev/null || \
  cp -rf "$PI_SESSIONS_SOURCE"* "$PI_SESSIONS_DEST/"

echo ""
echo "✅ Sincronizzazione completata!"
echo ""
echo "📂 Sessioni disponibili:"
ls -lh "$PI_SESSIONS_DEST"/*.jsonl | tail -5
echo ""
echo "💡 Ora le conversazioni sono su Synology Drive e accessibili dal PC"
echo "   Per continuare dal PC: pi --session <percorso-al-file.jsonl>"
