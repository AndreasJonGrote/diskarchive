⚠ Worker – Minimum Sonnet 5.5 Medium (sonst in der ersten Zeile melden und auf Bestätigung warten).

Rolle: **Worker**. Lies `AGENTS.md`, `todo/regeln.md` (verbindlich), `konzept/lauf-lebenszyklus.md` (Abschnitt „Übergabe Lauf → Überwachung“) und `todo/paket-30.md`. Setze **bug.0.4.205** um, nur diese Aufgabe.

- Eine Prüfstelle `mayStartWatching` in `ChangeWatcher` mit den Bedingungen aus K5:
  - Sperre
  - keine Pause
  - Medium bekannt mit „Ja“ und `allowIndexing`
  - angeschlossen
- Alle drei Startwege rufen sie direkt vor `ChangeWatcher.start`, nach ihrem letzten `await`: `LiveWiring.startWatching`, `ChangeWatcher.applyPause` (dort auch die Generation erneut prüfen) und `restartWatchIfConnected`.
- Tests je Weg mit Haken nach dem Lesen und Gegenprobe. Dazu der Fall „nicht mehr angeschlossen“ in `startWatchingChecksTheStateAfterTheRead`.
- Patches `bug.0.4.205-a` bis `-d` wie im Paket beschrieben.

Vor Beginn `df -h /`, mindestens 25 GB müssen frei sein. Builds und Testergebnisse nur in den festen Ordnern unter `$TMPDIR`, am Ende löschen (Regel 13). Rot vor dem Fix belegen (Regel 8). Selbstprüfung (Regel 12). Zum Schluss die App des Nutzers bauen (Regel 14). Gesamtlauf nur bei Last < 3, sonst weglassen und im Status vermerken.

Schreibe nur das Feld „Status“ der Aufgabe (höchstens 5 Zeilen, „Bereit zur Prüfung“). Danach den Bericht nach Regel 15. Ersetze zum Schluss diese Datei durch „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ **HALT.**
