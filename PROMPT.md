⚠ Worker – Minimum Sonnet 5.5 Medium (sonst in der ersten Zeile melden und auf Bestätigung warten).

Rolle: **Worker**. Lies `AGENTS.md` (Abschnitt „Befunde: drei Stufen“), `todo/regeln.md` (verbindlich), `konzept/indizieren.md` („Fortschritt“ und „Eine Rechnung“), `konzept/medien.md` (Punkt 3, „Fokus einmal beim Erscheinen“) und `todo/paket-34.md`. Setze **bug.0.4.210** um, danach **bug.0.4.209 + bug.0.4.216** als eine Aufgabe.

- **210:**
  - Eine reine Funktion berechnet den angezeigten Fortschritt, alle Anzeigen nutzen nur sie.
  - Zähler = gespeicherte Einträge, nichts doppelt. Bei „Neu indizieren“ zählt nur dieser Lauf.
  - In der Zählphase gilt der gespeicherte Wert.
  - 100 % nur bei „indiziert“; „Fehler“ mit Lücke bleibt 99 %.
  - Tabellentest mit den fünf Fällen des Nutzers plus „Fehler mit Lücke“.
  - Gegenproben: Abbruch, „Neu indizieren“, zweites Medium gleichzeitig.
  - **Lebenszyklus und Ablauf von `IndexingService` bleiben unverändert**; wenn nötig „Frage:“ und HALT.
- **209 + 216:**
  - Eine Änderung in `syncNewMediumPanels`: Die Lage aller Panels wird bei jedem Abgleich neu berechnet.
  - Fokus nur, wenn ein Panel neu erscheint.
  - Kein `.floating` bei den vier Panels, die in der Tabelle im Paket stehen.
- Patches `bug.0.4.210-a` bis `-d`, `bug.0.4.209-a`/`-b`, `bug.0.4.216-a` wie im Paket.

Vor Beginn `df -h /` (mindestens 25 GB frei). Builds und Testergebnisse nur in den festen Ordnern unter `$TMPDIR`, am Ende löschen (Regel 13). Rot vor dem Fix belegen (Regel 8). Bei 20× parallel zählt ein `Test case … failed` im Protokoll auch dann als rot, wenn das `.xcresult` „Passed“ zeigt. Selbstprüfung mit den drei Stufen (Regel 12). Zum Schluss die App des Nutzers bauen (Regel 14). Gesamtlauf nur bei Last < 3, sonst weglassen und im Status vermerken.

Schreibe nur die Felder „Status“ (je höchstens 5 Zeilen, „Bereit zur Prüfung“), dann den Bericht nach Regel 15. Ersetze zum Schluss diese Datei durch „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“ **HALT.**
