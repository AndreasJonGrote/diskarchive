#!/usr/bin/env bash
# Aufgabe 107 — Spalten-Ladezeiten und Formen (a)/(b)/(c) im Release-Build messen.
# Build mit Flag BENCH; normale Release-App ohne dieses Flag ignoriert --column-load-bench.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/Werkzeuge/benchmarks"
STAMP="$(date +%Y%m%d-%H%M%S)"
RESULT="$OUT_DIR/column-load-$STAMP.txt"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

mkdir -p "$OUT_DIR"
cd "$ROOT/diskindex"

echo "=== column-load-bench: Release + BENCH bauen ==="
xcodebuild build -scheme diskindex -configuration Release -destination 'platform=macOS' \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='BENCH $(inherited)' \
  2>&1 | tee /tmp/diskindex-column-load-build.log | grep -E 'error:|warning:|BUILD ' | grep -v 'appintents\|Metadata' || true
if ! grep -q 'BUILD SUCCEEDED' /tmp/diskindex-column-load-build.log; then
  echo "Build fehlgeschlagen" >&2
  exit 1
fi

APP="$(find "$HOME/Library/Developer/Xcode/DerivedData"/diskindex-*/Build/Products/Release -name 'Disk Index.app' -type d 2>/dev/null | head -1)"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "Release-App nicht gefunden" >&2
  exit 1
fi
BIN="$APP/Contents/MacOS/Disk Index"
echo "App: $APP"
echo "Ergebnis: $RESULT"
echo "Start: $(date '+%Y-%m-%d %H:%M:%S')"

set +e
"$BIN" --column-load-bench "$RESULT" 2>&1 | tee /tmp/diskindex-column-load-run.log
BENCH_RC=${PIPESTATUS[0]}
set -e

if [[ -f "$RESULT" ]]; then
  cp "$RESULT" "$OUT_DIR/column-load-latest.txt"
  echo "=== Inhalt ==="
  cat "$RESULT"
else
  echo "Keine Messdatei — Log: /tmp/diskindex-column-load-run.log" >&2
  exit 1
fi

if [[ "$BENCH_RC" -ne 0 ]]; then
  echo "Bench-Prozess Exit $BENCH_RC" >&2
  exit "$BENCH_RC"
fi

echo "Ende: $(date '+%Y-%m-%d %H:%M:%S')"
