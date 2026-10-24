# TODO.md — Index der offenen Arbeit

**Kurz halten.** Diese Datei ist der Einstieg für Host und Worker; Aufgabentexte stehen in den verlinkten Dateien. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). Versionsplan: README „Roadmap“, ausführlich [ROADMAP.md](ROADMAP.md). Erledigt: [DONE.md](DONE.md). Abnahme: [archiv/abnahme-ablauf.md](archiv/abnahme-ablauf.md). Komponenten: [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) (Quelle `layout/Komponenten.dc.html`). Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

| Datei | Inhalt | Wer liest |
|---|---|---|
| [todo/regeln.md](todo/regeln.md) | 15 Regeln für den Worker (verbindlich, neu gefasst 23.10.) | Worker immer, Host bei Bedarf |
| [todo/paket-18.md](todo/paket-18.md) | **aktuelles Paket** mit Aufgaben und Status-Feldern | Worker, Host beim Prüfen |
| [todo/backlog.md](todo/backlog.md) | nicht freigegeben, nach Zielversion | nur bei Planung |
| `archiv/todo-stand-*.md` | alte Fassungen (Volltexte abgenommener Pakete) | nur bei Bedarf |

## Kennungen (Nutzer 14.10.)

- **`todo.<Version>.<Nr>`** = Aufgabe (Funktion, Politur, Doku, Entscheidung).
- **`bug.<Version>.<Nr>`** = Fehler.
- `<Version>` ist die **Zielversion** aus der Roadmap (`0.4`, `0.3.2` …), `<Nr>` dreistellig und je Art und Version fortlaufend (Beispiel: `bug.0.4.014`). Die Kennung steht im Status, im Commit und in DONE.md. **Ausnahme (Host 16.10.):** Die schon vergebenen `bug.0.4.xxx` behalten ihre Nummern (sie stehen in Commits und DONE.md), auch wenn ihre Zielversion 0.3.8 oder 0.3.9 ist; maßgeblich ist die Spalte „Zielversion“ in der Paketliste. Neue Kennungen tragen die echte Zielversion (`bug.0.3.8.xxx`). Fehler-Nummern aus dem Audit 13.10. (`REPORT 54` …) stehen im Archiv `archiv/report-audit-2026-10-13.md`; jede Aufgabe nennt ihre Nummern.
- **Host und Worker** bestimmt der Nutzer bei der Übergabe (AGENTS.md). Worker (jeder Agent, auch auf einem anderen Gerät) arbeiten, der Host prüft und nimmt ab (Regel 15). `REPORT.md` bleibt leer; Fehler werden direkt hier als `bug.*` eingetragen.

## Stand

**Stand 24.10.2026 (Host):** Version im Xcode-Projekt **0.4.0**. Abgenommen bis einschließlich **Paket 17** (DONE.md). **Paket 18 freigegeben** ([todo/paket-18.md](todo/paket-18.md), 4 Kennungen), danach Abnahmerunde des Nutzers `todo.0.4.040`. „Keine Schwelle“ bleibt (Nutzer 23.10.). **Verfahren neu ab Paket 17 (Host 23.10., auf Wunsch des Nutzers):** `todo/regeln.md` auf 15 Regeln gekürzt (verlorene Selbstprüfung als Regel 12 zurück, mit fünf Fragen), Sabotage als Patch mit automatischer Prüfung (`Werkzeuge/pruefung.sh sabotage`, Regel 9), Invarianten in `konzept/architektur.md`, kleine Pakete (höchstens 8 Kennungen, eine schwere zuerst; `archiv/abnahme-ablauf.md` 2a).

**Prüfung Host 24.10. 08:25–08:55 (Paket 17, Commit `3fdeebb`, MacBook Air macOS 15.7.3, Xcode 26.3, `Werkzeuge/pruefung.sh voll`):** Debug mit Testziel und Release 0 Warnungen, seriell **1032/1032** grün, **parallel 3/3** grün (je 1026, 6 übersprungen), keine neuen `.ips`, **Sabotage 15/15 rot ✓** (erster Lauf nach dem neuen Verfahren), App des Nutzers aktuell (08:55:22, Signatur gültig, Version 0.4.0). Zwei Prüf-Agenten (Sonnet): kein hoher Befund; Reste `bug.0.4.173`–`176` in Paket 18 (Stichprobe Host bestätigt 173). Alle 5 Kennungen abgenommen. Frage 170 entschieden: Grenze 6 h bleibt. Vorige Prüfungen: `archiv/paket-1[4-7]-abgenommen-*.md`.

**Abnahmekriterien 0.4.0 (alle müssen erfüllt sein):** (1) alle Kennungen von 0.4.0 vom Host abgenommen und in DONE.md; (2) Debug und Release inklusive Testziel 0 Warnungen; (3) serieller Gesamtlauf grün; (4) Parallellauf grün, dreimal hintereinander; (5) keine neuen `Disk Archive*.ips`; (6) App des Nutzers aktuell (Regel 14); (7) Abnahmerunde des Nutzers `todo.0.4.040`; (8) keine offene „Frage:“; (9) alle Sabotage-Patches rot (ab Paket 17).

**Keine Schwelle (Nutzer 20.10.):** Jeder bestätigte Befund kommt in 0.4.0, gleich welcher Schwere – „wir beenden fehlerfrei die 0.4.0-Runde“.

## Pakete

| Paket | Zielversion | Kennungen | Thema | Stand |
|---|---|---|---|---|
| 0–12 | 0.3.8–0.4.0 | siehe DONE.md | Testbasis bis Funde des Nutzers | abgenommen bis 20.10. |
| 13 | **0.4.0** | ~~`bug.0.4.116`, `117`, `105`, `104`, `103`, `126`–`129`, `137`, `138`, `109`, `093`, `095`–`097`, `131`–`133`, `100`~~ | Testfenster, Einstellungen, Status, Live, Oberfläche | **abgenommen 23.10.** |
| 14 | **0.4.0** | alle außer `bug.0.4.113`, `134`, `148` (→ Paket 15) | Reste, Tests, Prüfbefunde 13, Version 0.4.0 → [archiv/paket-14-abgenommen-2026-10-23.md](archiv/paket-14-abgenommen-2026-10-23.md) | **abgenommen 23.10.** |
| 15 | **0.4.0** | `bug.0.4.148`, `134`, `113`, `156`–`163` | Scroll-Regression, Absturzbericht, Prüfbefunde 14 → [archiv/paket-15-abgenommen-2026-10-23.md](archiv/paket-15-abgenommen-2026-10-23.md) | **abgenommen 23.10.** |
| 16 | **0.4.0** | `bug.0.4.164`–`167` (168, 169 → Paket 17) | Absturzbericht, Wiederverbinden, Tests → [archiv/paket-16-abgenommen-2026-10-23.md](archiv/paket-16-abgenommen-2026-10-23.md) | **abgenommen 23.10.** |
| 17 | **0.4.0** | `bug.0.4.169`, `168`, `170`–`172` | Teil-Prüfsumme ohne Datenverlust, Scroll während Indizierung, Reste → [archiv/paket-17-abgenommen-2026-10-24.md](archiv/paket-17-abgenommen-2026-10-24.md) | **abgenommen 24.10.** |
| **18** | **0.4.0** | `bug.0.4.175`, `174`, `173`, `176` | Einhängepunkt ohne Medium, Abbruch im Abschluss, Spalten-Cache, Kleinkram → [todo/paket-18.md](todo/paket-18.md) | **freigegeben 24.10.** |
| – | **0.4.0** | `todo.0.4.040` (Nutzer) | Abnahmerunde: echte Medien, Layout → Release-Kandidat | nach Paket 18 |
| – | **0.4.1** | `todo.0.4.021`, `022`, `024`, `todo.0.4.1.001`, `002` | Release der Open Beta → [todo/backlog.md](todo/backlog.md) | Backlog |

## Entscheidungen des Nutzers

**Offen:** `bug.0.4.151` – Fortschritt bei dauerhafter Lücke: heute 99 % (Kappung) neben dem Lücken-Status aus 127. Vorschlag Host: so lassen.

**Entschieden 23.10.:** `bug.0.4.153` Einstellungen nicht lesbar → Hinweis im Einstellungsfenster, keine Indizierung/kein Abgleich in der Sitzung, beim nächsten Start neu lesen (Vorschlag Host, vom Nutzer bestätigt).

**Entschieden 20.10.:** Wartescreen der Suche nur aus dem Leerzustand; Rollbalken nur Platz, keine leere Leiste; Sicherungskopie vor Schema-Erweiterung erst zu 1.0 (`bug.0.4.106`, Backlog); eingereihte Berichte gehen auch nach dem Ausschalten von „automatisch senden“ raus. Ältere Entscheidungen (16.10.: `todo.0.4.030`–`039`): `archiv/todo-stand-2026-10-23-vor-abnahme-paket13.md`.

## Nutzer und Host (ohne Worker)

| Kennung | Was | Wer |
|---|---|---|
| `todo.0.3.2.001` | Layout **02** (Erkennungs-Dialog mit Stapel/Warteschlange) und **04** (Dashboard-`card-meta`: Belegung links, „Zuletzt indiziert“ rechts, eine Zeile) in `layout/Disk Index App.dc.html` nachziehen. Blockiert keinen Code. | Nutzer |
| `todo.0.4.042` | **Zielversion 0.4.0, wartet auf Layout (Nutzer 18.10.; vorher „Wartescreen der Suche“ in 0.5).** Regel: README Abschnitt 5, „Ladeanzeige von Suche und Favoriten“. Startet eine Suche **aus dem Leerzustand** (noch keine Treffer sichtbar; auch wenn sie auf die Warteschlange nach einer Regeländerung wartet), zeigt die Suchansicht **sofort** die ganze Fläche aus Layout 10.1 (`SearchIdlePlaceholder`/`EmptyStateView`) in gleicher Größe und Position, mit **Spinner** statt der zwei Icons und dem Titel **„Suche läuft“** (de/en), **mindestens 1 s**, auch wenn die Treffer schneller da sind; dann die Treffer in einem Schritt. Verfeinern (Tippen, Filter, Sortierung) bei sichtbaren Treffern: alte Treffer bleiben, bis die neuen da sind, kein Wartescreen. Die kleine Zeile mit Spinner in der leeren Tabelle (`SearchView.swift`, `placeholder`, `LayoutCopy.searchInProgress`) entfällt. Mindestdauer als Parameter (kein prozessweiter Schalter, Regel 11), eine gemeinsame Quelle mit `todo.0.4.043` (Regel 7). Fenstertest: Suche aus dem Leerzustand → Wartescreen sofort, nach ≥ 1 s Treffer; Verfeinern → kein Wartescreen; Pixel hell/dunkel. **Freigabe durch den Host, sobald das Layout vorliegt.** |
| `todo.0.4.045` | Nach Paket 18 (`bug.0.4.124`, `162 c`): Löschbefehl für die rund 8.600 leeren Test-`.plist` in `~/Library/Preferences` an den Nutzer geben (Host löscht nichts außerhalb des Projekts). Danach Checkliste für `todo.0.4.040` (SD, USB, SSD gleichzeitig; vorher alle Medien neu indizieren; Gegenprobe `bug.0.4.141`). | Host → Nutzer |
