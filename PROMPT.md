Rolle: Worker (AGENTS.md). Lies TODO.md (Regeln 1–30, Abschnitt A, Paket 8a). Paket 7 ist abgenommen (Prüfung des Hosts 17.10. 17:21–17:36: 0 Warnungen, seriell 712/712, parallel 3/3). Der Code wurde je Aufgabe von Prüf-Agenten gelesen; ihre Befunde und die aus Paket 6 bilden Paket 8a.

Reihenfolge (verbindlich):
1. `bug.0.3.9.008`: Wächter-Test wieder eng (Grenze aus der Stillstandszeit, nicht aus der Wiederholungspause); `BulkDirectoryReaderTests`-Messung in die Messgruppe.
2. `bug.0.3.9.009`: Beenden mit Zeitgrenze (Standard 8 s) und Merker gegen doppelten Abschluss.
3. `bug.0.3.9.010`: Absturzschreiber härten (`lock.try()` aus dem Handler, `backtrace` vorab, `O_CLOEXEC`, Nullbytes im Ring).
4. `bug.0.3.9.001`: weitere prozessweite Test-Schalter auf Instanz/`@TaskLocal`.
5. `bug.0.3.9.002`: `VolumeLookup.info` mit Zeitgrenze (Bauart wie `DirectMediumAccess.probe`).
6. `bug.0.3.9.003`: Live-Suche bricht den Nachlauf beim Direktlauf ab.
7. `bug.0.3.9.005`: Tests aus Paket 6 (Verhältnis statt Millisekunden, echte Kette statt eingefrorener Liste, Panel und Esc der Ignorier-Rückfrage, Testlücken).
8. `bug.0.3.9.006`: Favoriten (Zahl gegen Generation, Rücknahme bei Fehler, Task-Liste aufräumen, beim Beenden auf die Schreibkette warten, nachladen nach Abwählen auf voller Seite).
9. `bug.0.3.9.007`: Kleinkram (Dialog-Abstand 12 pt, Prompts beim Schließen zurücksetzen, Fortschritt nach `invalidateAll`, natürliche Sortierung je Medium, Popover-Zählung bei genau 3).

Laufzeitgrenzen, die bewusst Laufzeit messen, werden nicht gelockert; eine Grenze, die nur Last misst, wird aus der Aussage abgeleitet und im Test begründet. Regel 18 und 20 gelten für jeden geänderten Test; ein Test, der immer grün ist, zählt nicht. Absturz- und Signalpfade nur über Funktionsaufrufe testen.

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (selbst gezählt); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Je Lauf die Zeile `Test run with …` bzw. die roten Tests mit Uhrzeit in den Status; ein roter Lauf wird genannt, nicht wiederholt, bis er grün ist. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers ohne `-derivedDataPath`, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos, kein Start der echten App. Nur die Felder „Status“ der Aufgaben ändern (höchstens 5 Zeilen). Nicht anfassen: Paket 8b (`bug.0.4.050`–`062`), `bug.0.4.063`, alles in B.

HALT nach Punkt 9. Bericht nach Regel 30: Prompt für den Host (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
