# DONE.md — von Claude abgenommene Aufgaben

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

**Offen:** nichts freigegeben; Alltagstest des Nutzers. Danach 0.3 (Start mit 196). 196 (Messwerkzeug) liegt im Backlog unter 0.3.
