Lies TODO.md: Regeln 1–30 und nur Paket 0 (bug.0.4.010, bug.0.4.043, todo.0.4.010, todo.0.4.011, todo.0.4.012).
Reihenfolge: bug.0.4.043 zuerst (Repro-Test rot belegen), dann bug.0.4.010, todo.0.4.010, todo.0.4.011, todo.0.4.012. Zusätzlich die Warnung `notice` in AppState+VersionLock.swift:38 beheben.
Akzeptanz: Build Debug und Release mit 0 Warnungen; drei volle Läufe (einmal seriell, zweimal parallel), alle grün; grep-Prüfung aus todo.0.4.010 leer; Regel 23.
Kein Git außer status/log/diff/show. Status je Aufgabe höchstens 5 Zeilen mit Kennung, „Bereit zur Prüfung“. HALT nach Paket 0.
Beende deine Antwort nach Regel 30: Prompt für Claude im Codeblock und eine Commit-Nachricht.
