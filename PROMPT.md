Lies TODO.md: Regeln 1–30, dann nur `bug.0.4.045` sowie aus Paket 4 `bug.0.4.021`, `bug.0.4.022` und `bug.0.4.023`.
Reihenfolge: bug.0.4.045, bug.0.4.021, bug.0.4.022 (nimm die Hinweise zu eventInLiveScope, isInsidePackageInterior und urlIsPackage mit hinein), bug.0.4.023. Tests nach Regel 20: nichts darf abstürzen, kein assertionFailure/fatalError in Produktcode, der von Tests absichtlich ausgelöst wird. Keine neuen sichtbaren Texte.
Nach jedem Testlauf: keine neuen `Disk Archive*.ips` in ~/Library/Logs/DiagnosticReports (Ergebnis im Status).
Parallellauf immer mit: xcodebuild test-without-building … -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120. Dieses Kommando und die Uhrzeiten stehen im Status.
Akzeptanz: Build Debug und Release mit 0 Warnungen (einschließlich Testziel; selbst zählen mit grep "warning:" | grep -v appintents | sort -u | wc -l); seriell grün; zwei Parallelläufe grün; Regel 23.
Kein Git außer status/log/diff/show. Status je Aufgabe höchstens 5 Zeilen mit Kennung, „Bereit zur Prüfung“. HALT nach bug.0.4.023.
Beende deine Antwort nach Regel 30: Prompt für Claude im Codeblock und eine Commit-Nachricht.
