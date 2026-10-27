#!/bin/bash
# Werkzeuge/pruefung.sh — Prüfläufe des Hosts (archiv/abnahme-ablauf.md, Abschnitt 3).
# Pflege nur durch den Host (AGENTS.md). Der Worker ändert diese Datei nicht.
#
# Aufruf (aus beliebigem Ordner):
#   Werkzeuge/pruefung.sh voll                      Paketende: Build, seriell, 3x parallel, Release, .ips, App des Nutzers (Regel 14)
#   Werkzeuge/pruefung.sh schnell [Suite ...]       Build + Warnungen + gezielte Suites (nur Lesen, keine Nutzer-App)
#   Werkzeuge/pruefung.sh sabotage                  nur die Sabotage-Patches aus todo/sabotage/ (Regel 9), je Patch rot erwartet
#   (voll prüft die Patches am Ende mit, wenn welche da sind)
# Umgebung (alles optional):
#   S=<Ordner>   Scratch-Ordner (Standard: neuer Ordner pruefung.XXXXXX unter ${TMPDIR:-/tmp}); muss unter $TMPDIR
#                liegen – nie im Repository, nie im Scratch einer Sitzung (sonst Abbruch)
#   KEEP=1       DerivedData und alle .xcresult behalten
# Platz (Host 26.10., Platte lief mit 167 GB Testresten voll): beim Start Abbruch unter 25 GB frei; ältere
#   pruefung.*-Ordner unter $TMPDIR bis auf die zwei neuesten (und laufende) werden gelöscht; .xcresult grüner Läufe
#   und erwartungsgemäß roter Sabotage-Läufe werden sofort gelöscht, nur die zur Fehlersuche nötigen bleiben.
# Ausgabe: eine Zusammenfassung ($S/zusammenfassung.txt, am Ende auch auf stdout), Rohlogs bleiben in $S.
# Kein Git, keine Eingriffe außerhalb von $TMPDIR/pruefung.* und dem DerivedData der Nutzer-App (Regel 14).

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

TMPBASE="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
MINFREI_GB=25
FREI_GB=$(( $(df -k "$TMPBASE" | awk 'NR==2 {print $4}') / 1024 / 1024 ))
if [ "$FREI_GB" -lt "$MINFREI_GB" ]; then
  echo "Abbruch: zu wenig Platz ($FREI_GB GB frei unter $TMPBASE, mindestens $MINFREI_GB GB) – erst aufräumen, sonst falsche Rote."
  exit 3
fi
# Alte Läufe: alle pruefung.* bis auf die zwei neuesten löschen, laufende (PID in .laeuft lebt) nie.
ALT=0
while IFS= read -r d; do
  [ -n "$d" ] || continue
  ALT=$((ALT+1)); [ "$ALT" -le 2 ] && continue
  pid=$(cat "$d/.laeuft" 2>/dev/null)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then continue; fi
  rm -rf "$d"
done < <(ls -dt "$TMPBASE"/pruefung.* 2>/dev/null)

if [ -n "${S:-}" ]; then
  # Erst prüfen, dann anlegen (macOS: /var ist /private/var).
  case "$S" in /var/*|/tmp/*) S="/private$S" ;; esac
  case "$S/" in
    "$TMPBASE"/*) ;;
    *) echo "Abbruch: S=$S liegt nicht unter \$TMPDIR ($TMPBASE) – Voreinstellung nutzen (S weglassen)."; exit 2 ;;
  esac
  mkdir -p "$S" || exit 2
else
  S="$(mktemp -d "$TMPBASE/pruefung.XXXXXX")"
fi
echo $$ > "$S/.laeuft"
DD="$S/dd"; DDREL="$S/dd-rel"; SUM="$S/zusammenfassung.txt"
DEST='platform=macOS,arch=arm64'
BASIS=(-project diskindex.xcodeproj -scheme diskindex -destination "$DEST")
TESTOPT=(-only-testing:diskindexTests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120)
: > "$SUM"

zeit() { date '+%H:%M:%S'; }
log()  { echo "$*" | tee -a "$SUM"; }
warnungen() { grep "warning:" "$1" | grep -v appintents | sort -u | wc -l | tr -d ' '; }
# „gruen“ nur bei result == Passed und 0 roten Tests; sonst anderes Wort oder leer (nicht lesbar).
ergebnis() {
  xcrun xcresulttool get test-results summary --path "$1" --compact 2>/dev/null \
    | python3 -I -c 'import sys,json; d=json.load(sys.stdin); print("gruen" if d.get("result")=="Passed" and d.get("failedTests",0)==0 else "rot")' 2>/dev/null
}
# .xcresult eines grünen Laufs löschen (je ~140 MB); rote, abgestürzte (Exit ≠ 0 ohne gezählten roten Test) und nicht
# lesbare bleiben zur Fehlersuche (Host 26.10.: nur bei result == Passed löschen). Zweites Argument: Exit-Code von
# xcodebuild – bei Exit ≠ 0 bleibt das Ergebnis auch bei „Passed“ (Paket 31: Klone im Parallelmodus fehlen darin).
gruen_weg() {
  [ "${KEEP:-0}" = "1" ] && return
  [ -d "$1" ] || return
  if [ -n "${2:-}" ] && [ "$2" != "0" ]; then
    [ "$(ergebnis "$1")" = "gruen" ] && log "   ACHTUNG: Exit $2, aber Ergebnis „Passed“ – rote Tests im Log suchen (grep 'failed' $(basename "${1%.xcresult}").log)"
    return
  fi
  [ "$(ergebnis "$1")" = "gruen" ] && rm -rf "$1"
}
# Sabotage (Regel 9): jeder Patch in einer Kopie des Projekts, die in "# Test:" genannten Tests müssen rot werden.
sabotage() {
  shopt -s nullglob
  local P=("$ROOT"/todo/sabotage/*.patch)
  shopt -u nullglob
  if [ "${#P[@]}" -eq 0 ]; then log "Sabotage: keine Patches in todo/sabotage/"; return; fi
  local K="$S/sab-kopie" DDS="$S/dd-sab" ok=0 bad=0
  rm -rf "$K"; mkdir -p "$K"; rsync -a "$ROOT/diskindex" "$K/"
  for p in "${P[@]}"; do
    local name; name=$(basename "$p" .patch)
    # Mehrere Tests: je Zeile einer oder in einer Zeile mit Komma getrennt (Paket 36).
    local tests; tests=$(grep -E '^# Test:' "$p" | sed -E 's/^# Test:[[:space:]]*//' | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    if [ -z "$tests" ]; then log "Sabotage $name: FEHLT # Test:-Zeile"; bad=$((bad+1)); continue; fi
    if ! (cd "$K" && patch -p1 --forward --silent < "$p") > "$S/sab-$name-patch.log" 2>&1; then
      log "Sabotage $name: Patch passt nicht auf den Endstand"; bad=$((bad+1))
      rm -rf "$K"; mkdir -p "$K"; rsync -a "$ROOT/diskindex" "$K/"; continue
    fi
    local ARGS=() t
    while IFS= read -r t; do [ -n "$t" ] && ARGS+=("-only-testing:diskindexTests/$t"); done <<< "$tests"
    local START; START=$(zeit)
    (cd "$K/diskindex" && xcodebuild build-for-testing "${BASIS[@]}" -derivedDataPath "$DDS") > "$S/sab-$name-build.log" 2>&1
    if [ $? -ne 0 ]; then
      log "Sabotage $name: Build mit Patch scheitert (Patch ungültig)  $START–$(zeit)"; bad=$((bad+1))
    else
      rm -rf "$S/sab-$name.xcresult"
      (cd "$K/diskindex" && xcodebuild test-without-building "${BASIS[@]}" -derivedDataPath "$DDS" "${ARGS[@]}" \
        -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 \
        -resultBundlePath "$S/sab-$name.xcresult") > "$S/sab-$name-test.log" 2>&1
      local rot; rot=$(xcrun xcresulttool get test-results summary --path "$S/sab-$name.xcresult" --compact 2>/dev/null \
        | python3 -I -c 'import sys,json; d=json.load(sys.stdin); print("%s %s" % (d.get("failedTests",0), d.get("totalTestCount",0)))' 2>/dev/null)
      local f=${rot%% *} n=${rot##* }
      if [ -n "$rot" ] && [ "${n:-0}" -gt 0 ] && [ "${f:-0}" -gt 0 ]; then
        log "Sabotage $name: rot ✓ ($f von $n)  $START–$(zeit)"; ok=$((ok+1))
        # Erwartetes Rot: das Ergebnis wird nicht mehr gebraucht (Log bleibt).
        [ "${KEEP:-0}" = "1" ] || rm -rf "$S/sab-$name.xcresult"
      elif [ "${n:-0}" -eq 0 ]; then
        log "Sabotage $name: kein Test gefunden ($tests)  $START–$(zeit)"; bad=$((bad+1))
      else
        log "Sabotage $name: GRÜN ✗ – Test beweist den Fix nicht ($tests)  $START–$(zeit)"; bad=$((bad+1))
      fi
    fi
    (cd "$K" && patch -p1 -R --silent < "$p") > /dev/null 2>&1 || { rm -rf "$K"; mkdir -p "$K"; rsync -a "$ROOT/diskindex" "$K/"; }
  done
  log "Sabotage gesamt: rot ✓ $ok, Mängel $bad (Ziel 0)"
  [ "${KEEP:-0}" = "1" ] || rm -rf "$K" "$DDS"
}
testzeile() { grep -E "Test run with|Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)" "$1" | tail -2 | tr '\n' ' '; }

log "Prüfung $MODUS  Start $(zeit)  Scratch $S"
log "Rechner: $(sw_vers -productVersion), $(xcodebuild -version 2>/dev/null | head -1)"
BEZUG="$S/bezug"; touch "$BEZUG"

if [ "$MODUS" = "sabotage" ]; then
  sabotage
  rm -f "$S/.laeuft"
  log "Ende $(zeit)  (Rohlogs in $S; frei $(df -h "$TMPBASE" | awk 'NR==2 {print $4}'))"; echo; echo "=== Zusammenfassung ($SUM) ==="; cat "$SUM"; exit 0
fi

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
  RC=$?
  log "Gezielt (${SUITES[*]:-alle}): Exit $RC  $(testzeile "$S/schnell.log")  $START–$(zeit)"
  gruen_weg "$S/schnell.xcresult" "$RC"
else
  # 2. Seriell
  START=$(zeit)
  xcodebuild test-without-building "${BASIS[@]}" -derivedDataPath "$DD" "${TESTOPT[@]}" \
    -parallel-testing-enabled NO -resultBundlePath "$S/seriell.xcresult" > "$S/seriell.log" 2>&1
  RC=$?
  log "Seriell: Exit $RC  $(testzeile "$S/seriell.log")  $START–$(zeit)"
  gruen_weg "$S/seriell.xcresult" "$RC"

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
      gruen_weg "$S/par$i.xcresult" "$RC"
    fi
  done

  # 4. Release-Warnungen
  START=$(zeit)
  xcodebuild build "${BASIS[@]}" -configuration Release -derivedDataPath "$DDREL" > "$S/release.log" 2>&1
  log "Release: Exit $?  Warnungen $(warnungen "$S/release.log") (Ziel 0)  $START–$(zeit)"

  # 5. Neue Absturzberichte
  NEU=$(find ~/Library/Logs/DiagnosticReports -name 'Disk Archive*.ips' -newer "$BEZUG" 2>/dev/null | wc -l | tr -d ' ')
  log "Neue Absturzberichte seit Start: $NEU (Ziel 0)"

  # 5a. Ein Ordner (bug.0.4.208): Tests schreiben nichts nach ~/Library/Preferences. Nur app.diskarchive.plist
  # (Sprache, Fensterposition – schreibt macOS bzw. die echte App) darf sich ändern.
  PREFS=$(find ~/Library/Preferences -maxdepth 1 -newer "$BEZUG" \( -name 'app.diskarchive*' -o -name '*diskindex*' \) \
    ! -name 'app.diskarchive.plist' 2>/dev/null)
  log "Neue Dateien in ~/Library/Preferences seit Start: $(printf '%s' "$PREFS" | grep -c . | tr -d ' ') (Ziel 0)"
  [ -n "$PREFS" ] && printf '%s\n' "$PREFS" | head -5 | sed 's/^/   /' | tee -a "$SUM"

  # 5b. Sabotage-Patches (Regel 9)
  sabotage

  # 6. Regel 14: App des Nutzers (ohne -derivedDataPath)
  START=$(zeit)
  xcodebuild build "${BASIS[@]}" -configuration Debug > "$S/nutzerapp.log" 2>&1
  log "Nutzer-App gebaut: Exit $?  $START–$(zeit)"
  B=$(ls -dt ~/Library/Developer/Xcode/DerivedData/diskindex-*/Build/Products/Debug/"Disk Archive.app" 2>/dev/null | head -1)
  if [ -n "$B" ]; then
    BIN="$B/Contents/MacOS/Disk Archive"
    log "App des Nutzers: Binary $(stat -f '%Sm' -t '%H:%M:%S' "$BIN"); neuere .swift: $(find . -name '*.swift' -newer "$BIN" | wc -l | tr -d ' ') (Ziel 0)"
    codesign --verify --deep --strict "$B" 2>&1 && log "App des Nutzers: Signatur gültig" || log "App des Nutzers: Signatur FEHLT/ungültig"
    log "Version: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$B/Contents/Info.plist" 2>/dev/null)"
  else
    log "App des Nutzers: Nutzer-App nicht gefunden"
  fi
fi

[ "${KEEP:-0}" = "1" ] || rm -rf "$DD" "$DDREL"
rm -f "$S/.laeuft"
BLEIBT=$(ls -d "$S"/*.xcresult 2>/dev/null | wc -l | tr -d ' ')
log "Ende $(zeit)  (Rohlogs in $S; behaltene .xcresult: $BLEIBT; Ordnergröße $(du -sh "$S" 2>/dev/null | cut -f1); frei $(df -h "$TMPBASE" | awk 'NR==2 {print $4}'))"
echo; echo "=== Zusammenfassung ($SUM) ==="; cat "$SUM"
