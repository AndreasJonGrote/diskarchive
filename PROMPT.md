⚠ Worker – Minimum Sonnet 5.5 Medium (sonst in der ersten Zeile melden und auf Bestätigung warten).

Rolle: **Worker**. Lies `AGENTS.md`, `todo/regeln.md` (verbindlich) und in `todo/paket-29.md` den Abschnitt bug.0.4.204 mit **„Korrektur 1 (Host 26.10.)“**. Setze **K1–K5** um, in dieser Reihenfolge, und nur diese.

- **K1:** `IndexingWiringTests/forgetStopsWatcherAndCoordinatorMapping` ist im Gesamtlauf jedes Mal rot. Der Test hing am alten 20-ms-Abfragen in `waitUntilIdle`. Repariere nur den Test: auf die Bedingung warten. Das Produkt bleibt unverändert. Prüfe die übrigen Stellen mit `waitUntilIdle` auf dasselbe Muster und nenne die Fundstellen.
- **K2:** „Nein“ während `finish` zeigt Hinweis und Mitteilung. Fix: `decision == .index && allowIndexing` in der Hinweis-Bedingung. Dazu ein neuer Test mit einem Lauf, der einen Hinweis hätte (keine stille Lücke), geprüft im `finishDecisionHookForTesting`, mit Gegenprobe. Patch `bug.0.4.204-k2.patch`.
- **K3:** nur der Kommentar an `watchHandedOn` (Nachhol-Abgleich: bewusst „so lassen“).
- **K4:** ein Test „zwei Starts im Abschluss (einer von vorn) → genau ein Lauf, von vorn“. Patch `bug.0.4.204-k4.patch`.
- **K5 (Supervisor):** `LiveWiring.startWatching` prüft Sperre und Pause nur vor dem `await` auf den Speicher. Vergessen, Nein oder Pause in diesem Fenster → die Überwachung startet trotzdem. Fix: direkt vor `watcher.start` gegen den aktuellen `AppState` prüfen (Sperre, Pause, Medium bekannt mit Ja und `allowIndexing`, angeschlossen). Test mit Haken nach dem Lesen, je Fall, mit Gegenprobe. Patch `bug.0.4.204-k5.patch`.

Vor Beginn `df -h /` (mindestens 25 GB frei). Builds und Testergebnisse nur in den festen Ordnern unter `$TMPDIR`, am Ende löschen (Regel 13). Rot vor dem Fix belegen (Regel 8). Selbstprüfung (Regel 12). Zum Schluss die App des Nutzers bauen (Regel 14). Gesamtlauf nur bei Last < 3, sonst weglassen und im Status vermerken.

Schreibe nur das Feld „Status“ unter „Korrektur 1“ (höchstens 5 Zeilen, „Bereit zur Prüfung“). Dann folgt der Bericht nach Regel 15. Ersetze zum Schluss diese Datei durch „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ **HALT.**
