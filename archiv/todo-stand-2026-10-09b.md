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
8. **Tests:** nur `-only-testing:diskindexTests`; nach **jeder Aufgabe seriell**, am **Ende des Pakets** zusätzlich einmal parallel. UI-Tests nicht starten (Passwortabfrage). Leistungszahlen nur im Release-Build.
9. **Kein Aufräumen, Verschieben oder Löschen** von Dateien, die nicht in der Aufgabe stehen. Kein Refactoring „nebenbei“.
10. **Echte Fenster testen, nicht nur Bilder.** Das Offscreen-Bildschirmfoto (`ScreenshotRunner`) beweist nicht, dass eine Ansicht im echten Fenster funktioniert (Beispiel: `NSTableView`-Zeilen waren im Foto da, im echten Fenster leer). Bei jeder Aufgabe, die Ansichten, Klickflächen oder `NSViewRepresentable` berührt: Test mit echtem `NSWindow` (`makeKeyAndOrderFront`, Layout abwarten, Zeilen/Knöpfe zählen, Klick per `hitTest` auf Randpunkte).
11. **Regression-Rauchtest** (`RegressionSmokeTests`, Cursor legt ihn bei Aufgabe 122 an und erweitert ihn bei jeder Aufgabe): jede Ansicht, die schon einmal kaputt war, bekommt eine Zeile. Vor „Bereit zur Prüfung“ muss er grün sein. Eine Aufgabe, die etwas Abgenommenes wieder kaputt macht, gilt als nicht erledigt.
12. **Gemeinsame Bausteine nur zentral ändern** (Knopf, Chip, Zeile, Spaltenkopf, Leerzustand): eine Quelle, Änderung wirkt überall, Test an der Quelle. Keine zweite Kopie in einer Ansicht.
13. **Maße nur aus dem Komponentenkatalog** (`docs/Komponenten-Masse.md`, Quelle `layout/Komponenten.dc.html`). Keine eigenen Zahlen für Höhe, Innenabstand, Schrift, Rahmen, Radius. Jede Komponente hat einen Messtest gegen diese Zahlen (±0,5 pt), Hell und Dunkel.
14. **Nach Fehlern zurückrollen statt überbauen:** schlägt ein Test fehl, Ursache beheben, nicht Test abschwächen.
15. **Zeichenpfad sauber halten:** in `body`, `init`, `Binding(get:)`, `@State … = …` und `onAppear` **keine** Systemaufrufe (`SMAppService`, `UNUserNotificationCenter`, Dateisystem, Datenbank) und **keine** Zustandsänderungen. Solche Werte liegen in `AppState` und werden im Hintergrund aktualisiert.
16. **Zeilenangaben sind Richtwerte** („Z. ~“). Gilt eine Zeile nicht mehr, über den genannten **Symbolnamen** suchen; nichts an anderer Stelle „ähnlich“ ändern.

---

## A. Jetzt

**Stand 09.10.:** Abgenommen bis 172 a/c/d/e (siehe DONE.md). Offen: 174 (zuerst), dann 173.

## ARBEITSAUFTRAG JETZT (Claude, 09.10. — exakt so umsetzen)

**Lies zuerst diese drei Regeln, sie gelten für jede Aufgabe unten:**
- **R1 Nur die genannten Stellen ändern.** Jede Aufgabe nennt Datei und Zeile. Andere Dateien nur, wenn die Aufgabe es sagt. Keine „Verbesserungen nebenbei“.
- **R2 Beweis = Pixel aus einem echten Fenster.** `hitTest != nil`, `source.contains(…)`, Zahlenvergleiche mit Konstanten und Prüfungen nur am Datenmodell zählen **nicht** als Beweis für Aussehen oder Klickverhalten. Benutze dafür ausschließlich die Hilfe `PixelProbe` (Aufgabe 150 a). Jeder neue Test wird einmal **sabotiert** und muss dann rot sein; im Status: „Sabotage: rot ✓“.
- **R3 Status je Aufgabe:** höchstens 5 Zeilen: geänderte Dateien:Zeilen, Testname, Ergebnis der Sabotage, Pfad der Bildschirmfotos (`Werkzeuge/screenshots/<JJJJ-MM-TT>-<aufgabe>/`).

---

**Claude-Prüfung 09.10.:** 172 a, c, d, e **abgenommen**. Claude-Lauf **348 Tests, 85 Suiten seriell grün** (stimmt mit Cursor). Code geprüft: `.scrollIndicators(.never)` und Tabelle ohne Scroller; `ConfirmButton` ohne `onHover`; `SettingsLanguageSection` mit eigenem `isOpen`, `focusEffectDisabled` an Knopf, Feld, Zeilen. Fotos: keine Spur in den Spalten, Beispielkasten mit neuem Text. Volltext 172: `archiv/todo-stand-2026-10-09.md`.
**Antworten auf Cursors Fragen:** (d) Verlassen ist im Testprozess nicht prüfbar — in Ordnung, `onHover` ist im Code entfernt, der Nutzer prüft in der App. (e) Fokusfarbe: Nutzer prüft in der App. Messung: **im Release-Build** wiederholen (siehe 173 b). (b) PixelProbe-Suiten **nicht** aus dem Lauf herausnehmen, sondern unter **eine** serielle Elternsuite legen (siehe 173 a). Ein `.serialized` je Suite reicht **nicht**: es ordnet nur die Tests innerhalb dieser Suite, verschiedene Suiten laufen weiter gleichzeitig.

**174. Live-Überwachung startet nach dem Erstlauf nicht (Nutzer 09.10., echte App, NO NAME-Stick) — VOR 173.**
*Befund (Claude, Protokoll `~/Library/Logs/Disk Index/diskindex.log`):* Nutzer hat 07:16 „Alle Speichermedien vergessen“, den Stick neu angesteckt, „Indizieren“ gewählt (07:17:27 `index start … abgleich=false`, 07:17:32 `lauf ende status=indexed`). Danach Datei umbenannt, Ordner angelegt, Ordner mit Tausenden Dateien kopiert → **kein einziger `watcher`-Eintrag**, Spalten bleiben alt. Letztes `watcher reread` im Protokoll: 06.10.
*Ursache:* `ChangeWatcher.start(…)` wird nur in `coordinator.onReconcileRequested` aufgerufen (`App/AppDelegate.swift` ~Z. 307–324, bekanntes Medium beim Anschließen). Der Pfad für ein **neues** Medium (`startIndex` → `coordinator.setIndexHandler`, ~Z. 303–306) startet den Lauf, aber **nie** die Überwachung. Erst Abziehen/Anstecken oder App-Neustart würde sie starten.
a) **Eine Stelle für „Überwachung starten“.** In `AppDelegate.swift` eine private Funktion `startWatching(id: UUID, volume: VolumeInfo) async` (liest `store.medium(uuid:)` für `fsEventsUUID`/`lastEventID` wie bisher, ruft `watcher.start(…)`). Aufrufen in: (1) `onReconcileRequested` (ersetzt den bisherigen Inline-Code), (2) `startIndex` (neues Medium nach „Indizieren“), (3) `appState.onReindexMedium` („Neu indizieren“). `start` ist durch `guard tasks[mediumID] == nil` schon doppelt-sicher, nichts daran ändern. Nicht starten für Medien mit Entscheidung „Nein“ (README Regel 4) — `startIndex` wird nur nach „Indizieren“ gerufen, das bitte im Status bestätigen (Datei:Zeile).
b) **Protokoll:** in `ChangeWatcher.start` nach dem Anlegen `DiskIndexLog.shared.record(.watcher, .info, "start medium=\(mediumID)")`, in `stop(mediumID:)` `"stop medium=\(mediumID)"`. Sonst keine neuen Protokollzeilen.
c) **Test (echtes FSEvents, kein Fake-`ChangeSource`):** neue Suite `LiveWatchAfterFirstIndexTests` (unter `WindowTestGroup` aus 173 a, falls schon vorhanden, sonst `.serialized`). Temporärer Ordner als Medium, Index-Lauf über **denselben Pfad wie ein neues Medium** (Index-Handler, nicht `onReconcileRequested`; dafür die Verdrahtung aus `AppDelegate` in eine testbare Funktion ziehen, z. B. `LiveWiring.connect(coordinator:service:watcher:store:appState:)` in neuer Datei `App/LiveWiring.swift`, `AppDelegate` ruft nur diese). Danach drei Fälle wie beim Nutzer, je Fall Warten auf Bedingung (`waitUntil`, höchstens 10 s): (1) Datei umbenennen → alter Name `removedAt != nil`, neuer Name vorhanden; (2) neuen Ordner anlegen → Zeile vorhanden; (3) Ordner mit 2.000 Dateien hineinkopieren → Ordner und `fileCount` stimmen. Zusätzlich: die Kinderliste der Spalte (`AppState`-Ladefunktion der Spalten) liefert den neuen Namen (Spalten-Cache wurde invalidiert). Sabotage: Aufruf (2) aus a entfernen → rot ✓.
d) **Echte App (Cursor):** Debug-App, Testvolumen aus dem System (nicht der NO NAME-Stick), vergessen → anstecken/einhängen → Indizieren → Datei umbenennen. Protokollauszug (`watcher start`, `reread`) in den Status, Foto der Spalte mit neuem Namen nach `Werkzeuge/screenshots/2026-10-09-174/`.
Status: a) `App/LiveWiring.swift` (connect + `startWatching`), `AppDelegate.swift` `startWatching` + Aufruf in connect; `ChangeWatcher.swift` Protokoll start/stop. `startIndex` nur nach „Indizieren“: `MediumCoordinator.swift:335-336` (`allowIndexing` → `requestIndex`). c) `LiveWatchAfterFirstIndexTests.changesAppearAfterFirstIndexRun` (hdiutil-Volume, Index-Handler), Sabotage ohne `startWatching` im Index-Handler: rot ✓.
d) Testvolume hdiutil `/Volumes/DI174v081705` (nicht NO NAME); Protokoll: `08:17:06.001 watcher info start medium=AB4C3942-7929-45FC-B379-8A32B43A3C5A`, danach `lauf ende … status=indexed`. Foto: `Werkzeuge/screenshots/2026-10-09-174/spalte-nach-umbenennung.png`. Seriell 349 Tests, 87 Suiten grün (08:32). Bereit zur Prüfung.

**173. Paralleler Testlauf grün, Messung Sprach-Dropdown im Release.**
a) **Fenster-Tests nacheinander.** Neue Datei `diskindexTests/WindowTestGroup.swift` mit genau `@Suite(.serialized) @MainActor enum WindowTestGroup {}`. Jede Suite, die ein echtes Fenster öffnet (`PixelProbe`, `NSWindow`, `NSEvent`-Mausereignisse) **oder** gemeinsame Singletons nutzt (`NoticeThrottle.shared`, `SystemNotice.testPostHandler`, `UserDefaults.standard`), wird als verschachtelte Suite eingehängt: `extension WindowTestGroup { @Suite struct ColumnChromeTests { … } }` (Inhalt unverändert, nur die Hülle). `.serialized` an der Elternsuite gilt für alle eingehängten Suiten. Mindestens: alle 16 Dateien mit `PixelProbe`, `ConfirmButtonTimeoutTests`, `NoticeToggleOrderTests`, `ColumnAndSearchTests`, `SurfaceStoreTests`. Liste der eingehängten Suiten in den Status. Keine Testlogik ändern, keine Wartezeit verlängern, keine Tests löschen oder deaktivieren.
*Kriterium:* seriell grün (gleiche Testzahl 348), **und** paralleler Gesamtlauf dreimal hintereinander grün, Zeiten im Status. Bleibt danach ein Test parallel rot: Name, Fehlermeldung und Zeile als „Frage:“ melden, nicht weiter umbauen.
b) **Sprach-Dropdown im Release messen.** Dieselbe Messung wie 172 e (Klick → Feld sichtbar), einmal im Release-Build, je 5 Werte für „erstes Öffnen“ und „weitere Öffnungen“ in den Status. Keine Codeänderung in b. Liegt das erste Öffnen im Release über 17 ms: als „Frage:“ melden mit dem größten Posten aus Instruments (Time Profiler, Hauptthread), nicht selbst umbauen.

Status: a) `WindowTestGroup.swift`; eingehängt: ColumnChromeTests, LanguagePickerTests, ProgressHoldTests, SettingsTabSwitchTests, ToolbarFillTests, ColumnStatusIconTests, AutostartToggleTests, ReindexGateTests, MenuBarRowHeightTests, LayoutCheckboxTests, ColumnDemoIsolationTests, ColumnLoadingBorderStableTests, ProgressDisplayTests, ColumnVerticalLayoutTests, ColumnAndSearchTests, SurfaceStoreTests, NoticeToggleOrderTests, LiveWatchAfterFirstIndexTests, ConfirmButtonTimeoutTests. Seriell 349 Tests, 87 Suiten grün (08:32). Parallel 3×: 98 s / 99 s / 99 s, nicht grün (je 1–2 rot).
Frage: Parallel rot `ChangeWatcherTests/newFolderWithFilesIsReadAfterQuiet()` (4–5 s Timeout, Flake mit LiveWatch/hdiutil?), einmal `rootChangeDoesNotRereadSubfolders()`. b) `xcodebuild test -configuration Release` für `diskindexTests` scheitert am Modul `diskindex` (Testhilfen/Debug) — Release-Messung nicht ausführbar ohne Vorgabe.

**Reihenfolge 174 → 173. HALT nach 173.**

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
