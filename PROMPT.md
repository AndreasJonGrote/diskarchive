⚠ Worker – Minimum Sonnet 5.5 Medium (sonst in der ersten Zeile melden und auf Bestätigung warten).

Rolle: **Worker**. Lies `AGENTS.md`, `todo/regeln.md` (verbindlich), `konzept/lauf-lebenszyklus.md` (Abschnitt „Übergabe Lauf → Überwachung“) und `todo/paket-32.md`. Setze **bug.0.4.207** um, nur diese Aufgabe.

- Ein Stream-Unmount gilt nur für den Stream, der ihn meldet: `start` gibt die Generation des Streams an `ingest` und `handleStreamUnmount` weiter.
- `handleStreamUnmount` prüft sie am Anfang und nach `saveCursor`. Weicht die Generation des Mediums ab, tut es nichts weiter (Protokollzeile).
- Die Generation des Streams ist das `since` des Neustarts.
- Neuer Haken `streamUnmountAfterSaveHookForTesting` (je Instanz) nach `saveCursor`. Dazu drei Tests in `WatchStartCheckTests`: `stop` mit neuem Start, nur `stop`, Gegenprobe zuerst.
- Patches `bug.0.4.207-a` und `-b` wie im Paket beschrieben.
- Die Fenster zwischen `onRunIndexed`/`pauseChanged`/Aufwachen und einem `stopWatcherAndStartIndex` **nicht** schließen (Konzept: bewusst offen).

Vor Beginn `df -h /` (mindestens 25 GB frei). Builds und Testergebnisse nur in den festen Ordnern unter `$TMPDIR`, am Ende löschen (Regel 13). Rot vor dem Fix belegen (Regel 8). Bei 20× parallel zählt ein `Test case … failed` im Protokoll auch dann als rot, wenn das `.xcresult` „Passed“ zeigt. Selbstprüfung (Regel 12). Zum Schluss die App des Nutzers bauen (Regel 14). Gesamtlauf nur bei Last < 3, sonst weglassen und im Status vermerken.

Schreibe nur das Feld „Status“ der Aufgabe (höchstens 5 Zeilen, „Bereit zur Prüfung“), dann den Bericht nach Regel 15. Ersetze zum Schluss diese Datei durch „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ **HALT.**
