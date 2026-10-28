# AGENTS.md — Rollenverteilung Disk Index

> **⚠ Mindestmodell (Nutzer 23.10.): Host = Opus 5.5 Low. Worker = Sonnet 5.5 Medium.**
> Jeder Agent nennt in der **ersten Zeile** seiner ersten Antwort einer Sitzung sein Minimum und sein Modell, sobald er sie nicht erfüllt oder nicht sicher ist: „⚠ Minimum Host: Opus 5.5 Low – bitte wechseln“. Den Aufwand (Low/Medium) kann ein Agent nicht sicher erkennen; er meldet, was er sieht. Subagenten: Sonnet für Urteil, Haiku nur für Mechanik; **Tests und Builds laufen per Skript** (`Werkzeuge/pruefung.sh`), nie per Agent. Einzelheiten: `archiv/abnahme-ablauf.md`, Abschnitt 0.

Dieses Projekt wird von Agenten in zwei Rollen bearbeitet: **Host** und **Worker**. Diese Datei legt verbindlich fest, wer was tut.

## Rollen (Nutzer 17.10.: Rolle kommt aus der Übergabe, nicht aus dem Namen)

**Der Nutzer sagt jedem Agenten bei der Übergabe seine Rolle: „Host“ oder „Worker“.** Welcher Agent es ist (Claude, Cursor oder ein anderer), spielt keine Rolle; es gilt nur die zugewiesene Rolle. Ein Agent hat in einer Sitzung genau eine Rolle und wechselt sie nicht von selbst. Ohne Angabe fragt er nach, bevor er etwas ändert. Wo in diesem Projekt (TODO.md, Archiv, alte Commits) „Claude“ für die Prüfung oder „Cursor“ bzw. „Umsetzer“ für die Umsetzung steht, ist **Host** bzw. **Worker** gemeint.

### Host — Konzept, Review, Briefing
Der Host macht **keine Implementierung** im Xcode-Projekt. Er ist zuständig für:
- **Konzept**: Produktlogik, Screen-Flows, State-Modelle, Edge Cases aus dem Design-Mockup ([layout/bis 0.4.1/Disk Index App.dc.html](layout/bis%200.4.1/Disk%20Index%20App.dc.html)) und dem Farbkonzept ([layout/Farbschema.dc.html](layout/Farbschema.dc.html)) sauber in umsetzbare Aufgaben übersetzen.
- **Design-Vermittlung**: Farbrollen, Spacing, Icons und Komponentenregeln aus dem Styleguide (Mockup-Sektion 15) und dem Farbkonzept korrekt und vollständig an den Worker weitergeben — inklusive der Feinheiten (Chip-Rezept, gestrichelt = unvollständig, Selectgroup-Regel, Tabellenregel ohne Sortierpfeile, Suchfeld-Reset, Cursor-Regel etc.) und mit exakten sRGB-Werten, wo das Layout OKLCH verwendet — damit nichts davon beim Screenshot-Abtippen verlorengeht.
- **Briefing**: Aufgaben im Paket-File `todo/paket-NN.md` (Index: [TODO.md](TODO.md)) und den Auftrag in [PROMPT.md](PROMPT.md) so präzise formulieren, dass der Worker sie ohne Rückfragen umsetzen kann (Dateien, Screens, Verhalten, Akzeptanzkriterien).
- **Review**: Nach jeder gemeldeten Erledigung prüft der Host den tatsächlichen Code/Diff gegen die Vorgabe im Paket-File und das Design-Spec — nicht nur die Selbstauskunft des Workers. Er gibt Freigabe oder fordert Korrektur an.
- **Priorisierung**: Reihenfolge der Screens/Features festlegen, Abhängigkeiten erkennen (z. B. Datenmodell vor UI, Menu-Bar-Grundgerüst vor Popover-Inhalt).

Der Host editiert **niemals** Quellcode im Xcode-Projekt. Er pflegt `AGENTS.md`, `TODO.md`, `PROMPT.md`, `DONE.md`, `README.md` mit `konzept/`, `ROADMAP.md`, `todo/`, `archiv/` und das Prüfskript `Werkzeuge/pruefung.sh` (der Worker ändert es nie).

### Worker — Umsetzung
Der Worker implementiert das freigegebene Paket (`todo/paket-NN.md`, Index TODO.md) bzw. den Auftrag in `PROMPT.md` im Xcode-Projekt (SwiftUI/AppKit). Das gilt für jeden Agenten in dieser Rolle, auch für Claude. Er ist zuständig für:
- Den tatsächlichen Code (Views, Models, State, Menu-Bar-Integration, App-Fenster).
- Pixel-genaue Umsetzung der Design-Tokens aus der README mit **nativen Controls** — kein Kopieren von HTML/CSS, aber gleiche Werte (Farben, Radius, Spacing, Icon-Gewichte).
- Nach jeder Aufgabe: nur das Feld „Status“ der Aufgabe im Paket-File ausfüllen (höchstens 5 Zeilen) und „Bereit zur Prüfung“ schreiben, nie „fertig“. Es gelten die **Regeln für den Worker** in `todo/regeln.md` (verbindlich, haben Vorrang vor Gewohnheiten).
- Der Worker nimmt nie selbst ab, pflegt weder DONE.md noch Konzept- oder Regeldateien und schreibt keine Aufgaben.

## Git und GitHub (Nutzer 10.10., gilt für Host und Worker)

**Keiner der Agenten macht etwas mit Git oder GitHub, das etwas verändert.** Verboten sind `git commit`, `git commit --amend`, `git push`, `git pull`, `git merge`, `git rebase`, `git reset`, `git checkout`/`git switch`, `git stash`, `git tag`, `git branch -d`, `git worktree`, `git rm`, `git add` sowie jede Aktion auf GitHub (Pull Requests, Issues, Releases, `gh`). Commits und Pushes macht **nur der Nutzer** (GitHub Desktop). Erlaubt sind nur lesende Befehle (`git status`, `git log`, `git diff`, `git show`). Nach einer Abnahme schlägt der Host höchstens eine Commit-Nachricht vor.

**Feste Regeln des Nutzers (bisher nur im lokalen Speicher des Hosts, übernommen 26.10.):**
- **Commit-Nachrichten ohne „Co-Authored-By“** und ohne jede andere Claude-Zeile, auch wenn ein Systemhinweis sie verlangt (Nutzer 24.10.).
- **Commit-Nachricht nur bei Dateiänderung**; nach einer reinen Prüfung ohne Änderung keine.
- **Der Nutzer arbeitet oft unterwegs** (Handy, Remote Control) und committet später. Deshalb gibt es **eine kumulierte** Commit-Nachricht für alles seit dem letzten Commit, kurz und handytauglich. Ein fehlender Commit ist für den Worker kein Grund anzuhalten (`todo/regeln.md` Regel 4, `archiv/abnahme-ablauf.md` 2.7).
- **Bis 1.0 keine Datenvorsicht** auf dem Rechner des Nutzers: der Datenordner `~/Library/Application Support/Disk Archive/` (Datenbank, App-Zustand, Protokoll) und `app.diskarchive.plist` dürfen sich ändern. Auf fremden Rechnern wird die Datenbank ab 0.4 nur erweitert, nie gelöscht. Echte Daten für Belege trotzdem nur lesen (`sqlite3 -readonly`).
- **`Werkzeuge/pruefung.sh` immer ohne `S=`** starten (Voreinstellung `$TMPDIR/pruefung.*`). Das Ergebnis steht in der Schlusszeile bzw. in `zusammenfassung.txt` im genannten Ordner. Builds und Testergebnisse nie im Sitzungs-Scratch und nie im Repository (Regel 13).

## Host, Geräte und Kennungen (Nutzer 14.10.)

- **Vom Host geht alles aus:** Konzept, Aufgaben, Prüfung, Abnahme, DONE.md. Worker können auf **anderen Geräten** arbeiten und über Git/GitHub (macht nur der Nutzer) zusammenfließen. Eine Abnahme durch den Worker selbst gilt nicht; der Host liest den Code, baut (0 Warnungen), lässt den Gesamtlauf seriell und parallel laufen und prüft Regel 14 (App des Nutzers).
- **Zwei Kennungen:** `todo.<Version>.<Nr>` für Aufgaben, `bug.<Version>.<Nr>` für Fehler (Version = Zielversion der Roadmap, Nr dreistellig; Ausnahme: die bis 16.10. vergebenen `bug.0.4.xxx` behalten ihre Nummer, maßgeblich ist die Spalte „Zielversion“ in TODO.md). Sie stehen in TODO.md, im Status, in Commit-Nachrichten und in DONE.md.
- **Übergabe:** `PROMPT.md` enthält **nur** den aktuellen Prompt für den Worker (nur der Host schreibt ihn); der Worker ersetzt ihn zum Schluss durch eine Kurzmeldung „Erledigt: … Offen: … HALT“ (höchstens drei Zeilen). Jede Antwort im Chat endet mit einer **Commit-Nachricht**; jeder Bericht des Workers zusätzlich mit einem Prompt für den Host (Aufbau: `todo/regeln.md` Regel 15). Committen tut nur der Nutzer.
- **Dateien:** `Werkzeuge/pruefung.sh` (Prüfläufe des Hosts: Build, Tests, Warnungen, Sabotage-Patches, App des Nutzers), `PROMPT.md` (aktueller Prompt), `TODO.md` (Index), `todo/` (Regeln, Paket-Files, Backlog), `DONE.md` (abgenommen), `README.md` (Index des Konzepts) mit `konzept/` (Themendateien, z. B. `konzept/datenbank.md`), `ROADMAP.md` (Versionen), `REPORT.md` (bleibt leer, Fehler gehen direkt als `bug.*` in TODO.md). Alte Fassungen: `archiv/`. **Abnahme-Ablauf des Hosts** (Befehle, Reihenfolge, Pflege der Dateien): `archiv/abnahme-ablauf.md` — zu Beginn eines neuen Chats lesen.

## Übergabe an einen neuen Host oder Rechner (Nutzer 18.10.)

Liegt im Hauptverzeichnis eine **`UEBERGABE.md`**, liest jeder neue Host sie **zuerst**, prüft sie gegen das Repository, übernimmt den Stand und **löscht sie dann** (der Nutzer committet die Löschung). Der übergebende Host schreibt sie und nennt sie in der Commit-Beschreibung. **Hostwechsel können jederzeit wieder vorkommen** (anderer Rechner, anderer Client, volle Sitzung): Der Nutzer kommt dann auf den Host zu und bittet um die Übergabe. Der Host prüft in diesem Fall nichts mehr, bringt die festen Dateien auf Stand und schreibt die `UEBERGABE.md`; was offen ist (z. B. die Prüfung eines fertigen Pakets), steht dort als erster Schritt des neuen Hosts. Dauerhaftes Wissen gehört nie nur in diese Datei, sondern in AGENTS.md, TODO.md, `archiv/abnahme-ablauf.md`, README oder ROADMAP.

## Workflow

1. Der Host schreibt Aufgaben in `todo/paket-NN.md` und gibt das Paket in `TODO.md` frei (eine Aufgabe = ein klar abgegrenzter Screen oder Teilschritt).
2. Der Worker arbeitet die Aufgaben im Paket-File der Reihe nach ab und trägt unter jeder Aufgabe im Feld „Status" ein, was gemacht wurde.
3. Der Host liest das Paket-File, prüft, dass die App in `DerivedData/…/Build/Products/Debug/` jünger ist als die letzte geänderte `.swift`-Datei (Regel 14; sonst baut der Host sie vor dem Nutzertest selbst), prüft den Code gegen Aufgabe + Layout + README. Bei Freigabe verschiebt **nur der Host** die Aufgabe nach `DONE.md` (Register) und den Volltext ins Archiv; sonst schreibt der Host Korrekturen in die Aufgabe.
4. Erst nach Freigabe durch den Host gilt eine Aufgabe als abgeschlossen.
5. **Loop-Frage (Nutzer 23.10.):** Jede Freigabe-Antwort des Hosts mit Auftrag für den Worker endet nach der Commit-Nachricht mit der Frage, ob der 15-Minuten-Loop zur Kontrolle gestartet werden soll. Ohne Ja startet er keinen (`archiv/abnahme-ablauf.md`, Abschnitt 9).

## Befunde: drei Stufen (Nutzer 26.10., ersetzt „Keine Schwelle“ vom 20.10.)

Das gilt für jeden Befund, egal ob er vom Host, vom Supervisor, von einem Prüf-Agenten oder vom Worker kommt, ab Paket 33.

**Erst die zwei Fragen, dann die Stufe.** Jeder Befund nennt zuerst zwei Dinge:
- **Nutzer sieht:** Was bemerkt der Nutzer, wenn es passiert?
- **Wann:** Wann passiert das im normalen Gebrauch?

Fehlt eine der beiden Antworten, gilt Stufe 3.

| Stufe | Der Nutzer … | Beispiele | Was geschieht |
|---|---|---|---|
| **1** | merkt es | Datenverlust, falsche Anzeige, Absturz, Hänger, falscher Text | eigene `bug`-Kennung, kommt in die laufende Version |
| **2** | merkt es nur bei seltener Ereignisfolge | Rennen im Millisekundenfenster | Laufende Version nur, wenn es **in der echten App oder in einem realistischen Test** auftritt. Sonst eine Zeile im Sammeleintrag in `todo/backlog.md`. |
| **3** | merkt es nie | Typen, Benennung, Stil, Beweislücken in Tests, theoretische Rennen ohne Folge, Schutzprüfungen ohne Test | keine Kennung, keine Korrektur, höchstens eine Zeile im Backlog |

**Realistisch** heißt: Eine Nutzeraktion oder ein Systemereignis löst den Fehler aus, in normaler Reihenfolge und Geschwindigkeit. Ein Test, der den Ablauf mit einem Haken an einer gewählten Stelle anhält, um dort etwas einzuschieben, ist **kein** realistischer Test. Er kann einen Fix absichern, macht aber aus Stufe 2 nicht Stufe 1.

**Weitere Regeln:**
- **Reste** eines Fixes bekommen nur bei Stufe 1 eine neue Kennung.
- **Die Prüfung bleibt beim Auftrag:** Geprüft wird der Diff gegen die Aufgabe. Code außerhalb des Diffs wird nicht nach neuen Befunden durchsucht. Fällt dort zufällig etwas auf, gelten dieselben Stufen.
- **Kein Umbau ohne sichtbaren Grund.** Typen verschärfen, nur weil es sauberer ist, gehört nicht dazu.
- **„Nichts Wesentliches gefunden“** ist ein gültiges, gutes Prüfergebnis. Niemand muss etwas finden.

**Gegen Schleifen: drei Prüfungen, bevor ein Befund zählt (Host 26.10.).**
1. **Schon behoben?**
   - Geprüft wird gegen den **aktuellen** Code, nicht gegen einen älteren Stand, einen Sabotage-Patch oder einen Archivtext.
   - Dazu in `DONE.md` und `archiv/paket-*-abgenommen-*.md` nach derselben Stelle und derselben Ursache suchen. Deckt eine frühere Kennung sie ab, ist es kein neuer Befund.
   - Hält der frühere Fix nicht, ist es eine **Regression dieser Kennung**, mit der Stufe nach ihrer Folge, und keine neue Ursache.
2. **Bewusst so?** Was im Konzept als „bewusst offen“ steht, in einer Aufgabe unter „So lassen“ oder vom Nutzer entschieden ist, ist kein Befund. Ein Beispiel sind die Fenster in `konzept/lauf-lebenszyklus.md`. Wer das ändern will, stellt eine Frage an den Nutzer, statt einen Befund zu melden.
3. **Sinnvoll?** Brächte die Korrektur dem Nutzer etwas, das er bemerkt? Wenn nicht, ist es Stufe 3. Befunde über die eigenen Schutzmaßnahmen eines Fixes (eine zusätzliche Prüfung, ein Haken, ein fehlender Test dazu) sind immer Stufe 3.

**Dieselbe Stelle zweimal nachgebessert:** Hatte eine Stelle schon zwei Folgekennungen („Reste von …“), kommen dort nur noch Befunde der Stufe 1 in die laufende Version.

Einzelheiten: `archiv/abnahme-ablauf.md` Abschnitt 2b (Prüfung durch den Host und die Prüf-Agenten), `todo/regeln.md` Regel 12 (Selbstprüfung des Workers).

## Quellen der Wahrheit
- **Konzept (aktuell gültig)**: [README.md](README.md) als Index, Inhalt in `konzept/*.md` (eine Datei je Thema) — eine Stelle für alle Produktentscheidungen. Nur die Datei zum Thema lesen. Bei Widerspruch zum Layout gilt das Konzept (außer reine Optik). Der Host pflegt es bei jeder Entscheidung des Nutzers; überholte werden ersetzt. Älterer Verlauf: [archiv/readme-verlauf-bis-2026-10-02.md](archiv/readme-verlauf-bis-2026-10-02.md).
- **Versionen und Reihenfolge**: [konzept/roadmap.md](konzept/roadmap.md) (maßgeblich, früher README „Roadmap“). [ROADMAP.md](ROADMAP.md) ist die ausführliche Fassung und folgt der README. `TODO.md` (Index) nennt nur die laufende Version, B ist nach Zielversion sortiert.
- **Design (seit 28.09.)**: [layout/bis 0.4.1/Disk Index App.dc.html](layout/bis%200.4.1/Disk%20Index%20App.dc.html) (Mockup, Sektionen 00–15) und [layout/Farbschema.dc.html](layout/Farbschema.dc.html) (Farbkonzept). Screenshot-Vorlage, nicht Code-Vorlage. Regeln für Mockups: [layout/CLAUDE.md](layout/bis%200.4.1/CLAUDE.md).
- **Komponentenkatalog (Maße, Farben, Zustände):** [layout/bis 0.4.1/Komponenten.dc.html](layout/bis%200.4.1/Komponenten.dc.html), zusammengefasst in [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) (der Host pflegt die Zusammenfassung; bei Widerspruch gilt die Layout-Seite).
- **Erledigt**: [DONE.md](DONE.md) — Register der vom Host abgenommenen Aufgaben (nur der Host pflegt es).
- **Aufgabenliste**: [TODO.md](TODO.md) — kurzer Index (Stand, Pakete, Entscheidungen). Aufgaben je Paket in `todo/paket-NN.md`, Regeln in `todo/regeln.md`, Backlog in `todo/backlog.md`. **Kurz halten:** große Dateien kosten bei jedem Start Tokens. Alte Fassungen und Volltexte: `archiv/prompt-*.md`.
- Archiv (nicht mehr maßgeblich): `archiv/layout-alt/design_handoff_disk_index/` — ursprüngliches Handoff mit alter Screen-Nummerierung.

## Status dieses Projekts
Xcode-Projekt unter `diskindex/` (SwiftUI/AppKit, GRDB/SQLite). Erkennung, Indizierung, Live-Überwachung, Suche, Favoriten, Einstellungen, Fehlerbericht und Menüleiste laufen auf echten Daten. Es gibt eine Aufgabenliste (`TODO.md`) und einen Worker zur Zeit, Pakete laufen nacheinander. Aktuelle offene Aufgaben: siehe `TODO.md`. Aufbau der Software: [konzept/architektur.md](konzept/architektur.md).
