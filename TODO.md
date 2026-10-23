# TODO.md — Index der offenen Arbeit

**Kurz halten.** Diese Datei ist der Einstieg für Host und Worker; Aufgabentexte stehen in den verlinkten Dateien. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). Versionsplan: README „Roadmap“, ausführlich [ROADMAP.md](ROADMAP.md). Erledigt: [DONE.md](DONE.md). Abnahme: [archiv/abnahme-ablauf.md](archiv/abnahme-ablauf.md). Komponenten: [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) (Quelle `layout/Komponenten.dc.html`). Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

| Datei | Inhalt | Wer liest |
|---|---|---|
| [todo/regeln.md](todo/regeln.md) | Regeln 1–31 für den Worker (verbindlich) | Worker immer, Host bei Bedarf |
| [todo/paket-16.md](todo/paket-16.md) | **aktuelles Paket** mit Aufgaben und Status-Feldern | Worker, Host beim Prüfen |
| [todo/backlog.md](todo/backlog.md) | nicht freigegeben, nach Zielversion | nur bei Planung |
| `archiv/todo-stand-*.md` | alte Fassungen (Volltexte abgenommener Pakete) | nur bei Bedarf |

## Kennungen (Nutzer 14.10.)

- **`todo.<Version>.<Nr>`** = Aufgabe (Funktion, Politur, Doku, Entscheidung).
- **`bug.<Version>.<Nr>`** = Fehler.
- `<Version>` ist die **Zielversion** aus der Roadmap (`0.4`, `0.3.2` …), `<Nr>` dreistellig und je Art und Version fortlaufend (Beispiel: `bug.0.4.014`). Die Kennung steht im Status, im Commit und in DONE.md. **Ausnahme (Host 16.10.):** Die schon vergebenen `bug.0.4.xxx` behalten ihre Nummern (sie stehen in Commits und DONE.md), auch wenn ihre Zielversion 0.3.8 oder 0.3.9 ist; maßgeblich ist die Spalte „Zielversion“ in der Paketliste. Neue Kennungen tragen die echte Zielversion (`bug.0.3.8.xxx`). Fehler-Nummern aus dem Audit 13.10. (`REPORT 54` …) stehen im Archiv `archiv/report-audit-2026-10-13.md`; jede Aufgabe nennt ihre Nummern.
- **Host und Worker** bestimmt der Nutzer bei der Übergabe (AGENTS.md). Worker (jeder Agent, auch auf einem anderen Gerät) arbeiten, der Host prüft und nimmt ab (Regel 28). `REPORT.md` bleibt leer; Fehler werden direkt hier als `bug.*` eingetragen.

## Stand

**Stand 23.10.2026 abends (Host):** Version im Xcode-Projekt **0.4.0**. Abgenommen bis einschließlich **Paket 15** (DONE.md). **Paket 16 freigegeben** ([todo/paket-16.md](todo/paket-16.md)), danach Abnahmerunde des Nutzers `todo.0.4.040`. Ein Worker zur Zeit, Pakete nacheinander.

**Prüfung Host 23.10. 19:21–19:44 (Paket 15, Stand `675fe3d` plus uncommittete Änderungen, MacBook Air macOS 15.7.3, Xcode 26.3, `Werkzeuge/pruefung.sh voll`):** Debug mit Testziel und Release 0 Warnungen, seriell **1011/1011** grün, **parallel 3/3** grün (je 1005, 6 übersprungen; `openObjectScrollsToTheFileInTable` wieder stabil), keine neuen `.ips`, Regel 23 (App 19:44:38, keine neuere `.swift`, Signatur gültig, Version 0.4.0). Drei Prüf-Agenten (Sonnet): kein hoher Befund; Reste als `bug.0.4.164`–`169` in Paket 16 (Stichproben Host bestätigt 164 a, 165 a). Alle 11 Kennungen abgenommen. Fragen des Workers entschieden: 113 c → `164 d` (`"?"`, Laufzeit weglassen), 156 „Lesen vor der Transaktion“ → `169` (umbauen), 156 schwacher 141-Test → `165 b`, 162 f → `167 a`, 163 d → `167 b` (Feld bleibt, Test deterministisch). Vorige Prüfung (Paket 14): `archiv/paket-14-abgenommen-2026-10-23.md`.

**Abnahmekriterien 0.4.0 (alle müssen erfüllt sein):** (1) alle Kennungen von 0.4.0 vom Host abgenommen und in DONE.md; (2) Debug und Release inklusive Testziel 0 Warnungen; (3) serieller Gesamtlauf grün; (4) Parallellauf grün, dreimal hintereinander; (5) keine neuen `Disk Archive*.ips`; (6) Regel 23; (7) Abnahmerunde des Nutzers `todo.0.4.040`; (8) keine offene „Frage:“.

**Keine Schwelle (Nutzer 20.10.):** Jeder bestätigte Befund kommt in 0.4.0, gleich welcher Schwere – „wir beenden fehlerfrei die 0.4.0-Runde“.

## Pakete

| Paket | Zielversion | Kennungen | Thema | Stand |
|---|---|---|---|---|
| 0–12 | 0.3.8–0.4.0 | siehe DONE.md | Testbasis bis Funde des Nutzers | abgenommen bis 20.10. |
| 13 | **0.4.0** | ~~`bug.0.4.116`, `117`, `105`, `104`, `103`, `126`–`129`, `137`, `138`, `109`, `093`, `095`–`097`, `131`–`133`, `100`~~ | Testfenster, Einstellungen, Status, Live, Oberfläche | **abgenommen 23.10.** |
| 14 | **0.4.0** | alle außer `bug.0.4.113`, `134`, `148` (→ Paket 15) | Reste, Tests, Prüfbefunde 13, Version 0.4.0 → [archiv/paket-14-abgenommen-2026-10-23.md](archiv/paket-14-abgenommen-2026-10-23.md) | **abgenommen 23.10.** |
| 15 | **0.4.0** | `bug.0.4.148`, `134`, `113`, `156`–`163` | Scroll-Regression, Absturzbericht, Prüfbefunde 14 → [archiv/paket-15-abgenommen-2026-10-23.md](archiv/paket-15-abgenommen-2026-10-23.md) | **abgenommen 23.10.** |
| **16** | **0.4.0** | `bug.0.4.164`–`169` | Absturzbericht, Wiederverbinden, Tests, Spaltenansicht → [todo/paket-16.md](todo/paket-16.md) | **freigegeben 23.10.** |
| – | **0.4.0** | `todo.0.4.040` (Nutzer) | Abnahmerunde: echte Medien, Layout → Release-Kandidat | nach Paket 16 |
| – | **0.4.1** | `todo.0.4.021`, `022`, `024`, `todo.0.4.1.001`, `002` | Release der Open Beta → [todo/backlog.md](todo/backlog.md) | Backlog |

## Entscheidungen des Nutzers

**Offen:** `bug.0.4.151` – Fortschritt bei dauerhafter Lücke: heute 99 % (Kappung) neben dem Lücken-Status aus 127. Vorschlag Host: so lassen.

**Entschieden 23.10.:** `bug.0.4.153` Einstellungen nicht lesbar → Hinweis im Einstellungsfenster, keine Indizierung/kein Abgleich in der Sitzung, beim nächsten Start neu lesen (Vorschlag Host, vom Nutzer bestätigt).

**Entschieden 20.10.:** Wartescreen der Suche nur aus dem Leerzustand; Rollbalken nur Platz, keine leere Leiste; Sicherungskopie vor Schema-Erweiterung erst zu 1.0 (`bug.0.4.106`, Backlog); eingereihte Berichte gehen auch nach dem Ausschalten von „automatisch senden“ raus. Ältere Entscheidungen (16.10.: `todo.0.4.030`–`039`): `archiv/todo-stand-2026-10-23-vor-abnahme-paket13.md`.

## Nutzer und Host (ohne Worker)

| Kennung | Was | Wer |
|---|---|---|
| `todo.0.3.2.001` | Layout **02** (Erkennungs-Dialog mit Stapel/Warteschlange) und **04** (Dashboard-`card-meta`: Belegung links, „Zuletzt indiziert“ rechts, eine Zeile) in `layout/Disk Index App.dc.html` nachziehen. Blockiert keinen Code. | Nutzer |
| `todo.0.4.042` | **Zielversion 0.4.0, wartet auf Layout (Nutzer 18.10.; vorher „Wartescreen der Suche“ in 0.5).** Regel: README Abschnitt 5, „Ladeanzeige von Suche und Favoriten“. Startet eine Suche **aus dem Leerzustand** (noch keine Treffer sichtbar; auch wenn sie auf die Warteschlange nach einer Regeländerung wartet), zeigt die Suchansicht **sofort** die ganze Fläche aus Layout 10.1 (`SearchIdlePlaceholder`/`EmptyStateView`) in gleicher Größe und Position, mit **Spinner** statt der zwei Icons und dem Titel **„Suche läuft“** (de/en), **mindestens 1 s**, auch wenn die Treffer schneller da sind; dann die Treffer in einem Schritt. Verfeinern (Tippen, Filter, Sortierung) bei sichtbaren Treffern: alte Treffer bleiben, bis die neuen da sind, kein Wartescreen. Die kleine Zeile mit Spinner in der leeren Tabelle (`SearchView.swift`, `placeholder`, `LayoutCopy.searchInProgress`) entfällt. Mindestdauer als Parameter (kein prozessweiter Schalter, Regel 20), eine gemeinsame Quelle mit `todo.0.4.043` (Regel 12). Fenstertest: Suche aus dem Leerzustand → Wartescreen sofort, nach ≥ 1 s Treffer; Verfeinern → kein Wartescreen; Pixel hell/dunkel. **Freigabe durch den Host, sobald das Layout vorliegt.** |
| `todo.0.4.045` | Nach Paket 16 (`bug.0.4.124`, `162 c`): Löschbefehl für die rund 8.600 leeren Test-`.plist` in `~/Library/Preferences` an den Nutzer geben (Host löscht nichts außerhalb des Projekts). Danach Checkliste für `todo.0.4.040` (SD, USB, SSD gleichzeitig; vorher alle Medien neu indizieren; Gegenprobe `bug.0.4.141`). | Host → Nutzer |
