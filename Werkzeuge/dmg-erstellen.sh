#!/bin/bash
# Erzeugt Disk-Archive-<Version>.dmg im Hauptverzeichnis des Repositorys.
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
if ! xcodebuild -project "$ROOT/diskindex/diskindex.xcodeproj" -scheme diskindex -configuration Release \
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
AUSGABE="$ROOT/$OUTNAME"

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
badge_icon = os.path.join(app, E["volume_icon"]["badge_source"])
PYEOF
mkdir -p "$(dirname "$AUSGABE")"
[ -f "$AUSGABE" ] && rm -f "$AUSGABE"   # nur genau diese Datei
DA_JSON="$JSON" DA_APP="$APP" DA_BG="$WORK/hintergrund.tiff" \
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

# 7. Meldung
schritt "7/7 Ergebnis"
GROESSE="$(du -h "$AUSGABE" | cut -f1)"
echo "DMG:         $AUSGABE"
echo "Größe:       $GROESSE ($(stat -f %z "$AUSGABE") Bytes)"
echo "Version:     $VERSION"
echo "Volume-Name: $VOLNAME"
