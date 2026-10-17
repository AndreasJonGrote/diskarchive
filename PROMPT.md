Rolle: Worker (AGENTS.md). Lies TODO.md (Regeln 1–30, Abschnitt A). Paket 4 ist abgenommen; von 5a sind `026`, `032`, `033` abgenommen. Prüfung des Hosts 17.10.: seriell 637/637, parallel 3/3 grün, Release 0, aber Debug mit Testziel 4 Warnungen; mehrere Akzeptanztests beweisen nicht, was sie sollen.

Reihenfolge (verbindlich), jeweils nur die Punkte unter „Nacharbeit 3 (Host 17.10. 00:15)“ bzw. in der neuen Aufgabe:
1. `bug.0.3.8.003`: 4 Warnungen auf 0, toten Code entfernen (Symbolliste in der Aufgabe, vorher je Symbol grep).
2. `bug.0.4.030`: Test Tiefe 2 → 5 startet genau einen Abgleich (`fromScratch: false`); Test Scope verkleinert bei laufendem Lauf; `*.tmp`-Test mit laufendem Lauf; `scopeMedium` weg.
3. `bug.0.4.028`: Aufwach-Test über den echten Weg (genau ein Start); Aufwach-Ablauf als Funktion, die AppDelegate und Test aufrufen; Startreihenfolge über `MediumRecognitionStartup.bootstrap`; `WakeCountingAccess` weg oder ohne `lock()` über `await`.
4. `bug.0.4.029`: Bootstrap-Test ohne Aufruf von `pruneIfDue` von Hand; `UserDefaults(suiteName:)!` → `#require`.
5. `bug.0.4.027`: Doppelanfrage über `requestIndex`/Dialog → genau ein Lauf; Sabotage-Schalter `skipClearIndexRequestForTesting` und Dauertest entfernen, Rot einmal im Status belegen.

Regel 18 gilt für jeden neuen Test: kein Schritt der geprüften Kette von Hand aufrufen. Ein Test, der immer grün ist (z. B. `>=` auf denselben Wert), zählt nicht.

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (`grep "warning:" | grep -v appintents | sort -u | wc -l`, selbst gezählt); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Je Lauf Ergebnis und Uhrzeit in den Status. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers ohne `-derivedDataPath`, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos, kein Start der echten App. Nur die Felder „Status“/„Nacharbeit-Status“ der Aufgaben ändern (höchstens 5 Zeilen). Neue sichtbare Texte nur über „Frage:“. Nicht anfassen: Paket 5b (`031`), `bug.0.4.063`, alles in B.

HALT nach Punkt 5. Bericht nach Regel 30: Prompt für den Host (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
