Rolle: Worker (AGENTS.md). Lies TODO.md (Regeln 1–30, Abschnitt A, Paket 6). 0.3.8 ist vom Host abgenommen (Prüfung 17.10. 13:49–14:03: 0 Warnungen, seriell 645/645, parallel 3/3). Jetzt beginnt 0.3.9 mit Paket 6 (Oberfläche).

Reihenfolge (verbindlich):
1. `todo.0.3.8.001`: `MARKETING_VERSION` auf `0.3.8` (alle Stellen in `project.pbxproj`, Versions-Tests anpassen).
2. `bug.0.4.034`: Spaltenansicht „wird indiziert“ (Zustand einmal je Zeile, Scan-Tiefe → `.uncaptured(.scanDepth)`).
3. `bug.0.4.035`: ⌘A in großen Ordnern ohne quadratischen Aufwand; Rückfrage ab 500 Zielen (Textvorschlag freigegeben, unter „Neue Texte:“ auflisten).
4. `bug.0.4.036`: Spalten-Cache verdrängt keine sichtbaren Spalten; `replaceStore` erhöht Generationen.
5. `bug.0.4.037`: Favorit und Online-Status in Listen aktuell.
6. `bug.0.4.038`: Suche sortiert und gruppiert über alle Treffer, nicht nur die erste Seite.
7. `bug.0.4.039`: Popover-Suche entprellen und abbrechen.
8. `bug.0.4.040`: Favoriten-Tabelle lazy und seitenweise.

Für jede Aufgabe, die Ansichten berührt: Test mit echtem Fenster außerhalb des Bildschirms (Regel 10/19/21), Maße aus dem Komponentenkatalog (Regel 13), Zeile in `RegressionSmokeTests` (Regel 11). Messungen (< 50 ms, < 300 ms) im Status mit Zahl. Regel 18 und 20 gelten für jeden neuen Test; ein Test, der immer grün ist, zählt nicht; keine Zeitgrenze verlängern, um Grün zu bekommen.

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (selbst gezählt); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Je Lauf Ergebnis und Uhrzeit in den Status; ein roter Lauf wird genannt, nicht wiederholt, bis er grün ist. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers ohne `-derivedDataPath`, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos, kein Start der echten App. Nur die Felder „Status“ der Aufgaben ändern (höchstens 5 Zeilen). Nicht anfassen: Pakete 7 und 8, `bug.0.4.063`, alles in B.

HALT nach Punkt 8. Bericht nach Regel 30: Prompt für den Host (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
