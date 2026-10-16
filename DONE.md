# DONE.md — von Claude abgenommene Aufgaben und Fehler

Kennungen: bis 233b alte Aufgabennummern; ab 12.10. `todo.<Version>.<Nr>` (Aufgabe) und `bug.<Version>.<Nr>` (Fehler), Tabelle unten.

Nur Claude pflegt diese Datei. Eine Aufgabe steht hier erst nach Prüfung von Code, Tests und (bei Optik) Bildschirmfotos gegen README und Layout. Volltexte, Spezifikationen und Statusblöcke liegen im Archiv, diese Datei ist nur das Register.

| Nr. | Thema | Abnahme | Volltext |
|---|---|---|---|
| bis 88 | Grundgerüst: Erkennung, Medien-Lebenszyklus, Indizierung, Live-Überwachung, Suche, Favoriten, Einstellungen (4 Tabs), Fehlerbericht, Menüleiste, Popover, Pausieren, Dunkelmodus, Icon, Dock-Verhalten, Indizierungsfehler-Dialog, Bestätigungsmodus | 02.–04.10. (Code, Bildschirmfotos, am echten Stick) | `archiv/prompt-verlauf-bis-2026-09-28.md` |
| 100 | Tests grün, `hasIndex` zurückgenommen | 05.10. | ebenda |
| 101 | Datenbank-Zähler nicht mehr O(N) je Schreibvorgang | 05.10. | ebenda |
| 103 | Lesen mit `getattrlistbulk` richtig; Messung am Stick (Release): 30.000 Dateien in 13 s | 05./06.10. | ebenda, `archiv/prompt-spezifikationen-paket2-2026-10-05.md` |
| 104 | Schreiben in Stücken, Live-Sync gedrosselt | 06.10. | ebenda |
| 105 | Fortschritt in Prozent (erst zählen, dann indizieren, stetig) | 06.10. | ebenda |
| 106 | Immer vollständiger Abgleich beim Anschließen | 06.10. | ebenda |
| 108 | Stresstest-Werkzeug (`Werkzeuge/stresstest.sh`) | 06.10. | ebenda |
| 115 | Chip-Texte nur nach Layout | 05.10. | ebenda |
| 116 | Chips werden nie gekürzt | 05.10. | ebenda |
| 117, 118 | Paket-1-Abschluss, Texte, Bildschirmfotos | 05.10. | ebenda |
| 120 | Test-Isolation (`IndexingRunLimits`), Zahlenformat mit Punkt | 06.10. (Code, Unit-Tests) | `archiv/prompt-stand-2026-10-06.md` |
| 121 | T4 („Artefakt-Kategorien“, „Trotzdem einschließen“) zurückgebaut | 06.10. (Code) | ebenda |
| 102 | Spalten-Cache gezielt invalidieren, Wettlauf-Schutz | 06.10. (Tests grün) | `archiv/prompt-stand-2026-10-06.md` |
| 114 | Spaltenzustand je Ordner (Layout 07, ohne Info-Chips) | 06.10. (Bildschirmfotos `2026-10-06-r2`) | ebenda |
| 119 | Rote Vorschlagstexte, Bildschirmfotos | 06.10. | ebenda |
| 109 | Fehlerbehandlung: Cancellation, stille Datenbankfehler protokolliert | 06.10. (Code, Tests) | `archiv/prompt-stand-2026-10-06.md` |
| 107 | Große Ordner: Index, Keyset, `NSTableView`, Messung Release (200.000 Zeilen < 2,1 s, Hauptfaden < 3 ms) | 06.10. (**Rückschritt 07.10.:** im echten Fenster bleiben Ordnerspalten leer → Aufgabe 122) | `archiv/prompt-stand-2026-10-06.md` |
| 110 | Toter Code entfernt, Debug-Werkzeuge in `DebugTools/`, Testhilfen verschoben | 07.10. (Code, Tests) | ebenda |
| 112 | Layout-Abgleich: 3 px, Mitteilung bei Indizierungsfehler, Texte in `LayoutCopy` (Rest: blaues Symbol im Layout = Nutzer) | 07.10. | ebenda |
| 113 | Button-Regeln: gleiche Größe je Gruppe, `ButtonStyles.swift` | 07.10. (Bildschirmfotos, Messtest) | ebenda |
| 111 | Struktur: `RestModels` aufgelöst, `IndexStore` (630 Z.), `AppState` (298 Z.) geteilt, Simulation nach `DebugTools`, Test-Sammeldateien geteilt; wackelnder Icon-Test behoben | 07.10. (276 Tests seriell 2× grün, Release ohne Warnung) | `archiv/todo-stand-2026-10-07.md` |
| 122–139 | Spaltenansicht (Zeilen, lange Namen, Statusflächen mit Restbreite), Medienliste, Bestätigungsknopf, Dashboard-Kachel, Klickflächen, Mitteilungen, Leerzustände, Einstellungen, Knopfmaße | 07.10. (Nutzertest, Fotos) | `archiv/todo-stand-2026-10-08.md` |
| 140–149 | Echte Tests (Mausereignisse), Autostart-Handoff, Auto-Senden, Abstände, Knopfrahmen, Leerzustände Suche/Favoriten/Speichermedien, Ja/Nein ohne Flackern | 07.10. | ebenda |
| 150 | Spalten oben statt mittig (`FadeMaskText` ohne gierigen Behälter), Testhilfe `PixelProbe` | 08.10. | ebenda |
| 151 | Fortschritt nur in Prozent, Balken an derselben Quelle, keine Dateizahlen | 08.10. | ebenda |
| 152 | Pfadmarkierung deckend schwarz, keine Scrollspur, Demo-Ladefläche sofort | 08.10. | ebenda |
| 154 | Autostart: Layout-Checkbox, Zweitinstanz `--background` beendet sich ohne Dock | 08.10. (Dock: Nutzer prüft) | ebenda |
| 156 | Spaltenrand flackert nicht mehr beim Laden | 08.10. | ebenda |
| 157 | Demo-Medium nur in der Spaltenansicht, stimmige 42 % | 08.10. | ebenda |
| 158–166 | Layout-Checkbox überall, Popover-Zeile fest 56 pt, „Neu indizieren“-Sperre (sofort, bis 59 s nach Ende), Fortschritt min. 1 s, Autostart-Kästchen sofort, Status-Icons nach Layout, Sprach-Dropdown nach Layout, Mitteilung an/aus mit 5-s-Sperre, Icon-Füllung 50 % (Wahl offen) | 08.10. | `archiv/todo-stand-2026-10-08b.md` |
| 167–171 | Einstellungen ohne Systemaufrufe im Zeichenpfad, Mitteilung an/aus in richtiger Reihenfolge, Fortschritt 0,6 s bis 100 %, Sprach-Dropdown oben, Layout-Entscheidungen (Hover-Reset, Pausentexte, kein blauer Spinner) | 08.10. (Hover-Reset: Nutzer prüft) | `archiv/todo-stand-2026-10-08c.md` |
| 172 a, c, d, e | Keine Scrollspur auch bei klassischen Rollbalken (`.never`), Beispielkasten „Medien werden wieder indiziert.“, Bestätigungsknopf nur 3-s-Reset, Sprach-Dropdown: eigener Abschnitt, kein Fokuseffekt | 09.10. (Claude-Lauf 348 Tests seriell grün; Dropdown-Gefühl: Nutzer prüft) | `archiv/todo-stand-2026-10-09.md` |
| 174 a–c | Live-Überwachung startet auch nach dem Erstlauf eines neuen Mediums und nach „Neu indizieren“ (`LiveWiring`), Protokoll start/stop, Test mit echtem FSEvents auf Disk-Image | 09.10. (Claude-Lauf 349 Tests seriell grün; Echttest neues Medium: Nutzer) | `archiv/todo-stand-2026-10-09b.md` |
| 173 a | Fenster-/Singleton-Suiten unter einer seriellen Elternsuite `WindowTestGroup` | 09.10. | ebenda |
| 176 a–d | Spalte behält bei Live-Änderung den alten Inhalt bis zum Tausch (veraltet statt leeren), sichtbare Spalten laden sofort neu | 09.10. (Claude-Lauf 352 Tests seriell grün; Echttest Stick: Nutzer) | `archiv/todo-stand-2026-10-09c.md` |
| 175 b, c | Ereignisstand nur bei Änderung schreiben, ChangeWatcherTests seriell; parallel 3× grün (Cursor) | 09.10. | ebenda |
| 178 | Überwachung startet bei jedem Einhängen und nach dem Aufwachen neu, Unmount im Strom beendet sie | 09.10. | `archiv/todo-stand-2026-10-09d.md` |
| 179 a–e | Überwachung nach jedem fertigen Lauf, Abgleich nach Pausenende, Überlauf = Abgleich (einmal nachgeholt), Vergessen beendet Lauf/Überwachung, neuer Wurzelordner ohne Vollabgleich (179 f entfällt) | 09.10. | ebenda |
| 181 a, c | Live-Änderungen melden den aufgelösten Elternordner (`DirectoryWriter.apply` → `parentPath`), Unterordner-Spalten werden invalidiert; Store-Test mit Sabotage | 09.10. (Claude-Lauf 359 Tests seriell grün; Nutzer testet App) | `archiv/todo-stand-2026-10-09e.md` |
| 180 b | Vergessen-Hook `async`, vor dem Löschen abgewartet | 09.10. | ebenda |
| 183 | Store → Spalte: Zähler je Meldung (`IndexChangeEvent`), Pfade sammeln statt ersetzen, „verloren“ = Medium veraltet; `ColumnChangeLoopTests` ohne Nachhilfe; Testfenster außerhalb des Bildschirms; `live-kette-pruefen.sh` | 09.10. (Claude-Lauf 363 Tests seriell grün) | `archiv/todo-stand-2026-10-09f.md` |
| 182 a | Live-Tests (Unterordner, Remount) ohne Nachhilfe, Fenster vor der Änderung offen | 09.10. | ebenda |
| 184 | Mindest-macOS 14.0 (`pointerStyle` mit Ausweichweg, `SizeKey`); Laufzeittest auf 14 offen | 09.10. | ebenda |
| 185 a–c, e | Umbenennung „Disk Archive“, `app.diskarchive`, Pfade, Logger, Launch-Agent; keine sichtbaren „Disk Index“ mehr | 09.10. | ebenda |
| 186 | Übernahme entfernt, Testziel 0 Warnungen (Claude bestätigt nach `clean`), Ruhe-Test Spalten | 09.10. (Claude-Lauf 374 Tests seriell grün) | `archiv/todo-stand-2026-10-09g.md` |
| 189 a | Zentraler Knopfstil `.plainFullHit`, 30 Stellen ersetzt, Suchbefehl leer | 09.10. | ebenda |
| 190 | Dashboard-Kachel: Uhr-Symbol + Kurztext nach Layout, „jetzt“ wenn angeschlossen, lokalisiert | 09.10. | ebenda |
| 191 | Einstellungen: Mitteilungen in Allgemein; Erweitert = Autostart, Fehlerberichte, Lösch-/Rücksetzknöpfe; Reihenfolge-Test mit echter Sabotage | 09.10. | ebenda |
| 187, 188 (Code) | Waagerechte Leiste über der Statusleiste (`contentMargins`), automatisch nach rechts (`ScrollViewReader`) — Tests noch nicht scharf, siehe 192 | 09.10. | ebenda |
| 192 | Tests scharf (Sabotagen a, b, d rot ✓; c und e begründet: Innenabstand allein trägt, Ruhe-Test zählt `requestLoad`-Aufrufe), Innenabstand nur bei Überlauf, Altprüfung Autostart entfernt, Testfenster ohne Systemklicks/Doppelfreigabe | 10.10. (Claude-Lauf 380 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-10.md` |
| 193 | Fehlerbericht: Erfolg = 201 mit `id`, Debug lokal, Release `https://diskarchive.app/api/issues/` | 10.10. | ebenda |
| 194 | Systemanfragen „Disk Archive“, Netzlaufwerke-Text, Englisch | 10.10. (plutil geprüft) | ebenda |
| 195 a, b | `MustScanSubDirs` an/unter dem Einhängepunkt → Abgleich, außerhalb ignoriert; `.counts` verwirft keine geplante Spalten-Invalidierung mehr (Sabotagen von Claude nachgestellt: rot ✓) | 10.10. (Claude-Lauf 383 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-10b.md` |
| 197 | FAT-Test meldet Fehler sichtbar, Abbild 64m (lief vorher nie) | 10.10. (Claude-Lauf 380 Tests seriell grün, 0 Warnungen; Ersatz-Agent) | `archiv/todo-stand-2026-10-10d.md` |
| 198 | Systemscrollleisten: senkrecht je Spalte, waagerecht über der Statusleiste (beide Stile getestet) | 10.10. | ebenda |
| 199 | Detail-Spalte nur bei Datei oder Mehrfachauswahl | 10.10. | ebenda |
| 200 | Demo-Medium „Spalten-Zustände (Demo)“ entfernt, Tests auf echte Daten | 10.10. | ebenda |
| 201 | Toter Code, nur von Tests benutzte Logik und Doppeltes entfernt; `RuntimeEnvironment`, `IndexRunTypes` | 10.10. (Claude-Lauf 387 Tests zweimal seriell grün, 0 Warnungen; Ersatz-Agent) | `archiv/todo-stand-2026-10-10e.md` |
| 202 | Fehlergrund aus dem Fehlerobjekt bis in den Dialog | 10.10. | ebenda |
| 203 | Englisch vollständig (72 neue Schlüssel, `docs/englisch-neu.md`), Zahlen und Uhrzeit nach App-Sprache, Quell-Scan-Test | 10.10. | ebenda |
| 205 | Tests mit eigener Einstellungsdatei (`AppDefaults.current`), echte Datei aufgeräumt | 10.10. (Claude-Lauf 390 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-10f.md` |
| 206 | Vorlauf: Ebene 1 und 2 vor der Zählung gespeichert (1 TB nach Sekunden sichtbar) | 10.10. (Claude-Lauf 393 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-10g.md` |
| 207 | Debug-Prototypen und Diagnosefenster entfernt, 26 Übersetzungsschlüssel weg | 10.10. | ebenda |
| 208 | Testläufe räumen fremde Test-Einstellungsdateien auf; F11 geklärt (Test wartete nicht auf den Dialog) | 10.10. | ebenda |
| 209 | Vorlauf zeigt die Zählanzeige (ein `.counting`-Ereignis zu Beginn) | 11.10. (Claude-Lauf 395 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-11.md` |
| 210 | Kein Phasen-Blinken beim Abgleich, Spinner dreht überall (Winkel aus der Zeit) | 11.10. (Claude-Lauf 407 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-11b.md` |
| 211 | Suche: Zahl ohne Obergrenze, kein Flackern (alte Ergebnisse bleiben, Neustart höchstens alle 2 s), X leert | 11.10. | ebenda |
| 212 | Scrollleisten in Suche (Breite per Preference statt GeometryReader), großen Ordnern, Einstellungen (Wächter) | 11.10. | ebenda |
| 213 | Prozent im Popover rechtsbündig | 11.10. | ebenda |
| 214 | Rote Vorschlagstexte sind normale Texte (de/en), Rot-Mechanismus entfernt | 11.10. | ebenda |
| 215 | Suche: Ergebnisse sofort, Trefferzahl nachgereicht („–“ bis dahin), neue Suche bricht alte Zählung ab | 11.10. (Claude-Lauf 411 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-11c.md` |
| 216 | Namensprüfung nur bei ausstehender Bereinigung (`IndexScope.checksNames`), sonst reines SQL (0,4 s statt 4,4 s) | 11.10. | ebenda |
| 217 | Wackeltest `fastLoadNeverShowsHint` robust (5/5 parallel grün) | 11.10. (Claude-Lauf 416 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-11d.md` |
| 218 | Ergebnistabelle (Suche, Favoriten) über die ganze Breite, Status rechts; eigenes `ObjectTableRowLayout` statt Breitenmessung (Rückschritt aus 212) | 11.10. | ebenda |
| 219 | Startreihenfolge: Symbol sofort, Datenbank im Hintergrund, `quick_check` nur nach unsauberem Ende oder alle 7 Tage | 11.10. (Claude-Lauf 421 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-11e.md` |
| 196 | Messwerkzeug Datenbank (`IndexBenchTests`, `DA_BENCH=1`, `Werkzeuge/db-messung.sh`), Messung „vorher“ S1 1 Mio. / S2 8,6 Mio. | 11.10. (Claude-Lauf 423 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-11g.md` |
| 220 | Version 0.2.0, Build-Nummer automatisch (Zeitstempel) | 11.10. (Claude-Lauf 425 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-11h.md` |
| 221 | „Über Disk Archive“ (Menüleiste, Programm-Menü, Link), ⌘, öffnet Einstellungen | 11.10. (Claude-Lauf 438 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-11j.md` |
| 230 | Schema V3 angelegt (11 Tabellen, Suchhilfen), Slug, natürliche Sortierung, ItemKind | 11.10. | ebenda |
| 231 | Schreibwege V3 (`IndexStoreV3`, `IndexWriting`), Status „verschwunden“, Lauf-Nummer, WAL kürzen | 11.10. (Claude-Lauf 463 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-11k.md` |
| 232 | Lesewege V3 (`IndexReading`), natürliche gemischte Sortierung, Pfad per Kette, parallele Suche über `slug`, Mediennamen | 11.10. (Claude-Lauf 477 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-11l.md` |
| 222 | Wackeltests stabilisiert (fester Spinner-Winkel im Test, Vertrag `==` statt Zeichenläufe) | 12.10. (Claude-Lauf 473 Tests seriell grün, 0 Warnungen) | `archiv/todo-stand-2026-10-12.md` |
| 233 | Umschalten: App nur noch V3 (`archive.sqlite`, Migration `0.3.0-schema`), alte Schicht entfernt, `lastSeenRun` weg, `unreadable` zurückgesetzt, nur `.app`/`.dmg`/`.pkg` = Programme, veraltete Zusatzdaten fallen, Bereinigen 100.000 in 1,5 s | 12.10. (Claude-Lauf 473 Tests seriell grün, 0 Warnungen, Regel 23 ✓) | `archiv/todo-stand-2026-10-12.md` |
| 233b | `auto_vacuum = 2` auf neuer Datei (vor WAL, `prepareNewFile`), Test mit Sabotage | 12.10. (Claude: Build 0 Warnungen, 16 Schema-/Umschalt-Tests grün, 474 laut Agent; App von Claude neu gebaut 09:16) | `archiv/todo-stand-2026-10-12b.md` |

**Prüfzeichen (Claude 14.10.):** **A** = Gesamtlauf 554/554 Tests seriell grün (Stand `64f4e0c`); **B** = die genannten Symbole sind im Code vorhanden und verdrahtet (Stichprobe per Suche); **C** = Code selbst gelesen. Alles bis 233b (oben) hat Claude jeweils zum Abnahmezeitpunkt mit eigenem Lauf geprüft. Die Spur von Cursor (12./13.10., Claude war nicht verfügbar) ist von Cursor am Code gelesen und gilt erst mit A+B als von Claude bestätigt; **offen aus der Spur:** 23 Compiler-Warnungen (Regel 7) → `bug.0.4.010`.

## Seit 12.10. — Kennungen `todo.<Version>.<Nr>` und `bug.<Version>.<Nr>`

| Kennung | früher | Inhalt | Abgenommen | Prüfung |
|---|---|---|---|---|
| todo.0.3.2.003 | c.0.3.2.002 / 002b | Erkennungs-Stapel (je Medium ein Dialog), kein Index ohne Entscheidung, Dashboard-Meta (REPORT 16, 17) | 12.10. Cursor | A B |
| bug.0.3.2.001 | c.0.3.2.003 | Store-Öffnen, Retry, Integritätsfehler (REPORT 2, 3, 4, 5, 22, 28) | 12.10. Cursor | A B |
| bug.0.3.2.002 | c.0.3.2.004 | FSEvents-/Watcher-Lebenszyklus (REPORT 6, 8, 9, 10) | 12.10. Cursor | A B |
| bug.0.3.2.003 | c.0.3.2.005 | Suche und Spalten: Scope und Seiten (REPORT 11, 12, 19, 20) | 12.10. Cursor | A B |
| bug.0.3.2.004 | c.0.3.2.006 | IndexingService finish/cancel/Recount (REPORT 13, 15, 26) | 12.10. Cursor | A B |
| bug.0.3.2.005 | c.0.3.2.007 | Oberfläche, Beenden, Meta (REPORT 14, 18, 21, 23, 24, 25, 27) | 12.10. Cursor | A B |
| todo.0.3.234 | c.0.3.234 | Status-Flag und Warteschlange für Regeländerungen (F25) | 12.10. Cursor | A B |
| todo.0.3.235 | c.0.3.235 + 235b | fileID erfassen, Umbenennen/Verschieben erkennen, Ereignispaare, FAT-Merkmale, Teil-Prüfsumme | 12.10. Cursor | A B |
| todo.0.3.236 | c.0.3.236 | Wartung nach Zeit und Zähler, WAL kürzen, Leerlauf-Verkleinern (F26) | 12.10. Cursor | A B |
| todo.0.3.237 | c.0.3.237 | Einstellungen in der Tabelle `settings` (außer Sprache, Fensterposition) | 12.10. Cursor | A B |
| todo.0.3.238 | c.0.3.238 | Messung „nachher“, Vergleich, Bericht, Schema eingefroren; Größe und Abfrage bestanden | 12.10. Cursor | A (Berichte in `Werkzeuge/messung/`) |
| todo.0.3.1.001 | c.0.3.1.001 | API-Warteschlange `api_queue`, Netzmeldung plus 60-s-Ping | 12.10. Cursor | A B |
| bug.0.3.239 | c.0.3.239 | `invalidateAll` bumpt Generationen (REPORT 29) | 13.10. Cursor | A C |
| bug.0.3.240 | c.0.3.240 | `api_queue`: Busy-Timeout, Flush einfach, Leak-Zeilen, Netz-Zustand (REPORT 30, 31, 33, 37) | 13.10. Cursor | A B |
| bug.0.3.241 | c.0.3.241 | Wartung und Regel-Reconcile nach Fehler (REPORT 32, 36) | 13.10. Cursor | A B |
| bug.0.3.242 | c.0.3.242 | FAT: gone-Ordner nur mit Name und Eltern (REPORT 34) | 13.10. Cursor | A B |
| bug.0.3.243 | c.0.3.243 | Ordner-Umbenennen live, Kind-Tiefen (REPORT 35) | 13.10. Cursor | A B |
| bug.0.3.244 | c.0.3.244 | Spaltenansicht 50.000: Guard bestanden (REPORT 39, F29) | 13.10. Cursor | A (Messung `2026-10-13-spalten-244-final-vergleich.md`) |
| bug.0.3.245 | c.0.3.245 | Spalten-Cache: missing-folder mit Generations-Prüfung (REPORT 51) | 13.10. Cursor | A B |
| bug.0.3.246 | c.0.3.246 | Live-Rename gone-Clash, Build-Zeit in UTC (REPORT 52, 53) | 13.10. Cursor | A B |
| todo.0.4.001 | c.0.3.3.001 | Versions-Check, Update-Modal mit „überspringen“, Beta-Sperre, Nur-Lesen-Schranke (`FeatureAccess`) | 13.10. Cursor | A B |
| bug.0.4.001 | c.0.3.3.002 | Nur-Lesen-Sperre geschlossen (REPORT 42–50) | 13.10. Cursor | A B |
| bug.0.4.043 | – | „Ja“ nach „Nein“ springt nicht mehr zurück (`publish` lässt Nutzerfelder stehen, solange ein Schreibvorgang aussteht); Test `AllowIndexingToggleRaceTests` | 14.10. Claude | A C |
| todo.0.4.010 | – | Purge: 14 tote Namen entfernt, Test-Hilfen in `IndexStoreV3TestHooks` (Test-Ziel); `hasCachedChildren` nur noch `#if DEBUG` | 14.10. Claude | A B |
| todo.0.4.011 | – | Kaltstart öffnet Menüleiste und Hauptfenster; Anmeldung: durch `todo.0.4.013` ersetzt | 14.10. Claude | A C |
| todo.0.4.012 | – | Panel „Neues Speichermedium“ an Standardposition (mittig, 38,2 % von oben), nicht gemerkt, reine Rechenfunktion mit Test | 14.10. Claude | A C |
| bug.0.4.010 | – | Warnungen 0 (Debug/Release), `partialMatching` als Parameter, Wackeltests stabilisiert (Rest in `bug.0.4.044`) | 14.10./15.10. Claude | A |
| bug.0.4.044 | – | Parallellauf grün: Zeit-Test nur unter `DA_BENCH` (plus Test ohne Zeitgrenze), `ChangeWatcherTests` wartet auf Bedingung, Test-Schalter isoliert | 15.10. Claude | A |
| bug.0.4.011 | – | Datei-Protokoll ohne `privateDetail` (nur `pathDepth`/`pathLen`), Fehler als `domain/code/posix` über `DiskIndexLog.errorSummary`, `os_log` privat, Suchbegriff nicht protokolliert, Scrubber: Pfade bis Zeilenende, typografische Anführungszeichen, nur eigene Profile | 15.10. Claude | A C |
| bug.0.4.012 | – | Leak-Wächter prüft den dekodierten JSON-Inhalt, Namen mit Wortgrenzen (≥ 4 Zeichen, Ausschlussliste), Medien­namen im Hintergrund geladen | 15.10. Claude | A C |
| todo.0.4.013 | ersetzt `todo.0.4.011` b | Jeder Start (Klick, Anmeldung, Handoff) zeigt Menüleiste und Hauptfenster, Versions-Check bei jedem Start sofort (`force: true`) | 15.10. Claude | A C |
| bug.0.4.013 | – | App öffnet keine neuere Datenbank (`hasBeenSuperseded` → `schemaSuperseded`), Migration `0.4.0-items_gone` (Teilindex, im Plan belegt), Kandidatenabfrage mit Literal `status = 2` | 15.10. Claude | A C |
| bug.0.4.014 | – | Abgebrochener Abgleich: Datenbank bleibt `.indexed`, Ergebnis „unterbrochen“, verschwundene Einträge nur nach vollständigem Lauf gelöscht, Token-Aufräumen; Repro `nr58/59/67` grün | 15.10. Claude | A C |
| bug.0.4.015 | – | FAT/exFAT/NTFS: Verbindungs-Nachlauf vor `deleteGoneItems` (Umbenennen/Verschieben außerhalb), gleiche Ebene über „frei gewordene Namen“; echte Läufe über `DirectoryIndexer` (`FatReconnectIndexerTests`) | 15.10. Claude | A C |
| bug.0.4.016 | – | fileID-Zweig: nur gleiche Ebene entfernt gleichnamige Zeile, Kind-Tiefen angepasst, zwei Durchgänge (nicht mehr von der Reihenfolge abhängig), Hardlinks (`LINKCOUNT`) verbinden nicht, Bulk-Offsets korrigiert; Repro `nr57/nr69` grün | 15.10. Claude | A C |
| bug.0.4.017 | – | Live-Rename: fehlender Elternordner ist nicht mehr „Wurzel“, Inode-Prüfung (`nr70`), Papierkorb-Ereignisse außerhalb des Bereichs verworfen (`nr56`), Mount-Präfix als Text statt `standardizedFileURL`; `LiveRenameReproTests` | 15.10. Claude | A C |
| bug.0.4.018 | – | Ereignisse im Inneren von Paketen lesen den Ordner des Pakets neu, kein Voll-Abgleich; `PackageAndTrashesWatcherTests` | 15.10. Claude | A C |
| todo.0.4.014 | – | Nur-Lesen-Nachweis: `WriteGuard.permits` mit Erlaubnisliste (Datenordner, Protokoll, Voreinstellungen, Temp, Caches), Aufrufer überspringen das Schreiben, `blockedWriteCount`; Wächter-Test über den Quelltext mit Sabotage; Teil-Prüfsumme auf schreibgeschützter Datei; kein `assertionFailure` (Absturz im Testlauf 15.10., Fehler im Auftrag, korrigiert) | 16.10. Claude | A C |
| bug.0.4.019 | – | Flush je Medium serialisiert (`flushInFlight`/`flushAgain`), Abbruch ohne Voll-Abgleich, Meta-Delta bei Fehler zurückgelegt, Pause an/aus mit Generationszähler; Repro `nr66/nr99` | 16.10. Claude | A C |
| bug.0.4.020 | – | Indexer: Schreibfehler (`IndexWriteFailed`) getrennt von Lesefehlern, `DirectoryReadStalled` ohne Wiederholung, Halt sofort; `IndexerWriteReproTests` | 16.10. Claude | A C |
| todo.0.3.2.002 | – | `MARKETING_VERSION` 0.3.2 (6 Stellen in `project.pbxproj`), `BundleVersionTests`/`AboutAndSettingsMenuTests` angepasst | 16.10. Claude | B C |
| bug.0.3.8.001 | – | Nacharbeit Paket 4 Teil A: `WatcherFlushReproTests` ohne `lock()` über `await`; Existenzprüfung und Metadaten bei Teil-Prüfsumme und Live-Umbenennung außerhalb des Store-Actors (b2: `fileExists` im losgelösten Task, Test mit hängender Prüfung); Elternordner je Paar in `ChangeWatcherEngine`; `LiveWatchScope` nur `isPackageKey` | 16.10. Claude (seriell 623/623, Debug mit Testziel und Release 0 Warnungen) | A C |

**Doku erledigt (Claude 14.10.):** REPORT 38 (kein Fix, nur Zeitstempel), 40 (Messbericht), 41 (Layout-Reminder), README „Architektur“ und Abschnitt „Datenbank“ neu, ROADMAP abgeglichen, `datenbank-konzeption.md` und `todo-audit.md` aufgelöst (Archiv: `archiv/datenbank-konzeption-bis-2026-10-14.md`, `archiv/todo-audit-2026-10-13.md`), REPORT in `archiv/report-audit-2026-10-13.md`.

**Offen:** siehe [TODO.md](TODO.md).
