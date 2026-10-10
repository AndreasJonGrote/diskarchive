#!/usr/bin/env bash
# Vergleicht find-Zähler mit SQLite fileCount+folderCount (Medium einmal indiziert).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOUNT="${STRESS_MOUNT:-/Volumes/STRESS}"
STICK="${STRESS_STICK_ROOT:-$MOUNT/stick}"
DB="${DISKINDEX_DB:-$HOME/Library/Application Support/Disk Index/index.sqlite}"

if [[ ! -d "$STICK" ]]; then
  echo "Stick-Pfad fehlt: $STICK" >&2
  exit 1
fi

FIND_COUNT="$(find "$STICK" \( -type f -o -type d \) | wc -l | tr -d ' ')"
echo "find (Dateien+Ordner unter stick): $FIND_COUNT"

if [[ ! -f "$DB" ]]; then
  echo "DB fehlt: $DB — App einmal gegen STRESS indizieren." >&2
  exit 2
fi

SQL="$(sqlite3 "$DB" "SELECT name, file_count, folder_count FROM media WHERE name LIKE '%STRESS%' OR name LIKE '%STRESS%' LIMIT 5;" 2>/dev/null || true)"
if [[ -z "$SQL" ]]; then
  SQL="$(sqlite3 "$DB" "SELECT name, file_count, folder_count FROM media ORDER BY last_seen_at DESC LIMIT 3;" 2>/dev/null || true)"
fi
echo "SQLite media (name | files | folders):"
echo "$SQL"
echo "Hinweis: file_count+folder_count sollte zur App-Anzeige passen; find zählt Volume-Pfade inkl. stick-Wurzel."
