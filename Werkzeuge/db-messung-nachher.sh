#!/usr/bin/env bash
# Aufgabe 238 — Messung Datenbank („nachher“). DA_BENCH=1, Ausgabe: Werkzeuge/messung/<Datum>-nachher.md/.json.
# Echte Messung: DA_BENCH_SCALE=1 (Default). Probe: DA_BENCH_SCALE=0.01 BENCH_ONLY=s1OneMediumOneMillion
# Debug mit -O. Kein Fenster.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$ROOT/diskindex"
TEST_RUNNER_DA_BENCH=1 TEST_RUNNER_DA_BENCH_NAME=nachher xcodebuild test -scheme diskindex -destination 'platform=macOS' \
  -only-testing:diskindexTests/IndexBenchTests${BENCH_ONLY:+/$BENCH_ONLY} -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 7200 -maximum-test-execution-time-allowance 7200 \
  SWIFT_OPTIMIZATION_LEVEL=-O 2>&1 | { grep -E "BENCH|error:|✘|✔|TEST " || true; }
