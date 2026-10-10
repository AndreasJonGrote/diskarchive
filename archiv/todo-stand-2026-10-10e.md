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
17. **Fotos selbst prüfen.** Jedes Foto im Status vorher öffnen; zeigt es nicht das Verlangte (Sperrbildschirm, falsches Fenster, leerer Inhalt), neu aufnehmen. Ein falsches Foto = Aufgabe nicht gemacht.
18. **Keine Nachhilfe in End-to-End-Tests.** Ein Test, der eine Kette beweisen soll (Platte → FSEvents → Store → Meldung → Spalte), darf keinen Schritt dieser Kette selbst aufrufen (`flushIndexChange`, `scheduleIndexChange`, `invalidate`, `requestLoad`, `loadChildren` als Ersatz für die Anzeige). Er wartet nur und liest das Ergebnis. Geht es ohne Nachhilfe nicht, ist das ein Befund → „Frage:“.
19. **Bildschirm des Nutzers frei lassen (Nutzer 09.10.: „keine Screenshots, nur Script-Prüfung“, gilt bis auf Widerruf).** Keine echte App starten, keinen `ScreenshotRunner`, keine Bildschirmfotos, nichts aktivieren oder in den Vordergrund holen. Nachweis nur über `xcodebuild test` (mit Zeitgrenze), Protokolldateien und Skripte (`sqlite3`, `grep`). `PixelProbe`-Fenster werden **außerhalb des sichtbaren Bereichs** geöffnet (Ursprung `x: -20000, y: -20000`, `orderFrontRegardless` statt `makeKeyAndOrderFront`, nie `NSApp.activate`); `cacheDisplay` funktioniert dort genauso. Echte-App-Teilaufgaben (z. B. 183 e) entfallen und werden durch einen Skript-Nachweis ersetzt (siehe dort).
20. **Tests stürzen nie ab.** Kein Zugriff `array[i]` ohne vorheriges `try #require(array.count > i)` (bzw. `#require(array.first)`), kein `!` auf Optionals, keine Bereiche `a..<b` ohne Prüfung `a <= b`. Ein fehlgeschlagener Test meldet „rot“, er beendet nie den Prozess (sonst Absturzbericht auf dem Bildschirm des Nutzers, Regel 19). Vor „Bereit zur Prüfung“: `grep -n '\[0\]\|\[1\]\|\[2\]' diskindexTests/<neue Dateien>` und jede Stelle absichern.
21. **Keine System-Ereignisse aus Tests.** Verboten: `CGEvent(…).post(…)`, `CGWarpMouseCursorPosition`, `AXUIElement…`, alles, was die **echte** Maus/Tastatur des Nutzers bewegt oder Bedienungshilfen-Rechte braucht (Nutzer 09.10. 23:00: macOS fragte „Disk Archive möchte diesen Computer mit Funktionen der Bedienungshilfe steuern“). Klicks nur per `NSEvent.mouseEvent(…)` + `window.sendEvent` an das **eigene** Testfenster (wie `PixelProbe.click`). Kein `makeKeyAndOrderFront`, kein `NSApp.activate` (Regel 19).
22. **Kein Git, kein GitHub (AGENTS.md).** Keine verändernden Git-Befehle (`commit`, `add`, `push`, `pull`, `checkout`, `stash`, `worktree`, `reset` …), keine Best-of-N-Läufe mit Git-Arbeitskopien, nichts auf GitHub. Nur `git status`/`log`/`diff`/`show` zum Nachsehen.
23. **Zum Schluss die App bauen, die der Nutzer startet (Nutzer 10.10.).** Letzter Schritt jeder Aufgabe, **nach** Sabotage-Rücknahme und Testläufen: `xcodebuild build -project diskindex.xcodeproj -scheme diskindex -configuration Debug -destination 'platform=macOS'` **ohne** `-derivedDataPath` (Ziel: `~/Library/Developer/Xcode/DerivedData/diskindex-…/Build/Products/Debug/Disk Archive.app`, dort startet der Nutzer). Dann belegen: `stat -f '%Sm' -t '%H:%M:%S'` der Datei `Contents/MacOS/Disk Archive` ist **jünger** als die zuletzt geänderte `.swift`-Datei (`find diskindex -name '*.swift' -newer <App-Binary>` muss **leer** sein). Beide Uhrzeiten in den Status. Ohne diesen Beleg gilt die Aufgabe als nicht gemacht. Grund: Am 10.10. testete der Nutzer einen Sabotage-Build, weil nach der Rücknahme nicht mehr gebaut wurde.

---

## A. Jetzt — Version 0.2 „Alle bekannten Fehler“

**Maßgeblich für Versionen und Reihenfolge: README, Abschnitt „Roadmap“** (ausführlich: [ROADMAP.md](ROADMAP.md), folgt der README). In A steht nur, was zur **laufenden Version (0.2)** gehört, also bekannte **Fehler**. Was nach dem Einfrieren auffällt und kein Fehler ist, kommt nach B mit Zielversion.

**Stand 10.10.:** Abgenommen bis 200 (siehe DONE.md). **Freigegeben: 201 → 202 → 203 (Aufräum-Paket nach Claude-Durchsicht 10.10.). HALT nach 203.** 204 wartet auf den Nutzer.

**Claude-Prüfung 10.10. (3):** 197–200 **abgenommen** (Umsetzung durch Ersatz-Agenten). Claude: `clean build-for-testing` **0** Warnungen; **380 Tests, 99 Suiten seriell grün**; App des Nutzers 09:58:19, keine neuere `.swift`-Datei (Regel 23 ✓). Volltext: `archiv/todo-stand-2026-10-10d.md`.

**Arbeitsregeln je Aufgabe (gelten zusätzlich zu den 23 Regeln):**
- **R1 Nur die genannten Stellen ändern.** Jede Aufgabe nennt Datei und Zeile. Andere Dateien nur, wenn die Aufgabe es sagt. Keine „Verbesserungen nebenbei“.
- **R2 Beweis = Pixel aus einem echten Fenster.** `hitTest != nil`, `source.contains(…)`, Zahlenvergleiche mit Konstanten und Prüfungen nur am Datenmodell zählen **nicht** als Beweis für Aussehen oder Klickverhalten. Benutze dafür ausschließlich die Hilfe `PixelProbe` (Aufgabe 150 a). Jeder neue Test wird einmal **sabotiert** und muss dann rot sein; im Status: „Sabotage: rot ✓“.
- **R3 Status je Aufgabe:** höchstens 5 Zeilen: geänderte Dateien:Zeilen, Testname, Ergebnis der Sabotage, Pfad der Bildschirmfotos (`Werkzeuge/screenshots/<JJJJ-MM-TT>-<aufgabe>/`).

### Liste der bekannten Fehler (0.2, Claude sammelt)

| Nr. | Fehler | Herkunft | Stand |
|---|---|---|---|
| 195 | `MustScanSubDirs` unter der Wurzel verlor Änderungen; `.counts` verwarf Spalten-Invalidierung | Claude-Prüfung 192 | **behoben** 10.10. |
| F1 | Testlücke: `BulkDirectoryReaderTests` (FAT-Abbild) endet mit `return` und meldet **grün**, wenn `hdiutil create/attach` scheitert (in Claudes Umgebung so geschehen) → prüft dann nichts. Soll: sichtbar überspringen oder rot. | Claude 10.10. | **behoben** 10.10. (197; Abbild 64m, Test lief vorher nie) |
| F3 | Waagerechte Scrollleiste liegt **auf** der Statusleiste und verdeckt den Pfadtext; senkrechte Leisten je Spalte fehlen (README „Spaltenansicht: Scrollen“, Nutzer 10.10.) | Nutzer 10.10. (Foto) | **behoben** 10.10. (198) |
| F4 | Detail-Spalte erscheint **ohne Auswahl**, sobald die Ordnerspalten breiter als das Fenster sind (README 5: nur bei Datei oder Mehrfachauswahl) | Nutzer 10.10. (Foto) | **behoben** 10.10. (199) |
| F5 | Demo-Medium „Spalten-Zustände (Demo)“ entfernen (Nutzer 10.10.: Layouts sind abgenommen, wird nicht mehr gebraucht) | Nutzer 10.10. | **behoben** 10.10. (200) |
| F6 | Fehlerdialog zeigt **nie** einen Grund: `IndexingService` meldet immer `reason: .unknown`; `IndexRunOutcome` trägt keinen Fehler, `IndexFailureReason.classify` wird nur von Tests benutzt (README 2b verlangt den Grund) | Claude-Durchsicht 10.10. | **freigegeben als 202** |
| F7 | Englisch unvollständig: feste deutsche Texte außerhalb von `L10n` (Kontextmenü, Menüleisten-Rechtsklick, Mitteilungen, Fehlergründe, Statuszeilen, Altersfilter, Fußzeile „x von y ausgewählt“, „Zuletzt indiziert“, Platzhalter) und feste `de_DE`-Formate | Claude-Durchsicht 10.10. | **freigegeben als 203** |
| F8 | Toter Code, nur von Tests benutzte Logik, Doppeltes | Claude-Durchsicht 10.10. | **freigegeben als 201** |
| F9 | Stresstest 1 TB (Nutzer 10.10.): erster Lauf zeigt **2 Minuten nichts** (Start 10:13:02, „ebene 1 fertig“ 10:15:02), weil die **Zählphase** (README 4) erst den ganzen Baum liest, bevor Ebene 1 geschrieben wird. Widerspricht „Schichten: erste Ebene sofort sichtbar“ | Claude, Protokoll 10.10. | **wartet auf Entscheidung des Nutzers** |
| F2 | Live-Überwachung am echten Stick nach 195 bestätigen: Umbenennen, neuer Ordner, Kopieren, Spalte bleibt sichtbar und aktualisiert sich | Nutzer 09.10. | **bestätigt** 10.10. (erster Test lief mit veraltetem Sabotage-Build → Regel 23) |

Weitere Fehler aus dem Alltag trägt Claude hier ein, sobald der Nutzer sie meldet.

---

**201. (F8) Toten Code und Doppeltes entfernen.** *Vor jedem Löschen:* `grep -rnw <Name> diskindex diskindexTests` → Ergebnis bestätigt die Lage unten. Weicht es ab: nicht löschen, „Frage:“.
a) **Nirgends benutzt (App und Tests) → löschen:** `ChangeWatcher.stopAll` (es bleibt `stopAllForTermination`), `DiskIndexLog.diagnosticReport`, `ScreenshotPlan.containsProposalRed`, `DesignButtonMetrics` (ButtonStyles.swift ~Z. 47–50), `GhostButtonStyle`, `DelayedLoadingState.Timing` (typealias), `DesignTokens.settingsActive`, in `LayoutCopy`: `languageGerman`, `languageEnglish`, `noticesText`, `filesFolders`, `uncapturedContentNotCaptured`, `folderLoadingProgressExample`; `ProposedCopyText`, `IndexingLimits` (IgnoreMatcher.swift ~Z. 128), `MenuBarPopoverLayout.rowHeightIndexing`, `Medium.filesFoldersLabel` (Medium+Detail.swift), `Medium.indexProgressStoredEntries`, `MediumAccess.resourceKeys`.
b) **Nur von Tests benutzte App-Logik → mit den zugehörigen Tests löschen** (diese Tests prüfen Code, den die App nie ausführt): `IndexRunGuard.capped`, `.nextProgress`, `.resumeDepth` (die App rechnet den Fortschritt in `DirectoryIndexer` selbst; `shouldPending` bleibt); `MenuBarPopoverLayout.pauseMenuVerticalOffset`, `.pausePanelExtension`, `.footerOpenAppTextInset`; `DestructiveButtonStyle`. `MenuBarPauseMenuPositioning.arrowTipAlignsWithToggle` ist ein Prüf-Prädikat → in die Testdatei verschieben, nicht löschen. Testnamen der gelöschten Tests in den Status.
c) **Doppeltes zusammenführen:** (1) Test-Erkennung über `XCTestConfigurationFilePath`/`XCTestSessionIdentifier` steht dreimal (`AppDelegate` ~Z. 186, `DiskIndexLog` ~Z. 50, `MediumCoordinator` ~Z. 424) → eine Stelle `RuntimeEnvironment.isRunningTests` (neue Datei `App/RuntimeEnvironment.swift`), drei Aufrufer. (2) `ContextMenuPlan.titles` (ColumnSelection.swift ~Z. 204) wiederholt die Menütitel, die `ObjectFileContextMenu` ohnehin selbst setzt → `titles` entfernen, Tests auf die Einträge des echten Menüs umstellen.
d) **Typen an den richtigen Ort:** `IgnoreMatcher.swift` enthält außer dem Matcher `IndexingRunLimits`, `IndexProgress`, `IndexRunOutcome` → in eine neue Datei `Indexing/IndexRunTypes.swift` verschieben (nur verschieben, nichts ändern).
e) **Ungenutzte Übersetzungsschlüssel** aus `Localizable.xcstrings` entfernen: `copy.menu.connected_heading`, `copy.notice.defaults_applied`, `copy.notice.forget_all`, `copy.notice.prune`, `copy.table.column.index`, `.name`, `.status`, `.type`. (Die `diagnostics.*`-Schlüssel und „Ebene %lld“ bleiben bis zur Entscheidung 204.)
f) Keine Sabotage (Entfernen). Testzahl vorher/nachher, Warnungen 0.

**202. (F6) Fehlergrund kommt im Dialog an.**
a) `IndexRunOutcome` bekommt `failureReason: IndexFailureReason?`. `DirectoryIndexer` setzt ihn dort, wo ein Lauf mit `.error` endet, **aus dem Fehlerobjekt**, nicht aus Text: POSIX `EACCES`/`EPERM` → `.permission`; Medium weg (`ENXIO`, `ENODEV`, `ENOENT` auf dem Einhängepunkt, oder Ereignis „ausgehängt“ während des Laufs) → `.disconnected`; Abbruch nach `consecutiveTimeoutLimit` → `.timeout`; `ENOSPC` oder SQLite `SQLITE_FULL` → `.diskSpace`; sonstiger Datenbankfehler (`DatabaseError`, `IndexStoreError.directoryWriteFailed`) → `.database`; sonst `.unknown`. Neue Funktion `IndexFailureReason.classify(_ error: Error)`. Die Text-Variante `classify(_ message: String)` und ihre Tests **löschen**.
b) `IndexingService.finish` (~Z. 225) übergibt `outcome.failureReason ?? .unknown` statt `.unknown`.
c) Tests: je Grund ein Lauf gegen ein Test-Medium mit eingespeistem Fehler (`MemoryVolume`/`setDirectoryWritesFailing`) → `appState.indexingFailure?.reason` hat den erwarteten Wert und die Grundzeile steht im Dialog (`PixelProbe`, Text vorhanden). Sabotage: `.unknown` fest zurück → rot ✓.

**203. (F7) Englisch vollständig, Formate nach App-Sprache.**
a) Alle für Nutzer sichtbaren Texte über `L10n` bzw. `LayoutCopy`, mit **de** (unverändert wie heute) und **en**. Mindestens: `ObjectFileContextMenu.swift` (alle Titel), `MenuBarController.swift` ~Z. 226–266 (Rechtsklick-Menü der Menüleiste), `SystemNotice.swift` ~Z. 131, 140 (Mitteilungen) und `IndexFailureReason.line` ~Z. 262–271, `MenuBarConnectedMediumRow.swift` ~Z. 96–114, `MenuBarPopoverView.swift` ~Z. 147, `SearchState.swift` ~Z. 22–30 (Altersfilter), `ColumnSelection.swift` ~Z. 132 („x von y ausgewählt“), `IndexedDateFormatting.swift` ~Z. 11, 21, `ObjectSearchField`/`MediumSidebarSearchField` (Platzhalter), `StatusChip.swift` ~Z. 109, `AppSettings.swift` ~Z. 204 (Beispiel Scan-Tiefe), `PauseDurationMenu.swift` ~Z. 172, `AppWindowPresenter.swift` ~Z. 46. Danach eigene Suche nach weiteren Stellen: `grep -rnE '"[A-ZÄÖÜ][a-zäöüß]+ [^"]*"' diskindex | grep -v 'DebugTools\|record(\|Logger\|L10n\|Localization/'` → Treffer, die Nutzer sehen, ebenfalls umstellen; Rest begründen.
b) **Englische Texte:** sachlich, kurz, macOS-üblich (z. B. „Show in Finder“, „Add to Favorites“). Ist ein Begriff unklar: **rot** als `ProposalCopy`-Vorschlag und „Frage:“. Liste aller neuen en-Texte als Tabelle in `docs/englisch-neu.md` (Nutzer prüft).
c) **Formate nach App-Sprache:** feste `Locale(identifier: "de_DE")` in `DisplayNumberFormat.swift` ~Z. 11, `GlobalPause.swift` ~Z. 43, `PauseDurationMenu.swift` ~Z. 170 → `AppLanguagePolicy.resolvedDisplayLanguage().localeIdentifier`. Die beiden gleichen „HH:mm“-Formatierer (GlobalPause, PauseDurationMenu) → **ein** Helfer.
d) Test: App-Sprache Englisch → Kontextmenü, Menüleisten-Menü, Altersfilter, Fußzeile, Fehlergrund und eine Mitteilung liefern die englischen Texte; Zahl 1234567 erscheint als „1,234,567“. Und ein Test, der alle `.swift`-Dateien außerhalb von `DebugTools/` nach dem `grep` aus a) durchsucht und bei neuen Treffern rot wird (Ausnahmeliste in der Testdatei, je Eintrag mit Grund). Sabotage: einen Titel zurück auf festen Text → rot ✓.

**Für 201–203:** nach jeder Aufgabe seriell grün (Zahl), am Ende parallel, Warnungen 0, zum Schluss **Regel 23**.
Status 201–203:
- 201: a) alle 21 Namen per `grep -rnw` nur als Definition bestätigt, gelöscht. b) gelöscht mit Tests: `pauseMenuOverlapsPanelByAnchor`, `pauseVerticalOffsetPlacesTopAboveAnchor` (Zeilen aus `panelHorizontalInsetMatchesLayout`, `standardActionButtonsShareHeight` entfernt; `progressNeverFalls…` → `threeConsecutiveTimeoutsSetPending`, `shouldPending` bleibt); `arrowTipAlignsWithToggle` in die Testdatei. c) neu `App/RuntimeEnvironment.swift` (die erweiterte Variante aus MediumCoordinator), `ContextMenuPlan.titles` weg (Test nutzt `multipleContextMenuGroups`, jetzt internal). d) `Indexing/IndexRunTypes.swift`. e) 6 von 8 Schlüsseln entfernt.
  Frage: `copy.table.column.type`/`.status` NICHT entfernt: `LayoutCopyTests.windowLinesFromTheLayoutAreInLayoutCopy` braucht „Typ“/„Status“ aus dem Katalog; sie werden jetzt von den Spaltenköpfen benutzt (203). Tests 380 → 378 (seriell grün). Bereit zur Prüfung.
- 202: `IndexFailureReason.classify(_ error:)` (SystemNotice.swift; POSIX/Cocoa/GRDB/IndexStoreError/DirectoryReadStalled), Text-Variante samt Test gelöscht; `IndexRunOutcome.failureReason` (DirectoryIndexer: alle `.error`-Enden + Timeout-Abbruch), `IndexingService.finish`. Neu `readRetryDelays` in `IndexingRunLimits` (nur damit Tests ohne 14-s-Wartezeit laufen). Tests `IndexFailureReasonTests` (Klassifikation, Lauf je Grund außer timeout, Dienst→Dialog, Grundzeile im Dialog). Sabotage `.unknown` fest + EACCES→unknown: rot ✓. 382 Tests grün.
  Frage: Der Timeout-Abbruch endet mit Status `.pending`, nicht `.error` → kein Fehlerdialog; so belassen?
- 203: Texte nach `LayoutCopy+Menus.swift` (+72 Schlüssel de/en im Katalog, Liste `docs/englisch-neu.md`), `DisplayNumberFormat`/`DisplayTimeFormat` nach App-Sprache (de_DE weg), ein HH:mm-Helfer; `L10n.languageOverride` (Task-lokal, nur für Tests). Tests `EnglishLocalizationTests` (5; Kontextmenü, Menüleiste, Altersfilter, Fußzeile, Fehlergrund, Mitteilung, 1,234,567; Quell-Scan mit Ausnahmeliste). Sabotage Titel fest / neuer Festtext: rot ✓.
  Frage: `ProposalCopy.swift` (rote Vorschlagstexte, ~25) und `UncapturedFolderContextHint` bleiben Deutsch (Ausnahme im Scan); englische Texte dazu brauchen deine Freigabe der deutschen. Englisch im Doc zur Prüfung.
- Gesamt: seriell 387 Tests grün (10:5x), parallel grün, Warnungen 0. Build 11:06:01, jüngste Swift 10:58:03 (`find` leer). Bereit zur Prüfung.

**204. Debug-Werkzeuge — wartet auf Entscheidung des Nutzers (nicht bearbeiten).** In `DebugTools/` liegen frühe Prototypen aus Aufgabe 35 (`AccessProbeSpike`, `BreadthScanSpike`, `FSEventsSpike`, `SQLiteSpike`, `VolumeListing`) hinter dem Debug-Menüpunkt „Index-Diagnose“ (`IndexDiagnostics*`), dazu `ColumnLoadBench` (`#if BENCH`, wird durch das Messwerkzeug 196 ersetzt) und `ScreenshotRunner` (Bildschirmfotos sind seit Regel 19 tabu; `ScreenshotPlan` wird noch von Tests gelesen). Claude-Empfehlung: Prototypen + Diagnosefenster löschen, `ColumnLoadBench` mit 196 ersetzen, `ScreenshotRunner` behalten, bis die neuen Layouts kommen.

---

### Vor 0.4: Voraussetzungen für die Weitergabe

Siehe README, Abschnitt „Roadmap“ (0.4). Cursor arbeitet nicht daran; die Liste steht in B unter 0.4. Merkhilfe für den Nutzer (bleibt hier):

- **Eigene Kopie auf einem anderen Mac (ohne Notarisierung, nur für den Nutzer selbst):** Xcode → Product → Archive → „Distribute App“ → „Custom“ → „Copy App“. Kommt die App per AirDrop/Mail/Cloud und blockiert macOS sie: `xattr -dr com.apple.quarantine "/Applications/Disk Archive.app"` (Pfad anpassen; per USB-Stick kopiert meist nicht nötig). Für andere Nutzer nur mit Developer ID + Notarisierung.

### Offen, ohne Cursor

- **Nutzer:** (1) Kurztest am Stick für 107: großen Ordner öffnen, Pfeiltasten, Mehrfachauswahl, Rechtsklick. (2) Layout nachziehen: alte Chip-Beschreibungstexte, Menüleisten-Symbol „blauer Spinner (Abgleich)“ (112 Punkt 3), Texte der roten Vorschläge (Debug-App prüfen). (3) Entscheiden: T5 (ausführliches Protokoll) freigeben?
- **Claude:** Layout (Stand 07.10.) gegen README abgleichen; danach neue Aufgaben für Cursor schreiben. Spezifikationen der abgenommenen Aufgaben: `archiv/todo-stand-2026-10-07.md`.

---

## B. Backlog (nicht freigegeben, Cursor arbeitet nicht daran) — nach Zielversion

### Ohne feste Version (klein)

- **V1. Versionsnummer.** `MARKETING_VERSION` von heute `1.0` auf **`0.1`** setzen (Debug und Release, App und Tests gleich), `CURRENT_PROJECT_VERSION` **automatisch erhöhen** (Build-Nummer, z. B. Build-Phase vor dem Kompilieren). **Keine Anzeige bauen:** Cursor meldet per „Frage:“, **wo** die Version heute in der App erscheint (Einstellungen, Fehlerbericht `app{version,build}`, Info-Fenster …).

### 0.3 — Neue Datenbankstruktur (Roadmap 0.3, `datenbank-konzeption.md`)

Reihenfolge: (1) Messwerkzeug 196 und Messung „vorher“ → (2) Architektur entscheiden (eine Datei oder Datei je Medium plus Register) → (3) Konvention Seitentabellen (`item_<funktion>`, `itemID`, `ON DELETE CASCADE`, `srcSize`, `srcModifiedAt`, `extractorVersion`; Thumbnails in eigener Datei) → (4) Zuschnitt `item`/`medium` → (5) Schema neu, Abfragen umstellen (erst Schreib-, dann Lesewege, kleine Aufgaben mit Zwischenabnahme) → (6) Messung „nachher“ gegen die Schwelle → (7) Altlasten entfernen.

**196. Messwerkzeug Datenbank (Roadmap 0.3, README; Grundlage: `datenbank-konzeption.md`, Empfehlung Schritt 1). Nur messen, nichts am App-Schema ändern.**
*Zweck:* Zahlen für die Architektur-Entscheidung (eine Datei vs. Datei je Medium, Zuschnitt `item`, Pfad speichern oder berechnen). Dieser Lauf misst den **heutigen** Stand („vorher“).
a) **Ort und Start:** neue Datei `diskindexTests/IndexBenchTests.swift`, Suite mit `.enabled(if: ProcessInfo.processInfo.environment["DA_BENCH"] == "1")` → im normalen Lauf **übersprungen**. Start: `TEST_RUNNER_DA_BENCH=1 xcodebuild test -scheme diskindex -destination platform=macOS -only-testing:diskindexTests/IndexBenchTests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 3600`. Skript `Werkzeuge/db-messung.sh` mit genau diesem Aufruf. Kein Fenster (Regel 19).
b) **Speicherplatz:** Datenbank im Temp-Ordner; **vorher** freien Platz prüfen — unter **15 GB** frei: Test bricht mit klarer Meldung ab (Mac des Nutzers hat ~25 GB frei). Nach dem Lauf Temp-Datenbank löschen.
c) **Daten (synthetisch, reproduzierbar, fester Zufallsstartwert)** über die **echten** Schreibwege (`IndexStore.applyDirectories` in Blöcken wie der Indexer), nicht per Roh-SQL:
- **S1:** 1 Medium, **1.000.000** Einträge, Tiefe bis 6; darunter Ordner mit genau 100, 5.000 und 50.000 Kindern.
- **S2:** **300** Medien, zusammen **9.000.000** Einträge: 1 × 3 Mio., 20 × 200.000, Rest gleichmäßig.
Namen realistisch (Länge 4–60, Umlaute, Leerzeichen), Endungen nach Verteilung (jpg 30 %, pdf 10 %, mov 5 %, txt 10 %, ohne 15 %, Rest gemischt), `modifiedAt` über 10 Jahre, `sizeBytes` 1 KB–4 GB.
d) **Messen** (je Median aus 5 Läufen, Zeiten in ms), für S1 und S2:
- Schreibdurchsatz beim Erzeugen (Einträge/s); zwei Medien **gleichzeitig** schreiben (Durchsatz je Medium und gesamt).
- Öffnen der Datenbank kalt (`IndexDatabase` öffnen inkl. `quick_check`) — getrennt: Zeit mit und ohne `quick_check`.
- Spaltenansicht: `childCount` + erste Seite `childrenPage` und **alle** Seiten für 100 / 5.000 / 50.000 Kinder.
- Suche über alle Medien: `search` (Limit 500) und `searchCount` für einen häufigen Begriff (3 Zeichen) und einen seltenen (8 Zeichen); jeweils ohne Filter, mit Dateityp-Filter (pdf), mit Alters-Filter (letzte 30 Tage), mit beiden.
- `favorites` bei 1.000 Favoriten verteilt über alle Medien.
- `deleteMedium` für das 3-Mio.-Medium (S2) und anschließend Dateigröße vor/nach `incremental_vacuum`.
- `pruneToMatch` nach Verringern der Scan-Tiefe um 1.
- Größe: Datenbankdatei, WAL, Anteil `item`, Indizes, `item_fts` (`dbstat` bzw. `PRAGMA page_count`), und **Bytes der Spalte `path`** gesamt (`SUM(LENGTH(path))`).
e) **Ausgabe:** `Werkzeuge/messung/2026-10-<TT>-vorher.md` (Tabelle je Messpunkt, Rechner, macOS, Laufzeit gesamt) und dieselben Werte als `.json`. Die Datei kommt ins Repository (klein).
f) Kein Sabotage-Nachweis nötig (Messung, kein Prüftest). Normaler serieller Lauf bleibt grün und **unverändert schnell** (Suite übersprungen); Warnungen 0.
Status: (noch nicht freigegeben)

### 0.4 — Letzte Fixes, Beta für Beta-Tester

- **Signatur und Notarisierung:** Release signiert heute mit „Apple Development“ (`CODE_SIGN_IDENTITY`). Nötig: **Developer ID Application** + Notarisierung (`notarytool`) + Stapeln (Bezahl-Mitgliedschaft Apple Developer Program). Hardened Runtime ist an, Sandbox aus.
- **Download-Seite** auf `https://diskarchive.app/` mit stabilem Link (Nutzer, nicht Cursor).
- **Versions-Check:** `version.json` bzw. `GET …/api/version/` (existiert), Dialog „Neue Version verfügbar“ **einmal je Version**, Link **nur** auf `diskarchive.app`, Schalter in den Einstellungen; Datenschutztext, README 8 und 9 anpassen.
- **Beta-Verfallsdatum** mit freundlicher Meldung.
- **`FeatureAccess`:** zentrale Stelle „Darf der Nutzer das?“, in der Beta immer „ja“ (Vorbereitung 0.9).
- **macOS 14:** Mindestversion entschieden (184 erledigt); **Laufzeittest auf macOS 14** (z. B. VM) steht aus.
- **Fehlerbericht:** Ziel live `https://diskarchive.app/api/issues` (193 erledigt). **Datenschutz:** `ReportScrubber` ersetzt Pfade unter `/Volumes`, `/Users`, `~` und Anführungsnamen; `leakCategory` sperrt Versand bei Restpfaden. Test mit **echten Protokollzeilen** (`reread … /Volumes/NO NAME/…`).
- **Name:** „Disk Archive“, Bundle-ID `app.diskarchive` (185 erledigt).
- **Release-Prüfung:** Release-Build mit `DEAD_CODE_STRIPPING = YES`; Debug-Werkzeuge sauber abgegrenzt (`#if DEBUG`/`#if BENCH` in allen `DebugTools`-Dateien geprüft).
- **Update durch Ersetzen der App:** Bundle-ID und Datenordner gleich, Einzelinstanz-Übergabe nach Version (neuere übernimmt), Launch Agent beim Start neu registrieren.
- **Ab 0.4 echte Migrationen:** Sicherungskopie vor jeder Migration, Schutz vor Rückschritt (GRDB `hasBeenSuperseded`, Namen prüfen).

### 0.5 — Metadaten und EXIF
Wartet auf das **Layout vom Nutzer** und eine eigene Besprechung (README Roadmap). Felder: `datenbank-konzeption.md`.

### 0.6 — Vorschaubilder
Eigene Datei, **Abschalter global und je Medium**. Größe laut README **250 px** lange Seite (Nutzer 10.10.). Wird vor dem Start besprochen.

### 0.7 — CSV-Export
Noch nicht ausgearbeitet; vier offene Fragen in README (Roadmap).

### 0.8 — Duplikate
Über alle Medien, stufenweise, nur im Hintergrund (README).

### 0.9 — Lizenz
Nach Medienzahl **1 / 50 / 250**; offene Fragen in README.

### Ohne Zielversion (wartet auf Entscheidung des Nutzers)

- **T1. Ladehinweis erst nach 1 s** (Nutzer 06.10.): gehört zu 107; Suche/Favoriten später.
- **T2. Programme als Dateityp „Programme“** (`.app`-Pakete, dmg, pkg).
- **T3. Erweiterte Dateityp-Icons** (Styleguide Sektion 15).
- Cursor hat T1–T3 vorzeitig gebaut; Claude entscheidet bei der Prüfung, was bleibt.
- **T5 (Vorschlag Claude, wartet auf Nutzer): Ausführliches Protokoll („Diagnose-Modus“).** Es gibt schon `~/Library/Logs/Disk Index/diskindex.log` (Kategorien, `crash-last.txt`, „previous run ended without clean exit“). Lücken: (1) **Beenden wird nicht protokolliert** (`applicationShouldTerminate` schreibt nichts; nur `applicationWillTerminate` „app terminate ok“) → Zeilen „quit requested (Quelle)“, „quit: status item entfernt“, „quit: Indizierung gestoppt“ mit Dauer. (2) **Haupt-Thread-Wächter:** blockiert der Hauptfaden > 2 s, Zeile `hang main ms=…` mit Stack (Release tauglich). (3) **Schalter** „Ausführlich“ (Erweitert, nur Debug oder per `defaults`) für Pegel `debug`: je Medium Dauer von Lesen/Schreiben, Cache-Treffer, Ladezeiten Spalten, Speicher. (4) `crash-last.txt` auch bei Beenden durch Signal. Nicht freigegeben.
