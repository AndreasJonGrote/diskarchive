Lies TODO.md: Regeln 1–30, dann nur `todo.0.4.014` (Paket 2a, Nur-Lesen-Nachweis; Konzept in README §9) und aus Paket 3 `bug.0.4.017` und `bug.0.4.018`.
Reihenfolge: todo.0.4.014, bug.0.4.017, bug.0.4.018. Repro-Tests nach Regel 25 (`Werkzeuge/audit-repro/ReproAuditTests.swift`, `nr56_…`, `nr70_…`): Rot vor dem Fix belegen, Sabotage zurücknehmen vor Regel 23. Die Erlaubnisliste des Wächter-Tests (todo.0.4.014) ändert nur Claude: nenne in der Antwort jede Datei, die du aufnehmen willst, mit Grund. Keine neuen sichtbaren Texte.
Parallellauf immer mit: xcodebuild test-without-building … -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120. Dieses Kommando und die Uhrzeiten stehen im Status.
Akzeptanz: Build Debug und Release mit 0 Warnungen; seriell grün; zwei Parallelläufe grün; Regel 23.
Kein Git außer status/log/diff/show. Status je Aufgabe höchstens 5 Zeilen mit Kennung, „Bereit zur Prüfung“. HALT nach bug.0.4.018.
Beende deine Antwort nach Regel 30: Prompt für Claude im Codeblock und eine Commit-Nachricht.
