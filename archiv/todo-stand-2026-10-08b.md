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
8. **Tests:** nur `-only-testing:diskindexTests`, seriell **und** parallel. UI-Tests nicht starten (Passwortabfrage). Leistungszahlen nur im Release-Build.
9. **Kein Aufräumen, Verschieben oder Löschen** von Dateien, die nicht in der Aufgabe stehen. Kein Refactoring „nebenbei“.
10. **Echte Fenster testen, nicht nur Bilder.** Das Offscreen-Bildschirmfoto (`ScreenshotRunner`) beweist nicht, dass eine Ansicht im echten Fenster funktioniert (Beispiel: `NSTableView`-Zeilen waren im Foto da, im echten Fenster leer). Bei jeder Aufgabe, die Ansichten, Klickflächen oder `NSViewRepresentable` berührt: Test mit echtem `NSWindow` (`makeKeyAndOrderFront`, Layout abwarten, Zeilen/Knöpfe zählen, Klick per `hitTest` auf Randpunkte).
11. **Regression-Rauchtest** (`RegressionSmokeTests`, Cursor legt ihn bei Aufgabe 122 an und erweitert ihn bei jeder Aufgabe): jede Ansicht, die schon einmal kaputt war, bekommt eine Zeile. Vor „Bereit zur Prüfung“ muss er grün sein. Eine Aufgabe, die etwas Abgenommenes wieder kaputt macht, gilt als nicht erledigt.
12. **Gemeinsame Bausteine nur zentral ändern** (Knopf, Chip, Zeile, Spaltenkopf, Leerzustand): eine Quelle, Änderung wirkt überall, Test an der Quelle. Keine zweite Kopie in einer Ansicht.
13. **Maße nur aus dem Komponentenkatalog** (`docs/Komponenten-Masse.md`, Quelle `layout/Komponenten.dc.html`). Keine eigenen Zahlen für Höhe, Innenabstand, Schrift, Rahmen, Radius. Jede Komponente hat einen Messtest gegen diese Zahlen (±0,5 pt), Hell und Dunkel.
14. **Nach Fehlern zurückrollen statt überbauen:** schlägt ein Test fehl, Ursache beheben, nicht Test abschwächen.

---

## A. Jetzt

**Stand 06.10. abends:** Paket 1, 2 und die Spaltenansicht (102, 114, 119, 120, 121) sind abgenommen, siehe DONE.md. Offen: Paket 3 (107, 109), dann Paket 4 (110, 111, 112 Rest, 113). Reihenfolge der Freigabe bestimmt Claude.

## ARBEITSAUFTRAG JETZT (Claude, 07.10. abends — exakt so umsetzen)

**Lies zuerst diese drei Regeln, sie gelten für jede Aufgabe unten:**
- **R1 Nur die genannten Stellen ändern.** Jede Aufgabe nennt Datei und Zeile. Andere Dateien nur, wenn die Aufgabe es sagt. Keine „Verbesserungen nebenbei“.
- **R2 Beweis = Pixel aus einem echten Fenster.** `hitTest != nil`, `source.contains(…)`, Zahlenvergleiche mit Konstanten und Prüfungen nur am Datenmodell zählen **nicht** als Beweis für Aussehen oder Klickverhalten. Benutze dafür ausschließlich die Hilfe `PixelProbe` (unten, Aufgabe 150 a). Jeder neue Test wird einmal **sabotiert** (die Korrektur zurücknehmen) und muss dann rot sein; im Status: „Sabotage: rot ✓“.
- **R3 Status je Aufgabe:** höchstens 5 Zeilen: geänderte Dateien:Zeilen, Testname, Ergebnis der Sabotage, Pfad der Bildschirmfotos (neu erzeugt in `Werkzeuge/screenshots/2026-10-08-<aufgabe>/`). Ohne diese vier Angaben gilt die Aufgabe als nicht gemacht.

---

**Claude-Prüfung 08.10.:** 150, 151, 152, 156, 157, 154 **abgenommen** (Bildschirmfotos geprüft: Spalten oben, Ladefläche mit Spinner/Text/Ladestand und Restbreite, Pfadmarkierung schwarz, Demo isoliert; Tests mit `PixelProbe`; Claude-Lauf **321 Tests, 72 Suiten seriell grün** — Cursor meldete 338: Zählweise im Status künftig aus der Zeile `Test run with N tests` übernehmen). Nutzer prüft: Dock beim Autostart, Fortschritt im Popover.
*Kleinigkeit:* `07-spalten-langname-*` enthält wieder **keinen** langen Namen — Fixture mit einem 80-Zeichen-Dateinamen versehen (bei 158 miterledigen).

**Phosphor-Symbole:** fehlt ein Symbol im Asset-Katalog, die **offizielle Datei** nehmen (gleiche Quelle wie die vorhandenen): `https://unpkg.com/@phosphor-icons/core/assets/regular/<name>.svg` (bzw. `/duotone/<name>-duotone.svg`), unverändert als Template-Imageset anlegen. Gilt für `caret-down` und `warning-circle` unten.

**158. Restliche System-Kästchen → Layout-Checkbox.** „Ordner weiterhin anzeigen“ (`SettingsGeneralTab`, Dateityp-Filter) und die zwei „Ignorieren“ (`SettingsIgnoredObjectsTab` Z. ~79, ~97): `.toggleStyle(DesignCheckbox())`, `.tint` entfernen. Danach kein `Toggle` ohne `DesignCheckbox` im Projekt. Fixture `07-spalten-langname` mit einem echten 80-Zeichen-Dateinamen. *Test (`PixelProbe`):* Kästchen 16 × 16 in Layout-Farbe (kein System-Blau), Mausklick auf das Kästchen schaltet.

**Status:** `SettingsGeneralTab.swift:213`, `SettingsIgnoredObjectsTab.swift:79,97` `DesignCheckbox`, `.tint` weg. `ScreenshotRunner.swift:630` Dateiname 80 Zeichen. Test `LayoutCheckboxTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-158/`. Seriell Test run with 322 tests; Release ohne Compiler-Warnung. Bereit zur Prüfung.

**159. Menüleisten-Popover: Zeile springt beim Start von „Neu indizieren“.** *Ursache:* `MenuBarPopoverLayout.rowHeight(for:)` (Z. ~76) liefert **56** im Ruhezustand und **64** beim Indizieren (`rowHeightStandard`/`rowHeightIndexing`, Z. ~25/26); in `MenuBarConnectedMediumRow.rowBody` (Z. ~52–66) wird die zweite Zeile (Text „Zuletzt indiziert: …“, 11 pt) durch den niedrigeren `IndexingProgressBar` ersetzt. *Ändern:* **eine** Zeilenhöhe für beide Zustände (56). Die zweite Zeile ist ein **fester Platz** mit der Höhe einer 11-pt-Textzeile (`Text("Ag").font(.system(size: 11)).hidden()` als Maß); darin liegt **entweder** der Text **oder** der Balken, der Balken **senkrecht mittig** in diesem Platz. **Der Balken selbst bleibt dünn wie bisher bzw. wie im Layout** (seine Höhe nicht ändern, nicht auf Texthöhe strecken); nur der reservierte Platz hat Texthöhe. Rechts gilt dasselbe: der Knopf „Neu indizieren“ und der Block „Spinner + x %“ teilen einen Platz fester Höhe (Höhe des Knopfes klein, 24,4), Inhalt mittig. *Test (`PixelProbe`):* Popover mit einem Medium im Ruhezustand und indizierend rendern: Gesamthöhe des Popovers gleich (±0,5 pt), Oberkante des Namens gleich, Mitte des Balkens = Mitte der Textzeile (±1 pt).

**Status:** `MenuBarPopoverLayout.swift:77` immer 56. `MenuBarConnectedMediumRow.swift:58` fester Textplatz, `:36` Slot 24,4. Test `MenuBarRowHeightTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-159/`. Seriell Test run with 323 tests; Release ohne Compiler-Warnung. Bereit zur Prüfung.

**160. „Neu indizieren“: sofort sperren, bis 59 s nach Laufende (README §4).** *Ändern:* zentrale Prüfung in `AppState` `func canReindex(_ id: UUID, now: Date = Date()) -> Bool`: falsch, wenn (a) `reindexRequested.contains(id)` (Satz von Kennungen, **beim Klick sofort** gesetzt, bevor irgendetwas anderes passiert), (b) das Medium gerade indiziert (`indexStatus == .indexing`), (c) `now < lastIndexedAt + 59 s` (Ende des letzten Laufs). `reindexRequested` wird geleert, wenn der Lauf beginnt (dann greift b). Alle Knöpfe „Neu indizieren“ benutzen **nur** diese Prüfung: `MenuBarConnectedMediumRow` (Z. ~75), `MediumDetailModalView` (Z. ~163) und jede weitere Stelle (Suche `reindexMedium(` im Projekt, Liste im Status). Gesperrter Knopf: `.disabled(true)` mit dem deaktivierten Aussehen des Knopfstils, kein Hover/Zeiger-Hand. Die Freigabe nach 59 s muss **ohne** Nutzeraktion erscheinen (Zeitgeber, der die Ansicht zum Ablaufzeitpunkt neu zeichnet). `reindexMedium(id:)` prüft `canReindex` selbst noch einmal (doppelte Klicks, Tastatur). *Test:* (1) Doppelklick (zwei echte Mausereignisse in 50 ms) auf „Neu indizieren“ im Popover → genau **ein** Aufruf von `onReindexMedium`; (2) Laufende bei t, `canReindex` bei t + 58 s falsch, bei t + 59 s wahr (eingespeiste Uhr); (3) während des Laufs in Popover **und** Details deaktiviert (`PixelProbe`: Knopf in Deaktiviert-Farbe).

**Status:** `AppState+Media.swift:54` `canReindex`, `:77` sperrt vor dem Start. `MenuBarConnectedMediumRow.swift:86`, `MediumDetailModalView.swift:163` nur diese Prüfung, deaktiviert ohne Zeiger. Zeitgeber `armReindexGate` `:62`. Test `ReindexGateTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-160/`. Seriell Test run with 326 tests; Release ohne Compiler-Warnung. Bereit zur Prüfung.

**161. Fortschritt mindestens 1 Sekunde sichtbar (README §4).** *Befund:* schnelle Läufe zeigen nur „0 %“ und springen dann in den Endzustand. *Ändern:* eine Anzeige-Funktion `displayedProgress(id, now)` = `min(echter Fortschritt, (now − Laufstart) / 1 s)`, nie fallend; nach dem echten Ende läuft sie mit derselben Formel weiter, bis 1,0 erreicht ist, **erst dann** wechselt die Anzeige in den Endzustand („Zuletzt indiziert …“, Chip weg/„Online“). Chip, Popover-Zahl und Balken lesen **nur** diese Funktion (zusätzlich zu 151: eine Quelle). Aktualisierung mit 30 Bildern pro Sekunde während der Animation (`TimelineView(.animation)` oder Zeitgeber), sonst wie bisher. 100 % darf nur in dieser Abschlussbewegung erscheinen. *Test:* Lauf, der nach 0,2 s fertig ist: Messpunkte 0,1 / 0,5 / 0,9 / 1,05 s → Anzeige ≈ 10 / 50 / 90 % (±5), dann Endzustand; Lauf mit echtem Fortschritt langsamer als die Uhr → Anzeige = echter Fortschritt.

**Status:** `AppState+Media.swift:59` `displayedProgress`, Chip `StatusChip.swift:15`, Popover `MenuBarConnectedMediumRow.swift:29` mit 30 Bildern/s. Test `ProgressHoldTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-161/`. Seriell Test run with 328 tests; Release ohne Compiler-Warnung. Bereit zur Prüfung.

**162. Autostart-Kästchen reagiert verzögert.** *Ursache:* `SettingsGeneralTab` `launchAtLoginSection` ruft im `set` des Bindings **synchron** `LaunchAtLogin.setEnabled` (`SMAppService.register/unregister`, blockiert den Hauptfaden) und liest erst danach den Zustand neu. *Ändern:* Zustand **sofort** in der Ansicht setzen (optimistisch), `setEnabled` in einem Hintergrund-Task ausführen; danach `LaunchAtLogin.state` lesen und nur bei Abweichung (Fehler, Genehmigung nötig) korrigieren und protokollieren. *Test:* Klick per Mausereignis → Kästchen ist im **nächsten** Bild (≤ 1/60 s) umgeschaltet (Attrappe für `setEnabled`, die 500 ms schläft).

**Status:** `SettingsGeneralTab.swift:105` setzt den Zustand sofort, `setEnabled` im Hintergrund. `LaunchAtLogin.swift:47` `nonisolated`. Test `AutostartToggleTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-162/`. Seriell Test run with 329 tests; Release ohne Compiler-Warnung. Bereit zur Prüfung.

**163. Aktive Toolbar-Icons: Füllung 50 % testen (Nutzer 08.10.).** Nutzer: keines der Nicht-Home-Icons sieht aus wie im Entwurf, 95 % wirken in Swift zu kräftig. *Ändern:* `DesignSystem/ToolbarNavIcon.swift` Z. ~20: Füllung für `.settings, .filter, .favorites, .search` **0,50** (Home bleibt 1,0). Zusätzlich **Vergleichsbogen** für den Nutzer erzeugen: `Werkzeuge/screenshots/2026-10-08-163/icons-vergleich-hell.png` und `…-dunkel.png`: eine Tabelle, Zeilen = Icon (Einstellungen, Filter, Suche, Favoriten), Spalten = Füllung 30 %, 50 %, 70 %, 95 %, jeweils 4-fach vergrößert, mit Beschriftung. Der Nutzer wählt; bis dahin 50 %.

**Status:** `ToolbarNavIcon.swift:20` Füllung 0,50. Vergleich `Werkzeuge/screenshots/2026-10-08-163/icons-vergleich-hell.png` und `icons-vergleich-dunkel.png`. Test `ToolbarFillTests`. Sabotage: rot ✓. Seriell Test run with 334 tests; Release ohne Compiler-Warnung. Bereit zur Prüfung.

**164. Status-Icons in den Spalten nach Layout (gemessen 08.10.).** Für die drei Statusflächen (`FolderContentsLoadingHint`, `FolderPendingIndexingHint`, Hinweis „Inhalt wird nicht indiziert“ in `ColumnFolderStatusPanels`): Icon-Rahmen **20 × 20**, Abstand Icon → Titel **10**. **Spinner:** Ring Ø **20**, Strichstärke **2,5**, oberes Viertel offen (drei Viertel sichtbar), dreht in 0,9 s; Farbe bei „Inhalte werden geladen“ **Textfarbe**, bei „Wird indiziert“ **Grün** `oklch(0.62 0.16 150)`. **Nicht indiziert:** Symbol **`warning-circle`** (Kreis, nicht Dreieck; Phosphor regular, 25 pt, mittig im 20er-Rahmen, darf überstehen), Farbe Gelb `#EDA12D`. Titel 12/600. *Test (`PixelProbe`):* Durchmesser der Spinner-Pixel 20 ± 1, Symbol-Pixel des Warnkreises rund (Breite ≈ Höhe ± 1), Abstand Unterkante Icon → Oberkante Titel 10 ± 1.

**Status:** Spinner 20 pt, Abstand 10: `FolderContentsLoadingHint.swift:17`, `ColumnFolderStatusPanels.swift:16`. Warnkreis `IconWarningCircle`, gelb `#EDA12D`. Test `ColumnStatusIconTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-164/`. Seriell Test run with 330 tests; Release ohne Compiler-Warnung. Bereit zur Prüfung.

**165. Sprachschalter nach Layout (ersetzt 153, gemessen 08.10.).** *Knopf:* Sekundär-Knopf klein: Mindestbreite **160**, Höhe **24,4**, Schrift **12/600**, Innenabstand **4/12**, Rahmen 1 px `#9B9797` (Dunkel: Farbrolle), Radius **8**, Text **links**, Pfeil **`caret-down`** (Phosphor regular, **11 pt**) **rechts** (`justify: space-between`, Abstand 8). *Aufgeklappt:* **kein** System-Menü, sondern ein eigenes Feld **4 pt unter dem Knopf, linksbündig**, Mindestbreite 160, Innenabstand **4**, Rahmen 1 px Text 40 %, Radius **14**, Hintergrund `bg`, Schatten `0 3 10` mit 16 %; Einträge als **Radio-Zeilen**: Innenabstand 4/12, Schrift 12/400, Radio-Kreis **16 × 16** mit Rand 1,5 px Text 40 %, gewählter Eintrag mit gefülltem Punkt; Klick wählt und schließt; Klick außerhalb oder Esc schließt. Bauen als Overlay über dem Inhalt (wie das Pausen-Popover, aber **ohne Nase**; Katalog „Popover ohne Nase · Auswahl-Dropdown“). *Test (`PixelProbe`):* Knopf 160 × 24,4 (±0,5), Pfeil in den rechten 24 pt; nach Mausklick erscheint das Feld 4 pt darunter mit zwei Zeilen; Klick auf „English“ setzt die Sprache und schließt.

**Status:** `SettingsLanguagePicker.swift` Knopf 160×24,4, `NavCaretDown`, eigenes Feld. Test `LanguagePickerTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-165/`. Seriell Test run with 331 tests; Release ohne Compiler-Warnung. Bereit zur Prüfung.

**166. Mitteilung beim Ein-/Ausschalten der Mitteilungen + 5-s-Sperre (README §6).** *Ändern:* Beim Umschalten des Hauptschalters `notificationsEnabled`: **an** → nach dem Einschalten Mitteilung `ProposalCopy.noticesTurnedOn` („Mitteilungen sind eingeschaltet.“); **aus** → **vor** dem Abschalten Mitteilung `ProposalCopy.noticesTurnedOff` („Mitteilungen sind ausgeschaltet.“). Beide gehen am Unterpunkt „Systemmeldungen“ vorbei (immer, wenn macOS es erlaubt). **Sperre** in einer kleinen Klasse `NoticeThrottle` (eingespeiste Uhr): dieselbe Meldungsart frühestens **5 s** nach der letzten gleichen; die andere Art ist davon unabhängig. *Test (Attrappe für das Posten):* an, aus, an innerhalb 1 s → Meldungen: an, aus (zweites „an“ unterdrückt); nach 5 s erneut an → Meldung.

**Status:** `NoticeToggle.apply` in `SystemNotice.swift`, Texte `ProposalCopy.noticesTurnedOn/Off`. Schalter `SettingsGeneralTab.swift`. Test `NoticeThrottleTests`. Sabotage: rot ✓. Fotos `Werkzeuge/screenshots/2026-10-08-166/`. Seriell Test run with 332 tests; Release ohne Compiler-Warnung. Bereit zur Prüfung.

**155. Toolbar-Icons (Form) — nur 163 umsetzen**, sonst nichts an den Icons ändern.

**HALT nach 163 (letzte in der Reihenfolge).** Reihenfolge **158 → 159 → 160 → 161 → 162 → 164 → 165 → 166 → 163**. (Der alte Text von 153 entfällt, 165 ersetzt ihn.)

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
