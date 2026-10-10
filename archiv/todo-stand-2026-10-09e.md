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

---

## A. Jetzt

**Stand 09.10. (4):** Abgenommen bis 179 a–e (siehe DONE.md). Offen: 181 (zuerst, dringend), dann 180.

## ARBEITSAUFTRAG JETZT (Claude, 09.10. — exakt so umsetzen)

**Lies zuerst diese drei Regeln, sie gelten für jede Aufgabe unten:**
- **R1 Nur die genannten Stellen ändern.** Jede Aufgabe nennt Datei und Zeile. Andere Dateien nur, wenn die Aufgabe es sagt. Keine „Verbesserungen nebenbei“.
- **R2 Beweis = Pixel aus einem echten Fenster.** `hitTest != nil`, `source.contains(…)`, Zahlenvergleiche mit Konstanten und Prüfungen nur am Datenmodell zählen **nicht** als Beweis für Aussehen oder Klickverhalten. Benutze dafür ausschließlich die Hilfe `PixelProbe` (Aufgabe 150 a). Jeder neue Test wird einmal **sabotiert** und muss dann rot sein; im Status: „Sabotage: rot ✓“.
- **R3 Status je Aufgabe:** höchstens 5 Zeilen: geänderte Dateien:Zeilen, Testname, Ergebnis der Sabotage, Pfad der Bildschirmfotos (`Werkzeuge/screenshots/<JJJJ-MM-TT>-<aufgabe>/`).

---

**Claude-Prüfung 09.10. (4):** 178 und 179 a–e **abgenommen** (Code gelesen: `LiveWiring` stoppt vor dem Abgleich, Neustart nach Aufwachen nur für überwachte Medien, `startWatching` ruht in der Pause, `onRunIndexed` in `finish`, `rerunAfterFinish`, `fromScratch: false` bei Überlauf, `coordinator.forget`). Volltexte: `archiv/todo-stand-2026-10-09d.md`.
**Antworten:** (179 f) Entfällt — die Tests brauchen `/Volumes`, damit `VolumeCandidateRule` sie als Medium annimmt; App-Code dafür nicht ändern. (178 Frage Spalte) siehe 180 a. (177) siehe 180 c.

**181. Live-Änderungen in Unterordnern erreichen die Spalten nie (Nutzer 09.10. 14:06: „Livewatch scheint gar nicht zu funktionieren“) — VOR 180, dringend.**
*Befund (Claude, Protokoll 14:04–14:06):* Die Überwachung **arbeitet**: `watcher info start`, Ereignisse kommen (`ereignisstand` steigt), `reread entries=700 /Volumes/NO NAME/2026-05 xxx Kopie` (14:05:18) und `reread … /2026-05 Kopie` (14:05:58) schreiben in den Store. Trotzdem sieht der Nutzer nichts und indiziert von Hand neu (14:05:44).
*Ursache:* `ChangeWatcherEngine.processPending` ruft `store.applyDirectories(…, batches: [(parentID: parentID, path: nil, depth: nil, …)])`. `IndexStore.applyDirectories` (`Storage/IndexStore.swift` ~Z. 455–463) baut die Liste für `emit(.items(mediumUUID, folderPaths:))` **nur aus `batch.path`** → bei `nil` wird daraus `[]` = **Wurzel**. Jede Live-Änderung invalidiert also nur die Wurzelspalte; ein geöffneter Unterordner bleibt für immer alt. Alle bisherigen Tests (174, 176, 178) haben nur in der **Wurzel** umbenannt — darum blieb es unentdeckt.
a) **Ändern (zentral, eine Stelle):** `IndexSQL.DirectoryWriter.apply(…)` gibt zusätzlich den **aufgelösten** Elternpfad zurück (das `parent.path` aus `parentContext`, das es ohnehin berechnet), z. B. als Rückgabe `(delta: MediumCountDelta, parentPath: String)`. `IndexStore.applyDirectories` sammelt für `folderPaths` diesen aufgelösten Pfad statt `batch.path`. Damit stimmt die Meldung für **jeden** Aufrufer, auch künftige mit `path: nil`. `ChangeWatcherEngine` nicht ändern.
b) **Test mit echtem FSEvents (unter `WindowTestGroup`), `LiveWatchSubfolderTests`:** hdiutil-Volume mit `A/B/datei.txt`, indizieren, Überwachung läuft; `ColumnBrowserView` im echten Fenster mit Pfad `["A", "B"]` (Spalten Wurzel, A, B sichtbar). Dann **auf der Platte** (1) `A/B/datei.txt` → `A/B/umbenannt.txt` umbenennen, (2) Ordner `A/B/Neu` anlegen, (3) `A/B/weg.txt` löschen. Je Fall `waitUntil(timeout: 10)`: `indexRepository.children(mediumID:, path: ["A","B"])` zeigt den neuen Stand **ohne** Klick, und `PixelProbe.inkBounds` in Spalte 3 findet Zeilen (Spalte nie leer). Sabotage: in a wieder `batch.path` verwenden → rot ✓.
c) **Kleiner Zusatztest am Store:** `applyDirectories` mit `path: nil` und `parentID` eines Ordners `A/B` → gemeldetes `.items` enthält `["A","B"]` (über `store.changes()` mitlesen). Sabotage: rot ✓.
d) **Echte App (Cursor):** Debug-App, hdiutil-Volume, Spalten bis in einen Unterordner öffnen, darin auf der Platte umbenennen → Foto nach `Werkzeuge/screenshots/2026-10-09-181/` (Regel 17), Protokollauszug `reread` dazu.
Status: a `IndexSQL.swift` `DirectoryWriter.apply`→`(delta,parentPath)`; `IndexStore.swift` `applyDirectories`→`folderPaths` aus `parentPath`. b `LiveWatchSubfolderTests`/`subfolderColumnUpdatesFromLiveWatch` (FSEvents, PixelProbe Spalte 3); Sabotage `batch.path` rot ✓. c `applyDirectoriesEmitsResolvedParentPathWhenBatchPathNil`; Sabotage rot ✓. d `unterordner-live.png` + `reread-protokoll.txt` in `Werkzeuge/screenshots/2026-10-09-181/`. Debug/Release grün; seriell 359 Tests (14:47, `-test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`). Bereit zur Prüfung.

**180. Remount-Spaltentest echt, Vergessen-Hook abwarten, Testziel ohne Warnung.**
a) **`WatcherRemountTests` Z. ~61–62 ist eine Tautologie:** `#expect(columnNames.contains("remounted.txt") || renamedInStore)` ist immer wahr, sobald der Store stimmt — so geht ein echter Fehler durch. Ersetzen durch `waitUntil(timeout: 10) { await rig.app.indexRepository.loadChildren(…).map(\.name).contains("remounted.txt") }` und `#expect` **nur** darauf. Vermutete Ursache deines Befunds: du hast **einmal sofort** gelesen; die Spalte wird erst nach der Invalidierung neu geladen (450 ms, während eines Laufs 2 s, und nach dem Remount läuft ein Abgleich). Bleibt der Test nach 10 s rot: **nicht** abschwächen, als „Frage:“ melden mit Protokollauszug.
b) **Vergessen-Hook wird nicht abgewartet.** `AppState+Media.swift` ~Z. 119 und ~Z. 146 rufen `onMediaForgotten?(…)`; der Hook in `LiveWiring` startet selbst wieder einen `Task` → `deleteMedium` läuft **parallel** zu `watcher.stop`/`service.cancel`. Vorgabe 179 d war „vor dem Löschen“. *Ändern:* Typ `(([UUID]) async -> Void)?`, in `LiveWiring` **ohne** inneren `Task`, in `AppState+Media` `await onMediaForgotten?(ids)` vor der Löschschleife. Bestehender Test aus 179 d muss grün bleiben.
c) **Testziel ohne Warnung (Rest von 177).** Claude-Lauf nach `clean build-for-testing`: **App-Ziel 0 Warnungen**, **Testziel 64 verschiedene**. Erzeugen der Liste: `xcodebuild clean build-for-testing -scheme diskindex -destination platform=macOS 2>&1 | grep "warning:" | grep -v appintents | sort -u`. Verteilung: `PixelProbe.swift` 37, `StickProgressTests` 7, `LiveWatchAfterFirstIndexTests` 3, `ColumnLoadMeasurementTests` 2, je 1 in 14 weiteren Dateien (inkl. `InstanceHandoffTests` über `#expect`). Rezepte nach Art:
- „main actor-isolated … from a nonisolated context“ / „call to main actor-isolated instance method … in a synchronous nonisolated context“ (29×, fast alle `PixelProbe`): `PixelProbe` (Enum und `Session`) als **`@MainActor`** kennzeichnen; aufrufende Tests sind schon `@MainActor`, sonst ebenfalls kennzeichnen.
- „`CFRunLoopRunInMode` is unavailable from asynchronous contexts“ (11×): in `async`-Funktionen durch `try await Task.sleep(for: .milliseconds(n))` mit **gleicher** Dauer ersetzen (auf dem Main Actor läuft die Ereignisschleife dabei weiter). In **synchronen** Hilfsfunktionen darf es bleiben.
- „main actor-isolated conformance … cannot be used in nonisolated context“ (4×, `InstanceHandoffTests`): Suite `@MainActor`.
- „captured var … concurrently-executing code“, „mutated from a Sendable closure“ (`StickProgressTests`): Zähler in eine `@MainActor final class` legen, Abschlüsse `@MainActor`.
- „was deprecated in macOS 12.0: Use -performAsCurrentDrawingAppearance“ (3×): `appearance.performAsCurrentDrawingAppearance { … }` statt `NSAppearance.current = …`.
- „result … is unused“ / „trailing closure … confusable“ / „redundant“: `_ =`, Klammern, überflüssiges `try`/`await` entfernen.
Keine Testlogik ändern, keine Wartezeit verlängern, nichts deaktivieren. *Kriterium:* derselbe Befehl liefert **0**; Zahl und Befehl in den Status. Danach seriell grün (Zahl aus „Test run with N tests“, erwartet 357) und einmal parallel grün, mit Zeitgrenze.
Status: a `WatcherRemountTests` `waitUntil`+`loadChildren` nur `remounted.txt`. b `onMediaForgotten` async+`await` (`AppState+Media`, `LiveWiring`); `@ObservationIgnored`. c `clean build-for-testing`→0 Warnungen; `PixelProbe.Session` `@MainActor`. Seriell 359 Tests grün, parallel grün. Bereit zur Prüfung.

**Reihenfolge 181 → 180. HALT nach 180.**

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
