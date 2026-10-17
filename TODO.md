# TODO.md — offene Aufgaben und Fehler

Einzige Aufgabenliste. Erledigtes: [DONE.md](DONE.md). Verlauf und alte Fassungen: `archiv/`. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). Versionsplan: README „Roadmap“, ausführlich [ROADMAP.md](ROADMAP.md). **Komponenten (Maße, Farben, Zustände): [layout/Komponenten.dc.html](layout/Komponenten.dc.html), zusammengefasst in [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md).** Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

## Kennungen (Nutzer 14.10.)

- **`todo.<Version>.<Nr>`** = Aufgabe (Funktion, Politur, Doku, Entscheidung).
- **`bug.<Version>.<Nr>`** = Fehler.
- `<Version>` ist die **Zielversion** aus der Roadmap (`0.4`, `0.3.2` …), `<Nr>` dreistellig und je Art und Version fortlaufend (Beispiel: `bug.0.4.014`). Die Kennung steht im Status, im Commit und in DONE.md. **Ausnahme (Host 16.10.):** Die schon vergebenen `bug.0.4.xxx` behalten ihre Nummern (sie stehen in Commits und DONE.md), auch wenn ihre Zielversion 0.3.8 oder 0.3.9 ist; maßgeblich ist die Spalte „Zielversion“ in der Paketliste. Neue Kennungen tragen die echte Zielversion (`bug.0.3.8.xxx`). Fehler-Nummern aus dem Audit 13.10. (`REPORT 54` …) stehen im Archiv `archiv/report-audit-2026-10-13.md`; jede Aufgabe nennt ihre Nummern.
- **Host und Worker** bestimmt der Nutzer bei der Übergabe (AGENTS.md). Worker (jeder Agent, auch auf einem anderen Gerät) arbeiten, der Host prüft und nimmt ab (Regel 28). `REPORT.md` bleibt leer; Fehler werden direkt hier als `bug.*` eingetragen.

## Regeln für den Worker (verbindlich)

**Rollen (Nutzer 17.10.):** Der Nutzer sagt jedem Agenten bei der Übergabe, ob er **Host** oder **Worker** ist (AGENTS.md). Es zählt nur diese Rolle, nicht der Name des Agenten. In dieser Datei heißt „Umsetzer“ = **Worker** und „Claude“ (prüft, nimmt ab, schreibt Aufgaben) = **Host**, auch in älteren Einträgen. Ein Claude in der Worker-Rolle befolgt alle Regeln hier wie jeder andere Worker.

1. **Nur freigegebene Aufgaben aus „A. Jetzt“**, in der dort stehenden Reihenfolge. „B. Backlog“ und alles andere nicht anfassen, auch nicht „vorbereiten“.
2. **Nach jedem Paket anhalten** (Zeile „HALT“). Erst weiterarbeiten, wenn Claude in A. freigegeben hat.
3. **Nichts erfinden.** Kein Feature, Text, Schalter, Screen ohne Vorgabe in README oder Layout. Fehlt etwas: Frage unter die Aufgabe schreiben („Frage:“), nicht bauen. Nötige Texte ohne Layout-Vorlage (ab 11.10., Nutzer): normal über `L10n`/`LayoutCopy` mit de und en anlegen und im Status als „Neue Texte:“ auflisten; der Nutzer prüft sie.
4. **Layout, README, ROADMAP, DONE.md und REPORT.md sind schreibgeschützt** für den Umsetzer (auch `AGENTS.md`, `archiv/`). Abweichung gefunden → als „Frage:“ melden, nicht selbst „angleichen“.
5. **Diese Datei:** Der Umsetzer ändert nur das Feld „Status“ (bei Nacharbeit „Nacharbeit-Status“) der jeweiligen Aufgabe (höchstens 5 Zeilen: was, welche Dateien, Abweichung) und am Ende PROMPT.md (Regel 30). Keine Reviewblöcke, keine neuen Aufgaben, nichts umsortieren, nichts löschen. Claude räumt auf.
6. **Keine Selbstfreigabe.** Umsetzer schreibt „Bereit zur Prüfung“, nie „fertig“. Nur Claude verschiebt nach DONE.md.
7. **Belege statt Behauptungen:** „Tests grün“ nur mit Zahl, Uhrzeit, Kommando. Bildschirmfotos nur melden, wenn sie in diesem Lauf neu erzeugt wurden (Zeitstempel prüfen). Build Debug (einschließlich Testziel) und Release ohne Warnung, selbst gezählt.
8. **Tests:** nur `-only-testing:diskindexTests`; nach **jeder Aufgabe die betroffenen Suites** (`-only-testing:diskindexTests/<Suite>`), am **Ende des Pakets** den Gesamtlauf seriell und den Parallellauf **dreimal hintereinander** (Kommando und Uhrzeiten im Status). UI-Tests nicht starten (Passwortabfrage). Leistungszahlen nur im Release-Build.
9. **Kein Aufräumen, Verschieben oder Löschen** von Dateien, die nicht in der Aufgabe stehen. Kein Refactoring „nebenbei“.
10. **Echte Fenster testen, nicht nur Bilder.** Das Offscreen-Bildschirmfoto (`ScreenshotRunner`) beweist nicht, dass eine Ansicht im echten Fenster funktioniert (Beispiel: `NSTableView`-Zeilen waren im Foto da, im echten Fenster leer). Bei jeder Aufgabe, die Ansichten, Klickflächen oder `NSViewRepresentable` berührt: Test mit echtem `NSWindow` (`makeKeyAndOrderFront`, Layout abwarten, Zeilen/Knöpfe zählen, Klick per `hitTest` auf Randpunkte).
11. **Regression-Rauchtest** (`RegressionSmokeTests`, wird bei jeder Aufgabe erweitert): jede Ansicht, die schon einmal kaputt war, bekommt eine Zeile. Vor „Bereit zur Prüfung“ muss er grün sein. Eine Aufgabe, die etwas Abgenommenes wieder kaputt macht, gilt als nicht erledigt.
12. **Gemeinsame Bausteine nur zentral ändern** (Knopf, Chip, Zeile, Spaltenkopf, Leerzustand): eine Quelle, Änderung wirkt überall, Test an der Quelle. Keine zweite Kopie in einer Ansicht.
13. **Maße nur aus dem Komponentenkatalog** (`docs/Komponenten-Masse.md`, Quelle `layout/Komponenten.dc.html`). Keine eigenen Zahlen für Höhe, Innenabstand, Schrift, Rahmen, Radius. Jede Komponente hat einen Messtest gegen diese Zahlen (±0,5 pt), Hell und Dunkel.
14. **Nach Fehlern zurückrollen statt überbauen:** schlägt ein Test fehl oder hängt er, Ursache beheben; weder den Test abschwächen noch Zeitgrenzen verlängern noch wiederholen, bis er grün ist.
15. **Zeichenpfad sauber halten:** in `body`, `init`, `Binding(get:)`, `@State … = …` und `onAppear` **keine** Systemaufrufe (`SMAppService`, `UNUserNotificationCenter`, Dateisystem, Datenbank) und **keine** Zustandsänderungen. Solche Werte liegen in `AppState` und werden im Hintergrund aktualisiert.
16. **Zeilenangaben sind Richtwerte** („Z. ~“). Gilt eine Zeile nicht mehr, über den genannten **Symbolnamen** suchen; nichts an anderer Stelle „ähnlich“ ändern.
17. *(entfällt: keine Bildschirmfotos, siehe Regel 19; die Nummer bleibt, weil andere Stellen auf spätere Regeln verweisen.)*
18. **Keine Nachhilfe in End-to-End-Tests.** Ein Test, der eine Kette beweisen soll (Platte → FSEvents → Store → Meldung → Spalte), darf keinen Schritt dieser Kette selbst aufrufen (`flushIndexChange`, `scheduleIndexChange`, `invalidate`, `requestLoad`, `loadChildren` als Ersatz für die Anzeige). Er wartet nur und liest das Ergebnis. Geht es ohne Nachhilfe nicht, ist das ein Befund → „Frage:“.
19. **Bildschirm des Nutzers frei lassen (Nutzer 09.10.: „keine Screenshots, nur Script-Prüfung“, gilt bis auf Widerruf).** Keine echte App starten, keinen `ScreenshotRunner`, keine Bildschirmfotos, nichts aktivieren oder in den Vordergrund holen. Nachweis nur über `xcodebuild test` (mit Zeitgrenze), Protokolldateien und Skripte (`sqlite3`, `grep`). `PixelProbe`-Fenster werden **außerhalb des sichtbaren Bereichs** geöffnet (Ursprung `x: -20000, y: -20000`, `orderFrontRegardless` statt `makeKeyAndOrderFront`, nie `NSApp.activate`); `cacheDisplay` funktioniert dort genauso. Echte-App-Teilaufgaben entfallen und werden durch einen Skript-Nachweis ersetzt.
20. **Tests stürzen nie ab und flaken nicht.** *Testaufbau:* keine prozessweiten statischen Variablen für Verzögerungen oder Schalter (der Parallellauf teilt Prozesse; stattdessen Parameter, Provider oder `@TaskLocal`), kein `lock()` über ein `await`, Zeitgrenzen mit Reserve (nie genau an der eigenen Grenze), keine exakten Zählvergleiche auf asynchrone Ereignisse (`>=` oder auf die Bedingung warten). Kein Zugriff `array[i]` ohne vorheriges `try #require(array.count > i)` (bzw. `#require(array.first)`), kein `!` auf Optionals, keine Bereiche `a..<b` ohne Prüfung `a <= b`. Ein fehlgeschlagener Test meldet „rot“, er beendet nie den Prozess (sonst Absturzbericht auf dem Bildschirm des Nutzers, Regel 19). Vor „Bereit zur Prüfung“: `grep -n '\[0\]\|\[1\]\|\[2\]' diskindexTests/<neue Dateien>` und jede Stelle absichern.
21. **Keine System-Ereignisse aus Tests.** Verboten: `CGEvent(…).post(…)`, `CGWarpMouseCursorPosition`, `AXUIElement…`, alles, was die **echte** Maus/Tastatur des Nutzers bewegt oder Bedienungshilfen-Rechte braucht (Nutzer 09.10. 23:00: macOS fragte „Disk Archive möchte diesen Computer mit Funktionen der Bedienungshilfe steuern“). Klicks nur per `NSEvent.mouseEvent(…)` + `window.sendEvent` an das **eigene** Testfenster (wie `PixelProbe.click`). Kein `makeKeyAndOrderFront`, kein `NSApp.activate` (Regel 19).
22. **Kein Git, kein GitHub (AGENTS.md).** Keine verändernden Git-Befehle (`commit`, `add`, `push`, `pull`, `checkout`, `stash`, `worktree`, `reset` …), keine Best-of-N-Läufe mit Git-Arbeitskopien, nichts auf GitHub. Nur `git status`/`log`/`diff`/`show` zum Nachsehen.
23. **Zum Schluss die App bauen, die der Nutzer startet (Nutzer 10.10.).** Letzter Schritt **je Paket** (nicht je Aufgabe, Host 16.10.), **nach** Sabotage-Rücknahme und Testläufen: `xcodebuild build -project diskindex.xcodeproj -scheme diskindex -configuration Debug -destination 'platform=macOS'` **ohne** `-derivedDataPath` (Ziel: `~/Library/Developer/Xcode/DerivedData/diskindex-…/Build/Products/Debug/Disk Archive.app`, dort startet der Nutzer). Dann belegen: `stat -f '%Sm' -t '%H:%M:%S'` der Datei `Contents/MacOS/Disk Archive` ist **jünger** als die zuletzt geänderte `.swift`-Datei (`find diskindex -name '*.swift' -newer <App-Binary>` muss **leer** sein). Beide Uhrzeiten in den Status. Ohne diesen Beleg gilt das Paket als nicht fertig. Grund: Am 10.10. testete der Nutzer einen Sabotage-Build, weil nach der Rücknahme nicht mehr gebaut wurde.
24. **Kennung nennen.** Im Status und in Commit-Vorschlägen steht immer die Kennung (`bug.0.4.014`, `todo.0.4.010` …), bei Fehlern zusätzlich die REPORT-Nummer (Archiv `archiv/report-audit-2026-10-13.md`).
25. **Repro-Tests.** Nennt eine Aufgabe einen Repro-Test aus `Werkzeuge/audit-repro/ReproAuditTests.swift` (Ordner schreibgeschützt), wird der Test in eine passende Suite unter `diskindex/diskindexTests/` übernommen (`@Suite(.serialized) @MainActor`). **Vor dem Fix ausführen und das Rot im Status belegen**, danach grün. Testname und Meldung dürfen angepasst werden, die Erwartung nicht.
26. **Parallelbetrieb.** Vor jeder Aufgabe `git status`. Sind `.swift`-Dateien geändert, die nicht von dir stammen (anderes Gerät oder anderer Agent arbeitet), **anhalten** und „Frage:“ schreiben. Keine fremden Änderungen überschreiben.
27. **Schema nach 0.3 nur erweitern** (README, Abschnitt „Datenbank“): neue Migrationen, neue Indizes, neue Schlüssel; keine bestehende Tabelle umbauen.
28. **Abnahme nur durch den Host.** Der Host prüft Code, Build (0 Warnungen, Testziel eingeschlossen), seriellen Gesamtlauf, Parallelläufe und Regel 23 und trägt die Aufgabe erst dann in DONE.md ein; ein Sprung (0.3.8, 0.3.9) zählt erst bei allen Abnahmekriterien (Abschnitt A). Eine Selbstabnahme (wie in der früheren „Cursor-Spur“) gilt nicht.
29. **Signatur.** Ohne gültiges Zertifikat baut man für Tests mit `CODE_SIGN_IDENTITY="-"`; Regel 23 verlangt dann das Zertifikat für den Nutzer-Build, den baut der Host.
30. **Antwort mit Prompt und Commit.** Jeder Bericht des Workers endet mit zwei Teilen: (1) einem **Prompt für den Host** in einem Codeblock, höchstens 12 Zeilen: Kennungen und „Bereit zur Prüfung“ oder „Blockiert: …“; geänderte Dateien je Aufgabe; Belege (Warnungen, Testläufe mit Art, Zahl und Uhrzeit, Sabotage rot ✓, Regel 23 mit beiden Uhrzeiten); offene „Frage:“; letzte Zeile „Prüfe die genannten Aufgaben nach Regel 28 und gib mir den nächsten Prompt.“ (2) einer **Commit-Nachricht** in einem eigenen Codeblock (eine Zeile, beginnt mit den Kennungen). Der Nutzer committet selbst (Regel 22). Der aktuelle Auftrag steht allein in [PROMPT.md](PROMPT.md). **Zum Schluss (Nutzer 16.10.) ersetzt der Umsetzer den ganzen Inhalt von PROMPT.md durch eine Kurzmeldung von höchstens drei Zeilen:** `Erledigt (Bereit zur Prüfung): <Kennungen>. Offen/blockiert: <Kennungen oder –>. HALT.` Sonst ändert er diese Datei nicht.

---

---

## A. Jetzt

**Stand 17.10.2026 (Host):** Version im Xcode-Projekt **0.3.8**. Abgenommen: 0.3, 0.3.1, 0.3.2, aus 0.4 Versions-Check/Update-Modal/Beta-Sperre/Nur-Lesen-Sperre, und für **0.3.8 die Pakete 4 und 5a** (DONE.md). Offen für 0.3.8: **Paket 5c** (freigegeben; 4, 5a, 5b abgenommen), danach `todo.0.3.8.001` (Version). Stick-Test, Großplatten-Lauf und Layout gesammelt als letzter Schritt von 0.4 (`todo.0.4.040`). Letzte Prüfung 17.10. 17:21–17:36: 0 Warnungen, seriell 712/712, parallel 3/3. Ein Worker zur Zeit, Pakete nacheinander. Bestandsaufnahme vom 16.10.: [archiv/bestandsaufnahme-2026-10-16.md](archiv/bestandsaufnahme-2026-10-16.md).

**Zwei Sprünge bis zur stabilen Version (Nutzer 16.10.):** **0.3.8** = Paket 4 (Medien-I/O, mit Nacharbeit) + Paket 5 (Entscheidung, Status, Regeln, Identität). **0.3.9** = Paket 6 (Oberfläche) + Paket 7 (Absturzschreiber, Start) + Paket 8 (Fehler niedriger Schwere), danach Stabilitätsprüfung. **0.4** enthält danach nur noch die Voraussetzungen der Weitergabe (Signatur, Notarisierung, Download-Seite, Versions-Check-Feinschliff, Beta-Verfallsdatum, macOS 14). **Eingefroren:** Neue Funde kommen nur dann in 0.3.8/0.3.9, wenn sie ein Abnahmekriterium verletzen, sonst nach B mit Zielversion 0.4 oder später. Kein neuer Auditlauf und keine neuen Pakete, bis 0.3.9 abgenommen ist.

**Abnahmekriterien je Sprung (alle müssen erfüllt sein):** (1) alle Kennungen des Sprungs vom Host abgenommen und in DONE.md; (2) Debug und Release inklusive Testziel 0 Warnungen; (3) serieller Gesamtlauf grün (Zahl der Tests genannt); (4) Parallellauf grün, dreimal hintereinander; (5) keine neuen `Disk Archive*.ips`; (6) Regel 23: der Host baut die App des Nutzers als letzten Schritt; (7) **entfällt je Sprung (Nutzer 17.10.):** der Test am echten Stick kommt gesammelt als letzter Schritt von 0.4 (`todo.0.4.040`: Großplatten-Lauf, Stick, Layout; danach an die Nutzer); (8) keine offene „Frage:“ in dieser Datei. Bei Abnahme eines Sprungs setzt der Umsetzer `MARKETING_VERSION` (`todo.0.3.8.001`, `todo.0.3.9.001`).

**Abnahme (Host, billiger):** je Aufgabe gezielte Tests, Code lesen, Build ohne Warnung; Gesamtlauf und Parallelläufe nur am Paketende; die Nutzer-App wird einmal je Paket gebaut. Ablauf: [archiv/abnahme-ablauf.md](archiv/abnahme-ablauf.md).

**Arbeitsregeln je Aufgabe (zusätzlich zu 1–30):** **R1** Nur die genannten Stellen ändern. **R2** Beweis = Pixel aus einem echten Fenster (`PixelProbe`); Sabotage → rot ✓. **R3** Status höchstens 5 Zeilen.

**Test- und Build-Kommandos:** Build `xcodebuild clean build-for-testing -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner>`; Warnungen zählen mit `| grep "warning:" | grep -v appintents | sort -u | wc -l` (Ziel 0). Tests `test-without-building … -only-testing:diskindexTests -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`. Danach den Ordner löschen.

### Reihenfolge der Pakete

| Paket | Zielversion | Kennungen | Thema | Stand |
|---|---|---|---|---|
| 0–3, 2a | 0.4 (vorab) | ~~`bug.0.4.010`–`020`, `043`, `044`, `todo.0.4.010`–`014`~~ | Testbasis, Datenschutz, Inventar, Live, Nur-Lesen | **abgenommen 15./16.10.** |
| 4 | **0.3.8** | ~~`bug.0.3.8.001`–`002`, `bug.0.4.045`, `021`–`025`~~ | Medien-I/O und Datenbank nicht auf dem Haupt-Thread | **abgenommen 16./17.10.** |
| 5a | **0.3.8** | ~~`bug.0.4.026`–`030`, `032`, `033`, `bug.0.3.8.003`~~ | Entscheidung, Status, Regeln, Identität, Teil 1 | **abgenommen 17.10.** |
| 5b | **0.3.8** | ~~`bug.0.3.8.004`, `005`, `bug.0.4.031`~~ | Testaufbau, tote Dateien, Identität | **abgenommen 17.10.** |
| 5c | **0.3.8** | ~~`bug.0.3.8.006`, `007`~~ | Zeitgrenze Medienprüfung, Parallellauf stabil | **abgenommen 17.10.; 0.3.8 fertig** |
| 6 | **0.3.9** | ~~`todo.0.3.8.001`, `bug.0.4.034`–`040`~~ | Version 0.3.8, Oberfläche | **abgenommen 17.10.** |
| 7 | **0.3.9** | ~~`bug.0.3.9.004`, `bug.0.4.041`–`042`~~ | Parallellauf unter Last, Absturzschreiber, Start | **abgenommen 17.10.** |
| 8a | **0.3.9** | `bug.0.3.9.001`–`003`, `005`–`010` | Befunde aus den Prüfungen | **freigegeben 17.10.** |
| 8b | **0.3.9** | `bug.0.4.050`–`062` | Fehler niedriger Schwere (Audit) | B |
| – | **0.4** | `todo.0.4.020`–`025` | Weitergabe an Beta-Tester | B |

Reihenfolge: 0.3.8 abgenommen; jetzt 0.3.9 mit den Paketen 6, 7, 8, danach 0.4. Neue sichtbare Texte nur über „Frage:“ oder als freigegebener Textvorschlag in der Aufgabe (Regel 3 bleibt).

#### Paket 4 und 5a — abgenommen (Hintergrund gilt weiter)

**Hintergrund (verbindlich):** Im Build ist `NonisolatedNonsendingByDefault` aktiv (`SWIFT_APPROACHABLE_CONCURRENCY`). Eine `nonisolated … async`-Funktion ohne `@concurrent` läuft daher **auf dem Actor des Aufrufers**, also auf main, wenn der Aufrufer `@MainActor` ist. „async“ heißt hier **nicht** „Hintergrund“.

**Prüfung Host 17.10. 00:00–00:15 (Commits `08a8a95` + `aa124c0`):** Debug mit Testziel **4 Warnungen** (nur Tests, siehe `bug.0.3.8.003`), Release 0, seriell **637/637** grün (23:59–00:05), **Parallel 3 von 3 grün** (00:05–00:12), keine neuen `.ips`, Regel 23 (App 00:14:16, Signatur gültig). **Paket 4 abgenommen** (`bug.0.3.8.002`, `bug.0.4.045`, `021`–`025`), siehe DONE.md; Volltexte im Archiv `archiv/todo-stand-2026-10-17-vor-abnahme-paket4.md`.

**Prüfung Host 17.10. 08:30–08:45 (Commit `58ec44e`):** Debug mit Testziel und Release 0 Warnungen, seriell **639/639** grün, Parallel **2 von 3** grün (Lauf 2 rot: `MainThreadMediumIOTests/directProbeKeepsMainActorResponsive`, Ticker 2 statt ≥ 8, Messaufbau, siehe `bug.0.3.8.004`), keine neuen `.ips`, Regel 23 erfüllt. **Paket 5a abgenommen** (`bug.0.4.026`–`030`, `032`, `033`, `bug.0.3.8.003`); die neuen Tests gehen über die echten Wege (Regel 18). Volltexte: `archiv/todo-stand-2026-10-17-vor-abnahme-paket5a.md`.

**Prüfung Host 17.10. 17:21–17:36 (Paket 7, ungecommittet auf `3d7f1a4`):** Debug mit Testziel und Release 0 Warnungen, seriell **712/712** grün, **Parallel 3 von 3 grün**, keine neuen `.ips`, Regel 23 (App 17:36:20, Signatur gültig). Code je Aufgabe von einem Prüf-Agenten gelesen: kein hoher Befund; zwei mittlere (`bug.0.3.9.008`, `009`) und niedrige (`010`) in Paket 8a. **Paket 7 abgenommen** (`bug.0.3.9.004`, `bug.0.4.041`, `042`). Paket 6 wurde nachträglich ebenfalls von Prüf-Agenten gelesen (Befunde `bug.0.3.9.005`–`007`). Volltexte: `archiv/todo-stand-2026-10-17-vor-abnahme-paket7.md`.

#### Paket 8a — Befunde aus den Prüfungen (0.3.9, freigegeben 17.10.)

Reihenfolge: `bug.0.3.9.008`, `009`, `010`, dann `001`, `002`, `003`, `005`, `006`, `007`. Die drei neuen kommen aus den Prüf-Agenten zu Paket 7.

**bug.0.3.9.008 — Wächter-Test: Laufzeitgrenze wieder eng (Prüf-Agent 17.10., mittel).** `IndexerWriteReproTests.hungStreamTriggersDirectoryReadStalled`: In `bug.0.3.9.004` von `< 4 s` auf `< retryPause / 2` (30 s) gelockert, obwohl `DirectoryReadStalled` nie wiederholt wird; die Grenze misst, dass der Wächter nach der Stillstandszeit rechtzeitig auslöst. Grenze aus `directoryStallTimeout` und dem Takt ableiten (Stillstand + 2 Takte + Reserve, etwa 8–10 s) und begründen. Sabotage: Wächter-Takt verzehnfachen → rot ✓. Dazu `BulkDirectoryReaderTests` Z. ~102 (`< 2 s` auf echtem Dateisystem) in `MeasurementTestGroup`.
Status:

**bug.0.3.9.009 — Beenden mit Zeitgrenze (Prüf-Agent 17.10., mittel).** `AppStartup` (`shouldTerminate`/`finishTermination`): Hängt `flushPendingWritesForTermination`, hängt das Beenden für immer; seit `bug.0.4.042` gilt das auch für SIGTERM (vorher sofort beendet, jetzt `SIG_IGN`). Zeitgrenze für den Abschluss (Standard 8 s, injizierbar); danach Protokollzeile „beenden zeitgrenze“ und `reply(toApplicationShouldTerminate: true)`. Merker gegen doppelten Abschluss (zweites SIGTERM oder ⌘Q während `.terminateLater`): Abbau und Abschluss genau einmal. Tests: hängender Abschluss → Antwort nach der Zeitgrenze (Notfall-Grenze großzügig); zweiter Aufruf → kein zweiter Abschluss (Zähler je Instanz).
Status:

**bug.0.3.9.010 — Absturzschreiber härten (Prüf-Agent 17.10., niedrig).** `DiskIndexLog.swift`: `lock.try()`/`unlock()` aus dem Signal-Handler entfernen (Z. ~334/336; nicht signalsicher, schützt nichts); `backtrace` einmal in `start` aufrufen (Initialisierung vorwegnehmen); `O_CLOEXEC` bei beiden `open` (Z. ~314/628); Nullbytes mitten im Ring beim Lesen überspringen (`crashSection`, gleichzeitiges `storeCrumb`). Den ungenutzten Parameter `crashAutoSend:` entfernen oder mit einem Test für Auto-Senden → `enqueue` → `consumeCrashMarker` belegen. Statuszeile von `041` („Ende-Bytes“) ist überholt, nichts tun.
Status:

**bug.0.3.9.001 — Weitere prozessweite Test-Schalter (Befund Worker 17.10.).** `SystemNotice.center`/`testPostHandler`, `DatabaseMaintenance.incrementalVacuumEnabled`, `LaunchAtLogin.setEnabledForTesting`, `ReportScrubber.pathPatternForTesting` als Parameter, Instanz oder `@TaskLocal` (Regel 20). Akzeptanz: Parallellauf 3× grün; `grep -rn "static var.*Testing\|ForTesting" diskindex/diskindex` im Status begründet.
Status:

**bug.0.3.9.002 — `VolumeLookup.info` ohne Zeitgrenze (Befund Worker 17.10.).** Serielle Queue: ein hängendes Volume hält alle weiteren Lookups auf (Erkennung, Aufwachen). Zeitgrenze wie `DirectMediumAccess.probe` (einmal fortsetzbare Continuation, injizierbar, Standard 5 s; Ergebnis `nil` = kein Kandidat, Protokollzeile). Test mit hängendem Lookup: zweiter Lookup kehrt zurück. Sabotage rot ✓.
Status:

**bug.0.3.9.003 — Live-Suche: Nachlauf nach Direktlauf nicht abgebrochen (Befund Worker 17.10.).** `runSearchAfterLiveChange` bricht den ausstehenden Nachlauf nicht ab, wenn eine Suche direkt ausgelöst wird; es läuft eine überflüssige zweite Suche. Abbrechen; Test: Live-Änderung, dann sofort Direktsuche → genau eine Suche (Zähler, nach kurzem Abwarten erneut geprüft).
Status:

**bug.0.3.9.005 — Nachprüfung Paket 6, Tests (Prüf-Agenten des Hosts 17.10., mittel).**
- a) Feste Laufzeitgrenzen im normalen Testlauf: `ColumnSelectionScaleTests` Z. ~73–85 (< 50 ms) und `FavoritesPagingTests` Z. ~136–147 (< 300 ms). Gleiche Fehlerklasse wie `bug.0.3.9.004`. Laufzeit nur noch protokollieren (Zahl im Testbericht) oder durch eine Zählung ersetzen (Zugriffe, gebaute Zeilen); die Aussage „ohne quadratischen Aufwand“ über ein Verhältnis prüfen (z. B. 50.000 vs. 5.000 Einträge, Faktor deutlich unter 100), nicht über Wanduhr-Millisekunden.
- b) `FavoritesPagingTests` (300-ms-Test und Tick-Test) rufen `reloadFavoritePage()` selbst auf und frieren mit `screenshotFrozenLists = true` das Laden der Ansicht ein (Regel 18). Über die echte Kette laden (`FavoritesView` im Fenster → `.task` → Laden), dann zählen.
- c) Rückfrage beim Ignorieren: Die App überspringt `AppWindowPresenter.openIgnoreConfirmation`, wenn `RuntimeEnvironment.isRunningTests` gilt (`AppState+Media.swift` Z. ~38–40); Panel, `IgnoreConfirmDialogWindowHost` und **Esc** (`onExitCommand`, gefordert) sind ungetestet. Öffnen des Panels injizierbar machen (Instanz statt Prozess-Schalter), Test: Panel außerhalb des Bildschirms, Esc per `sendEvent` → Abbrechen, nichts ignoriert. Gleiches für `openReplaceMediumPrompt` prüfen.
- d) `ColumnSelectionScaleTests.ignoreBatchAndMenuPlanUseSets` prüft `ContextMenuPlan` nicht; ergänzen oder umbenennen. `PopoverSearchDebounceTests`: eine veraltete **Seite** wird nicht verworfen geprüft; ergänzen. `ColumnCacheVisibleTests`: Nach-hinten-Setzen beim Lesen über `children()` und „alter Load endet nach neuem Load“ ergänzen.
Status:

**bug.0.3.9.006 — Favoriten: Zahl, Fehler, Aufräumen (Prüf-Agent des Hosts 17.10.).**
- a) **mittel:** `AppState+IndexChanges.swift` Z. ~293–306: Die Zählabfragen der Favoriten-Seite prüfen `favoriteEditGeneration` nicht. Wird während der Zählung abgewählt, überschreibt das alte Ergebnis die gesenkte Zahl; die Fußzeile bleibt um 1 falsch. Nach der Zählung die Generation prüfen und bei Änderung neu zählen. Test mit Tor in der Zählung.
- b) niedrig: Schlägt `setFavorites` fehl, bleibt der lokale Stand geändert (`AppState+Favorites.swift` Z. ~146–150). Lokalen Stand zurücknehmen, Protokollzeile. Test mit fehlschlagendem Store.
- c) niedrig: `favoriteChecksumTasks` wächst je Umschalten um zwei Tasks und wird nur beim Beenden geleert; fertige Tasks entfernen.
- d) niedrig: Beim Beenden wartet `prepareForTerminationAsync` nicht auf die Favoriten-Schreibkette (`favoriteWriteTail`); die letzten Umschaltungen können verloren gehen. Wie `bug.0.4.033`: vor dem Beenden auf die Kette warten (mit Zeitgrenze).
- e) niedrig: Auf einer vollen Seite (> 500 Favoriten) fehlt nach dem Abwählen eine Zeile, bis neu geladen wird. Den nächsten Favoriten nachladen oder die Seite neu laden.
Status:

**bug.0.3.9.007 — Kleinkram aus der Nachprüfung Paket 6 (niedrig).**
- a) `IgnoreConfirmDialog.swift` Z. ~41/65: 12 pt Abstand plus `padding(.top, 8)` = 20 pt zwischen Text und Knöpfen; Katalog „Dialog: Abstand 12“ (Regel 13). Gleiches in `ReplaceMediumDialog.swift` prüfen. Messtest anpassen.
- b) `AppWindowPresenter.closeAll` blendet das Ignorier-Panel nur aus; `ignoreConfirmationPrompt` (und `replaceMediumPrompt`) zurücksetzen.
- c) `IndexRepository`: Nach `invalidateAll` kann der alte Load bis zum nächsten Yield den Fortschritt wieder füllen (kurz veraltete Anzeige). Fortschritt nur mit passender Generation schreiben.
- d) Suche nach Medium sortiert innerhalb eines Mediums binär („datei 10“ vor „datei 2“); innerhalb der Seite wie bei Name natürlich nachsortieren.
- e) `PopoverSearch.complete` (`< 3`) startet bei genau 3 Dateien und 0 Ordnern eine unnötige Zählung; Bedingung korrigieren.
- *Bewusst so (Host 17.10.):* Ein Ordner genau auf der Scan-Tiefe darf offen bleiben (`clampPathToScanDepth` mit `<=`): die Statusspalte zeigt „Inhalt wird nicht indiziert“. Eigene Endungen in Favoriten-/Suchfiltern treffen exakt über `extID` (wie die Suche), mehrteilige Endungen wie „tar.gz“ nicht.
Status:

**HALT nach Paket 8a.**




---

### Nutzer und Host (ohne Worker)

| Kennung | Was | Wer |
|---|---|---|
| `todo.0.3.2.001` | Layout **02** (Erkennungs-Dialog mit Stapel/Warteschlange) und **04** (Dashboard-`card-meta`: Belegung links, „Zuletzt indiziert“ rechts, eine Zeile) in `layout/Disk Index App.dc.html` nachziehen. Blockiert keinen Code. | Nutzer |

### Entscheidungen des Nutzers (blockieren nur die genannte Stelle)

**Alle Entscheidungen getroffen (Nutzer 16.10. abends).** Umsetzung: `todo.0.4.032` in `bug.0.4.031` c), `todo.0.4.031` in `bug.0.4.035`, `todo.0.4.034`–`038` als `todo.0.4.026`–`029` (0.4, Abschnitt B). Die Fragen bleiben zur Nachverfolgung hier stehen.

| Kennung | Frage | betrifft |
|---|---|---|
| `todo.0.4.030` | **erledigt 16.10. (Nutzer):** Die API meldet wieder `0.3.0`; die Beta sperrt nicht mehr sofort. Keine Änderung an der App. | – |
| `todo.0.4.031` | **entschieden 16.10. (Nutzer): Rückfrage ab Schwelle.** Ab 500 Zielen auf einmal fragt die App vor dem Ignorieren nach; nichts wird verhindert. | `bug.0.4.035` |
| `todo.0.4.032` | **entschieden 16.10. (Nutzer): Hinweis anbieten.** Neues Medium mit gleichem Namen wie ein Offline-Medium → Rückfrage, ob es das alte ersetzt; nie automatisch vergessen. | `bug.0.4.031` c) |
| `todo.0.4.033` | **entschieden 16.10. (Nutzer): ja.** Einstellungen müssen vor dem ersten Lauf geladen sein; fest als Regel (README, Abschnitt „Datenbank“/Start). Gilt für `bug.0.4.028`. | – |
| `todo.0.4.034` | **entschieden 16.10. (Nutzer): README gilt.** Ohne Haken erscheint der Dialog beim nächsten Anschließen wieder, mit Haken nicht. | `todo.0.4.026` |
| `todo.0.4.035` | **entschieden 16.10. (Nutzer): ja.** Auch eine Pause, die bei beendeter App abgelaufen ist, meldet beim Start „Medien werden wieder indiziert.“ | `todo.0.4.027` |
| `todo.0.4.036` | **entschieden 16.10. (Nutzer): Kalenderzeit.** Beim Start und beim Aufwachen prüfen, ob seit dem letzten Check 24 h vergangen sind. | `todo.0.4.028` |
| `todo.0.4.037` | **entschieden 16.10. (Nutzer): jedes 201 gilt als Erfolg**, `id` ist optional. Keine Änderung am Server. | `todo.0.4.029` |
| `todo.0.4.038` | **entschieden 16.10. (Nutzer):** `ScreenshotRunner.swift` löschen (Umsetzung jetzt in `bug.0.3.8.005`); `PreviewData.swift` nur behalten, wenn Vorschauen oder Tests es nutzen, sonst auch löschen. | `todo.0.4.029` |
| `todo.0.4.039` | entschieden 15.10.: **Jeder Start zeigt alles**, auch der Anmeldestart (siehe `todo.0.4.013`). | – |

### Beobachten (keine Aufgabe)

| Kennung | Stand |
|---|---|

---

## B. Backlog (nicht freigegeben, der Worker arbeitet nicht daran), nach Zielversion


---

### 0.3.9 — Paket 8b (nach 8a), danach Stabilitätsprüfung

#### Paket 8b — Fehler niedriger Schwere aus dem Audit (nach 8a; Lösung im Archiv-Report, Nummer nennen)

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

**HALT nach Paket 8b = Ende von 0.3.9** — Abnahmekriterien 1–6 und 8, `todo.0.3.9.001` (`MARKETING_VERSION` auf `0.3.9`), Stabilitätsprüfung; erst dann 0.4.

---

### 0.4 — Beta für Beta-Tester (nach 0.3.9) (Voraussetzungen der Weitergabe, ROADMAP)

| Kennung | Inhalt |
|---|---|
| `todo.0.4.020` | **Signatur und Notarisierung:** Developer ID Application, `notarytool`, Stapeln (heute „Apple Development“). Merkhilfe eigene Kopie ohne Notarisierung: Xcode Archive → Distribute → Copy App; ggf. `xattr -dr com.apple.quarantine "…"`. |
| `todo.0.4.021` | **Download-Seite** auf `https://diskarchive.app/` mit stabilem Link (Nutzer). |
| `todo.0.4.022` | **Laufzeittest auf macOS 14** (z. B. VM); `pointerStyle` und `CGSize: Hashable` brauchen einen Ausweichweg. |
| `todo.0.4.023` | **Fehlerbericht mit echten Protokollzeilen** testen (erst nach `bug.0.4.011` und `bug.0.4.012`). |
| `todo.0.4.024` | **Update durch Ersetzen der App:** Bundle-ID und Datenordner gleich, Einzelinstanz-Übergabe bei neuerer Version, Launch-Agent neu registrieren; Schema-Erweiterungen mit Sicherung davor (nach `bug.0.4.013`). |
| `todo.0.4.040` | **Große Abnahmerunde = letzter Schritt vor den Nutzern (Nutzer 17.10.):** erst, wenn **alles andere von 0.4 abgenommen** ist; nicht vorziehen. Inhalt: (1) Lauf über die große Platte des Nutzers (rund 2 Mio. HTML-Dateien): vollständig indizieren, suchen, Spaltenansicht in großen Ordnern, ab- und anstecken, Live-Änderung; Zeiten (Release-Build) und Protokoll festhalten. (2) Test am echten Stick (großer Ordner, Pfeiltasten, Mehrfachauswahl, Rechtsklick, Medium ab- und anstecken, Live-Änderung, Rückfrage „Ersetzt dieses Medium?“ samt Texten, Umbenennen eines Volumes). (3) Layout-Durchgang aller Ansichten gegen `layout/` (einschließlich `todo.0.3.2.001`). Funde als `bug.0.4.xxx`; nach ihrer Behebung und Abnahme geht die App an die Nutzer. Ersetzt das Kriterium 7 der Sprünge 0.3.8 und 0.3.9. |
| `todo.0.4.025` | **Fenster „Datenbank wird aktualisiert“** (einmalig, mit Fortschritt) bei der ersten Schema-Erweiterung durch ein Update. |
| `todo.0.4.026` | **„Für dieses Medium merken“ auswerten** (`todo.0.4.034`): `rememberDecision` beim Anschließen lesen; ohne Haken erscheint der Erkennungs-Dialog beim nächsten Anschließen wieder (Vorbelegung = letzte Entscheidung), mit Haken nicht. Test für beide Fälle. |
| `todo.0.4.027` | **Pause beim Start abgelaufen** (`todo.0.4.035`): Mitteilung „Medien werden wieder indiziert.“ wie beim Ablauf im Betrieb (gleiche Schalter); danach Abgleich wie nach Pausenende. Test. |
| `todo.0.4.028` | **Versions-Check nach Kalenderzeit** (`todo.0.4.036`): Zeitpunkt des letzten Checks speichern; beim Start, beim Aufwachen und stündlich prüfen, ob 24 h vergangen sind. Test mit injizierbarer Uhr. |
| `bug.0.4.063` | **Nur-Lesen-Sperre stoppt laufende Arbeit nicht (Befund Host 17.10.):** `AppState.onVersionLockEngaged` wird in `VersionCheckCoordinator` aufgerufen, aber im Produkt nirgends gesetzt. Beim Einrasten der Sperre laufen Indexlauf, Regel-Abgleich und Überwachung weiter (README: gesperrt = 100 % nur ansehen, auch Überwachung aus). `IndexingService.cancelAllActiveForVersionLock` und `AppState.cancelRuleReconcileForVersionLock` rufen nur Tests auf (`VersionLockReadOnlyTests`, von Hand, Regel 18). In `LiveWiring` verdrahten (Läufe abbrechen, Abgleich abbrechen, Watcher stoppen); Test: Lauf aktiv → Auswertung mit Sperre → Lauf endet, keine Schreibvorgänge mehr, ohne die Abbruch-Funktionen von Hand aufzurufen. |
| `todo.0.4.029` | **Kleinkram Fehlerbericht und Altcode** (`todo.0.4.037`, `038`): jedes 201 gilt als Erfolg, `id` optional (Test: 201 ohne Körper → Zeile gelöscht, kein erneutes Senden); Screenshot-Werkzeug: nach `bug.0.3.8.005` verschoben (17.10.). |

### 0.5 bis 1.0 (Entwürfe, jede Funktion vor dem Start einzeln besprechen; Details ROADMAP)

| Kennung | Inhalt |
|---|---|
| `todo.0.5.001` | **Metadaten und EXIF** (Video, Foto/RAW, Audio, PDF; zweiter Durchgang nach dem Index, Markierung `_analyzed`), neue Layouts, **Wartescreen der Suche** |
| `todo.0.5.002` | **Natürliche Namensordnung über die Seitengrenze** (Vorschlag Worker 17.10., `bug.0.4.038`): Index `items_search_natural ON items(slug COLLATE "natural", status)` als eigene Migration (Regel 27). Heute bestimmt bei mehr als 500 Treffern die binäre Ordnung, welche 500 auf die Seite kommen; innerhalb der Seite wird natürlich sortiert. Kosten: größere Datenbank und Migration bei Nutzern (`todo.0.4.025`). Erst entscheiden, wenn es im Alltag stört. |
| `todo.0.6.001` | **Vorschaubilder** 250 px, Abschalter global und je Medium, Dateien `Thumbnails/<storageID>/<itemID>` |
| `todo.0.7.001` | **CSV-Export** (Umfang, Spalten, Kodierung offen) |
| `todo.0.8.001` | **Duplikate** über volle Prüfsumme, nach Größe gruppiert, nur im Hintergrund |
| `todo.0.9.001` | **Lizenz** (1 / 50 / 250 Medien als Lizenzgrenze; Fragen siehe README) |
| `todo.1.0.001` | Ladehinweis erst nach 1 s (früher T1; prüfen, ob durch `DelayedLoadingState` erledigt) |
| `todo.1.0.002` | Erweiterte Dateityp-Icons (früher T3, Styleguide 15) |
| `todo.1.0.003` | Ausführliches Protokoll / Diagnose-Modus (früher T5, Vorschlag Claude, nicht freigegeben) |

Entfallen: T2 „Programme als Dateityp“ (erledigt in 233: `.app`, `.dmg`, `.pkg`); Signatur/Notarisierung stand im alten Backlog bei 1.0, gilt laut README aber als Voraussetzung von 0.4 (`todo.0.4.020`).
