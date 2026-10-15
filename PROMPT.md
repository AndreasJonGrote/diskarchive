Lies TODO.md: Regeln 1–30, dann nur Paket 2, Rest: `bug.0.4.015` und `bug.0.4.016`.
Reihenfolge: bug.0.4.015 (FAT/exFAT/NTFS: Umbenennen/Verschieben außerhalb verbinden), danach bug.0.4.016 (fileID-Zweig, Tiefe der Kinder, Reihenfolge, Hardlinks). Repro-Tests nach Regel 25 (`Werkzeuge/audit-repro/ReproAuditTests.swift`, `nr57_…`, `nr69_…`): Rot vor dem Fix belegen, Sabotage zurücknehmen vor Regel 23. Tests mit echten Läufen über `DirectoryIndexer` und `MemoryVolume` (Regel 18).
Zu bug.0.4.016 d (Hardlinks): Offsets in `BulkDirectoryReader` immer um die Attributgröße erhöhen (Archiv-Report Nr. 96). Keine neuen sichtbaren Texte.
Parallellauf immer mit: xcodebuild test-without-building … -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120. Dieses Kommando und die Uhrzeiten stehen im Status.
Akzeptanz: Build Debug und Release mit 0 Warnungen; seriell grün; zwei Parallelläufe grün; Regel 23.
Kein Git außer status/log/diff/show. Status je Aufgabe höchstens 5 Zeilen mit Kennung, „Bereit zur Prüfung“. HALT nach Paket 2.
Beende deine Antwort nach Regel 30: Prompt für Claude im Codeblock und eine Commit-Nachricht.
