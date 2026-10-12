#!/usr/bin/env bash
# Aufgabe 196 — Messung Datenbank („vorher“). Läuft nur mit DA_BENCH=1; Ausgabe: Werkzeuge/messung/<Datum>-vorher.md/.json.
# Debug mit -O, weil die Tests Debug-Hilfen brauchen (Release-Testbuild scheitert). Kein Fenster.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$ROOT/diskindex"
TEST_RUNNER_DA_BENCH=1 xcodebuild test -scheme diskindex -destination 'platform=macOS' \
  -only-testing:diskindexTests/IndexBenchTests${BENCH_ONLY:+/$BENCH_ONLY} -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 7200 -maximum-test-execution-time-allowance 7200 \
  SWIFT_OPTIMIZATION_LEVEL=-O 2>&1 | { grep -E "BENCH|error:|✘|✔|TEST " || true; }
