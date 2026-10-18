Rolle: Worker (AGENTS.md). Lies TODO.md (Regeln 1–31, Abschnitt A, Paket 9). 0.3.9 ist vom Host abgenommen (Prüfung 18.10. 03:07–03:23: 0 Warnungen, seriell 805/805, parallel 3/3; drei Prüf-Agenten ohne hohen Codefehler). Paket 9 ist der Beginn von 0.4. Deine Fragen zu 053/054/055/058 sind in den Aufgaben 065–067 beantwortet.

Reihenfolge (verbindlich):
1. `todo.0.3.9.001`: `MARKETING_VERSION` auf `0.3.9` (alle Stellen in `project.pbxproj`, Versions-Tests anpassen).
2. `bug.0.4.064`: Notfall-Zeitgeber beim Beenden zuerst antworten bzw. Ausstieg planen, dann protokollieren, nicht dauerhaft; Test mit blockiertem Protokoll.
3. `bug.0.4.065`: „frisch installiert“ nur, wenn bei der ersten API-Antwort noch kein Medium registriert ist; Test für beide Fälle; prozessweiten Schalter im Test nicht zurückschreiben.
4. `bug.0.4.066`: Merker `scanTotalIncomplete` schon zu Beginn des Vorlaufs; Test auf „kein erneutes Indizieren“ umstellen; Halt vor Zählbeginn → nicht 99 %.
5. `bug.0.4.067`: Größenformat wie im Finder (unter 1.000 Byte als Bytes, Null als Ziffer); Tests 0/999/1.500/1,5 GB in de und en; Tests mit festen Gruppentiteln sprachunabhängig.
6. `bug.0.4.068` a)–f): Kleinkram (PauseSpan unbekannt, Ladehinweis-Test, Aushängen-Pfad, `loadUnaligned`, Rauchtest kennzeichnen, Symlinks auf Dateien im FileManager-Weg).
7. `bug.0.4.063`: Nur-Lesen-Sperre stoppt laufende Arbeit (in `LiveWiring` verdrahten: Läufe und Abgleich abbrechen, Watcher stoppen); Test ohne Abbruch-Funktionen von Hand.
8. `todo.0.4.026`: „Für dieses Medium merken“ auswerten.
9. `todo.0.4.027`: abgelaufene Pause beim Start meldet „Medien werden wieder indiziert.“
10. `todo.0.4.028`: Versions-Check nach Kalenderzeit.
11. `todo.0.4.029`: jedes 201 gilt als Erfolg (Screenshot-Teil ist schon erledigt).

Regel 31: nach jeder Aufgabe Selbstprüfung mit Subagent, am Ende einmal selbst korrigieren. Laufzeitgrenzen, die bewusst Laufzeit messen, nicht lockern; Regel 18 und 20 für jeden geänderten Test; ein Test, der immer grün ist, zählt nicht. Absturz- und Signalpfade nur über Funktionsaufrufe testen.

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (selbst gezählt); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Je Lauf die Zeile `Test run with …` bzw. die roten Tests mit Uhrzeit in den Status; ein roter Lauf wird genannt, nicht wiederholt, bis er grün ist. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers ohne `-derivedDataPath`, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos, kein Start der echten App. Nur die Felder „Status“ der Aufgaben ändern (höchstens 5 Zeilen je Aufgabe). Neue sichtbare Texte nur über `L10n`/`LayoutCopy` mit de und en, im Status unter „Neue Texte:“. Nicht anfassen: `todo.0.4.020`–`025`, `040`, alles in B.

HALT nach Punkt 11. Bericht nach Regel 30: Prompt für den Host (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
