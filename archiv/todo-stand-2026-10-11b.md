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

## A. Jetzt — Version 0.2 „Alle bekannten Fehler“

**Maßgeblich für Versionen und Reihenfolge: README, Abschnitt „Roadmap“** (ausführlich: [ROADMAP.md](ROADMAP.md), folgt der README). In A steht nur, was zur **laufenden Version (0.2)** gehört, also bekannte **Fehler**. Was nach dem Einfrieren auffällt und kein Fehler ist, kommt nach B mit Zielversion.

**Stand 11.10.:** Abgenommen bis 209 (siehe DONE.md). **Freigegeben: 210 → 211 → 212 → 213 → 214 (Paket aus Nutzertest 11.10.). HALT nach 214.**

**Claude-Prüfung 11.10.:** 209 **abgenommen**. Claude: 0 Warnungen, **395 Tests seriell grün**, App 00:07:58 aktuell. Volltext: `archiv/todo-stand-2026-10-11.md`.

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
| F6 | Fehlerdialog zeigt **nie** einen Grund: `IndexingService` meldet immer `reason: .unknown`; `IndexRunOutcome` trägt keinen Fehler, `IndexFailureReason.classify` wird nur von Tests benutzt (README 2b verlangt den Grund) | Claude-Durchsicht 10.10. | **behoben** 10.10. (202) |
| F7 | Englisch unvollständig: feste deutsche Texte außerhalb von `L10n` (Kontextmenü, Menüleisten-Rechtsklick, Mitteilungen, Fehlergründe, Statuszeilen, Altersfilter, Fußzeile „x von y ausgewählt“, „Zuletzt indiziert“, Platzhalter) und feste `de_DE`-Formate | Claude-Durchsicht 10.10. | **behoben** 10.10. (203) |
| F8 | Toter Code, nur von Tests benutzte Logik, Doppeltes | Claude-Durchsicht 10.10. | **behoben** 10.10. (201) |
| F10 | Tests schreiben in die echten Einstellungen des Nutzers (`UserDefaults.standard` = `app.diskarchive`) | Claude-Prüfung 10.10. | **behoben** 10.10. (205) |
| F11 | `serviceRunPassesTheReasonToTheDialog` fällt im **parallelen** Lauf selten aus (2× gesehen, Meldung nicht erfasst; seriell 10/10 grün) | Agent 10.10. | beobachten; beim nächsten Ausfall Meldung sichern |
| F12 | Jeder Testlauf hinterlässt eine Datei `~/Library/Preferences/app.diskarchive.tests.<pid>.plist` (16 Stück am 10.10.) | Claude-Prüfung 10.10. | **behoben** 10.10. (208) |
| F9 | Stresstest 1 TB (Nutzer 10.10.): erster Lauf zeigt **2 Minuten nichts** (Start 10:13:02, „ebene 1 fertig“ 10:15:02), weil die **Zählphase** (README 4) erst den ganzen Baum liest, bevor Ebene 1 geschrieben wird. Widerspricht „Schichten: erste Ebene sofort sichtbar“ | Claude, Protokoll 10.10. | **behoben** 10.10. (206, Nacharbeit 209) |
| F13 | Beim Abgleich nach dem Start blinkt die Prozentzahl im Dashboard grün/rot: der Hintergrund-Nachzähler (`DirectoryIndexer` ~Z. 146 `Task { runCountingPhase(… onProgress: onProgress) }`) meldet `.counting`, die Ebenen-Schleife gleichzeitig `.indexing` → Phase springt | Nutzer 11.10., Claude-Ursache | **freigegeben als 210** |
| F14 | Spinner im Dashboard-Chip dreht sich nicht (steht in `TimelineView`, die 30× pro Sekunde neu zeichnet; `IndexingSpinnerRing` nutzt `repeatForever` aus `onAppear`) | Nutzer 11.10. | **freigegeben als 210** |
| F15 | Suche zählt höchstens 50.000 (`IndexStore.searchCount` mit `scope` holt `limit: 50_000` und zählt in Swift); „.html“ ergibt 50.000 statt ca. 1,6 Mio. | Nutzer 11.10. | **freigegeben als 211** |
| F16 | Suchergebnisse flackern im Takt des Fortschritts (`runSearch` leert `searchMatch` vor jeder neuen Suche; jede Live-Meldung startet die Suche neu) | Nutzer 11.10. | **freigegeben als 211** |
| F17 | X im Suchfeld leert das Feld, aber nicht die Suche | Nutzer 11.10. | **freigegeben als 211** |
| F18 | Scrollleisten fehlen in der Ergebnisliste der Suche, in Einstellungen → Speichermedien und in sehr großen Ordnern (`ColumnFolderTableView` ~Z. 26 `hasVerticalScroller = false`) | Nutzer 11.10. | **freigegeben als 212** |
| F19 | Prozentzahl im Menüleisten-Popover nicht rechtsbündig | Nutzer 11.10. (Foto) | **freigegeben als 213** |
| F20 | Rote Vorschlagstexte gelten als festgelegt (Nutzer 11.10.: „setze alle roten Texte als gesetzt“) | Nutzer 11.10. | **freigegeben als 214** |
| F2 | Live-Überwachung am echten Stick nach 195 bestätigen: Umbenennen, neuer Ordner, Kopieren, Spalte bleibt sichtbar und aktualisiert sich | Nutzer 09.10. | **bestätigt** 10.10. (erster Test lief mit veraltetem Sabotage-Build → Regel 23) |

Weitere Fehler aus dem Alltag trägt Claude hier ein, sobald der Nutzer sie meldet.

---

---

**210. (F13, F14) Anzeige während des Laufs ruhig und lebendig.**
a) **Blinken:** Der Nachzähler beim Abgleich (`DirectoryIndexer.run` ~Z. 146, `Task { runCountingPhase(…) }`) bekommt **kein** `onProgress` mehr (leerer Rückruf); er aktualisiert nur `scanTotal` in der Datenbank wie heute. Ergebnis: Ein Lauf mit gespeicherter Gesamtzahl meldet nur Phase `.indexing`. Test: Abgleich mit gespeicherter Gesamtzahl und verzögertem Lesen → **alle** `onProgress`-Ereignisse haben `phase == .indexing`. Sabotage: `onProgress` wieder durchreichen → rot ✓.
b) **Spinner dreht sich überall:** `IndexingSpinnerRing` dreht sich auch innerhalb einer `TimelineView` (Dashboard-Chip, `StatusChip.swift` ~Z. 15–37). Empfehlung: Winkel aus der Zeit berechnen (`TimelineView(.animation)` im Ring selbst, Winkel = Zeit modulo 0,9 s × 360°) statt `repeatForever` aus `onAppear`; eine Quelle für Chip, Popover-Zeile und Seitenleiste (Regel 12). Test (`PixelProbe`, Dashboard-Karte mit Medium „Wird indiziert“): zwei Aufnahmen des Spinners im Abstand von 0,3 s unterscheiden sich. Sabotage: Winkel fest → rot ✓.

**211. (F15, F16, F17) Suche: genaue Zahl, kein Flackern, X leert.**
a) **Zahl:** `IndexStore.searchCount` (`Storage/IndexStore+Search.swift` ~Z. 24–33) zählt **ohne Obergrenze**. Die Regeln aus `IndexScope` (Tiefe, unsichtbare Dateien, Artefakte, Ausschlüsse) möglichst als SQL-Bedingung; was nicht in SQL geht, über einen Cursor ohne `limit` zählen (kein Array mit allen Zeilen). Dauer für eine Suche mit über 1 Mio. Treffern messen (Release-Build, Regel 8) und in den Status. Über 1 s → „Frage:“ mit Messwert (die Datenbank wird in 0.3 ohnehin umgebaut). Test: 60.000 Treffer → Zahl 60.000. Sabotage: Obergrenze zurück → rot ✓.
b) **Kein Flackern:** `AppState.runSearch` leert die Ergebnisse **nicht** mehr vor der neuen Suche; die alten bleiben sichtbar, bis die neuen da sind (wie „veraltet statt leeren“ in der Spaltenansicht). Während ein Medium indiziert wird, startet die Suche durch Live-Meldungen höchstens **alle 2 s** neu; eine Suche, die der Nutzer selbst abschickt, sofort. Test: 20 Live-Meldungen in 1 s bei offener Suche → höchstens 1 Neustart, `searchMatch` ist zwischendurch nie leer. Sabotage: Leeren zurück → rot ✓.
c) **X im Suchfeld** (`ObjectSearchField`): leert Feld **und** Suche (`submittedQuery` leer, Ergebnisse weg, Leerzustand der Suche wie beim ersten Öffnen). Gilt auch für das Suchfeld im Menüleisten-Popover. Test über `PixelProbe.click` auf das X. Sabotage → rot ✓.

**212. (F18) Systemscrollleisten auch in Suche, Einstellungen und großen Ordnern.** README „Spaltenansicht: Scrollen“ gilt sinngemäß für **alle** langen Listen (Nutzer 11.10.).
a) Ergebnisliste der Suche (`Views/Search/ObjectResultsTable.swift` ~Z. 45), Einstellungen → Speichermedien (`SettingsMediaRegistryPanel.swift` ~Z. 40) und sehr große Ordner (`ColumnFolderTableView.swift` ~Z. 26 `hasVerticalScroller = false` → `true`) zeigen die senkrechte Systemleiste, wenn der Inhalt länger ist als die Fläche. Erst **Ursache** finden, warum die Leiste in Suche und Einstellungen fehlt (verschachtelte ScrollView? abgeschnittener Rand?), 1 Zeile in den Status.
b) Tests wie in 198 (beide Stile, `flashScrollers()`, Rahmen des `verticalScroller` sichtbar und innerhalb der Fläche) für alle drei Stellen mit langem Inhalt. Sabotage je Stelle → rot ✓.

**213. (F19) Prozent im Popover rechtsbündig.** `MenuBar/MenuBarConnectedMediumRow.swift` (~Z. 150, Prozenttext neben dem Spinner): rechte Kante des Prozenttexts bündig mit der rechten Innenkante der Zeile (gleicher Abstand wie links das Icon zum Zeilenrand, Layout Screen 03). „5 %“, „63 %“ und „100 %“ enden an derselben x-Position. Test (`PixelProbe`, Tintengrenzen): rechte Kante bei allen drei Werten gleich (±0,5 pt) und Abstand zum Zeilenrand = linker Abstand des Icons. Sabotage → rot ✓.

**214. (F20) Rote Vorschlagstexte werden normale Texte.** *Nutzer 11.10.: alle roten Texte gelten als gesetzt; neue Layouts kommen später.*
a) Alle Texte aus `DesignSystem/ProposalCopy.swift`, `ProposedCopy.swift` und `UncapturedFolderContextHint` wandern als normale Einträge nach `LayoutCopy` (Schlüssel im Katalog, **de unverändert**, **en neu**; neue en-Texte an `docs/englisch-neu.md` anhängen).
b) Den Rot-Mechanismus ganz entfernen: `ProposalCopySettings`, `proposalRed`, die Hervorhebung, den Debug-Menüpunkt (`MenuBarController.swift` ~Z. 243, 300) und den Einstellungsschlüssel `highlightProposalCopy`. Auch die Zählanzeige im Chip (`StatusChip.usesProposalCountingLabel`) erscheint danach in normaler Farbe.
c) Die Ausnahme für Vorschlagstexte im Quell-Scan von 203 entfällt; der Scan-Test bleibt grün.
d) `grep -rn "ProposalCopy\|ProposedCopy\|proposalRed\|highlightProposal" diskindex diskindexTests` → leer. Keine Sabotage (Entfernen). Testzahl vorher/nachher.

**Für 210–214:** nach jeder Aufgabe seriell grün (Zahl), am Ende parallel, Warnungen 0, zum Schluss **Regel 23**.
Status 210–214:
- 210: a) `DirectoryIndexer.run`: Nachzähler beim Abgleich mit leerem `onProgress`; Test `reconcileWithStoredTotalReportsOnlyTheIndexingPhase`, Sabotage rot ✓. b) `IndexingSpinnerRing` rechnet den Winkel aus der Uhrzeit (`TimelineView(.animation)`), eine Quelle für alle Orte; Tests `spinnerAngleAdvancesWithTime`, `dashboardChipSpinnerRotates` (zwei Aufnahmen 0,3 s), Sabotage Winkel fest: rot ✓ (`IndexingDisplayTests.swift`). Bereit zur Prüfung.
- 211: a) `searchCount` ohne Obergrenze (SQL für Tiefe/`._`/Systemordner/versteckt, Cursor für Artefakte und Muster; `searchRequest(ordered:)`); Test 60.000 Treffer, Sabotage Grenze: rot ✓. **Messung 1,2 Mio. Treffer (Debug mit `-O`, weil das Test-Ziel in Release nicht übersetzbar ist): mit Bereich 4,4 s, ohne Bereich 0,16 s** (gated `SearchCountBenchTests`, `DA_BENCH=1`). **Frage:** über 1 s — so lassen (0.3 baut um) oder Namensprüfung beschleunigen? b) `runSearch` leert nicht mehr; `runSearchAfterLiveChange` höchstens alle 2 s; c) X → `clearObjectSearch()`, Popover-Leerfeld ohne Suche. `SearchBehaviorTests` (4), Sabotage je rot ✓. Bereit zur Prüfung.
- 212: Ursache Suche: `GeometryReader` um die `ScrollView` — im Legacy-Stil hängt SwiftUI die Leiste außen an (Rahmen +15 pt), sie lag hinter dem Fensterrand (jetzt Breitenmessung per Preference); Einstellungen → Speichermedien: kein Fehler nachstellbar (Leiste in beiden Stilen da, nur Wächtertest); große Ordner: `hasVerticalScroller = true`. `ScrollersEverywhereTests` (3 × 2 Stile), Sabotage je Stelle rot ✓. Bereit zur Prüfung.
- 213: Ursache: `ZStack` im rechten Platz schrumpft auf den Inhalt und `frame(alignment: .center)` zentrierte ihn → `.trailing`. `PopoverPercentAlignmentTests` (5/63/99 %; „100 %“ nicht darstellbar, Anzeige max. 99 %), Sabotage rot ✓. `ReindexGateTests` maß im Popover bisher gar nicht den Knopf (Einheiten) → Messbereich relativ + helles Schema. Bereit zur Prüfung.
- 214: 22 Texte nach `LayoutCopy+Menus.swift` (de unverändert, en neu, Tabelle an `docs/englisch-neu.md`), Rot-Mechanismus samt `ProposalCopy.swift`, `ProposedCopy.swift`, Debug-Menüpunkte, Chip-Sonderfall entfernt, `languageSettingDescription` (ungenutzt) gelöscht; `grep` leer. Tests: `ProposalCopyPresentationTests` gelöscht, `ProposalCopyTests` → `NoGermanLiteralsTests` (ohne Layout-Test), Ausnahmen im Quell-Scan entfernt, `formerProposalTextsAreLocalized` neu. Tests 408 → 407. Bereit zur Prüfung.
- Gesamt: seriell 407 Tests grün, parallel 2/2 grün, Warnungen 0, Build 02:00:05, jüngste Swift 01:50:42 (`find` leer).

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
Status: (noch nicht freigegeben) — **Zusatz (Nutzer 10.10., 204 ja):** mit 196 die alte `DebugTools/ColumnLoadBench.swift` samt `#if BENCH`-Zweigen (`AppDelegate`, `SystemNotice`) entfernen.

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
