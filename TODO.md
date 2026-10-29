# TODO.md — Index der offenen Arbeit

**Kurz halten.** Diese Datei ist der Einstieg für Host und Worker; Aufgabentexte stehen in den verlinkten Dateien. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). Versionsplan: README „Roadmap“, ausführlich [ROADMAP.md](ROADMAP.md). Erledigt: [DONE.md](DONE.md). Abnahme: [archiv/abnahme-ablauf.md](archiv/abnahme-ablauf.md). Komponenten: [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) (Quelle `layout/bis 0.4.1/Komponenten.dc.html`). Design: [layout/bis 0.4.1/Disk Index App.dc.html](layout/bis%200.4.1/Disk%20Index%20App.dc.html).

| Datei | Inhalt | Wer liest |
|---|---|---|
| [todo/regeln.md](todo/regeln.md) | 15 Regeln für den Worker (verbindlich, neu gefasst 23.10.) | Worker immer, Host bei Bedarf |
| [todo/funde-abnahmerunde-0.4.0.md](todo/funde-abnahmerunde-0.4.0.md) | Funde der Abnahmerunde (`bug.0.4.209`–`220`), Stand der Runde, Paketschnitt | Host |
| [todo/abnahmerunde-0.4.0.md](todo/abnahmerunde-0.4.0.md) | Checkliste der Abnahmerunde `todo.0.4.040` | Nutzer |
| [todo/backlog.md](todo/backlog.md) | nicht freigegeben, nach Zielversion | nur bei Planung |
| `archiv/todo-stand-*.md` | alte Fassungen (Volltexte abgenommener Pakete) | nur bei Bedarf |

## Kennungen (Nutzer 14.10.)

- **`todo.<Version>.<Nr>`** = Aufgabe (Funktion, Politur, Doku, Entscheidung).
- **`bug.<Version>.<Nr>`** = Fehler.
- `<Version>` ist die **Zielversion** aus der Roadmap (`0.4`, `0.3.2` …), `<Nr>` dreistellig und je Art und Version fortlaufend (Beispiel: `bug.0.4.014`). Die Kennung steht im Status, im Commit und in DONE.md. **Ausnahme (Host 16.10.):** Die schon vergebenen `bug.0.4.xxx` behalten ihre Nummern (sie stehen in Commits und DONE.md), auch wenn ihre Zielversion 0.3.8 oder 0.3.9 ist; maßgeblich ist die Spalte „Zielversion“ in der Paketliste. Neue Kennungen tragen die echte Zielversion (`bug.0.3.8.xxx`). Fehler-Nummern aus dem Audit 13.10. (`REPORT 54` …) stehen im Archiv `archiv/report-audit-2026-10-13.md`; jede Aufgabe nennt ihre Nummern.
- **Host und Worker** bestimmt der Nutzer bei der Übergabe (AGENTS.md). Worker (jeder Agent, auch auf einem anderen Gerät) arbeiten, der Host prüft und nimmt ab (Regel 15). `REPORT.md` bleibt leer; Fehler werden direkt hier als `bug.*` eingetragen.

## Stand

**Stand 28.10.2026 (Host):** Version im Xcode-Projekt **0.4.0**. Abgenommen bis einschließlich **Paket 45**, **Paket 46** (`bug.0.4.230`, SSD als SSD) in Korrektur, Nachtest des Nutzers bestanden; **Pakete 47–49 freigegeben 29.10.** (Nutzer „Alles“: Lesetempo, Fenstergröße, Rückfragen, Spaltenbreite, gesperrter Ordner), nacheinander; Entwurf Tester-Anleitung 0.4.1: [docs/anleitung-beta-0.4.1.md](docs/anleitung-beta-0.4.1.md) (Pakete 41 und 42 vorgezogen aus 0.4.1) (DONE.md; Ablauf: [konzept/lauf-lebenszyklus.md](konzept/lauf-lebenszyklus.md)). **Gesamtlauf 28.10. 01:05–01:35 grün** (seriell 1205/1205, parallel 3× grün, Sabotage 5/5, 0 Warnungen, keine `.ips`, 0 neue Dateien in `~/Library/Preferences`). Abnahmerunde `todo.0.4.040`: Funde `bug.0.4.209`–`220` (Pakete 34–36), aus dem Nachtest 27.10. `bug.0.4.222` (Paket 37) sowie `bug.0.4.221` und `223` (Paket 38), alle abgenommen. **Nachtest des Nutzers 28.10.:** „Alle Speichermedien vergessen“ geht beim Beenden verloren → `bug.0.4.224` (Stufe 1), **mit Paket 39 abgenommen** (Gesamtlauf 09:10–09:41; ein Hänger außerhalb des Diffs in Parallel 1, Backlog). **Nachtest 28.10. 11:20–11:45, Platte „Daten I“ (exFAT, 283 000 Einträge):** Indizieren liest Anfang und Ende jeder Datei, ohne es zu brauchen (`bug.0.4.225`), und der Store-Actor wartet dabei auf die Platte, sodass alle anderen Medien stehen (`bug.0.4.226`), beide Stufe 1 → **Paket 40, abgenommen 28.10.** (Gesamtlauf 12:47–13:25: seriell 1216/1216, parallel 2/3 grün, ein Zeittest außerhalb des Diffs im Backlog, Sabotage 5/5, 0 Warnungen). ****Gesamtlauf 28.10. 19:53–20:22 (nach Paket 41) grün:** Debug mit Testziel und Release 0 Warnungen, seriell 1216/1216, **parallel 3× grün** (je 1210, 6 übersprungen), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 20:22:34 (verlangt jetzt macOS 15). Damit ist Kriterium 4 erfüllt. Kein Auftrag an den Worker; Version bleibt 0.4.0 bis zur Bestätigung des Release-Kandidaten.** **Nachtest nach Paket 39 (28.10.): bestanden** (A1, B1–B3, C1–C3, D1–D6). Offen: Nachtest „Daten I“ und B4 (große Platte) mit der App von 13:25 ([todo/abnahmerunde-0.4.0.md](todo/abnahmerunde-0.4.0.md) Abschnitt 5). Ohne Fund der Stufe 1 ist 0.4.0 danach Release-Kandidat; Kriterium 4 (dreimal parallel grün) ist seit dem Gesamtlauf 28.10. 19:53–20:22 erfüllt, es fehlt nur noch der Nachtest des Nutzers (Kriterium 7). Checkliste der Abnahmerunde: [todo/abnahmerunde-0.4.0.md](todo/abnahmerunde-0.4.0.md). Befunde nach den drei Stufen (Nutzer 26.10., unten). Verfahren seit Paket 17: `todo/regeln.md` (15 Regeln), Sabotage als Patch (`Werkzeuge/pruefung.sh sabotage`, Regel 9), Invarianten in `konzept/architektur.md`, kleine Pakete (`archiv/abnahme-ablauf.md` 2a).

**Prüfung Host 26.10. 20:45–21:13 (Paket 33, Arbeitsbaum uncommittet seit e5718a9, macOS 15.7.4, Xcode 26.3, `Werkzeuge/pruefung.sh voll`, erste Prüfung nach den drei Stufen):** Debug mit Testziel und Release 0 Warnungen, seriell 1164/1164, Parallel 1–3 grün (je 1158 bestanden, 6 übersprungen), keine neuen `.ips`, 0 neue Dateien in `~/Library/Preferences`, Sabotage **4/4 rot ✓**, App des Nutzers 21:13:32, Version 0.4.0. Prüf-Agent (Sonnet): nichts Wesentliches gefunden. Ältere Prüfungen: `archiv/paket-*-abgenommen-*.md`.

**Abnahmekriterien 0.4.0 (alle müssen erfüllt sein):** (1) alle Kennungen von 0.4.0 vom Host abgenommen und in DONE.md; (2) Debug und Release inklusive Testziel 0 Warnungen; (3) serieller Gesamtlauf grün; (4) Parallellauf grün, dreimal hintereinander; (5) keine neuen `Disk Archive*.ips`; (6) App des Nutzers aktuell (Regel 14); (7) Abnahmerunde des Nutzers `todo.0.4.040`; (8) keine offene „Frage:“; (9) alle Sabotage-Patches rot (ab Paket 17); (10) nach dem Gesamtlauf keine neue Datei `app.diskarchive.tests.*` in `~/Library/Preferences` (ab Paket 33, `pruefung.sh` meldet es).

**Drei Stufen (Nutzer 26.10., ersetzt „Keine Schwelle“ vom 20.10., gilt ab Paket 33):** Jeder Befund nennt zuerst, was der Nutzer sieht und wann das im normalen Gebrauch passiert. Ohne Antwort ist es Stufe 3.
- **Stufe 1** (der Nutzer merkt es): eigene Kennung in 0.4.0.
- **Stufe 2** (nur bei seltener Ereignisfolge): 0.4.0 nur, wenn es in der echten App oder in einem realistischen Test auftritt; sonst Sammeleintrag in `todo/backlog.md`.
- **Stufe 3** (der Nutzer merkt es nie): keine Kennung.

Dazu kommen drei Prüfungen gegen Schleifen: schon behoben, bewusst so, sinnvoll. Regeln: AGENTS.md „Befunde: drei Stufen“.

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
| **29** | **0.4.0** | ~~`bug.0.4.204`~~ | Abschluss und Abbruch je Medium nacheinander (Umbau), schwache Tests → [archiv](archiv/paket-29-abgenommen-2026-10-26.md) | **abgenommen 26.10.** |
| 30 | **0.4.0** | ~~`bug.0.4.205`~~ | Überwachung: eine Prüfstelle für alle drei Startwege → [archiv](archiv/paket-30-abgenommen-2026-10-26.md) | **abgenommen 26.10.** |
| 31 | **0.4.0** | ~~`bug.0.4.206`~~ | Überwachung: `stop` im Lesefenster gewinnt (Generation je Medium) → [archiv](archiv/paket-31-abgenommen-2026-10-26.md) | **abgenommen 26.10.** |
| 32 | **0.4.0** | ~~`bug.0.4.207`~~ | Überwachung: Stream-Unmount nur für den eigenen Stream → [archiv](archiv/paket-32-abgenommen-2026-10-26.md) | **abgenommen 26.10.** |
| 33 | **0.4.0** | ~~`bug.0.4.208`~~ | Ein Ordner: alles in `Application Support/Disk Archive/`, Tests ohne `UserDefaults`, Schreibschranke enger → [archiv](archiv/paket-33-abgenommen-2026-10-26.md) | **abgenommen 26.10.** |
| **34** | **0.4.0** | `bug.0.4.210`, `209` + `216` | Fortschritt: eine Rechnung; Dialoge: Fokus nur beim Erscheinen, Stapel → [archiv/paket-34-abgenommen-2026-10-27.md](archiv/paket-34-abgenommen-2026-10-27.md) | **abgenommen 27.10.** |
| 35 | **0.4.0** | `bug.0.4.215`, `212`, `213`, `214` | Ersetzen zuerst, Filter und Scrollen, ← →, Auswahl bei Live-Verschieben → [archiv/paket-35-abgenommen-2026-10-27.md](archiv/paket-35-abgenommen-2026-10-27.md) | **abgenommen 27.10.** |
| **36** | **0.4.0** | `bug.0.4.211`, `218`, `219`, `220`, `217` | Layout: Kacheln, Spaltenbreite, Grauton, Pfad bündig, Spinner → [archiv/paket-36-abgenommen-2026-10-27.md](archiv/paket-36-abgenommen-2026-10-27.md) | **abgenommen 27.10.** |
| 37 | **0.4.0** | `bug.0.4.222` (221 → 38) | Nachtest: Fortschritt nach Wiedereinstecken → [archiv/paket-37-abgenommen-2026-10-27.md](archiv/paket-37-abgenommen-2026-10-27.md) | **abgenommen 27.10.** |
| 38 | **0.4.0** | `todo.0.4.049`, `bug.0.4.221` + `223` | Testpfad Layout; Dialoge: Fokus einmal beim Erscheinen, neuester vorn → [archiv/paket-38-abgenommen-2026-10-28.md](archiv/paket-38-abgenommen-2026-10-28.md) | **abgenommen 28.10.** |
| 39 | **0.4.0** | `bug.0.4.224` | „Vergessen“ sofort dauerhaft, Löschen im Hintergrund, Beenden ohne Hänger → [archiv/paket-39-abgenommen-2026-10-28.md](archiv/paket-39-abgenommen-2026-10-28.md) | **abgenommen 28.10.** |
| 40 | **0.4.0** | `bug.0.4.225`, `226` | Teil-Prüfsumme nur bei Bedarf lesen; Store-Actor ohne Plattenzugriff → [archiv/paket-40-abgenommen-2026-10-28.md](archiv/paket-40-abgenommen-2026-10-28.md) | **abgenommen 28.10.** |
| 41 | **0.4.1** (vorgezogen) | `todo.0.4.1.003`, `todo.0.4.1.001` | Mindest-macOS 15; DMG mit einem Befehl (`Werkzeuge/dmg-erstellen.sh`) → [archiv/paket-41-abgenommen-2026-10-28.md](archiv/paket-41-abgenommen-2026-10-28.md) | **abgenommen 28.10.** (Sichtprüfung des Nutzers 29.10. bestanden: Fenster 476, Hintergrund „Dunkel“, Icon mittig nach Paket 42) |
| 42 | **0.4.1** | `bug.0.4.1.001` | DMG: App-Symbol mittig auf dem Laufwerks-Icon → [archiv/paket-42-abgenommen-2026-10-29.md](archiv/paket-42-abgenommen-2026-10-29.md) | **abgenommen 29.10.** |
| **43** | **0.4.0** | `bug.0.4.227` | Großer Ordner mit gleich großen Dateien blockiert den Store (Nachtest E1/E2 29.10.) → [archiv/paket-43-abgenommen-2026-10-29.md](archiv/paket-43-abgenommen-2026-10-29.md) | **abgenommen 29.10.** |
| **44** | **0.4.0** | `bug.0.4.228` | Abfragen über das ganze Medium je Ordner: Abgleich „Daten I“ > 30 min bei 99 % (Nachtest 29.10.) → [archiv/paket-44-abgenommen-2026-10-29.md](archiv/paket-44-abgenommen-2026-10-29.md) | **abgenommen 29.10.** |
| **45** | **0.4.0** | `bug.0.4.229` | Verschobener Ordner auf FAT/exFAT verliert beim Wiederanstecken seinen Favoriten (Nachtest E5 29.10.) → [archiv/paket-45-abgenommen-2026-10-29.md](archiv/paket-45-abgenommen-2026-10-29.md) | **abgenommen 29.10.** |
| **46** | **0.4.0** | `bug.0.4.230` | Externe SSDs erscheinen als „HDD“: Typ aus „Solid State“ (IOKit), wechselbar bleibt USB (Nutzer 29.10.) → [todo/paket-46.md](todo/paket-46.md) | **Korrektur 29.10.** (Gesamtlauf 20:06–20:38: nur ein Quelltext-Test rot) |
| 47 | **0.4.0** | `todo.0.4.051`, `bug.0.4.231` | Lesetempo nach Plattentyp (SSD 4, drehend 1); Medium ohne Zugriff zeigt alten Typ (Nutzer 29.10. „Alles“) → [todo/paket-47.md](todo/paket-47.md) | **freigegeben 29.10.**, startet nach Abnahme 46 |
| 48 | **0.4.0** | `todo.0.4.050`, `bug.0.4.234`, `232`, `233` | Erste Fenstergröße 1258 × 770; Spaltenbreite nach Umbenennen; „Behalten“ gemerkt; keine falsche Rückfrage beim Start → [todo/paket-48.md](todo/paket-48.md) | **freigegeben 29.10.**, nach 47 |
| 49 | **0.4.0** | `bug.0.4.235` | Gesperrter Ordner: keine Wiederholung bei „keine Rechte“, Unterordner nicht einzeln lesen → [todo/paket-49.md](todo/paket-49.md) | **freigegeben 29.10.**, nach 48 |
| – | **0.4.0** | `todo.0.4.040` (Nutzer) | Abnahmerunde: echte Medien, Layout → Release-Kandidat; Checkliste [todo/abnahmerunde-0.4.0.md](todo/abnahmerunde-0.4.0.md) | **läuft** (Nachtest nach Paket 39 bestanden; E1/E2 29.10. nicht bestanden → Paket 43 abgenommen; Nachtest 29.10. 12:55–13:50: E1 Erstindex 25 min ok, E2–E4 ok, Abgleich > 30 min → Paket 44 abgenommen (Gesamtlauf 16:01–16:33 grün); Nachtest 16:45–16:57: Erstindex 1 min 53 s, Abgleich 1 min 14 s ok, E5 mit Ordner nicht bestanden → Paket 45 abgenommen (Gesamtlauf 18:03–18:36 grün); SSD-Typ → Paket 46; 22:07–22:23 alle Testmedien neu indiziert, B4 bestanden („Daten“ 7 min 53 s, 1,6 Mio. Dateien, 0 Lesefehler); E5 bestanden (Datei belegt, Ordner laut Nutzer); **Abnahmerunde ohne offenen Punkt**, Release-Kandidat nach Abnahme der Pakete 46–49) |
| – | **0.4.1** | `todo.0.4.021`, `024`, `todo.0.4.1.002`, Aufwärtstest macOS 27 (`022` entfällt; `todo.0.4.1.001`, `003` → Paket 41) | Release der Open Beta → [todo/backlog.md](todo/backlog.md) | Backlog |

## Entscheidungen des Nutzers

**Offen:** keine.

**Entschieden 28.10.:** Abgleich nach dem Aufwachen des Macs bleibt: jedes verbundene, indizierte Medium wird einmal still abgeglichen (`bug.0.4.028`, Konzept `indizieren.md`).

**Entschieden 25.10.:** `bug.0.4.151` (dauerhafte Lücke) → Status „Fehler“, Fortschritt als Zeile „Indiziert“ im Details-Modal (`bug.0.4.199`, Paket 26). Knopf „Datenhygiene“ in den Einstellungen: nicht bauen (Nutzer macht das später selbst; Testreste räumt der nächste Testlauf auf, `bug.0.4.124`).

**Entschieden 23.10.:** `bug.0.4.153` Einstellungen nicht lesbar → Hinweis im Einstellungsfenster, keine Indizierung/kein Abgleich in der Sitzung, beim nächsten Start neu lesen (Vorschlag Host, vom Nutzer bestätigt).

**Entschieden 20.10.:** Wartescreen der Suche nur aus dem Leerzustand; Rollbalken nur Platz, keine leere Leiste; Sicherungskopie vor Schema-Erweiterung erst zu 1.0 (`bug.0.4.106`, Backlog); eingereihte Berichte gehen auch nach dem Ausschalten von „automatisch senden“ raus. Ältere Entscheidungen (16.10.: `todo.0.4.030`–`039`): `archiv/todo-stand-2026-10-23-vor-abnahme-paket13.md`.

## Nutzer und Host (ohne Worker)

| Kennung | Was | Wer |
|---|---|---|
| `todo.0.3.2.001` | **Erledigt 25.10.:** Layout 02 → `todo.0.4.048`; Layout 04 per Screenshot des Nutzers (Dashboard-Karten: Belegung links, Uhr + Zeit rechts, eine Zeile) – die App setzt das schon so um (`MediumDashboardCard`); die HTML-Datei wird nicht nachgezogen. Weitere Layout-Fragen erst zu 0.4.1, nur auf Nachfrage. | – |
| `todo.0.4.045` | **Erledigt 25.10.:** Die 8.600 alten Test-`.plist` sind weg (seit `bug.0.4.124` räumt jeder Testlauf die des vorigen auf; übrig bleiben nur die ~90 des letzten Laufs). Löschbefehl und Checkliste: [todo/abnahmerunde-0.4.0.md](todo/abnahmerunde-0.4.0.md). | – |
