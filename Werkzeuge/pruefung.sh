#!/bin/bash
# Werkzeuge/pruefung.sh — Prüfläufe des Hosts (archiv/abnahme-ablauf.md, Abschnitt 3).
# Pflege nur durch den Host (AGENTS.md). Der Worker ändert diese Datei nicht.
#
# Aufruf (aus beliebigem Ordner):
#   Werkzeuge/pruefung.sh voll                      Paketende: Build, seriell, 3x parallel, Release, .ips, Regel 23
#   Werkzeuge/pruefung.sh schnell [Suite ...]       Build + Warnungen + gezielte Suites (nur Lesen, keine Nutzer-App)
# Umgebung (alles optional):
#   S=<Ordner>   Scratch-Ordner (Standard: neuer Ordner unter ${TMPDIR:-/tmp}); nie im Repository
#   KEEP=1       DerivedData nicht löschen
# Ausgabe: eine Zusammenfassung ($S/zusammenfassung.txt, am Ende auch auf stdout), Rohlogs bleiben in $S.
# Kein Git, keine Eingriffe außerhalb von $S und dem DerivedData der Nutzer-App (Regel 23).

set -u
MODUS="${1:-voll}"; shift || true
SUITES=("$@")

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJ="$ROOT/diskindex"
[ -d "$PROJ" ] || { echo "Projektordner fehlt: $PROJ"; exit 2; }
cd "$PROJ" || exit 2

# Xcode: auf Rechnern mit Command Line Tools muss DEVELOPER_DIR gesetzt sein (nichts am System ändern).
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

S="${S:-$(mktemp -d "${TMPDIR:-/tmp}/pruefung.XXXXXX")}"
mkdir -p "$S"
DD="$S/dd"; DDREL="$S/dd-rel"; SUM="$S/zusammenfassung.txt"
DEST='platform=macOS,arch=arm64'
BASIS=(-project diskindex.xcodeproj -scheme diskindex -destination "$DEST")
TESTOPT=(-only-testing:diskindexTests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120)
: > "$SUM"

zeit() { date '+%H:%M:%S'; }
log()  { echo "$*" | tee -a "$SUM"; }
warnungen() { grep "warning:" "$1" | grep -v appintents | sort -u | wc -l | tr -d ' '; }
testzeile() { grep -E "Test run with|Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)" "$1" | tail -2 | tr '\n' ' '; }

log "Prüfung $MODUS  Start $(zeit)  Scratch $S"
log "Rechner: $(sw_vers -productVersion), $(xcodebuild -version 2>/dev/null | head -1)"
BEZUG="$S/bezug"; touch "$BEZUG"

# 1. Build mit Testziel
START=$(zeit)
xcodebuild clean build-for-testing "${BASIS[@]}" -derivedDataPath "$DD" > "$S/build.log" 2>&1
log "Build Debug+Testziel: Exit $?  Warnungen $(warnungen "$S/build.log") (Ziel 0)  $START–$(zeit)"

if [ "$MODUS" = "schnell" ]; then
  ARGS=()
  if [ "${#SUITES[@]}" -gt 0 ]; then
    for s in "${SUITES[@]}"; do ARGS+=("-only-testing:diskindexTests/$s"); done
  else
    ARGS=(-only-testing:diskindexTests)
  fi
  START=$(zeit)
  xcodebuild test-without-building "${BASIS[@]}" -derivedDataPath "$DD" "${ARGS[@]}" \
    -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 \
    -resultBundlePath "$S/schnell.xcresult" > "$S/schnell.log" 2>&1
  log "Gezielt (${SUITES[*]:-alle}): Exit $?  $(testzeile "$S/schnell.log")  $START–$(zeit)"
else
  # 2. Seriell
  START=$(zeit)
  xcodebuild test-without-building "${BASIS[@]}" -derivedDataPath "$DD" "${TESTOPT[@]}" \
    -parallel-testing-enabled NO -resultBundlePath "$S/seriell.xcresult" > "$S/seriell.log" 2>&1
  log "Seriell: Exit $?  $(testzeile "$S/seriell.log")  $START–$(zeit)"

  # 3. Parallel, dreimal
  for i in 1 2 3; do
    START=$(zeit)
    xcodebuild test-without-building "${BASIS[@]}" -derivedDataPath "$DD" "${TESTOPT[@]}" \
      -parallel-testing-enabled YES -resultBundlePath "$S/par$i.xcresult" > "$S/par$i.log" 2>&1
    RC=$?
    log "Parallel $i: Exit $RC  $(testzeile "$S/par$i.log")  $START–$(zeit)"
    if [ -d "$S/par$i.xcresult" ]; then
      xcrun xcresulttool get test-results summary --path "$S/par$i.xcresult" --compact 2>/dev/null \
        | python3 -I -c 'import sys,json
d=json.load(sys.stdin)
print("   Ergebnis %s, gesamt %s, bestanden %s, rot %s, übersprungen %s" % (d.get("result"),d.get("totalTestCount"),d.get("passedTests"),d.get("failedTests"),d.get("skippedTests")))
for f in d.get("testFailures",[]): print("   ROT:",f.get("testName"),"-",f.get("failureText"))' | tee -a "$SUM"
    fi
  done

  # 4. Release-Warnungen
  START=$(zeit)
  xcodebuild build "${BASIS[@]}" -configuration Release -derivedDataPath "$DDREL" > "$S/release.log" 2>&1
  log "Release: Exit $?  Warnungen $(warnungen "$S/release.log") (Ziel 0)  $START–$(zeit)"

  # 5. Neue Absturzberichte
  NEU=$(find ~/Library/Logs/DiagnosticReports -name 'Disk Archive*.ips' -newer "$BEZUG" 2>/dev/null | wc -l | tr -d ' ')
  log "Neue Absturzberichte seit Start: $NEU (Ziel 0)"

  # 6. Regel 23: App des Nutzers (ohne -derivedDataPath)
  START=$(zeit)
  xcodebuild build "${BASIS[@]}" -configuration Debug > "$S/nutzerapp.log" 2>&1
  log "Nutzer-App gebaut: Exit $?  $START–$(zeit)"
  B=$(ls -dt ~/Library/Developer/Xcode/DerivedData/diskindex-*/Build/Products/Debug/"Disk Archive.app" 2>/dev/null | head -1)
  if [ -n "$B" ]; then
    BIN="$B/Contents/MacOS/Disk Archive"
    log "Regel 23: Binary $(stat -f '%Sm' -t '%H:%M:%S' "$BIN"); neuere .swift: $(find . -name '*.swift' -newer "$BIN" | wc -l | tr -d ' ') (Ziel 0)"
    codesign --verify --deep --strict "$B" 2>&1 && log "Regel 23: Signatur gültig" || log "Regel 23: Signatur FEHLT/ungültig"
    log "Version: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$B/Contents/Info.plist" 2>/dev/null)"
  else
    log "Regel 23: Nutzer-App nicht gefunden"
  fi
fi

[ "${KEEP:-0}" = "1" ] || rm -rf "$DD" "$DDREL"
log "Ende $(zeit)  (Rohlogs und .xcresult in $S)"
echo; echo "=== Zusammenfassung ($SUM) ==="; cat "$SUM"
