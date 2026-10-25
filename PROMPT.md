Rolle: **Worker**. Arbeite **Paket 28** ab: [todo/paket-28.md](todo/paket-28.md), nur `bug.0.4.203` (a–d): nach `runs[id] = nil` verändert ein altes `finish` nichts mehr, was einem neuen Lauf gehört (Sperre, Anforderung, Anzeige); `cancel` liest bei unbestätigter Art immer den Speicher; Test für den Zweig `!finishedRun`; wackliger Lesefehler-Zähler im Test. Regeln: `todo/regeln.md` (verbindlich).

Test vorher rot belegen, je Teil ein Sabotage-Patch unter `todo/sabotage/` (alle rot), Selbstprüfung nach Regel 12. Paketende: 0 Warnungen Debug und Release, betroffene Tests grün (Rennen-Tests 20× parallel), App des Nutzers gebaut. Gesamtlauf nur auf ruhigem Rechner (Last < 3, keine Spiele), sonst weglassen und im Status vermerken.

Zum Schluss: nur das Feld „Status“ im Paket-File füllen (höchstens 5 Zeilen, „Bereit zur Prüfung“) und diese Datei durch „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen (höchstens drei Zeilen). Kein Git.
