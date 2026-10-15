Lies TODO.md: Regeln 1–30, dann nur `todo.0.4.013` (Paket 0, Rest) sowie aus Paket 2 `bug.0.4.013` und `bug.0.4.014`.
Reihenfolge: todo.0.4.013, bug.0.4.013 (Schutz vor Rückschritt in derselben Lieferung wie der Teilindex), bug.0.4.014. Repro-Tests nach Regel 25 (`Werkzeuge/audit-repro/ReproAuditTests.swift`, `nr58_…`, `nr59_…`, `nr67_…`): Rot vor dem Fix belegen, Sabotage zurücknehmen vor Regel 23.
Parallellauf immer mit: xcodebuild test-without-building … -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120. Dieses Kommando und die Uhrzeiten stehen im Status.
Akzeptanz: Build Debug und Release mit 0 Warnungen; seriell grün; zwei Parallelläufe grün; Regel 23.
Kein Git außer status/log/diff/show. Status je Aufgabe höchstens 5 Zeilen mit Kennung, „Bereit zur Prüfung“. HALT nach bug.0.4.014.
Beende deine Antwort nach Regel 30: Prompt für Claude im Codeblock und eine Commit-Nachricht.
