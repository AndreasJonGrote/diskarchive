#!/bin/zsh
# Setzt den Testzustand von Disk Index zurück.
#   ./testzustand-zuruecksetzen.sh                  App beenden, Index (Datenbank) löschen
#   ./testzustand-zuruecksetzen.sh --mit-freigabe   zusätzlich die macOS-Freigabe „Wechseldatenträger“ löschen
pkill -x "Disk Index" 2>/dev/null
sleep 1
DIR="$HOME/Library/Application Support/Disk Index"
rm -f "$DIR/index.sqlite" "$DIR/index.sqlite-wal" "$DIR/index.sqlite-shm"
echo "App beendet, Datenbank gelöscht."
if [[ "$1" == "--mit-freigabe" ]]; then
  tccutil reset SystemPolicyRemovableVolumes xjonx.diskindex | head -1
fi
