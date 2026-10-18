Rolle: Worker (AGENTS.md). Lies TODO.md (Regeln 1–31, Abschnitt A, Paket 10). Paket 9 ist vom Host abgenommen (Prüfung 18.10. 09:20–09:37: 0 Warnungen, seriell 840/840, parallel 3/3, App 0.3.9; drei Prüf-Agenten ohne hohen Befund). Deine Frage zu 026 und der Hinweis zu 065 sind in den Aufgaben 072 und 075 beantwortet.

Reihenfolge (verbindlich):
1. `bug.0.4.072`: „frisch installiert“ zählt nur indizierte Medien (`firstIndexedAt IS NOT NULL`); Tests mit nur angestecktem Stick (sofortige Sperre) und indiziertem Medium (7 Tage), Medium über den echten Weg angelegt.
2. `bug.0.4.073`: nach dem Entsperren unterbrochene Abgleiche nachholen; Test über die echte Kette; eigener Test für `stopAllForVersionLock`.
3. `bug.0.4.074`: lokale Sperr-Auswertung beim Start wieder synchron vor der Erkennung, nur das Einreihen asynchron; Test „gesperrt in der DB → kein Lauf, kein Schreiben“; altes `enqueueCheckIfNeeded`/`enqueueCooldown`/`globalLastVersionCheckEnqueue` entfernen, Tests auf `enqueueCheckIfDue`.
4. `bug.0.4.075`: Änderung der Entscheidung in 05/06 setzt `rememberDecision = true`; Tests ohne Handaufruf von `completeNewMediumDecision`.
5. `bug.0.4.076` a)–d): Kleinkram (Einzahl im Größenformat-Test, `>= 2` in `SlowVolumeMountTests`, Startreihenfolge im Pausen-Test, Flush-Reste nach Sperre).
6. `bug.0.4.077`: natürliche Namensordnung über die Seitengrenze – neuer Index `items_search_natural` als eigene neue Migration, Sortierung nach Name und Medium in SQL natürlich, Nachsortieren in der Seite entfällt; Tests (Rechnung 1…600, Plan ohne TEMP B-TREE), Sabotage rot ✓. **Messung im Release-Build vorher/nachher** (≥ 1 Mio. Einträge synthetisch über den Store: Indizierdauer und DB-Größe); über 10 % Dauer oder 15 % Größe → „Blockiert: Messung“ statt weitermachen.
7. `todo.0.4.023`: Fehlerbericht mit echten Protokollzeilen testen.

Ziel des Pakets (Nutzer 18.10.): 0.4.0 ist der Release-Kandidat der Open Beta – nur, was die App fehlerfrei macht. `todo.0.4.024` (Update durch Ersetzen) gehört zu 0.4.1 und ist **nicht** Teil dieses Pakets; `025` entfällt.

Regel 31: nach jeder Aufgabe Selbstprüfung mit Subagent, am Ende einmal selbst korrigieren. Laufzeitgrenzen, die bewusst Laufzeit messen, nicht lockern; Regel 18 und 20 für jeden geänderten Test; ein Test, der immer grün ist, zählt nicht. Absturz- und Signalpfade nur über Funktionsaufrufe testen. Kein Start der echten App.

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (selbst gezählt); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Je Lauf die Zeile `Test run with …` bzw. die roten Tests mit Uhrzeit in den Status; ein roter Lauf wird genannt, nicht wiederholt, bis er grün ist. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers ohne `-derivedDataPath`, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos. Nur die Felder „Status“ der Aufgaben ändern (höchstens 5 Zeilen je Aufgabe). Nicht anfassen: `todo.0.4.020`–`022`, `024`, `025`, `040`, `todo.0.4.1.*`, alles in B.

HALT nach Punkt 7. Bericht nach Regel 30: Prompt für den Host (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
