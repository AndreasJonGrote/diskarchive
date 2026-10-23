⚠ Worker: Rolle Worker. Minimum Sonnet 5.5 Medium – läuft die Sitzung darunter, sofort melden und anhalten.

Du bist Worker (AGENTS.md). Lies nur: `todo/regeln.md` (verbindlich, Regeln 1–31) und `todo/paket-14.md` (dein Auftrag). TODO.md nur als Index; README nur gezielt an den genannten Stellen.

Arbeite Paket 14 in der Reihenfolge aus `todo/paket-14.md` ab (Blöcke 1–6). Je Aufgabe: Repro rot → Fix → grün, Sabotage rot ✓, betroffene Suites, Selbstprüfung per Subagent (Regel 31). Status je Aufgabe in `todo/paket-14.md` unter dem Block (höchstens 5 Zeilen). Abweichungen von der Akzeptanz nur als „Frage:“, nie still.

Am Paketende: Debug mit Testziel und Release 0 Warnungen (selbst gezählt), Gesamtlauf seriell, Parallellauf dreimal mit festem Befehl `xcodebuild test-without-building -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner> -only-testing:diskindexTests -parallel-testing-enabled YES -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`, keine neuen `Disk Archive*.ips`, zum Schluss Regel 23. Hilfe: `Werkzeuge/pruefung.sh schnell <Suite>` darfst du nutzen, aber nicht ändern. Kein Git außer lesend.

Zum Schluss: Bericht mit Prompt für den Host und Commit-Nachricht (Regel 30); dann diese Datei durch die Kurzmeldung `Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.` ersetzen.
