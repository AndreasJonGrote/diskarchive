# AGENTS.md — Rollenverteilung Disk Index

Dieses Projekt wird von Agenten in zwei Rollen bearbeitet: **Host** und **Worker**. Diese Datei legt verbindlich fest, wer was tut.

## Rollen (Nutzer 17.10.: Rolle kommt aus der Übergabe, nicht aus dem Namen)

**Der Nutzer sagt jedem Agenten bei der Übergabe seine Rolle: „Host“ oder „Worker“.** Welcher Agent es ist (Claude, Cursor oder ein anderer), spielt keine Rolle; es gilt nur die zugewiesene Rolle. Ein Agent hat in einer Sitzung genau eine Rolle und wechselt sie nicht von selbst. Ohne Angabe fragt er nach, bevor er etwas ändert. Wo in diesem Projekt (TODO.md, Archiv, alte Commits) „Claude“ für die Prüfung oder „Cursor“ bzw. „Umsetzer“ für die Umsetzung steht, ist **Host** bzw. **Worker** gemeint.

### Host — Konzept, Review, Briefing
Der Host macht **keine Implementierung** im Xcode-Projekt. Er ist zuständig für:
- **Konzept**: Produktlogik, Screen-Flows, State-Modelle, Edge Cases aus dem Design-Mockup ([layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html)) und dem Farbkonzept ([layout/Farbschema.dc.html](layout/Farbschema.dc.html)) sauber in umsetzbare Aufgaben übersetzen.
- **Design-Vermittlung**: Farbrollen, Spacing, Icons und Komponentenregeln aus dem Styleguide (Mockup-Sektion 15) und dem Farbkonzept korrekt und vollständig an den Worker weitergeben — inklusive der Feinheiten (Chip-Rezept, gestrichelt = unvollständig, Selectgroup-Regel, Tabellenregel ohne Sortierpfeile, Suchfeld-Reset, Cursor-Regel etc.) und mit exakten sRGB-Werten, wo das Layout OKLCH verwendet — damit nichts davon beim Screenshot-Abtippen verlorengeht.
- **Briefing**: Aufgaben in [TODO.md](TODO.md) und den Auftrag in [PROMPT.md](PROMPT.md) so präzise formulieren, dass der Worker sie ohne Rückfragen umsetzen kann (Dateien, Screens, Verhalten, Akzeptanzkriterien).
- **Review**: Nach jeder gemeldeten Erledigung prüft der Host den tatsächlichen Code/Diff gegen die Vorgabe in TODO.md und das Design-Spec — nicht nur die Selbstauskunft des Workers. Er gibt Freigabe oder fordert Korrektur an.
- **Priorisierung**: Reihenfolge der Screens/Features festlegen, Abhängigkeiten erkennen (z. B. Datenmodell vor UI, Menu-Bar-Grundgerüst vor Popover-Inhalt).

Der Host editiert **niemals** Quellcode im Xcode-Projekt. Er pflegt `AGENTS.md`, `TODO.md`, `PROMPT.md`, `DONE.md`, `README.md`, `ROADMAP.md` und `archiv/`.

### Worker — Umsetzung
Der Worker implementiert die freigegebenen Aufgaben aus `TODO.md` bzw. den Auftrag in `PROMPT.md` im Xcode-Projekt (SwiftUI/AppKit). Das gilt für jeden Agenten in dieser Rolle, auch für Claude. Er ist zuständig für:
- Den tatsächlichen Code (Views, Models, State, Menu-Bar-Integration, App-Fenster).
- Pixel-genaue Umsetzung der Design-Tokens aus der README mit **nativen Controls** — kein Kopieren von HTML/CSS, aber gleiche Werte (Farben, Radius, Spacing, Icon-Gewichte).
- Nach jeder Aufgabe: nur das Feld „Status“ der Aufgabe in `TODO.md` ausfüllen (höchstens 5 Zeilen) und „Bereit zur Prüfung“ schreiben, nie „fertig“. Es gelten die **Regeln für den Worker** oben in `TODO.md` (verbindlich, haben Vorrang vor Gewohnheiten).
- Der Worker nimmt nie selbst ab, pflegt weder DONE.md noch Konzept- oder Regeldateien und schreibt keine Aufgaben.

## Git und GitHub (Nutzer 10.10., gilt für Host und Worker)

**Keiner der Agenten macht etwas mit Git oder GitHub, das etwas verändert.** Verboten sind `git commit`, `git commit --amend`, `git push`, `git pull`, `git merge`, `git rebase`, `git reset`, `git checkout`/`git switch`, `git stash`, `git tag`, `git branch -d`, `git worktree`, `git rm`, `git add` sowie jede Aktion auf GitHub (Pull Requests, Issues, Releases, `gh`). Commits und Pushes macht **nur der Nutzer** (GitHub Desktop). Erlaubt sind nur lesende Befehle (`git status`, `git log`, `git diff`, `git show`). Nach einer Abnahme schlägt der Host höchstens eine Commit-Nachricht vor.

## Host, Geräte und Kennungen (Nutzer 14.10.)

- **Vom Host geht alles aus:** Konzept, Aufgaben, Prüfung, Abnahme, DONE.md. Worker können auf **anderen Geräten** arbeiten und über Git/GitHub (macht nur der Nutzer) zusammenfließen. Eine Abnahme durch den Worker selbst gilt nicht; der Host liest den Code, baut (0 Warnungen), lässt den Gesamtlauf seriell und parallel laufen und prüft Regel 23.
- **Zwei Kennungen:** `todo.<Version>.<Nr>` für Aufgaben, `bug.<Version>.<Nr>` für Fehler (Version = Zielversion der Roadmap, Nr dreistellig; Ausnahme: die bis 16.10. vergebenen `bug.0.4.xxx` behalten ihre Nummer, maßgeblich ist die Spalte „Zielversion“ in TODO.md). Sie stehen in TODO.md, im Status, in Commit-Nachrichten und in DONE.md.
- **Übergabe:** `PROMPT.md` enthält **nur** den aktuellen Prompt für den Worker (nur der Host schreibt ihn); der Worker ersetzt ihn zum Schluss durch eine Kurzmeldung „Erledigt: … Offen: … HALT“ (höchstens drei Zeilen). Jede Antwort im Chat endet mit einer **Commit-Nachricht**; jeder Bericht des Workers zusätzlich mit einem Prompt für den Host (Aufbau: TODO.md Regel 30). Committen tut nur der Nutzer.
- **Dateien:** `PROMPT.md` (aktueller Prompt), `TODO.md` (offen), `DONE.md` (abgenommen), `README.md` (Konzept inkl. Datenbank), `ROADMAP.md` (Versionen), `REPORT.md` (bleibt leer, Fehler gehen direkt als `bug.*` in TODO.md). Alte Fassungen: `archiv/`. **Abnahme-Ablauf des Hosts** (Befehle, Reihenfolge, Pflege der Dateien): `archiv/abnahme-ablauf.md` — zu Beginn eines neuen Chats lesen.

## Übergabe an einen neuen Host oder Rechner (Nutzer 18.10.)

Liegt im Hauptverzeichnis eine **`UEBERGABE.md`**, liest jeder neue Host sie **zuerst**, prüft sie gegen das Repository, übernimmt den Stand und **löscht sie dann** (der Nutzer committet die Löschung). Der übergebende Host schreibt sie und nennt sie in der Commit-Beschreibung. Dauerhaftes Wissen gehört nie nur in diese Datei, sondern in AGENTS.md, TODO.md, `archiv/abnahme-ablauf.md`, README oder ROADMAP.

## Workflow

1. Der Host schreibt/aktualisiert Aufgaben in `TODO.md` (eine Aufgabe = ein klar abgegrenzter Screen oder Teilschritt).
2. Der Worker arbeitet die Aufgaben in `TODO.md` der Reihe nach ab und trägt unter jeder Aufgabe im Feld „Status" ein, was gemacht wurde.
3. Der Host liest `TODO.md`, prüft, dass die App in `DerivedData/…/Build/Products/Debug/` jünger ist als die letzte geänderte `.swift`-Datei (TODO Regel 23; sonst baut der Host sie vor dem Nutzertest selbst), prüft den Code gegen Aufgabe + Layout + README. Bei Freigabe verschiebt **nur der Host** die Aufgabe nach `DONE.md` (Register) und den Volltext ins Archiv; sonst schreibt der Host Korrekturen in die Aufgabe.
4. Erst nach Freigabe durch den Host gilt eine Aufgabe als abgeschlossen.

## Quellen der Wahrheit
- **Konzept (aktuell gültig)**: [README.md](README.md) — eine Stelle für alle Produktentscheidungen, nach Thema. Bei Widerspruch zum Layout gilt das Konzept (außer reine Optik). Der Host pflegt es bei jeder Entscheidung des Nutzers; überholte werden ersetzt. Älterer Verlauf: [archiv/readme-verlauf-bis-2026-10-02.md](archiv/readme-verlauf-bis-2026-10-02.md).
- **Versionen und Reihenfolge**: README, Abschnitt „Roadmap“ (maßgeblich). [ROADMAP.md](ROADMAP.md) ist die ausführliche Fassung und folgt der README. `TODO.md` A enthält nur die laufende Version, B ist nach Zielversion sortiert.
- **Design (seit 28.09.)**: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html) (Mockup, Sektionen 00–15) und [layout/Farbschema.dc.html](layout/Farbschema.dc.html) (Farbkonzept). Screenshot-Vorlage, nicht Code-Vorlage. Regeln für Mockups: [layout/CLAUDE.md](layout/CLAUDE.md).
- **Komponentenkatalog (Maße, Farben, Zustände):** [layout/Komponenten.dc.html](layout/Komponenten.dc.html), zusammengefasst in [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) (der Host pflegt die Zusammenfassung; bei Widerspruch gilt die Layout-Seite).
- **Erledigt**: [DONE.md](DONE.md) — Register der vom Host abgenommenen Aufgaben (nur der Host pflegt es).
- **Aufgabenliste**: [TODO.md](TODO.md) — nur offene Aufgaben (A. Jetzt) und Backlog (B., der Worker arbeitet nicht daran) plus die verbindlichen Regeln für den Worker. Alte Fassungen und Volltexte: `archiv/prompt-*.md`.
- Archiv (nicht mehr maßgeblich): `archiv/layout-alt/design_handoff_disk_index/` — ursprüngliches Handoff mit alter Screen-Nummerierung.

## Status dieses Projekts
Xcode-Projekt unter `diskindex/` (SwiftUI/AppKit, GRDB/SQLite). Erkennung, Indizierung, Live-Überwachung, Suche, Favoriten, Einstellungen, Fehlerbericht und Menüleiste laufen auf echten Daten. Es gibt eine Aufgabenliste (`TODO.md`) und einen Worker zur Zeit, Pakete laufen nacheinander. Aktuelle offene Aufgaben: siehe `TODO.md`. Aufbau der Software: README, „Architektur“.
