Rolle: Worker (AGENTS.md). Lies TODO.md (Regeln 1–30, Abschnitt A). Paket 4 und Paket 5a sind abgenommen. Prüfung des Hosts 17.10. 08:30–08:45: 0 Warnungen, seriell 639/639, parallel 2 von 3 (rot: `directProbeKeepsMainActorResponsive`, Messaufbau). Jetzt Paket 5b, der Abschluss von 0.3.8.

Reihenfolge (verbindlich):
1. `bug.0.3.8.004`: `directProbeKeepsMainActorResponsive` ohne Tick-Zählung umbauen (prüft „nicht auf main“ und „main nicht blockiert“), Sabotage rot ✓; Tests gleicher Bauart nennen.
2. `bug.0.3.8.005`: tote Dateien entfernen – `ScreenshotRunner.swift`, `ScreenshotPlan.swift` samt Aufruf in `AppDelegate` und Hinweis in `SystemNotice`; UI-Testziel `diskindexUITests` (Ordner, Ziel in `project.pbxproj`, Schema); dazu b2): Icon-Werkzeug samt `IconCandidateTests` und `Scripts/GenerateAppIcons.swift`, die Bildschirmfotos in `ToolbarFillTests`/`ColumnLiveRenameTests`, das Messwerkzeug `IndexBenchTests` mit `db-messung*.sh`. `PreviewData.swift`, `audit-repro`, `generate_localizable.py` und `stress_fill_stick.sh` bleiben. Vor jedem Löschen grep; weiterer Bezug → „Frage:“.
3. `bug.0.4.031` a)–c): Klone (nie zwei Pfade für ein Medium), Volume-Umbenennung als eigenes Ereignis samt Watcher-Neustart und `kFSEventStreamCreateFlagWatchRoot`, Rückfrage „Ersetzt dieses Medium?“ (`todo.0.4.032`). Die Textvorschläge in der Aufgabe sind freigegeben; im Status unter „Neue Texte:“ auflisten. Die Rückfrage braucht einen Test mit echtem Fenster außerhalb des Bildschirms (Regel 10/19/21) und Maße aus dem Komponentenkatalog (Regel 13).

Regel 18 gilt für jeden neuen Test: kein Schritt der geprüften Kette von Hand aufrufen; ein Test, der immer grün ist, zählt nicht.

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (`grep "warning:" | grep -v appintents | sort -u | wc -l`, selbst gezählt); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Je Lauf Ergebnis und Uhrzeit in den Status; ein roter Lauf wird genannt, nicht wiederholt, bis er grün ist. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers ohne `-derivedDataPath`, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos, kein Start der echten App. Nur die Felder „Status“ der Aufgaben ändern (höchstens 5 Zeilen). `MARKETING_VERSION` **nicht** ändern (`todo.0.3.8.001` kommt erst nach dem Stick-Test des Nutzers). Nicht anfassen: `bug.0.4.063`, alles in B.

HALT nach Punkt 3. Bericht nach Regel 30: Prompt für den Host (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
