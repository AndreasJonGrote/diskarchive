#!/usr/bin/env bash
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/diskindex"

LOG="$(mktemp)"
if xcodebuild test \
  -scheme diskindex \
  -destination platform=macOS \
  -only-testing:diskindexTests/WindowTestGroup/ColumnChangeLoopTests \
  -only-testing:diskindexTests/WindowTestGroup/LiveWatchSubfolderTests \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -maximum-test-execution-time-allowance 120 \
  2>&1 | tee "$LOG"; then
  if rg -q "✘ Test" "$LOG"; then
    echo "LIVE-KETTE FEHLER:"
    rg "✘ Test" "$LOG" || true
    exit 1
  fi
  echo "LIVE-KETTE OK"
else
  echo "LIVE-KETTE FEHLER:"
  rg "✘ Test|error:" "$LOG" || true
  exit 1
fi
