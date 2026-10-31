# Paket 51 — Zielversion 0.4.1 (freigegeben und abgenommen 30.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). Herkunft: zweiter Durchlauf des Nutzers auf macOS 27.0.1 (30.10., Screenshots in `report-macos27/`, nicht im Git). Nutzer 30.10.: „Vor der Weitergabe“. Konzept: `konzept/darstellung.md` (App-Icon: Kachel 824/1024, Symbol 60 % der Kachel, Verlauf #575757 nach #1F1F1F, helles Symbol, **ein** Icon in Hell und Dunkel).

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Nur die betroffenen Suites per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Gesamtlauf, kein Git.

**Reihenfolge (HALT am Ende):** `bug.0.4.1.002`. **HALT.**

## Abnahme Host 30.10. (Gesamtlauf 12:51–13:21)

- Diff gelesen: `AppIcon.icon` (`icon.json`: Verlauf #575757 → #1F1F1F, 160°; Ebene `HardDrives.svg` mit dem Layout-Pfad, #F2F2F2, 614,4 pt = 60 %), `AppIcon.appiconset` entfernt, `AppIconTests`. Abweichung vom Auftrag (icns nur 16/128 pt, große Größen im `Assets.car`) begründet und im Test berücksichtigt. Nichts Wesentliches.
- Gesamtlauf: Debug und Release 0 Warnungen, seriell 1250/1250, parallel 3× grün (je 1244, 6 übersprungen), Sabotage 1/1 rot (2 von 2 Tests), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 13:21:39, Version 0.4.1.
- DMG selbst geprüft: App 0.4.1 Build 202610301247, `CFBundleIconName`/`CFBundleIconFile` AppIcon, `AppIcon.icns` und `Assets.car` vorhanden, Signatur ok; `.icns` und Laufwerks-Icon gerendert: dunkle Kachel, Motiv hell (für macOS 15 von Xcode mit leichtem Glas-Effekt gezeichnet). SHA-256 `3f602f9cb7d9106552c4f095c6f7b95340d5c8799d7372fc92e52e7366f71b42`, Quarantäne-Merkmal wieder gesetzt (Nutzer 30.10.).
- Frage des Workers (Motiv im dunklen Erscheinungsbild von macOS 26+ automatisch abgedunkelt): Sichtprüfung des Nutzers entscheidet.
- Patches: `archiv/sabotage/paket-51/`.

## Aufgaben

- **bug.0.4.1.002 — App-Symbol auf macOS 26/27 verkleinert auf heller Platte:**
  - **Nutzer sieht:** Auf macOS 27 sitzt das dunkle Symbol im DMG-Fenster, im Dock, in „Programme“ und in den Systemeinstellungen (Mitteilungen) verkleinert auf einer hellgrauen Fläche. Auf macOS 15 sieht es richtig aus.
  - **Wann:** Immer auf macOS 26 und neuer. **Stufe 1** (falsche Anzeige).
  - **Ursache:** `diskindex/Assets.xcassets/AppIcon.appiconset` enthält nur PNGs im alten Raster (dunkle Kachel 824/1024 mit transparentem Rand). macOS ab 26 setzt Symbole, die nicht aus einer Icon-Composer-Datei stammen, auf eine eigene Platte.
  - **Soll:**
    1. Neue Icon-Composer-Datei `diskindex/diskindex/AppIcon.icon` (Ordner mit `icon.json` und `Assets/`, Format von Xcode 26 / Icon Composer; von Hand oder mit Icon Composer erstellt).
       - **Hintergrund (Fill):** linearer Verlauf **#575757** oben links nach **#1F1F1F** unten rechts (Layout: `linear-gradient(160deg, #575757, #1f1f1f)`), füllt die ganze Fläche; die Ecken setzt macOS.
       - **Ebene:** das Motiv aus dem Layout als SVG, **Füllung #F2F2F2**, mittig, Breite **60 %** der Fläche (Konzept). Pfad (Phosphor „HardDrives“, viewBox 0 0 256 256), wörtlich aus `layout/bis 0.4.1/Disk Index App.dc.html` Abschnitt „App-Icon“:
         `M208,136H48a16,16,0,0,0-16,16v48a16,16,0,0,0,16,16H208a16,16,0,0,0,16-16V152A16,16,0,0,0,208,136Zm0,64H48V152H208v48Zm0-160H48A16,16,0,0,0,32,56v48a16,16,0,0,0,16,16H208a16,16,0,0,0,16-16V56A16,16,0,0,0,208,40Zm0,64H48V56H208v48ZM192,80a12,12,0,1,1-12-12A12,12,0,0,1,192,80Zm0,96a12,12,0,1,1-12-12A12,12,0,0,1,192,176Z`
       - **Wirkung:** keine zusätzlichen Effekte über die Standardwerte von Icon Composer hinaus; **Dunkel = Standard** (kein eigenes Motiv für das dunkle Erscheinungsbild, Konzept „ein Icon in Hell und Dunkel“).
    2. `AppIcon.icon` gehört zum App-Ziel; `AppIcon.appiconset` aus `Assets.xcassets` entfernen (sonst zwei Quellen mit gleichem Namen). `ASSETCATALOG_COMPILER_APPICON_NAME` bleibt `AppIcon`. `DockIcon.imageset` und `MenuBarHardDrives` bleiben.
    3. Die gebaute App enthält weiter **`Contents/Resources/AppIcon.icns`** (Bild für macOS 15 und Quelle des DMG-Laufwerks-Icons, `Werkzeuge/dmg/dmg-einstellungen.json` → `volume_icon.badge_source`) und `CFBundleIconName = AppIcon`. Fehlt die `.icns`, **nicht** das DMG-Skript ändern, sondern im Status melden (Frage an den Host).
  - **Gegenprobe (Test, Regel 10/11):** Test liest das gebaute Bundle: `CFBundleIconName == "AppIcon"`, `AppIcon.icns` vorhanden und enthält eine Größe ≥ 512 pt; die Pixelfarbe in der Mitte oben der 512er-Darstellung (Hintergrund, nicht Motiv) ist dunkel (Helligkeit < 0,45) – auf macOS 15 läuft der Test hier. Dazu Quelltext-Prüfung: `AppIcon.icon/icon.json` vorhanden, Ziel enthält sie, `AppIcon.appiconset` existiert nicht mehr.
  - **Patch (rot erwartet):** `bug.0.4.1.002-a.patch`: `AppIcon.icon` aus dem Ziel nehmen und `AppIcon.appiconset` zurück → Test rot.
  - **Danach:** `Werkzeuge/dmg-erstellen.sh` neu ausführen (Version bleibt **0.4.1**, neues Build). Im Status: Name, Größe, SHA-256 des neuen `Disk-Archive-0.4.1.dmg`, Build-Nummer der App darin. **Das alte DMG wird damit ersetzt.**
  - **Sichtprüfung** macht der Nutzer auf macOS 27 (Dock, DMG-Fenster, Programme) und auf macOS 15; nicht per Agent.
  - **So lassen:** Menüleisten-Symbol, Symbole in der App, DMG-Hintergrund und `Werkzeuge/dmg/`, Version, Signatur.
  - **Status:** Bereit zur Prüfung (Worker 30.10.).
    - Neu `diskindex/diskindex/AppIcon.icon` (`icon.json`: Verlauf #575757 → #1F1F1F, Richtung 160°; Ebene `Assets/HardDrives.svg`, viewBox eng um den Pfad, 614,4 pt = 60 % von 1024, #F2F2F2, sonst Standardwerte, kein Dunkel-Motiv); liegt im synchronisierten App-Ordner, keine Ausnahme. `AppIcon.appiconset` entfernt, `DockIcon` (im Code unbenutzt) und `MenuBarHardDrives` bleiben.
    - Abweichung Test: `actool` legt in `AppIcon.icns` nur 16 und 128 pt ab (beim alten appiconset genauso), die großen Größen stehen im `Assets.car`. `AppIconTests` prüft daher: `CFBundleIconName` AppIcon, icns ≥ 128 pt, `NSImage(named: "AppIcon")` ≥ 512 pt, Pixel (256, 92) der 512er-Darstellung deckend und Helligkeit < 0,45; dazu Quelle (`icon.json` da, appiconset weg, keine Ausnahme im Ziel). Rot 12:41 (3 Fehler), grün 12:44; mit Bundle/About/EnglishLocalization 12:46: 4 Suites, 14 Tests, Build 0 Warnungen.
    - Patch `bug.0.4.1.002-a` (Ausnahme für `AppIcon.icon` im Ziel + appiconset nur mit `Contents.json`, `patch` kann keine PNGs): rot 2/2, 0 Mängel (12:44–12:45).
    - `dmg-erstellen.sh` 12:47: `Disk-Archive-0.4.1.dmg` ersetzt, 16 972 215 Bytes, SHA-256 `3f602f9c…6f71b42`, Release ohne Warnungen; App darin 0.4.1 Build 202610301247, `AppIcon.icns` vorhanden, `Assets.car` mit Ebenen (Gradient, HardDrives). Frage: `ictool` (Rendition Dark) zeigt, dass macOS 26+ im Erscheinungsbild Dunkel das Motiv automatisch abdunkelt (grau statt #F2F2F2); laut Auftrag so gelassen.
