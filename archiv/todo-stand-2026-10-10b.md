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

---

## A. Jetzt

**Stand 10.10.:** Abgenommen bis 194 (siehe DONE.md). Offen: 195.

## ARBEITSAUFTRAG JETZT (Claude, 10.10. — exakt so umsetzen)

**Lies zuerst diese drei Regeln, sie gelten für jede Aufgabe unten:**
- **R1 Nur die genannten Stellen ändern.** Jede Aufgabe nennt Datei und Zeile. Andere Dateien nur, wenn die Aufgabe es sagt. Keine „Verbesserungen nebenbei“.
- **R2 Beweis = Pixel aus einem echten Fenster.** `hitTest != nil`, `source.contains(…)`, Zahlenvergleiche mit Konstanten und Prüfungen nur am Datenmodell zählen **nicht** als Beweis für Aussehen oder Klickverhalten. Benutze dafür ausschließlich die Hilfe `PixelProbe` (Aufgabe 150 a). Jeder neue Test wird einmal **sabotiert** und muss dann rot sein; im Status: „Sabotage: rot ✓“.
- **R3 Status je Aufgabe:** höchstens 5 Zeilen: geänderte Dateien:Zeilen, Testname, Ergebnis der Sabotage, Pfad der Bildschirmfotos (`Werkzeuge/screenshots/<JJJJ-MM-TT>-<aufgabe>/`).

---

**Claude-Prüfung 10.10.:** 192, 193, 194 **abgenommen**. Claude: `clean build-for-testing` **0** Warnungen; **380 Tests, 101 Suiten seriell grün**; `plutil` zeigt beide Texte „Disk Archive …“. Volltexte: `archiv/todo-stand-2026-10-10.md`.
**Zwei Nebenänderungen aus 192 (Fix für `largeOpenFolderSurvivesMetaTicksDuringLiveSync`) sind fachlich falsch → 195.**

**195. Zwei Korrekturen an der Live-Kette.**
a) **`MustScanSubDirs` unterhalb der Wurzel verliert Änderungen.** `ChangeWatcher.ingest` (`Indexing/ChangeWatcher.swift` ~Z. 195–204) löst den Abgleich jetzt **nur noch** aus, wenn das Ereignis genau die Wurzel betrifft; für `/mount/A/B` läuft es wie ein normales Ereignis weiter → `directoryToReread` liest nur den **Elternordner** `A` neu, der Unterbaum von `B` (wo macOS Ereignisse **verworfen** hat — genau das bedeutet das Flag) wird nie gelesen. *Soll:* Pfad **außerhalb** des Einhängepunkts → ignorieren (das war dein eigentlicher Befund); Pfad **an oder unterhalb** des Einhängepunkts → `onFullReconcile` (Abgleich, `fromScratch: false`, wie seit 179 c). *Test* (Fake-`ChangeSource`): `mustScanSubDirs` für `/mount/A/B` → genau ein Abgleich angefordert; für `/anderswo/X` → keiner. Sabotage: heutige Fassung → rot ✓.
b) **`.counts` darf fremde Spaltenaufträge nicht verwerfen.** `scheduleIndexChange` ruft bei `.counts` `discardPendingColumnCacheInvalidation` (`App/AppState+IndexChanges.swift` ~Z. 167–170, Funktion ~Z. 260) → eine geplante Invalidierung **des ganzen Mediums** (aus `.layer` nach einer fertigen Ebene oder aus `dropAll`) wird gestrichen, die Spalten bleiben nach dem Indizieren alt. README: „Meta-Ticks (`.counts`) invalidieren nie“ heißt: sie **tun nichts** an den Spalten, sie **löschen** aber auch nichts. *Soll:* Aufruf bei `.counts` entfernen; `discardPendingColumnCacheInvalidation` löschen, falls danach unbenutzt. `largeOpenFolderSurvivesMetaTicksDuringLiveSync` muss weiter grün sein (40 Meta-Ticks planen nichts → kein Neuladen). *Neuer Test:* `.layer`-Meldung, sofort danach `.counts` → nach der Verzögerung sind die Spalten des Mediums `stale` und werden neu geladen. Sabotage: Aufruf zurück → rot ✓.
c) Seriell grün (Zahl aus „Test run with N tests“), einmal parallel, Warnungen 0 (Befehl wörtlich). Regeln 19–21.
Status (R3, Cursor): **a** `ChangeWatcher.swift` ~195–206: `mustScanSubDirs` unter Mount → `onFullReconcile`, außerhalb ignorieren; Tests `mustScanSubDirsUnderMountStartsReconcile`, `mustScanSubDirsOutsideMountIsIgnored` — Sabotage nur Wurzel **rot** ✓. **b** `AppState+IndexChanges`: `discardPending…` bei `.counts` entfernt; Test `layerWholeMediumInvalidateSurvivesCountsMetaTick` (`stale.count`); Sabotage Aufruf zurück **rot** ✓; `largeOpenFolder…` grün. **c** Seriell **383** Tests, parallel grün; Warnungen (6): **0**. Bereit zur Prüfung.

**196. Messwerkzeug Datenbank (Fahrplan Stufe 2, README; Grundlage: `datenbank-konzeption.md`, Empfehlung Schritt 1). Nur messen, nichts am App-Schema ändern.**
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
Status:

**Reihenfolge 195 → 196. HALT nach 196.**

### Weg zur Veröffentlichung (Claude 09.10., Nutzer: „langsam Richtung Production“ — Entscheidungen offen, Cursor arbeitet nicht daran)
- **Signatur und Notarisierung:** Release signiert heute mit „Apple Development“ (`CODE_SIGN_IDENTITY`). Für Weitergabe außerhalb des App Store: **Developer ID Application** + Notarisierung (`notarytool`) + Stapeln. Hardened Runtime ist schon an, Sandbox aus (README).
- **Mindest-macOS:** entschieden 14.0 → Aufgabe 184. Laufzeittest auf macOS 14 (z. B. VM) vor Release.
- **Fehlerbericht-Ziel:** live `https://diskarchive.app/api/issues` → Aufgabe 193.
- **Name:** entschieden „Disk Archive“, Bundle-ID `app.diskarchive` → Aufgabe 185.
- **Version:** `MARKETING_VERSION 1.0`, `CURRENT_PROJECT_VERSION 1` — vor Release festlegen, Build-Nummer automatisch erhöhen.
- **Release-Prüfung:** ein Release-Build mit `DEAD_CODE_STRIPPING = YES`; Debug-Werkzeuge sind sauber abgegrenzt (`#if DEBUG`/`#if BENCH` in allen `DebugTools`-Dateien geprüft).
- **Datenschutz Fehlerbericht:** `ReportScrubber` ersetzt Pfade unter `/Volumes`, `/Users`, `~` und Anführungsnamen; `leakCategory` sperrt Versand bei Restpfaden. Vor Release: ein Test mit echten Protokollzeilen dieses Tages (`reread … /Volumes/NO NAME/…`).

- **Eigene Kopie auf einem anderen Mac (ohne Notarisierung, nur für den Nutzer selbst):** Xcode → Product → Archive → „Distribute App“ → „Custom“ → „Copy App“. Kommt die App per AirDrop/Mail/Cloud und blockiert macOS sie: `xattr -dr com.apple.quarantine "/Applications/Disk Archive.app"` (Pfad anpassen; per USB-Stick kopiert meist nicht nötig). Für andere Nutzer nur mit Developer ID + Notarisierung.

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
