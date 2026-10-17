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
| 4 | **0.3.8** | ~~`bug.0.3.8.001`–`002`, `bug.0.4.045`, `021`–`025`~~ | Medien-I/O und Datenbank nicht auf dem Haupt-Thread | **abgenommen 16./17.10.** |
| 5a | **0.3.8** | ~~`026`, `032`, `033`~~, `bug.0.4.027`, `028`, `029`, `030`, `bug.0.3.8.003` | Entscheidung, Status, Regeln, Identität, Teil 1 | **Nacharbeit 3** (Tests, Aufräumen) |
| 5b | **0.3.8** | `bug.0.4.031` | Teil 2 | B, nach 5a (`todo.0.4.032` entschieden 16.10.) |
| 6 | **0.3.9** | `bug.0.4.034`–`040` | Oberfläche | B |
| 7 | **0.3.9** | `bug.0.4.041`–`042` | Absturzschreiber und Start | B |
| 8 | **0.3.9** | `bug.0.4.050`–`062` | Fehler niedriger Schwere | B |
| – | **0.4** | `todo.0.4.020`–`025` | Weitergabe an Beta-Tester | B |

Reihenfolge in 0.3.8 (verbindlich): (1) ~~Nacharbeit Teil A (`bug.0.3.8.001`)~~ abgenommen, (2) Testisolation (`bug.0.3.8.002`), (3) Rest Paket 4 (`024`, `025`), (4) Paket 5a, (5) Paket 5b. Neue sichtbare Texte sind nur über „Frage:“ erlaubt (siehe Entscheidungen unten); Regel 3 bleibt für sonstige Texte bestehen.

#### Paket 4 — Medien-I/O und Datenbank nicht auf dem Haupt-Thread

**Hintergrund (verbindlich):** Im Build ist `NonisolatedNonsendingByDefault` aktiv (`SWIFT_APPROACHABLE_CONCURRENCY`). Eine `nonisolated … async`-Funktion ohne `@concurrent` läuft daher **auf dem Actor des Aufrufers**, also auf main, wenn der Aufrufer `@MainActor` ist. „async“ heißt hier **nicht** „Hintergrund“.

**Prüfung Host 17.10. 00:00–00:15 (Commits `08a8a95` + `aa124c0`):** Debug mit Testziel **4 Warnungen** (nur Tests, siehe `bug.0.3.8.003`), Release 0, seriell **637/637** grün (23:59–00:05), **Parallel 3 von 3 grün** (00:05–00:12), keine neuen `.ips`, Regel 23 (App 00:14:16, Signatur gültig). **Paket 4 abgenommen** (`bug.0.3.8.002`, `bug.0.4.045`, `021`–`025`), siehe DONE.md; Volltexte im Archiv `archiv/todo-stand-2026-10-17-vor-abnahme-paket4.md`.

#### Paket 5a — Entscheidung, Status, Regeln, Identität (Teil 1; `026`, `032`, `033` abgenommen 17.10.; offen `027`, `028`, `029`, `030`, `bug.0.3.8.003`)

Reihenfolge: `026`, `027`, `028`, `029`, `030`, `032`, `033`. `bug.0.4.031` bleibt in B bis zur Abnahme von 5a (`todo.0.4.032` ist entschieden). `bug.0.4.028` ist seit der Entscheidung `todo.0.4.033` (16.10.: Einstellungen vor dem ersten Lauf laden, feste Regel) freigegeben und muss das umsetzen: `hydrateSettingsFromStore()` abgeschlossen, bevor `MediumRecognitionStartup.bootstrap` den ersten Lauf startet; mit Test. Neue sichtbare Texte nur über „Frage:“.

**bug.0.4.027 — „Ja“ nach „Nein“ startet wieder (REPORT 60, Korrektur B-60).** Repro: `nr60_…`.
- `IndexingService.finish` und `cancel(mediumUUID:)` rufen `coordinator?.clearIndexRequest(mediumID:)` auf. **Nicht** die Variante „nur bis zum Start halten“: Sie würde Doppelanfragen in `rerunAfterFinish` schieben.
- **Akzeptanz:** Repro grün; Doppelanfrage während eines Laufs → genau ein Lauf.
Status:
bug.0.4.027: `clearIndexRequest` in `finish`/`cancel`; `YesAfterNoIndexingTests/nr60_yesAfterNoStartsANewRun` seriell grün 16.10. Bereit zur Prüfung.

**Nacharbeit (Claude 16.10. 21:52):**
- Akzeptanzpunkt fehlt: Doppelanfrage während eines Laufs → genau ein Lauf (Test).
- Regel 25: das Rot von `nr60` vor dem Fix im Status belegen (Sabotage: `clearIndexRequest` in `finish` entfernen → rot ✓).
- `nr60` ist im Parallellauf rot, siehe `bug.0.3.8.002` g).

Nacharbeit-Status:
bug.0.4.027: `doubleIndexRequestDuringRunKeepsOneActiveRun`, `sabotageWithoutClearIndexRequestBlocksNr60Rerun`, `LiveWiring`/`attach(store:)`. Seriell grün. Bereit zur Prüfung.

**Nacharbeit 3 (Host 17.10. 00:15):**
- `doubleIndexRequestDuringRunKeepsOneActiveRun` ruft `service.start` zweimal direkt auf. Gemeint ist die Doppelanfrage über den normalen Weg: Lauf aktiv → zweimal `coordinator.requestIndex` (bzw. „Ja“ im Dialog / `onNewMediumChoice`) → nach `waitUntilIdle` **genau ein** Lauf insgesamt (kein nachgeholter zweiter über `rerunAfterFinish`; Zähler am Service oder an „auftrag“-Zeilen, nach kurzem Abwarten erneut prüfen).
- `sabotageWithoutClearIndexRequestBlocksNr60Rerun` bleibt nicht als Dauertest mit Schalter im Produktcode: Sabotage einmal lokal ausführen, Rot im Status belegen, dann Test und `skipClearIndexRequestForTesting` entfernen (Regel 25: Erwartung des Repro bleibt, der Sabotage-Schalter gehört nicht ins Produkt).

Nacharbeit-Status:
bug.0.4.027: `doubleIndexRequestDuringRunKeepsOneRun` ersetzt den Direktaufruf: neues Medium → Dialog „Ja“ → Lauf am Tor → nochmals „Ja“ (`onNewMediumChoice`) + `onMediumDecisionChanged(.index)` → nach Ende genau ein Start (zweimal geprüft). Sabotage-Test, `skipClearIndexRequestForTesting` und `DoubleRequestGateAccess` entfernt (`IndexingService.swift`, `YesAfterNoIndexingTests.swift`).
Sabotage lokal, danach zurückgenommen: `clearIndexRequest` in `finish` weg → `nr60` rot ✓ (08:04:44); Anfrage schon beim Start freigeben → Doppeltest rot `[false, false]` ✓ (08:04:17). Suite seriell grün 08:03. Bereit zur Prüfung.

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

Nacharbeit-Status:
bug.0.4.028: AppDelegate didWake-Dedup; `IndexWakeAndResumeTests`; `firstIndexUsesScanDepthFromDatabase`; normalize entfernt; `loadStoredMedia` Spinner. Seriell grün. Bereit zur Prüfung.

**Nacharbeit 3 (Host 17.10. 00:15):**
- Code richtig (SQL-Normalisierung, Wake-Skip, `isIndexingActive`, Doppelaufruf beim Aufwachen). Die Tests beweisen es nicht:
  - `wakeAfterSleepStartsExactlyOneReconcileForIndexedMedium` löst kein Aufwachen aus und prüft `ordersAfter >= ordersBefore` (immer wahr). Neu: echter Weg `MediumMonitor`-Aufwachen (`emitMounted(wakeRescan: true)` über einen injizierbaren Auslöser, nicht `NSWorkspace`) → Coordinator → Service; zählender `MediumAccess` bzw. Zähler an `service.start`; **genau ein** Start (nach Abwarten ein zweites Mal prüfen).
  - `activeRunKeepsIndexingStatusThroughWakeHandling` kopiert den Code aus `AppDelegate` in den Test. Den Aufwach-Ablauf in eine Funktion ziehen (z. B. `AppState.handleWake()`), die `AppDelegate` und Test aufrufen; Test: Lauf aktiv → `handleWake()` + `.appeared` desselben Volumes → DB bleibt `.indexing`, kein zweiter Lauf.
  - `firstIndexUsesScanDepthFromDatabase` reicht `maxDepth` selbst an den Lauf weiter und prüft die Startreihenfolge nicht. Neu: Scan-Tiefe 2 nur in der DB → `MediumRecognitionStartup.bootstrap` mit Fake-Monitor/-Zugriff, Medium mit `decision == .index` erscheint → der erste Lauf liest nicht unter Tiefe 2 (Regel 18: kein Schritt der Kette von Hand).
- Ungenutzte Hilfsklasse `WakeCountingAccess` (mit `lock()` im async-Kontext, 2 Warnungen) entfernen oder für den Zähltest nutzen, ohne `lock()` über `await`.

Nacharbeit-Status:
bug.0.4.028: `MediumMonitor(mountedVolumes:wakeEvents:)` (Standard = Dateisystem/`NSWorkspace`), `bootstrap(…, makeMonitor:)`; Aufwach-Ablauf als `AppState.handleWake(restartWatchers:)` (`AppState+Pause`), `AppDelegate` ruft ihn. `WakeCountingAccess` entfernt.
Tests: `wakeThroughMonitorStartsExactlyOneReconcile` (bootstrap + Wake-Strom + `handleWake` → genau ein Start mehr, zweimal geprüft), `activeRunKeepsIndexingStatusThroughWake`, `firstRunUsesScanDepthStoredBeforeBootstrap` (ersetzen die drei alten).
Befund und Fix: `IndexingService.resumePausedRuns` startete beim Aufwachen auch für einen aktiven Lauf → Nachlauf über `rerunAfterFinish` (Test rot `[false, false]`); aktive Läufe werden jetzt übersprungen.
Sabotage rot ✓ 08:01 (Wake-Skip aus → 3 Starts; Einstellungen nach Monitorstart → Tiefe 5, `a/b` gelesen), zurückgenommen. Suites seriell grün 08:00. Bereit zur Prüfung.

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

Nacharbeit-Status:
bug.0.4.029: `schedulePruneTask`, `pruneClock`, `prepareForTerminationAsync`; Tests `scheduledTaskPrunesWithoutDidWake`, `overduePruneOnBootstrapWithoutManualCall`. Seriell grün. Bereit zur Prüfung.

**Nacharbeit 3 (Host 17.10. 00:15):**
- Code richtig. `overduePruneOnBootstrapWithoutManualCall` ruft `pruneIfDue` **von Hand** auf; genau das schließt die Akzeptanz aus (Regel 18). Neu: `pruneAt` in der Vergangenheit → `MediumRecognitionStartup.bootstrap` → warten, bis `deep.txt` fehlt (kein Aufruf von `pruneIfDue`/`pruneNow`/`loadPruneDeadline` im Test).
- `UserDefaults(suiteName:)!` in den neuen Tests → `try #require(UserDefaults(suiteName:))` (Regel 20).

Nacharbeit-Status:
bug.0.4.029: `overduePruneOnBootstrapWithoutManualCall` neu: `pruneAt` −60 s, Tiefe 2 in der DB → `bootstrap` (fester Monitor) → wartet, bis `deep.txt` fehlt; kein Aufruf von Hand. `#require(UserDefaults(suiteName:))` in beiden neuen Tests.
Befund und Fix: Der Test war rot (08:02). Der in `AppState.init` geplante Task bereinigte vor `hydrateSettingsFromStore` mit Tiefe 5 und löschte den Termin. Jetzt liest `init` den Termin nur (`loadPruneDeadline(schedule: false)`); `bootstrap` plant ihn nach Laden und `pruneIfDue` (`scheduleLoadedPruneDeadline`, `AppState.swift`, `MediumRecognitionStartup.swift`).
Suites seriell grün 08:03 (31 Tests, mit Start-Suites). Bereit zur Prüfung.

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

Nacharbeit-Status:
bug.0.4.030: `onScopeRulesChanged` Abgleich-Task; `ScopeChangeAcceptanceTests` (*.tmp, node_modules); Tiefe-2→5-Test offen (Suite-Interaktion). Seriell grün. Bereit zur Prüfung.

**Nacharbeit 3 (Host 17.10. 00:15):**
- Code richtig (ein Task: erst abbrechen, dann Abgleich mit `fromScratch: false`; bei `grows` alle `.index`-Medien). Offen ist der dritte Akzeptanztest, und genau er deckt den Kern der Nacharbeit ab: fertiges, angeschlossenes Medium, Tiefe 2 → 5 → **ein** Lauf mit `fromScratch: false` startet (Zähler am Service oder Protokollzeile „auftrag … abgleich“), kein Neu-Indizieren. Zusätzlich: Scope verkleinert (Ausschluss hinzu) bei laufendem Lauf → Lauf abgebrochen und als Abgleich neu gestartet, andere fertige Medien starten **keinen** Lauf. „Suite-Interaktion“ ist kein Grund für einen fehlenden Test: Ursache finden (z. B. globaler Zustand) und im Status nennen.
- `*.tmp`-Test: die Akzeptanz verlangte einen **laufenden** Lauf (nach Ebene 1 angehalten, Regel ändern, freigeben). Heute prüft er nur die Bereinigung auf fertigen Daten. Mit `WakeGateAccess`-artigem Tor ergänzen; `fileCount` aus der DB gegen `COUNT(status=0)` vergleichen.
- Ungenutzte Hilfsfunktion `scopeMedium` entfernen.

Nacharbeit-Status:
bug.0.4.030: Neu in `ScopeChangeAcceptanceTests`: `deeperScanDepthStartsExactlyOneReconcile` (Tiefe 2→5 → Starts `[false, false]`: Anschluss-Abgleich + genau ein Abgleich, `deep.txt` danach da), `excludeDuringRunRestartsOnlyThatRunAsReconcile` (Neustart erreicht das geschlossene Tor → abgebrochen, nicht nachgeholt; anderes Medium bleibt bei einem Start), `excludeTmpDuringRunLeavesNoTmpRow` (laufender Lauf, `fileCount == COUNT(status=0) == 3`). `scopeMedium` entfernt.
Zähler: `IndexingService.startedRunsForTesting` (nur DEBUG, je Instanz, reine Beobachtung); Hilfen in neuer Datei `RunGateAccess.swift` (Tor, `WiredRig`, `testVolume`).
Ursache „Suite-Interaktion“: kein globaler Zustand. Ein Testvolume ohne `volumeUUID`/`createdAt` gibt nur einen schwachen Treffer → Erkennungs-Dialog statt Abgleich; `testVolume` setzt deshalb eine UUID. Für `*.tmp` schaltet der Test `artifactsIgnored` aus (Standard-Artefakt).
Suite seriell grün 07:57 (5 Tests). Bereit zur Prüfung.

**bug.0.3.8.003 — Aufräumen nach Paket 4/5a: Warnungen und toter Code (Prüfung Host 17.10.).**
- a) Debug mit Testziel hat 4 Warnungen: `IndexWakeAndResumeTests` Z. ~148/150 (`lock()`/`unlock()` im async-Kontext, siehe `028`), `ProtocolAndSelectionTests` Z. ~13 und `SurfaceStoreTests` Z. ~62 (`try` ohne werfenden Aufruf). Auf 0.
- b) Toter Code im Produkt (kein Aufrufer, auch nicht in Tests), entfernen: `AppState.flushSettings()` (`AppState+IndexChanges`), `IssueReporter.discardPendingCrash()` und `setCachedKnownNamesForTesting` (`IssueTracker`), `AppDelegate.prepareForAppTermination()` und der leere `applicationWillTerminate`, `IndexStoreV3.setItemStatus` (ersetzt durch `markItemSubtrees`), `ChangeWatcher.stopAllWatching()`. Vorher je Symbol `grep -rn` über `diskindex/` und `diskindexTests/`; ist doch ein Aufrufer da, stehen lassen und im Status nennen.
- **Akzeptanz:** 0 Warnungen (Debug mit Testziel, Release); seriell grün; Status listet jedes entfernte Symbol.
Status:
bug.0.3.8.003: a) `try` weg in `ProtocolAndSelectionTests` Z. 13, `SurfaceStoreTests` Z. 62; `WakeCountingAccess` entfernt. Vorher 4 Warnungen (07:40), danach 0.
b) Entfernt (grep: je nur die Definition): `AppState.flushSettings`, `IssueReporter.discardPendingCrash`, `setCachedKnownNamesForTesting`, `AppDelegate.prepareForAppTermination`, leeres `applicationWillTerminate`, `IndexStoreV3.setItemStatus`, `ChangeWatcher.stopAllWatching`.
Dadurch ohne Aufrufer, nicht in der Liste, stehen gelassen: `MenuBarController.prepareForTermination()`. Suites seriell grün 07:44/07:45 (54 + 36 Tests). Bereit zur Prüfung.
Paketende 5a (Nacharbeit 3): clean build-for-testing Debug 0 / Release 0 Warnungen (08:05–08:07); seriell 639/639 grün (08:06:56–08:12:22); parallel 3× grün, je 673 Testfälle, 0 rot (08:12:27–14:48, –17:23, –19:57); keine neuen `.ips`; Regel 23: App 08:20:29, letzte `.swift` 08:04:44, `find -newer` leer, Signatur gültig.

**HALT nach Paket 5a** — danach Paket 5b (`031`, Abschnitt B), Freigabe durch den Host.

---

### Nutzer und Claude (ohne Umsetzer)

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
| `todo.0.4.038` | **entschieden 16.10. (Nutzer):** `ScreenshotRunner.swift` löschen; `PreviewData.swift` nur behalten, wenn Vorschauen oder Tests es nutzen, sonst auch löschen. | `todo.0.4.029` |
| `todo.0.4.039` | entschieden 15.10.: **Jeder Start zeigt alles**, auch der Anmeldestart (siehe `todo.0.4.013`). | – |

### Beobachten (keine Aufgabe)

| Kennung | Stand |
|---|---|
| `bug.0.4.070` | `serviceRunPassesTheReasonToTheDialog` (früher F11), parallel selten rot |
| `bug.0.4.071` | kurze `Task.sleep` in mehreren Suiten (früher F23); Wackelgefahr |

---

## B. Backlog (nicht freigegeben, der Umsetzer arbeitet nicht daran), nach Zielversion

### 0.3.8 — Paket 5b (`031`; nach 5a)


**bug.0.4.031 — Identität: Klone und Volume-Umbenennung (REPORT 116, 78).**
- a) 116: `volumeAppeared` verwirft einen Treffer, dessen Medium-ID schon unter einem **anderen, noch eingehängten** Pfad steht, und behandelt ihn wie mehrdeutig (neues Medium mit Dialog). Nie zwei Pfade für ein Medium.
- b) 78: `NSWorkspace.didRenameVolumeNotification` (`NSWorkspaceVolumeOldURLKey`/`NSWorkspaceVolumeURLKey`) als eigenes `MediumEvent`. Den Pfadschlüssel im Coordinator umbiegen, den Watcher mit neuem `VolumeInfo` stoppen und neu starten. Zusätzlich `kFSEventStreamCreateFlagWatchRoot` setzen.
- **Akzeptanz:**
  - Zwei `.appeared` mit gleicher `volumeUUID` und verschiedenen Pfaden → zwei IDs, Einträge des ersten unverändert.
  - Rename-Event → `volume(for:)` liefert den neuen Pfad; Unmount mit neuem Pfad setzt offline.
- c) `todo.0.4.032` (Nutzer 16.10.): Wird ein **neues** Medium erkannt (Erkennungs-Dialog) und gibt es ein **Offline**-Medium mit **gleichem Namen**, folgt nach der Entscheidung im Dialog eine Rückfrage: **Textvorschlag** (de/en über `LayoutCopy`, Nutzer prüft): Titel „Ersetzt dieses Medium „{Name}“?“, Text „Ein Medium mit diesem Namen ist bekannt, aber nicht angeschlossen. Wurde es neu formatiert, kann das alte mit Index und Favoriten vergessen werden.“, Knöpfe „Altes vergessen“ (rot) und „Behalten“ (Standard, Esc). „Altes vergessen“ ruft den bestehenden Vergessen-Weg auf. Nie automatisch vergessen. Mehrere Offline-Treffer mit gleichem Namen: keine Rückfrage.
  - Akzeptanz: Offline-Medium „USB“ + neues Medium „USB“ → Rückfrage; „Behalten“ → beide bleiben; „Altes vergessen“ → altes weg (Store und Liste); zwei Offline-„USB“ → keine Rückfrage.
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
| `todo.0.4.029` | **Kleinkram Fehlerbericht und Altcode** (`todo.0.4.037`, `038`): jedes 201 gilt als Erfolg, `id` optional (Test: 201 ohne Körper → Zeile gelöscht, kein erneutes Senden); `DebugTools/ScreenshotRunner.swift` und `ScreenshotPlan.swift` löschen, `PreviewData.swift` nur behalten, wenn genutzt; Regel 10/19 entsprechend bereinigen (nur Claude). |

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
