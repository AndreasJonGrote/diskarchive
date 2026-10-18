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
31. **Selbstprüfung mit Subagent (Nutzer 18.10.).** Nach jedem Zwischenschritt (jeder Aufgabe) lässt der Worker seine Arbeit einmal von einem Subagenten prüfen (Akzeptanz, Regel 18/20, Sabotage plausibel). Am Ende des Laufs darf er **einmal** selbstständig korrigieren, was die Prüfungen gefunden haben; was danach offen bleibt, steht im Status. Die Abnahme bleibt beim Host (Regel 28).

---

---

## A. Jetzt

**Stand 17.10.2026 (Host):** Version im Xcode-Projekt **0.3.9**. Abgenommen: 0.3, 0.3.1, 0.3.2, aus 0.4 Versions-Check/Update-Modal/Beta-Sperre/Nur-Lesen-Sperre, und für **0.3.8 die Pakete 4 und 5a** (DONE.md). Offen für 0.3.8: **Paket 5c** (freigegeben; 4, 5a, 5b abgenommen), danach `todo.0.3.8.001` (Version). Stick-Test, Großplatten-Lauf und Layout gesammelt als letzter Schritt von 0.4 (`todo.0.4.040`). Letzte Prüfung 18.10. 11:02–11:19: 0 Warnungen, seriell 866/866, parallel 3/3. Ein Worker zur Zeit, Pakete nacheinander. Bestandsaufnahme vom 16.10.: [archiv/bestandsaufnahme-2026-10-16.md](archiv/bestandsaufnahme-2026-10-16.md).

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
| 8a | **0.3.9** | ~~`bug.0.3.9.001`–`003`, `005`–`010`~~ | Befunde aus den Prüfungen | **abgenommen 17.10.** |
| 8b | **0.3.9** | ~~`bug.0.3.9.011`–`014`, `bug.0.4.050`–`062`~~ | Prüfbefunde 8a, Fehler niedriger Schwere (Audit) | **abgenommen 18.10.; 0.3.9 fertig** |
| 9 | **0.4** | ~~`todo.0.3.9.001`, `bug.0.4.063`–`068`, `todo.0.4.026`–`029`~~ | Version 0.3.9, Prüfbefunde, Code ohne Nutzerschritte | **abgenommen 18.10.** |
| 10 | **0.4.0** | ~~`bug.0.4.072`–`076`, `todo.0.4.023`~~ | Prüfbefunde 9, Fehlerbericht | **abgenommen 18.10.** |
| 11 | **0.4.0** | `bug.0.4.077` (Nacharbeit), `078`–`080` | natürliche Ordnung schneller, Datenschutz im Fehlerbericht | **freigegeben 18.10.** |
| – | **0.4.0** | `todo.0.4.040` (Nutzer) | Abnahmerunde: 2-Mio-Platte, Stick, Layout → Release-Kandidat | nach Paket 10 |
| – | **0.4.1** | `todo.0.4.021`, `022`, `024`, `todo.0.4.1.001`, `todo.0.4.1.002` (Tester-Prüfung mit Quarantäne) | Release der Open Beta (Auslieferung) | B |

Reihenfolge: 0.3.8 abgenommen; jetzt 0.3.9 mit den Paketen 6, 7, 8, danach 0.4. Neue sichtbare Texte nur über „Frage:“ oder als freigegebener Textvorschlag in der Aufgabe (Regel 3 bleibt).

#### Paket 4 und 5a — abgenommen (Hintergrund gilt weiter)

**Hintergrund (verbindlich):** Im Build ist `NonisolatedNonsendingByDefault` aktiv (`SWIFT_APPROACHABLE_CONCURRENCY`). Eine `nonisolated … async`-Funktion ohne `@concurrent` läuft daher **auf dem Actor des Aufrufers**, also auf main, wenn der Aufrufer `@MainActor` ist. „async“ heißt hier **nicht** „Hintergrund“.

**Prüfung Host 17.10. 00:00–00:15 (Commits `08a8a95` + `aa124c0`):** Debug mit Testziel **4 Warnungen** (nur Tests, siehe `bug.0.3.8.003`), Release 0, seriell **637/637** grün (23:59–00:05), **Parallel 3 von 3 grün** (00:05–00:12), keine neuen `.ips`, Regel 23 (App 00:14:16, Signatur gültig). **Paket 4 abgenommen** (`bug.0.3.8.002`, `bug.0.4.045`, `021`–`025`), siehe DONE.md; Volltexte im Archiv `archiv/todo-stand-2026-10-17-vor-abnahme-paket4.md`.

**Prüfung Host 17.10. 08:30–08:45 (Commit `58ec44e`):** Debug mit Testziel und Release 0 Warnungen, seriell **639/639** grün, Parallel **2 von 3** grün (Lauf 2 rot: `MainThreadMediumIOTests/directProbeKeepsMainActorResponsive`, Ticker 2 statt ≥ 8, Messaufbau, siehe `bug.0.3.8.004`), keine neuen `.ips`, Regel 23 erfüllt. **Paket 5a abgenommen** (`bug.0.4.026`–`030`, `032`, `033`, `bug.0.3.8.003`); die neuen Tests gehen über die echten Wege (Regel 18). Volltexte: `archiv/todo-stand-2026-10-17-vor-abnahme-paket5a.md`.

**Prüfung Host 17.10. 19:37–19:53 (Paket 8a, ungecommittet auf `151ea0f`):** Debug mit Testziel und Release 0 Warnungen, seriell **741/741** grün, **Parallel 3 von 3 grün**, keine neuen `.ips`, Regel 23 (App 19:52:52, Signatur gültig). Drei Prüf-Agenten: kein hoher Befund; zwei mittlere (`bug.0.3.9.011` Beenden hängt am Hauptthread, `012` langsames Volume) und niedrige (`013`, `014`) in Paket 8b. **Paket 8a abgenommen** (`bug.0.3.9.001`–`003`, `005`–`010`). Volltexte: `archiv/todo-stand-2026-10-17-vor-abnahme-paket8a.md`.

**Prüfung Host 18.10. 11:02–11:19 (Paket 10, ungecommittet auf `6396632`):** Debug mit Testziel und Release 0 Warnungen, seriell **866/866** grün, **Parallel 3 von 3 grün**, keine neuen `.ips`, Regel 23 (App 11:19:28, Signatur gültig; Achtung: diese App legt den Index aus `bug.0.4.077` beim Öffnen der Nutzer-Datenbank an). Zwei Prüf-Agenten: kein hoher Befund; ein mittlerer (Schwärzung, `bug.0.4.078`) und niedrige (`079`, `080`). **Abgenommen:** `bug.0.4.072`–`076`, `todo.0.4.023`. **Offen:** `bug.0.4.077` (Messung über der Grenze, Nacharbeit unten). Volltexte: `archiv/todo-stand-2026-10-18-vor-abnahme-paket10.md`.

#### Paket 11 — 0.4.0 (Release-Kandidat): natürliche Ordnung schneller, Datenschutz im Fehlerbericht (freigegeben 18.10.)

Reihenfolge: `bug.0.4.077` (Nacharbeit), `bug.0.4.078`, `079`, `080`. Danach ist der Code von 0.4.0 fertig; es folgt die Abnahmerunde des Nutzers (`todo.0.4.040`).

**bug.0.4.077 — Natürliche Namensordnung über die Seitengrenze, mit Index von Anfang an (Nutzer 18.10.; vorher Vorschlag `todo.0.5.002` aus `bug.0.4.038`).** Bei mehr als 500 Treffern wählt die Datenbank die erste Seite heute binär aus (`i.slug`), erst innerhalb der Seite wird natürlich sortiert; an der Seitengrenze fehlen dadurch natürlich benachbarte Namen („Rechnung 2“ bei „Rechnung 10/100“). Gleiches gilt für die Sortierung nach Medium (innerhalb eines Mediums).
- Neuer Index `items_search_natural ON items(slug COLLATE "natural", status)` (bzw. passend zur bestehenden Such-Bedingung) als **eigene neue GRDB-Migration** (nur Erweiterung, Regel 27). Weil es außer dem Nutzer noch keine Datenbanken gibt, entsteht der Index bei allen Testern von Anfang an und wächst beim Indizieren mit (kein nachträglicher Aufbau, Regel „Erweitern statt aktualisieren“). Auf der Datenbank des Nutzers baut die Migration ihn einmal beim Öffnen; das ist vor 1.0 zulässig.
- `searchSortedHitsSQL` (Name, auf/ab) und die Sortierung nach Medium (`s.slug, i.slug`) sortieren in SQL natürlich (`COLLATE "natural"`); das Nachsortieren innerhalb der Seite (`naturalWithinMedium` u. ä.) entfällt, wo SQL es jetzt liefert. `EXPLAIN QUERY PLAN` im Test: Index wird benutzt, kein `USE TEMP B-TREE FOR ORDER BY` bei Name.
- **Messung (Abnahmebedingung, Release-Build, gleiche Maschine, vorher/nachher):** Indizieren von mindestens 1 Mio. Einträgen (synthetisch über den Store, nicht über das Dateisystem) – Dauer und Dateigröße der Datenbank. Liegt der Mehraufwand beim Indizieren über **10 %** oder die Größe über **15 %**, Status „Blockiert: Messung“ und Rückfrage an den Host statt Abnahme. Zahlen in den Status.
- Tests: 600 Treffer `Rechnung 1`…`Rechnung 600` → erste Seite Name aufsteigend beginnt mit `Rechnung 1, 2, 3 …` (nicht `1, 10, 100`), absteigend mit `600, 599 …`; Sortierung nach Medium über die Seitengrenze natürlich. Sabotage (binäre Ordnung zurück) → rot ✓.
- Hinweis für Prüf-Skripte: Abfragen über diesen Index brauchen die Sortierregel „natural“; `sqlite3` im Terminal kennt sie nicht. Prüfungen per `sqlite3` nur auf Abfragen ohne diesen Index; im Status vermerken.
Status: Blockiert: Messung. Release (-O, ganzes Modul; Testhilfen über DEBUG, vorher/nachher gleich gebaut), Mac16,12 M4, 1.010.100 Einträge über applyDirectories, je 3 Läufe im Wechsel, Median: Indizieren 29,97 → 36,10 s (+20,5 %, Grenze 10 %), DB 238,0 → 274,6 MB (+15,35 %, Grenze 15 %; items_search_natural 36,5 MB). Prüf-Agent: Messung belastbar (Streuung < 1 %, Zuwachs = Index).
Im Arbeitsstand: Migration 0.4.0-items_search_natural (SchemaV3), natürliche SQL-Ordnung für Name/Medium/Cursor (IndexStoreV3+Reading), kein Nachsortieren (pageOrderedColumns + .name, naturalWithinMedium weg). Achtung: Die App aus Regel 23 legt den Index beim Öffnen der Nutzer-DB an.
Tests NaturalSearchOrderTests (7, u. a. Rechnung 1…600 auf/ab, Medium über die Seitengrenze, gleiche Namen an der Cursorgrenze, EXPLAIN ohne TEMP B-TREE), Messwerkzeug NaturalOrderIndexMeasurementTests (nur mit DISKINDEX_MEASURE=1); seriell 10:41:57–10:42:23 39 Tests grün; Sabotage rot ✓ 10:40:35, 10:41:35. sqlite3-Prüfungen keine (Kollation „natural“ unbekannt).
Frage: zweiten Index behalten, items_search durch die natürliche Fassung ersetzen (Größe ±0, braucht DROP INDEX – Regel 27) oder zuerst NaturalOrder.compare ohne Speicherblöcke (Zeit)? Hinweis: slug-Gleichheit in IndexStoreV3/DirectoryWriterV3 sollte bei Ersatz COLLATE "natural" nutzen.
Blockiert: Messung

**Nacharbeit (Host 18.10., Entscheidung des Nutzers nach der Messung):** Messung belastbar (+20,5 % Indizierzeit beim reinen Datenbank-Schreiben, +15,35 % Größe). Der Nutzer entscheidet: **erst den Vergleich beschleunigen.** `NaturalOrder.compare` (bzw. die Sortierfunktion der Kollation „natural“) ohne Speicheranlegen je Vergleich: direkt auf den UTF-8-Bytes bzw. Zeigern arbeiten, Zifferngruppen ohne Zwischen-Strings vergleichen, keine `String`/`Array`-Erzeugung im Vergleich. Gleiche Reihenfolge wie bisher (Tests `NaturalSearchOrderTests` bleiben unverändert grün, zusätzlich ein Gleichwertigkeitstest alt/neu über viele Zufallsnamen inkl. Umlaute und Ziffern). Danach **neu messen** wie vorher. **Abnahme:** Indizierzeit höchstens **+10 %**; die Größe (+15 %, gut 36 MB je Mio. Einträge) nimmt der Nutzer hin. Liegt die Zeit weiter über 10 %, „Blockiert: Messung“ mit den neuen Zahlen.

**bug.0.4.078 — Fehlerbericht: Schwärzung lässt Text nach „$s“/„$S“ durch (Prüf-Agent 18.10., mittel, Datenschutz).** `ReportScrubber.swift` Z. ~37–58 (`stackLine`): Der Ausdruck `\$[sS][0-9A-Za-z_]+` lässt jeden Text nach „$s“/„$S“ ungeschwärzt. Ohne `crash-last.txt` besteht `crash.stack` aus allen Protokollzeilen nach der letzten „CRASH signal=“-Zeile (`DiskIndexLog.swift` Z. ~691); ein Dateiname wie „Konto$Sparbuch.pdf“ ginge im Klartext in den Bericht. `stackLine` nur auf Zeilen anwenden, die wie Stapelrahmen aussehen (z. B. `^\d+\s+\S+\s+0x[0-9a-f]+`), alle anderen über die normale Schwärzung (`text`). Test: Protokollzeile mit „…$Sparbuch.pdf“ und Pfad hinter der CRASH-Zeile → im Bericht geschwärzt; echte Stapelrahmen bleiben lesbar. Sabotage rot ✓.
Status:

**bug.0.4.079 — Fehlerbericht kürzen: letzte Protokollzeilen behalten (Host-Entscheidung 18.10.).** `IssueTracker.swift` Z. ~91–102: Heute leert die Kürzung zuerst `logTail` ganz, dann `actions`, erst danach den Stapel. Neu: mindestens die **letzten 20 Protokollzeilen** bleiben erhalten; vorher wird der Stapel gekürzt (älteste Rahmen zuerst weg, Signal und Kopf bleiben), dann `actions`. Test mit sehr großem Stapel aus echtem Protokoll: Bericht ≤ 256 KB **und** `logTail` enthält mindestens 20 Zeilen.
Status:

**bug.0.4.080 — Kleinkram aus der Prüfung 10 (niedrig).**
- a) `IndexingService.swift` Z. ~101–109: Kommt `start` während eines Abbruchs zweimal (LiveWiring und Koordinator), wartet je ein eigener Task, der zweite landet in `rerunAfterFinish` → doppelter Abgleich. Wartende Starts je Medium zusammenfassen. Die beiden Tests in `VersionLockReadOnlyTests` (`starts == [false, false]`) nach dem Ende kurz nachwarten und erneut prüfen, damit ein später dritter Start auffällt.
- b) `LiveWiring.swift` Z. ~236–243: `watcher?.pauseChanged()` und `stopWatcherAndStartIndex` beim Entsperren nicht ungeordnet nebeneinander starten (erst Abgleich, Überwachung danach über `onRunIndexed`).
- c) `ChangeWatcher.swift` Z. ~358–362: Das `defer` eines alten Flushes darf nach `stopAllForVersionLock` und schnellem Entsperren die `flushInFlight`-Marke eines neuen Flushes nicht entfernen (Generation prüfen).
- d) `writeMedium`: früh zurück bei unbekanntem Medium → Marke `userDecisionIDs` mit entfernen.
- e) `IssueReportRealLogTests` Z. ~80/108: Testordner und UserDefaults-Suites aufräumen.
Status:

**HALT nach Paket 11.** Danach ist der Code von 0.4.0 fertig; nächster Schritt ist die Abnahmerunde des Nutzers (`todo.0.4.040`).







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

---

### 0.4.0 / 0.4.1 — Open Beta (Nutzer 18.10.: 0.4.0 Release-Kandidat, 0.4.1 Release)

| Kennung | Inhalt |
|---|---|
| `todo.0.4.020` | **verschoben nach 1.0 (Nutzer 18.10.):** Signatur mit Developer ID und Notarisierung erst zu 1.0. Alle Beta-Versionen gehen ohne Notarisierung (mit Quarantäne-Merkmal) an den kleinen Kreis der Tester; siehe `todo.0.4.021` (Anleitung) und `todo.0.4.040` (Prüfung). |
| `todo.0.4.021` | **Zielversion 0.4.1.** **Download-Seite** auf `https://diskarchive.app/` mit stabilem Link (Nutzer). **Pflicht (Nutzer/Host 18.10.):** kurze Anleitung für die nicht notarisierte Beta: (1) App aus dem Download in „Programme“ ziehen (sonst startet macOS sie von einem zufälligen Pfad, App-Translocation), (2) öffnen, (3) unter Systemeinstellungen → Datenschutz & Sicherheit „Trotzdem öffnen“ (seit macOS 15 reicht Rechtsklick → Öffnen nicht mehr). |
| `todo.0.4.022` | **Zielversion 0.4.1.** **Laufzeittest auf macOS 14** (z. B. VM); `pointerStyle` und `CGSize: Hashable` brauchen einen Ausweichweg. |
| `todo.0.4.023` | → Paket 10 (Abschnitt A, freigegeben 18.10.) |
| `todo.0.4.024` | **Zielversion 0.4.1 (aus Paket 10 genommen, Nutzer 18.10.).** → Paket 10 (Abschnitt A, freigegeben 18.10.) |
| `todo.0.4.040` | **Abnahmerunde des Release-Kandidaten 0.4.0 (Nutzer 17./18.10.):** erst, wenn **alles andere von 0.4.0 abgenommen** ist; nicht vorziehen. Inhalt: (1) Lauf über die große Platte des Nutzers (rund 2 Mio. HTML-Dateien): vollständig indizieren, suchen, Spaltenansicht in großen Ordnern, ab- und anstecken, Live-Änderung; Zeiten (Release-Build) und Protokoll festhalten. (2) Test am echten Stick (großer Ordner, Pfeiltasten, Mehrfachauswahl, Rechtsklick, Medium ab- und anstecken, Live-Änderung, Rückfrage „Ersetzt dieses Medium?“ samt Texten, Umbenennen eines Volumes). (3) Layout-Durchgang aller Ansichten gegen `layout/` (einschließlich `todo.0.3.2.001`).  Funde als `bug.0.4.xxx`; nach ihrer Behebung und Abnahme ist 0.4.0 der Release-Kandidat. An die Tester geht die App mit 0.4.1. Ersetzt das Kriterium 7 der Sprünge 0.3.8 und 0.3.9. |
| `todo.0.4.025` | **entfällt (Nutzer/Host 18.10.):** Ein Fenster „Datenbank wird aktualisiert“ braucht es nicht. Nach dem Datenbank-Konzept wird nur erweitert (neue Schlüssel oder neue Tabellen, angelegt in Millisekunden), nie umgebaut (README, Abschnitt „Datenbank“, „Erweitern statt aktualisieren“). |
| `todo.0.4.026` | → Paket 9 (Abschnitt A, freigegeben 18.10.) |
| `todo.0.4.027` | → Paket 9 (Abschnitt A, freigegeben 18.10.) |
| `todo.0.4.028` | → Paket 9 (Abschnitt A, freigegeben 18.10.) |
| `bug.0.4.063` | → Paket 9 (Abschnitt A, freigegeben 18.10.) |
| `todo.0.4.029` | → Paket 9 (Abschnitt A, freigegeben 18.10.) |

### 0.4.1 — Release der Open Beta: Auslieferung (Nutzer 18.10.)

| Kennung | Inhalt |
|---|---|
| `todo.0.4.1.001` | **DMG zum Herunterladen mit Hintergrundbild, ein Befehl (Nutzer 18.10.; verschoben auf 0.4.1, vorher `todo.0.4.041`).** **Auftrag „Erstelle nun das Ausgabe-DMG“** = ein Agent führt `Werkzeuge/dmg-erstellen.sh` aus, sonst nichts. Das Skript: (1) baut die Release-App selbst in einen festen Ordner (kein Suchen in DerivedData), (2) liest die Version aus `CFBundleShortVersionString`, (3) erzeugt das DMG mit **dmgbuild** (schreibt die Fenster-Einstellungen direkt, steuert den Finder nicht, Regel 19/21): App, symbolischer Link auf `/Applications`, Hintergrundbild @1x/@2x, feste Fenstergröße und Symbolpositionen aus `Werkzeuge/dmg/dmg-einstellungen.json`, (4) legt `Disk-Archive-<Version>.dmg` ins Git-Hauptverzeichnis (gleiche Version wird ersetzt), (5) prüft ohne Finder (`hdiutil attach -nobrowse`, Inhalt auflisten, aushängen) und meldet Pfad und Größe. Kein automatischer Lauf nach jedem Build. `*.dmg` in `.gitignore`. **Voraussetzung:** Layout-Seite `layout/DMG.dc.html` vom Nutzer mit Hintergrund (`dmg-background`, z. B. 660 × 400 pt) und zwei markierten Platzhaltern `dmg-app` und `dmg-applications`; der **Host** liest die Mittelpunkte aus und schreibt `dmg-einstellungen.json` (bei Layout-Änderung nachziehen), exportiert das Hintergrundbild als PNG @1x/@2x. Hinweis im Bild: Pfeil „in Programme ziehen“ und „Beim ersten Öffnen: Systemeinstellungen → Datenschutz & Sicherheit → Trotzdem öffnen“ (Beta ohne Notarisierung). Ansicht prüft der Nutzer. Freigabe durch den Host, sobald die Layout-Seite vorliegt. |

| `todo.0.4.1.002` | **Tester-Prüfung mit Quarantäne (aus `todo.0.4.040` gelöst, Nutzer 18.10.):** die nicht notarisierte App mit Quarantäne-Merkmal auf einen Mac bringen, der sie noch nie gesehen hat (oder Benutzerkonto ohne Vorgeschichte); prüfen: Gatekeeper-Freigabe nach Anleitung, Start aus „Programme“ (keine App-Translocation), Einzelinstanz, Start beim Anmelden (`SMAppService`), Update durch Ersetzen (`todo.0.4.024`), Fehlerbericht senden. |

Zu 0.4.1 gehören außerdem `todo.0.4.021` (Download-Seite mit Anleitung), `022` (macOS 14) und `024` (Update durch Ersetzen). Mit 0.4.1 geht die App an die Tester.

### 0.5 bis 1.0 (Entwürfe, jede Funktion vor dem Start einzeln besprechen; Details ROADMAP)

| Kennung | Inhalt |
|---|---|
| `todo.0.5.001` | **Metadaten und EXIF** (Video, Foto/RAW, Audio, PDF; zweiter Durchgang nach dem Index, Markierung `_analyzed`), neue Layouts, **Wartescreen der Suche** |
| `todo.0.5.002` | **vorgezogen als `bug.0.4.077` (Paket 10, Nutzer 18.10.).** |
| `todo.0.6.001` | **Vorschaubilder** 250 px, Abschalter global und je Medium, Dateien `Thumbnails/<storageID>/<itemID>` |
| `todo.0.7.001` | **CSV-Export** (Umfang, Spalten, Kodierung offen) |
| `todo.0.8.001` | **Duplikate** über volle Prüfsumme, nach Größe gruppiert, nur im Hintergrund |
| `todo.0.9.001` | **Lizenz** (1 / 50 / 250 Medien als Lizenzgrenze; Fragen siehe README) |
| `todo.1.0.001` | Ladehinweis erst nach 1 s (früher T1; prüfen, ob durch `DelayedLoadingState` erledigt) |
| `todo.1.0.002` | Erweiterte Dateityp-Icons (früher T3, Styleguide 15) |
| `todo.1.0.003` | Ausführliches Protokoll / Diagnose-Modus (früher T5, Vorschlag Claude, nicht freigegeben) |

Entfallen: T2 „Programme als Dateityp“ (erledigt in 233: `.app`, `.dmg`, `.pkg`); Signatur/Notarisierung stand im alten Backlog bei 1.0, gilt laut README aber als Voraussetzung von 0.4 (`todo.0.4.020`).
