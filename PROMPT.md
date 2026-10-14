Lies TODO.md: Regeln 1–30, dann nur `bug.0.4.044` (Paket 0, Rest) und Paket 1 (`bug.0.4.011`, `bug.0.4.012`).
Reihenfolge: bug.0.4.044, bug.0.4.011, bug.0.4.012. Repro-Tests nach Regel 25: Rot vor dem Fix belegen, Sabotage zurücknehmen vor Regel 23.
Parallellauf immer mit: xcodebuild test-without-building … -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120. Dieses Kommando und die Uhrzeiten stehen im Status.
Akzeptanz: Build Debug und Release mit 0 Warnungen; seriell grün; drei Parallelläufe grün; Regel 23.
Kein Git außer status/log/diff/show. Status je Aufgabe höchstens 5 Zeilen mit Kennung, „Bereit zur Prüfung“. HALT nach Paket 1.
Beende deine Antwort nach Regel 30: Prompt für Claude im Codeblock und eine Commit-Nachricht.
