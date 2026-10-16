Lies TODO.md (Regeln 1–30, Abschnitt A, Prüfung Claude 16.10. 21:52). Nacharbeit nach der Paketprüfung 4 + 5a. `bug.0.3.8.001` ist abgenommen. Der Parallellauf war 0 von 3 grün (immer dieselben vier Tests); die Meldung „3× parallel grün“ stimmte nicht.

Reihenfolge (verbindlich), jeweils nur die Punkte unter „Nacharbeit 2 (Claude 16.10. 21:52)“ bzw. „Nacharbeit (Claude 16.10. 21:52)“:
1. `bug.0.3.8.002` e)–h): prozessweite Test-Zähler und -Schalter weg (Regel 20), die vier roten Parallel-Tests an der Ursache beheben, Laufzeit des 100k-Bereinigens vor/nach `eb819f7` messen.
2. `bug.0.4.025`: Summenzeile am Ende des Indexlaufs, Test über einen echten Lauf mit 2.000 Ordnern.
3. `bug.0.4.033`: `indexStatus` aus dem Erkennungs-Setter; Beenden synchron mit Zeitgrenze ≤ 1 s oder `.terminateLater`; Test ohne Warten danach; Einstellungen beim Beenden.
4. `bug.0.4.030`: Abgleich statt Neu-Indizieren, nur bei `grows` alle Medien, Abbrechen und Neustart in einem Task; drei Akzeptanztests.
5. `bug.0.4.028`: Doppelaufruf beim Aufwachen, drei Akzeptanztests, Test „erster Lauf nutzt Einstellung aus der DB“, tote Funktion entfernen.
6. `bug.0.4.029`: geplanter Task bis `pruneAt`, zwei Akzeptanztests.
7. `bug.0.4.026`, `bug.0.4.027` (Doppelanfrage-Test, Rot-Beleg `nr60`), `bug.0.4.032` (Akzeptanztest).

Nach jeder Aufgabe die betroffenen Suites seriell. Am Ende: `xcodebuild clean build-for-testing` (Debug mit Testziel) und Release je 0 Warnungen (`grep "warning:" | grep -v appintents | sort -u | wc -l`); serieller Gesamtlauf; Parallellauf dreimal hintereinander mit genau diesem Kommando:
`xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`
Je Lauf die Zeile `Test run with … passed` mit Uhrzeit in den Status. Keine neuen `Disk Archive*.ips`. Zuletzt Regel 23 (App des Nutzers, beide Uhrzeiten).

Kein Git, kein GitHub. Keine UI-Tests, keine Bildschirmfotos, kein Start der echten App. Nur das Feld „Nacharbeit-Status“ der Aufgaben ändern (höchstens 5 Zeilen). Neue sichtbare Texte nur über „Frage:“.

HALT nach Punkt 7. Bericht nach Regel 30: Prompt für Claude (Codeblock, höchstens 12 Zeilen) und Commit-Nachricht (eine Zeile, beginnt mit den Kennungen). Zum Schluss PROMPT.md durch die Kurzmeldung „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen.
