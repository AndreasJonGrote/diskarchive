#!/bin/bash
# Erzeugt builds/Disk-Archive-<Version>.dmg und legt die signierte Release-App daneben als
# builds/Disk Archive <Version>.app ab (todo.0.4.3.004). Ältere Fassungen in builds/ löscht es am Ende,
# es bleibt nur die letzte Version.
# Alle Werte kommen aus Werkzeuge/dmg/dmg-einstellungen.json (pflegt der Host).
# Kein Finder, kein AppleScript, kein open, kein Einhängen unter /Volumes.
set -euo pipefail

SKRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SKRIPT_DIR/.." && pwd)"
DMG_DIR="$SKRIPT_DIR/dmg"
JSON="$DMG_DIR/dmg-einstellungen.json"
CACHE="$HOME/Library/Caches/disk-archive-dmg"
VENV="$CACHE/venv"
TMP="${TMPDIR:-/tmp}"; TMP="${TMP%/}"
BUILD="$TMP/dmg-build"
WORK="$TMP/dmg-arbeit"
MOUNT="$TMP/dmg-pruefung"

fehler() { echo "FEHLER: $*" >&2; exit 1; }
schritt() { echo; echo "== $* =="; }

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
[ -f "$JSON" ] || fehler "Einstellungen fehlen: $JSON"

# JSON-Wert lesen (System-Python, nur Standardbibliothek).
jget() { /usr/bin/python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d=d[k]
print(d)' "$JSON" "$1"; }

# 1. Python-Umgebung
schritt "1/7 Python-Umgebung"
venv_anlegen() { # $1 = Python
  rm -rf "$VENV"; mkdir -p "$CACHE"
  "$1" -m venv "$VENV" && "$VENV/bin/python" -m pip install --quiet --disable-pip-version-check 'dmgbuild[badge_icons]'
}
venv_ok() { "$VENV/bin/python" -c 'import dmgbuild, objc' >/dev/null 2>&1; }
if [ -x "$VENV/bin/python" ] && venv_ok; then
  echo "Vorhandene Umgebung wird wiederverwendet: $VENV"
else
  echo "Lege Umgebung an: $VENV"
  if ! { venv_anlegen python3 && venv_ok; }; then
    echo "Python aus python3 klappt nicht, versuche /usr/bin/python3."
    venv_anlegen /usr/bin/python3 && venv_ok || fehler "dmgbuild lässt sich nicht installieren."
  fi
fi
echo "Python in der Umgebung: $("$VENV/bin/python" --version)"

# 2. Release-Build
schritt "2/7 Release-Build"
mkdir -p "$BUILD"
LOG="$BUILD/build.log"
if ! xcodebuild -project "$ROOT/DiskArchive/DiskArchive.xcodeproj" -scheme DiskArchive -configuration Release \
     -derivedDataPath "$BUILD" build > "$LOG" 2>&1; then
  grep -E "error:|warning:" "$LOG" | sort -u | head -40 || true
  fehler "Release-Build fehlgeschlagen (Protokoll: $LOG)"
fi
WARN="$(grep "warning:" "$LOG" | grep -v appintents | sort -u || true)"
if [ -n "$WARN" ]; then echo "Warnungen im Release-Build:"; echo "$WARN"; else echo "Release-Build ohne Warnungen."; fi
APP="$BUILD/Build/Products/Release/Disk Archive.app"
[ -d "$APP" ] || fehler "App nicht gefunden: $APP"

# 3. Version
schritt "3/7 Version"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[ -n "$VERSION" ] || fehler "Version nicht lesbar."
echo "Version: $VERSION"
VOLNAME="$(jget volume_name)"; VOLNAME="${VOLNAME//\{version\}/$VERSION}"
OUTNAME="$(jget output_name)"; OUTNAME="${OUTNAME//\{version\}/$VERSION}"
ABLAGE="$ROOT/builds"
AUSGABE="$ABLAGE/$OUTNAME"
APP_KOPIE="$ABLAGE/Disk Archive $VERSION.app"

# 4. Hintergrund
schritt "4/7 Hintergrund"
rm -rf "$WORK"; mkdir -p "$WORK"
BG1="$DMG_DIR/$(jget background.1x)"; BG2="$DMG_DIR/$(jget background.2x)"
[ -f "$BG1" ] && [ -f "$BG2" ] || fehler "Hintergrundbilder fehlen."
tiffutil -cathidpicheck "$BG1" "$BG2" -out "$WORK/hintergrund.tiff" >/dev/null 2>&1 \
  || fehler "tiffutil konnte das TIFF nicht erzeugen."
echo "TIFF: $WORK/hintergrund.tiff"

# 5. dmgbuild
schritt "5/7 dmgbuild"
# Laufwerks-Icon (bug.0.4.1.001): dmgbuilds badge.py als Kopie im Arbeitsordner, die Ecken des App-Symbols um
# volume_icon.badge_versatz_y nach unten (fehlt der Wert: 0). Im venv ändert sich nichts.
BADGE_PY="$(ls "$VENV"/lib/python*/site-packages/dmgbuild/badge.py 2>/dev/null | head -1 || true)"
[ -n "$BADGE_PY" ] && [ -f "$BADGE_PY" ] || fehler "badge.py von dmgbuild nicht gefunden."
cp "$BADGE_PY" "$WORK/laufwerk_badge.py"
LAUFWERK_ICNS="$WORK/laufwerk.icns"
DA_JSON="$JSON" DA_WORK="$WORK" DA_QUELLE="$APP/$(jget volume_icon.badge_source)" DA_ZIEL="$LAUFWERK_ICNS" \
  "$VENV/bin/python" -I -c 'import json, os, sys
E = json.load(open(os.environ["DA_JSON"]))
versatz = float(E["volume_icon"].get("badge_versatz_y", 0))
pfad = os.path.join(os.environ["DA_WORK"], "laufwerk_badge.py")
alt = "corners = ((0.2, 0.95), (0.8, 0.95), (0.85, 0.35), (0.15, 0.35))"
text = open(pfad).read()
if text.count(alt) != 1:
    sys.exit("dmgbuild hat badge.py geändert, Versatz nicht anwendbar.")
y = lambda wert: round(wert - versatz, 4)
neu = f"corners = ((0.2, {y(0.95)}), (0.8, {y(0.95)}), (0.85, {y(0.35)}), (0.15, {y(0.35)}))"
open(pfad, "w").write(text.replace(alt, neu))
print("Ecken des App-Symbols:", neu)
sys.path.insert(0, os.environ["DA_WORK"])
import laufwerk_badge
laufwerk_badge.badge_disk_icon(os.environ["DA_QUELLE"], os.environ["DA_ZIEL"])' \
  || fehler "Laufwerks-Icon ließ sich nicht erzeugen."
[ -f "$LAUFWERK_ICNS" ] || fehler "Laufwerks-Icon wurde nicht erzeugt."
echo "Laufwerks-Icon: $LAUFWERK_ICNS"
cat > "$WORK/einstellungen.py" <<'PYEOF'
import json, os
E = json.load(open(os.environ["DA_JSON"]))
W = E["window"]
app = os.environ["DA_APP"]
files = [app]
symlinks = {E["applications_link"]["name"]: E["applications_link"]["target"]}
hide_extensions = [E["app"]["name"]] if E["app"].get("hide_extension") else []
icon_locations = {
    E["app"]["name"]: (E["app"]["x"], E["app"]["y"]),
    E["applications_link"]["name"]: (E["applications_link"]["x"], E["applications_link"]["y"]),
}
format = E["format"]
filesystem = E["filesystem"]
window_rect = ((W["x"], W["y"]), (W["content_width"], W["content_height"]))
show_toolbar = E["show_toolbar"]
show_status_bar = E["show_status_bar"]
show_sidebar = E["show_sidebar"]
show_pathbar = E["show_pathbar"]
show_tab_view = E["show_tab_view"]
default_view = E["default_view"]
icon_size = E["icon_size"]
text_size = E["text_size"]
label_pos = E["label_pos"]
background = os.environ["DA_BG"]
icon = os.environ["DA_ICON"]
PYEOF
mkdir -p "$(dirname "$AUSGABE")"
[ -f "$AUSGABE" ] && rm -f "$AUSGABE"   # nur genau diese Datei
DA_JSON="$JSON" DA_APP="$APP" DA_BG="$WORK/hintergrund.tiff" DA_ICON="$LAUFWERK_ICNS" \
  "$VENV/bin/python" -m dmgbuild -s "$WORK/einstellungen.py" "$VOLNAME" "$AUSGABE" \
  || fehler "dmgbuild ist fehlgeschlagen."
[ -f "$AUSGABE" ] || fehler "DMG wurde nicht erzeugt."

# 6. Prüfung ohne Finder
schritt "6/7 Prüfung (schreibgeschützt eingehängt, nicht sichtbar)"
if [ -e "$MOUNT" ] && mount | grep -q " on $MOUNT "; then hdiutil detach "$MOUNT" -quiet || true; fi
rm -rf "$MOUNT"; mkdir -p "$MOUNT"
hdiutil attach "$AUSGABE" -nobrowse -readonly -noverify -noautoopen -mountpoint "$MOUNT" >/dev/null \
  || fehler "DMG lässt sich nicht einhängen."
trap 'hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || true' EXIT
ls -laO "$MOUNT"
FEHLT=()
APPNAME="$(jget app.name)"; LINKNAME="$(jget applications_link.name)"; LINKZIEL="$(jget applications_link.target)"
[ -d "$MOUNT/$APPNAME" ] || FEHLT+=("$APPNAME")
[ -L "$MOUNT/$LINKNAME" ] && [ "$(readlink "$MOUNT/$LINKNAME")" = "$LINKZIEL" ] || FEHLT+=("$LINKNAME -> $LINKZIEL")
# dmgbuild legt das Hintergrundbild als .background.tiff ab (ältere Fassungen: Ordner .background/).
[ -e "$MOUNT/.background.tiff" ] || [ -d "$MOUNT/.background" ] || FEHLT+=(".background")
[ -f "$MOUNT/.VolumeIcon.icns" ] || FEHLT+=(".VolumeIcon.icns")
[ -f "$MOUNT/.DS_Store" ] || FEHLT+=(".DS_Store")
if [ ${#FEHLT[@]} -gt 0 ]; then fehler "In der Prüfung fehlt: ${FEHLT[*]}"; fi
echo "Prüfung: App, Verweis $LINKNAME -> $LINKZIEL, Hintergrund (.background*), .VolumeIcon.icns, .DS_Store vorhanden."
hdiutil detach "$MOUNT" -quiet; trap - EXIT
rmdir "$MOUNT" 2>/dev/null || true

# 7. Ablage und Meldung
schritt "7/7 Ergebnis"
# App neben das DMG; ditto behält die Signatur.
[ -e "$APP_KOPIE" ] && rm -rf "$APP_KOPIE"   # nur genau diese App
ditto "$APP" "$APP_KOPIE" || fehler "App ließ sich nicht nach builds/ kopieren."
codesign --verify --deep --strict "$APP_KOPIE" || fehler "Signatur der App in builds/ ist ungültig."
# Nur die letzte Version bleibt.
shopt -s nullglob
for alt in "$ABLAGE"/Disk-Archive-*.dmg "$ABLAGE"/"Disk Archive "*.app; do
  [ "$alt" = "$AUSGABE" ] || [ "$alt" = "$APP_KOPIE" ] && continue
  echo "Lösche ältere Fassung: $alt"
  rm -rf "$alt"
done
shopt -u nullglob
GROESSE="$(du -h "$AUSGABE" | cut -f1)"
echo "DMG:         $AUSGABE"
echo "Größe:       $GROESSE ($(stat -f %z "$AUSGABE") Bytes)"
echo "Version:     $VERSION"
echo "Volume-Name: $VOLNAME"
echo "App:         $APP_KOPIE"
