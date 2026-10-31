# Paket 36 — Zielversion 0.4.0 (freigegeben 27.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Funde der Abnahmerunde, ausführlich (Ursachen, Zeilen): [todo/funde-abnahmerunde-0.4.0.md](funde-abnahmerunde-0.4.0.md). Maße: [docs/Komponenten-Masse.md](../docs/Komponenten-Masse.md), bei Widerspruch gilt [layout/Komponenten.dc.html](../../layout/Komponenten.dc.html). Layout-Durchgang des Nutzers abgeschlossen 27.10.: keine weiteren Funde. Mit diesem Paket sind alle Funde der Abnahmerunde abgearbeitet.

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün. Messtests ±0,5 pt (Regel 7), **hell und dunkel**.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3). Native Controls, keine HTML-Werte abtippen, aber gleiche Maße.

**Reihenfolge (HALT am Ende):** `bug.0.4.211`, `bug.0.4.218`, `bug.0.4.219`, `bug.0.4.220`, `bug.0.4.217`. **HALT.**

## Funde aus der Abnahmerunde des Nutzers (26.10., Supervisor 27.10. bestätigt)

- **bug.0.4.211 — Dashboard-Kacheln: gleich breit, Abstand 16 pt.**
  - **Nutzer sieht:** Kacheln kleben paarweise aneinander, dazwischen größere Lücken; Online-Kacheln sind breiter als Offline-Kacheln. **Wann:** immer, wenn die Zellbreite des Rasters unter der Inhaltsbreite einer Kachel liegt (z. B. Fenster 1134 pt, 5 Spalten). **Stufe 1.**
  - **Ursachen:** `DashboardGridLayout.minCardWidth = 200` (Katalog: Kachel 240, Mindestbreite 220); `MediumDashboardCard` hat Zeilen mit `fixedSize(horizontal: true…)` (Chip, Zeitzeile), die Kachel wird breiter als ihre Zelle; `DashboardEqualHeightRowLayout.placeSubviews` rückt trotzdem um `cardWidth + spacing` weiter.
  - **Soll:**
    - Mindestbreite nach Katalog (220).
    - Jede Kachel ist genau so breit wie ihre Zelle, in allen Zuständen gleich: Online, Offline, „x % indiziert“, „Fehler“, lange Namen.
    - Text, der nicht passt, wird mit „…“ gekürzt, nie breiter. Der Chip bleibt ganz, gekürzt wird der Text daneben.
    - Abstand immer 16 pt, waagerecht und senkrecht.
  - **Tests:** Fenstertest außerhalb des Bildschirms, Breiten 900, 1134, 1400, gemischte Zustände inklusive eines langen Namens. Alle Kacheln einer Reihe gleich breit, Abstand 16 ± 0,5 pt, keine Überlappung (Frames).
  - **Sabotage:** 211-a `fixedSize` zurück (rot), 211-b Mindestbreite 200 (rot).
  - **Status:** Bereit zur Prüfung.
    - Fix: `minCardWidth` 220; Zeitzeilen der Kachel ohne `fixedSize` (kürzen mit „…“), Chip bleibt ganz. `DashboardGridLayoutTests.columnCountsForFixtureWidths` an 220 angepasst (868 → 3, 1368 → 5).
    - Test `WindowTestGroup/DashboardCardWidthTests` (Pixel, 900/1134/1400, acht gemischte Zustände, Rollbalken Overlay, hell/dunkel): rot 10:58 (je zwei Kacheln ineinander, ~426 statt 2 × 205 pt), grün 10:59.
    - Sabotage 211-a (`fixedSize` zurück), 211-b (Mindestbreite 200): rot 12:07/12:08. 20× parallel grün 12:10–12:15.

- **bug.0.4.218 — Spaltenbreite: nur die gezogene Spalte, ohne Ruckeln.**
  - **Nutzer sieht:** Beim Ziehen am Rand einer Ordnerspalte ruckelt es; beim Loslassen werden **alle** Ordnerspalten so breit. **Wann:** bei jedem Ziehen. **Stufe 1.**
  - **Entscheidung (Nutzer 26.10.):** Jede Ordnerspalte hat ihre eigene Breite; nur die gezogene ändert sich, beim Ziehen und danach. Konzept `konzept/suche-navigation.md`, „Spaltenbreite“.
  - **Neu geöffnete Spalte (Host 27.10., Nutzer kann widersprechen):** Standardbreite 230 pt, nicht die zuletzt gezogene. Die Breite gilt je Spaltenposition (Index), solange der Pfad bis dorthin gleich bleibt; schließt die Spalte, fällt ihre Breite weg. Nicht gespeichert, kein neuer Eintrag in `app-state.plist`.
  - **Heute:** `ColumnBrowserState.folderColumnWidth` ist eine Breite für alle; `ColumnResizeHandle.onEnded` schreibt sie, während des Ziehens gilt `columnResizePreview` für die eine Spalte.
  - **Ruckeln:** Beim Ziehen ändert sich nur der Frame der einen Spalte; kein Neuaufbau der anderen Spalten, kein Scroll-Auftrag. Die gefundene Ursache im Status nennen.
  - **Tests:** Fenstertest mit drei Ordnerspalten: die mittlere ziehen (`sendEvent`) → nur sie ist breiter, die anderen bleiben (Frames ±0,5). Gegenproben: die erste Spalte ziehen; eine neue Spalte öffnen → 230 pt.
  - **Sabotage:** 218-a eine Breite für alle (rot), 218-b neue Spalte erbt die gezogene Breite (rot).
  - **Status:** Bereit zur Prüfung.
    - Ursache des Ruckelns: `ColumnResizeHandle` maß den Weg lokal; der Griff wanderte mit der Spalte mit, jeder Schritt zog die eigene Verschiebung ab (Breite folgte der Maus nur halb, beim Loslassen falscher Wert). Jetzt `coordinateSpace: .global`. Breite je Spalte: `ColumnBrowserState.folderColumnWidths[Index]`, Standard 230, fällt bei Pfadwechsel davor weg, nicht gespeichert; `UiQuitMetaTests` auf `folderColumnWidth(at: 0)`.
    - Test `WindowTestGroup/ColumnWidthPerColumnTests` (Trennlinien, Schritte à 10 pt, neue Spalte, wieder geöffnet, erste Spalte): rot 11:06, grün 11:07. Mausereignisse direkt an die getroffene Ansicht (`window.sendEvent` erreicht im inaktiven Testfenster keine SwiftUI-Geste, auch kein Tippen).
    - Sabotage 218-a (eine Breite), 218-b (erbt), 218-c (lokal gemessen): rot 12:07–12:09. 20× grün 12:10–12:15.
    - Stufe 2 (Selbstprüfung): Benennt der Nutzer einen geöffneten Ordner im Finder um, fällt die gezogene Breite der Spalte rechts davon weg (Pfad nach Namen). Nicht behoben.

- **bug.0.4.219 — Eine Farbe für Seitenleiste, Offline-Leiste und Detailspalte.**
  - **Nutzer sieht:** Die Hintergründe der Detailspalte und der Leiste „Offline — Inhalt aus dem Index …“ passen nicht zusammen. **Wann:** immer bei einem Offline-Medium mit offenen Details; die Seitenleiste immer. **Stufe 1.**
  - **Heute** (`ColumnBrowserView.swift`): Seitenleiste `text.opacity(0.06)` (Z. ~300), Offline-Leiste `0.05` (Z. ~340), Detailspalte `0.04` (Z. ~909) — drei Grautöne, nicht aus dem Katalog.
  - **Soll:** Eine Farbrolle aus `docs/Komponenten-Masse.md` bzw. Layout 07 für alle drei Flächen (z. B. `DesignColor.toolbar` oder `surface`), hell und dunkel. Steht sie dort nicht eindeutig: „Frage:“ und HALT bei dieser Aufgabe, mit den nächsten weitermachen.
  - **Test:** Pixeltest (`PixelProbe`): Seitenleiste, Offline-Leiste und Detailspalte haben denselben Farbwert, hell und dunkel.
  - **Sabotage:** 219-a Detailspalte wieder 0,04 (rot).
  - **Status:** Bereit zur Prüfung.
    - Rolle `DesignColor.toolbar` für alle drei: Katalog „Seitenleiste“ = Text 6 % über bg (genau `toolbar`); Detailspalte und Offline-Leiste stehen im Katalog nicht (Layout 07: 4 % bzw. 5 %).
    - Test `WindowTestGroup/ColumnSurfaceColorTests` (Pixel, Offline-Medium mit Datei, hell/dunkel): rot 11:24, grün 11:25.
    - Sabotage 219-a (Detail 4 %): rot 12:07. 20× grün 12:10–12:15.

- **bug.0.4.220 — Pfad in der Fußzeile bündig mit dem Icon der ersten Ordnerspalte.**
  - **Nutzer sieht:** Der Pfad in der Fußzeile beginnt nicht genau an der linken Kante des Ordner-Icons der ersten Ordnerspalte. Vorgabe: zu 100 % bündig. **Wann:** immer; stärker, wenn die Seitenleiste gezogen ist. **Stufe 1.**
  - **Ursache** (`ColumnBrowserPathFooter.swift`): Der linke Teil hat die feste Breite `DesignSpacing.columnBrowserSidebarWidth` (Z. ~18), die Seitenleiste ist aber ziehbar (`columnBrowserState.sidebarWidth`). Der Pfad hat `padding(.horizontal, 8)` (Z. ~25), das Icon sitzt bei Spalteneinzug + `ColumnBrowserRow` `padding(.horizontal, 10)`.
  - **Soll:** Der Pfad beginnt bei x = aktuelle Seitenleistenbreite + Spalteneinzug + Zeileneinzug, aus denselben Konstanten berechnet (keine zweite Zahl), und folgt dem Ziehen der Seitenleiste.
  - **Test:** Fenstertest: linke Kante des ersten Pfadzeichens (Glyph-Rahmen oder Pixel) = linke Kante des Icons der ersten Ordnerspalte, ±0,5 pt; bei Standardbreite und nach dem Ziehen der Seitenleiste um +60 pt.
  - **Sabotage:** 220-a feste Breite zurück (rot nach dem Ziehen).
  - **Status:** Bereit zur Prüfung.
    - Pfad beginnt bei `sidebarWidth + ColumnFolderContents.rowInset + ColumnBrowserRow.iconLeading` (8 + 10 + 0,5 aus denselben Konstanten wie die Zeile); Seitenleistenbreite aus dem Zustand; freier Platz einzeilig.
    - Test `WindowTestGroup/ColumnFooterPathAlignmentTests` (Tinte von Icon und Pfad, bereinigt um Rahmen → Tinte aus einer Vergleichsdarstellung; Standard und Seitenleiste +60 gezogen, hell/dunkel): rot 11:58 (Pfad 224,0 / Icon 218,5; gezogen 224,0 / 278,5), grün 11:59.
    - Sabotage 220-a (feste Breite): rot 12:07. 20× grün 12:10–12:15.

- **bug.0.4.217 — Spinner in der Medienspalte 12 × 12 pt.**
  - **Nutzer sieht:** Der Spinner neben einem Medium, das gerade indiziert wird, ist größer als im Layout. **Wann:** bei jedem laufenden Lauf. **Stufe 1.**
  - **Heute:** `ColumnBrowserRow.swift` (Z. ~33–37): `IndexingSpinnerRing(lineWidth: 1.5).frame(width: 14, height: 14)` in einer 16er-Box.
  - **Soll:** 12 × 12 pt, Strich 2 pt, mittig in der 16er-Icon-Box (die Zeile springt nicht). Farbe bleibt Text-/Icon-Farbe, schwarz bzw. weiß je nach Erscheinungsbild (Nutzer 26.10., **nicht** grün wie im Layout). Konzept `konzept/suche-navigation.md`.
  - **Test:** Messtest ±0,5 pt, hell und dunkel; Zeilenhöhe mit und ohne Spinner gleich.
  - **Sabotage:** 217-a 14 × 14 (rot).
  - **Status:** Bereit zur Prüfung.
    - `IndexingSpinnerRing(lineWidth: 2).padding(1).frame(12 × 12)` in der 16er-Box, Farbe unverändert Icon-/Textfarbe.
    - Test `WindowTestGroup/SidebarSpinnerSizeTests` (Pixel, gewählte Zeile, hell/dunkel; Größe, Mitte, Zeilenhöhe mit/ohne, Strich): rot 12:01 (16 × 16), grün 12:01 (12 × 12, Strich 2,0).
    - Sabotage 217-a (14 × 14): rot 12:07. 20× grün 12:10–12:15.

**Paketende:**
- 0 Warnungen in Debug und Release.
- Die betroffenen Suites grün; die neuen Suites 20× parallel grün. Rote Läufe zählen auch, wenn nur das Protokoll sie zeigt.
- Alle Patches unter `todo/sabotage/` rot.
- App des Nutzers gebaut.
- **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele). Sonst weglassen und im Status vermerken, dann macht ihn der Host.

## Abnahme Host 27.10. (Gesamtlauf 12:37–13:20, Sabotage 13:23–13:27)

`Werkzeuge/pruefung.sh voll` ergab:
- Debug und Release: 0 Warnungen.
- Seriell **1196/1196** grün.
- Parallel 1–3 **grün** (je 1190 bestanden, 6 übersprungen, Exit 0).
- Keine neuen `.ips`; neue Dateien in `~/Library/Preferences`: 0.
- App des Nutzers 13:20:44, Signatur gültig, Version 0.4.0.

Bei der Sabotage meldeten 218-a bis -c zuerst „kein Test gefunden“: Die `# Test:`-Zeile nannte zwei Tests mit Komma, das Skript las nur einen je Zeile. Es nimmt jetzt beides an (`pruefung.sh`, Regel 9 ergänzt). Der zweite Lauf `pruefung.sh sabotage` zeigte **8/8 rot ✓** (218-a bis -c je 2 von 2).

Den Commit `06f467c` hat der Host gelesen:
- **211:** Die Mindestbreite ist 220. Die Zeitzeilen haben kein `fixedSize` mehr, der Chip bleibt ganz.
- **218:** Die Breite gilt je Spalte (`folderColumnWidths`). Sie fällt weg, wenn sich der Pfad links davon ändert. Gezogen wird in Fensterkoordinaten, das war die Ursache des Ruckelns.
- **219:** Alle drei Flächen haben `DesignColor.toolbar`.
- **220:** Der Pfad beginnt bei `sidebarWidth + rowInset + iconLeading`, aus denselben Konstanten wie die Zeile.
- **217:** Der Spinner ist 12 × 12 mit Strich 2.

Prüf-Agent (Sonnet, Vorlage 2b): nichts Wesentliches, kein Befund der Stufe 1 oder 2.

- **Abgenommen:** `bug.0.4.211`, `bug.0.4.217`, `bug.0.4.218`, `bug.0.4.219`, `bug.0.4.220`.
- **Stufe 2 (Backlog):** Benennt der Nutzer einen geöffneten Ordner im Finder um, fällt die gezogene Breite der Spalte rechts davon weg.
- **Stufe 3 (keine Aufgabe):** Beim Wechsel des Mediums bleibt die gezogene Breite der ersten Ordnerspalte. Das war schon vorher so.
