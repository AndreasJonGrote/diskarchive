# AGENTS.md — Rollenverteilung Disk Index

Dieses Projekt wird von zwei Agenten bearbeitet. Diese Datei legt verbindlich fest, wer was tut.

## Rollen

### Claude Code — Konzept, Review, Briefing (100%)
Claude Code macht **keine Implementierung** im Xcode-Projekt. Claude ist zuständig für:
- **Konzept**: Produktlogik, Screen-Flows, State-Modelle, Edge Cases aus dem Design-Mockup ([layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html)) und dem Farbkonzept ([layout/Farbschema.dc.html](layout/Farbschema.dc.html)) sauber in umsetzbare Aufgaben übersetzen.
- **Design-Vermittlung**: Farbrollen, Spacing, Icons und Komponentenregeln aus dem Styleguide (Mockup-Sektion 15) und dem Farbkonzept korrekt und vollständig an Cursor weitergeben — inklusive der Feinheiten (Chip-Rezept, gestrichelt = unvollständig, Selectgroup-Regel, Tabellenregel ohne Sortierpfeile, Suchfeld-Reset, Cursor-Regel etc.) und mit exakten sRGB-Werten, wo das Layout OKLCH verwendet — damit nichts davon beim Screenshot-Abtippen verlorengeht.
- **Briefing**: Aufgaben in [TODO.md](TODO.md) so präzise formulieren, dass Cursor sie ohne Rückfragen umsetzen kann (Dateien, Screens, Verhalten, Akzeptanzkriterien).
- **Review**: Nach jeder von Cursor gemeldeten Erledigung prüft Claude den tatsächlichen Code/Diff gegen die Vorgabe in TODO.md und das Design-Spec — nicht nur die Selbstauskunft von Cursor. Claude gibt Freigabe oder fordert Korrektur an.
- **Priorisierung**: Reihenfolge der Screens/Features festlegen, Abhängigkeiten erkennen (z. B. Datenmodell vor UI, Menu-Bar-Grundgerüst vor Popover-Inhalt).

Claude editiert **niemals** Quellcode im Xcode-Projekt selbst. Ausnahme: Pflege von `AGENTS.md` und `TODO.md`.

### Cursor — Umsetzung (100%)
*Ab 10.10. kann diese Rolle auch ein anderer Agent übernehmen (Cursor ohne Guthaben). Alles, was hier und in `TODO.md` für „Cursor“ gilt, gilt dann genauso für ihn.*
Cursor implementiert alle Aufgaben aus `TODO.md` im Xcode-Projekt (SwiftUI/AppKit). Cursor ist zuständig für:
- Den tatsächlichen Code (Views, Models, State, Menu-Bar-Integration, App-Fenster).
- Pixel-genaue Umsetzung der Design-Tokens aus der README mit **nativen Controls** — kein Kopieren von HTML/CSS, aber gleiche Werte (Farben, Radius, Spacing, Icon-Gewichte).
- Nach jeder Aufgabe: nur das Feld „Status“ der Aufgabe in `TODO.md` ausfüllen (höchstens 5 Zeilen) und „Bereit zur Prüfung“ schreiben, nie „fertig“. Es gelten die **Regeln für Cursor** oben in `TODO.md` (verbindlich, haben Vorrang vor Gewohnheiten).

## Git und GitHub (Nutzer 10.10., gilt für beide Agenten)

**Keiner der Agenten macht etwas mit Git oder GitHub, das etwas verändert.** Verboten sind `git commit`, `git commit --amend`, `git push`, `git pull`, `git merge`, `git rebase`, `git reset`, `git checkout`/`git switch`, `git stash`, `git tag`, `git branch -d`, `git worktree`, `git rm`, `git add` sowie jede Aktion auf GitHub (Pull Requests, Issues, Releases, `gh`). Commits und Pushes macht **nur der Nutzer** (GitHub Desktop). Erlaubt sind nur lesende Befehle (`git status`, `git log`, `git diff`, `git show`). Nach einer Abnahme schlägt Claude höchstens eine Commit-Nachricht vor.

## Host, Geräte und Kennungen (Nutzer 14.10.)

- **Claude ist der Host.** Von ihm geht alles aus: Konzept, Aufgaben, Prüfung, Abnahme, DONE.md. Umsetzer (Cursor oder ein anderer Agent) können auf **anderen Geräten** arbeiten und über Git/GitHub (macht nur der Nutzer) zusammenfließen. Eine Abnahme durch den Umsetzer selbst gilt nicht; Claude liest den Code, baut (0 Warnungen), lässt den Gesamtlauf seriell laufen und prüft Regel 23.
- **Zwei Kennungen:** `todo.<Version>.<Nr>` für Aufgaben, `bug.<Version>.<Nr>` für Fehler (Version = Zielversion der Roadmap, Nr dreistellig). Sie stehen in TODO.md, im Status, in Commit-Nachrichten und in DONE.md.
- **Dateien:** `TODO.md` (offen), `DONE.md` (abgenommen), `README.md` (Konzept inkl. Datenbank), `ROADMAP.md` (Versionen), `REPORT.md` (bleibt leer, Fehler gehen direkt als `bug.*` in TODO.md). Alte Fassungen: `archiv/`.

## Workflow

1. Claude schreibt/aktualisiert Aufgaben in `TODO.md` (eine Aufgabe = ein klar abgegrenzter Screen oder Teilschritt).
2. Cursor arbeitet die Aufgaben in `TODO.md` der Reihe nach ab und trägt unter jeder Aufgabe im Feld „Status" ein, was gemacht wurde.
3. Claude liest `TODO.md`, prüft, dass die App in `DerivedData/…/Build/Products/Debug/` jünger ist als die letzte geänderte `.swift`-Datei (TODO Regel 23; sonst baut Claude sie vor dem Nutzertest selbst), prüft den Code gegen Aufgabe + Layout + README. Bei Freigabe verschiebt **nur Claude** die Aufgabe nach `DONE.md` (Register) und den Volltext ins Archiv; sonst schreibt Claude Korrekturen in die Aufgabe.
4. Erst nach Freigabe durch Claude gilt eine Aufgabe als abgeschlossen.

## Quellen der Wahrheit
- **Konzept (aktuell gültig)**: [README.md](README.md) — eine Stelle für alle Produktentscheidungen, nach Thema. Bei Widerspruch zum Layout gilt das Konzept (außer reine Optik). Claude pflegt es bei jeder Entscheidung des Nutzers; überholte werden ersetzt. Älterer Verlauf: [archiv/readme-verlauf-bis-2026-10-02.md](archiv/readme-verlauf-bis-2026-10-02.md).
- **Versionen und Reihenfolge**: README, Abschnitt „Roadmap“ (maßgeblich). [ROADMAP.md](ROADMAP.md) ist die ausführliche Fassung und folgt der README. `TODO.md` A enthält nur die laufende Version, B ist nach Zielversion sortiert.
- **Design (seit 28.09.)**: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html) (Mockup, Sektionen 00–15) und [layout/Farbschema.dc.html](layout/Farbschema.dc.html) (Farbkonzept). Screenshot-Vorlage, nicht Code-Vorlage. Regeln für Mockups: [layout/CLAUDE.md](layout/CLAUDE.md).
- **Komponentenkatalog (Maße, Farben, Zustände):** [layout/Komponenten.dc.html](layout/Komponenten.dc.html), zusammengefasst in [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) (Claude pflegt die Zusammenfassung; bei Widerspruch gilt die Layout-Seite).
- **Erledigt**: [DONE.md](DONE.md) — Register der von Claude abgenommenen Aufgaben (nur Claude pflegt es).
- **Aufgabenliste**: [TODO.md](TODO.md) — nur offene Aufgaben (A. Jetzt) und Backlog (B., Cursor arbeitet nicht daran) plus die verbindlichen Regeln für Cursor. Alte Fassungen und Volltexte: `archiv/prompt-*.md`.
- Archiv (nicht mehr maßgeblich): `archiv/layout-alt/design_handoff_disk_index/` — ursprüngliches Handoff mit alter Screen-Nummerierung.

## Status dieses Projekts
Xcode-Projekt unter `diskindex/` (SwiftUI/AppKit, GRDB/SQLite). Erkennung, Indizierung, Live-Überwachung, Suche, Favoriten, Einstellungen, Fehlerbericht und Menüleiste laufen auf echten Daten. Aktuelle offene Aufgaben: siehe `TODO.md`. Aufbau der Software: README, „Architektur“.
