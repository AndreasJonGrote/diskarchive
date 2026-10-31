# Paket 41 — Zielversion 0.4.1, vorgezogen (freigegeben 28.10.2026, abgenommen 28.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln, Sprache Deutsch). Herkunft: Nutzer 28.10. (über Supervisor): DMG für die Open Beta jetzt vorbereiten, dazu Mindest-macOS 15 (Nutzer 27.10.). Die **Version bleibt 0.4.0**, bis der Nutzer 0.4.0 als Release-Kandidat bestätigt. Erst dann setzt der Host 0.4.1 und baut das DMG für die Tester.

Reihenfolge: erst `todo.0.4.1.003`, dann `todo.0.4.1.001`. Am Ende **HALT**.

**Ausnahmen von `todo/regeln.md` nur für dieses Paket:**
- Regel 4: Schreiben darfst du zusätzlich `Werkzeuge/dmg-erstellen.sh` (neu) und die eine Zeile `*.dmg` in `.gitignore`.
- Regel 13: Den Release-Build machst du nur über das Skript.
- `todo.0.4.1.001`: keine Tests im Testziel, kein Sabotage-Patch. `todo.0.4.1.003` ändert kein Verhalten, daher auch dort kein Patch.
- **Nicht anfassen:** `Werkzeuge/dmg/` (Bild und Einstellungen gehören dem Host), `Werkzeuge/pruefung.sh`, `layout/` (vor allem `layout/ab 0.4.2/`).
- Regel 12 (Selbstprüfung) gilt weiter.

---

- **todo.0.4.1.003 — Mindest-macOS 15 (Nutzer 27.10.):**
  - **Soll:** Die App verlangt macOS 15.0. Der Rechner des Nutzers läuft mit 15.7.4; Tester mit macOS 14 sind nicht vorgesehen.
  - **Weg:**
    1. `diskindex/diskindex.xcodeproj/project.pbxproj`: `MACOSX_DEPLOYMENT_TARGET = 14.0;` → `15.0;` an allen **4** Stellen (heute Z. 314, 372, 466, 487).
    2. `diskindex/DesignSystem/PointerCursor.swift`: die beiden `if #available(macOS 15, *) { … } else { content }` (Z. 27 und 56) durch den Zweig für macOS 15 ersetzen, also `content.pointerStyle(active ? .link : nil)` bzw. `content.pointerStyle(.columnResize)`. Der Doc-Kommentar Z. 15 verliert „sonst `resizeLeftRight`“.
  - **So lassen:** `.onHover` mit `NSCursor.….set()` und `.onDisappear` in beiden Modifiern bleiben unverändert (kein Umbau ohne sichtbaren Grund). `SizeKey` in `HardDrivesTemplateIcon.swift` bleibt. Sonst nichts an Verfügbarkeitsprüfungen ändern.
  - **Gegenprobe:** Debug mit Testziel 0 Warnungen; betroffene Suites zu Zeiger und Spaltenbreite grün. In der gebauten Debug-App: `LSMinimumSystemVersion` = 15.0 (`PlistBuddy`, im Status).
  - **Status:** Bereit zur Prüfung. `MACOSX_DEPLOYMENT_TARGET` 4× auf 15.0; `PointerCursor.swift`: beide `#available` samt `Group` entfernt, Doc-Kommentar angepasst, `.onHover`/`.onDisappear` unverändert.
    Debug+Testziel (17:23:40–17:24:31, DerivedData `$TMPDIR/worker-dd`): 0 Warnungen; gebaute Debug-App `LSMinimumSystemVersion` = 15.0 (PlistBuddy). Suites `ColumnDividerTests` und `ColumnWidthPerColumnTests` (stecken in `WindowTestGroup`): 4 Tests grün (17:25:27).
    Selbstprüfung nach Regel 12 lesend durch mich (kein Subagent): reine Entfernung toter Zweige, kein Zeitfenster, kein Löschen, keine fremden Ereignisse, keine Reste; kein Patch (Ausnahme im Paket).

- **todo.0.4.1.001 — DMG mit einem Befehl (Nutzer 18.10., vorgezogen 28.10.):**
  - **Soll:** Auf den Auftrag „Erstelle nun das Ausgabe-DMG“ startet ein Agent nur `Werkzeuge/dmg-erstellen.sh`, sonst nichts. Das Skript erzeugt `Disk-Archive-<Version>.dmg` im Git-Hauptverzeichnis: Laufwerk mit App, Verweis „Programme“ auf `/Applications`, Hintergrundbild (Retina-scharf) und Laufwerks-Icon mit dem App-Icon darauf.
  - **Eingaben (vom Host, nur lesen):**
    - `Werkzeuge/dmg/dmg-einstellungen.json`: Volume-Name, Ausgabename, Format, Dateisystem, Fenster, Leisten, Ansicht, Icon- und Schriftgröße, Positionen, Namen, Quelle des Volume-Icons. `{version}` im Text ersetzt das Skript durch die Version der App. Koordinaten sind Icon-Mittelpunkte in pt, wie dmgbuild `icon_locations`.
    - `Werkzeuge/dmg/hintergrund.png` (660 × 400) und `hintergrund@2x.png` (1320 × 800).
    - **Keine Werte im Skript fest einbauen**, die in der JSON stehen. Passt etwas nicht (z. B. zählt dmgbuild die Titelleiste in die Fenstergröße), nicht im Skript ausgleichen, sondern im Status melden; der Host ändert die JSON.
  - **Ablauf des Skripts** (`set -euo pipefail`, Meldungen deutsch, läuft aus jedem Arbeitsverzeichnis; ermittelt das Hauptverzeichnis aus dem eigenen Pfad):
    1. **Python-Umgebung:** `~/Library/Caches/disk-archive-dmg/venv`. Fehlt sie, legt das Skript sie an (`python3 -m venv`) und installiert dort `dmgbuild[badge_icons]`. Nie mit `pip` ins Homebrew-Python (dort gesperrt) und nie `--break-system-packages`. Läuft dmgbuild mit dem Homebrew-Python (3.14) nicht, `/usr/bin/python3` nehmen und das im Status nennen.
    2. **Release-Build:** `xcodebuild -project diskindex/diskindex.xcodeproj -scheme diskindex -configuration Release -derivedDataPath "$TMPDIR/dmg-build" build`. Fester Ordner, wird wiederverwendet. Kein Suchen in DerivedData. Ausgabe gekürzt (Fehler und Warnungen zeigen), bei Fehler Abbruch.
    3. **Version** aus `CFBundleShortVersionString` der eben gebauten `Disk Archive.app`.
    4. **Hintergrund:** beide PNGs zu einem TIFF mit zwei Auflösungen (`tiffutil -cathidpicheck`) in einem Arbeitsordner unter `$TMPDIR`, außer dmgbuild macht das nachweislich selbst.
    5. **dmgbuild** mit einer erzeugten Einstellungsdatei (unter `$TMPDIR`) oder `-D`-Werten, alles aus der JSON:
       - `volume_name`, `format`, `filesystem`; Größe berechnet dmgbuild selbst.
       - `files` = die gebaute App; `symlinks` = {„Programme“: „/Applications“}; `hide_extensions` = [„Disk Archive.app“]; `icon_locations` aus `app` und `applications_link`.
       - `window_rect` = ((x, y), (content_width, content_height)); `show_toolbar`, `show_status_bar`, `show_sidebar`, `show_pathbar`, `show_tab_view`; `default_view`; `icon_size`; `text_size`; `label_pos`; `background` = das TIFF.
       - `badge_icon` = `Contents/Resources/AppIcon.icns` der eben gebauten App (Laufwerks-Icon von macOS mit dem App-Icon darauf).
    6. **Ausgabe:** `Disk-Archive-<Version>.dmg` im Hauptverzeichnis. Eine vorhandene Datei derselben Version wird ersetzt (nur genau diese Datei löschen).
    7. **Prüfung ohne Finder:** `hdiutil attach -nobrowse -readonly -mountpoint "$TMPDIR/dmg-pruefung"`. Dann auflisten und prüfen: `Disk Archive.app`, `Programme` ist ein Verweis auf `/Applications`, Hintergrund (`.background/…`), `.VolumeIcon.icns`, `.DS_Store`. Danach `hdiutil detach`. Fehlt etwas → Abbruch mit Meldung.
    8. **Meldung:** Pfad und Größe des DMG, Version, Volume-Name.
  - **Nie:** Finder, AppleScript/`osascript`, `open`, Einhängen unter `/Volumes`. dmgbuild schreibt die Fenster-Einstellungen selbst. Kein automatischer Lauf nach jedem Build.
  - **`.gitignore`:** eine Zeile `*.dmg`.
  - **Gegenprobe (im Status):**
    1. Erster Lauf ohne venv (`~/Library/Caches/disk-archive-dmg/` vorher löschen): DMG entsteht, Prüfliste vollständig.
    2. Zweiter Lauf direkt danach: venv wird wiederverwendet, das DMG ersetzt das erste (Zeitstempel).
    3. Release-Build im Skript ohne Warnungen.
    4. Ausgabe von Schritt 7 und die Größe des DMG in den Status.
  - **Version:** Nicht ändern. Das DMG heißt jetzt `Disk-Archive-0.4.0.dmg`; 0.4.1 setzt der Host später.
  - **Status:** Bereit zur Prüfung. `Werkzeuge/dmg-erstellen.sh` neu (alle Werte aus der JSON, venv mit System-`python3` 3.14 reichte, kein Rückgriff auf `/usr/bin/python3`), `*.dmg` in `.gitignore`. Lauf 1 ohne venv 17:27:37–17:27:49, Lauf 2 mit venv 17:27:54–17:28:06; Zeitstempel/Größe: 17:27:49 15422173 Bytes → 17:28:06 15422196 Bytes (ersetzt). Release-Build 0 Warnungen. `Disk-Archive-0.4.0.dmg` im Hauptverzeichnis (15 MB), Volume „Disk Archive 0.4.0 Beta“.
    Prüfliste Schritt 7 (Auszug): `.DS_Store`, `.VolumeIcon.icns`, `.background.tiff`, `Disk Archive.app`, `Programme -> /Applications`; alles vorhanden. Abweichung: dmgbuild legt das Bild als `.background.tiff` ab (nicht `.background/…`), das Skript akzeptiert beides.
    Hinweis für den Host (JSON): dmgbuild schreibt `window_rect` unverändert als Fenstergröße; die Titelleiste (ca. 28 pt) zählt vermutlich dazu, sichtbarer Inhalt dann 660 × ca. 372. Im Skript nicht ausgeglichen, Sichtprüfung beim Nutzer nötig (ich habe nichts geöffnet).
    Selbstprüfung Regel 12 (lesend, ohne Subagent): Teilarbeit nur in `$TMPDIR`, gelöscht wird nur die DMG derselben Version; Einhängen `-nobrowse -readonly` unter `$TMPDIR`, Trap trennt bei Abbruch; kein Fund.

---

## Abnahme (Host, dann Nutzer)

- **Host:** Diff lesen; `dmg-erstellen.sh` zweimal hintereinander, einmal ohne venv; beide Male entsteht das DMG, beim zweiten Mal ersetzt es das erste; Prüfliste vollständig; `pruefung.sh voll` (Debug und Release 0 Warnungen), nur bei Last < 3.
- **Nutzer** (DMG per Doppelklick, hell und dunkel):
  - Das ganze Bild ist zu sehen, ohne Rollbalken und grauen Rand, auf Retina scharf.
  - App-Icon mittig in den Ringen, Pfeil zwischen den Icons (sonst passt der Host `y` in der JSON an; die Seite nennt 250, eingetragen ist 234).
  - „Disk Archive“ und „Programme“ lesbar, berühren die Hinweiszeile nicht. Der Finder färbt die Namen selbst: im hellen Modus prüfen, ob schwarze Schrift auf dem dunklen Bild lesbar ist; sonst Frage an den Nutzer.
  - Schreibtisch und Informationen (⌘I) zeigen das Laufwerk mit dem App-Icon.
  - DMG bei laufender App öffnen: kein Erkennungsdialog.
  - Kein Befund: Die `.dmg`-Datei selbst hat nach einem Download das weiße Standard-Icon (ein Download überträgt kein Datei-Icon).
- **Danach** (erst nach Bestätigung des Release-Kandidaten 0.4.0): Version 0.4.1, DMG bauen, Download- und Aufwärtstest auf macOS 27 (`todo.0.4.1.002`, Backlog).

**Prüfung Host 28.10. 17:29:** Diff gelesen (pbxproj 4×, `PointerCursor.swift` nur die toten Zweige, `.gitignore`, Skript liest alle Werte aus der JSON). `dmg-erstellen.sh` zweimal: 17:29:05 ohne venv (neu angelegt, Python 3.14) und 17:29:18 mit venv; beide grün, das zweite DMG ersetzt das erste; Release-Build ohne Warnungen. Im DMG: `LSMinimumSystemVersion` 15.0, `.background.tiff` mit 660 × 400 und 1320 × 800, `WindowBounds {{200, 120}, {660, 400}}`, Icons bei (170, 234) und (490, 234), alle Leisten aus. Offen: Sichtprüfung des Nutzers (zählt der Finder die Titelleiste in die 400, wird `content_height` in der JSON 428), Gesamtlauf bei Last < 3 (17:29 Last 5,7).

**Beschnitt (Nutzer 28.10.):** Bild unten um 40 pt verlängert (660 × 440 bzw. 1320 × 880, unterste Zeile fortgesetzt, keine Kante), Fenster in der JSON auf 428 hoch. Zählt der Finder die Titelleiste mit, sieht man genau die 400 pt der Layout-Seite, sonst 28 pt Beschnitt, nie einen grauen Rand. DMG neu gebaut 28.10. (`WindowBounds {{200, 120}, {660, 428}}`, TIFF 660 × 440 und 1320 × 880). Beim nächsten Export aus der Layout-Seite den Beschnitt wieder anfügen (Python/PIL, unterste Zeile bis 440 bzw. 880 wiederholen).

**Prüfpunkt vor der Weitergabe (Supervisor 28.10.):** Die App im DMG ist mit „Apple Development“ signiert und trägt `get-task-allow`, eine Developer ID gibt es nicht. Ob „Dennoch öffnen“ damit auf einem fremden Mac klappt, zeigt erst `todo.0.4.1.002` auf macOS 27 (Backlog). Vorher geht das DMG an keinen Tester.

## Abnahme Host 28.10. (Gesamtlauf 19:53–20:22)

`Werkzeuge/pruefung.sh voll`: Debug mit Testziel und Release 0 Warnungen, seriell 1216/1216, Parallel 1–3 grün (je 1210, 6 übersprungen), keine neuen `.ips`, 0 neue Dateien in `~/Library/Preferences`, keine Sabotage-Patches (Ausnahme im Paket), App des Nutzers 20:22:34, Signatur gültig, Version 0.4.0. Supervisor 28.10.: Paket 41 und DMG nachgeprüft, nichts Wesentliches. Umgesetzt hat ein Worker-Agent (Sonnet) im Chat des Hosts, weil der Worker nicht erreichbar war. Offen: Sichtprüfung des DMG durch den Nutzer; Signatur-Prüfpunkt bei `todo.0.4.1.002`.
