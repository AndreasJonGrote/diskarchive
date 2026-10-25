# TODO.md — Index der offenen Arbeit

**Kurz halten.** Diese Datei ist der Einstieg für Host und Worker; Aufgabentexte stehen in den verlinkten Dateien. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). Versionsplan: README „Roadmap“, ausführlich [ROADMAP.md](ROADMAP.md). Erledigt: [DONE.md](DONE.md). Abnahme: [archiv/abnahme-ablauf.md](archiv/abnahme-ablauf.md). Komponenten: [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) (Quelle `layout/Komponenten.dc.html`). Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

| Datei | Inhalt | Wer liest |
|---|---|---|
| [todo/regeln.md](todo/regeln.md) | 15 Regeln für den Worker (verbindlich, neu gefasst 23.10.) | Worker immer, Host bei Bedarf |
| [todo/paket-29.md](todo/paket-29.md) | **aktuelles Paket** mit Aufgaben und Status-Feldern | Worker, Host beim Prüfen |
| [todo/abnahmerunde-0.4.0.md](todo/abnahmerunde-0.4.0.md) | Checkliste der Abnahmerunde `todo.0.4.040` | Nutzer |
| [todo/backlog.md](todo/backlog.md) | nicht freigegeben, nach Zielversion | nur bei Planung |
| `archiv/todo-stand-*.md` | alte Fassungen (Volltexte abgenommener Pakete) | nur bei Bedarf |

## Kennungen (Nutzer 14.10.)

- **`todo.<Version>.<Nr>`** = Aufgabe (Funktion, Politur, Doku, Entscheidung).
- **`bug.<Version>.<Nr>`** = Fehler.
- `<Version>` ist die **Zielversion** aus der Roadmap (`0.4`, `0.3.2` …), `<Nr>` dreistellig und je Art und Version fortlaufend (Beispiel: `bug.0.4.014`). Die Kennung steht im Status, im Commit und in DONE.md. **Ausnahme (Host 16.10.):** Die schon vergebenen `bug.0.4.xxx` behalten ihre Nummern (sie stehen in Commits und DONE.md), auch wenn ihre Zielversion 0.3.8 oder 0.3.9 ist; maßgeblich ist die Spalte „Zielversion“ in der Paketliste. Neue Kennungen tragen die echte Zielversion (`bug.0.3.8.xxx`). Fehler-Nummern aus dem Audit 13.10. (`REPORT 54` …) stehen im Archiv `archiv/report-audit-2026-10-13.md`; jede Aufgabe nennt ihre Nummern.
- **Host und Worker** bestimmt der Nutzer bei der Übergabe (AGENTS.md). Worker (jeder Agent, auch auf einem anderen Gerät) arbeiten, der Host prüft und nimmt ab (Regel 15). `REPORT.md` bleibt leer; Fehler werden direkt hier als `bug.*` eingetragen.

## Stand

**Stand 25.10.2026 (Host):** Version im Xcode-Projekt **0.4.0**. Abgenommen bis einschließlich **Paket 28** (DONE.md). **Gesamtlauf 25.10. 23:01–23:33 grün** (seriell 1140/1140, parallel 3× grün, Sabotage 10/10, 0 Warnungen, keine `.ips`). **Paket 29 freigegeben** ([todo/paket-29.md](todo/paket-29.md), `bug.0.4.204`, Umbau statt weiterer Flicken). **Offen vor `todo.0.4.040`:** Paket 29. Checkliste der Abnahmerunde: [todo/abnahmerunde-0.4.0.md](todo/abnahmerunde-0.4.0.md). „Keine Schwelle“ bleibt (Nutzer 23.10.). Verfahren seit Paket 17: `todo/regeln.md` (15 Regeln), Sabotage als Patch (`Werkzeuge/pruefung.sh sabotage`, Regel 9), Invarianten in `konzept/architektur.md`, kleine Pakete (`archiv/abnahme-ablauf.md` 2a).

**Prüfung Host 25.10. 23:01–23:33 (Paket 28, Arbeitsbaum uncommittet seit Paket 27, macOS 15.7.4, Xcode 26.3, `Werkzeuge/pruefung.sh voll`, ruhiger Rechner):** Debug mit Testziel und Release 0 Warnungen, seriell 1140/1140, Parallel 1–3 grün (je 1134 bestanden, 6 übersprungen), keine neuen `.ips`, Sabotage **10/10 rot ✓**, App des Nutzers 23:32:54, Version 0.4.0. Prüf-Agent (Sonnet): kein hoher oder mittlerer Befund; die niedrigen betreffen alle das Nebeneinander zweier Läufe und gehen ohne neue Kennung in `bug.0.4.204` (Supervisor/Nutzer 25.10.). Ältere Prüfungen: `archiv/paket-*-abgenommen-*.md`.

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
| 18 | **0.4.0** | `bug.0.4.175`, `174`, `173`, `176` | Einhängepunkt ohne Medium, Abbruch im Abschluss, Spalten-Cache, Kleinkram → [archiv/paket-18-abgenommen-2026-10-24.md](archiv/paket-18-abgenommen-2026-10-24.md) | **abgenommen 24.10.** |
| 19 | **0.4.0** | `bug.0.4.177`–`180` (180 b → Paket 20) | Auswurf mitten im Lauf, roter Parallellauf, Medienprüfung, Kleinkram → [archiv/paket-19-abgenommen-2026-10-24.md](archiv/paket-19-abgenommen-2026-10-24.md) | **abgenommen 24.10.** |
| 20 | **0.4.0** | `bug.0.4.181`–`185` (185 c entfällt) | Live-Überwachung nach Auswurf, sichtbarer Abbruch, Testhaken, Beweis 180 b, Kleinkram → [archiv/paket-20-abgenommen-2026-10-24.md](archiv/paket-20-abgenommen-2026-10-24.md) | **abgenommen 24.10.** |
| 21 | **0.4.0** | `bug.0.4.186`, `187` | Keine Überwachung nach „nicht bestätigt“, Kleinkram → [archiv/paket-21-abgenommen-2026-10-24.md](archiv/paket-21-abgenommen-2026-10-24.md) | **abgenommen 24.10.** |
| 22 | **0.4.0** | `bug.0.4.188`–`191` | Roter Parallellauf nach Wiedereinhängen, Verwaltungsdateien, Systemmitteilung, Kleinkram → [archiv/paket-22-abgenommen-2026-10-24.md](archiv/paket-22-abgenommen-2026-10-24.md) | **abgenommen 24.10.** |
| 23 | **0.4.0** | `bug.0.4.192`–`195`, `todo.0.4.042`, `046`–`048` | Wackler, Mitteilung, Beweislücken, Wartescreens, Updatedialog, Stapel Erkennungsdialoge, Aufräumen → [archiv/paket-23-abgenommen-2026-10-25.md](archiv/paket-23-abgenommen-2026-10-25.md) | **abgenommen 25.10.** |
| 24 | **0.4.0** | `bug.0.4.196`, `197` | Zeitumstellung im Protokoll, Reste aus Prüfung 23 → [archiv/paket-24-abgenommen-2026-10-25.md](archiv/paket-24-abgenommen-2026-10-25.md) | **abgenommen 25.10.** (ruhiger Gesamtlauf 11:45–12:11 grün) |
| 25 | **0.4.0** | `bug.0.4.198` | Text „Auf Updates hinweisen“ ohne „in der Menüleiste“ → [archiv/paket-25-abgenommen-2026-10-25.md](archiv/paket-25-abgenommen-2026-10-25.md) | abgenommen 25.10. |
| 26 | **0.4.0** | `bug.0.4.199`–`201` | Dauerhafte Lücke = „Fehler“, Details „Indiziert x %“, Reste aus der Prüfung → [archiv/paket-26-abgenommen-2026-10-25.md](archiv/paket-26-abgenommen-2026-10-25.md) | **abgenommen 25.10.** |
| 27 | **0.4.0** | `bug.0.4.202` | Zeitfenster am Laufende, Beweislücken (Reste aus 26) → [archiv/paket-27-abgenommen-2026-10-25.md](archiv/paket-27-abgenommen-2026-10-25.md) | **abgenommen 25.10.** |
| 28 | **0.4.0** | `bug.0.4.203` | `finish`/`cancel` ganz am Token, Beweislücke, wackliger Test (Reste aus 27) → [archiv/paket-28-abgenommen-2026-10-25.md](archiv/paket-28-abgenommen-2026-10-25.md) | **abgenommen 25.10.** |
| **29** | **0.4.0** | `bug.0.4.204` | Abschluss und Abbruch je Medium nacheinander (Umbau), schwache Tests → [todo/paket-29.md](todo/paket-29.md) | **freigegeben 25.10.** |
| – | **0.4.0** | `todo.0.4.040` (Nutzer) | Abnahmerunde: echte Medien, Layout → Release-Kandidat; Checkliste [todo/abnahmerunde-0.4.0.md](todo/abnahmerunde-0.4.0.md) | nach Paket 29 |
| – | **0.4.1** | `todo.0.4.021`, `022`, `024`, `todo.0.4.1.001`, `002` | Release der Open Beta → [todo/backlog.md](todo/backlog.md) | Backlog |

## Entscheidungen des Nutzers

**Offen:** keine.

**Entschieden 25.10.:** `bug.0.4.151` (dauerhafte Lücke) → Status „Fehler“, Fortschritt als Zeile „Indiziert“ im Details-Modal (`bug.0.4.199`, Paket 26). Knopf „Datenhygiene“ in den Einstellungen: nicht bauen (Nutzer macht das später selbst; Testreste räumt der nächste Testlauf auf, `bug.0.4.124`).

**Entschieden 23.10.:** `bug.0.4.153` Einstellungen nicht lesbar → Hinweis im Einstellungsfenster, keine Indizierung/kein Abgleich in der Sitzung, beim nächsten Start neu lesen (Vorschlag Host, vom Nutzer bestätigt).

**Entschieden 20.10.:** Wartescreen der Suche nur aus dem Leerzustand; Rollbalken nur Platz, keine leere Leiste; Sicherungskopie vor Schema-Erweiterung erst zu 1.0 (`bug.0.4.106`, Backlog); eingereihte Berichte gehen auch nach dem Ausschalten von „automatisch senden“ raus. Ältere Entscheidungen (16.10.: `todo.0.4.030`–`039`): `archiv/todo-stand-2026-10-23-vor-abnahme-paket13.md`.

## Nutzer und Host (ohne Worker)

| Kennung | Was | Wer |
|---|---|---|
| `todo.0.3.2.001` | **Erledigt 25.10.:** Layout 02 → `todo.0.4.048`; Layout 04 per Screenshot des Nutzers (Dashboard-Karten: Belegung links, Uhr + Zeit rechts, eine Zeile) – die App setzt das schon so um (`MediumDashboardCard`); die HTML-Datei wird nicht nachgezogen. Weitere Layout-Fragen erst zu 0.4.1, nur auf Nachfrage. | – |
| `todo.0.4.045` | **Erledigt 25.10.:** Die 8.600 alten Test-`.plist` sind weg (seit `bug.0.4.124` räumt jeder Testlauf die des vorigen auf; übrig bleiben nur die ~90 des letzten Laufs). Löschbefehl und Checkliste: [todo/abnahmerunde-0.4.0.md](todo/abnahmerunde-0.4.0.md). | – |
