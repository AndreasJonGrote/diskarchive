⚠ Worker – Minimum Sonnet 5.5 Medium (sonst in der ersten Zeile melden und auf Bestätigung warten).

Rolle: **Worker**. Lies `AGENTS.md`, `todo/regeln.md` (verbindlich), `konzept/lauf-lebenszyklus.md` (Abschnitt „Übergabe Lauf → Überwachung“) und `todo/paket-31.md`. Setze **bug.0.4.206** um, nur diese Aufgabe.

- Jeder der drei Startwege der Überwachung merkt sich **vor** seinem ersten `await` die Generation des Mediums (`watchGenerations`): `LiveWiring.startWatching`, `applyPause` und `restartWatchIfConnected`.
- `mayStartWatching` lehnt ab, wenn sich die Generation seitdem geändert hat. Ein `stop` oder `start` im Lesefenster gewinnt.
- Gestartet wird mit dem aktuellen Volume.
- Tests je Weg: im Haken nach dem Lesen `watcher.stop(id)`, Erwartung „keine Überwachung“, mit Gegenprobe. Dazu `applyPause` mit dem Fall „nicht mehr angeschlossen“.
- Patches `bug.0.4.206-a` bis `-c` wie im Paket beschrieben.

Vor Beginn `df -h /` (mindestens 25 GB frei). Builds und Testergebnisse nur in den festen Ordnern unter `$TMPDIR`, am Ende löschen (Regel 13). Rot vor dem Fix belegen (Regel 8). Selbstprüfung (Regel 12). Zum Schluss die App des Nutzers bauen (Regel 14). Gesamtlauf nur bei Last < 3, sonst weglassen und im Status vermerken.

Schreibe nur das Feld „Status“ der Aufgabe (höchstens 5 Zeilen, „Bereit zur Prüfung“), dann den Bericht nach Regel 15. Ersetze zum Schluss diese Datei durch „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ **HALT.**
