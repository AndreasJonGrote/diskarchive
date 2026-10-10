#!/usr/bin/env bash
# Log-Abnahme für Paket-2-Stresstest (108): keine Lesestall/Zeitlimit, bulk=ja.
set -euo pipefail
LOG="${DISKINDEX_LOG:-$HOME/Library/Logs/Disk Index/diskindex.log}"
FAIL=0

if [[ ! -f "$LOG" ]]; then
  echo "Kein Log: $LOG" >&2
  exit 2
fi

check_absent() {
  local pattern="$1"
  local label="$2"
  if rg -q "$pattern" "$LOG" 2>/dev/null; then
    echo "FAIL: $label (Treffer in Log)"
    FAIL=1
  else
    echo "OK: kein $label"
  fi
}

check_present() {
  local pattern="$1"
  local label="$2"
  if rg -q "$pattern" "$LOG" 2>/dev/null; then
    echo "OK: $label"
  else
    echo "WARN: $label nicht im Log (Release-Lauf fehlt?)"
  fi
}

echo "=== stress_verify.sh ==="
echo "Log: $LOG"
check_absent "ordner zeitlimit" "ordner zeitlimit"
check_absent "ordner lesestall" "ordner lesestall"
check_present "lesen bulk=ja" "getattrlistbulk (lesen bulk=ja)"

echo "--- letzte relevante Zeilen ---"
rg "children count=|ebene ms=|lesen bulk=|ordner " "$LOG" 2>/dev/null | tail -12 || true

if rg -q "ebene ms=" "$LOG" 2>/dev/null; then
  last_ms="$(rg "ebene ms=" "$LOG" | tail -1 | sed -n 's/.*ebene ms=\([0-9.]*\).*/\1/p')"
  if [[ -n "$last_ms" ]]; then
    echo "Letzte ebene ms=$last_ms (Referenz Archiv: Ziel < 60000 ms für Stick)"
  fi
fi

exit "$FAIL"
