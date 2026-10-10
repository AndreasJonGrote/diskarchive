#!/usr/bin/env bash
# Paket-2-Stresstest (108) — Hybrid: Fill, Log/SQL-Checks, optionale Formen & Parallel-Messreihe.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/Werkzeuge"
APP="${DISKINDEX_APP:-}"
if [[ -z "$APP" ]]; then
  APP="$(find "$HOME/Library/Developer/Xcode/DerivedData"/diskindex-*/Build/Products/Release -name "Disk Index.app" -type d 2>/dev/null | head -1 || true)"
fi
LOG="$HOME/Library/Logs/Disk Index/diskindex.log"
IMAGE="${STRESS_IMAGE_PATH:-$TOOLS/stress-fat32.sparseimage}"
MOUNT="${STRESS_MOUNT:-/Volumes/STRESS}"
RESULTS="${STRESS_RESULTS_DIR:-$TOOLS/stress-results}"

stress_build_image() {
  if [[ "${STRESS_BUILD_IMAGE:-0}" != "1" ]]; then
    echo "FAT32-Image: übersprungen (STRESS_BUILD_IMAGE=1)"
    return 0
  fi
  echo "=== FAT32-Image (600m, MS-DOS FAT32) ==="
  if ! hdiutil create -size 600m -fs "MS-DOS FAT32" -volname STRESS -type SPARSE -layout NONE "$IMAGE" 2>/dev/null; then
    echo "hdiutil create fehlgeschlagen (Rechte/Full-Disk?)" >&2
    exit 1
  fi
  if ! hdiutil attach "$IMAGE" -mountpoint "$MOUNT" -nobrowse -quiet 2>/dev/null; then
    echo "hdiutil attach fehlgeschlagen — Mount $MOUNT prüfen" >&2
    exit 1
  fi
  echo "Mount: $MOUNT"
  mkdir -p "$MOUNT/stick/700-a" "$MOUNT/stick/700-b" "$MOUNT/stick/14300-a" "$MOUNT/stick/14300-b" "$MOUNT/stick/1400"
}

stress_fill() {
  if [[ "${STRESS_FILL_STICK:-0}" != "1" ]]; then
    echo "Fill: übersprungen (STRESS_FILL_STICK=1)"
    return 0
  fi
  bash "$TOOLS/stress_fill_stick.sh"
}

stress_form() {
  if [[ -z "${STRESS_FORM:-}" ]]; then
    return 0
  fi
  bash "$TOOLS/stress_fill_form.sh"
}

stress_parallel_series() {
  local series="${STRESS_PARALLEL:-}"
  [[ -z "$series" ]] && return 0
  mkdir -p "$RESULTS"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local out="$RESULTS/parallel-$ts.tsv"
  echo -e "parallel\tseconds\tnote" > "$out"
  IFS=',' read -ra levels <<< "$series"
  for p in "${levels[@]}"; do
    p="$(echo "$p" | tr -d ' ')"
    [[ -z "$p" ]] && continue
    echo "=== Parallel-Messreihe: IndexingLimits.parallelDirectoryReads=$p ==="
    echo "Hinweis: Release-Test mit Umgebung DISKINDEX_PARALLEL=$p — z. B.:"
    echo "  DISKINDEX_PARALLEL=$p xcodebuild test -scheme diskindex -destination 'platform=macOS' -only-testing:diskindexTests/ScaleMeasurementTests -parallel-testing-enabled NO"
    echo -e "$p\t-\tmanuell oder CI-Job (siehe ScaleMeasurementTests)" >> "$out"
  done
  echo "TSV: $out"
}

echo "=== Disk Index Stresstest (Hybrid) ==="
echo "Projekt: $ROOT"
echo "App: ${APP:-'(Release-Build: xcodebuild -configuration Release)'}"
echo "Log: $LOG"
stress_build_image
stress_fill
stress_form
bash "$TOOLS/stress_verify.sh" || VERIFY=$?
VERIFY="${VERIFY:-0}"
if [[ -d "${STRESS_MOUNT:-/Volumes/STRESS}/stick" ]]; then
  bash "$TOOLS/stress_count.sh" || true
fi
stress_parallel_series

echo ""
echo "=== Abnahme (Halb-manuell) ==="
echo "(4) Auswerfen mitten im Lauf — App pausiert, Fortsetzen ohne Duplikat"
echo "(5) Datei offline ändern — Watcher/FSEvents nach Reconnect"
echo "(6) 3× identischer Stick-Lauf — Dauer/Log mit stress_verify.sh"
echo ""
if [[ "$VERIFY" -ne 0 ]]; then
  exit "$VERIFY"
fi
