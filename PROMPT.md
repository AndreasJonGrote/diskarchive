Du bist **Worker** (AGENTS.md). Arbeite **Paket 49** ab: [todo/paket-49.md](todo/paket-49.md), zwei Aufgaben der Reihe nach: `bug.0.4.236` (Einstiegskachel nur mit Medien „Indizieren: Ja“; abgelehnte zeigten „Wird indiziert“; neuer Leertext in de und en) und `bug.0.4.235` (gesperrter Ordner: keine Wiederholung bei „keine Rechte“, Unterordner nicht einzeln lesen).

Regeln: [todo/regeln.md](todo/regeln.md) (verbindlich). Test zuerst rot, dann grün; Sabotage-Patches unter `todo/sabotage/`; nur betroffene Suites per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), immer auch `EnglishLocalizationTests`; kein Gesamtlauf; kein Git; Sprache Deutsch. Kein neues Schema (vorher fragen).

Zum Schluss: Status je Aufgabe im Paket-File (höchstens 5 Zeilen, „Bereit zur Prüfung“), diese Datei durch „Erledigt (Bereit zur Prüfung): … Offen: … HALT“ ersetzen, Bericht mit Commit-Nachricht und Prompt für den Host (Regel 15). **HALT.** Danach ist 0.4.0 Release-Kandidat (Entscheidung des Nutzers).
