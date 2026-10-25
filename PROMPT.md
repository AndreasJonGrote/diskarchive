Rolle: **Worker**. Arbeite **Paket 27** ab: [todo/paket-27.md](todo/paket-27.md), nur `bug.0.4.202` (a–e): Merker des Laufs an das Token binden, keine Überwachung nach Aushängen am Laufende, `cancel` vor dem Lesen des Speichers, Patch 201-b teilen, Pausenzweig beim Anschließen testen. Regeln: `todo/regeln.md` (verbindlich).

Test vorher rot belegen, je Teil ein Sabotage-Patch unter `todo/sabotage/` (alle rot), Selbstprüfung nach Regel 12. Paketende: 0 Warnungen Debug und Release, betroffene Tests grün (Rennen-Tests 20× parallel), App des Nutzers gebaut. Gesamtlauf nur auf ruhigem Rechner (Last < 3, keine Spiele), sonst weglassen und im Status vermerken.

Zum Schluss: nur das Feld „Status“ im Paket-File füllen (höchstens 5 Zeilen, „Bereit zur Prüfung“) und diese Datei durch „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ ersetzen (höchstens drei Zeilen). Kein Git.
