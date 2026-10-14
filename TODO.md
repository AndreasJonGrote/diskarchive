# TODO.md — offene Aufgaben und Fehler

Einzige Aufgabenliste. Erledigtes: [DONE.md](DONE.md). Verlauf und alte Fassungen: `archiv/`. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). Versionsplan: README „Roadmap“, ausführlich [ROADMAP.md](ROADMAP.md). **Komponenten (Maße, Farben, Zustände): [layout/Komponenten.dc.html](layout/Komponenten.dc.html), zusammengefasst in [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md).** Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

## Kennungen (Nutzer 14.10.)

- **`todo.<Version>.<Nr>`** = Aufgabe (Funktion, Politur, Doku, Entscheidung).
- **`bug.<Version>.<Nr>`** = Fehler.
- `<Version>` ist die **Zielversion** aus der Roadmap (`0.4`, `0.3.2` …), `<Nr>` dreistellig und je Art und Version fortlaufend (Beispiel: `bug.0.4.014`). Die Kennung steht im Status, im Commit und in DONE.md. Fehler-Nummern aus dem Audit 13.10. (`REPORT 54` …) stehen im Archiv `archiv/report-audit-2026-10-13.md`; jede Aufgabe nennt ihre Nummern.
- **Host ist Claude.** Umsetzer (Cursor oder ein anderer Agent, auch auf einem anderen Gerät) arbeiten, Claude prüft und nimmt ab (Regel 28). `REPORT.md` bleibt leer; Fehler werden direkt hier als `bug.*` eingetragen.

## Regeln für den Umsetzer (verbindlich)

1. **Nur freigegebene Aufgaben aus „A. Jetzt“**, in der dort stehenden Reihenfolge. „B. Backlog“ und alles andere nicht anfassen, auch nicht „vorbereiten“.
2. **Nach jedem Paket anhalten** (Zeile „HALT“). Erst weiterarbeiten, wenn Claude in A. freigegeben hat.
3. **Nichts erfinden.** Kein Feature, Text, Schalter, Screen ohne Vorgabe in README oder Layout. Fehlt etwas: Frage unter die Aufgabe schreiben („Frage:“), nicht bauen. Nötige Texte ohne Layout-Vorlage (ab 11.10., Nutzer): normal über `L10n`/`LayoutCopy` mit de und en anlegen und im Status als „Neue Texte:“ auflisten; der Nutzer prüft sie. Keine roten Vorschläge mehr.
4. **Layout, README, ROADMAP, DONE.md und REPORT.md sind schreibgeschützt** für den Umsetzer (auch `AGENTS.md`, `archiv/`). Abweichung gefunden → als „Frage:“ melden, nicht selbst „angleichen“.
5. **Diese Datei:** Der Umsetzer ändert nur das Feld „Status“ der jeweiligen Aufgabe (höchstens 5 Zeilen: was, welche Dateien, Abweichung). Keine Reviewblöcke, keine neuen Aufgaben, nichts umsortieren, nichts löschen. Claude räumt auf.
6. **Keine Selbstfreigabe.** Umsetzer schreibt „Bereit zur Prüfung“, nie „fertig“. Nur Claude verschiebt nach DONE.md.
7. **Belege statt Behauptungen:** „Tests grün“ nur mit Zahl, Uhrzeit, Kommando. Bildschirmfotos nur melden, wenn sie in diesem Lauf neu erzeugt wurden (Zeitstempel prüfen). Build Debug und Release ohne Warnung.
8. **Tests:** nur `-only-testing:diskindexTests`; nach **jeder Aufgabe seriell**, am **Ende des Pakets** zusätzlich einmal parallel. UI-Tests nicht starten (Passwortabfrage). Leistungszahlen nur im Release-Build.
9. **Kein Aufräumen, Verschieben oder Löschen** von Dateien, die nicht in der Aufgabe stehen. Kein Refactoring „nebenbei“.
10. **Echte Fenster testen, nicht nur Bilder.** Das Offscreen-Bildschirmfoto (`ScreenshotRunner`) beweist nicht, dass eine Ansicht im echten Fenster funktioniert (Beispiel: `NSTableView`-Zeilen waren im Foto da, im echten Fenster leer). Bei jeder Aufgabe, die Ansichten, Klickflächen oder `NSViewRepresentable` berührt: Test mit echtem `NSWindow` (`makeKeyAndOrderFront`, Layout abwarten, Zeilen/Knöpfe zählen, Klick per `hitTest` auf Randpunkte).
11. **Regression-Rauchtest** (`RegressionSmokeTests`, wird bei jeder Aufgabe erweitert): jede Ansicht, die schon einmal kaputt war, bekommt eine Zeile. Vor „Bereit zur Prüfung“ muss er grün sein. Eine Aufgabe, die etwas Abgenommenes wieder kaputt macht, gilt als nicht erledigt.
12. **Gemeinsame Bausteine nur zentral ändern** (Knopf, Chip, Zeile, Spaltenkopf, Leerzustand): eine Quelle, Änderung wirkt überall, Test an der Quelle. Keine zweite Kopie in einer Ansicht.
13. **Maße nur aus dem Komponentenkatalog** (`docs/Komponenten-Masse.md`, Quelle `layout/Komponenten.dc.html`). Keine eigenen Zahlen für Höhe, Innenabstand, Schrift, Rahmen, Radius. Jede Komponente hat einen Messtest gegen diese Zahlen (±0,5 pt), Hell und Dunkel.
14. **Nach Fehlern zurückrollen statt überbauen:** schlägt ein Test fehl, Ursache beheben, nicht Test abschwächen.
15. **Zeichenpfad sauber halten:** in `body`, `init`, `Binding(get:)`, `@State … = …` und `onAppear` **keine** Systemaufrufe (`SMAppService`, `UNUserNotificationCenter`, Dateisystem, Datenbank) und **keine** Zustandsänderungen. Solche Werte liegen in `AppState` und werden im Hintergrund aktualisiert.
16. **Zeilenangaben sind Richtwerte** („Z. ~“). Gilt eine Zeile nicht mehr, über den genannten **Symbolnamen** suchen; nichts an anderer Stelle „ähnlich“ ändern.
17. **Fotos selbst prüfen.** Jedes Foto im Status vorher öffnen; zeigt es nicht das Verlangte (Sperrbildschirm, falsches Fenster, leerer Inhalt), neu aufnehmen. Ein falsches Foto = Aufgabe nicht gemacht.
18. **Keine Nachhilfe in End-to-End-Tests.** Ein Test, der eine Kette beweisen soll (Platte → FSEvents → Store → Meldung → Spalte), darf keinen Schritt dieser Kette selbst aufrufen (`flushIndexChange`, `scheduleIndexChange`, `invalidate`, `requestLoad`, `loadChildren` als Ersatz für die Anzeige). Er wartet nur und liest das Ergebnis. Geht es ohne Nachhilfe nicht, ist das ein Befund → „Frage:“.
19. **Bildschirm des Nutzers frei lassen (Nutzer 09.10.: „keine Screenshots, nur Script-Prüfung“, gilt bis auf Widerruf).** Keine echte App starten, keinen `ScreenshotRunner`, keine Bildschirmfotos, nichts aktivieren oder in den Vordergrund holen. Nachweis nur über `xcodebuild test` (mit Zeitgrenze), Protokolldateien und Skripte (`sqlite3`, `grep`). `PixelProbe`-Fenster werden **außerhalb des sichtbaren Bereichs** geöffnet (Ursprung `x: -20000, y: -20000`, `orderFrontRegardless` statt `makeKeyAndOrderFront`, nie `NSApp.activate`); `cacheDisplay` funktioniert dort genauso. Echte-App-Teilaufgaben (z. B. 183 e) entfallen und werden durch einen Skript-Nachweis ersetzt (siehe dort).
20. **Tests stürzen nie ab.** Kein Zugriff `array[i]` ohne vorheriges `try #require(array.count > i)` (bzw. `#require(array.first)`), kein `!` auf Optionals, keine Bereiche `a..<b` ohne Prüfung `a <= b`. Ein fehlgeschlagener Test meldet „rot“, er beendet nie den Prozess (sonst Absturzbericht auf dem Bildschirm des Nutzers, Regel 19). Vor „Bereit zur Prüfung“: `grep -n '\[0\]\|\[1\]\|\[2\]' diskindexTests/<neue Dateien>` und jede Stelle absichern.
21. **Keine System-Ereignisse aus Tests.** Verboten: `CGEvent(…).post(…)`, `CGWarpMouseUmsetzerPosition`, `AXUIElement…`, alles, was die **echte** Maus/Tastatur des Nutzers bewegt oder Bedienungshilfen-Rechte braucht (Nutzer 09.10. 23:00: macOS fragte „Disk Archive möchte diesen Computer mit Funktionen der Bedienungshilfe steuern“). Klicks nur per `NSEvent.mouseEvent(…)` + `window.sendEvent` an das **eigene** Testfenster (wie `PixelProbe.click`). Kein `makeKeyAndOrderFront`, kein `NSApp.activate` (Regel 19).
22. **Kein Git, kein GitHub (AGENTS.md).** Keine verändernden Git-Befehle (`commit`, `add`, `push`, `pull`, `checkout`, `stash`, `worktree`, `reset` …), keine Best-of-N-Läufe mit Git-Arbeitskopien, nichts auf GitHub. Nur `git status`/`log`/`diff`/`show` zum Nachsehen.
23. **Zum Schluss die App bauen, die der Nutzer startet (Nutzer 10.10.).** Letzter Schritt jeder Aufgabe, **nach** Sabotage-Rücknahme und Testläufen: `xcodebuild build -project diskindex.xcodeproj -scheme diskindex -configuration Debug -destination 'platform=macOS'` **ohne** `-derivedDataPath` (Ziel: `~/Library/Developer/Xcode/DerivedData/diskindex-…/Build/Products/Debug/Disk Archive.app`, dort startet der Nutzer). Dann belegen: `stat -f '%Sm' -t '%H:%M:%S'` der Datei `Contents/MacOS/Disk Archive` ist **jünger** als die zuletzt geänderte `.swift`-Datei (`find diskindex -name '*.swift' -newer <App-Binary>` muss **leer** sein). Beide Uhrzeiten in den Status. Ohne diesen Beleg gilt die Aufgabe als nicht gemacht. Grund: Am 10.10. testete der Nutzer einen Sabotage-Build, weil nach der Rücknahme nicht mehr gebaut wurde.
24. **Kennung nennen.** Im Status und in Commit-Vorschlägen steht immer die Kennung (`bug.0.4.014`, `todo.0.4.010` …), bei Fehlern zusätzlich die REPORT-Nummer (Archiv `archiv/report-audit-2026-10-13.md`).
25. **Repro-Tests.** Nennt eine Aufgabe einen Repro-Test aus `Werkzeuge/audit-repro/ReproAuditTests.swift` (Ordner schreibgeschützt), wird der Test in eine passende Suite unter `diskindex/diskindexTests/` übernommen (`@Suite(.serialized) @MainActor`). **Vor dem Fix ausführen und das Rot im Status belegen**, danach grün. Testname und Meldung dürfen angepasst werden, die Erwartung nicht.
26. **Parallelbetrieb.** Vor jeder Aufgabe `git status`. Sind `.swift`-Dateien geändert, die nicht von dir stammen (anderes Gerät oder anderer Agent arbeitet), **anhalten** und „Frage:“ schreiben. Keine fremden Änderungen überschreiben.
27. **Schema nach 0.3 nur erweitern** (README, Abschnitt „Datenbank“): neue Migrationen, neue Indizes, neue Schlüssel; keine bestehende Tabelle umbauen.
28. **Abnahme nur durch Claude (Host).** Der Umsetzer kann auf einem anderen Gerät arbeiten; Claude prüft Code, Build (0 Warnungen), seriellen Gesamtlauf und Regel 23 und trägt die Aufgabe erst dann in DONE.md ein. Eine Selbstabnahme (wie in der früheren „Cursor-Spur“) gilt nicht.
29. **Signatur.** Ohne gültiges Zertifikat baut man für Tests mit `CODE_SIGN_IDENTITY="-"`; Regel 23 verlangt dann das Zertifikat für den Nutzer-Build, den baut Claude.
30. **Antwort mit Prompt und Commit.** Jeder Bericht des Umsetzers endet mit zwei Teilen: (1) einem **Prompt für Claude** in einem Codeblock, höchstens 12 Zeilen: Kennungen und „Bereit zur Prüfung“ oder „Blockiert: …“; geänderte Dateien je Aufgabe; Belege (Warnungen, Testläufe mit Art, Zahl und Uhrzeit, Sabotage rot ✓, Regel 23 mit beiden Uhrzeiten); offene „Frage:“; letzte Zeile „Prüfe die genannten Aufgaben nach Regel 28 und gib mir den nächsten Prompt.“ (2) einer **Commit-Nachricht** in einem eigenen Codeblock (eine Zeile, beginnt mit den Kennungen). Der Nutzer committet selbst (Regel 22). Der aktuelle Auftrag steht allein in [PROMPT.md](PROMPT.md); der Umsetzer ändert diese Datei nicht.

---

## A. Jetzt

**Stand 14.10.2026.** Die Xcode-Version steht noch auf **0.2.0**; gebaut sind **0.3** (Datenbank), **0.3.1** (API-Warteschlange), der **Code von 0.3.2** (Erkennung/Dashboard) und von **0.4** der Versions-Check mit Update-Modal und Beta-Sperre (alles in DONE.md). Gesamtlauf am 14.10.: 554 Tests seriell grün, 23 Compiler-Warnungen. **Freigegeben: Paket 0 (`bug.0.4.010`, `bug.0.4.043`, `todo.0.4.010`, `todo.0.4.011`, `todo.0.4.012`). HALT nach Paket 0.** Danach gibt Claude Paket für Paket frei, in der Reihenfolge der Tabelle. Mit 0.4 sind **alle Probleme erledigt** (README Grundsatz): Die Pakete 0 bis 7 sind das Tor zur Beta für Tester.

**Arbeitsregeln je Aufgabe (zusätzlich zu 1–30):** **R1** Nur die genannten Stellen ändern. **R2** Beweis = Pixel aus einem echten Fenster (`PixelProbe`); Sabotage → rot ✓. **R3** Status höchstens 5 Zeilen.

**Test- und Build-Kommandos:** Build `xcodebuild clean build-for-testing -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner>`; Warnungen zählen mit `| grep "warning:" | grep -v appintents | sort -u | wc -l` (Ziel 0). Tests `test-without-building … -only-testing:diskindexTests -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`. Danach den Ordner löschen.

### Reihenfolge der Pakete (Audit 13.10., Zweitprüfung Abschnitt D)

| Paket | Kennungen | Thema | Warum in dieser Reihenfolge |
|---|---|---|---|
| 0 | `bug.0.4.010`, `bug.0.4.043`, `todo.0.4.010`–`012` | Testbasis stabil, Warnungen 0, toter Code | ohne grüne, stabile Tests ist jede weitere Prüfung unsicher |
| 1 | `bug.0.4.011`–`012` | Datenschutz im Fehlerbericht | vor jeder Weitergabe zwingend |
| 2 | `bug.0.4.013`–`016` | Inventar und Favoriten (Datenverlust) | `013` muss vor der ersten Schema-Erweiterung stehen; `015` erst nach `013` und `014` |
| 3 | `bug.0.4.017`–`020` | Live-Überwachung | |
| 4 | `bug.0.4.021`–`025` | Medien-I/O und Datenbank nicht auf dem Haupt-Thread | beseitigt das Einfrieren („Spinning Ball“) |
| 5 | `bug.0.4.026`–`033` | Entscheidung, Status, Regeln, Identität | `014`, `028` teilen eine Wurzel (Status eines Laufs) |
| 6 | `bug.0.4.034`–`040` | Oberfläche | |
| 7 | `bug.0.4.041`–`042` | Absturzschreiber und Start | |

Die Pakete unten stammen aus dem Audit „claude seitenweise“ vom 13.10. und gelten **mit den Korrekturen der Zweitprüfung** (hier eingearbeitet). Neue sichtbare Texte sind nur über „Frage:“ erlaubt (siehe Entscheidungen unten); Regel 3 bleibt für sonstige Texte bestehen.

#### Paket 0 — Testbasis stabil

**bug.0.4.010 — Vier rote Tests stabil machen (REPORT 109).**
Ausgangslage: Voller Testlauf 586/590 grün. Rot sind `ItemIdentityTests/fatPartialDisambiguatesGoneCandidates`, `AutoSendToggleTests/autoSendPersistsInDatabase`, `ChangeWatcherTests/newFileAppearsAfterQuiet` und `ChangeWatcherTests/liveRenamePairMovesFolderAndShiftsChildDepth`.
- a) `DirectoryWriterV3.partialMatchingEnabled` (globales `nonisolated(unsafe) static var`) **durch einen Parameter ersetzen**, z. B. ein Feld im Writer bzw. `IndexStoreV3`, das nur Tests umstellen. Der Sabotage-Test in `ItemIdentityTests` Z. ~166 nutzt dann diesen Parameter. Danach darf die Suite parallel laufen, ohne dass sich Tests gegenseitig beeinflussen.
- b) `AutoSendToggleTests`: geteilten `AppSettingsRuntimeCache` je Test isolieren oder die Suite `.serialized`; feste 600 ms durch Warten auf die Bedingung ersetzen (`waitUntil`, Grenze ≤ 3 s).
- c) `ChangeWatcherTests`: Die 800-ms-Grenze in `waitFor` durch Warten auf die Bedingung mit Grenze ≤ 3 s ersetzen. Die Erwartungen bleiben unverändert (Regel 14).
- d) Zusätzlich die Warnungen aus REPORT 108 beheben, inklusive Testziel:
  - `checkpoint()` `nonisolated`
  - captured `var` in `IndexStoreV3` Z. ~210/815
  - `?? freelistBefore` (Z. ~219)
  - `loadLegacyPersisted`
  - `IndexingFinishCancelTests`, `IssueTrackerTests` Z. ~283, `AppSettingsPersistenceTests`
  - `AppState+VersionLock.swift:38` `variable 'notice' was never mutated` (neu, Claude 14.10.). Stand Claude 14.10.: **23 Warnungen**, seriell 554/554 grün (die vier Wackeltests zeigen sich nur im Parallellauf).

**Akzeptanz:** Drei volle Läufe hintereinander, einmal seriell und zweimal parallel, jeweils **alle grün**. Build Debug und Release ohne Warnung. Regel 23.
Status:

**todo.0.4.010 — Purge: toter Code (Claude-Suche 14.10., Wortzählung über `diskindex/` und `diskindexTests/`).**
- a) **Löschen** (kommt nirgends sonst vor, auch nicht in Tests): `AppVersion.majorMinor` (Z. 16) und `isNewerThanMajorMinor` (Z. 69), `AppWindowPresenter.closeNewMedium` (Z. 138), `FeatureAccess.unrestricted` (Z. 39), `MenuBarPopoverLayout.pauseMenuAnchorFromBottom` (Z. 35), `IndexStoreV3.purgeGoneItems` (Z. 548; dazu den Kommentar „für die Überwachung“ entfernen, REPORT E).
- b) **Nur von Tests benutzt, im App-Programm unnötig:** `IndexStoreV3+Reading` `columnFirstPageSQL` (Z. 117), `statusOfItem` (Z. 242), `searchMedia` (Z. 398), `storedNames` (Z. 408); `IndexStoreV3` `recordMaintenanceDebt` (Z. 185), `orphanCount` (Z. 108), `databaseFileBytes` (Z. 122); `IndexRepository.hasCachedChildren` (Z. 166). Je Fall: ohne Test-Nutzen → löschen samt Test; sonst als `extension` ins **Test-Ziel** verschieben. Nicht anfassen: `applyDirectory` (19 Tests; bug.0.4.015 c ersetzt es dort, wo es eine Kette beweisen soll).
- c) **Nicht löschen** (Falschtreffer der Suche): AppDelegate-Rückrufe, `windowWillClose`, `canBecomeKey/Main`, `mouseDown`-Überschreibungen.
- d) **Nicht anfassen, Entscheidung `todo.0.4.038`:** `DebugTools/ScreenshotRunner.swift` (708 Zeilen, Regel 19 verbietet den Lauf) und `PreviewData.swift`.
- **Akzeptanz:** `grep -rnw` auf jeden Namen aus a) → leer; Warnungen 0; seriell grün (Zahl vorher/nachher im Status; sie sinkt nur um gelöschte Tests, Begründung je Test).
Status:

**todo.0.4.011 — Start zeigt Menüleiste und Hauptfenster (Nutzer 14.10., ersetzt README 7 „Kaltstart: nur Menüleiste“).** Gehört zu Paket 0, nach `bug.0.4.010` und `todo.0.4.010`.
- a) **Kaltstart (Klick/Finder/Spotlight):** Menüleiste **und** Hauptfenster. Stelle: `AppLaunch.opensMainWindow(_:)` und der Aufruf in `AppDelegate` (Symbolnamen suchen, Regel 16). `launchKind == .click` öffnet das Hauptfenster; Fensterposition und -größe aus dem Frame-Autosave wie bisher.
- b) **Start beim Anmelden (`.login`):** weiter still, **außer** nach dem Versions-Check liegt ein Update-Angebot oder eine Sperre vor: dann öffnet das Hauptfenster **einmal** (nicht bei jedem Check, nicht wenn es schon offen ist). Das ist ein Vorschlag; der Nutzer bestätigt noch. Wird er abgelehnt, entfällt b).
- c) **Unverändert:** Dock-Reopen, Einzelinstanz-Übergabe (Zweitinstanz öffnet das Fenster der laufenden), Fenster schließen = Hintergrund, Dock-Symbol bleibt.
- **Tests (keine echte App starten, Regel 19):** `AppLaunch.opensMainWindow(.click) == true`, `.login == false`; Test mit Meldung bei `.login` → `true`, ohne → `false`; echtes `NSWindow` außerhalb des Bildschirms (Regel 10). Sabotage `.click → false` → rot ✓. Warnungen 0, seriell, Regel 23.
Status:

**todo.0.4.012 — Erkennungs-Panel „Neues Speichermedium“: immer Standardposition (Nutzer 14.10.).**
- a) Die Position des Panels wird **nicht gemerkt**: kein Frame-Autosave, kein Wiederverwenden der letzten Lage. Jedes neue Erscheinen eines Panels startet an der Standardposition. Zieht der Nutzer es, bleibt es bis zum Schließen dort (kein erneutes Platzieren bei jedem `syncNewMediumPanels`).
- b) **Standardposition:** waagerecht **mittig** auf dem Hauptbildschirm (`NSScreen.main`, `visibleFrame`), senkrecht so, dass die **Mitte des Panels beim goldenen Schnitt oben** liegt (38,2 % der sichtbaren Höhe von oben gemessen, also leicht über der Mitte). Mehrere offene Panels: bestehenden Versatz `newMediumStackOffset` beibehalten, der neueste liegt vorn an der Standardposition.
- c) Stelle: `AppWindowPresenter.placeNewMediumPanel` (heute unten rechts mit `newMediumScreenMargin`). Die Konstante `newMediumScreenMargin` entfällt, wenn sie sonst nirgends gebraucht wird.
- d) Test mit der reinen Rechenfunktion (Frame aus `visibleFrame` und Panelgröße): Mitte x, Mitte y bei 38,2 %, mit und ohne Menüleisten-Versatz im `visibleFrame`, Versatz bei Stapel. Sabotage (alter Wert) → rot ✓. Warnungen 0, seriell, Regel 23.
Status:

**bug.0.4.043 — „Ja“ nach „Nein“ springt auf „Nein“ zurück (Nutzer 14.10., Medium zoom_h4e).** Ablauf: Erkennungs-Dialog mit „Für dieses Medium merken“ aus, „Nicht indizieren“; die Einstellungen zeigen Nein (richtig). Klick auf **Ja** (Einstellungen → Speichermedien): die Indizierung startet (richtig), aber der Schalter springt wieder auf **Nein**; erst der zweite Klick auf Ja bleibt stehen.
- **Vermutete Ursache (Claude, am Code gelesen, noch nicht belegt):** Der Schalter schreibt `decision`/`allowIndexing` nur in den Speicher (`AppState.updateMedium(persist: true)`), das Schreiben in die Datenbank ist um ca. 500 ms verzögert (`scheduleMediumWrite`). Gleichzeitig löst `onMediumDecisionChanged` → `MediumCoordinator.requestIndexingAfterDecision` aus, liest die **noch alte Zeile** aus der Datenbank (`allowIndexing = false`) und `publish(_:connection:)` schreibt sie in den Speicher zurück (`current.allowIndexing = medium.allowIndexing`). Danach schreibt `writeMedium` den richtigen Wert in die Datenbank, die Anzeige bleibt aber falsch. Gleiche Wurzel wie `bug.0.4.033` (Lesen → `await` → Zeile zurückschreiben).
- a) **Zuerst Repro-Test** (Regel 25): Medium `.dontIndex`, in der Datenbank gespeichert; `updateMedium(persist: true)` auf `.index`; `requestIndexingAfterDecision`/`publish` läuft vor `writeMedium` → erwartet `medium.allowIndexing == true` und `decision == .index` nach 2 s; Rot vor dem Fix belegen.
- b) **Fix:** `publish` überschreibt Nutzerfelder (`decision`, `allowIndexing`, `autoIndexPaused`, `isFavorite`, `showAbsoluteCapacity`) nicht, solange für das Medium ein Schreibvorgang aussteht (`pendingMediumWrites`), oder Entscheidungen werden **sofort** geschrieben statt entprellt. Der Auslöser nach der Entscheidung liest die Werte aus dem Speicher, nicht aus der Datenbank. Nicht erst `bug.0.4.033` abwarten; beide Fixes müssen zusammenpassen.
- c) **Akzeptanz:** Nein → Ja: Schalter bleibt auf Ja, Indizierung läuft, nach Neustart ebenfalls Ja. Ja → Nein → Ja gleiche Prüfung. Sabotage rot ✓. Warnungen 0, seriell, Regel 23.
Status:

**HALT nach Paket 0** — Freigabe durch Claude:

---

#### Paket 1 — Datenschutz im Fehlerbericht (vor 0.4 zwingend)

**bug.0.4.011 — Keine Namen, Pfade oder Fehlertexte mit Namen im Datei-Protokoll; Scrubber verlässlich (REPORT 54, 124, 91).**
- a) `DiskIndexLog.record`: `privateDetail` **nicht mehr in die Protokolldatei** schreiben. In der Datei steht stattdessen ` pathDepth=<n> pathLen=<utf8-Bytes>`. In `os_log` bleibt `privateDetail` `.private`.
- b) Datei-Protokoll ohne `error.localizedDescription` und ohne `\(error)` bei Datei-/Ordnerfehlern. Stattdessen eine technische Kurzform `domain=<NSError.domain> code=<code> posix=<code>`. Eine Hilfsfunktion an **einer** Stelle, alle Aufrufer umstellen. Der Grund: lokalisierte NSError-Texte enthalten Dateinamen in „…“. Fundstellen u. a.:
  - `ChangeWatcherEngine` Z. ~101/136
  - `DirectoryIndexer` Z. ~298/319/450
  - `MediumCoordinator` Z. ~141
- c) `os_log`: `message` standardmäßig `.private`, öffentlich nur feste technische Präfixe. Die Zeile `ui("search query=…")` (`AppState` Z. ~19) im `os_log` nicht mehr mit Suchbegriff.
- d) `ReportScrubber` als zweite Schicht:
  - Pfad-Regex bis Zeilenende (`(?:/Volumes|/Users|~|file://)[^\n]*`).
  - Typografische Anführungszeichen „…“ ‚…‘ «…» wie `"`/`'` behandeln.
  - `scrubRemainder` lässt nur selbst erzeugte Profile `‹(path|name|query) [^‹›]*›` durch, nicht jedes `‹…›`.
  - Deutsche Buchstaben (ä ö ü Ä Ö Ü ß) und typografischer Apostroph gelten als **gewöhnlich**, damit feste Meldungstexte samt Zeitstempel, ID und Status erhalten bleiben (124).
  - `ext=‹odd›` ohne Winkelklammern (`ext=odd`).
- **Tests:**
  - `ReportScrubber.text` mit `/Volumes/Jon's Passport/Clients/Acme Corp`, `/Volumes/A/My "Best" Photos`, `/Volumes/A/‹Kunde Acme›/x`, `file:///Volumes/O'Brien/x`, `Die Datei „Präsentation.key“ …` → weder `Passport`, `Acme`, `Photos`, `O'Brien` noch `Präsentation` im Ergebnis.
  - `2026-10-13T20:01:02Z medium info candidate=ja eingehängt id=1234 stärke=uuid` → Zeitstempel, `id=1234`, `stärke=uuid` bleiben.
  - `DiskIndexLog` in ein Testverzeichnis schreiben lassen, `record(…, privateDetail: "/Volumes/X/geheim")` → die Datei enthält `geheim` nicht.
- **Sabotage:** Pfad-Regex auf den alten Stand → rot.
Status:

**bug.0.4.012 — Leak-Wächter vor dem Senden wirksam machen (REPORT 55, Korrektur B-55).**
- a) `ReportScrubber.leakCategory` prüft den **dekodierten** Body: JSON parsen, alle String-Werte rekursiv prüfen auf `/Volumes/`, `/Users/`, `~/`, `file://`. Alternativ mit `.withoutEscapingSlashes` serialisieren und zusätzlich dekodiert prüfen.
- b) Namensabgleich (`knownNames`): Mediennamen aus der DB **beim Start einmal** im Hintergrund laden, nicht auf main, nicht beim Senden. Prüfung nur mit Wortgrenzen und mindestens 4 Zeichen. **Ausschlussliste:** App- und Image-Namen („Disk Archive“, „diskindex“, Systemframework-Namen aus Backtraces). Ein Medium „Disk“ oder „Archive“ darf keinen Bericht blockieren.
- **Tests:**
  - Payload mit `/Volumes/X/geheim` direkt in die Queue legen → `flush` → Zeile `blocked:leak=path`, kein Request beim Mock.
  - Medium „Archive“ registriert, Bericht mit Backtrace „Disk Archive“ → **nicht** blockiert.
  - Bestehender Test `IssueTrackerTests` Z. ~212–217 zusätzlich mit echt serialisiertem JSON.
Status:

**HALT nach Paket 1** — Freigabe durch Claude:

---

#### Paket 2 — Inventar und Favoriten (Datenverlust)

**bug.0.4.013 — Schema: Schutz vor Rückschritt + Teilindex für verschwundene Einträge (REPORT 101, 63, Korrekturen B-101, B-63).**
- a) `SchemaV3.openPool`: Vor `migrate` `try pool.read(migrator.hasBeenSuperseded)`. Bei `true` mit eigenem Fehler abbrechen; dieser läuft über den bestehenden Store-Fehlerdialog, ohne neuen Text (Regel 3: falls einer nötig ist, „Frage:“). **Muss in derselben Lieferung wie b) sein**, also vor der ersten Schema-Erweiterung.
- b) Neue Migration (eigener Name, nach `firstMigration`): `CREATE INDEX items_gone ON items(storageID, isFolder) WHERE status = 2`.
- c) `DirectoryWriterV3.matchGoneCandidate`: SQL mit **Literal** `status = 2` (nicht als Parameter), damit der Teilindex greift. Keinen Vorabtest je Writer zwischenspeichern.
- **Tests:**
  - Zeile `grdb_migrations('9.9-future')` einfügen → `openPool` wirft.
  - `EXPLAIN QUERY PLAN` der Kandidaten-Abfrage nennt `items_gone`.
  - Messtest (Release): FAT-Erstindex mit 50.000 Dateien gegen vorher, Zahl im Status.
Status:

**bug.0.4.014 — Abgebrochener Abgleich: kein Ebenen-Überspringen, keine Löschung verschwundener Einträge, Token aufräumen (REPORT 59, 58, 67, Korrekturen B-58, B-59).** Repro: `nr59_…`, `nr58_…`, `nr67_…`.
- a) Laufart merken: Ein Lauf ist ein **Abgleich**, wenn `!fromScratch && stored.indexStatus == .indexed && stored.completedDepth > 0` (Bedingung aus `DirectoryIndexer` Z. ~61).
  - Wird ein Abgleich angehalten (`stop()`: pause/cancel/none) oder über `IndexingService.cancel` abgebrochen, schreibt die DB **`.indexed`** (nicht `.pending`), und die UI zeigt `.indexed`.
  - Das Laufergebnis an `IndexingService.finish` muss trotzdem **„unterbrochen“** melden. Keine Meldung „vollständig indiziert“, kein `onRunIndexed`, keine Wartung (B-59).
  - Bei Erst- und „Neu indizieren“-Läufen bleibt `.pending` wie heute.
- b) `finishIndexing`: `deleteGoneItems` **nur**, wenn der Lauf vollständig endet (`.indexed` und nicht unterbrochen). Bei pending, error oder unterbrochen bleiben gone-Zeilen stehen (B-58: nur zusammen mit a).
- c) `beginIndexing`: Wirft der Schreibvorgang, das Token zurücksetzen (`if indexingToken[uuid] == token { … = nil }`), dann erneut werfen.
- **Akzeptanz:**
  - Medium `.indexed`, Abgleich nach Ebene 1 pausiert → DB `.indexed`, Folgelauf liest Ebenen 2…n (neue Datei auf Ebene 3 wird gefunden).
  - Favorit in gone-Unterbaum übersteht `.pending`.
  - Die drei Repro-Tests sind grün.
Status:

**bug.0.4.015 — FAT/exFAT/NTFS: Umbenennen/Verschieben außerhalb wieder verbinden (REPORT 110).** Voraussetzung: bug.0.4.013, bug.0.4.014.
- a) Für Medien ohne `trustsFileID`: **Verbindungs-Nachlauf am Laufende vor `deleteGoneItems`**.
  - Paare bilden aus „in diesem Lauf neu eingefügt“ (Kennzeichnung im Lauf, z. B. Menge der neuen IDs oder Zeitstempel) und `status = 2`.
  - Regeln wie heute: gleiche Art (Ordner/Datei/Paket), gleiche Größe, Datum ±FAT-Toleranz, gleiche Endung, bei Mehrdeutigkeit Teil-Prüfsumme. Ordner nur mit Name + Eltern (wie Nr. 34).
  - Bei **eindeutigem** Treffer: Die **alte** Zeile übernimmt Elternordner, Namen, Slug und Tiefe der neuen. Favorit, Meta und Prüfsumme bleiben an der alten ID, die neue Zeile wird gelöscht.
- b) Zusätzlich im `finalize` eines Ordners die im selben Ordner verschwindenden Zeilen (`status = 0`, nicht in `incoming`) **vorab** als Kandidaten für die Neueinträge desselben Ordners zulassen (Umbenennen im selben Ordner).
- c) Die Tests `ItemIdentityTests` mit künstlichem `applyDirectory(entries: [])` durch **echte Läufe** über `DirectoryIndexer` mit `MemoryVolume` ergänzen (Regel 18).
- **Akzeptanz (je ein Test, FAT-Medium, Favorit):**
  - `alt.txt` → `neu.txt` im selben Ordner: gleiche ID, Favorit bleibt.
  - `P/a.txt` → `Q/a.txt` (gleiche Ebene): wie oben.
  - `/A/B/x.txt` → `/x.txt` (nach oben): wie oben.
  - Zwei gleich große Kandidaten ohne Prüfsumme: **kein** Verbinden.
Status:

**bug.0.4.016 — fileID-Zweig im Writer: fremde gleichnamige Zeile, Tiefe der Kinder, Reihenfolge, Hardlinks (REPORT 57, 69, 129, 112).** Repro: `nr57_…` (beide), `nr69_…`.
- a) 57: `existingByName.removeValue(forKey: located.name)` nur, wenn `located.parentID == parentID`.
- b) 69: Im fileID-Zweig bei Ordnern mit geänderter Tiefe `shiftDescendantDepths(folderID:by:)`; gilt auch für den Watcher-Pfad (`finalize: true`).
- c) 129: `apply` in **zwei Durchgängen**: zuerst Einträge ohne Namenstreffer (fileID-Umbenennungen), dann Namenstreffer. Das Ergebnis darf nicht mehr von der Dictionary-Reihenfolge abhängen.
- d) 112: `ATTR_FILE_LINKCOUNT` in `BulkDirectoryReader` mitlesen (Feld in `ListedDirectoryEntry`/`ScannedEntry`). Bei `linkCount > 1`, bei Ordner-Hardlinks oder wenn dieselbe fileID im Listing mehrfach vorkommt, die fileID **speichern, aber nicht zum Verbinden/Verschieben** nutzen. Offset-Regel aus REPORT 96 beachten (Offset immer um die Attributgröße erhöhen).
- **Akzeptanz:**
  - Die Repro-Tests sind grün. `nr57_moveInto…` 30/30 fehlerfrei.
  - Umbenennen + neue Datei mit altem Namen: 30 Läufe mit stabilem Ergebnis (Favorit folgt der fileID).
  - Temp-Ordner mit `link()`-Hardlinks in zwei Ordnern: zweimal echter Lauf → zwei Zeilen mit stabilen IDs.
Status:

**HALT nach Paket 2** — Freigabe durch Claude:

---

#### Paket 3 — Live-Überwachung

**bug.0.4.017 — Live-Rename und Pfadabgleich korrekt (REPORT 56, 70, 113).** Repro: `nr56_…`, `nr70_…`.
- a) `DirectoryWriterV3.folderID(segments:)` dreiwertig (`.root` / `.found(id)` / `.missing`). In `applyLivePathRename` bei `.missing` auf einer Seite `return false`. Das verworfene `delta` (Z. ~284) über `commitMediumMeta` mitschreiben.
- b) `ChangeWatcher.flush`: Item-Events **vor** dem Paaren durch dieselbe Scope-Logik wie `directoryToReread` filtern (Matcher, Tiefe, `.Trashes`, ausgeschlossene Ordner). Eltern aus Paaren nur übernehmen, wenn sie im Scope liegen.
- c) 70: `applyLivePathRename` nur, wenn das Ziel dieselbe Datei ist. Bei `trustsFileID` muss der Inode von `stat(toPath)` gleich `row.fileID` sein; bei FAT gleiche Größe plus, falls gespeichert, gleiche Teil-Prüfsumme. Sonst `false`.
- d) 113: FSEvents-Pfade **nicht** über `URL(fileURLWithPath:).standardizedFileURL.path` normieren, sondern das Mount-Präfix als String abschneiden. Namensvergleiche in `folderID`/`fetchChildRows`/`IndexStoreV3.folderID` zweistufig: zuerst exakt; ohne Treffer über `slug` im selben Elternordner suchen und in Swift kanonisch vergleichen (`==`). Keine Schemaänderung.
- **Akzeptanz:**
  - Die Repro-Tests sind grün.
  - Papierkorb-Fall (`X/f` → `.Trashes/501/f`): kein `onFullReconcile`.
  - NFC-Ordner `Fotos M\u{00E4}rz`, Ereignis mit NFC-Pfad: Ordner wird gelesen, kein Voll-Abgleich, neue Datei im Index.
Status:

**bug.0.4.018 — Änderungen innerhalb von Paketen (REPORT 111).**
- Liegt ein Vorfahr des Ereignispfads als Paket vor (DB `isPackage = 1` bzw. `isFolder = 0` mit Paket-Endung, oder `URLResourceValues.isPackage` auf der Platte), wird **der Elternordner des Pakets** zum Neulesen eingereiht. Ereignisse unterhalb des Pakets werden verworfen, ohne `.needsFullReconcile`.
- **Akzeptanz:** Wurzel mit Paketzeile `X.app`, Ereignis `/Volumes/DISK/X.app/Contents/Info.plist` → `.ok`, Wurzel gelesen, kein `onFullReconcile`. Ebenso für `Y.photoslibrary/database/a.sqlite-wal`.
Status:

**bug.0.4.019 — Flush je Medium serialisieren (REPORT 64, 66, 99, 79).** Repro: `nr66_…`, `nr99_…`.
- a) Quiet-Timer und Flush trennen:
  - Der Quiet-Task trägt sich vor dem Flush aus `quietTasks` aus (66).
  - Ein Flush je Medium zur Zeit (`flushInFlight`). Kommt während eines Flushs ein Ereignis, folgt danach genau ein weiterer Flush.
  - Laufende Flushes werden nur in `stop`/`stopAllForTermination` abgebrochen, nicht durch neue Ereignisse (64).
- b) `ChangeWatcherEngine`: `CancellationError` gesondert behandeln. `pending` zurücklegen, **kein** `.needsFullReconcile`.
- c) 99: `IndexStoreV3.commitPendingMetaIfNeeded` entnimmt das Delta **vor** dem `await` und setzt es auf null, ebenso `lastMetaCommitTime`. Bei Fehler wieder addieren.
- d) 79: `ChangeWatcher.stop` leert `tasks`, `mounts`, `volumes` und `sources` **synchron vor** dem `await saveCursor` (Cursor vorher in eine lokale Variable). `applyPause`/`pauseChanged` serialisieren und nach jedem `await` `globalAutoIndexPaused` erneut prüfen.
- **Akzeptanz:**
  - Die Repro-Tests sind grün.
  - `BlockingListAccess` blockiert den ersten Flush, zweites Ereignis, freigeben → kein `onFullReconcile`, beide Ordner gelesen.
  - Pause an/aus schnell hintereinander mit verzögertem `recordEventCursor` → Watcher aktiv, Ereignis wird gelesen.
Status:

**bug.0.4.020 — Indexer: Schreib- und Lesefehler trennen, Halt sofort, Stall-Wächter (REPORT 123, 94, 77, 102).**
- a) 123: Schreibfehler aus `onChunk` als eigener Typ (`IndexWriteFailed`). `readFolderWithRetry` wirft ihn sofort weiter; der Lauf endet über `failWrite` mit `.error` (nicht „Ordner nicht lesbar“).
- b) 94: `DirectoryIndexInterrupted`, `CancellationError` und `IndexWriteFailed` werden ohne Wiederholung weitergeworfen. `folderEntries` und die Zählung werden je Versuch zurückgesetzt.
- c) 77:
  - Watchdog, der `DirectoryReadStalled` auch ohne eintreffenden Chunk auslöst. Die Stall-Zeit zählt ab dem letzten Lebenszeichen.
  - `continuation.onTermination` setzt ein Abbruch-Flag, das `BulkDirectoryReader.readStreaming` zwischen den `getattrlistbulk`-Aufrufen prüft (fd schließen), und bricht den inneren Task ab.
  - Bei `willUnmount` laufende Läufe des Mediums abbrechen.
- d) 102: `parentsFor` gibt DB-Fehler weiter (kein `try? … ?? []`), der Lauf endet `.error`.
- **Akzeptanz:**
  - Store, der beim Chunk-Schreiben wirft → Lauf `.error`, kein „nicht lesbar“, Dauer < 2 s.
  - Pause im ersten Chunk → genau ein Lesevorgang, ohne Wartezeit (heute ca. 14 s).
  - Fake-Stream, der nie liefert → `DirectoryReadStalled` nach `directoryStallTimeout`.
Status:

**HALT nach Paket 3** — Freigabe durch Claude:

---

#### Paket 4 — Medien-I/O und Datenbank nicht auf dem Haupt-Thread

**Hintergrund (verbindlich):** Im Build ist `NonisolatedNonsendingByDefault` aktiv (`SWIFT_APPROACHABLE_CONCURRENCY`). Eine `nonisolated … async`-Funktion ohne `@concurrent` läuft daher **auf dem Actor des Aufrufers**, also auf main, wenn der Aufrufer `@MainActor` ist. „async“ heißt hier **nicht** „Hintergrund“.

**bug.0.4.021 — Medienprüfung und Volume-Abfragen vom Main-Thread nehmen (REPORT 117, 118).**
- a) `DirectMediumAccess.probe` als `@concurrent` oder per Continuation auf eine eigene Queue (wie `listDirectory`). Zeitgrenze 5 s, danach `.denied(reason: "timeout")`.
- b) `MediumMonitor`:
  - Billig vorfiltern ohne Zugriff aufs Volume: `getfsstat(MNT_NOWAIT)` bzw. `.skipHiddenVolumes`, nur `MNT_LOCAL`, nur Präfix `/Volumes/`.
  - `VolumeLookup.info` und DiskArbitration auf einer seriellen Hintergrund-Queue; nur das Ergebnis auf main.
- c) DEBUG: `dispatchPrecondition(condition: .notOnQueue(.main))` in `probe`, `VolumeLookup.info`, `PartialChecksum.compute` und `BulkDirectoryReader`-Einstiegen.
- **Akzeptanz:**
  - Fake-`MediumAccess`, dessen `probe` 2 s schläft und `!Thread.isMainThread` prüft; `applicationDidBecomeActive()` → MainActor-Ticker läuft weiter.
  - Netz-/nicht lokale Einträge erreichen `info()` nie.
Status:

**bug.0.4.022 — Live-Watcher: `stat()` und Matcher nicht je Ereignis auf main (REPORT 119).**
- `LiveRenamePairs.pair`: `guard byPath.count == 2 else { return [] }` **vor** jedem `fileExists`.
- Paarbildung und `stat` im `ChangeWatcherEngine`-Actor statt auf main.
- `IgnoreMatcher` einmal je Flush bzw. Ingest bauen, nicht je Ereignis.
- **Akzeptanz:**
  - `pair` mit 10.000 Ereignissen und zählendem `fileExists` → 0 Aufrufe.
  - Test-Closure für `fileExists` mit `dispatchPrecondition(.notOnQueue(.main))`.
Status:

**bug.0.4.023 — Teil-Prüfsumme außerhalb von Store-Actor und Schreibsperre (REPORT 121).**
- `storePartialChecksum`: Datei außerhalb des Actors lesen (`@concurrent`-Helfer, Zeitgrenze), dem Actor nur das fertige Ergebnis zum Schreiben geben.
- `DirectoryWriterV3`: `incomingPartialDigest` und `resourceValues` **vor** `pool.write` berechnen.
- Favoriten-Tasks (`AppState+Favorites`) halten und in `prepareForTermination` abbrechen.
- **Akzeptanz:** Prüfsummen-Provider blockiert 5 s; parallel `childrenPage` und `search` jeweils < 100 ms.
Status:

**bug.0.4.024 — Fehlerbericht-Warteschlange: ein Pool, nichts Synchrones auf main, Offline richtig (REPORT 120, 75, 127, Korrektur B-75).**
- a) In `wireStore` `IssueReporter.shared.queuePool = store.pool`. Vor dem Öffnen der DB (Auto-Senden in `applicationWillFinishLaunching`) **nur in die Outbox** schreiben; die Übernahme läuft nach `wire`. Die Outbox-Datei erst nach erfolgreichem `enqueue` löschen (REPORT 90).
- b) Alle `IssueReporter`-DB-Arbeit (`enqueue`, `flush`, `queueHasWork`) auf eine serielle Queue bzw. in einen Actor; die UI ruft nur asynchron. Bestand aus `storages.fileCount + folderCount` statt `COUNT(*)`. `VersionCheckCoordinator` schreibt mit `await pool.write`.
- c) 75: Fehlversuche wegen fehlendem Netz (`URLError` `.notConnectedToInternet`, `.networkConnectionLost`, `.cannotFindHost`, `.cannotConnectToHost`, `.timedOut`) als `info = "offline"` speichern. `isDue` behandelt sie **ohne** Wartezeit als fällig. Achtung: `delay(afterAttempt: 0)` ist 1 h, „`attempts` nicht erhöhen“ reicht also nicht. Der 60-s-Timer läuft, solange nicht blockierte Zeilen existieren.
- d) 127: „Verwerfen“ im Absturzdialog fasst die Warteschlange nicht an (nur `acknowledgeCrashDialog`).
- **Akzeptanz:**
  - Hintergrund-Write hält 2 s; `enqueue` und `enqueueCheckIfNeeded` kehren auf main in < 100 ms zurück; Zähler der geöffneten Pools = 1.
  - Mock: erst `notConnectedToInternet`, dann 201; `onFlush` → Zeile gelöscht, ohne die Uhr vorzustellen.
  - „Verwerfen“ lässt eine ältere, zugestimmte Zeile stehen.
Status:

**bug.0.4.025 — Protokoll ohne `chmod`/`fsync` je Zeile (REPORT 122).**
- `FilePrivacy.restrict` nur beim Öffnen der Datei und bei der Rotation.
- `fsync` nur für Zeilen mit Fehler-, Absturz- und Ende-Status; sonst schreibt eine serielle Hintergrund-Queue.
- Die „lesen“-Zeilen des `BulkDirectoryReader` je Lauf zusammenfassen (eine Summenzeile).
- **Akzeptanz:**
  - Spion auf `restrict`: höchstens einmal je geöffneter Datei.
  - Lauf über 2.000 Ordner erzeugt höchstens 10 „lesen“-Zeilen.
  - `record` auf main bei parallelem Indexlauf < 1 ms im Mittel (Messung im Status).
Status:

**HALT nach Paket 4** — Freigabe durch Claude:

---

#### Paket 5 — Entscheidung, Status, Regeln, Identität

**bug.0.4.026 — Reprobe setzt keine Entscheidung zurück (REPORT 61).**
- `reprobeDeniedVolumes`: Medien mit `decision != .undecided` **nicht** über `storeAndPresent` führen.
  - Bei `.index`: Status `.indexed` (wenn `lastIndexedAt != nil`) bzw. `.pending` setzen und den passenden Lauf anstoßen (Abgleich bzw. `requestIndex`).
  - Bei `.dontIndex`: nur den Status setzen, keinen Lauf starten.
  - `decision = .undecided` nur für Medien, die schon unentschieden sind.
- Schnappschuss-Problem aus REPORT 132: Ist das Volume nach dem `await` nicht mehr in `mounted`, nichts tun (kein neues Medium anlegen).
- **Akzeptanz:**
  - `.index` + `.error` → `applicationDidBecomeActive()` → `decision` bleibt `.index`, kein Dialog.
  - Gemerktes `.dontIndex` + `.error` → bleibt `.dontIndex`.
Status:

**bug.0.4.027 — „Ja“ nach „Nein“ startet wieder (REPORT 60, Korrektur B-60).** Repro: `nr60_…`.
- `IndexingService.finish` und `cancel(mediumUUID:)` rufen `coordinator?.clearIndexRequest(mediumID:)` auf. **Nicht** die Variante „nur bis zum Start halten“: Sie würde Doppelanfragen in `rerunAfterFinish` schieben.
- **Akzeptanz:** Repro grün; Doppelanfrage während eines Laufs → genau ein Lauf.
Status:

**bug.0.4.028 — Status laufender Läufe nicht von außen überschreiben; Aufwachen ohne Doppel-Abgleich (REPORT 71, 72, Korrektur B-71).**
- a) `normalizeInterruptedIndexingStatuses` aus `loadStoredMedia` entfernen. Die Normalisierung nach Absturz (`indexing` → `indexed`/`pending`) läuft als SQL-`UPDATE` **beim Öffnen der DB vor `wire`**. Zur Laufzeit wird nicht normalisiert, `mediumLiveSyncIDs` wird nicht geleert.
- b) Aufwachen:
  - `MediumMonitor` sendet beim Aufwachen `.appeared` nur für Pfade, die nicht schon mit gleicher Identität in `mounted` stehen.
  - `connectKnown` ändert den Status eines bereits verbundenen Mediums nur, wenn `!service.isRunActive(id)`.
  - Der explizite Aufruf in `AppDelegate` (Z. ~248) entfällt, wenn sich der Pausenzustand dabei schon über `didSet` geändert hat.
- **Akzeptanz:**
  - Lauf aktiv → `resumeAfterRuleReconcile()` → Status bleibt `.indexing`, DB unverändert.
  - Medium verbunden und indiziert → `didWake` → **genau ein** `service.start`.
  - Lauf aktiv → `didWake` → DB-Status bleibt `.indexing`.
Status:

**bug.0.4.029 — Bereinigung „nach 1 Stunde“ wirklich nach Zeit und beim Start (REPORT 114).**
- Nach `hydrateSettingsFromStore()`/`loadStoredMedia()` `pruneIfDue()` aufrufen.
- `armPrune` und `loadPruneDeadline` planen einen Task bis `pruneAt`; ein neuer Termin ersetzt ihn.
- `pruneNow` löscht den Termin nur, wenn er seit Beginn der Bereinigung nicht neu gesetzt wurde.
- `didWake` bleibt zusätzlich.
- **Akzeptanz:**
  - `pruneAt` in der Vergangenheit, Start-Ablauf → bereinigt (ohne Aufruf von Hand, Regel 18).
  - Wache App mit injizierbarer Uhr/kurzer Frist → bereinigt ohne `didWake`.
Status:

**bug.0.4.030 — Regeländerungen wirken sofort und vollständig (REPORT 115, 68).**
- a) Bei jeder Scope-Änderung (`shrinks` oder `grows`, `AppState` Z. ~41–55) aktive Läufe abbrechen und mit **neuer** Konfiguration als Abgleich neu starten. Bei `grows` zusätzlich für jedes angeschlossene Medium mit `decision == .index` einen Abgleich anstoßen.
- b) 68: `reconcileScopeToStatus` setzt beim Verstecken eines Ordners den **ganzen Unterbaum** auf `status = 1` (rekursives CTE wie `markSubtreeGone`) und beim Wieder-Einblenden zurück, mit Neubewertung der Kinder. `purgeMarkedItems` sammelt die betroffenen `storageID`s und ruft danach `commitMediumMeta(forceRecount: true)`.
- **Akzeptanz:**
  - Lauf blockiert nach Ebene 1, `excludedPatterns += ["*.tmp"]`, freigeben → keine sichtbare `.tmp`-Zeile, `fileCount == COUNT(status=0)`.
  - `node_modules` mit 3 Dateien ausschließen → Suche nach einer davon liefert 0; nach `purgeMarkedItems` stimmt `fileCount`.
  - Tiefe 2 → 5+ bei fertigem, angeschlossenem Medium → Abgleich startet.
Status:

**bug.0.4.031 — Identität: Klone und Volume-Umbenennung (REPORT 116, 78).**
- a) 116: `volumeAppeared` verwirft einen Treffer, dessen Medium-ID schon unter einem **anderen, noch eingehängten** Pfad steht, und behandelt ihn wie mehrdeutig (neues Medium mit Dialog). Nie zwei Pfade für ein Medium.
- b) 78: `NSWorkspace.didRenameVolumeNotification` (`NSWorkspaceVolumeOldURLKey`/`NSWorkspaceVolumeURLKey`) als eigenes `MediumEvent`. Den Pfadschlüssel im Coordinator umbiegen, den Watcher mit neuem `VolumeInfo` stoppen und neu starten. Zusätzlich `kFSEventStreamCreateFlagWatchRoot` setzen.
- **Akzeptanz:**
  - Zwei `.appeared` mit gleicher `volumeUUID` und verschiedenen Pfaden → zwei IDs, Einträge des ersten unverändert.
  - Rename-Event → `volume(for:)` liefert den neuen Pfad; Unmount mit neuem Pfad setzt offline.
Status:

**bug.0.4.032 — Dialog-Entscheidung nach dem Abziehen (REPORT 73).**
- `applyChoice` veröffentlicht als Verbindung `volume(for:) != nil ? .connected : .offline`.
- `volumeDisappeared` ruft nach `publish(.offline)` `AppWindowPresenter.syncNewMediumPanels(appState:)` auf (nicht in Unit-Tests).
- **Akzeptanz:** `requestDialog` → `.disappeared` → `onNewMediumChoice(id, true, true)` → `connectionStatus == .offline`, Panel geschlossen.
Status:

**bug.0.4.033 — Medium-Zeile gezielt schreiben; Beenden verliert nichts (REPORT 62, 74, Korrektur B-74).**
- a) `MediumCodecV3.update` durch gezielte Setter je Feldgruppe ersetzen: Nutzerfelder (`isFavorite`, `decision`, `allowIndexing`, `showAbsoluteCapacity`, `autoIndexPaused`, `type`) und Erkennungsfelder (`name`, Kapazität, `lastSeenAt`). Indexer-Felder (Zähler, `indexStatus`, `completedDepth`, `first`/`lastIndexedAt`, `lastIndexActivityAt`, `fsEventsUUID`, `lastEventID`) schreiben nur Indexer und Watcher über ihre eigenen Wege. Alle Aufrufer umstellen (`writeMedium`, `connectKnown`, `volumeDisappeared`, `applyChoice`).
- b) Beenden: ausstehende Einstellungs- und Medium-Schreibvorgänge mit diesen gezielten `UPDATE`s sichern. Das geht synchron mit kurzer Zeitgrenze, nicht mit dem 10-s-Busy-Timeout auf main, oder per `.terminateLater` und `reply(toApplicationShouldTerminate:)` nach dem `await`.
- **Akzeptanz:**
  - Hook zwischen Lesen und Schreiben von `writeMedium`, dort `commitMediumMeta(delta: +100)` → `fileCount` enthält +100.
  - Einstellung bzw. Entscheidung ändern → sofort `prepareForTermination()` → neuer Store hat den Wert.
Status:

**HALT nach Paket 5** — Freigabe durch Claude:

---

#### Paket 6 — Oberfläche

**bug.0.4.034 — Spaltenansicht: Zustand „wird indiziert“ richtig (REPORT 81, 126).**
- a) `rowOpacity` übergibt `folderName`, `folderListedAt` und `folderUnreadable` wie `iconColor`. Den Zustand **einmal je Zeile** berechnen und für Farbe und Deckkraft verwenden.
- b) `ColumnFolderOpenState.resolve`: `folderDepth >= maxDepth` → `.uncaptured(.scanDepth)` (der Indexer öffnet Ordner auf Tiefe = Scan-Tiefe nicht). Den Test `ProtocolAndSelectionTests` Z. ~290 auf `columnIndex: 1` bei Tiefe 2 umstellen.
- **Akzeptanz (echtes Fenster außerhalb des Bildschirms, Regel 10/19):**
  - Indizierter Ordner → Deckkraft 1.
  - Ordner mit `listedAt == nil` bei laufender Indizierung → 0,55.
  - Bei Scan-Tiefe 2 sind Ordner der Ebene 2 gelb mit „Inhalt wird nicht indiziert“, nicht grün.
Status:

**bug.0.4.035 — ⌘A in großen Ordnern ohne quadratischen Aufwand (REPORT 65).**
- `ColumnSelection` führt zusätzlich ein `Set<UUID>` für `contains`.
- In `folderColumn`, `commit`, `multipleSelectionItems` und `contextTargets` einmal ein Dictionary `id → item` bzw. ein Set je Body/Aufruf.
- `IgnoreBatch`/`ContextMenuPlan` über Sets.
- Für „Dateinamen ignorieren“ mit sehr vielen Zielen: Entscheidung `todo.0.4.031` abwarten (Obergrenze oder Warnung braucht einen Text); bis dahin nur die Laufzeit-Teile umsetzen.
- **Akzeptanz:** 50.000 künstliche Items, `selectAll`, `commit` und `selectedIDs` jeweils < 50 ms (Messung im Status).
Status:

**bug.0.4.036 — Spalten-Cache verdrängt keine sichtbaren Spalten (REPORT 125, 98).**
- `IndexRepository.children()` setzt den Schlüssel bei jedem Lesen ans Ende von `cacheOrder`. Schlüssel der sichtbaren Spalten (`pathStack`) werden nie verdrängt.
- `pruneSelectionToVisibleItems` läuft nur, wenn der Ordner tatsächlich geladen ist (nicht bei fehlendem Cache oder `isLoading`).
- 98: `replaceStore` erhöht die Generationen (wie `invalidateAll`) statt sie zu löschen. Das `defer` des Loads räumt `loading`/`loadingTotals` nur bei passendem Token ab.
- **Akzeptanz:**
  - Wurzel offen, Ordner gewählt, danach 35 andere Ordner laden → Wurzel bleibt im Cache, Auswahl und `pathStack` bleiben.
  - `invalidateAll` während Auswahl → Auswahl bleibt.
Status:

**bug.0.4.037 — Favorit und Online-Status in Listen aktuell (REPORT 80, 82, 103).**
- `AppState` führt eine Menge der Favoriten-IDs als Quelle für `isFavorite(_:)` bei Dateien. `toggleFavorite`/`toggleFavorites` patchen `favoriteObjects` und `searchMatch.items` lokal.
- `isOnline` in Suche, Favoriten und `ObjectContextTarget` beim Rendern und Filtern aus einem Dictionary `mediumID → connected` ableiten (einmal je Body), nicht speichern.
- 103: `ColumnFolderTableView.updateNSView` lädt sichtbare Zeilen neu, wenn `coordinator.items != items`.
- **Akzeptanz:**
  - In Favoriten einen Favoriten abwählen → Zeile verschwindet sofort; zweiter Klick setzt ihn wieder.
  - Medium per `updateMedium` offline → Filter „Offline“ enthält dessen Favoriten.
  - Tabelle ab 50k: Favorit umschalten → Zeile zeigt neuen Zustand.
Status:

**bug.0.4.038 — Suche: Sortierung und Gruppen nicht nur über die erste Seite (REPORT 83, 130, 131).**
- `store.search` bekommt Sortierspalte und -richtung für **Name, Datum, Medium** (SQL `ORDER BY`, `items_modified` existiert). Bei Klick wird neu abgefragt.
- Für **Pfad** und **Status**: Client-Sortierung nur bei `itemCount <= pageLimit`, sonst diesen Spaltenkopf deaktivieren (kein neuer Text).
- 130: Das Popover holt Ordner und Dateien je mit eigener kleiner Abfrage (`LIMIT 3`).
- 131: Medien-IDs für die Kacheln per `SELECT DISTINCT storageID` mit denselben Filtern.
- **Akzeptanz:**
  - 600 Treffer, neuester heißt „zzz“ → Datum absteigend zeigt ihn zuerst; Name absteigend zeigt den alphabetisch letzten.
  - „rechnung“ mit 600 Dateien `Rechnung_…` und Ordner „Rechnungen“ → Gruppe „ORDNER“ vorhanden.
Status:

**bug.0.4.039 — Popover-Suche entprellen und abbrechen (REPORT 85).**
- Den Task in `AppState` halten und bei neuer Eingabe `cancel()`. 150 ms Entprellung.
- Die Seite mit `withCount: false` holen, die Zahl getrennt und abbrechbar nachreichen.
- **Akzeptanz:** 5 Eingaben schnell hintereinander → höchstens eine Zählabfrage (Zähler im Test).
Status:

**bug.0.4.040 — Favoriten-Tabelle lazy und seitenweise (REPORT 86).**
- `ObjectResultsTable` mit `LazyVStack`.
- Favoriten seitenweise wie die Suche (500 + Zählung).
- Mediennamen und Verbindungsstatus einmal als Dictionary übergeben, nicht je Zeile `appState.medium(with:)`.
- **Akzeptanz:** 10.000 Favoriten → erste Darstellung < 300 ms; Fortschritts-Tick baut nicht alle Zeilen neu (Zähler im Test).
Status:

**HALT nach Paket 6** — Freigabe durch Claude:

---

#### Paket 7 — Absturzschreiber und Start

**bug.0.4.041 — Absturzschreiber signalsicher, Ringzeilen UTF-8-sicher (REPORT 76, 128).**
- Header-Puffer je Signal, Frame-Puffer und Signalnamen einmalig in `start(installHandlers:)` vorab anlegen (statischer Speicher).
- `writeRing` öffnet nie selbst (`guard crashFD >= 0 else { return }`).
- `consumeCrashMarker` öffnet `crash-last.txt` nach dem Verschieben sofort neu (außerhalb des Signalkontexts).
- SIGTERM-Pfad schreibt nur vorab angelegte Bytes.
- 128: `storeCrumb` kürzt auf eine UTF-8-Zeichengrenze. Beim Lesen `String(decoding:as: UTF8.self)`.
- **Akzeptanz:**
  - Nach `acknowledgeCrashDialog()` existiert `crash-last.txt` (64 KB), Debug-Accessor `crashFD >= 0`.
  - `writeCrashSnapshot` schreibt `CRASH signal=`.
  - Aktionszeile mit 300 Bytes Umlauten → Absturzdatei gültig, `CRASH` erkannt.
Status:

**bug.0.4.042 — Einzelinstanz vor Protokoll; SIGTERM sauber (REPORT 87, 88).**
- `ensureSingleInstance()` **vor** `DiskIndexLog.shared.start()`.
- Bei `handedOff` in `applicationWillTerminate` nichts protokollieren und nichts abbauen.
- Protokoll-Handle mit `O_APPEND`.
- Bei `launchKind == .login` die Übergabe ohne `showMainWindow`.
- SIGTERM: aus der sigaction-Liste nehmen; `signal(SIGTERM, SIG_IGN)` plus `DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)` → `NSApp.terminate(nil)`.
- **Akzeptanz:**
  - Test der Startreihenfolge: Bei Übergabe schreibt die Zweitinstanz keine Protokollzeile und fasst `crash-last.txt` nicht an.
  - Testprozess mit SIGTERM → normales Beenden (Checkpoint läuft).
  - Kein Start der echten App (Regel 19).
Status:

**HALT nach Paket 7** — Freigabe durch Claude:

---

---

### Nutzer und Claude (ohne Umsetzer)

| Kennung | Was | Wer |
|---|---|---|
| `todo.0.3.2.001` | Layout **02** (Erkennungs-Dialog mit Stapel/Warteschlange) und **04** (Dashboard-`card-meta`: Belegung links, „Zuletzt indiziert“ rechts, eine Zeile) in `layout/Disk Index App.dc.html` nachziehen. Blockiert keinen Code. | Nutzer |
| `todo.0.3.2.002` | `MARKETING_VERSION` im Xcode-Projekt von 0.2.0 auf **0.3.2** anheben (dreistellig `n.n.n`, Build-Nummer bleibt der Zeitstempel). Nach Paket 0 freigeben. | Umsetzer |

### Entscheidungen des Nutzers (blockieren nur die genannte Stelle)

| Kennung | Frage | betrifft |
|---|---|---|
| `todo.0.4.030` | **Beta-Sperre und API-Stand.** Die API meldet heute `1.0.0`. Eine Beta (0.x) mit **frischer Datenbank sperrt dann sofort** (nur ansehen), mit vorhandener Datenbank nach 7 Tagen ab erster Abfrage. Das trifft jeden Neustart nach Zurücksetzen und jeden neuen Rechner. Soll die API bis zur Weitergabe auf die Beta-Nummer (z. B. `0.3`) gestellt werden, oder soll Debug die Sperre überspringen? (PHP-API nur mit Okay des Nutzers.) | Test der App, `todo.0.4.001` |
| `todo.0.4.031` | **Mehrere Ordner auf einmal ignorieren** (⌘A, 50.000 Ziele): Obergrenze oder Warnung? Braucht einen neuen Text. | `bug.0.4.035` |
| `todo.0.4.032` | **Medium neu formatiert** (neue UUID, gleicher Name): altes Medium bleibt tot „Offline“. Hinweis anbieten oder automatisch vergessen? | `bug.0.4.031` |
| `todo.0.4.033` | **Startreihenfolge:** Einstellungen müssen vor dem ersten Lauf geladen sein (Verdacht: sonst läuft der erste Lauf mit Voreinstellungen, z. B. „Unsichtbare Dateien ignorieren“ an, und löscht Favoriten). Soll das fest als Regel gelten (Empfehlung: ja)? | `bug.0.4.028` |
| `todo.0.4.034` | **„Für dieses Medium merken“:** `rememberDecision` wird geschrieben, aber nie gelesen. Gilt README 2.3 (Dialog erscheint ohne Haken wieder) noch, oder entfällt der Haken? | Erkennung |
| `todo.0.4.035` | **Abgelaufene Pause beim Start** endet still, ohne Mitteilung „Medien werden wieder indiziert.“ Soll die Mitteilung auch hier kommen? | Pause |
| `todo.0.4.036` | **Versions-Check-Takt:** `Task.sleep` zählt Betriebszeit, nicht Kalenderzeit; auf Laptops mit Ruhezustand seltener als „alle 24 h“. Kalenderzeit gemeint? | `VersionCheckScheduler` |
| `todo.0.4.037` | **Antwort 201 ohne JSON-`id`** gilt als Fehlschlag und wird erneut gesendet (Doppel auf dem Server). Mit der Server-Seite abstimmen. | Fehlerbericht |
| `todo.0.4.038` | `DebugTools/ScreenshotRunner.swift` (708 Zeilen, Regel 19 verbietet den Lauf) und `PreviewData.swift`: noch gebraucht oder löschen? | `todo.0.4.010` |

### Beobachten (keine Aufgabe)

| Kennung | Stand |
|---|---|
| `bug.0.4.070` | `serviceRunPassesTheReasonToTheDialog` (früher F11), parallel selten rot |
| `bug.0.4.071` | kurze `Task.sleep` in mehreren Suiten (früher F23); Wackelgefahr |

---

## B. Backlog (nicht freigegeben, der Umsetzer arbeitet nicht daran)

### 0.4 — Beta für Beta-Tester (Voraussetzungen der Weitergabe, ROADMAP)

| Kennung | Inhalt |
|---|---|
| `todo.0.4.020` | **Signatur und Notarisierung:** Developer ID Application, `notarytool`, Stapeln (heute „Apple Development“). Merkhilfe eigene Kopie ohne Notarisierung: Xcode Archive → Distribute → Copy App; ggf. `xattr -dr com.apple.quarantine "…"`. |
| `todo.0.4.021` | **Download-Seite** auf `https://diskarchive.app/` mit stabilem Link (Nutzer). |
| `todo.0.4.022` | **Laufzeittest auf macOS 14** (z. B. VM); `pointerStyle` und `CGSize: Hashable` brauchen einen Ausweichweg. |
| `todo.0.4.023` | **Fehlerbericht mit echten Protokollzeilen** testen (erst nach `bug.0.4.011` und `bug.0.4.012`). |
| `todo.0.4.024` | **Update durch Ersetzen der App:** Bundle-ID und Datenordner gleich, Einzelinstanz-Übergabe bei neuerer Version, Launch-Agent neu registrieren; Schema-Erweiterungen mit Sicherung davor (nach `bug.0.4.013`). |
| `todo.0.4.025` | **Fenster „Datenbank wird aktualisiert“** (einmalig, mit Fortschritt) bei der ersten Schema-Erweiterung durch ein Update. |

### 0.4 — Fehler mit niedriger Schwere (nach den Paketen; Lösung im Archiv-Report, Nummer nennen)

| Kennung | REPORT | Kurz |
|---|---|---|
| `bug.0.4.050` | 84 | Pfeiltasten in anderer Spalte → falscher Spaltenindex |
| `bug.0.4.051` | 89 | Versions-Check-Zeilen verdrängen Absturzberichte |
| `bug.0.4.052` | 92 | Pausentimer nach Store-Fehler |
| `bug.0.4.053` | 93 | Versions-Sperre: Lücken (API nie erreicht, Uhr zurückgestellt, 0 Medien = „frisch“) |
| `bug.0.4.054` | 95 | Pause in der Zählphase speichert Teilsumme |
| `bug.0.4.055` | 96 | `getattrlistbulk`-Offsets (teilweise in `bug.0.4.016`) |
| `bug.0.4.056` | 97 | Hot Path Matcher und Artefakte |
| `bug.0.4.057` | 100 | Kollation der Folgeseiten (latent) |
| `bug.0.4.058` | 104 | Feste deutsche Texte, Locale-Formatierung |
| `bug.0.4.059` | 105 | Pausentimer leitet Dauer aus Restzeit ab |
| `bug.0.4.060` | 106 | Popover-Höhe „Keine Treffer“ |
| `bug.0.4.061` | 107 | Mindestanzeige (400 ms) des Ladehinweises wirkt nie |
| `bug.0.4.062` | 132 | Sammelzeile Nebenläufigkeit (Verdacht) |

### 0.5 bis 1.0 (Entwürfe, jede Funktion vor dem Start einzeln besprechen; Details ROADMAP)

| Kennung | Inhalt |
|---|---|
| `todo.0.5.001` | **Metadaten und EXIF** (Video, Foto/RAW, Audio, PDF; zweiter Durchgang nach dem Index, Markierung `_analyzed`), neue Layouts, **Wartescreen der Suche** |
| `todo.0.6.001` | **Vorschaubilder** 250 px, Abschalter global und je Medium, Dateien `Thumbnails/<storageID>/<itemID>` |
| `todo.0.7.001` | **CSV-Export** (Umfang, Spalten, Kodierung offen) |
| `todo.0.8.001` | **Duplikate** über volle Prüfsumme, nach Größe gruppiert, nur im Hintergrund |
| `todo.0.9.001` | **Lizenz** (1 / 50 / 250 Medien als Lizenzgrenze; Fragen siehe README) |
| `todo.1.0.001` | Ladehinweis erst nach 1 s (früher T1; prüfen, ob durch `DelayedLoadingState` erledigt) |
| `todo.1.0.002` | Erweiterte Dateityp-Icons (früher T3, Styleguide 15) |
| `todo.1.0.003` | Ausführliches Protokoll / Diagnose-Modus (früher T5, Vorschlag Claude, nicht freigegeben) |

Entfallen: T2 „Programme als Dateityp“ (erledigt in 233: `.app`, `.dmg`, `.pkg`); Signatur/Notarisierung stand im alten Backlog bei 1.0, gilt laut README aber als Voraussetzung von 0.4 (`todo.0.4.020`).
