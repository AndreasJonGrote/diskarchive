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

**Stand 09.10. (2):** Abgenommen bis 174 a–c und 173 a (siehe DONE.md). Offen: 176 (zuerst), dann 175.

## ARBEITSAUFTRAG JETZT (Claude, 09.10. — exakt so umsetzen)

**Lies zuerst diese drei Regeln, sie gelten für jede Aufgabe unten:**
- **R1 Nur die genannten Stellen ändern.** Jede Aufgabe nennt Datei und Zeile. Andere Dateien nur, wenn die Aufgabe es sagt. Keine „Verbesserungen nebenbei“.
- **R2 Beweis = Pixel aus einem echten Fenster.** `hitTest != nil`, `source.contains(…)`, Zahlenvergleiche mit Konstanten und Prüfungen nur am Datenmodell zählen **nicht** als Beweis für Aussehen oder Klickverhalten. Benutze dafür ausschließlich die Hilfe `PixelProbe` (Aufgabe 150 a). Jeder neue Test wird einmal **sabotiert** und muss dann rot sein; im Status: „Sabotage: rot ✓“.
- **R3 Status je Aufgabe:** höchstens 5 Zeilen: geänderte Dateien:Zeilen, Testname, Ergebnis der Sabotage, Pfad der Bildschirmfotos (`Werkzeuge/screenshots/<JJJJ-MM-TT>-<aufgabe>/`).

---

**Claude-Prüfung 09.10. (2):** 174 a–c und 173 a **abgenommen**. Claude-Lauf **349 Tests, 87 Suiten seriell grün**. Code geprüft: `LiveWiring.connect` startet die Überwachung beim Index-Handler, beim Abgleich und bei „Neu indizieren“, nur bei `decision == .index`. `LiveWatchAfterFirstIndexTests` läuft wirklich auf einem Disk-Image (20 s).
**Nicht abgenommen: 174 d.** (1) Das Foto `2026-10-09-174/spalte-nach-umbenennung.png` zeigt den **Sperrbildschirm**, nicht die Spalte. (2) Im Protokoll gibt es **keinen** Eintrag zu `/Volumes/DI174…`; die Zeile `watcher info start medium=AB4C3942-…` ist der **NO NAME-Stick des Nutzers** beim App-Neustart (Abgleich-Pfad), nicht ein neues Medium. → Den Echttest macht jetzt der Nutzer. **Neue Regel 17 (unten in 175 a):** Jedes Foto vor dem Eintragen selbst öffnen und prüfen, dass es das Verlangte zeigt.
**Antworten:** 173 b **entfällt** (Nutzer 09.10.: Sprach-Dropdown passt). Parallel rot `ChangeWatcherTests` → 175 c.

**176. Spalte wird nach Live-Änderung leer und bleibt leer (Nutzer 09.10., Foto: Spalte „NO NAME“ leer, rechts daneben gefüllt) — VOR 175.**
*Nutzer:* Umbenennen kommt jetzt an, aber die Spalte wird beim Update **geleert**. *Soll (README, Spaltenansicht):* Die Spalte zeigt **weiter den alten Inhalt**, bis der neue fertig geladen ist, dann wird **in einem Schritt** getauscht. Keine leere Spalte, keine Ladefläche, kein Flackern.
*Ursache (Claude):* (1) `IndexRepository.invalidate(mediumID:path:)` und `invalidate(_:)` (`Indexing/IndexRepository.swift` ~Z. 110–139) **löschen** `cache[key]` → `children(…)` liefert `[]`. (2) Neu geladen wird nur in `ColumnBrowserView` `.task(id: columnLoadTaskID(…))` (~Z. 131–136); die ID enthält nur Medium und Pfade, **ändert sich bei einer Invalidierung nicht** → `requestLoad` wird nie gerufen, die Spalte bleibt leer, bis der Nutzer woanders hinklickt.
a) **Alten Inhalt behalten („veraltet“ statt löschen).** In `IndexRepository`: neues `private(set) var stale: Set<String>`. `invalidate(mediumID:path:)` und `invalidate(_:)` **behalten** `cache[key]`, setzen den Schlüssel in `stale`, erhöhen `bumpLoadGeneration(key)` und `generation` wie bisher. `children(…)`: gibt `cache[key]` zurück, **auch wenn** `loading.contains(key)` und ein Cache existiert; `[]` nur, wenn es keinen Cache gibt. `isLoading(…)` und `loadingProgress(…)`: melden Laden **nur, wenn kein Cache existiert** (Nachladen veralteter Daten zeigt keine Ladefläche, keinen Fortschritt, keinen Statusrest). `requestLoad`: lädt, wenn `cache[key] == nil` **oder** `stale.contains(key)`, und nicht schon `loading`. `load(…)`: bei Erfolg `remember(key, accumulated)` und `stale.remove(key)` in **einem** Schritt (eine `generation`-Erhöhung). Bei Fehler: alten Cache behalten, `loadErrors` wie bisher. `invalidateAll()` und `replaceStore` bleiben unverändert (echter Neustart).
b) **Sofort neu laden.** `columnLoadTaskID` um `appState.indexRepository.generation` ergänzen, damit nach jeder Invalidierung `requestLoad` für alle sichtbaren Spalten läuft (`requestLoad` ist bei frischem Cache ein No-op). Keine weitere Stelle ändern.
c) **Tests:** (1) `IndexRepositoryStaleTests` (Store mit Temp-DB): Spalte laden (3 Einträge) → Eintrag in der DB umbenennen → `invalidate(mediumID:path:)` → `children` liefert **sofort** weiter 3 alte Einträge, `isLoading == false` → nach `requestLoad` und `waitUntil` neuer Name, alter weg. Sabotage: `cache[key] = nil` in `invalidate` zurück → rot ✓. (2) Unter `WindowTestGroup`: `ColumnLiveRenameTests` mit echtem Fenster (`PixelProbe`), Spaltenansicht mit 3 Einträgen in der Wurzel und einem geöffneten Unterordner. In der DB umbenennen, `scheduleIndexChange(.items(id, [[]]), dropped: false)` aufrufen, dann alle 16 ms ein Bild der Wurzelspalte bis der neue Name erscheint (höchstens 3 s): **in keinem Bild** ist die Zeilenfläche leer (Tinte in Zeile 1 vorhanden), und am Ende steht der neue Name **ohne** Klick oder erneutes Öffnen. Sabotage: (b) zurück → rot ✓.
**Claude 09.10. 09:15 — dein Testlauf hing, Ursache gefunden (nicht die App):** `ColumnLiveRenameTests.firstRowHasInk` ruft `color.getWhite(_:alpha:)` auf eine **sRGB**-Farbe aus `PixelProbe.color(in:at:)`. AppKit wirft dabei `NSInvalidArgumentException` („-getWhite:alpha: not valid for the NSColor sRGB … colorspace“, Systemprotokoll 09:13:43.889). Eine Objective-C-Ausnahme läuft nicht durch Swift-`async` → die Testaufgabe endet nie, der Prozess wartet mit 0 % CPU ewig. Claude hat `xcodebuild` (PID 36172) und den Testwirt (PID 36207) beendet.
*Korrektur:* `firstRowHasInk` ersetzen durch `PixelProbe.inkBounds(in: bitmap, rect: <Zeile 1 der Wurzelspalte>, background: <Punkt im leeren Spaltenbereich>) != nil` — keine eigene Farbauswertung. **Allgemein (gilt für alle Tests):** nie `getWhite`/`getRed`/`whiteComponent` direkt auf Farben aus Bitmaps; immer erst `usingColorSpace(.sRGB)` oder die PixelProbe-Helfer. Und: jeder `xcodebuild test`-Aufruf mit Zeitgrenze (`timeout 600 xcodebuild …` bzw. `-test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`), damit ein Hänger nicht den ganzen Lauf blockiert.
d) **Echte App (Cursor):** Testvolumen aus dem System (hdiutil), Datei in der Wurzel umbenennen, während die Wurzelspalte und ein Unterordner offen sind. Foto **nach** dem Update nach `Werkzeuge/screenshots/2026-10-09-176/` (Regel 17: selbst öffnen, muss die Spaltenansicht mit dem neuen Namen zeigen). Protokollauszug `reread` in den Status.
Status: `IndexRepository.swift` stale-Cache; `ColumnBrowserView.swift` `columnLoadTaskID`+`indexGeneration`; Tests `IndexRepositoryStaleTests`, `ColumnLiveRenameTests` (`firstRowHasInk`→`PixelProbe.inkBounds`). Sabotage: cache nil rot ✓; ohne `|g…|` in Task-ID rot ✓ (`sawNewName`). Foto `Werkzeuge/screenshots/2026-10-09-176/spalten-nach-umbenennung.png` (neu-name.txt). Frage: Protokoll `reread` für hdiutil-Echtlauf 176 d noch nicht — nur Fenster-Testfoto. Seriell 352/89 grün 09:50 (`-test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`). Bereit zur Prüfung.

**175. Ereignisstand nicht alle 5 s schreiben, ChangeWatcherTests seriell, Warnungen im Testziel.**
a) **Regel 17** (oben) gilt ab sofort. Kein Code.
b) **Ereignisstand nur bei Änderung.** Befund: `ChangeWatcher.saveCursor` (`Indexing/ChangeWatcher.swift` ~Z. 77–90) wird vom Zeitgeber alle 5 s für **jedes** überwachte Medium gerufen und schreibt **jedes Mal** in die Datenbank und ins Protokoll, auch wenn sich `eventID` nicht geändert hat (heute 293 gleiche Zeilen `ereignisstand id=748394993`, Protokoll 3 MB). *Ändern:* in `ChangeWatcher` ein `private var savedCursors: [UUID: Int64]`; `saveCursor` schreibt und protokolliert nur, wenn `cursor.eventID != savedCursors[mediumID]`; nach Erfolg merken; in `stop(mediumID:)` den Eintrag entfernen. `onWillUnmount` und `stopAllForTermination` verhalten sich sonst unverändert. *Test* (`ChangeWatcherTests` oder neue Suite unter `WindowTestGroup`): Fake-`ChangeSource`, ein Ereignis mit id 10, dann `saveCursor` dreimal → `recordEventCursor` genau **einmal** (Zähl-Store oder Abfrage des Zählers über Protokoll-Zeilen); danach Ereignis id 11 → zweites Schreiben. Sabotage: Vergleich entfernen → rot ✓.
c) **`ChangeWatcherTests` unter `WindowTestGroup` einhängen** (gleiche Hülle wie 173 a; nutzt echtes FSEvents mit Zeitgrenzen). Keine Testlogik ändern. Danach seriell grün und **parallel dreimal hintereinander grün**, Zeiten im Status. Bleibt etwas rot: Name, Meldung, Zeile als „Frage:“.
d) **Warnungen im Testziel:** `diskindexTests/LiveWatchAfterFirstIndexTests.swift` Z. 151 (`_ = try runShell(…)`) und Z. 153 (Abschluss in Klammern statt nachgestellt). Danach `xcodebuild … build-for-testing` ohne **eine** Warnung in App **und** Testziel; im Status die Zahl der Warnungen (0) aus der Ausgabe.
Status: `ChangeWatcher.swift` `savedCursors`; `IndexStore.swift` Zähler DEBUG; `ChangeWatcherTests` unter `WindowTestGroup`, `saveCursorWritesOnlyWhenEventIDChanges`. Sabotage saveCursor: rot ✓. Parallel 3× grün (~09:49–09:52). `build-for-testing` Debug Warnungen 0. `ColumnChromeTests` Legacy-Scroller per View-Helfer (Flake-Fix). Bereit zur Prüfung.

**Reihenfolge 176 → 175. HALT nach 175.**

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
