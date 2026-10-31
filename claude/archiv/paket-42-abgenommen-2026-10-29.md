# Paket 42 — Zielversion 0.4.1 (freigegeben 29.10.2026, abgenommen 29.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln, Sprache Deutsch). Herkunft: Sichtprüfung des DMG durch den Nutzer 29.10. (Screenshot): Auf dem Laufwerks-Icon sitzt das App-Symbol zu weit oben, nicht in der Mitte der Fläche.

Eine Aufgabe. Am Ende **HALT**.

**Ausnahmen von `todo/regeln.md` nur für dieses Paket:**
- Regel 4: Schreiben darfst du nur `Werkzeuge/dmg-erstellen.sh`.
- Regel 13: Bauen nur über das Skript.
- Keine Tests im Testziel, kein Sabotage-Patch, kein Gesamtlauf.
- **Nicht anfassen:** `Werkzeuge/dmg/` (gehört dem Host, die JSON ist schon angepasst), `Werkzeuge/pruefung.sh`, `layout/`, der venv selbst (`~/Library/Caches/disk-archive-dmg/venv`, nichts darin ändern).
- Regel 12 (Selbstprüfung) gilt weiter.

---

- **bug.0.4.1.001 — App-Symbol auf dem Laufwerks-Icon zu weit oben (Stufe 1, Nutzer sieht: Symbol klebt oben auf dem Laufwerk; Wann: jedes Mal, wenn ein Tester das DMG öffnet):**
  - **Ursache:** dmgbuild (`dmgbuild/badge.py`, Funktion `badge_disk_icon`) legt das Symbol mit festen Ecken auf `Removable.icns`: `corners = ((0.2, 0.95), (0.8, 0.95), (0.85, 0.35), (0.15, 0.35))` (Anteile, Ursprung unten links). Das passt zum alten Laufwerks-Icon, nicht zum heutigen: Die Mitte des Symbols liegt bei 34 % von oben, die Mitte der Fläche über der Leiste bei 41 %.
  - **Soll:** Das Symbol sitzt mittig auf der Fläche. Der Host hat den Wert im Scratch ausprobiert: alle vier y-Werte der Ecken um **0,07** verringern (also 0.88 und 0.28) ergibt die Mitte. Der Wert steht in `Werkzeuge/dmg/dmg-einstellungen.json` unter `volume_icon.badge_versatz_y` (positiv = nach unten).
  - **Weg (in `Werkzeuge/dmg-erstellen.sh`, Schritt 5 vor dmgbuild):**
    1. `badge.py` aus dem venv (`"$VENV"/lib/python*/site-packages/dmgbuild/badge.py`) in den Arbeitsordner unter `$TMPDIR` kopieren, z. B. als `laufwerk_badge.py`.
    2. In der Kopie genau die Zeile `corners = ((0.2, 0.95), (0.8, 0.95), (0.85, 0.35), (0.15, 0.35))` ersetzen, sodass jeder y-Wert um `badge_versatz_y` aus der JSON kleiner wird. **Vorher prüfen**, dass die Zeile genau einmal vorkommt; sonst Abbruch mit deutscher Meldung („dmgbuild hat badge.py geändert, Versatz nicht anwendbar“). Nichts im venv ändern.
    3. Mit dem venv-Python (`-I`, Arbeitsordner in `sys.path`) `badge_disk_icon(<App>/Contents/Resources/AppIcon.icns, <Arbeitsordner>/laufwerk.icns)` aufrufen. Die Quelle kommt weiter aus `volume_icon.badge_source`.
    4. In der erzeugten Einstellungsdatei statt `badge_icon = …` jetzt `icon = <Pfad zu laufwerk.icns>` setzen (dmgbuild-Einstellung `icon`).
    5. Fehlt `badge_versatz_y` in der JSON, gilt 0 (dann gleiches Bild wie bisher).
  - **So lassen:** Alles andere am Skript (Build, Version, TIFF, Prüfung in Schritt 6, Meldungen) unverändert. Keine Werte fest einbauen, die in der JSON stehen.
  - **Gegenprobe (im Status):**
    - Skript einmal laufen lassen, Schlusszeilen in den Status.
    - `.VolumeIcon.icns` aus dem DMG holen (schreibgeschützt eingehängt, `-nobrowse`, wie Schritt 6), mit `iconutil -c iconset` zerlegen und `icon_256x256@2x.png` ansehen: dunkle Fläche des Symbols etwa bei y 88–332 von 512 (Mitte ~210). Gemessene Werte in den Status.
    - Kein Finder, kein `open`, kein AppleScript.
  - **Status:** Bereit zur Prüfung. Schritt 5 in `Werkzeuge/dmg-erstellen.sh`: `badge.py` als `$WORK/laufwerk_badge.py` kopiert, die Ecken-Zeile (genau einmal geprüft, sonst Abbruch „dmgbuild hat badge.py geändert, Versatz nicht anwendbar.“) um `volume_icon.badge_versatz_y` verschoben (fehlt: 0), `badge_disk_icon` → `laufwerk.icns`, Einstellung `icon` statt `badge_icon`. Im venv nichts geändert.
    - Lauf 08:15–08:16 Exit 0: Release-Build ohne Warnungen, Version 0.4.0, Ecken ((0.2, 0.88), (0.8, 0.88), (0.85, 0.28), (0.15, 0.28)), Prüfung Schritt 6 vollständig, DMG 15 349 957 Bytes, Volume „Disk Archive 0.4.0 Beta“.
    - `.VolumeIcon.icns` (schreibgeschützt, `-nobrowse` eingehängt), `icon_256x256@2x.png`: dunkle Fläche des Symbols y 88–333 von 512, Mitte 210,5 (Leiste des Laufwerks darunter bei y 415–418 und 474–477).
    - Selbstprüfung: nichts Wesentliches gefunden. Kein Finder, kein `open`.

**Abnahme Host 29.10.:** Diff gelesen (nur `Werkzeuge/dmg-erstellen.sh`, Schritt 5; Prüfung auf genau eine Ecken-Zeile, venv unverändert, Wert aus der JSON). Skript 08:30 grün, Ecken ((0.2, 0.88), (0.8, 0.88), (0.85, 0.28), (0.15, 0.28)). `.VolumeIcon.icns` aus dem DMG: `icon_256x256@2x.png` pixelgleich mit dem Versuch des Hosts (0,07), der vorher geprüft wurde. Kein Gesamtlauf nötig (kein App-Code). Gleichzeitig vom Host: Hintergrund Variante „Dunkel“ des Layouts 29.10., Icons bei y 200, Fenster 660 × 476, Beschnitt bis 480 pt; Beschriftungen bleiben dunkel (Nutzer).
