⚠ Worker – Minimum Sonnet 5.5 Medium (sonst in der ersten Zeile melden und auf Bestätigung warten).

Rolle: **Worker**. Lies `AGENTS.md`, `todo/regeln.md` (verbindlich), `konzept/architektur.md` (Absatz „Speicherung“) und `todo/paket-33.md`. Setze **bug.0.4.208** um (Umbau „ein Ordner“), Schritte a bis e der Reihe nach, nur diese Aufgabe.

- a) Ein Speicher `AppStateStore` statt `UserDefaults` für den App-Zustand. In der App ist das die Datei `app-state.plist` im Datenordner, unter Tests ein Speicher im Speicher. `UserDefaults.standard` steht nur noch in einer Ausnahmedatei (`AppleLanguages`, `NSQuitAlwaysKeepsWindows`). Der Legacy-Import entfällt. Alte Schlüssel entfernt die App einmal beim Start, unter Tests nie.
- b) Kein Test benutzt `UserDefaults`. `AppDefaults` mit dem Aufräumen der Test-Domänen entfällt.
- c) Protokoll und `crash-last.txt` liegen in `Disk Archive/Logs/`.
- d) `WriteGuard` erlaubt nur den Datenordner und `$TMPDIR`.
- e) Wächter-Test über den Quelltext und Rundlauf der Datei; Patches `bug.0.4.208-a` bis `-d` wie im Paket.

**Abnahmekriterium:** Nach einem Gesamtlauf gibt es keine neue Datei `app.diskarchive.tests.*` in `~/Library/Preferences`. Belege das im Status mit einer Startmarke und `find -newer`.

Vor Beginn `df -h /` (mindestens 25 GB frei). Builds und Testergebnisse nur in den festen Ordnern unter `$TMPDIR`, am Ende löschen (Regel 13). Rot vor dem Fix belegen (Regel 8). Bei 20× parallel zählt ein `Test case … failed` im Protokoll auch dann als rot, wenn das `.xcresult` „Passed“ zeigt. Selbstprüfung (Regel 12). Zum Schluss die App des Nutzers bauen und kurz starten (Regel 14): `app-state.plist` und `Logs/` entstehen im Datenordner. Gesamtlauf nur bei Last < 3, sonst weglassen und im Status vermerken.

Schreibe nur das Feld „Status“ der Aufgabe (höchstens 5 Zeilen, „Bereit zur Prüfung“), dann den Bericht nach Regel 15. Ersetze zum Schluss diese Datei durch „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ **HALT.**
