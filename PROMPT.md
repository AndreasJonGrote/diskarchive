Rolle: Worker (AGENTS.md). Lies TODO.md (Regeln 1–30, Abschnitt A, Paket 7). Paket 6 ist abgenommen, die App meldet 0.3.8. Prüfung des Hosts 17.10. 15:47–16:03: 0 Warnungen, seriell 698/698, aber **parallel 0 von 3** (beim Host; rot: `pauseDuringFirstChunkAvoidsReadRetries` zweimal, `versionLockCancelClearsIndexingStatus` einmal – alte Tests mit festen Zeitgrenzen unter der neuen Last von Paket 6). Deine Meldung „parallel 3× grün“ ließ sich beim Host nicht wiederholen.

Reihenfolge (verbindlich):
1. `bug.0.3.9.004`: die beiden Tests an der Ursache beheben (a: Grenze aus der Wiederholungspause bzw. Zähler statt 2 s; b: Lauf am Tor halten statt Rennen); Messtests aus Paket 6 in einer `.serialized`-Gruppe bündeln, damit sie sich parallel nicht gegenseitig ausbremsen. Keine Grenze lockern, die Laufzeit misst.
2. `bug.0.4.041`: Absturzschreiber signalsicher (vorab angelegte Puffer, `writeRing` öffnet nie selbst, `crash-last.txt` sofort neu, kein `sync` auf die eigene Queue im Absturzpfad), Ringzeilen UTF-8-sicher.
3. `bug.0.4.042`: Einzelinstanz vor Protokoll; bei Übergabe beim Beenden nichts protokollieren und nichts abbauen (`applicationShouldTerminate`); `O_APPEND`; SIGTERM über `DispatchSource` → `NSApp.terminate`. **Kein echtes SIGTERM an den Testprozess** (Regel 20), stattdessen injizierbare Signalquelle.

Regel 18 und 20 gelten für jeden neuen Test; ein Test, der immer grün ist, zählt nicht. Absturzpfade nur über Funktionsaufrufe testen, nie einen echten Absturz oder ein echtes Signal auslösen (Regel 19/20, keine `.ips`).

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (selbst gezählt); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Je Lauf die Zeile `Test run with …` bzw. die roten Tests mit Uhrzeit in den Status; ein roter Lauf wird genannt, nicht wiederholt, bis er grün ist. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers ohne `-derivedDataPath`, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos, kein Start der echten App. Nur die Felder „Status“ der Aufgaben ändern (höchstens 5 Zeilen). Nicht anfassen: Paket 8, `bug.0.4.063`, alles in B.

HALT nach Punkt 3. Bericht nach Regel 30: Prompt für den Host (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
