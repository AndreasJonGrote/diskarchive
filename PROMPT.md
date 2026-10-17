Rolle: Worker (AGENTS.md). Lies TODO.md (Regeln 1–30, Abschnitt A, Paket 8b). Paket 8a ist abgenommen (Prüfung des Hosts 17.10. 19:37–19:53: 0 Warnungen, seriell 741/741, parallel 3/3; drei Prüf-Agenten ohne hohen Befund). Paket 8b ist das letzte Paket von 0.3.9.

Reihenfolge (verbindlich):
1. `bug.0.3.9.011`: Beenden darf nicht am Hauptthread hängen – Checkpoint und andere synchrone DB-Schritte beim Beenden vom Hauptthread nehmen, Notfall-Zeitgeber unabhängig vom MainActor; Test mit synchron blockierendem Checkpoint.
2. `bug.0.3.9.012`: langsames Volume beim Einhängen nicht verlieren – Wiederholung nach Zeitgrenze (5 s, 15 s, 30 s), höchstens ein Lookup je Pfad; Test „erst hängt, dann antwortet“ → genau ein `.appeared`.
3. `bug.0.3.9.013`: `WriteGuard` ohne prozessweiten Test-Zustand, Test-Funktionen nur in DEBUG.
4. `bug.0.3.9.014` a)–d): Esc im Erkennungs-Dialog, Live-Suche bricht beim Start ab, Wächter-Konstanten aus dem Produktcode, Startwert der Panel-Platzierung.
5. `bug.0.4.050`–`062` in Zahlenfolge: Lösung je REPORT-Nummer im Archiv `archiv/report-audit-2026-10-13.md`. Je Kennung im Status: REPORT-Nummer, geänderte Stelle, Test. Ist ein Fehler durch frühere Pakete schon behoben, mit Beleg (Datei, Zeile, Test) als „erledigt durch …“ melden. Neue sichtbare Texte (`bug.0.4.058`) nur über `L10n`/`LayoutCopy` mit de und en, im Status unter „Neue Texte:“.

Laufzeitgrenzen, die bewusst Laufzeit messen, nicht lockern; eine Grenze, die nur Last misst, aus der Aussage ableiten und begründen. Regel 18 und 20 für jeden geänderten Test; ein Test, der immer grün ist, zählt nicht. Absturz- und Signalpfade nur über Funktionsaufrufe testen.

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (selbst gezählt); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Je Lauf die Zeile `Test run with …` bzw. die roten Tests mit Uhrzeit in den Status; ein roter Lauf wird genannt, nicht wiederholt, bis er grün ist. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers ohne `-derivedDataPath`, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos, kein Start der echten App. Nur die Felder „Status“ der Aufgaben ändern (höchstens 5 Zeilen je Aufgabe). `MARKETING_VERSION` nicht ändern (`todo.0.3.9.001` erst nach Abnahme von 0.3.9). Nicht anfassen: `bug.0.4.063`, alles in B.

HALT nach Punkt 5. Bericht nach Regel 30: Prompt für den Host (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
