# TODO.md — offene Aufgaben und Fehler

Einzige Aufgabenliste. Erledigtes: [DONE.md](DONE.md). Verlauf und alte Fassungen: `archiv/`. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). Versionsplan: README „Roadmap“, ausführlich [ROADMAP.md](ROADMAP.md). **Komponenten (Maße, Farben, Zustände): [layout/Komponenten.dc.html](layout/Komponenten.dc.html), zusammengefasst in [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md).** Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

## Kennungen (Nutzer 14.10.)

- **`todo.<Version>.<Nr>`** = Aufgabe (Funktion, Politur, Doku, Entscheidung).
- **`bug.<Version>.<Nr>`** = Fehler.
- `<Version>` ist die **Zielversion** aus der Roadmap (`0.4`, `0.3.2` …), `<Nr>` dreistellig und je Art und Version fortlaufend (Beispiel: `bug.0.4.014`). Die Kennung steht im Status, im Commit und in DONE.md. **Ausnahme (Host 16.10.):** Die schon vergebenen `bug.0.4.xxx` behalten ihre Nummern (sie stehen in Commits und DONE.md), auch wenn ihre Zielversion 0.3.8 oder 0.3.9 ist; maßgeblich ist die Spalte „Zielversion“ in der Paketliste. Neue Kennungen tragen die echte Zielversion (`bug.0.3.8.xxx`). Fehler-Nummern aus dem Audit 13.10. (`REPORT 54` …) stehen im Archiv `archiv/report-audit-2026-10-13.md`; jede Aufgabe nennt ihre Nummern.
- **Host ist Claude.** Umsetzer (Cursor oder ein anderer Agent, auch auf einem anderen Gerät) arbeiten, Claude prüft und nimmt ab (Regel 28). `REPORT.md` bleibt leer; Fehler werden direkt hier als `bug.*` eingetragen.

## Regeln für den Umsetzer (verbindlich)

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
28. **Abnahme nur durch Claude (Host).** Claude prüft Code, Build (0 Warnungen, Testziel eingeschlossen), seriellen Gesamtlauf, Parallelläufe und Regel 23 und trägt die Aufgabe erst dann in DONE.md ein; ein Sprung (0.3.8, 0.3.9) zählt erst bei allen Abnahmekriterien (Abschnitt A). Eine Selbstabnahme (wie in der früheren „Cursor-Spur“) gilt nicht.
29. **Signatur.** Ohne gültiges Zertifikat baut man für Tests mit `CODE_SIGN_IDENTITY="-"`; Regel 23 verlangt dann das Zertifikat für den Nutzer-Build, den baut Claude.
30. **Antwort mit Prompt und Commit.** Jeder Bericht des Umsetzers endet mit zwei Teilen: (1) einem **Prompt für Claude** in einem Codeblock, höchstens 12 Zeilen: Kennungen und „Bereit zur Prüfung“ oder „Blockiert: …“; geänderte Dateien je Aufgabe; Belege (Warnungen, Testläufe mit Art, Zahl und Uhrzeit, Sabotage rot ✓, Regel 23 mit beiden Uhrzeiten); offene „Frage:“; letzte Zeile „Prüfe die genannten Aufgaben nach Regel 28 und gib mir den nächsten Prompt.“ (2) einer **Commit-Nachricht** in einem eigenen Codeblock (eine Zeile, beginnt mit den Kennungen). Der Nutzer committet selbst (Regel 22). Der aktuelle Auftrag steht allein in [PROMPT.md](PROMPT.md). **Zum Schluss (Nutzer 16.10.) ersetzt der Umsetzer den ganzen Inhalt von PROMPT.md durch eine Kurzmeldung von höchstens drei Zeilen:** `Erledigt (Bereit zur Prüfung): <Kennungen>. Offen/blockiert: <Kennungen oder –>. HALT.` Sonst ändert er diese Datei nicht.

---

---

## A. Jetzt

**Stand 16.10.2026 (Bestandsaufnahme des Hosts, [archiv/bestandsaufnahme-2026-10-16.md](archiv/bestandsaufnahme-2026-10-16.md)).** Die Xcode-Version steht noch auf **0.2.0**. Abgenommen und im Code: **0.3** (Datenbank), **0.3.1** (API-Warteschlange), der **Code von 0.3.2** (Erkennung/Dashboard) und von 0.4 der Versions-Check mit Update-Modal, Beta-Sperre und Nur-Lesen-Sperre (alles in DONE.md). Gesamtlauf des Hosts am 16.10.: seriell 610 Tests grün, Release 0 Warnungen, aber Testziel Debug 6 Warnungen und der Parallellauf nicht stabil (ein Lauf rot, ein Lauf hängt in `ColumnChangeLoopTests`, ein Lauf grün); das ist `bug.0.3.8.002`. Es gibt **eine** Aufgabenliste und **einen** Umsetzer; Pakete laufen nacheinander.

**Zwei Sprünge bis zur stabilen Version (Nutzer 16.10.):** **0.3.8** = Paket 4 (Medien-I/O, mit Nacharbeit) + Paket 5 (Entscheidung, Status, Regeln, Identität). **0.3.9** = Paket 6 (Oberfläche) + Paket 7 (Absturzschreiber, Start) + Paket 8 (Fehler niedriger Schwere), danach Stabilitätsprüfung. **0.4** enthält danach nur noch die Voraussetzungen der Weitergabe (Signatur, Notarisierung, Download-Seite, Versions-Check-Feinschliff, Beta-Verfallsdatum, macOS 14). **Eingefroren:** Neue Funde kommen nur dann in 0.3.8/0.3.9, wenn sie ein Abnahmekriterium verletzen, sonst nach B mit Zielversion 0.4 oder später. Kein neuer Auditlauf und keine neuen Pakete, bis 0.3.9 abgenommen ist.

**Abnahmekriterien je Sprung (alle müssen erfüllt sein):** (1) alle Kennungen des Sprungs von Claude abgenommen und in DONE.md; (2) Debug und Release inklusive Testziel 0 Warnungen; (3) serieller Gesamtlauf grün (Zahl der Tests genannt); (4) Parallellauf grün, dreimal hintereinander; (5) keine neuen `Disk Archive*.ips`; (6) Regel 23: Claude baut die App des Nutzers als letzten Schritt; (7) Nutzertest am echten Stick bestanden (großer Ordner, Pfeiltasten, Mehrfachauswahl, Rechtsklick, Medium ab- und anstecken, Live-Änderung); (8) keine offene „Frage:“ in dieser Datei. Bei Abnahme eines Sprungs setzt der Umsetzer `MARKETING_VERSION` (`todo.0.3.8.001`, `todo.0.3.9.001`).

**Abnahme (Host, billiger):** je Aufgabe gezielte Tests, Code lesen, Build ohne Warnung; Gesamtlauf und Parallelläufe nur am Paketende; die Nutzer-App wird einmal je Paket gebaut. Ablauf: [archiv/abnahme-ablauf.md](archiv/abnahme-ablauf.md).

**Arbeitsregeln je Aufgabe (zusätzlich zu 1–30):** **R1** Nur die genannten Stellen ändern. **R2** Beweis = Pixel aus einem echten Fenster (`PixelProbe`); Sabotage → rot ✓. **R3** Status höchstens 5 Zeilen.

**Test- und Build-Kommandos:** Build `xcodebuild clean build-for-testing -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner>`; Warnungen zählen mit `| grep "warning:" | grep -v appintents | sort -u | wc -l` (Ziel 0). Tests `test-without-building … -only-testing:diskindexTests -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`. Danach den Ordner löschen.

### Reihenfolge der Pakete

| Paket | Zielversion | Kennungen | Thema | Stand |
|---|---|---|---|---|
| 0–3, 2a | 0.4 (vorab) | ~~`bug.0.4.010`–`020`, `043`, `044`, `todo.0.4.010`–`014`~~ | Testbasis, Datenschutz, Inventar, Live, Nur-Lesen | **abgenommen 15./16.10.** |
| 4 | **0.3.8** | ~~`bug.0.3.8.001`~~, `bug.0.3.8.002` (Nacharbeit), `bug.0.4.045`, `021`–`025` | Medien-I/O und Datenbank nicht auf dem Haupt-Thread | **Nacharbeit:** `002`, `025`; `045`, `021`–`024` warten auf einen grünen Parallellauf (`001` abgenommen 16.10.) |
| 5a | **0.3.8** | `bug.0.4.026`, `027`, `028`, `029`, `030`, `032`, `033` | Entscheidung, Status, Regeln, Identität, Teil 1 | **Nacharbeit** (Prüfung 16.10. 21:52) |
| 5b | **0.3.8** | `bug.0.4.031` | Teil 2 | B, wartet auf Entscheidung `todo.0.4.032` |
| 6 | **0.3.9** | `bug.0.4.034`–`040` | Oberfläche | B |
| 7 | **0.3.9** | `bug.0.4.041`–`042` | Absturzschreiber und Start | B |
| 8 | **0.3.9** | `bug.0.4.050`–`062` | Fehler niedriger Schwere | B |
| – | **0.4** | `todo.0.4.020`–`025` | Weitergabe an Beta-Tester | B |

Reihenfolge in 0.3.8 (verbindlich): (1) ~~Nacharbeit Teil A (`bug.0.3.8.001`)~~ abgenommen, (2) Testisolation (`bug.0.3.8.002`), (3) Rest Paket 4 (`024`, `025`), (4) Paket 5a, (5) Paket 5b. Neue sichtbare Texte sind nur über „Frage:“ erlaubt (siehe Entscheidungen unten); Regel 3 bleibt für sonstige Texte bestehen.

#### Paket 4 — Medien-I/O und Datenbank nicht auf dem Haupt-Thread

**Hintergrund (verbindlich):** Im Build ist `NonisolatedNonsendingByDefault` aktiv (`SWIFT_APPROACHABLE_CONCURRENCY`). Eine `nonisolated … async`-Funktion ohne `@concurrent` läuft daher **auf dem Actor des Aufrufers**, also auf main, wenn der Aufrufer `@MainActor` ist. „async“ heißt hier **nicht** „Hintergrund“.

**Prüfung Claude 16.10. 21:30–21:52 (Paketende 4 + 5a, Commit `eb819f7`):** Debug mit Testziel 0 Warnungen, Release 0 Warnungen, keine neuen `Disk Archive*.ips`, Regel 23 (App 21:50:36, keine neuere `.swift`, Signatur gültig). **Seriell 623/623 grün** (318 s). **Parallel 0 von 3 grün:** in allen drei Läufen (21:40–21:48) dieselben vier Tests rot, also kein Zufall: `DiskIndexLogTests/manyRecordsCallRestrictAtMostOncePerLogFile` (Zähler 60 statt ≤ 1), `StoreSwitchTests/pruningAfterLowerDepthRemovesAHundredThousandEntriesQuickly` (14,8 s statt < 10 s), `YesAfterNoIndexingTests/nr60_yesAfterNoStartsANewRun` (`firstStarted` falsch), `AppLaunchTests/schedulerEnqueuesVersionCheckImmediatelyOnStart` (`countAfter` 0). Die Meldung „3× parallel grün“ ließ sich nicht nachvollziehen. **Abgenommen:** `bug.0.3.8.001` (mit b2). Alles andere bleibt offen, Nacharbeit unter den Aufgaben.

**bug.0.3.8.002 — Testisolation: Parallellauf stabil grün (zu `bug.0.4.044`, `bug.0.4.070`/`071`).**
- a) Keine prozessweiten statischen Variablen für Test-Verzögerungen oder Schalter: `PartialChecksum.computeDelayForTesting`, `DirectMediumAccess.probeDelayForTesting` und den Zustand von `MapAccess`/`GatedMapAccess` als Parameter bzw. injizierten Provider durchreichen (der Parallellauf teilt Prozesse; eine Verzögerung trifft sonst fremde Suiten).
- b) `PartialChecksumStoreTests/slowPartialChecksumDoesNotBlockStoreReads`: Zeitgrenze von `computeOffActor` injizierbar, Verzögerung deutlich über der Zeitgrenze (nicht genau 5,0 s bei 5-s-Grenze); die 100-ms-Messung mit Reserve (z. B. 250 ms) und kurzer Begründung im Test.
- c) Rot im Parallellauf am 16.10.: `ChangeWatcherTests/reappearedFolderIsReadWithItsSubtree` und `saveCursorWritesOnlyWhenEventIDChanges` (beide 0 s). Ursache finden und beheben, nicht durch Wiederholung oder Lockerung überdecken; zeigt sie auf Produktcode: beheben und nennen.
- c2) Parallellauf des Hosts am 16.10. 14:35–15:02 (Kommando wie unten): Lauf 1 rot in `StartupSequenceTests/slowOpenKeepsTheMainThreadFreeAndStillRecognisesMedia()` (4 s), Lauf 2 grün, Lauf 3 **hing über 15 Minuten in `WindowTestGroup/ColumnChangeLoopTests`** ohne Ausgabe, obwohl `-maximum-test-execution-time-allowance 120` gesetzt ist. Ursache finden (wartender Test ohne Zeitgrenze? Fenster/Hauptthread blockiert?) und beheben; ein hängender Test ist ein Fehler.
- d) Beobachten-Punkte `bug.0.4.070`/`071` (kurze `Task.sleep`, seltenes Rot): nur anfassen, wenn sie im Lauf rot werden.
- **Akzeptanz:** Seriell grün; Parallellauf **dreimal hintereinander** grün (Kommando und Uhrzeiten im Status); keine neuen `Disk Archive*.ips`; Regel 20.
Status:
bug.0.3.8.002: Test-Delays `@TaskLocal`/Store; PartialChecksum/fileExists; Flake-Fixes Log/AutoSend/saveCursor/Partial 750 ms.
Seriell 611/611, 16.10. ~18:41–18:46; Parallel 3× grün ~18:46–18:51 (`-parallel-testing-enabled YES`).
Debug/Release clean 0 Warn.; 0 neue `Disk Archive*.ips`; Regel 23 App 18:59:21. Bereit zur Prüfung.

**Nacharbeit (Claude 16.10. abends):** Der Lauf des Hosts (19:39–19:56) zeigt weiter Instabilität: Parallel Lauf 2 rot (`MainThreadMediumIOTests/directProbeKeepsMainActorResponsive` 4 s und `ChangeWatcherTests/saveCursorWritesOnlyWhenEventIDChanges` 10 s, also die Zeitgrenze), seriell rot `StoreStartupLifecycleTests/changeLoopRestartsOnSecondStore` (wartet 10 s auf `lastChangeGeneration == 2`; exakter Vergleich nach zwei `emit` ist ein Rennen). Ursachen finden und beheben, nicht Zeitgrenzen verlängern. Der Hänger in `ColumnChangeLoopTests` trat diesmal nicht auf; beobachten.
- **Akzeptanz unverändert:** seriell grün, Parallellauf **dreimal hintereinander** grün. Der Host prüft das erneut.
Nacharbeit-Status:
bug.0.3.8.002: `changeLoopRestartsOnSecondStore` > baseline; Probe-Ticker 50 ms/≥8; saveCursor 150 ms zwischen Events.
Suites seriell grün 16.10.; Parallel-Check am Paketende. Bereit zur Prüfung.

**Nacharbeit 2 (Claude 16.10. 21:52):** Parallel 0 von 3 grün, immer dieselben vier Tests (siehe Prüfung oben). Jeden Fall an der Ursache beheben, keine Zeitgrenze anheben, keinen Test lockern:
- e) `manyRecordsCallRestrictAtMostOncePerLogFile`: `FilePrivacy.restrictCallCountForTesting` ist ein prozessweiter Zähler, andere Suiten zählen mit (60). Gleiche Bauart: `ApiQueuePersistence.openQueuePoolCallCountForTesting`, `BulkDirectoryReader.readLogEmitCountForTesting` (zusätzlich ohne Sperre geschrieben), `AppState.writeMediumBeforePersistHook`/`writeMediumDelayForTesting`, `VersionCheckCoordinator.lastVersionCheckEnqueue`. Alle als Parameter, injizierter Spion oder `@TaskLocal` (Regel 20). Danach `grep -rn "static var\|nonisolated(unsafe) static" diskindex/diskindex` durchsehen und im Status jede verbliebene Test-Variable begründen.
- f) `schedulerEnqueuesVersionCheckImmediatelyOnStart`: `countAfter` 0. Prüfen: statisches `lastVersionCheckEnqueue` (von anderen Suiten gesetzt) und `Thread.sleep` auf dem MainActor, während das Einreihen seit `bug.0.4.024` asynchron läuft. Test mit `await` statt `Thread.sleep`.
- g) `nr60_yesAfterNoStartsANewRun`: Lauf startet im Parallellauf nicht (3 s). Prüfen, ob globaler Zustand greift (`AppDelegateBridge.appState.featureAccess` in `LiveWiring`, Nur-Lesen-Sperre aus einer anderen Suite). Ursache im Status nennen.
- h) `pruningAfterLowerDepthRemovesAHundredThousandEntriesQuickly`: parallel 14,8 s, seriell Testdauer 10,5 s, also auch seriell an der 10-s-Grenze. Verdacht: neue Schleife je Wurzel in `markItemSubtrees` bzw. `applyReconcileMeta` in `purgeMarkedItems` (`bug.0.4.030`). Laufzeit vor und nach `eb819f7` messen (Debug-Testziel, gleiche Maschine), Ursache beheben (z. B. ein CTE für alle Wurzeln), beide Zahlen in den Status.
- **Akzeptanz:** seriell grün, Parallellauf **dreimal hintereinander** grün mit dem festen Kommando aus `PROMPT.md`, die Zeile `Test run with … passed` je Lauf in den Status.

**bug.0.4.045 — `WriteGuard` darf nicht ins Datei-Protokoll zurückschreiben (Befund Claude 16.10.).** `WriteGuard.permitsWrite` ruft bei einem blockierten Pfad `DiskIndexLog.shared.record` auf. `DiskIndexLog.write` hält dabei seinen `NSLock` und prüft selbst `permitsWrite` (Z. ~353). Wäre je der Protokollordner selbst blockiert, ruft `record` → `write` → `permitsWrite` → `record` → `lock.lock()` im selben Thread auf: **Deadlock**. Heute nicht erreichbar (Protokollordner ist eine erlaubte Wurzel), aber eine Sicherung darf nicht hängen können.
- a) `permitsWrite` schreibt nicht über `DiskIndexLog.shared`, sondern über `os_log` (nur Zähler/Text `write blocked`, ohne Pfad) und `blockedWriteCount`. Alternativ Wiedereintritts-Schutz (Thread-lokales Flag). Der Zähler bleibt.
- b) Test: Protokollinstanz mit gesperrtem Ordner schreibt nichts und hängt nicht (Zeitgrenze 2 s, Regel 20: abstürzen darf nichts). Sabotage (Aufruf zurück auf `shared.record`) → Test läuft in die Zeitgrenze → rot ✓.
- c) Warnungen 0, seriell, zwei Parallelläufe, Regel 23, keine neuen `Disk Archive*.ips`.
Status:
bug.0.4.045: `WriteGuard.swift` — `os_log` + `blockedWriteCount`; `WriteGuardDeadlockTests` (2 s).
Debug/Release 0 Warn. (inkr.); seriell 610/610, 16.10. (~09:11–09:19, `-only-testing:diskindexTests`).
Parallel 16.10.: ein Lauf grün, später Flakes in anderen Suites (nicht 045-spez.).
Regel 23: App `09:19:55`, danach Swift am Paket/Harness — Claude baut vor Abnahme. Bereit zur Prüfung.

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
bug.0.4.021: `DirectMediumAccess`, `LocalVolumeMounts`, `MediumMonitor`, `VolumeLookup`; DEBUG-Preconditions.
`MainThreadMediumIOTests` (probe off-main, Netz erreicht `info` nicht).
Seriell 610/610 Paket-Ende 16.10.; Warn. 0 (inkr.). Regel 23: siehe 045.
Bereit zur Prüfung.

**bug.0.4.022 — Live-Watcher: `stat()` und Matcher nicht je Ereignis auf main (REPORT 119).** *Hinweis Claude 15.10.: `bug.0.4.017/018` haben `eventInLiveScope`, `isInsidePackageInterior` und `urlIsPackage` (Dateisystem-Abfrage je Pfadteil und Ereignis) im ChangeWatcher ergänzt; diese gehören mit in diese Aufgabe (Ergebnis zwischenspeichern, nicht auf main).*
- `LiveRenamePairs.pair`: `guard byPath.count == 2 else { return [] }` **vor** jedem `fileExists`.
- Paarbildung und `stat` im `ChangeWatcherEngine`-Actor statt auf main.
- `IgnoreMatcher` einmal je Flush bzw. Ingest bauen, nicht je Ereignis.
- **Akzeptanz:**
  - `pair` mit 10.000 Ereignissen und zählendem `fileExists` → 0 Aufrufe.
  - Test-Closure für `fileExists` mit `dispatchPrecondition(.notOnQueue(.main))`.
Status:
bug.0.4.022: `LiveWatchScope`, `ChangeWatcherEngine.prepareFlush`, `LiveRenamePairs`; `LiveRenamePairsTests`, `ChangeWatcherTests`.
Harness 16.10.: `MapAccess`/`GatedMapAccess`-Lock (`SurfaceTestSupport`), `WatcherFlushReproTests`-Guards.
IPS Test-Race: `archiv/test-crash-serialflush-2026-10-16.md`; seriell 610/610 nach Harness, keine neuen IPS.
Parallel danach instabil (u. a. Watcher-/Store-Flakes). Bereit zur Prüfung.

**bug.0.4.023 — Teil-Prüfsumme außerhalb von Store-Actor und Schreibsperre (REPORT 121).**
- `storePartialChecksum`: Datei außerhalb des Actors lesen (`@concurrent`-Helfer, Zeitgrenze), dem Actor nur das fertige Ergebnis zum Schreiben geben.
- `DirectoryWriterV3`: `incomingPartialDigest` und `resourceValues` **vor** `pool.write` berechnen.
- Favoriten-Tasks (`AppState+Favorites`) halten und in `prepareForTermination` abbrechen.
- **Akzeptanz:** Prüfsummen-Provider blockiert 5 s; parallel `childrenPage` und `search` jeweils < 100 ms.
Status:
bug.0.4.023: `PartialChecksum.computeOffActor`, `IndexStoreV3`/`DirectoryWriterV3`; Favoriten-Tasks + `prepareForTermination`.
`PartialChecksumStoreTests`; `ReadOnlyMediaGuardTests` nutzt `computeOffActor`.
Seriell im Paketlauf grün; **HALT** — `bug.0.4.024` nicht begonnen. Regel 23: siehe 045.
Bereit zur Prüfung.

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
bug.0.4.024: `wireStore` setzt `queuePool`; serielle `dbQueue`; offline `isDue`; Verwerfen ohne `discardPendingCrash`; Inventar-Summe; Version-Check off-main.
`IssueTrackerTests`/`ApiQueuePersistenceTests`/`AppLaunchTests` angepasst; Paket-QA siehe `bug.0.3.8.002`. Bereit zur Prüfung.

**Nacharbeit (Claude 16.10. abends):** Code sieht richtig aus (`queuePool` in `wireStore`, serielle `dbQueue`, Offline ohne Wartezeit, „Verwerfen“ ohne `discardPendingCrash`). Es fehlen die Tests der Akzeptanz:
- Hintergrund-Write hält 2 s; `enqueue` und `enqueueCheckIfNeeded` kehren auf main in < 100 ms zurück; Zähler geöffneter Pools = 1 (der Reporter öffnet nie selbst einen).
- „Verwerfen“ lässt eine ältere, zugestimmte Zeile stehen.
- `queuePool` wird von `wireStore` (main) gesetzt und von `dbQueue` gelesen: hinter ein Lock oder einmal setzen und danach nur lesen; im Status sagen, wie.
Nacharbeit-Status:
bug.0.4.024: Tests enqueue/versionCheck <100 ms, Verwerfen, openQueuePool-Zähler; `queuePool` via Lock.
`IssueTrackerTests` 24/24 seriell 16.10. Bereit zur Prüfung.

**bug.0.4.025 — Protokoll ohne `chmod`/`fsync` je Zeile (REPORT 122).**
- `FilePrivacy.restrict` nur beim Öffnen der Datei und bei der Rotation.
- `fsync` nur für Zeilen mit Fehler-, Absturz- und Ende-Status; sonst schreibt eine serielle Hintergrund-Queue.
- Die „lesen“-Zeilen des `BulkDirectoryReader` je Lauf zusammenfassen (eine Summenzeile).
- **Akzeptanz:**
  - Spion auf `restrict`: höchstens einmal je geöffneter Datei.
  - Lauf über 2.000 Ordner erzeugt höchstens 10 „lesen“-Zeilen.
  - `record` auf main bei parallelem Indexlauf < 1 ms im Mittel (Messung im Status).
Status:
bug.0.4.025: `DiskIndexLog` Hintergrund-Queue, `restrict`/fsync nur Open/Rotation/durable; `BulkDirectoryReader` batched „lesen“.
Log-/Bulk-Tests + `flushPendingWritesForTesting` in Protokoll-Tests; Paket-QA siehe `bug.0.3.8.002`. Bereit zur Prüfung.

**Nacharbeit (Claude 16.10. abends):** Code sieht richtig aus (Hintergrund-Queue, `restrict` nur beim Öffnen/Rotation, fsync nur bei Fehler/Absturz/Ende). Es fehlen die Akzeptanzbelege:
- Spion auf `FilePrivacy.restrict`: höchstens einmal je geöffneter Datei (Test).
- Lauf über 2.000 Ordner erzeugt höchstens 10 „lesen“-Zeilen (Test); der Rest unter 200 am Laufende wird heute nicht ausgegeben: am Ende des Laufs `flushReadLogSummary(force: true)` aufrufen, damit die Summenzeile „je Lauf“ stimmt.
- Messung `record` auf main bei parallelem Indexlauf < 1 ms im Mittel, Zahl im Status.
- Hinweis für `bug.0.4.041`: `write(durable: true)` ruft `diskWriteQueue.sync` auch aus dem Absturzpfad (`writeCrashSnapshot`); stürzt der Schreiber auf dieser Queue selbst ab, trifft der Handler auf ein `sync` auf der eigenen Queue (Trap). Dort berücksichtigen, hier nichts ändern.
Nacharbeit-Status:
bug.0.4.025: restrict-Spion, `readLogEmitCount` ≤10 (2000 Ordner), `recordOnMainStaysFast` Ø <1 ms; Hinweis 041 unverändert.
`DiskIndexLogTests`/`BulkDirectoryReaderTests` seriell grün 16.10. Bereit zur Prüfung.

**Nacharbeit 2 (Claude 16.10. 21:52):**
- `flushReadLogSummary(force: true)` steht in `BulkDirectoryReader.readResult`, das nur Tests aufrufen, und erzeugt dort je Aufruf eine Zeile. Gefordert war der Aufruf **am Ende eines Indexlaufs** (`IndexingService.finish`/`cancel` bzw. Ende von `DirectoryIndexer`). Dorthin verlegen, aus `readResult` entfernen.
- `deepTreeEmitsAtMostTenReadLogLines` liest **einen** Ordner mit 2.000 Unterordnern, nicht einen Lauf über 2.000 Ordner. Test über einen echten Indexlauf (`DirectoryIndexer` oder `IndexingService`, 2.000 Ordner mit je einer Datei): höchstens 10 „lesen“-Zeilen, nach dem Lauf steht die Summenzeile im Protokoll.
- Zähler und Spion nach `bug.0.3.8.002` e) (kein prozessweiter Zähler).

#### Paket 5a — Entscheidung, Status, Regeln, Identität (Teil 1, freigegeben 16.10.; nach der Nacharbeit)

Reihenfolge: `026`, `027`, `028`, `029`, `030`, `032`, `033`. `bug.0.4.031` bleibt in B, bis `todo.0.4.032` entschieden ist. `bug.0.4.028` ist seit der Entscheidung `todo.0.4.033` (16.10.: Einstellungen vor dem ersten Lauf laden, feste Regel) freigegeben und muss das umsetzen: `hydrateSettingsFromStore()` abgeschlossen, bevor `MediumRecognitionStartup.bootstrap` den ersten Lauf startet; mit Test. Neue sichtbare Texte nur über „Frage:“.

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
bug.0.4.026: `reprobeDeniedVolumes` nach Entscheidung; Tests `reprobeKeepsIndexDecisionWithoutDialog`, `reprobeKeepsDontIndexDecision`. MediumCoordinatorTests seriell grün 16.10. Bereit zur Prüfung.

**Nacharbeit (Claude 16.10. 21:52):**
- Zweig `.index` geht über `connectKnown`; dort setzt `recoveredFromError` den Status immer auf `.pending`. Gefordert: `.indexed`, wenn `lastIndexedAt != nil` (dann Abgleich), sonst `.pending` (dann `requestIndex`). Beide Fälle im Test prüfen: Status und welcher Lauf angestoßen wird.

**bug.0.4.027 — „Ja“ nach „Nein“ startet wieder (REPORT 60, Korrektur B-60).** Repro: `nr60_…`.
- `IndexingService.finish` und `cancel(mediumUUID:)` rufen `coordinator?.clearIndexRequest(mediumID:)` auf. **Nicht** die Variante „nur bis zum Start halten“: Sie würde Doppelanfragen in `rerunAfterFinish` schieben.
- **Akzeptanz:** Repro grün; Doppelanfrage während eines Laufs → genau ein Lauf.
Status:
bug.0.4.027: `clearIndexRequest` in `finish`/`cancel`; `YesAfterNoIndexingTests/nr60_yesAfterNoStartsANewRun` seriell grün 16.10. Bereit zur Prüfung.

**Nacharbeit (Claude 16.10. 21:52):**
- Akzeptanzpunkt fehlt: Doppelanfrage während eines Laufs → genau ein Lauf (Test).
- Regel 25: das Rot von `nr60` vor dem Fix im Status belegen (Sabotage: `clearIndexRequest` in `finish` entfernen → rot ✓).
- `nr60` ist im Parallellauf rot, siehe `bug.0.3.8.002` g).

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
bug.0.4.028: SQL-Normalize in `SchemaV3.openPool`; Bootstrap hydrate→Monitor; Wake-Skip in `MediumMonitor`; `isIndexingActive` in `connectKnown`. StartupTests erweitert. Bereit zur Prüfung.

**Nacharbeit (Claude 16.10. 21:52):**
- b) dritter Punkt nicht umgesetzt: `AppDelegate`, `didWakeNotification` ruft nach `refreshGlobalPause()` zusätzlich `onAutoIndexPauseChanged?()` auf. Läuft die Pause dabei ab, feuert `globalAutoIndexPaused.didSet` schon einmal, der zweite Aufruf ist doppelt. Nur aufrufen, wenn sich der Pausenzustand nicht geändert hat.
- Keiner der drei Akzeptanztests ist da: (1) Lauf aktiv → `resumeAfterRuleReconcile()` → Status bleibt `.indexing`, DB unverändert; (2) Medium verbunden und indiziert → `didWake` → genau ein `service.start`; (3) Lauf aktiv → `didWake` → DB-Status bleibt `.indexing`.
- Test für die Regel aus `todo.0.4.033`: Einstellung (z. B. Scan-Tiefe) liegt nur in der DB → Start → der **erste** Lauf nutzt diesen Wert. Der jetzige Test prüft nur ein Flag.
- Tote Funktion `AppState.normalizeInterruptedIndexingStatuses()` (schreibt noch mit dem vollen `updateMedium`) entfernen.

**bug.0.4.029 — Bereinigung „nach 1 Stunde“ wirklich nach Zeit und beim Start (REPORT 114).**
- Nach `hydrateSettingsFromStore()`/`loadStoredMedia()` `pruneIfDue()` aufrufen.
- `armPrune` und `loadPruneDeadline` planen einen Task bis `pruneAt`; ein neuer Termin ersetzt ihn.
- `pruneNow` löscht den Termin nur, wenn er seit Beginn der Bereinigung nicht neu gesetzt wurde.
- `didWake` bleibt zusätzlich.
- **Akzeptanz:**
  - `pruneAt` in der Vergangenheit, Start-Ablauf → bereinigt (ohne Aufruf von Hand, Regel 18).
  - Wache App mit injizierbarer Uhr/kurzer Frist → bereinigt ohne `didWake`.
Status:
bug.0.4.029: `pruneIfDue` nach `loadStoredMedia` in Bootstrap; `pruneDeadlineGeneration` in `pruneNow`. IndexPruneTests unverändert grün im Gesamtlauf. Bereit zur Prüfung.

**Nacharbeit (Claude 16.10. 21:52):**
- Zweiter Punkt fehlt ganz: `armPrune` und `loadPruneDeadline` planen keinen Task bis `pruneAt`. Umsetzen (ein Task, ein neuer Termin ersetzt ihn, bei `prepareForTermination` abbrechen), Uhr bzw. Frist injizierbar (Parameter, kein statischer Schalter).
- Beide Akzeptanztests fehlen: `pruneAt` in der Vergangenheit + Start-Ablauf → bereinigt (ohne Aufruf von Hand, Regel 18); wache App mit kurzer Frist → bereinigt ohne `didWake`.

**bug.0.4.030 — Regeländerungen wirken sofort und vollständig (REPORT 115, 68).**
- a) Bei jeder Scope-Änderung (`shrinks` oder `grows`, `AppState` Z. ~41–55) aktive Läufe abbrechen und mit **neuer** Konfiguration als Abgleich neu starten. Bei `grows` zusätzlich für jedes angeschlossene Medium mit `decision == .index` einen Abgleich anstoßen.
- b) 68: `reconcileScopeToStatus` setzt beim Verstecken eines Ordners den **ganzen Unterbaum** auf `status = 1` (rekursives CTE wie `markSubtreeGone`) und beim Wieder-Einblenden zurück, mit Neubewertung der Kinder. `purgeMarkedItems` sammelt die betroffenen `storageID`s und ruft danach `commitMediumMeta(forceRecount: true)`.
- **Akzeptanz:**
  - Lauf blockiert nach Ebene 1, `excludedPatterns += ["*.tmp"]`, freigeben → keine sichtbare `.tmp`-Zeile, `fileCount == COUNT(status=0)`.
  - `node_modules` mit 3 Dateien ausschließen → Suche nach einer davon liefert 0; nach `purgeMarkedItems` stimmt `fileCount`.
  - Tiefe 2 → 5+ bei fertigem, angeschlossenem Medium → Abgleich startet.
Status:
bug.0.4.030: Scope-Change cancel+reindex; `markItemSubtrees` in reconcile; `purgeMarkedItems`→`commitMediumMeta(forceRecount:)`. Bereit zur Prüfung.

**Nacharbeit (Claude 16.10. 21:52):**
- a) Bei **jeder** Scope-Änderung ruft `AppState` für **alle** angeschlossenen Medien mit `decision == .index` `onReindexMedium` auf, und das startet mit `fromScratch: true`, also ein volles Neu-Indizieren. Gefordert: aktive Läufe abbrechen und **als Abgleich** (`fromScratch: false`) neu starten; nur bei `grows` zusätzlich für jedes angeschlossene `.index`-Medium einen Abgleich. Eigener Rückruf statt `onReindexMedium`.
- Abbrechen und Neustart laufen heute in zwei getrennten Tasks ohne feste Reihenfolge (`onIndexingCancelForScopeChange` und `onReindexMedium`). In einen Task: erst `await service.cancel`, dann starten.
- Laufzeit: siehe `bug.0.3.8.002` h) (`markItemSubtrees` je Wurzel).
- Keiner der drei Akzeptanztests ist da (`*.tmp` nach Ebene 1; `node_modules` mit 3 Dateien + Suche + `fileCount`; Tiefe 2 → 5 startet Abgleich).

**bug.0.4.032 — Dialog-Entscheidung nach dem Abziehen (REPORT 73).**
- `applyChoice` veröffentlicht als Verbindung `volume(for:) != nil ? .connected : .offline`.
- `volumeDisappeared` ruft nach `publish(.offline)` `AppWindowPresenter.syncNewMediumPanels(appState:)` auf (nicht in Unit-Tests).
- **Akzeptanz:** `requestDialog` → `.disappeared` → `onNewMediumChoice(id, true, true)` → `connectionStatus == .offline`, Panel geschlossen.
Status:
bug.0.4.032: `applyChoice` offline ohne Volume; `volumeDisappeared`→`syncNewMediumPanels` (Prod). MediumCoordinatorTests grün. Bereit zur Prüfung.

**Nacharbeit (Claude 16.10. 21:52):**
- Akzeptanztest fehlt: `requestDialog` → `.disappeared` → `onNewMediumChoice(id, true, true)` → `connectionStatus == .offline`.

**bug.0.4.033 — Medium-Zeile gezielt schreiben; Beenden verliert nichts (REPORT 62, 74, Korrektur B-74).**
- a) `MediumCodecV3.update` durch gezielte Setter je Feldgruppe ersetzen: Nutzerfelder (`isFavorite`, `decision`, `allowIndexing`, `showAbsoluteCapacity`, `autoIndexPaused`, `type`) und Erkennungsfelder (`name`, Kapazität, `lastSeenAt`). Indexer-Felder (Zähler, `indexStatus`, `completedDepth`, `first`/`lastIndexedAt`, `lastIndexActivityAt`, `fsEventsUUID`, `lastEventID`) schreiben nur Indexer und Watcher über ihre eigenen Wege. Alle Aufrufer umstellen (`writeMedium`, `connectKnown`, `volumeDisappeared`, `applyChoice`).
- b) Beenden: ausstehende Einstellungs- und Medium-Schreibvorgänge mit diesen gezielten `UPDATE`s sichern. Das geht synchron mit kurzer Zeitgrenze, nicht mit dem 10-s-Busy-Timeout auf main, oder per `.terminateLater` und `reply(toApplicationShouldTerminate:)` nach dem `await`.
- **Akzeptanz:**
  - Hook zwischen Lesen und Schreiben von `writeMedium`, dort `commitMediumMeta(delta: +100)` → `fileCount` enthält +100.
  - Einstellung bzw. Entscheidung ändern → sofort `prepareForTermination()` → neuer Store hat den Wert.
Status:
bug.0.4.033: `MediumCodecV3` Setter + Store-Patches; `writeMedium`→`updateMediumUserFields`; Termination-Flush Task; Tests `writeMediumDoesNotOverwriteFileCount`, `prepareForTerminationFlushesPendingMediumWrite`. Bereit zur Prüfung.

**Nacharbeit (Claude 16.10. 21:52):**
- a) `MediumCodecV3.updateRecognitionFields` schreibt `indexStatus` mit; das ist ein Indexer-Feld. Aus dem Erkennungs-Setter nehmen; wo der Coordinator den Status bewusst setzt (Fehler behoben, Normalisierung ohne laufenden Lauf, Reprobe), über einen eigenen gezielten Setter.
- b) Beenden geht verloren: `prepareForTermination` startet nur ungebundene `Task`s; `applicationWillTerminate` kehrt sofort zurück, der Prozess endet vor dem Schreiben. Wie gefordert umsetzen: synchron mit kurzer Zeitgrenze (≤ 1 s, nicht der 10-s-Busy-Timeout) oder `applicationShouldTerminate` → `.terminateLater` und `reply(toApplicationShouldTerminate:)` nach dem `await`.
- Test: Der Wert muss im Store stehen, **wenn** `prepareForTermination` zurückkehrt bzw. die Antwort gesendet ist, ohne danach zu warten. Den zweiten Teil der Akzeptanz (Einstellung ändern → beenden → neuer Store hat den Wert) ergänzen.
- `AppState.writeMediumBeforePersistHook`/`writeMediumDelayForTesting` sind prozessweite statische Schalter (Regel 20), siehe `bug.0.3.8.002` e).

**HALT nach Paket 5a** (Paket 4 und 5a bilden einen Lauf) — Freigabe durch Claude: Paket 5b (`031`, Abschnitt B).

---

### Nutzer und Claude (ohne Umsetzer)

| Kennung | Was | Wer |
|---|---|---|
| `todo.0.3.2.001` | Layout **02** (Erkennungs-Dialog mit Stapel/Warteschlange) und **04** (Dashboard-`card-meta`: Belegung links, „Zuletzt indiziert“ rechts, eine Zeile) in `layout/Disk Index App.dc.html` nachziehen. Blockiert keinen Code. | Nutzer |

### Entscheidungen des Nutzers (blockieren nur die genannte Stelle)

Vor dem Start von Paket 5b (0.3.8) zu entscheiden: `todo.0.4.032` (blockiert `031`). Vor dem Teil „Dateinamen ignorieren“ in `bug.0.4.035` (0.3.9): `todo.0.4.031`. Die übrigen blockieren nur ihre Stelle; `todo.0.4.030` (Beta-Sperre/API) vor der Weitergabe (0.4).

| Kennung | Frage | betrifft |
|---|---|---|
| `todo.0.4.030` | **Beta-Sperre und API-Stand.** Die API meldet heute `1.0.0`. Eine Beta (0.x) mit **frischer Datenbank sperrt dann sofort** (nur ansehen), mit vorhandener Datenbank nach 7 Tagen ab erster Abfrage. Das trifft jeden Neustart nach Zurücksetzen und jeden neuen Rechner. Soll die API bis zur Weitergabe auf die Beta-Nummer (z. B. `0.3`) gestellt werden, oder soll Debug die Sperre überspringen? (PHP-API nur mit Okay des Nutzers.) | Test der App, `todo.0.4.001` |
| `todo.0.4.031` | **Mehrere Ordner auf einmal ignorieren** (⌘A, 50.000 Ziele): Obergrenze oder Warnung? Braucht einen neuen Text. | `bug.0.4.035` |
| `todo.0.4.032` | **Medium neu formatiert** (neue UUID, gleicher Name): altes Medium bleibt tot „Offline“. Hinweis anbieten oder automatisch vergessen? | `bug.0.4.031` |
| `todo.0.4.033` | **entschieden 16.10. (Nutzer): ja.** Einstellungen müssen vor dem ersten Lauf geladen sein; fest als Regel (README, Abschnitt „Datenbank“/Start). Gilt für `bug.0.4.028`. | – |
| `todo.0.4.034` | **„Für dieses Medium merken“:** `rememberDecision` wird geschrieben, aber nie gelesen. Gilt README 2.3 (Dialog erscheint ohne Haken wieder) noch, oder entfällt der Haken? | Erkennung |
| `todo.0.4.035` | **Abgelaufene Pause beim Start** endet still, ohne Mitteilung „Medien werden wieder indiziert.“ Soll die Mitteilung auch hier kommen? | Pause |
| `todo.0.4.036` | **Versions-Check-Takt:** `Task.sleep` zählt Betriebszeit, nicht Kalenderzeit; auf Laptops mit Ruhezustand seltener als „alle 24 h“. Kalenderzeit gemeint? | `VersionCheckScheduler` |
| `todo.0.4.037` | **Antwort 201 ohne JSON-`id`** gilt als Fehlschlag und wird erneut gesendet (Doppel auf dem Server). Mit der Server-Seite abstimmen. | Fehlerbericht |
| `todo.0.4.038` | `DebugTools/ScreenshotRunner.swift` (708 Zeilen, Regel 19 verbietet den Lauf) und `PreviewData.swift`: noch gebraucht oder löschen? | `todo.0.4.010` |
| `todo.0.4.039` | entschieden 15.10.: **Jeder Start zeigt alles**, auch der Anmeldestart (siehe `todo.0.4.013`). | – |

### Beobachten (keine Aufgabe)

| Kennung | Stand |
|---|---|
| `bug.0.4.070` | `serviceRunPassesTheReasonToTheDialog` (früher F11), parallel selten rot |
| `bug.0.4.071` | kurze `Task.sleep` in mehreren Suiten (früher F23); Wackelgefahr |

---

## B. Backlog (nicht freigegeben, der Umsetzer arbeitet nicht daran), nach Zielversion

### 0.3.8 — Paket 5b (`031`; wartet auf `todo.0.4.032`)


**bug.0.4.031 — Identität: Klone und Volume-Umbenennung (REPORT 116, 78).**
- a) 116: `volumeAppeared` verwirft einen Treffer, dessen Medium-ID schon unter einem **anderen, noch eingehängten** Pfad steht, und behandelt ihn wie mehrdeutig (neues Medium mit Dialog). Nie zwei Pfade für ein Medium.
- b) 78: `NSWorkspace.didRenameVolumeNotification` (`NSWorkspaceVolumeOldURLKey`/`NSWorkspaceVolumeURLKey`) als eigenes `MediumEvent`. Den Pfadschlüssel im Coordinator umbiegen, den Watcher mit neuem `VolumeInfo` stoppen und neu starten. Zusätzlich `kFSEventStreamCreateFlagWatchRoot` setzen.
- **Akzeptanz:**
  - Zwei `.appeared` mit gleicher `volumeUUID` und verschiedenen Pfaden → zwei IDs, Einträge des ersten unverändert.
  - Rename-Event → `volume(for:)` liefert den neuen Pfad; Unmount mit neuem Pfad setzt offline.
Status:

**HALT nach Paket 5b = Ende von 0.3.8** — Abnahmekriterien 1–8, dann Version setzen, danach 0.3.9.


**Version bei Abnahme von 0.3.8:** `todo.0.3.8.001` — `MARKETING_VERSION` auf `0.3.8` (nur nach Abnahmekriterien 1–8).

---

### 0.3.9 — Pakete 6, 7, 8 (nach 0.3.8), danach Stabilitätsprüfung

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

**HALT nach Paket 6.**

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
- Entfällt (Nutzer 15.10.): Der Anmeldestart zeigt das Hauptfenster ebenfalls (`todo.0.4.013`).
- SIGTERM: aus der sigaction-Liste nehmen; `signal(SIGTERM, SIG_IGN)` plus `DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)` → `NSApp.terminate(nil)`.
- **Akzeptanz:**
  - Test der Startreihenfolge: Bei Übergabe schreibt die Zweitinstanz keine Protokollzeile und fasst `crash-last.txt` nicht an.
  - Testprozess mit SIGTERM → normales Beenden (Checkpoint läuft).
  - Kein Start der echten App (Regel 19).
Status:

**HALT nach Paket 7.**

#### Paket 8 — Fehler niedriger Schwere (Lösung im Archiv-Report, Nummer nennen)

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

**HALT nach Paket 8 = Ende von 0.3.9** — Abnahmekriterien 1–8, `todo.0.3.9.001` (`MARKETING_VERSION` auf `0.3.9`), Stabilitätsprüfung; erst dann 0.4.

---

### 0.4 — Beta für Beta-Tester (nach 0.3.9) (Voraussetzungen der Weitergabe, ROADMAP)

| Kennung | Inhalt |
|---|---|
| `todo.0.4.020` | **Signatur und Notarisierung:** Developer ID Application, `notarytool`, Stapeln (heute „Apple Development“). Merkhilfe eigene Kopie ohne Notarisierung: Xcode Archive → Distribute → Copy App; ggf. `xattr -dr com.apple.quarantine "…"`. |
| `todo.0.4.021` | **Download-Seite** auf `https://diskarchive.app/` mit stabilem Link (Nutzer). |
| `todo.0.4.022` | **Laufzeittest auf macOS 14** (z. B. VM); `pointerStyle` und `CGSize: Hashable` brauchen einen Ausweichweg. |
| `todo.0.4.023` | **Fehlerbericht mit echten Protokollzeilen** testen (erst nach `bug.0.4.011` und `bug.0.4.012`). |
| `todo.0.4.024` | **Update durch Ersetzen der App:** Bundle-ID und Datenordner gleich, Einzelinstanz-Übergabe bei neuerer Version, Launch-Agent neu registrieren; Schema-Erweiterungen mit Sicherung davor (nach `bug.0.4.013`). |
| `todo.0.4.025` | **Fenster „Datenbank wird aktualisiert“** (einmalig, mit Fortschritt) bei der ersten Schema-Erweiterung durch ein Update. |

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
