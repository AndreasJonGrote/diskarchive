#!/usr/bin/env bash
# Optionale Stress-Formen a|b|c (lange Laufzeit) — nur bei STRESS_FORM gesetzt.
set -euo pipefail
FORM="${STRESS_FORM:-}"
MOUNT="${STRESS_MOUNT:-/Volumes/STRESS}"
ROOT="${STRESS_FORM_ROOT:-$MOUNT/form-$FORM}"

if [[ -z "$FORM" ]]; then
  echo "STRESS_FORM nicht gesetzt (a|b|c)" >&2
  exit 0
fi

case "$FORM" in
  a)
    echo "Form a: breite flache Struktur (1000 Ordner × 10 Dateien)"
    mkdir -p "$ROOT"
    for d in $(seq 1 1000); do
      mkdir -p "$ROOT/o-$d"
      for f in $(seq 1 10); do echo x > "$ROOT/o-$d/f-$f.txt"; done
    done
    ;;
  b)
    echo "Form b: tiefe Kette (200 Ebenen)"
    mkdir -p "$ROOT"
    cur="$ROOT"
    for i in $(seq 1 200); do
      cur="$cur/level-$i"
      mkdir -p "$cur"
      echo x > "$cur/file.txt"
    done
    ;;
  c)
    echo "Form c: gemischt (50×50 Dateien pro Ordner)"
    mkdir -p "$ROOT"
    for d in $(seq 1 50); do
      mkdir -p "$ROOT/bulk-$d"
      for f in $(seq 1 50); do echo x > "$ROOT/bulk-$d/f-$f.txt"; done
    done
    ;;
  *)
    echo "Unbekannte STRESS_FORM=$FORM (a|b|c)" >&2
    exit 1
    ;;
esac
find "$ROOT" | wc -l | awk '{print "Einträge: " $1}'
