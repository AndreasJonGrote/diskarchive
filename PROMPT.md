Rolle: Worker (AGENTS.md). Lies TODO.md (Regeln 1–30, Abschnitt A, Paket 5c). Pakete 4, 5a und 5b sind abgenommen. Prüfung des Hosts 17.10. 12:47–13:02: 0 Warnungen, seriell 643/643, parallel 2 von 3 (rot: `saveCursorWritesOnlyWhenEventIDChanges`, exakter Zählvergleich). In vier Prüfungen wackelte jedes Mal ein anderer zeitabhängiger Test. Jetzt Paket 5c, der letzte Code-Schritt vor 0.3.8.

Reihenfolge (verbindlich):
1. `bug.0.3.8.006`: Zeitgrenze in `DirectMediumAccess.probe` wirklich wirksam machen (einmal fortsetzbare Continuation, Zeitgrenze injizierbar, kein Warten auf den blockierten Aufruf); Test mit hängender Prüfung → `.denied(reason: "timeout")`; Sabotage rot ✓; gleiche Bauart suchen.
2. `bug.0.3.8.007`: `saveCursorWritesOnlyWhenEventIDChanges` als Differenz mit abschaltbarem Cursor-Timer; dann Durchgang über alle Tests mit exakten Zählvergleichen oder kurzen Zeitgrenzen auf asynchrone Abläufe (Liste im Status, Laufzeitgrenzen nicht lockern); `bug.0.4.070`/`071` mit erledigen.

Regel 18 und 20 gelten für jeden geänderten Test. Ein Test, der immer grün ist, zählt nicht; keine Zeitgrenze verlängern, um Grün zu bekommen.

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (selbst gezählt); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Je Lauf Ergebnis und Uhrzeit in den Status; ein roter Lauf wird genannt, nicht wiederholt, bis er grün ist. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers ohne `-derivedDataPath`, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos, kein Start der echten App. Nur die Felder „Status“ der Aufgaben ändern (höchstens 5 Zeilen). `MARKETING_VERSION` nicht ändern. Nicht anfassen: `bug.0.4.063`, alles in B.

HALT nach Punkt 2. Bericht nach Regel 30: Prompt für den Host (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
