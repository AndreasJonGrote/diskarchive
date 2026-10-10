# TODO.md — offene Aufgaben für Cursor

Einzige Aufgabenliste. Erledigtes steht in [DONE.md](DONE.md), Verlauf und alte Spezifikationen in `archiv/`. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). **Komponenten (Maße, Farben, Zustände): [layout/Komponenten.dc.html](layout/Komponenten.dc.html), zusammengefasst in [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) — einzige Quelle für Größen.** Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

## Regeln für Cursor (verbindlich)

1. **Nur Aufgaben aus „A. Jetzt“**, in der dort stehenden Reihenfolge. „B. Backlog“ und alles andere nicht anfassen, auch nicht „vorbereiten“.
2. **Nach jedem Paket anhalten** (Zeile „HALT“). Erst weiterarbeiten, wenn Claude in A. freigegeben hat.
3. **Nichts erfinden.** Kein Feature, Text, Schalter, Screen ohne Vorgabe in README oder Layout. Fehlt etwas: Frage unter die Aufgabe schreiben („Frage:“), nicht bauen. Nötige Texte ohne Layout-Vorlage nur als rote Vorschläge (`ProposalCopy`).
4. **Layout und README sind schreibgeschützt** für Cursor (auch `AGENTS.md`, `archiv/`). Abweichung gefunden → als „Frage:“ melden, nicht selbst „angleichen“.
5. **Diese Datei:** Cursor ändert nur das Feld „Status“ der jeweiligen Aufgabe (höchstens 5 Zeilen: was, welche Dateien, Abweichung). Keine Reviewblöcke, keine neuen Aufgaben, nichts umsortieren, nichts löschen. Claude räumt auf.
6. **Keine Selbstfreigabe.** Cursor schreibt „Bereit zur Prüfung“, nie „fertig“. Nur Claude verschiebt nach DONE.md.
7. **Belege statt Behauptungen:** „Tests grün“ nur mit Zahl, Uhrzeit, Kommando. Bildschirmfotos nur melden, wenn sie in diesem Lauf neu erzeugt wurden (Zeitstempel prüfen). Build Debug und Release ohne Warnung.
8. **Tests:** nur `-only-testing:diskindexTests`, seriell **und** parallel. UI-Tests nicht starten (Passwortabfrage). Leistungszahlen nur im Release-Build.
9. **Kein Aufräumen, Verschieben oder Löschen** von Dateien, die nicht in der Aufgabe stehen. Kein Refactoring „nebenbei“.
10. **Echte Fenster testen, nicht nur Bilder.** Das Offscreen-Bildschirmfoto (`ScreenshotRunner`) beweist nicht, dass eine Ansicht im echten Fenster funktioniert (Beispiel: `NSTableView`-Zeilen waren im Foto da, im echten Fenster leer). Bei jeder Aufgabe, die Ansichten, Klickflächen oder `NSViewRepresentable` berührt: Test mit echtem `NSWindow` (`makeKeyAndOrderFront`, Layout abwarten, Zeilen/Knöpfe zählen, Klick per `hitTest` auf Randpunkte).
11. **Regression-Rauchtest** (`RegressionSmokeTests`, Cursor legt ihn bei Aufgabe 122 an und erweitert ihn bei jeder Aufgabe): jede Ansicht, die schon einmal kaputt war, bekommt eine Zeile. Vor „Bereit zur Prüfung“ muss er grün sein. Eine Aufgabe, die etwas Abgenommenes wieder kaputt macht, gilt als nicht erledigt.
12. **Gemeinsame Bausteine nur zentral ändern** (Knopf, Chip, Zeile, Spaltenkopf, Leerzustand): eine Quelle, Änderung wirkt überall, Test an der Quelle. Keine zweite Kopie in einer Ansicht.
13. **Maße nur aus dem Komponentenkatalog** (`docs/Komponenten-Masse.md`, Quelle `layout/Komponenten.dc.html`). Keine eigenen Zahlen für Höhe, Innenabstand, Schrift, Rahmen, Radius. Jede Komponente hat einen Messtest gegen diese Zahlen (±0,5 pt), Hell und Dunkel.
14. **Nach Fehlern zurückrollen statt überbauen:** schlägt ein Test fehl, Ursache beheben, nicht Test abschwächen.

---

## A. Jetzt

**Stand 06.10. abends:** Paket 1, 2 und die Spaltenansicht (102, 114, 119, 120, 121) sind abgenommen, siehe DONE.md. Offen: Paket 3 (107, 109), dann Paket 4 (110, 111, 112 Rest, 113). Reihenfolge der Freigabe bestimmt Claude.

## ARBEITSAUFTRAG JETZT (Claude, 07.10. abends — exakt so umsetzen)

**Lies zuerst diese drei Regeln, sie gelten für jede Aufgabe unten:**
- **R1 Nur die genannten Stellen ändern.** Jede Aufgabe nennt Datei und Zeile. Andere Dateien nur, wenn die Aufgabe es sagt. Keine „Verbesserungen nebenbei“.
- **R2 Beweis = Pixel aus einem echten Fenster.** `hitTest != nil`, `source.contains(…)`, Zahlenvergleiche mit Konstanten und Prüfungen nur am Datenmodell zählen **nicht** als Beweis für Aussehen oder Klickverhalten. Benutze dafür ausschließlich die Hilfe `PixelProbe` (unten, Aufgabe 150 a). Jeder neue Test wird einmal **sabotiert** (die Korrektur zurücknehmen) und muss dann rot sein; im Status: „Sabotage: rot ✓“.
- **R3 Status je Aufgabe:** höchstens 5 Zeilen: geänderte Dateien:Zeilen, Testname, Ergebnis der Sabotage, Pfad der Bildschirmfotos (neu erzeugt in `Werkzeuge/screenshots/2026-10-08-<aufgabe>/`). Ohne diese vier Angaben gilt die Aufgabe als nicht gemacht.

---

**150. Spalten stehen senkrecht in der Mitte. Ursache ist gefunden (Claude), nur noch beheben.**
*Ursache:* `DesignSystem/FadeMaskText.swift`, `body`: `Color.clear.frame(maxWidth: .infinity, minHeight: minHeight)`. `Color.clear` ist in **beide** Richtungen gierig; ohne Höchsthöhe nimmt es **so viel Höhe, wie es bekommt**. Im Spaltenkopf (`ColumnBrowserColumnHeader` nutzt `FadeMaskText`) teilt es sich die Spaltenhöhe mit der Liste darunter: der Kopf wird ca. halb so hoch wie die Spalte, sein Text sitzt in dessen Mitte (y ≈ 360), die Liste beginnt erst darunter (y ≈ 666). Das war Claudes Vorgabe aus 138 (Fehler von Claude), nicht Cursors.
*Ändern (genau so):* in `FadeMaskText.body` den Behälter ersetzen durch einen **unsichtbaren Text als Höhenmaß**:
```swift
Text(verbatim: "Ag")            // eine Zeile in derselben Schrift = Zeilenhöhe
    .font(font)
    .lineLimit(1)
    .hidden()
    .frame(maxWidth: .infinity, alignment: .leading)   // nur Breite flexibel
    .overlay(alignment: .leading) { /* der sichtbare Text wie bisher */ }
    .clipped()
```
`minHeight` als Parameter entfernen (alle Aufrufer anpassen). Sonst nichts an Spalten, `ColumnBrowserView` oder `ColumnFolderContents` ändern.
*(a) Neue Testhilfe `diskindexTests/PixelProbe.swift`* (einmal anlegen, für alle folgenden Aufgaben benutzen):
```swift
@MainActor enum PixelProbe {
    /// Rendert eine SwiftUI-Ansicht in einem echten, sichtbaren Fenster und liefert die Bitmap.
    static func render<V: View>(_ view: V, size: CGSize, appearance: NSAppearance.Name = .aqua) async -> NSBitmapImageRep
    /// Kleinster Rahmen (in pt, Ursprung oben links) aller Pixel in `rect`, die sich vom Hintergrund
    /// (Farbe am Punkt `background`) um mehr als `tolerance` (0…1, je Kanal) unterscheiden.
    static func inkBounds(in bitmap: NSBitmapImageRep, rect: CGRect, background: CGPoint, tolerance: CGFloat = 0.08) -> CGRect?
    /// Farbe (sRGB) an einem Punkt in pt.
    static func color(in bitmap: NSBitmapImageRep, at point: CGPoint) -> NSColor
}
```
`render`: `NSWindow` (borderless, `orderFrontRegardless()`), `NSHostingView` als `contentView`, Laufschleife 0,3 s laufen lassen (`RunLoop.main.run(until:)`), dann `bitmapImageRepForCachingDisplay` + `cacheDisplay`; Faktor 2 beachten (pt → Pixel).
*(b) Test `ColumnVerticalLayoutTests`:* `ColumnBrowserView` mit Fixture „Studio Backup“ (drei Ordnerspalten, wie `07-spalten`) in 1280 × 800 rendern, hell **und** dunkel. Für jede Ordnerspalte: `inkBounds` im Streifen der Spalte von der Oberkante des Spaltenbereichs bis 60 pt darunter **muss** Pixel finden (der Kopftext) — Oberkante dieser Pixel **≤ 16 pt** unter der Spaltenbereichs-Oberkante; `inkBounds` im Bereich 30–80 pt darunter **muss** Pixel finden (erste Zeile). Gleicher Test für das Demo-Medium (Beispiel 1, 2, 3) und für `FadeMaskText` allein in einem 300 pt hohen Rahmen: Texthöhe der gerenderten Pixel ≤ 20 pt und oben ausgerichtet. *Sabotage:* `Color.clear`-Fassung zurückholen → Test rot.

**Status:** `FadeMaskText.swift:34–47` (Höhenmaß `Text("Ag")`, `minHeight` weg), `ColumnBrowserRow.swift:49–54`. Test `ColumnVerticalLayoutTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-150/` (00:16). Debug-Test 327 bestanden, 0 fehlgeschlagen (seriell, 00:13–00:16); Release-Build ohne Warnung (00:16). Bereit zur Prüfung.

**151. Fortschritt: nur das Layout. Alles über Dateizahlen löschen.**
*Layout (gemessen):* Chip „x % indiziert“ (gestrichelt grün, Spinner). Menüleisten-Popover, Zeile eines indizierenden Mediums: Name, darunter **Balken**, rechts **„14 %“** mit Spinner, gestrichelt unterstrichen; **Klick** darauf wechselt zur Byte-Angabe **„0,57 TB / 4,1 TB“** (Prozent × Gesamtkapazität / Gesamtkapazität, `ByteCountFormatter`, deutsches Komma) und zurück. **Nirgends Dateizahlen.**
*Ändern (genau diese Stellen):*
1. `DesignSystem/ProposalCopy.swift`: `countingChip` (Z. ~67), `countingPopoverLine` (Z. ~69–71), `countingObjects` (Z. ~73) und den Eintrag `countingChip` in der Vorschlagsliste (Z. ~110) **löschen**.
2. `DesignSystem/StatusChip.swift` Z. ~122–130: Zweig `indexRunPhase == .counting` **löschen**. Die Zählphase fällt damit in den normalen Zweig „\(percent) % indiziert“; `indexProgressFraction` liefert in der Zählphase bereits 0 → „0 % indiziert“.
3. `MenuBar/MenuBarConnectedMediumRow.swift` Z. ~59: `IndexingProgressBar(progress: medium.indexingProgress)` → **`medium.indexProgressFraction`** (eine Quelle für Text und Balken; das ist der Grund, warum der Balken steht).
4. Gleiche Datei, `indexingProgressLabel` (Z. ~125–131): Zweig `.counting` löschen; Zweig `showAbsoluteCapacity` gibt **nicht** mehr `indexProgressAbsoluteLabel` (Dateizahlen) zurück, sondern die Byte-Angabe aus dem Layout: `"\(bytes(fraction × capacityTotalBytes)) / \(bytes(capacityTotalBytes))"`; Standard `"\(medium.indexProgressPercent) %"`.
5. `Models/Medium.swift`: `indexProgressAbsoluteLabel` und `countingLiveCount` löschen; `Indexing/IndexingService.swift` Z. ~166 und ~214 (Zuweisungen an `countingLiveCount`) löschen; `DebugTools/ScreenshotRunner.swift` Z. ~225 anpassen. `indexRunPhase` bleibt (nur für 0 %).
6. Danach `grep -rn "Objekte\"\|gezählt\|countingLive\|indexProgressAbsoluteLabel" diskindex/diskindex` → **keine Treffer** (Fußzeile „x Objekte“ der Spaltenansicht ist eine andere Funktion und bleibt).
*Test `ProgressDisplayTests`:* Medium in Zählphase und bei 0,45 / 0,99: Chip-Text, Popover-Text sind „0 % indiziert“/„0 %“, „45 % …“, „99 % …“; Popover-Zeile mit `PixelProbe` rendern: Breite der gefüllten Balkenpixel / Balkenbreite = 0 / 0,45 / 0,99 (±0,02). *Sabotage:* Schritt 3 zurück → rot.

**Status:** `ProposalCopy.swift` Zähltexte weg, `StatusChip.swift:122` ohne Zählzweig, `MenuBarConnectedMediumRow.swift:59,126–135`, `Medium.swift:63` ohne Dateizahl-Label, `IndexingService.swift:165–171,211`, `ScreenshotRunner.swift` Zähl-Screenshot ohne `countingLiveCount`. Test `ProgressDisplayTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-151/` (00:26). Seriell 330 bestanden (00:23–00:25); Release ohne Warnung (00:26). Bereit zur Prüfung.

**152. Spaltenansicht: graue Pfadmarkierung, Scrollbalken, Demo-Ladefläche.**
1. *Graue Markierung:* `Views/ColumnBrowser/ColumnBrowserView.swift` `rowOpacity` (Z. ~193–196) dimmt **die ganze Zeile** (inklusive schwarzer Markierungsfläche) auf 55 %, sobald der Ordner im Zustand `.pendingIndex` ist (während das Medium indiziert). Darum sind die Pfad-Ordner grau (`#7f7f7f` = Schwarz mit 55 %). *Ändern:* `rowOpacity` gibt **1** zurück, wenn `isRowSelected(item:column:)` wahr ist; nur **nicht markierte** Zeilen werden gedimmt (Layout 07: „noch nicht indiziert erscheint ausgegraut“ gilt für normale Zeilen). *Test:* mit `PixelProbe` Farbe in der Mitte jeder markierten Pfadzeile = `DesignColor.sidebarActiveBackground` (hell `#1F1F1F`, dunkel `#4A4949`, ±3 je Kanal) auch während das Medium indiziert.
2. *Scrollbalken:* `ColumnFolderContents.swift` (`ScrollView` Z. ~52): `.scrollIndicators(.hidden)`; `ColumnFolderTableView.swift`: `scroll.scrollerStyle = .overlay`, `scroll.autohidesScrollers = true`. Gilt nur für Ordnerspalten, nicht Sidebar/Detail. *Test:* `PixelProbe`: rechter 16-pt-Streifen jeder Ordnerspalte mit 200 Einträgen hat **keine** Pixel einer Scrollspur (gleich Hintergrund, außer Zeilentext).
3. *Demo „Beispiel 3 — Inhalte werden geladen“ zeigt nichts außer dem Kopf:* Der Hinweis (`FolderContentsLoadingHint`: Spinner 24, „Inhalte werden geladen“, Satz, „12.480 von 41.902 Objekten geladen“) muss im Demo-Medium **sofort und dauerhaft** erscheinen. Prüfen, warum `demoLoadingColumnTiming` → `DelayedLoadingState` nicht `showsHint == true` liefert (Zustand `delayed` entsteht erst in `onAppear`, `syncDelayedState` vor dem ersten Takt; Demo-Zeitprofil muss Verzögerung 0 **und** keine Mindestanzeige-Bedingung haben). *Test:* `PixelProbe` 0,3 s nach Öffnen von Beispiel 3: Pixel des Titels im Bereich 30–80 pt unter dem Kopf vorhanden; Fläche reicht bis zum rechten Fensterrand (139).

**Status:** `ColumnBrowserView.swift:193–206` Auswahl deckend, `ColumnFolderContents.swift:43–45,61` Hinweis bei Verzögerung 0 und ohne Scrollbalken, `ColumnFolderTableView.swift:27` Overlay-Scroller, `DelayedLoadingState.swift:45–55`, Demo-Zeitprofil ohne Mindestzeit. Test `ColumnChromeTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-152/` (00:54). Seriell 334 bestanden (00:52–00:54); Release ohne Warnung. Bereit zur Prüfung.

**153. Sprachschalter: Pfeil steht links.**
*Ursache:* macOS setzt ein `Image` im Label eines SwiftUI-`Menu` **vor** den Text, egal wo es im `HStack` steht. *Ändern* `Views/Settings/SettingsLanguagePicker.swift`: Label des `Menu` = **nur** `Text(selection.label)` (12/600, links); Pfeil (`caret-down` aus dem Asset-Katalog, 10 pt, 55 % Text) als `.overlay(alignment: .trailing) { … .padding(.trailing, 12).allowsHitTesting(false) }` **auf dem Menu**, nicht im Label; Rahmen/Hintergrund ebenfalls außen auf dem Menu; Größe 200 × 32 (Einstellungslayout) mit Innenabstand 12 links; Rahmen 1 px `DesignBorder.secondaryControlBorderColor`, Radius 8. *Test:* `PixelProbe`: rechteste Pfeilpixel liegen in den rechten 24 pt, Textpixel beginnen in den linken 24 pt.

**Frage:** Im Asset-Katalog gibt es kein Imageset `caret-down` (nur `NavCaretRight` mit `caret-right.svg`). Ohne diese Datei setze ich den Pfeil nicht.

**154. Autostart.**
1. `Views/Settings/SettingsGeneralTab.swift` `launchAtLoginSection` (Z. ~100): dem `Toggle(LayoutCopy.autostartToggle …)` fehlt `.toggleStyle(DesignCheckbox())` → System-Kästchen (blau). Ergänzen. Danach `grep -n "Toggle(" -A3` über das Projekt: **jeder** `Toggle` hat `.toggleStyle(DesignCheckbox())` oder einen begründeten anderen Stil (Liste im Status).
2. *Dock blitzt beim Einschalten:* Das Registrieren des Launch-Agents (`RunAtLoad`) startet sofort eine zweite Instanz `--background`, die kurz im Dock erscheint und sich dann beendet. *Ändern:* in `diskindexApp.swift` im `init()` (läuft vor jeder Szene): wenn `CommandLine.arguments.contains("--background")` **und** `NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)` eine **andere** PID enthält → `exit(0)` sofort. Zusätzlich vor jeder Oberfläche `NSApp.setActivationPolicy(.accessory)` für `--background`. *Test:* Logik als Funktion `BackgroundLaunchGate.shouldExitImmediately(arguments:runningPIDs:ownPID:)` mit Unit-Test (3 Fälle). Nutzer prüft das Dock.

**Status:** `SettingsGeneralTab.swift:109` `DesignCheckbox`. `diskindexApp.swift:11–37` `BackgroundLaunchGate`, `exit(0)`, `.accessory`. Test `BackgroundLaunchGateTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-154/`. Seriell 338 bestanden; Release ohne Compiler-Warnung. Weitere `Toggle`: `DesignCheckbox` bei Mitteilungen, AutoSend, Filter, Dialogen; System nur mit `.tint`: Ordner anzeigen, zwei Ignorieren-Schalter. Bereit zur Prüfung.

**156. Rand der letzten Spalte flackert beim Laden großer Ordner (Nutzer 07.10.).**
*Ursache (aus dem Code):* `ColumnBrowserView.columnShowsStatusRestFill` (Z. ~342–351) gibt **wahr** zurück, sobald `indexRepository.isLoading(...)` wahr ist — also **ab der ersten Millisekunde** des Ladens, obwohl der Hinweis erst nach 1 s sichtbar wird. Solange das gilt, wird die Spalte zur Statusfläche: volle Restbreite, **kein** Rand/Resize-Griff (Overlay Z. ~437 `if !statusRest`), Detail-Spalte ausgeblendet (Z. ~301). Ist der Ordner fertig, springt sie zurück auf feste Breite **mit** Rand. Beim schnellen Laden (Bruchteile einer Sekunde, oder mehrere Seiten nacheinander) wechselt das hin und her → der Rand blinkt.
*Ändern:* Die Statusflächen-Breite für **Laden** gilt nur, **solange der Ladehinweis wirklich sichtbar ist** (`DelayedLoadingState.showsHint == true`, also nach 1 s, mindestens 400 ms, laut README). Dafür den Zustand „Hinweis sichtbar“ je Pfad aus `ColumnFolderContents` nach oben geben (z. B. im `IndexRepository` oder `ColumnBrowserState` als `loadingHintVisible(path)`, gesetzt von `DelayedLoadingState`) und in `columnShowsStatusRestFill` statt `isLoading` verwenden. Vor Ablauf der 1 s bleibt die Spalte **unverändert fest breit mit Rand** (leer, wie README „Ladehinweis erst nach 1 s“). Wird indiziert / nicht indiziert / Ladefehler bleiben wie bisher.
*Test `ColumnLoadingBorderStableTests`:* Ordner mit 20.000 Einträgen laden, dabei alle 16 ms (60 Bilder) mit `PixelProbe` den Rand rechts der Spalte messen: Ladezeit < 1 s → in **jedem** Bild Rand vorhanden, Spaltenbreite konstant; künstlich verzögertes Laden (2 s) → genau **ein** Wechsel zur Statusfläche bei ≥ 1 s und **ein** Wechsel zurück nach Ende, keine weiteren. *Sabotage:* wieder `isLoading` verwenden → rot.

**Status:** `ColumnBrowserView.swift` Statusfläche nur bei sichtbarem Hinweis, `ColumnBrowserState.swift` `loadingHintVisible`, `ColumnFolderContents.swift` meldet den Hinweis, `DelayedLoadingState.swift` zieht die Uhr nach. Test `ColumnLoadingBorderStableTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-156/`. Seriell 336 bestanden; Release ohne Warnung. Bereit zur Prüfung.

**157. Demo-Medium „Spalten-Zustände (Demo)“ verfälscht die ganze App (Claude-Prüfung 07.10.).**
*Befund (Code `DebugTools/ColumnStateSimulation.swift`, `App/AppState+Media.swift` Z. ~212–216):* In jedem Debug-Start wird das Demo-Medium **in `appState.media` eingefügt**. Damit zählt es überall mit, obwohl es nur in der Spaltenansicht gebraucht wird:
- `connectedMedia` → Menüleisten-Popover zeigt es als **dauerhaft indizierend**, das Menüleisten-Symbol (grüner Spinner) läuft im Debug **nie** aus;
- `registryMedia`/`indexedMedia` → Einstellungen › Speichermedien, Dashboard, Suche, Favoriten, Mitteilungen;
- `forgetAllMedia` (Z. ~75–95) löscht es mit → **`store error deleteMedium unknownMedium`** im Protokoll (Nutzer-Protokoll 07.10. 12:09), solche `store`-Fehler lösen `onTrackedError` aus;
- Medium-Details/Kontextmenü (Ja/Nein, Vergessen, Neu indizieren) wirken auf ein Medium, das es in der Datenbank nicht gibt.
*Statusfelder widersprechen sich:* `makeMedium()` setzt `indexingProgress: 0.42`, aber `fileCount 12_480 + folderCount 3 = 12.483` gespeicherte Einträge bei `scanTotal 50_000` = **25 %**. Je nach Anzeige erscheint 42 % oder 25 % (zwei Quellen, verboten laut README §4).
*Ändern:*
1. Demo **nicht** mehr in `media` einfügen (Z. ~212–216 löschen). Stattdessen in `AppState+Media.swift` eine eigene Liste `var columnBrowserMedia: [Medium] { indexedMedia + (DEBUG && shouldInjectIntoMediaList ? [ColumnStateSimulation.makeMedium()] : []) }`, die **nur** die Seitenleiste der Spaltenansicht und `resolvedSelectedMedium` in `ColumnBrowserView` benutzen. Alle anderen Stellen (`connectedMedia`, `registryMedia`, `indexedMedia`, Popover, Menüleiste, Dashboard, Einstellungen, Suche, Favoriten, Mitteilungen, `forgetAllMedia`) sehen das Demo-Medium nicht.
2. Für das Demo-Medium **keine Aktionen**: Kontextmenü der Seitenleiste und Medium-Details für `ColumnStateSimulation.isSimulationMedium` nicht anbieten (Rechtsklick ohne Wirkung, Doppelklick öffnet keine Details).
3. Statusfelder stimmig: `fileCount: 20_997`, `folderCount: 3` (= 21.000 gespeichert), `scanTotal: 50_000`, `indexingProgress: 0` → überall **42 % indiziert** aus `indexProgressFraction`.
*Test `ColumnDemoIsolationTests`:* mit Demo eingeschaltet: `connectedMedia`, `registryMedia`, `indexedMedia` enthalten die Demo-Kennung **nicht**; `columnBrowserMedia` enthält sie; `forgetAllMedia` erzeugt **keine** `store error`-Zeile (Protokoll-Attrappe); Menüleisten-Zustand „indiziert gerade“ ist falsch, wenn nur das Demo-Medium indiziert; Demo-Chip-Text = „42 % indiziert“. *Sabotage:* Einfügen in `media` zurückholen → rot.

**Status:** `AppState+Media.swift:192` `columnBrowserMedia`, kein Einfügen in `media`. `ColumnBrowserView.swift:47–52,97–98,280–285,707` nur diese Liste, Demo ohne Kontextmenü. `ColumnStateSimulation.swift:84–92` 20.997+3, `indexingProgress` 0. Test `ColumnDemoIsolationTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-157/`. Seriell 337 bestanden; Release ohne Compiler-Warnung. Bereit zur Prüfung.

**155. Toolbar-Icons — nicht anfassen.** Wartet auf ein Bild vom Nutzer.

**HALT nach 157.** Reihenfolge 150 → 151 → 152 → 156 → 157 → 153 → 154. Nach **jeder** Aufgabe: Debug- und Release-Build, Unit-Tests seriell, Status nach R3.

### Offen, ohne Cursor

- **Nutzer:** (1) Kurztest am Stick für 107: großen Ordner öffnen, Pfeiltasten, Mehrfachauswahl, Rechtsklick. (2) Layout nachziehen: alte Chip-Beschreibungstexte, Menüleisten-Symbol „blauer Spinner (Abgleich)“ (112 Punkt 3), Texte der roten Vorschläge (Debug-App prüfen). (3) Entscheiden: T5 (ausführliches Protokoll) freigeben?
- **Claude:** Layout (Stand 07.10.) gegen README abgleichen; danach neue Aufgaben für Cursor schreiben. Spezifikationen der abgenommenen Aufgaben: `archiv/todo-stand-2026-10-07.md`.

---

## B. Backlog (nicht freigegeben, Cursor arbeitet nicht daran)

- **T1. Ladehinweis erst nach 1 s** (Nutzer 06.10.): gehört zu 107; Suche/Favoriten später.
- **T2. Programme als Dateityp „Programme“** (`.app`-Pakete, dmg, pkg).
- **T3. Erweiterte Dateityp-Icons** (Styleguide Sektion 15).
- Cursor hat T1–T3 vorzeitig gebaut; Claude entscheidet bei der Prüfung, was bleibt.
- **T5 (Vorschlag Claude, wartet auf Nutzer): Ausführliches Protokoll („Diagnose-Modus“).** Es gibt schon `~/Library/Logs/Disk Index/diskindex.log` (Kategorien, `crash-last.txt`, „previous run ended without clean exit“). Lücken: (1) **Beenden wird nicht protokolliert** (`applicationShouldTerminate` schreibt nichts; nur `applicationWillTerminate` „app terminate ok“) → Zeilen „quit requested (Quelle)“, „quit: status item entfernt“, „quit: Indizierung gestoppt“ mit Dauer. (2) **Haupt-Thread-Wächter:** blockiert der Hauptfaden > 2 s, Zeile `hang main ms=…` mit Stack (Release tauglich). (3) **Schalter** „Ausführlich“ (Erweitert, nur Debug oder per `defaults`) für Pegel `debug`: je Medium Dauer von Lesen/Schreiben, Cache-Treffer, Ladezeiten Spalten, Speicher. (4) `crash-last.txt` auch bei Beenden durch Signal. Nicht freigegeben.
