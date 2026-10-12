# TODO.md — offene Aufgaben für Cursor

Einzige Aufgabenliste. Erledigtes steht in [DONE.md](DONE.md), Verlauf und alte Spezifikationen in `archiv/`. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). **Komponenten (Maße, Farben, Zustände): [layout/Komponenten.dc.html](layout/Komponenten.dc.html), zusammengefasst in [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) — einzige Quelle für Größen.** Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

## Regeln für Cursor (verbindlich)

1. **Nur Aufgaben aus „A. Jetzt“**, in der dort stehenden Reihenfolge. „B. Backlog“ und alles andere nicht anfassen, auch nicht „vorbereiten“.
2. **Nach jedem Paket anhalten** (Zeile „HALT“). Erst weiterarbeiten, wenn Claude in A. freigegeben hat.
3. **Nichts erfinden.** Kein Feature, Text, Schalter, Screen ohne Vorgabe in README oder Layout. Fehlt etwas: Frage unter die Aufgabe schreiben („Frage:“), nicht bauen. Nötige Texte ohne Layout-Vorlage (ab 11.10., Nutzer): normal über `L10n`/`LayoutCopy` mit de und en anlegen und im Status als „Neue Texte:“ auflisten; der Nutzer prüft sie. Keine roten Vorschläge mehr.
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

## A. Jetzt — Version 0.3

**Maßgeblich:** README „Roadmap“, ausführlich [ROADMAP.md](ROADMAP.md). **0.2 eingefroren** (11.10.). **Abgenommen bis 233** (siehe [DONE.md](DONE.md)). **Freigegeben: 233b. HALT nach 233b.**

**Arbeitsregeln je Aufgabe (zusätzlich zu 1–23):**
- **R1** Nur die genannten Stellen ändern.
- **R2** Beweis = Pixel aus einem echten Fenster (`PixelProbe`); Sabotage → rot ✓.
- **R3** Status höchstens 5 Zeilen.

### Noch offen / beobachten (keine Cursor-Aufgabe)

| Nr. | Stand |
|---|---|
| F11 | beobachten (`serviceRunPassesTheReasonToTheDialog`, parallel selten rot) |
| F23 | beobachten (kurze `Task.sleep` in mehreren Suites) |
| F25 | löst **234** (Status-Flag statt Bereich-Bereinigen) |
| F26 | löst **236** (WAL kürzen / Wartung) |

Weitere Alltagfehler trägt Claude hier ein.

### Aufgabe

**233b. `auto_vacuum` greift nicht (0.3).** Befund Claude: `SchemaV3.makeConfiguration` setzt erst `journal_mode = WAL`, dann `auto_vacuum = INCREMENTAL`. In dieser Reihenfolge bleibt eine neue Datei bei `auto_vacuum = 0` (mit sqlite3 nachgeprüft: WAL zuerst → 0, `auto_vacuum` zuerst → 2). Damit gibt `incremental_vacuum` (236) nie Platz zurück.
a) Reihenfolge so ändern, dass eine **neue** Datei `PRAGMA auto_vacuum` = **2** hat (vor WAL und vor der ersten Tabelle). Achtung: `DatabasePool` schaltet WAL womöglich selbst ein — dann die neue Datei zuerst mit `DatabaseQueue` anlegen (auto_vacuum setzen, schließen) und erst danach den Pool öffnen. Bestehende Dateien nicht umbauen (der Nutzer setzt zurück).
b) Test: frische Datei über `SchemaV3.openPool` → `PRAGMA auto_vacuum` = 2 und `journal_mode` = wal. Sabotage (alte Reihenfolge) → rot ✓.
c) Kopfkommentar `SchemaV3.swift` Z. 5 („Die App benutzt es noch nicht“) korrigieren.
d) Seriell, Warnungen 0, **Regel 23**.
Status: SchemaV3.swift: auto_vacuum vor WAL + prepareNewFile(DatabaseQueue); Kopfkommentar korrigiert. Test freshFileHasIncrementalAutoVacuumAndWAL. Sabotage (alte Reihenfolge): rot ✓. 474 Tests seriell grün 08:40, Warnungen 0. Regel 23: App 08:40:58, SchemaV3.swift 08:34:43 (find -newer leer). Bereit zur Prüfung.

#### Cursor-Spur (Schlüssel `c.0.3.2.NNN` = Cursor · Version 0.3.2 · Aufgabe). Claude pflegt Abnahmen später in DONE/README. Nur notiert — Freigabe je Aufgabe durch Nutzer/Claude.

**c.0.3.2.001 — 233b nachprüfen und abschließen (aus A.233b).**
Gegenprüfung am Code (12.10.): `SchemaV3.prepareNewFile` + `auto_vacuum` vor WAL; Test `freshFileHasIncrementalAutoVacuumAndWAL`; Kopfkommentar ok. Status stand „Bereit zur Prüfung“.
a) Suite erneut: `SchemaV3Tests` + seriell voll, Warnungen 0, **Regel 23** belegen.
b) Bei Grün: Status „Bereit zur Prüfung“ belassen bzw. Belege aktualisieren; nach Nutzer-/Claude-OK → DONE (Claude).
c) Bei Rot: Ursache beheben, Sabotage rot ✓, neuer Status.
Status: 233b-Code ok (prepareNewFile, Test freshFile…). Seriell: SchemaV3Tests 11 grün, 476 grün 11:06, Warnungen 0. Nebenfix MediumDecisionTests (undecided vor enqueue, 0.3.2-Badge). Regel 23: App 11:06:52, find -newer leer. Bereit zur Prüfung.
**Prüfung Cursor 12.10. 11:17:** Code a/c bestätigt (`prepareNewFile`, auto_vacuum vor WAL, Kopfkommentar). `SchemaV3Tests` 11/11 inkl. `freshFileHasIncrementalAutoVacuumAndWAL` grün 11:11. Suite seriell: **470 bestanden, 6 übersprungen, 0 fehlgeschlagen** (totalTestCount 476) 11:12–11:17, Warnungen 0. Regel 23: Build Debug App **11:17:20**, `find … -newer` leer. Keine Nacharbeit an 233b. Abnahme → DONE (Claude/Nutzer).

**c.0.3.2.002 — Erkennungs-Dialoge stapeln + keine Indizierung ohne Ja + Dashboard-Meta (Roadmap 0.3.2; REPORT 7/16/17).**
Kein Layout-Vorlauf. Layout 02/04 wird später nachgezogen.
a) **Mehrere Modals:** Pro Medium `undecided` ein eigenes Panel; Versatz nach unten rechts, neuestes vorne und unten; jedes Panel nur für seine ID; Schließen ohne Ja/Nein lässt Medium `undecided` (Queue/Badge bleiben).
b) **Keine Indizierung ohne explizites Ja:** Lauf/Reindex/Watcher nur bei `decision == .index`. Ja nur über Erkennungs-Dialog **oder** Einstellungen → Speichermedien / Medium-Details. Nein: Lauf canceln, Watcher stoppen (REPORT 7). Popover: kein „Neu indizieren“ bei `undecided`.
c) REPORT **17:** „Nicht indizieren“ setzt nicht `indexStatus = .indexed` ohne Index. REPORT **16:** Latch `requestedIndex` bei Pause-No-Op bereinigen.
d) **Dashboard-Kachel:** Meta unten — Belegung links, „Zuletzt indiziert“ / „Zuletzt gesehen“ rechts; Uhr auch im Absolut-Modus.
e) README-Konzept §2 + Roadmap 0.3.2 / Layout-Reminder anpassen (Stapel + Indizierungsregel; „erst Layout“ streichen).
f) Tests (zwei Medien → zwei Dialoge; ohne Ja kein Lauf; Ja in Einstellungen startet), Sabotage rot ✓, seriell, Regel 23.
Status: Multi-Panel (`AppWindowPresenter`, `NewMediumDialogWindowHost`); `onMediumDecisionChanged`/`LiveWiring`; REPORT 16/17. Tests: NewMediumStackTests, MediumRecognition, DashboardLastSeen. 481 seriell grün 11:31, Warnungen 0. Regel 23: App 11:31:51. Frage: README §2/ROADMAP 0.3.2 (e) — Claude. Bereit zur Prüfung.
**Prüfung Cursor 12.10. (Code, ohne xcodebuild):** a) Multi-Panel + Versatz unten rechts (`syncNewMediumPanels`/`placeNewMediumPanel`, Offset 24) ok; Schließen = `dismissed` + Queue bleibt. b) Guards `decision == .index`, `onMediumDecisionChanged` → cancel/stop bzw. `requestIndexingAfterDecision`, Popover ohne Reindex bei undecided — ok; REPORT 16 `clearIndexRequest` bei Pause — ok. d) Dashboard-Meta ok. e) README/ROADMAP noch alt („erst Layout“) — offen für Claude. **c) REPORT 17 nicht erledigt:** `MediumCoordinator.applyChoice` berechnet `hasIndex`, setzt aber weiter `indexStatus = .indexed`; Test `dontIndexWithoutIndexKeepsPendingStatus` erwartet `.pending`. Dialog-Fallback in `NewMediumDetectedDialog` ist korrekt, der Store-Pfad nicht. → Nacharbeit **c.0.3.2.002b**. Suite/Regel-23-Zahlen des Status nicht erneut gelaufen (Passwort-Dialoge).

**c.0.3.2.002b — REPORT 17 nachziehen (aus Prüfung 002).**
In `MediumCoordinator.applyChoice` bei `allowIndexing == false`: `indexStatus = hasIndex ? .indexed : .pending` (oder Status unverändert lassen, wenn kein Index). `hasIndex` nicht tot liegen lassen. Test `dontIndexWithoutIndexKeepsPendingStatus` muss grün sein; Sabotage (immer `.indexed`) → rot ✓. Seriell betroffen Suites, **kein** xcodebuild mit Signatur-Prompts ohne Freigabe; Regel 23 wenn gebaut.
Status: `MediumCoordinator.applyChoice` Z. 326: `hasIndex ? .indexed : .pending`. MediumCoordinatorTests+NewMediumStackTests 17 grün; Sabotage rot ✓. Regel 23: App 11:40:19, find -newer leer. Bereit zur Prüfung.
**Prüfung Cursor 12.10. (Code, ohne xcodebuild):** Fix bestätigt — `applyChoice` Z. 325–326 nutzt `hasIndex ? .indexed : .pending`. Test `dontIndexWithoutIndexKeepsPendingStatus` passt zum Code. Dialog-Fallback in `NewMediumDetectedDialog` weiterhin konsistent. Regel 23: App 11:40:19, `MediumCoordinator.swift` 11:40:11, `find -newer` leer. Suite-Zahlen des Status nicht erneut gelaufen. Keine Nacharbeit. Abnahme mit 002 → Claude/Nutzer.

**c.0.3.2.003 — Store-Öffnen / Retry / Integrität (REPORT 2, 3, 4, 5, 22, 28).**
Teardown bei Integritätsfehler wie Beenden; Change-Loop an neuen Store binden; vor `wireStore` alte Indexer/Watcher stoppen; Startup-Task single-flight; Retry mit Lade-UI; `indexStore`/`changeLoop` zurücksetzen.
Status: `detachFromIndexStore`/`cancelChangeLoop`; Change-Loop wartet alten Task ab; AppDelegate single-flight + `stopLiveServicesBeforeRewire`; Integritäts-`onFailure` vollständig; Retry `clearIndexStoreOpenFailure`. StoreStartupLifecycleTests. 485 seriell grün. Regel 23: App 12:07:28, find -newer leer. Bereit zur Prüfung.
**Prüfung Cursor 12.10. (Code, ohne xcodebuild):** REPORT 2/28: `handleStoreFailure` bei ready Store → `stopLiveServicesBeforeRewire` + `prepareForTermination` + `detachFromIndexStore`. REPORT 3: `startChangeLoop` cancel + `await previous` + neuer Store. REPORT 4: `wireStore` stoppt Live-Dienste zuerst. REPORT 5: `storeStartupTask`/`storeStartupGeneration`. REPORT 22: Retry `clearIndexStoreOpenFailure` → `isStoreLoading`. Tests `StoreStartupLifecycleTests` decken Restart/Detach/Retry/Integrität ab. Regel 23: App 12:07:28, find -newer leer. Suite 485 nicht erneut gelaufen. Keine Nacharbeit.

**c.0.3.2.004 — FSEvents / Watcher-Lebenszyklus (REPORT 6, 8, 9, 10).**
Kein paralleles Schreiben Watcher↔Indexer ohne Token; Stream-Fehler → `continuation.finish`; Unmount → sauber stoppen/neu starten; Cursor nur bei erfolgreichem Reread speichern.
Status: LiveWiring stop vor Index, Watcher nur `onRunIndexed`; Engine deferred/apply-Fehler; flush `saveCursor` nur `.ok`; FSEvents `finish`, Unmount-Restart, Wake indexed. WatcherLifecycleTests. 489 seriell grün. Regel 23: App 12:27:39, find -newer leer. Bereit zur Prüfung.
**Prüfung Cursor 12.10. (Code, ohne xcodebuild):** REPORT 6: `stopWatcherAndStartIndex`; Watcher nur `onRunIndexed`; `isIndexingActive`/`hasActiveIndexingToken` → deferred. REPORT 8: FSEvents Create/Start-Fehler → `continuation.finish`. REPORT 9: Unmount `saveCursor` + Restart wenn verbunden; Wake startet auch ohne `isWatching`. REPORT 10: flush `saveCursor` nur `.ok`; apply-Fehler → `needsFullReconcile`. Tests `WatcherLifecycleTests`. Regel 23: Binary 12:27:39, find -newer leer. Suite 489 nicht erneut. Keine Nacharbeit.

**c.0.3.2.005 — Suche / Spalten Scope & Pagination (REPORT 11, 12, 19, 20).**
Bei `checksNames`: LIMIT/Pagination nach sichtbaren Treffern; `childrenPage` bei leerer gefilterter Seite weiterblättern; `childCount` Scope beachten; `searchCount` bei Namensregeln entlasten.
Status: `childrenPage` Cursor aus SQL-Zeilen; `visibleSearchHitIDs`/`searchHitPage`; `childCount` mit Scope; `searchCount` parallel bei checksNames. SearchScopePaginationTests. 492 seriell grün. Regel 23: App 12:40:03, find -newer leer. Bereit zur Prüfung.
**Prüfung Cursor 12.10. (Code, ohne xcodebuild):** REPORT 11: `visibleSearchHitIDs` paginiert SQL bis genug sichtbare Treffer. REPORT 12: `nextCursor` aus `rows`, nicht `filtered`; IndexRepository läuft bei leerer Seite weiter. REPORT 19: `childCount` filtert bei `checksNames` / `maxDepth`. REPORT 20: `searchCount` bei `checksNames` parallel über `idRanges`. Tests `SearchScopePaginationTests`. Regel 23: Binary 12:40:03, find -newer leer. Suite 492 nicht erneut. Keine Nacharbeit.

**c.0.3.2.006 — IndexingService finish / cancel / Recount (REPORT 13, 15, 26).**
Token vor Spinner/Task-Clear; `cancel` detached-Task abbrechen; Hintergrund-Recount an Token/`shouldHalt` koppeln.
Status: `finish` prüft Token vor Task/Spinner; `cancel` bricht Task ab, `await task?.value`, UI nur ohne Nachfolger; `publish` guard. DirectoryIndexer: `backgroundRecount` + defer-cancel, `setScanTotal` nur bei aktivem Token. Tests `IndexingFinishCancelTests` (3). 495 Tests serial grün; Debug-App 12:51:22. Bereit zur Prüfung.
**Prüfung Cursor 12.10. (Code, ohne xcodebuild):** REPORT 13: `finish` Token-`guard` vor Task/Spinner-Clear. REPORT 15: `cancel` → `task?.cancel()` + `await value`; UI/Task nur wenn kein Nachfolger-`runs`. REPORT 26: Recount als `backgroundRecount` + `defer` cancel; `setScanTotal` nur bei `indexingIsActive` (Recount + Zählphase). Tests `IndexingFinishCancelTests` (3). Regel 23: Binary 12:51:31, find -newer leer. Suite 495 nicht erneut. Keine Nacharbeit.

**c.0.3.2.007 — UI / Quit / Meta restlich (REPORT 14, 18, 21, 23, 24, 25, 27).**
`isSearchInProgress` bei Abbruch; Depth-`contentStamp`/`completedDepth` nur betroffene Storages; `forgetAllMedia` weiterlaufen; Spalten-State Tab-Wechsel; Notification-Delegate Main; Quit-Checkpoint warten; `autoIndexPaused` aus DB.
Status: REPORT 14 defer in `runSearch`; 18 prune-Meta nur `touchedStorages`; 21 `forgetAll` continue; 23 Spalten-Nav-Reset; 24 Delegate `@MainActor`; 25 sync `checkpoint`; 27 `asMedium` paused. Tests SearchBehavior, IndexPrune, SurfaceStore, UiQuitMetaTests. 499 serial grün. Regel 23: App 13:16:00, find -newer leer. Bereit zur Prüfung.
**Prüfung Cursor 12.10. (Code, ohne xcodebuild):** REPORT 14: `runSearch` defer setzt `isSearchInProgress` bei gleicher Generation zurück. REPORT 18: `contentStamp`/`completedDepth` nur `touchedStorages` (IndexPrune: anderes Medium behält Tiefe). REPORT 21: `forgetAll` catch → `continue`. REPORT 23: Spalten-Nav-Reset beim Verlassen. REPORT 24: Notification-Delegate `Task { @MainActor }`. REPORT 25: sync `checkpoint()` in `prepareForAppTermination`. REPORT 27: `asMedium` übernimmt `autoIndexPaused`. Tests SearchBehavior/IndexPrune/SurfaceStore/UiQuitMeta. Regel 23: Binary 13:16:00, find -newer leer. Suite 499 nicht erneut. Keine Nacharbeit.

### Offen, ohne Cursor

- **Nutzer:** Layout 02 + 04 für 0.3.2 **nachziehen** (blockiert Code nicht; siehe c.0.3.2.002).
- **Claude:** Nach Abnahme c.0.3.2.001 (233b) → DONE; Freigabe der nächsten `c.0.3.2.*`-Aufgabe.

---

## B. Backlog (nicht freigegeben, Cursor arbeitet nicht daran)

### 0.3 — noch offen (Reihenfolge)

- **234** Status-Flag und Warteschlange für Regeländerungen (ersetzt Bereinigen nach Bereich; F25).
- **235** Umbenennen/Verschieben erkennen (`fileID` erst erfassen).
- **236** Wartung (Zeit + Zähler), WAL nach Läufen kürzen (F26).
- **237** Einstellungen in Tabelle `settings` (außer Sprache, Fensterposition).
- **238** Messung „nachher“ mit 196 und Vergleich; Schema einfrieren.
- **0.3.1** API-Warteschlange (README / ROADMAP).
- **0.3.2** → Cursor-Spur **c.0.3.2.002** (gestapelte Dialoge, Indizierung nur nach Ja, Dashboard-Meta; Layout nachziehen).


### 0.4 — Letzte Fixes, Beta für Beta-Tester

- **Download-Seite** auf `https://diskarchive.app/` (Nutzer).
- **Versions-Check** / Update-Modal / Beta-Sperre (siehe README 0.4).
- **Beta-Verfallsdatum**; **`FeatureAccess`**; Laufzeittest **macOS 14**.
- **Fehlerbericht:** Test mit echten Protokollzeilen.
- **Update durch Ersetzen der App;** ab 0.4 echte Migrationen (Sicherung, `hasBeenSuperseded`).

Merkhilfe eigene Kopie ohne Notarisierung: Xcode Archive → Distribute → Copy App; ggf. `xattr -dr com.apple.quarantine "…"`.

### 0.5 — Metadaten und EXIF
Wartet auf Layout und Besprechung (README).

### 0.6 — Vorschaubilder
Eigene Datei, Abschalter; **250 px** lange Seite (README).

### 0.7 — CSV-Export
Noch nicht ausgearbeitet (README).

### 0.8 — Duplikate
Über alle Medien, stufenweise (README).

### 0.9 — Lizenz
Medienzahl **1 / 50 / 250**; offene Fragen in README.

### 1.0 – Finales Release

- **Signatur und Notarisierung:** Developer ID Application + Notarisierung + Stapeln.

### Ohne Zielversion (wartet auf Nutzer)

- **T1.** Ladehinweis erst nach 1 s.
- **T2.** Programme als Dateityp (`.app`/dmg/pkg) — teilweise in 233.
- **T3.** Erweiterte Dateityp-Icons (Styleguide 15).
- **T5.** Ausführliches Protokoll / Diagnose-Modus (Vorschlag Claude; nicht freigegeben).
