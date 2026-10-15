Lies TODO.md: Regeln 1–30, dann nur die Nacharbeit zu `todo.0.4.014` (Paket 2a, Abschnitt „Nacharbeit“, Punkte 1–4 und a–d) und aus Paket 3 `bug.0.4.019` und `bug.0.4.020`.
Reihenfolge: todo.0.4.014 (Nacharbeit), bug.0.4.019, bug.0.4.020. Repro-Tests nach Regel 25 (`Werkzeuge/audit-repro/ReproAuditTests.swift`, `nr66_…`, `nr99_…`): Rot vor dem Fix belegen, Sabotage zurücknehmen vor Regel 23. Keine neuen sichtbaren Texte.
Wichtig: Der Debug-Build hat 0 Warnungen **einschließlich Testziel**; Release ebenfalls. Prüfe vor der Meldung selbst mit: grep "warning:" | grep -v appintents | sort -u | wc -l.
Parallellauf immer mit: xcodebuild test-without-building … -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120. Dieses Kommando und die Uhrzeiten stehen im Status.
Akzeptanz: Build Debug und Release mit 0 Warnungen; seriell grün; zwei Parallelläufe grün; Regel 23.
Kein Git außer status/log/diff/show. Status je Aufgabe höchstens 5 Zeilen mit Kennung, „Bereit zur Prüfung“. HALT nach Paket 3.
Beende deine Antwort nach Regel 30: Prompt für Claude im Codeblock und eine Commit-Nachricht.
