⚠ Worker: Rolle Worker. Minimum Sonnet 5.5 Medium – läuft die Sitzung darunter, sofort melden und anhalten.

Du bist Worker (AGENTS.md). Lies nur: `todo/regeln.md` (verbindlich, 15 Regeln; Invarianten in `konzept/architektur.md`) und `todo/paket-19.md` (dein Auftrag). TODO.md nur als Index; Volltexte von Paket 18 bei Bedarf in `archiv/paket-18-abgenommen-2026-10-24.md`.

Arbeite Paket 19 in der Reihenfolge aus `todo/paket-19.md` ab: `bug.0.4.177` (Auswurf mitten im Lauf, zuerst), `178` (roter Parallellauf: erst Ursache klären), `179`, `180`. Je Aufgabe: rot → Fix → grün, Sabotage-Patch nach `todo/sabotage/` (Regel 9), betroffene Suites, Selbstprüfung per Subagent mit den fünf Fragen (Regel 12), mittlere und hohe Befunde vor „Bereit“ beheben. Status je Aufgabe in `todo/paket-19.md` (höchstens 5 Zeilen). Kann ein Test nicht rot werden: „Frage:“, nicht „Bereit“. HALT nach `bug.0.4.180`.

Am Paketende: Debug mit Testziel und Release 0 Warnungen, seriell und dreimal parallel grün (Regel 13), `Werkzeuge/pruefung.sh sabotage` alle rot, keine neuen `Disk Archive*.ips`, zum Schluss die App des Nutzers bauen (Regel 14). Kein Git außer lesend.

Zum Schluss: Bericht mit Prompt für den Host und Commit-Nachricht (Regel 15); dann diese Datei durch die Kurzmeldung `Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.` ersetzen.
