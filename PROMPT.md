Rolle: Worker (AGENTS.md). Lies TODO.md (Regeln 1–31, Abschnitt A, Paket 11). Paket 10 ist vom Host abgenommen bis auf `bug.0.4.077` (Prüfung 18.10. 11:02–11:19: 0 Warnungen, seriell 866/866, parallel 3/3; zwei Prüf-Agenten ohne hohen Befund). Zu 077 hat der Nutzer nach der ersten Messung (+20,5 % Zeit, +15,4 % Größe) entschieden: erst den Vergleich beschleunigen, die Größe wird hingenommen. Der übrige Code von 077 (Migration, natürliche Sortierung in SQL, Tests, Messwerkzeug) liegt schon im Repository; siehe Status von 077 in TODO.md. Paket 11 ist das letzte Code-Paket von 0.4.0 (Release-Kandidat).

Reihenfolge (verbindlich):
1. `bug.0.4.077` (Nacharbeit): `NaturalOrder.compare` bzw. die Kollation „natural“ ohne Speicheranlegen je Vergleich (auf UTF-8-Bytes, Zifferngruppen ohne Zwischen-Strings); gleiche Reihenfolge (Gleichwertigkeitstest alt/neu über viele Zufallsnamen inkl. Umlaute/Ziffern); `NaturalSearchOrderTests` unverändert grün; **neu messen** wie vorher (Release, ≥ 1 Mio. Einträge, je 3 Läufe im Wechsel, Median). Abnahme: Indizierzeit höchstens +10 %; sonst „Blockiert: Messung“ mit den neuen Zahlen.
2. `bug.0.4.078`: Schwärzung im Fehlerbericht – `stackLine` nur auf echte Stapelrahmen, alles andere über die normale Schwärzung; Test mit „$S…“-Dateinamen hinter der CRASH-Zeile; Sabotage rot ✓.
3. `bug.0.4.079`: Kürzung behält mindestens die letzten 20 Protokollzeilen, Stapel wird vorher gekürzt; Test ≤ 256 KB und ≥ 20 Zeilen `logTail`.
4. `bug.0.4.080` a)–e): Kleinkram (wartende Starts zusammenfassen + Nachwarten im Test, Reihenfolge beim Entsperren, `flushInFlight`-Generation, Marke bei unbekanntem Medium, Testordner aufräumen).

Regel 31: nach jeder Aufgabe Selbstprüfung mit Subagent, am Ende einmal selbst korrigieren. Laufzeitgrenzen, die bewusst Laufzeit messen, nicht lockern; Regel 18 und 20 für jeden geänderten Test; ein Test, der immer grün ist, zählt nicht.

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (selbst gezählt); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Je Lauf die Zeile `Test run with …` bzw. die roten Tests mit Uhrzeit in den Status; ein roter Lauf wird genannt, nicht wiederholt, bis er grün ist. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers ohne `-derivedDataPath`, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos, kein Start der echten App. Nur die Felder „Status“ der Aufgaben ändern (höchstens 5 Zeilen je Aufgabe). Nicht anfassen: `todo.0.4.020`–`022`, `024`, `040`, `todo.0.4.1.*`, alles in B.

HALT nach Punkt 4. Bericht nach Regel 30: Prompt für den Host (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
