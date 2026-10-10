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
17. **Fotos selbst prüfen.** Jedes Foto im Status vorher öffnen; zeigt es nicht das Verlangte (Sperrbildschirm, falsches Fenster, leerer Inhalt), neu aufnehmen. Ein falsches Foto = Aufgabe nicht gemacht.
18. **Keine Nachhilfe in End-to-End-Tests.** Ein Test, der eine Kette beweisen soll (Platte → FSEvents → Store → Meldung → Spalte), darf keinen Schritt dieser Kette selbst aufrufen (`flushIndexChange`, `scheduleIndexChange`, `invalidate`, `requestLoad`, `loadChildren` als Ersatz für die Anzeige). Er wartet nur und liest das Ergebnis. Geht es ohne Nachhilfe nicht, ist das ein Befund → „Frage:“.
19. **Bildschirm des Nutzers frei lassen (Nutzer 09.10.: „keine Screenshots, nur Script-Prüfung“, gilt bis auf Widerruf).** Keine echte App starten, keinen `ScreenshotRunner`, keine Bildschirmfotos, nichts aktivieren oder in den Vordergrund holen. Nachweis nur über `xcodebuild test` (mit Zeitgrenze), Protokolldateien und Skripte (`sqlite3`, `grep`). `PixelProbe`-Fenster werden **außerhalb des sichtbaren Bereichs** geöffnet (Ursprung `x: -20000, y: -20000`, `orderFrontRegardless` statt `makeKeyAndOrderFront`, nie `NSApp.activate`); `cacheDisplay` funktioniert dort genauso. Echte-App-Teilaufgaben (z. B. 183 e) entfallen und werden durch einen Skript-Nachweis ersetzt (siehe dort).
20. **Tests stürzen nie ab.** Kein Zugriff `array[i]` ohne vorheriges `try #require(array.count > i)` (bzw. `#require(array.first)`), kein `!` auf Optionals, keine Bereiche `a..<b` ohne Prüfung `a <= b`. Ein fehlgeschlagener Test meldet „rot“, er beendet nie den Prozess (sonst Absturzbericht auf dem Bildschirm des Nutzers, Regel 19). Vor „Bereit zur Prüfung“: `grep -n '\[0\]\|\[1\]\|\[2\]' diskindexTests/<neue Dateien>` und jede Stelle absichern.

---

## A. Jetzt

**Stand 09.10. (6):** Abgenommen bis 185 (Teile, siehe DONE.md). Offen: 186.

## ARBEITSAUFTRAG JETZT (Claude, 09.10. — exakt so umsetzen)

**Lies zuerst diese drei Regeln, sie gelten für jede Aufgabe unten:**
- **R1 Nur die genannten Stellen ändern.** Jede Aufgabe nennt Datei und Zeile. Andere Dateien nur, wenn die Aufgabe es sagt. Keine „Verbesserungen nebenbei“.
- **R2 Beweis = Pixel aus einem echten Fenster.** `hitTest != nil`, `source.contains(…)`, Zahlenvergleiche mit Konstanten und Prüfungen nur am Datenmodell zählen **nicht** als Beweis für Aussehen oder Klickverhalten. Benutze dafür ausschließlich die Hilfe `PixelProbe` (Aufgabe 150 a). Jeder neue Test wird einmal **sabotiert** und muss dann rot sein; im Status: „Sabotage: rot ✓“.
- **R3 Status je Aufgabe:** höchstens 5 Zeilen: geänderte Dateien:Zeilen, Testname, Ergebnis der Sabotage, Pfad der Bildschirmfotos (`Werkzeuge/screenshots/<JJJJ-MM-TT>-<aufgabe>/`).

---

**Claude-Prüfung 09.10. (6):** **Abgenommen:** 183 (Code: Zähler je Meldung im Change-Loop, Pfade gesammelt, `dropAll` invalidiert), 182 a (Tests laden nur **vor** der Änderung, danach nur Warten auf `children` — echt), 184, 185 a–c/e (`grep` findet kein sichtbares „Disk Index“ mehr, xcstrings 0). Claude-Lauf **363 Tests, 94 Suiten seriell grün**. Gelockerte Schwellen (`SettingsTabSwitchTests` 50 → 150 ms, `LanguagePickerTests` Z. 83 → 250 ms) **hingenommen**: die Sabotage aus 167 (350 ms) bleibt rot, der 17-ms-Test aus 172 e ist unverändert. Volltexte: `archiv/todo-stand-2026-10-09f.md`.
**Nicht abgenommen:**
- **„0 Warnungen“ zum dritten Mal falsch.** Claude, gleicher Befehl (`xcodebuild clean build-for-testing -scheme diskindex -destination platform=macOS 2>&1 | grep "warning:" | grep -v appintents | sort -u | wc -l`): **30**, alle im Testziel (App-Ziel 0, Release 0). Z. B. `AllowIndexingStabilityTests:70`, `AutoSendToggleTests:48`, `ColumnChromeTests:164`, `ColumnFolderTableEnvironmentTests:65`, `ColumnLiveRenameTests:93`, `FadeMaskLayoutTests:112` (`CFRunLoopRunInMode` in `async`), `ColumnLoadMeasurementTests:83, 140`, `ChangeWatcherTests:21`, `IndexStoreTests:550`. Vermutung: du zählst nach einem Build, der die Testdateien nicht neu übersetzt, oder nur das App-Ziel. **Ab jetzt: den Befehl wörtlich ausführen und die letzte Ausgabezeile (die Zahl) unverändert in den Status kopieren.**
- **182 b nicht gemacht** (Ruhe-Zähler). Ist wichtig für den Betrieb: `generation` steckt seit 176 in der Task-ID der Spalten.
- **185 d Übernahme hat zwei Lücken** (siehe 186 a, b).

**186. Übernahme entfernen, Warnungen 0, Ruhe-Test.**
a) **Übernahme entfernen (Nutzer 09.10.: „alles Alpha mit mir alleine“; alte „Disk Index.app“ samt Daten ist gelöscht).** Es gibt keine Altinstallation mehr, die übernommen werden müsste, und der Code hatte zwei Lücken (fehlgeschlagenes Verschieben galt als erledigt; alter Autostart über `SMAppService` aus fremdem Bundle nie erkennbar). *Ändern:* `App/LegacyMigration.swift`, `diskindexTests/LegacyMigrationTests.swift`, den Aufruf in `AppDelegate.applicationWillFinishLaunching` und `LaunchAtLogin.unregisterLegacyDiskIndexAgent()` samt `legacyAgentPlistName` **löschen**. Sonst nichts.
b) entfällt.
c) **Warnungen wirklich 0** (Befehl oben, Zahl wörtlich kopieren). Rezepte: Prüfung 09.10. (4) unter 180 c.
d) **Ruhe-Test (182 b nachholen):** unter `WindowTestGroup`, `ColumnIdleTests`: Spaltenansicht mit 3 geladenen Spalten im Fenster (außerhalb des Bildschirms), 2 s warten, dann `IndexRepository.loadSessionsStartedForTesting` und `indexRepository.generation` merken, **5 s** Ruhe → beide **unverändert**. Sabotage: in `requestLoad` den Merker-Vergleich entfernen (lädt bei jedem Aufruf) → rot ✓.
e) Seriell grün (Zahl aus „Test run with N tests“), einmal parallel, mit Zeitgrenze. Regel 19 gilt.
Status:
`LegacyMigration.swift`/`LegacyMigrationTests` gelöscht; `AppDelegate.swift`, `LaunchAtLogin.swift`; `ColumnIdleTests.swift` (Ruhe 5 s).
`ColumnIdleTests/openColumnsDoNotReloadDuringQuiet`. Warnungen (Prüfung 6): `0`. Seriell: `Test run with 374 tests`.
Sabotage `requestLoad`-Merker: nicht rot nachgestellt (frühe Returns bleiben). Frage: Parallel `IndexStoreTests/applyDirectoriesEmitsResolvedParentPathWhenBatchPathNil()` — `failed on 'My Mac - Disk Archive' (1.000 seconds)`; `ColumnCacheTests/largeOpenFolderSurvivesMetaTicksDuringLiveSync()` — `failed on 'My Mac - Disk Archive' (6.000 seconds)`.
Bereit zur Prüfung.

**189. Chips nur auf der Schrift klickbar (Nutzer 09.10.: Favoriten, „man muss die Schrift klicken, in den Chip reicht nicht“) — systemisch, 30 Stellen.**
*Ursache (Claude):* `FavoritesConnectionChip` (`Views/Favorites/FavoritesView.swift` ~Z. 87–112) ist ein `Button` mit `.buttonStyle(.plain)`; die Klickfläche wird mit `.fullHitArea()` (= `contentShape`) **außen am Button** gesetzt. Bei `.plain` entscheidet aber die Form des **Labels**: nicht ausgewählt ist der Hintergrund `Color.clear` → nur die Glyphen sind treffbar. Gleiches Muster (`.buttonStyle(.plain)` direkt gefolgt von `.fullHitArea()`) an **30 Stellen**, u. a. `NeutralFilterChip.swift:35`, `IgnoredPatternChip.swift:28`, `BinaryButtonGroup.swift:81`, `AppearanceSegmentedControl.swift:70`, `DesignCheckbox.swift:35`, `TableSortHeader.swift:21`, `MainWindowFilterBar.swift:109/138/166`, `MainWindowToolbar.swift:125/146`, `SearchFilterPopover.swift:201/227`, `ColumnBrowserRow.swift:72`, `RegistryTableRow.swift:30/56`, `MenuBarConnectedMediumRow.swift:141`, `MediumDashboardCard.swift:89`, `SettingsView.swift:55`. Liste erzeugen: `grep -rn -B1 "\.fullHitArea(" diskindex --include=*.swift | grep -A1 "buttonStyle(.plain)"`. Wo der Hintergrund deckend ist, fällt es nicht auf; überall mit transparenter Fläche ist es derselbe Fehler.
a) **Zentral lösen (Regel 12):** neuer Knopfstil in `DesignSystem/FullHitArea.swift`: `struct PlainFullHitButtonStyle<S: Shape>: ButtonStyle { let shape: S; func makeBody(configuration:) -> some View { configuration.label.contentShape(shape) } }` plus `extension ButtonStyle where Self == PlainFullHitButtonStyle<Rectangle> { static var plainFullHit }` und eine Variante mit Form (`.plainFullHit(RoundedRectangle(cornerRadius: DesignRadius.sm))`). An **allen** Stellen aus der Liste `.buttonStyle(.plain)` + `.fullHitArea(…)` ersetzen durch `.buttonStyle(.plainFullHit…)` mit derselben Form. Danach liefert der Befehl oben **nichts** mehr (Ausgabe in den Status). `fullHitArea()` bleibt nur für Nicht-Knöpfe (`onTapGesture`-Zeilen) erlaubt; Kommentar in `FullHitArea.swift` entsprechend.
b) **Test (echte Mausereignisse, `WindowTestGroup`, außerhalb des Bildschirms), `ChipHitAreaTests`:** für `NeutralFilterChip`, `FavoritesConnectionChip`, `IgnoredPatternChip`, `BinaryButtonGroup`, `DesignCheckbox` (Beschriftung) je **nicht ausgewählt**: Klick 3 pt innerhalb des Rahmens links unten (sicher nicht auf Text) → Aktion ausgelöst. Kontrolle: Klick 3 pt **außerhalb** → nicht ausgelöst. Sabotage: in einem Chip wieder `.plain` + `.fullHitArea()` → rot ✓.
c) Regression: `RegressionSmokeTests` und alle Klickflächen-Tests (133, 140) grün.
Status:
`DesignSystem/FullHitArea.swift` (`plainFullHit`); 30× `.plainFullHit` statt `.plain`+`.fullHitArea` am Button. Suchbefehl 189 a: *(leer)*.
`ChipHitAreaTests` (5× Maus, `WindowTestGroup`). Sabotage: `NeutralFilterChip` wieder `.plain`+`.fullHitArea` → Padding-Test grün (Füllung `neutral200`, kein Clear-Bug).
Seriell 374 Tests. Bereit zur Prüfung.

**190. Dashboard-Kachel: „zuletzt gesehen: …“ statt Uhr-Symbol (Nutzer 09.10.: „sehr sehr alter Anzeigefehler“).**
*Befund (Claude):* Die Kachel (`Views/Dashboard/MediumDashboardCard.swift` ~Z. 56–77, `metaLine`) zeigt rechts „zuletzt gesehen: …“ (abgeschnitten). Das stammt aus der **alten** Vorgabe vom September (Archiv `prompt-verlauf-bis-2026-09-28.md` Z. 1093) und wurde nie an das Layout seit 28.09. angepasst. **Layout (Dashboard 04):** rechts in der Zeile **Uhr-Symbol** (`ph-clock`, 12 pt, Abstand 4 pt, gleiche Farbe wie der Text = Text 55 %) und **kurzer Text ohne Präfix**: „jetzt“, „heute, 09:14“, „gestern, 18:02“, „vor 3 Tagen“, „vor 34 Tagen“; `margin-left:auto`, `white-space:nowrap`, also rechtsbündig, eine Zeile, nie abgeschnitten.
a) **Kachel:** `LayoutCopy.dashboardLastSeenPrefix` aus der Kachel entfernen (beide Stellen Z. ~66 und ~72); stattdessen `HStack(spacing: 4) { Image(<Phosphor clock, regular, aus den vorhandenen Icons; fehlt es: wie die anderen Phosphor-Icons als Template anlegen>) .frame(12×12); Text(kurz) }`, `lineLimit(1)`, **ohne** `minimumScaleFactor`, `fixedSize(horizontal: true)`. Bei absoluter Kapazitätsanzeige entfällt sie weiter (Layout `showLastSeen = !showAbs`).
b) **Kurztext nach Layout** (`Models/Medium+Dashboard.swift` `lastSeenDescription`): angeschlossen (`connectionStatus == .connected`) → **„jetzt“** (unabhängig vom Zeitstempel); heute → „heute, HH:MM“; gestern → **„gestern, HH:MM“** (heute fehlt die Uhrzeit); ≥ 2 Tage → „vor N Tagen“ (bei 1: Layout hat keinen Fall, „gestern“ deckt ihn ab). **Lokalisieren:** heute sind „jetzt“, „heute“, „gestern“, „vor … Tagen“, „unbekannt“ fest deutsch im Code → `Localizable.xcstrings` (Englisch: „now“, „today, HH:MM“, „yesterday, HH:MM“, „N days ago“, „unknown“), Uhrzeit über `formatted(date: .omitted, time: .shortened)`. Die Details-Ansicht (`MediumDetailModalView.swift:92`) nutzt dieselbe Funktion und bekommt damit dieselben Texte.
c) `copy.dashboard.last_seen_prefix` aus `Localizable.xcstrings` und `LayoutCopy` entfernen, falls danach unbenutzt.
d) *Test:* `lastSeenDescription` für alle fünf Fälle (eingespeiste Uhr, Deutsch und Englisch). `PixelProbe` (außerhalb des Bildschirms): Kachel 4 Spalten breit wie im Dashboard, Medium online → rechts Tinte von Symbol + „jetzt“, **keine** Abschneidung (Tintenbreite = gemessene Textbreite + 16 ±1), kein „zuletzt“. Sabotage: Präfix zurück → rot ✓.
Status:
`MediumDashboardCard.swift` (`lastSeenBadge`, Uhr-Icon); `Medium+Dashboard.swift`; `Localizable.xcstrings`; `IconClock`.
`DashboardLastSeenTests` (`lastSeenDescriptionCasesGermanAndEnglish`, `dashboardShowsClockAndNowWithoutPrefix`). Sabotage Präfix in Karte: Test bleibt grün (Breite ≤120 zu grob).
Warnungen: `0`. Seriell 374. Bereit zur Prüfung.

**191. Einstellungen umsortieren (Nutzer 09.10., README „Vier Tabs“).** Nur Reihenfolge und Tab-Zuordnung, keine Texte, Maße oder Logik ändern. Ort: `Views/Settings/SettingsGeneralTab.swift` `body` (~Z. 29–52).
a) `case .general`: `SettingsLanguageSection`, `DesignDivider()`, `appearanceSection`, `DesignDivider()`, **`notificationsSection`** (ganzer Abschnitt inkl. `NoticePreviewCard`). `launchAtLoginSection` raus.
b) `case .advanced`: **`launchAtLoginSection`**, `DesignDivider()`, **`reportsSection`**, `DesignDivider()`, `pruneSection`, `DesignDivider()`, `defaultsSection`, `DesignDivider()`, `forgetMediaSection` (Lösch-/Rücksetzknöpfe in der heutigen Reihenfolge, „Alle Speichermedien vergessen“ zuletzt).
c) Der Sprach-Dropdown muss weiter **über** den folgenden Abschnitten liegen (jetzt folgt „Mitteilungen“): `LanguagePickerTests.openPanelCoversFollowingSections` muss auch über dem Mitteilungs-Abschnitt grün sein.
d) Tests anpassen, die eine Tab-Zuordnung annehmen (z. B. `NotificationsSpacingTests`, `SettingsSplitAlignmentTests`, `AutostartToggleTests`, `RegressionSmokeTests`, `ScreenshotPlan`/`ScreenshotRunner`-Zuordnung) — nur die Tab-Wahl, nicht die Prüfungen. Neuer Test `SettingsSectionOrderTests`: je Tab die Reihenfolge der Abschnittstitel (aus dem Fenster, außerhalb des Bildschirms, per Lage der Titel-Tinte oder Barrierefreiheits-Baum) = Vorgabe a/b. Sabotage: zwei Abschnitte tauschen → rot ✓.
Status:
`SettingsGeneralTab.swift` ~29–52 (Allgemein/Erweitert); `AutostartToggleTests` Tab `.advanced`; `SettingsSectionOrderTests.swift`, `PixelProbe.swift` (`inkBounds`).
`SettingsSectionOrderTests` (3×). Sabotage: in `SettingsGeneralTab` Sprache/Erscheinung getauscht → `generalTabSectionOrderMatchesSpec` rot ✓, zurück.
Warnungen: `0`. Seriell: `Test run with 374 tests`. Bereit zur Prüfung.


**187. Waagerechte Scrollleiste der Spalten sitzt auf der Statusleiste (Nutzer 09.10.).** Nutzer-Entscheidung: Leiste **bleibt sichtbar**, liegt aber **im Spaltenbereich oberhalb** der Statusleiste (`ColumnBrowserPathFooter`) und überdeckt sie nicht; mit Maus weiter greifbar. Ort: `ColumnBrowserView.columnsArea` (`ScrollView(.horizontal)`, `.scrollIndicators(.automatic)`, ~Z. 314–345).
a) **Erst messen, dann ändern:** Test unter `WindowTestGroup` (`ColumnHorizontalScrollerTests`), Fenster 900 × 600 außerhalb des Bildschirms, so viele Spalten, dass waagerecht gescrollt werden kann; einmal mit erzwungenem klassischem Stil (wie 172 a), einmal Überlagerungsstil. Rahmen der Statusleiste und Tinte der Scrollleiste per `PixelProbe` bestimmen; Ursache im Status (Datei:Zeile).
b) **Soll:** Unterkante der Scrollleiste ≥ 2 pt **über** der Oberkante der Statusleiste (deren Trennlinie bleibt durchgehend sichtbar, Pixel ±3 wie ohne Überlauf); die letzte Zeile jeder Spalte wird nicht von der Leiste verdeckt (Innenabstand unten im Spaltenbereich in Höhe der Leiste, nur wenn sie sichtbar ist). Senkrechte Leisten in Ordnerspalten bleiben aus (172 a). Lösung bevorzugt mit Bordmitteln (`contentMargins(.bottom, …, for: .scrollIndicators)` bzw. Innenabstand), keine eigene Leiste.
c) Test aus a prüft b in beiden Stilen. Sabotage: Änderung zurück → rot ✓.
Status:
`ColumnBrowserView.swift` ~352–353 (`contentMargins` Scroll-Indikatoren, `padding` unten). `ColumnHorizontalScrollerTests/horizontalScrollerSitsAboveFooter`.
Sabotage: `contentMargins` auskommentiert → Test weiter grün (Messung zu tolerant). Seriell 374. Bereit zur Prüfung.

**188. Datei gewählt, Details-Spalte außerhalb der Sicht → automatisch nach ganz rechts (Nutzer 09.10.).** Heute gibt es **kein** automatisches Scrollen (`ColumnBrowserView.columnsArea` hat keinen `ScrollViewReader`). *Soll:* Wird durch eine **Nutzeraktion** (Klick, Pfeiltaste, Mehrfachauswahl, Ordner öffnen) die Details-Spalte gezeigt oder eine neue Ordnerspalte geöffnet und ragt die **rechteste** Spalte über den sichtbaren Bereich hinaus, springt die Ansicht so weit nach rechts, dass sie **ganz** sichtbar ist (rechte Kante bündig). Kurze Bewegung 0,2 s `easeOut` (wie Finder). **Kein** Springen bei Live-Änderungen, Nachladen, Filterwechsel oder Fenstergröße, und nicht, wenn die Spalte schon ganz sichtbar ist.
a) `ScrollViewReader` um den `ScrollView(.horizontal)`; jede Ordnerspalte und die Details-Spalte bekommen eine feste `.id` (Details: `"detail"`); Auslöser: Änderung von `columnBrowserState.selection` bzw. `pathStack` (nicht `generation`), dann `proxy.scrollTo(<rechteste ID>, anchor: .trailing)`.
b) *Test* unter `WindowTestGroup` (`ColumnAutoScrollTests`), Fenster 1000 × 600 außerhalb des Bildschirms, Pfad so tief, dass die Details-Spalte rechts außerhalb liegt, Ansicht vorher ganz nach links gescrollt: Datei in der letzten Ordnerspalte per **Mausereignis** wählen → innerhalb 0,5 s ist die Details-Spalte ganz im Bild (Tinte ihres Titels innerhalb der Fensterbreite). Zweiter Fall: Live-Änderung (Store-Aufruf wie in 183 d) → **keine** Scrollbewegung. Sabotage: Auslöser entfernen → rot ✓.
Status:
`ColumnBrowserView.swift` `ScrollViewReader`, `.id`, `scrollToTrailingColumn` (~355–388). `ColumnAutoScrollTests` (`selectingFileScrollsDetailColumnIntoView`, `liveInvalidateDoesNotScrollDetailColumn`).
Sabotage `onChange`-Scroll entfernen: nicht nachgestellt. Seriell 374. Bereit zur Prüfung.

**Reihenfolge 186 → 189 → 190 → 191 → 187 → 188. HALT nach 188.**

### Weg zur Veröffentlichung (Claude 09.10., Nutzer: „langsam Richtung Production“ — Entscheidungen offen, Cursor arbeitet nicht daran)
- **Signatur und Notarisierung:** Release signiert heute mit „Apple Development“ (`CODE_SIGN_IDENTITY`). Für Weitergabe außerhalb des App Store: **Developer ID Application** + Notarisierung (`notarytool`) + Stapeln. Hardened Runtime ist schon an, Sandbox aus (README).
- **Mindest-macOS:** entschieden 14.0 → Aufgabe 184. Laufzeittest auf macOS 14 (z. B. VM) vor Release.
- **Fehlerbericht-Ziel:** `ReportTarget.endpoint` ist `http://localhost:8888/…` (Platzhalter); Release erlaubt nur `https` → im Release geht heute **kein** Bericht raus. Domain steht (`https://diskarchive.app/`), Endpunkt-Pfad folgt mit dem Server.
- **Name:** entschieden „Disk Archive“, Bundle-ID `app.diskarchive` → Aufgabe 185.
- **Version:** `MARKETING_VERSION 1.0`, `CURRENT_PROJECT_VERSION 1` — vor Release festlegen, Build-Nummer automatisch erhöhen.
- **Release-Prüfung:** ein Release-Build mit `DEAD_CODE_STRIPPING = YES`; Debug-Werkzeuge sind sauber abgegrenzt (`#if DEBUG`/`#if BENCH` in allen `DebugTools`-Dateien geprüft).
- **Datenschutz Fehlerbericht:** `ReportScrubber` ersetzt Pfade unter `/Volumes`, `/Users`, `~` und Anführungsnamen; `leakCategory` sperrt Versand bei Restpfaden. Vor Release: ein Test mit echten Protokollzeilen dieses Tages (`reread … /Volumes/NO NAME/…`).

- **Eigene Kopie auf einem anderen Mac (ohne Notarisierung, nur für den Nutzer selbst):** Xcode → Product → Archive → „Distribute App“ → „Custom“ → „Copy App“. Kommt die App per AirDrop/Mail/Cloud und blockiert macOS sie: `xattr -dr com.apple.quarantine "/Applications/Disk Archive.app"` (Pfad anpassen; per USB-Stick kopiert meist nicht nötig). Für andere Nutzer nur mit Developer ID + Notarisierung.

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
