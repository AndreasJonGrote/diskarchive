Rolle: Worker (AGENTS.md). Lies TODO.md (Regeln 1–30, Abschnitt A, Paket 5b). Prüfung des Hosts 17.10. (Commit `91b90a6`): 0 Warnungen, seriell 642/642, parallel 2 von 3 (rot: `StartupSequenceTests/slowOpenKeepsTheMainThreadFreeAndStillRecognisesMedia`, MainActor-Sprung nach 3 s statt < 2 s). Code von `005` und `031` ist richtig. Deine beiden Fragen sind beantwortet. Jetzt die Nacharbeit, jeweils nur die Punkte unter „Nacharbeit (Host 17.10. 10:15)“.

Reihenfolge (verbindlich):
1. `bug.0.4.031`: `rootChanged` beim Abziehen absichern (kein Abgleich, wenn das Medium nicht mehr eingehängt ist; nach Umbenennung genau ein Abgleich unter dem neuen Pfad), mit Tests. Klon allein gesteckt → zuletzt gesehenes Medium verbinden, kein neues anlegen, mit Test.
2. `bug.0.3.8.004`: `directProbeKeepsMainActorResponsive` und `slowOpen…` ohne Zeitvergleich: Tor, das der Test erst nach einem gelungenen MainActor-Sprung öffnet; Notfall-Zeitgrenze nur für den roten Fall. Sabotage rot ✓.
3. `bug.0.3.8.005`: `ScreenshotPlan.swift`, die Testteile nur dafür, `--screenshots` in `SystemNotice` und `ScreenshotContextMenu` entfernen (Antwort auf deine Frage: ja).

Regel 18 gilt für jeden neuen Test: kein Schritt der geprüften Kette von Hand aufrufen; ein Test, der immer grün ist, zählt nicht.

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (selbst gezählt); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Je Lauf Ergebnis und Uhrzeit in den Status; ein roter Lauf wird genannt, nicht wiederholt, bis er grün ist. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers ohne `-derivedDataPath`, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos, kein Start der echten App. Nur die Felder „Status“/„Nacharbeit-Status“ der Aufgaben ändern (höchstens 5 Zeilen). `MARKETING_VERSION` nicht ändern. Nicht anfassen: `bug.0.4.063`, alles in B.

HALT nach Punkt 3. Bericht nach Regel 30: Prompt für den Host (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
