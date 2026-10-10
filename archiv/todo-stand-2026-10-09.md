# TODO.md — offene Aufgaben für Cursor

Einzige Aufgabenliste. Erledigtes steht in [DONE.md](DONE.md), Verlauf und alte Spezifikationen in `archiv/`. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). **Komponenten (Maße, Farben, Zustände): [layout/Komponenten.dc.html](layout/Komponenten.dc.html), zusammengefasst in [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) — einzige Quelle für Größen.** Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

## Regeln für Cursor (verbindlich)

1. **Nur Aufgaben aus „A. Jetzt“**, in der dort stehenden Reihenfolge. „B. Backlog“ und alles andere nicht anfassen, auch nicht „vorbereiten“.
2. **Nach jedem Paket anhalten** (Zeile „HALT“). Erst weiterarbeiten, wenn Claude in A. freigegeben hat.
3. **Nichts erfinden.** Kein Feature, Text, Schalter, Screen ohne Vorgabe in README oder Layout. Fehlt etwas: Frage unter die Aufgabe schreiben („Frage:“), nicht bauen. Nötige Texte ohne Layout-Vorlage nur als rote Vorschläge (`ProposalCopy`).
4. **Layout und README sind schreibgeschützt** für Cursor (auch `AGENTS.md`, `archiv/`). Abweichung gefunden → als „Frage:“ melden, nicht selbst „angleichen“.
5. **Diese Datei:** Cursor ändert nur das Feld „Status“ der jeweiligen Aufgabe (höchstens 5 Zeilen: was, welche Dateien, Abweichung). Keine Reviewblöcke, keine neuen Aufgaben, nichts umsortieren, nichts löschen. Claude räumt auf.
6. **Keine Selbstfreigabe.** Cursor schreibt „Bereit zur Prüfung“, nie „fertig“. Nur Claude verschiebt nach DONE.md.
7. **Belege statt Behauptungen:** „Tests grün“ nur mit Zahl, Uhrzeit, Kommando. Bildschirmfotos nur melden, wenn sie in diesem Lauf neu erzeugt wurden (Zeitstempel prüfen). Build Debug und Release ohne Warnung.
8. **Tests:** nur `-only-testing:diskindexTests`; nach **jeder Aufgabe seriell**, am **Ende des Pakets** zusätzlich einmal parallel. UI-Tests nicht starten (Passwortabfrage). Leistungszahlen nur im Release-Build.
9. **Kein Aufräumen, Verschieben oder Löschen** von Dateien, die nicht in der Aufgabe stehen. Kein Refactoring „nebenbei“.
10. **Echte Fenster testen, nicht nur Bilder.** Das Offscreen-Bildschirmfoto (`ScreenshotRunner`) beweist nicht, dass eine Ansicht im echten Fenster funktioniert (Beispiel: `NSTableView`-Zeilen waren im Foto da, im echten Fenster leer). Bei jeder Aufgabe, die Ansichten, Klickflächen oder `NSViewRepresentable` berührt: Test mit echtem `NSWindow` (`makeKeyAndOrderFront`, Layout abwarten, Zeilen/Knöpfe zählen, Klick per `hitTest` auf Randpunkte).
11. **Regression-Rauchtest** (`RegressionSmokeTests`, Cursor legt ihn bei Aufgabe 122 an und erweitert ihn bei jeder Aufgabe): jede Ansicht, die schon einmal kaputt war, bekommt eine Zeile. Vor „Bereit zur Prüfung“ muss er grün sein. Eine Aufgabe, die etwas Abgenommenes wieder kaputt macht, gilt als nicht erledigt.
12. **Gemeinsame Bausteine nur zentral ändern** (Knopf, Chip, Zeile, Spaltenkopf, Leerzustand): eine Quelle, Änderung wirkt überall, Test an der Quelle. Keine zweite Kopie in einer Ansicht.
13. **Maße nur aus dem Komponentenkatalog** (`docs/Komponenten-Masse.md`, Quelle `layout/Komponenten.dc.html`). Keine eigenen Zahlen für Höhe, Innenabstand, Schrift, Rahmen, Radius. Jede Komponente hat einen Messtest gegen diese Zahlen (±0,5 pt), Hell und Dunkel.
14. **Nach Fehlern zurückrollen statt überbauen:** schlägt ein Test fehl, Ursache beheben, nicht Test abschwächen.
15. **Zeichenpfad sauber halten:** in `body`, `init`, `Binding(get:)`, `@State … = …` und `onAppear` **keine** Systemaufrufe (`SMAppService`, `UNUserNotificationCenter`, Dateisystem, Datenbank) und **keine** Zustandsänderungen. Solche Werte liegen in `AppState` und werden im Hintergrund aktualisiert.
16. **Zeilenangaben sind Richtwerte** („Z. ~“). Gilt eine Zeile nicht mehr, über den genannten **Symbolnamen** suchen; nichts an anderer Stelle „ähnlich“ ändern.

---

## A. Jetzt

**Stand 08.10.:** Abgenommen bis 166 (siehe DONE.md). Offen: 167–170 unten.

## ARBEITSAUFTRAG JETZT (Claude, 08.10. — exakt so umsetzen)

**Lies zuerst diese drei Regeln, sie gelten für jede Aufgabe unten:**
- **R1 Nur die genannten Stellen ändern.** Jede Aufgabe nennt Datei und Zeile. Andere Dateien nur, wenn die Aufgabe es sagt. Keine „Verbesserungen nebenbei“.
- **R2 Beweis = Pixel aus einem echten Fenster.** `hitTest != nil`, `source.contains(…)`, Zahlenvergleiche mit Konstanten und Prüfungen nur am Datenmodell zählen **nicht** als Beweis für Aussehen oder Klickverhalten. Benutze dafür ausschließlich die Hilfe `PixelProbe` (unten, Aufgabe 150 a). Jeder neue Test wird einmal **sabotiert** (die Korrektur zurücknehmen) und muss dann rot sein; im Status: „Sabotage: rot ✓“.
- **R3 Status je Aufgabe:** höchstens 5 Zeilen: geänderte Dateien:Zeilen, Testname, Ergebnis der Sabotage, Pfad der Bildschirmfotos (neu erzeugt in `Werkzeuge/screenshots/<JJJJ-MM-TT>-<aufgabe>/`). Ohne diese vier Angaben gilt die Aufgabe als nicht gemacht.

---

**Claude-Prüfung 08.10. (zweite Runde):** 158–166 **abgenommen**. Claude-Lauf **334 Tests, 81 Suiten seriell grün** (stimmt mit Cursor überein). Fotos geprüft: Sprachschalter 160 × 24,4 mit Pfeil rechts, Warnkreis gelb in der Statusfläche, Vergleichsbogen Icons vorhanden. Volltexte: `archiv/todo-stand-2026-10-08b.md`.

**Nutzerentscheidungen 08.10.:** Icon-Füllung **50 %** bleibt (so wie jetzt). Texte „Mitteilungen sind eingeschaltet./ausgeschaltet.“ sind **feste Konzepttexte**, nicht rot.

**Claude-Prüfung 08.10. abends:** 167–171 **abgenommen** (Claude-Lauf: 345 Tests, 85 Suiten seriell; 1 rot = 172 a, 1 bekanntes Problem Hover = Nutzer prüft). Antworten auf Cursors Fragen: (170) Prüfung nur an der Trennlinie ist in Ordnung. (171.1) Verlassen des Knopfs ist im Testprozess nicht prüfbar → bleibt als „known issue“, der Nutzer prüft es in der App. (171.2) Claude hat den Beispielkasten im Layout auf „Medien werden wieder indiziert.“ geändert → siehe 172 c. Volltexte 167–171: `archiv/todo-stand-2026-10-08c.md`.

**172. Sichtbare Scrollbalken, Tests grün, Beispielkasten, Rücknahme Hover-Reset, Sprach-Dropdown.**
a) **Scrollbalken in den Ordnerspalten sind sichtbar (Nutzer-Foto 08.10., echte App)** — breite Spur mit Knopf rechts in der Spalte. Der rote Test `ColumnChromeTests.folderColumnHidesScrollTrack` hatte **recht**, nicht den Test ändern. *Ursache:* `.scrollIndicators(.hidden)` (`ColumnFolderContents.swift` Z. ~71) wird von macOS **nicht beachtet**, wenn das System klassische Rollbalken zeigt (Maus angeschlossen oder „Rollbalken: automatisch“ mit Maus) — `.hidden` heißt nur „wenn die Plattform es erlaubt“. *Ändern:* `.scrollIndicators(.never)` (gilt auch für klassische Rollbalken). In `ColumnFolderTableView.swift`: `scroll.hasVerticalScroller = false` und `hasHorizontalScroller = false` (Scrollen per Rad/Trackpad bleibt). Nur Ordnerspalten, nicht Seitenleiste/Detail. *Test:* bestehender Test grün, zusätzlich derselbe Test mit erzwungenem klassischen Stil (`NSScroller.preferredScrollerStyle`-Attrappe bzw. `UserDefaults`-Domäne des Tests `AppleShowScrollBars = Always`) → keine Spur. Sabotage: `.hidden` zurück → rot.
b) **Parallel instabil:** `SurfaceStoreTests.forgetAllClearsUIAndDatabase`, `ColumnAndSearchTests.aNewBatchAppearsWithoutReopening` → gemeinsamer Zustand (statische Variablen, gemeinsame Datenbankdatei, `UserDefaults.standard`, `SystemNotice.testPostHandler`, `NoticeThrottle.shared`, feste Wartezeiten). Je Test eigene Instanzen/Pfade, Warten auf Bedingung statt Schlafzeit. *Kriterium:* paralleler Gesamtlauf **dreimal hintereinander** grün.
c) **Beispielkasten Mitteilungen (Erweitert):** Layout zeigt jetzt „Medien werden wieder indiziert.“ → `LayoutCopy.previewSystem` (Englisch „Media are being indexed again.“); `LayoutCopyTests` grün.
d) **Hover-Reset zurücknehmen (Nutzer 08.10. abends):** Bestätigungsknopf setzt **nur nach 3 s ohne Klick** zurück, **nicht** beim Verlassen mit dem Zeiger (README §6, Layout 05 angepasst). Den Hover-Teil aus 171.1 und den „known issue“-Test `ConfirmButtonHoverTests.leavingResetsArmedStage` entfernen; Test: Stufe „Bestätigen“ bleibt nach Mausbewegung aus dem Knopf, kehrt nach 3 s (eingespeiste Uhr) zurück.
e) **Sprach-Dropdown: blockiert einige ms, „komischer Fokus“ (Nutzer).** (1) **Fokus:** Knopf und Radio-Zeilen zeigen beim Klick einen Fokusrahmen/eine Fokusmarkierung → `.focusEffectDisabled()` auf Knopf, Feld und Zeilen; das Feld nimmt beim Öffnen **keinen** Tastaturfokus (Esc schließt trotzdem über den bestehenden Tastenmonitor). Nach dem Schließen keine Markierung am Knopf. (2) **Blockade:** Das Öffnen setzt `isLanguageMenuOpen` in `SettingsGeneralTab` → die **ganze** Seite (alle Abschnitte inkl. Tag/Nacht-Szene) wird neu berechnet. Messen (Zeit Klick → Feld sichtbar, `os_signpost` oder Zeitstempel im Test) und die Seite so teilen, dass nur der Abschnitt „Sprache“ neu berechnet wird (Abschnitte als eigene Unteransichten, die `isLanguageMenuOpen` nicht lesen; `zIndex` am Abschnitt bleibt). Ziel: Feld im **nächsten Bild** (≤ 17 ms) sichtbar. Messwert vorher/nachher im Status. *Test (`PixelProbe`):* nach Klick keine Fokusfarbe (Akzentblau) im Bereich von Knopf und Feld; Zeit Klick → Feld ≤ 17 ms.

Status: a) `ColumnFolderContents.swift:~71` `.never`, `ColumnFolderTableView.swift` makeNSView keine Scroller; Test `ColumnChromeTests.folderColumnHidesScrollTrackWithLegacyScrollers`, Sabotage `.hidden`: rot ✓. d) `ConfirmButton.swift` onHover entfernt; `ConfirmButtonTimeoutTests.armedStageSurvivesLeavingAndResetsAfterThreeSeconds` (eingespeiste Uhr), Sabotage Reset aus: rot ✓.
e) `SettingsGeneralTab.swift` (`SettingsSplitRow`, `SettingsLanguageSection` mit eigenem `isOpen`), `SettingsLanguagePicker.swift` (focusEffectDisabled, Feld immer aufgebaut, Deckkraft); `LanguagePickerTests.panelOpensWithinOneFrameWithoutFocusRing`. Messung Debug Klick → Feld: **vorher** 1. Öffnen 22–30 ms, danach 6–7 ms; **nachher** 20–27 ms, danach 4–6 ms. Sabotage alte Struktur: 30–31/8–9 ms, Test bleibt grün (siehe Frage).
c) `Localizable.xcstrings` `preview_system`; `PauseNoticeTextTests.previewCardForSystemNotices`, Sabotage: rot ✓. b) `SurfaceTestSupport.swift` `waitUntil`; feste Pausen ersetzt in `SurfaceStoreTests.forgetAllClearsUIAndDatabase`, `ColumnAndSearchTests.aNewBatchAppearsWithoutReopening`, `ConfirmButtonTimeoutTests`; Sabotage ohne `forgetAllMedia`: rot ✓.
Debug/Release 0 Warnungen; seriell 348 Tests, 85 Suiten grün. Parallel 3×: 110 s/105 s/106 s, **nicht grün**: je 1–2 rot (`ConfirmButtonTimeoutTests` 3×, `aNewBatchAppearsWithoutReopening` 1×, `NoticeToggleOrderTests.offPostsBeforeEffectiveFalls` 1×). Fotos: `Werkzeuge/screenshots/2026-10-08-172a/`, `-172c/`, `-172d/`, `-172e/`. Bereit zur Prüfung (b offen).
Frage: e) Das erste Öffnen bleibt in Debug über 17 ms, die späteren liegen darunter. Reicht das, oder soll Release gemessen werden? Die Sabotage (alte Struktur) bleibt grün, weil die späteren Öffnungen auch vorher schon ≤ 17 ms waren. Die Fokusfarbe ist im Test nicht prüfbar, weil das Fenster nie Key wird.
Frage: d) Das Verlassen besteht trivial, weil der Testprozess nie aktiv ist und keine Hover-Ereignisse bekommt. b) Die PixelProbe-Tests scheitern parallel nur nach ca. 20 s (Zeitüberschreitung), seriell nie. Mutmaßlich stören sich die Fenster und Mausereignisse paralleler Prozesse. Sollen PixelProbe-Suiten mit `.serialized` laufen oder aus dem Parallellauf ausgenommen werden?

**HALT nach 172.** Reihenfolge a → d → e → c → b.

### Offen, ohne Cursor

- **Nutzer:** (1) Kurztest am Stick für 107: großen Ordner öffnen, Pfeiltasten, Mehrfachauswahl, Rechtsklick. (2) Layout nachziehen: alte Chip-Beschreibungstexte, Menüleisten-Symbol „blauer Spinner (Abgleich)“ (112 Punkt 3), Texte der roten Vorschläge (Debug-App prüfen). (3) Entscheiden: T5 (ausführliches Protokoll) freigeben?
- **Claude:** Layout (Stand 07.10.) gegen README abgleichen; danach neue Aufgaben für Cursor schreiben. Spezifikationen der abgenommenen Aufgaben: `archiv/todo-stand-2026-10-07.md`.

---

## B. Backlog (nicht freigegeben, Cursor arbeitet nicht daran)

- **T1. Ladehinweis erst nach 1 s** (Nutzer 06.10.): gehört zu 107; Suche/Favoriten später.
- **T2. Programme als Dateityp „Programme“** (`.app`-Pakete, dmg, pkg).
- **T3. Erweiterte Dateityp-Icons** (Styleguide Sektion 15).
- Cursor hat T1–T3 vorzeitig gebaut; Claude entscheidet bei der Prüfung, was bleibt.
- **T5 (Vorschlag Claude, wartet auf Nutzer): Ausführliches Protokoll („Diagnose-Modus“).** Es gibt schon `~/Library/Logs/Disk Index/diskindex.log` (Kategorien, `crash-last.txt`, „previous run ended without clean exit“). Lücken: (1) **Beenden wird nicht protokolliert** (`applicationShouldTerminate` schreibt nichts; nur `applicationWillTerminate` „app terminate ok“) → Zeilen „quit requested (Quelle)“, „quit: status item entfernt“, „quit: Indizierung gestoppt“ mit Dauer. (2) **Haupt-Thread-Wächter:** blockiert der Hauptfaden > 2 s, Zeile `hang main ms=…` mit Stack (Release tauglich). (3) **Schalter** „Ausführlich“ (Erweitert, nur Debug oder per `defaults`) für Pegel `debug`: je Medium Dauer von Lesen/Schreiben, Cache-Treffer, Ladezeiten Spalten, Speicher. (4) `crash-last.txt` auch bei Beenden durch Signal. Nicht freigegeben.
