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

**Stand 17.10.2026 (Host):** Version im Xcode-Projekt **0.3.2**. Abgenommen: 0.3, 0.3.1, 0.3.2, aus 0.4 Versions-Check/Update-Modal/Beta-Sperre/Nur-Lesen-Sperre, und für **0.3.8 die Pakete 4 und 5a** (DONE.md). Offen für 0.3.8: **Paket 5b** (freigegeben), danach Stick-Test des Nutzers und `todo.0.3.8.001` (Version). Letzte Prüfung 17.10. 08:30–08:45: 0 Warnungen, seriell 639/639, parallel 2/3 (Testaufbau, `bug.0.3.8.004`). Ein Worker zur Zeit, Pakete nacheinander. Bestandsaufnahme vom 16.10.: [archiv/bestandsaufnahme-2026-10-16.md](archiv/bestandsaufnahme-2026-10-16.md).

**Zwei Sprünge bis zur stabilen Version (Nutzer 16.10.):** **0.3.8** = Paket 4 (Medien-I/O, mit Nacharbeit) + Paket 5 (Entscheidung, Status, Regeln, Identität). **0.3.9** = Paket 6 (Oberfläche) + Paket 7 (Absturzschreiber, Start) + Paket 8 (Fehler niedriger Schwere), danach Stabilitätsprüfung. **0.4** enthält danach nur noch die Voraussetzungen der Weitergabe (Signatur, Notarisierung, Download-Seite, Versions-Check-Feinschliff, Beta-Verfallsdatum, macOS 14). **Eingefroren:** Neue Funde kommen nur dann in 0.3.8/0.3.9, wenn sie ein Abnahmekriterium verletzen, sonst nach B mit Zielversion 0.4 oder später. Kein neuer Auditlauf und keine neuen Pakete, bis 0.3.9 abgenommen ist.

**Abnahmekriterien je Sprung (alle müssen erfüllt sein):** (1) alle Kennungen des Sprungs vom Host abgenommen und in DONE.md; (2) Debug und Release inklusive Testziel 0 Warnungen; (3) serieller Gesamtlauf grün (Zahl der Tests genannt); (4) Parallellauf grün, dreimal hintereinander; (5) keine neuen `Disk Archive*.ips`; (6) Regel 23: Claude baut die App des Nutzers als letzten Schritt; (7) Nutzertest am echten Stick bestanden (großer Ordner, Pfeiltasten, Mehrfachauswahl, Rechtsklick, Medium ab- und anstecken, Live-Änderung); (8) keine offene „Frage:“ in dieser Datei. Bei Abnahme eines Sprungs setzt der Umsetzer `MARKETING_VERSION` (`todo.0.3.8.001`, `todo.0.3.9.001`).

**Abnahme (Host, billiger):** je Aufgabe gezielte Tests, Code lesen, Build ohne Warnung; Gesamtlauf und Parallelläufe nur am Paketende; die Nutzer-App wird einmal je Paket gebaut. Ablauf: [archiv/abnahme-ablauf.md](archiv/abnahme-ablauf.md).

**Arbeitsregeln je Aufgabe (zusätzlich zu 1–30):** **R1** Nur die genannten Stellen ändern. **R2** Beweis = Pixel aus einem echten Fenster (`PixelProbe`); Sabotage → rot ✓. **R3** Status höchstens 5 Zeilen.

**Test- und Build-Kommandos:** Build `xcodebuild clean build-for-testing -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner>`; Warnungen zählen mit `| grep "warning:" | grep -v appintents | sort -u | wc -l` (Ziel 0). Tests `test-without-building … -only-testing:diskindexTests -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`. Danach den Ordner löschen.

### Reihenfolge der Pakete

| Paket | Zielversion | Kennungen | Thema | Stand |
|---|---|---|---|---|
| 0–3, 2a | 0.4 (vorab) | ~~`bug.0.4.010`–`020`, `043`, `044`, `todo.0.4.010`–`014`~~ | Testbasis, Datenschutz, Inventar, Live, Nur-Lesen | **abgenommen 15./16.10.** |
| 4 | **0.3.8** | ~~`bug.0.3.8.001`–`002`, `bug.0.4.045`, `021`–`025`~~ | Medien-I/O und Datenbank nicht auf dem Haupt-Thread | **abgenommen 16./17.10.** |
| 5a | **0.3.8** | ~~`bug.0.4.026`–`030`, `032`, `033`, `bug.0.3.8.003`~~ | Entscheidung, Status, Regeln, Identität, Teil 1 | **abgenommen 17.10.** |
| 5b | **0.3.8** | `bug.0.3.8.004`, `005`, `bug.0.4.031` | Testaufbau, tote Dateien, Identität | **Nacharbeit** (Prüfung 17.10. 10:15) |
| 6 | **0.3.9** | `bug.0.4.034`–`040` | Oberfläche | B |
| 7 | **0.3.9** | `bug.0.4.041`–`042` | Absturzschreiber und Start | B |
| 8 | **0.3.9** | `bug.0.4.050`–`062` | Fehler niedriger Schwere | B |
| – | **0.4** | `todo.0.4.020`–`025` | Weitergabe an Beta-Tester | B |

Reihenfolge in 0.3.8 (verbindlich): Pakete 4 und 5a abgenommen; jetzt Paket 5b, dann Stick-Test des Nutzers (Abnahmekriterium 7), dann `todo.0.3.8.001`. Neue sichtbare Texte nur über „Frage:“ oder als freigegebener Textvorschlag in der Aufgabe (Regel 3 bleibt).

#### Paket 4 und 5a — abgenommen (Hintergrund gilt weiter)

**Hintergrund (verbindlich):** Im Build ist `NonisolatedNonsendingByDefault` aktiv (`SWIFT_APPROACHABLE_CONCURRENCY`). Eine `nonisolated … async`-Funktion ohne `@concurrent` läuft daher **auf dem Actor des Aufrufers**, also auf main, wenn der Aufrufer `@MainActor` ist. „async“ heißt hier **nicht** „Hintergrund“.

**Prüfung Host 17.10. 00:00–00:15 (Commits `08a8a95` + `aa124c0`):** Debug mit Testziel **4 Warnungen** (nur Tests, siehe `bug.0.3.8.003`), Release 0, seriell **637/637** grün (23:59–00:05), **Parallel 3 von 3 grün** (00:05–00:12), keine neuen `.ips`, Regel 23 (App 00:14:16, Signatur gültig). **Paket 4 abgenommen** (`bug.0.3.8.002`, `bug.0.4.045`, `021`–`025`), siehe DONE.md; Volltexte im Archiv `archiv/todo-stand-2026-10-17-vor-abnahme-paket4.md`.

**Prüfung Host 17.10. 08:30–08:45 (Commit `58ec44e`):** Debug mit Testziel und Release 0 Warnungen, seriell **639/639** grün, Parallel **2 von 3** grün (Lauf 2 rot: `MainThreadMediumIOTests/directProbeKeepsMainActorResponsive`, Ticker 2 statt ≥ 8, Messaufbau, siehe `bug.0.3.8.004`), keine neuen `.ips`, Regel 23 erfüllt. **Paket 5a abgenommen** (`bug.0.4.026`–`030`, `032`, `033`, `bug.0.3.8.003`); die neuen Tests gehen über die echten Wege (Regel 18). Volltexte: `archiv/todo-stand-2026-10-17-vor-abnahme-paket5a.md`.

**Prüfung Host 17.10. 09:59–10:15 (Commit `91b90a6`):** Debug mit Testziel und Release 0 Warnungen, seriell **642/642** grün, Parallel **2 von 3** (Lauf 2 rot: `StartupSequenceTests/slowOpen…`, siehe `bug.0.3.8.004`), keine neuen `.ips`, Regel 23 erfüllt. Code von `005` und `031` richtig; Nacharbeit: Testaufbau ohne Zeitvergleich (`004`), Screenshot-Reste (`005`), Klon „zuletzt gesehen“ und `rootChanged` beim Abziehen (`031`).

#### Paket 5b — Abschluss 0.3.8 (freigegeben 17.10.; Nacharbeit)

Reihenfolge: `bug.0.3.8.004`, `bug.0.3.8.005`, `bug.0.4.031`. Für `031` c) gelten die Textvorschläge in der Aufgabe als freigegeben; im Status unter „Neue Texte:“ auflisten, der Nutzer prüft sie beim Stick-Test.

**bug.0.3.8.004 — `directProbeKeepsMainActorResponsive` wackelt im Parallellauf (Host 17.10.).**
- Der Test zählt Ticks auf dem MainActor während einer 2-s-Prüfung und erwartet ≥ 8. Im Parallellauf teilen sich mehrere Suiten im selben Prozess den MainActor; unter Last kamen nur 2 Ticks an (Lauf 08:38, auch bei Cursor 16.10. 23:53). Das misst die Last, nicht den Fehler.
- Umbauen, sodass der Test genau das prüft, was `bug.0.4.021` verlangt: Die Prüfung läuft **nicht** auf main (Prüf-Closure mit `Thread.isMainThread == false` bzw. `dispatchPrecondition`, Ergebnis zurückmelden) und blockiert main nicht (ein einzelner MainActor-Sprung während der laufenden Prüfung kommt an, Zeitgrenze mit Reserve, z. B. < 1 s). Keine Tick-Zählung, keine Lockerung der Erwartung an den Produktcode.
- Sabotage: `probe` synchron auf main ausführen → Test rot ✓ (im Status).
- Gleiche Bauart in anderen Tests suchen (`grep -rn "ticker\|ticks" diskindexTests`) und nur dort umbauen, wo sie im Parallellauf rot werden können; im Status nennen.
Status:
bug.0.3.8.004: `directProbeKeepsMainActorResponsive` ohne Ticks: neuer DEBUG-`@TaskLocal` `DirectMediumAccess.probeThreadObserverForTesting` meldet Beginn und Thread; Test erwartet „nicht main“ und einen MainActor-Sprung vor dem Ende der 2-s-Pause (Reihenfolge statt fester Grenze); Strom endet mit der Prüfung (rot statt Hängen). `MainActorTickCounter` entfernt.
Gleiche Bauart: `StartupSequenceTests.slowOpenKeepsTheMainThreadFreeAndStillRecognisesMedia` (`ticks >= 3`) ebenso umgebaut. `AllowIndexingStabilityTests` nennt „ticks“ nur im Kommentar. Bestehend, nicht geändert: `dispatchPrecondition` in `probe` beendet bei echtem Rückfall den Prozess statt „rot“.
Sabotage rot ✓ 09:03:31 (Prüfung per `DispatchQueue.main.sync`, Öffnen ohne `Task.detached` → je „onMain true“ und Sprung nach Pausenende), zurückgenommen. Suites seriell grün 09:03:02. Bereit zur Prüfung.
Paketende 5b: clean build-for-testing Debug 0 / Release 0 Warnungen (09:14–09:16); seriell 642/642 grün (09:16:03–09:21:28); parallel 3× grün, je 680 Testfälle, 0 rot (09:21:28–23:54, –26:21, –28:57); keine neuen `.ips`; Regel 23: App 09:29:15, letzte `.swift` 09:13:37, `find -newer` leer, Signatur gültig. `MARKETING_VERSION` unverändert.

**Nacharbeit (Host 17.10. 10:15):**
- Parallellauf des Hosts 10:04–10:12: **2 von 3** grün. Lauf 2 rot: `StartupSequenceTests/slowOpenKeepsTheMainThreadFreeAndStillRecognisesMedia` (Z. ~64: der MainActor-Sprung kam erst nach 3 s, erwartet < 2 s). Die neue Fassung misst weiter eine Zeit, die unter Parallellast schwankt.
- Beide Tests (`directProbeKeepsMainActorResponsive` und `slowOpen…`) **ohne Zeitvergleich** bauen: Die Prüfung bzw. das Öffnen meldet den Beginn (Thread) und wartet dann auf ein **Tor, das der Test erst nach einem gelungenen MainActor-Sprung öffnet** (`await MainActor.run {}` bzw. `Task { @MainActor in }`, danach Tor auf). Läuft die Arbeit fälschlich auf main, kommt der Sprung nie an: Das Tor hat eine großzügige Notfall-Zeitgrenze (z. B. 10 s), danach meldet es „Zeitgrenze“, der Test ist rot. Im grünen Fall gibt es keine Uhrzeit-Erwartung mehr.
- Sabotage wie gehabt (Arbeit auf main) → rot ✓. Akzeptanz: Parallellauf dreimal hintereinander grün.

Nacharbeit-Status:
bug.0.3.8.004: Beide Tests ohne Zeitvergleich: neues Tor `MainHopGate` (`MainThreadMediumIOTests.swift`); Prüfung bzw. `open` meldet den Thread und wartet am Tor, der Test öffnet es erst nach `await Task { @MainActor in }.value`; Notfall-Zeitgrenze 10 s setzt nur „Zeitgrenze“ → rot. Strom endet mit der Arbeit (rot statt Hängen).
`probeDelayForTesting` (2-s-Pause) entfällt, der Beobachter-Hook darf jetzt warten (`MediumAccess.swift`); `StartupSequenceTests.slowOpen…` ohne `Thread.sleep`.
Sabotage rot ✓ 12:29:53 (Prüfung per `DispatchQueue.main.sync`, Öffnen ohne `Task.detached` → je „onMain true“ und „Zeitgrenze“ nach 10 s), zurückgenommen. Suites seriell grün 12:29:10 und 12:30:32. Bereit zur Prüfung.
Paketende (Nacharbeit 5b): clean build-for-testing Debug 0 / Release 0 Warnungen (12:31–12:33); seriell 643/643 grün (12:33:26–12:38:46); parallel 3× grün, je 681 Testfälle, 0 rot (12:38:46–41:11, –43:38, –46:14); keine neuen `.ips`; Regel 23: App 12:46:36, letzte `.swift` 12:31:09, `find -newer` leer, Signatur gültig.
Befund (Review, nicht geändert): `DirectMediumAccess.probe` – die 5-s-Zeitgrenze greift nie (Zeitgrenzen-Kind liefert `nil`, `for await` wartet weiter auf die Prüfung); ein hängendes Volume hängt also die Prüfung. Und `dispatchPrecondition` beendet bei echtem Rückfall auf main den Prozess statt „rot“.

**bug.0.3.8.005 — Tote Dateien entfernen (Host 17.10., Nutzer: „damit auch diese mal weg kommen“).**
- a) `diskindex/DebugTools/ScreenshotRunner.swift` und `ScreenshotPlan.swift` löschen (Regel 19 verbietet den Lauf; Entscheidung `todo.0.4.038`). Dazu den Aufruf in `AppDelegate` (Z. ~74–75, `ScreenshotPlan.folder`/`ScreenshotRunner.run`) und den Hinweis in `SystemNotice` (Z. ~323) entfernen bzw. anpassen. `DebugTools/PreviewData.swift` **bleibt** (genutzt von `DashboardView`, `MediumDashboardCard` und neun Test-Suiten).
- b) UI-Testziel `diskindexUITests` entfernen: nur die Xcode-Vorlage (`testExample`, `testLaunchPerformance`) und startet die echte App, was Regel 8/19 verbieten. Ordner, Ziel in `project.pbxproj` und Eintrag im Schema entfernen; danach `xcodebuild -list` und Build mit Testziel prüfen.
- b2) Werkzeug-Reste mit Code-Bezug (Nutzer 17.10.: „verschlanken“; die übrigen Werkzeuge hat der Host schon gelöscht, die Messberichte liegen jetzt in `archiv/messung`):
  - Icon: `Werkzeuge/icon-kandidat/`, `Werkzeuge/icon-pruefen` und `icon-pruefen.swift`, `diskindexTests/IconCandidateTests.swift`, `diskindex/Scripts/GenerateAppIcons.swift` löschen. Das fertige Icon liegt im Asset-Katalog und bleibt unberührt.
  - Bildschirmfotos aus Tests (Regel 19): `ToolbarFillTests.comparisonSheets` (schreibt PNGs nach `Werkzeuge/screenshots`) entfernen; in `ColumnLiveRenameTests` den Aufruf `saveScreenshot` und die Funktion entfernen, die Prüfung selbst bleibt. Danach darf kein Test mehr in den Projektordner schreiben (`grep -rn "Projekte/Disk Index" diskindexTests` leer).
  - Messwerkzeug: `diskindexTests/IndexBenchTests.swift`, `Werkzeuge/db-messung.sh`, `Werkzeuge/db-messung-nachher.sh` löschen; Kommentar in `SchemaV3.swift` (Z. ~6) auf `archiv/messung/*-nachher-bericht.md` ändern.
  - Bleiben: `Werkzeuge/audit-repro` (Regel 25, bis 0.3.9 abgenommen ist), `Werkzeuge/generate_localizable.py` (Lokalisierung), `Werkzeuge/stress_fill_stick.sh` (Stick-Test des Nutzers).
- c) Vorher für jede Datei `grep -rn` über `diskindex/`, `diskindexTests/` und `project.pbxproj`; taucht ein weiterer Bezug auf, stehen lassen und „Frage:“ schreiben.
- **Akzeptanz:** 0 Warnungen (Debug mit Testziel, Release), seriell grün, `xcodebuild -list` ohne `diskindexUITests`, Status listet jede entfernte Datei.
Status:
bug.0.3.8.005: Entfernt (in den Papierkorb): `DebugTools/ScreenshotRunner.swift` + Aufruf in `AppDelegate`; `diskindexUITests/` + Ziel in `project.pbxproj` (Schema hatte keinen Eintrag); `Werkzeuge/icon-kandidat/`, `icon-pruefen`, `icon-pruefen.swift`, `IconCandidateTests.swift`, `Scripts/GenerateAppIcons.swift` (leerer Ordner `Scripts` weg); `IndexBenchTests.swift`, `db-messung.sh`, `db-messung-nachher.sh`.
In Tests entfernt: `ToolbarFillTests.comparisonSheets` + `IconFillComparison`; `ColumnLiveRenameTests.saveScreenshot` samt Zeichenschleife davor. `SchemaV3`-Kommentar → `archiv/messung/*-nachher-bericht.md`. `grep "Projekte/Disk Index" diskindexTests` leer; `xcodebuild -list`: nur `diskindex`, `diskindexTests`.
Frage: `ScreenshotPlan.swift` hat weitere Bezüge (`RestCoverageTests.databaseHealthAndScreenshotArgument` Z. 95–96, `LayoutCopyTests` Z. 27–29 und `aFlatImageCountsAsEmptyAndAMarkedOneDoesNot` Z. 56–61), daher nach c) stehen gelassen, ebenso der Hinweis in `SystemNotice` (`--screenshots` prüft `RestCoverageTests` Z. 99). Ohne Aufrufer, nicht in der Liste: `ScreenshotContextMenu` (`ObjectFileContextMenu.swift` Z. 489). Mitlöschen samt dieser Testteile?
Suites seriell grün 09:03:02 (25 Tests). Bereit zur Prüfung bis auf die Frage.

**Nacharbeit (Host 17.10. 10:15):**
- Antwort auf die Frage: **ja, mitlöschen.** `DebugTools/ScreenshotPlan.swift`, die Testteile, die nur das Screenshot-Werkzeug prüfen (`RestCoverageTests.databaseHealthAndScreenshotArgument` Z. ~95–99 nur der Screenshot-Teil, `LayoutCopyTests` Z. ~27–29 und `aFlatImageCountsAsEmptyAndAMarkedOneDoesNot`, falls sie nur `ScreenshotPlan` prüfen), den Schalter `--screenshots` in `SystemNotice` (Z. ~323–327; `AppLaunch.backgroundArgument` bleibt) und das ungenutzte `ScreenshotContextMenu` (`ObjectFileContextMenu.swift` Z. ~489). Prüft ein Testteil auch Anderes, nur den Screenshot-Teil entfernen.
- Akzeptanz: `grep -rn "ScreenshotPlan\|ScreenshotRunner\|ScreenshotContextMenu\|--screenshots" diskindex/` leer; 0 Warnungen; betroffene Suites grün.

Nacharbeit-Status:
bug.0.3.8.005: Entfernt: `DebugTools/ScreenshotPlan.swift` (in den Papierkorb), `ScreenshotContextMenu` (`ObjectFileContextMenu.swift`), `--screenshots` in `NoticePermission` (`SystemNotice.swift`); `LayoutCopyTests`: `ScreenshotPlan`-Zeilen, `aFlatImageCountsAsEmptyAndAMarkedOneDoesNot` + Hilfe `bitmap(mark:)`; `RestCoverageTests`: Screenshot-Teil, Test heißt jetzt `databaseHealthAndNoticePermission`.
Abweichung: statt der `--screenshots`-Erwartung prüft der Test den `false`-Zweig mit `AppLaunch.backgroundArgument` (sonst ungetestet). Grep der Akzeptanz leer; 0 Warnungen; Suites seriell grün 12:31:28 (22 Tests). Bereit zur Prüfung.

**bug.0.4.031 — Identität: Klone und Volume-Umbenennung (REPORT 116, 78).**
- a) 116: `volumeAppeared` verwirft einen Treffer, dessen Medium-ID schon unter einem **anderen, noch eingehängten** Pfad steht, und behandelt ihn wie mehrdeutig (neues Medium mit Dialog). Nie zwei Pfade für ein Medium.
- b) 78: `NSWorkspace.didRenameVolumeNotification` (`NSWorkspaceVolumeOldURLKey`/`NSWorkspaceVolumeURLKey`) als eigenes `MediumEvent`. Den Pfadschlüssel im Coordinator umbiegen, den Watcher mit neuem `VolumeInfo` stoppen und neu starten. Zusätzlich `kFSEventStreamCreateFlagWatchRoot` setzen.
- **Akzeptanz:**
  - Zwei `.appeared` mit gleicher `volumeUUID` und verschiedenen Pfaden → zwei IDs, Einträge des ersten unverändert.
  - Rename-Event → `volume(for:)` liefert den neuen Pfad; Unmount mit neuem Pfad setzt offline.
- c) `todo.0.4.032` (Nutzer 16.10.): Wird ein **neues** Medium erkannt (Erkennungs-Dialog) und gibt es ein **Offline**-Medium mit **gleichem Namen**, folgt nach der Entscheidung im Dialog eine Rückfrage: **Textvorschlag** (de/en über `LayoutCopy`, Nutzer prüft): Titel „Ersetzt dieses Medium „{Name}“?“, Text „Ein Medium mit diesem Namen ist bekannt, aber nicht angeschlossen. Wurde es neu formatiert, kann das alte mit Index und Favoriten vergessen werden.“, Knöpfe „Altes vergessen“ (rot) und „Behalten“ (Standard, Esc). „Altes vergessen“ ruft den bestehenden Vergessen-Weg auf. Nie automatisch vergessen. Mehrere Offline-Treffer mit gleichem Namen: keine Rückfrage.
  - Akzeptanz: Offline-Medium „USB“ + neues Medium „USB“ → Rückfrage; „Behalten“ → beide bleiben; „Altes vergessen“ → altes weg (Store und Liste); zwei Offline-„USB“ → keine Rückfrage.
  - Die Rückfrage ist eine neue Ansicht: Maße und Knöpfe aus dem Komponentenkatalog (Regel 13), Test mit echtem Fenster außerhalb des Bildschirms (Regel 10/19), Klick auf beide Knöpfe per `window.sendEvent` (Regel 21).
Status:
bug.0.4.031: a) `volumeAppeared` verwirft Treffer, die unter anderem Pfad eingehängt sind (Klon → neues Medium mit Dialog; erneut gesteckter Klon findet seine Zeile). b) `MediumEvent.renamed` (Monitor: `didRenameVolumeNotification`), Coordinator biegt Pfad und Name um; LiveWiring `onMediumRenamed`: Watcher neu mit neuem Volume, aktiver Lauf → abbrechen + Abgleich; `onFullReconcile` nimmt das Volume des Coordinators; `kFSEventStreamCreateFlagWatchRoot`. c) `AppState.offerReplaceMediumPrompt`/`resolveReplaceMediumPrompt`, `ReplaceMediumDialog.swift`, Panel in `AppWindowPresenter`, zentral neu `DestructiveButtonStyle`.
Tests: `MediumIdentityTests` (6: Klon, Rename, Rename im Lauf, Rückfrage/Behalten/Vergessen, zwei Offline-„USB“), `ReplaceMediumDialogWindowTests` (Fenster außerhalb, 340 / 149 × 38,8 hell+dunkel, Klick beide Knöpfe). Sabotage rot ✓ 09:10:22 (Klon-Schutz, Watcher-Neustart, Auslöser aus), 09:11:46 (Knöpfe 154/95,5 statt 149), 09:12:55 (Aktionen vertauscht); zurückgenommen. Seriell grün 09:13:50.
Neue Texte: `copy.replace_medium.title` „Ersetzt dieses Medium „%1$@“?“ / “Does this medium replace “%1$@”?”; `.body` (Textvorschlag) / “A medium with this name is known but not connected. If it was reformatted, the old one can be forgotten along with its index and favorites.”; `.forget_old` „Altes vergessen“ / “Forget old”; `.keep` „Behalten“ / “Keep”.
Frage: Steckt nach einem Klon nur eine der beiden Platten, passen zwei Zeilen mit gleicher UUID → „mehrdeutig“, jede weitere Steckung legt eine neue Zeile an. Klon-Zeile ohne `volumeUUID` speichern oder bei Mehrdeutigkeit nachfragen? Außerdem offen für den Stick-Test: `rootChanged` (WatchRoot) beim Abziehen/Umbenennen kann einen Abgleich auf dem alten Pfad anstoßen. Bereit zur Prüfung bis auf die Frage.

**Nacharbeit (Host 17.10. 10:15):**
- Antwort Klon (Nutzer 17.10.): **Bei Mehrdeutigkeit zwischen bekannten Medien das zuletzt gesehene nehmen** (`lastSeenAt` am größten) und **kein** neues Medium anlegen. Gilt nur, wenn alle Treffer dieselbe starke Kennung haben und keiner unter einem anderen Pfad eingehängt ist; sonst bleibt das heutige Verhalten. Kein neuer Text. Test: Klon angelegt (beide gesteckt) → beide ab → nur der Klon steckt → genau das zuletzt gesehene Medium verbindet sich, Zahl der Medien bleibt gleich; zweimal wiederholt bleibt sie gleich.
- **Abziehen mit `WatchRoot` absichern (vor dem Stick-Test Pflicht):** `rootChanged` kann beim Abziehen kommen, bevor bzw. ohne dass `unmounted` gesetzt ist. `onFullReconcile` (`LiveWiring`) nimmt heute `coordinator?.volume(for: id) ?? volume`, also den alten Pfad, wenn das Medium schon weg ist → Abgleich ins Leere, womöglich Status „Fehler“. Ist das Medium nicht mehr eingehängt (`coordinator.volume(for:) == nil`), nichts starten; nur Protokollzeile. Test: Medium verbunden → `.disappeared` → `rootChanged` aus der Change-Quelle → kein Start, Status nicht „Fehler“; und Umbenennung → `rootChanged` → genau ein Abgleich unter dem **neuen** Pfad.

Nacharbeit-Status:
bug.0.4.031: Klon allein: `volumeAppeared` nimmt bei gleich starken Treffern (alle `.uuid` bzw. `.fingerprint`, keiner anderswo eingehängt) das Medium mit jüngstem `lastSeenAt` (Gleichstand: `uuid`), kein neues; Test `cloneAloneConnectsTheMostRecentlySeenMedium` (2× wiederholt, Zahl bleibt 2).
`rootChanged`: Nach `.disappeared` ist der Watcher schon gestoppt; ein Test in dieser Reihenfolge wäre immer grün. Gefährlich ist `rootChanged` **vor** dem Aushängen. Daher startet `ChangeWatcher` bei `rootChanged` keinen Abgleich mehr (nur Protokoll); `onFullReconcile` startet nichts, wenn `coordinator.volume(for:) == nil`; der eine Abgleich nach Umbenennung kommt aus `onMediumRenamed` (neuer Pfad, danach Watcher mit neuem Volume über `onRunIndexed`).
Tests: `rootChangedWhilePullingStartsNoReconcile` (Stick weg, `rootChanged` aus Testquelle → kein Start, nicht „Fehler“), `renameRekeysPathReconcilesOnceAndUnmountSetsOffline` (genau `[false, false]`, `rootChanged` der neuen Quelle startet nichts). `WiredRig.watcher` neu.
Nach Review: ohne Lauf (Medium pausiert) startet `onMediumRenamed` den Watcher direkt; Tests warten auf den gespeicherten Ereignisstand statt fest zu schlafen. Gleichstand `lastSeenAt` (gleiche Sekunde) entscheidet fest über `uuid`, nicht zwingend der Klon. Sabotage rot ✓ 12:27:27 und 12:31:09 (alter `rootChanged`-Weg → 2 bzw. 3 Starts und Status „Fehler“; „zuletzt gesehen“ aus → je Steckung neues Medium; Umbenennen ohne Abgleich → 1 Start), zurückgenommen. Suites seriell grün 12:30:32. Bereit zur Prüfung.

**HALT nach Paket 5b = Ende von 0.3.8** — Abnahmekriterien 1–8, dann Version setzen (`todo.0.3.8.001`, `MARKETING_VERSION` auf `0.3.8`, nur nach Abnahmekriterien 1–8), danach 0.3.9.

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
| `bug.0.4.070` | `serviceRunPassesTheReasonToTheDialog` (früher F11), parallel selten rot |
| `bug.0.4.071` | kurze `Task.sleep` in mehreren Suiten (früher F23); Wackelgefahr |

---

## B. Backlog (nicht freigegeben, der Worker arbeitet nicht daran), nach Zielversion


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
- `todo.0.4.031` (Nutzer 16.10.): Ab **500** Zielen auf einmal (Ignorieren über das Kontextmenü) fragt die App vorher nach. **Textvorschlag** (de/en, Nutzer prüft): „{N} Einträge ignorieren?“, Knöpfe „Ignorieren“ und „Abbrechen“ (Standard, Esc). Unter 500 keine Rückfrage. Test: 499 → keine Rückfrage, 500 → Rückfrage, „Abbrechen“ ändert nichts.
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
| `todo.0.4.026` | **„Für dieses Medium merken“ auswerten** (`todo.0.4.034`): `rememberDecision` beim Anschließen lesen; ohne Haken erscheint der Erkennungs-Dialog beim nächsten Anschließen wieder (Vorbelegung = letzte Entscheidung), mit Haken nicht. Test für beide Fälle. |
| `todo.0.4.027` | **Pause beim Start abgelaufen** (`todo.0.4.035`): Mitteilung „Medien werden wieder indiziert.“ wie beim Ablauf im Betrieb (gleiche Schalter); danach Abgleich wie nach Pausenende. Test. |
| `todo.0.4.028` | **Versions-Check nach Kalenderzeit** (`todo.0.4.036`): Zeitpunkt des letzten Checks speichern; beim Start, beim Aufwachen und stündlich prüfen, ob 24 h vergangen sind. Test mit injizierbarer Uhr. |
| `bug.0.4.063` | **Nur-Lesen-Sperre stoppt laufende Arbeit nicht (Befund Host 17.10.):** `AppState.onVersionLockEngaged` wird in `VersionCheckCoordinator` aufgerufen, aber im Produkt nirgends gesetzt. Beim Einrasten der Sperre laufen Indexlauf, Regel-Abgleich und Überwachung weiter (README: gesperrt = 100 % nur ansehen, auch Überwachung aus). `IndexingService.cancelAllActiveForVersionLock` und `AppState.cancelRuleReconcileForVersionLock` rufen nur Tests auf (`VersionLockReadOnlyTests`, von Hand, Regel 18). In `LiveWiring` verdrahten (Läufe abbrechen, Abgleich abbrechen, Watcher stoppen); Test: Lauf aktiv → Auswertung mit Sperre → Lauf endet, keine Schreibvorgänge mehr, ohne die Abbruch-Funktionen von Hand aufzurufen. |
| `todo.0.4.029` | **Kleinkram Fehlerbericht und Altcode** (`todo.0.4.037`, `038`): jedes 201 gilt als Erfolg, `id` optional (Test: 201 ohne Körper → Zeile gelöscht, kein erneutes Senden); Screenshot-Werkzeug: nach `bug.0.3.8.005` verschoben (17.10.). |

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
