# TODO.md — offene Aufgaben für Cursor

Einzige Aufgabenliste. Erledigtes steht in [DONE.md](DONE.md), Verlauf und alte Spezifikationen in `archiv/`. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). **Komponenten (Maße, Farben, Zustände): [layout/Komponenten.dc.html](layout/Komponenten.dc.html), zusammengefasst in [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) — einzige Quelle für Größen.** Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

## Regeln für Cursor (verbindlich)

1. **Nur Aufgaben aus „A. Jetzt“**, in der dort stehenden Reihenfolge. „B. Backlog“ und alles andere nicht anfassen, auch nicht „vorbereiten“.
2. **Nach jedem Paket anhalten** (Zeile „HALT“). Erst weiterarbeiten, wenn Claude in A. freigegeben hat.
3. **Nichts erfinden.** Kein Feature, Text, Schalter, Screen ohne Vorgabe in README oder Layout. Fehlt etwas: Frage unter die Aufgabe schreiben („Frage:“), nicht bauen. Nötige Texte ohne Layout-Vorlage (ab 11.10., Nutzer): normal über `L10n`/`LayoutCopy` mit de und en anlegen und im Status als „Neue Texte:“ auflisten; der Nutzer prüft sie. Keine roten Vorschläge mehr.
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
21. **Keine System-Ereignisse aus Tests.** Verboten: `CGEvent(…).post(…)`, `CGWarpMouseCursorPosition`, `AXUIElement…`, alles, was die **echte** Maus/Tastatur des Nutzers bewegt oder Bedienungshilfen-Rechte braucht (Nutzer 09.10. 23:00: macOS fragte „Disk Archive möchte diesen Computer mit Funktionen der Bedienungshilfe steuern“). Klicks nur per `NSEvent.mouseEvent(…)` + `window.sendEvent` an das **eigene** Testfenster (wie `PixelProbe.click`). Kein `makeKeyAndOrderFront`, kein `NSApp.activate` (Regel 19).
22. **Kein Git, kein GitHub (AGENTS.md).** Keine verändernden Git-Befehle (`commit`, `add`, `push`, `pull`, `checkout`, `stash`, `worktree`, `reset` …), keine Best-of-N-Läufe mit Git-Arbeitskopien, nichts auf GitHub. Nur `git status`/`log`/`diff`/`show` zum Nachsehen.
23. **Zum Schluss die App bauen, die der Nutzer startet (Nutzer 10.10.).** Letzter Schritt jeder Aufgabe, **nach** Sabotage-Rücknahme und Testläufen: `xcodebuild build -project diskindex.xcodeproj -scheme diskindex -configuration Debug -destination 'platform=macOS'` **ohne** `-derivedDataPath` (Ziel: `~/Library/Developer/Xcode/DerivedData/diskindex-…/Build/Products/Debug/Disk Archive.app`, dort startet der Nutzer). Dann belegen: `stat -f '%Sm' -t '%H:%M:%S'` der Datei `Contents/MacOS/Disk Archive` ist **jünger** als die zuletzt geänderte `.swift`-Datei (`find diskindex -name '*.swift' -newer <App-Binary>` muss **leer** sein). Beide Uhrzeiten in den Status. Ohne diesen Beleg gilt die Aufgabe als nicht gemacht. Grund: Am 10.10. testete der Nutzer einen Sabotage-Build, weil nach der Rücknahme nicht mehr gebaut wurde.

---

## A. Jetzt — Version 0.2 „Alle bekannten Fehler“

**Maßgeblich für Versionen und Reihenfolge: README, Abschnitt „Roadmap“** (ausführlich: [ROADMAP.md](ROADMAP.md), folgt der README). In A steht nur, was zur **laufenden Version (0.2)** gehört, also bekannte **Fehler**. Was nach dem Einfrieren auffällt und kein Fehler ist, kommt nach B mit Zielversion.

**Stand 11.10.:** Abgenommen bis 219 (siehe DONE.md). **0.2 eingefroren (Nutzer 11.10.: Start 0.3).** Fehler aus dem Alltagstest kommen weiter hierher und haben Vorrang. **Freigegeben: 221 (0.2, Rest) → 230 (0.3, erster Schritt). HALT nach 230.** Schema 0.3 vom Nutzer freigegeben (11.10.).

**Claude-Prüfung 11.10. (5):** 219 **abgenommen**. Claude: 0 Warnungen, **421 Tests seriell grün**, App 11:02:12 aktuell. Datenbank öffnet in `Task.detached`, Verdrahtung danach auf dem Hauptfaden, `quick_check` nur bei Bedarf im Hintergrund. Volltext: `archiv/todo-stand-2026-10-11e.md`.

**Arbeitsregeln je Aufgabe (gelten zusätzlich zu den 23 Regeln):**
- **R1 Nur die genannten Stellen ändern.** Jede Aufgabe nennt Datei und Zeile. Andere Dateien nur, wenn die Aufgabe es sagt. Keine „Verbesserungen nebenbei“.
- **R2 Beweis = Pixel aus einem echten Fenster.** `hitTest != nil`, `source.contains(…)`, Zahlenvergleiche mit Konstanten und Prüfungen nur am Datenmodell zählen **nicht** als Beweis für Aussehen oder Klickverhalten. Benutze dafür ausschließlich die Hilfe `PixelProbe` (Aufgabe 150 a). Jeder neue Test wird einmal **sabotiert** und muss dann rot sein; im Status: „Sabotage: rot ✓“.
- **R3 Status je Aufgabe:** höchstens 5 Zeilen: geänderte Dateien:Zeilen, Testname, Ergebnis der Sabotage, Pfad der Bildschirmfotos (`Werkzeuge/screenshots/<JJJJ-MM-TT>-<aufgabe>/`).

### Liste der bekannten Fehler (0.2, Claude sammelt)

| Nr. | Fehler | Herkunft | Stand |
|---|---|---|---|
| 195 | `MustScanSubDirs` unter der Wurzel verlor Änderungen; `.counts` verwarf Spalten-Invalidierung | Claude-Prüfung 192 | **behoben** 10.10. |
| F1 | Testlücke: `BulkDirectoryReaderTests` (FAT-Abbild) endet mit `return` und meldet **grün**, wenn `hdiutil create/attach` scheitert (in Claudes Umgebung so geschehen) → prüft dann nichts. Soll: sichtbar überspringen oder rot. | Claude 10.10. | **behoben** 10.10. (197; Abbild 64m, Test lief vorher nie) |
| F3 | Waagerechte Scrollleiste liegt **auf** der Statusleiste und verdeckt den Pfadtext; senkrechte Leisten je Spalte fehlen (README „Spaltenansicht: Scrollen“, Nutzer 10.10.) | Nutzer 10.10. (Foto) | **behoben** 10.10. (198) |
| F4 | Detail-Spalte erscheint **ohne Auswahl**, sobald die Ordnerspalten breiter als das Fenster sind (README 5: nur bei Datei oder Mehrfachauswahl) | Nutzer 10.10. (Foto) | **behoben** 10.10. (199) |
| F5 | Demo-Medium „Spalten-Zustände (Demo)“ entfernen (Nutzer 10.10.: Layouts sind abgenommen, wird nicht mehr gebraucht) | Nutzer 10.10. | **behoben** 10.10. (200) |
| F6 | Fehlerdialog zeigt **nie** einen Grund: `IndexingService` meldet immer `reason: .unknown`; `IndexRunOutcome` trägt keinen Fehler, `IndexFailureReason.classify` wird nur von Tests benutzt (README 2b verlangt den Grund) | Claude-Durchsicht 10.10. | **behoben** 10.10. (202) |
| F7 | Englisch unvollständig: feste deutsche Texte außerhalb von `L10n` (Kontextmenü, Menüleisten-Rechtsklick, Mitteilungen, Fehlergründe, Statuszeilen, Altersfilter, Fußzeile „x von y ausgewählt“, „Zuletzt indiziert“, Platzhalter) und feste `de_DE`-Formate | Claude-Durchsicht 10.10. | **behoben** 10.10. (203) |
| F8 | Toter Code, nur von Tests benutzte Logik, Doppeltes | Claude-Durchsicht 10.10. | **behoben** 10.10. (201) |
| F10 | Tests schreiben in die echten Einstellungen des Nutzers (`UserDefaults.standard` = `app.diskarchive`) | Claude-Prüfung 10.10. | **behoben** 10.10. (205) |
| F11 | `serviceRunPassesTheReasonToTheDialog` fällt im **parallelen** Lauf selten aus (2× gesehen, Meldung nicht erfasst; seriell 10/10 grün) | Agent 10.10. | beobachten; beim nächsten Ausfall Meldung sichern |
| F12 | Jeder Testlauf hinterlässt eine Datei `~/Library/Preferences/app.diskarchive.tests.<pid>.plist` (16 Stück am 10.10.) | Claude-Prüfung 10.10. | **behoben** 10.10. (208) |
| F9 | Stresstest 1 TB (Nutzer 10.10.): erster Lauf zeigt **2 Minuten nichts** (Start 10:13:02, „ebene 1 fertig“ 10:15:02), weil die **Zählphase** (README 4) erst den ganzen Baum liest, bevor Ebene 1 geschrieben wird. Widerspricht „Schichten: erste Ebene sofort sichtbar“ | Claude, Protokoll 10.10. | **behoben** 10.10. (206, Nacharbeit 209) |
| F13 | Beim Abgleich nach dem Start blinkt die Prozentzahl im Dashboard grün/rot: der Hintergrund-Nachzähler (`DirectoryIndexer` ~Z. 146 `Task { runCountingPhase(… onProgress: onProgress) }`) meldet `.counting`, die Ebenen-Schleife gleichzeitig `.indexing` → Phase springt | Nutzer 11.10., Claude-Ursache | **behoben** 11.10. (210) |
| F14 | Spinner im Dashboard-Chip dreht sich nicht (steht in `TimelineView`, die 30× pro Sekunde neu zeichnet; `IndexingSpinnerRing` nutzt `repeatForever` aus `onAppear`) | Nutzer 11.10. | **behoben** 11.10. (210) |
| F15 | Suche zählt höchstens 50.000 (`IndexStore.searchCount` mit `scope` holt `limit: 50_000` und zählt in Swift); „.html“ ergibt 50.000 statt ca. 1,6 Mio. | Nutzer 11.10. | **behoben** 11.10. (211) |
| F16 | Suchergebnisse flackern im Takt des Fortschritts (`runSearch` leert `searchMatch` vor jeder neuen Suche; jede Live-Meldung startet die Suche neu) | Nutzer 11.10. | **behoben** 11.10. (211) |
| F17 | X im Suchfeld leert das Feld, aber nicht die Suche | Nutzer 11.10. | **behoben** 11.10. (211) |
| F18 | Scrollleisten fehlen in der Ergebnisliste der Suche, in Einstellungen → Speichermedien und in sehr großen Ordnern (`ColumnFolderTableView` ~Z. 26 `hasVerticalScroller = false`) | Nutzer 11.10. | **behoben** 11.10. (212) |
| F19 | Prozentzahl im Menüleisten-Popover nicht rechtsbündig | Nutzer 11.10. (Foto) | **behoben** 11.10. (213) |
| F20 | Rote Vorschlagstexte gelten als festgelegt (Nutzer 11.10.: „setze alle roten Texte als gesetzt“) | Nutzer 11.10. | **behoben** 11.10. (214) |
| F21 | `DelayedLoadingStateTests.fastLoadNeverShowsHint` wackelt parallel (10 ms gegen 50 ms) | Agent 11.10. | **behoben** 11.10. (217) |
| F22 | Ergebnistabelle (Suche, vermutlich auch Favoriten) nutzt die Fensterbreite nicht: Name und Pfad stehen auf Mindestbreite (160/140), Status nicht rechts, rechts große Leerfläche. **Rückschritt aus 212** (Breite per Preference gemessen, kommt offenbar als 0 an) | Nutzer 11.10. (Foto) | **behoben** 11.10. (218) |
| F23 | Weitere Tests mit kurzem `Task.sleep` (< 200 ms), mögliche Wackler unter Last: `ChangeWatcherTests`, `ColumnCacheTests`, `ColumnLiveRenameTests`, `IndexStoreTests`, `SurfaceStoreTests`, `SurfaceTestSupport`, `WindowTestGroupStoreCacheTests` | Agent 11.10. (217) | beobachten; erst bei einem Ausfall angehen |
| F24 | Start: Wartekreisel („Spinning Ball“), Menüleistensymbol erst nach Sekunden. Protokoll 11.10.: `app launch` 10:24:53 → `store open ok` 10:25:12 = **19 s** (kalt), zweiter Start 3,3 s. Ursache: `IndexStore.openDefault()` läuft **synchron auf dem Hauptfaden** (`AppDelegate.startMediumRecognition` ~Z. 279) und `IndexDatabase` macht bei jedem Öffnen `PRAGMA quick_check` über die ganze Datei (1,4 GB; `Storage/IndexDatabase.swift` ~Z. 60) | Nutzer 11.10., Claude-Ursache | **behoben** 11.10. (219); gemessen: Datenbank offen 17–31 ms, bereit nach 0,1–0,25 s (vorher 3–19 s); Prüfung 3,5 s im Hintergrund |
| F25 | Bereinigen nach geringerer Scan-Tiefe extrem langsam (Messung 196: S1 nach 15 min nichts entfernt, S2 479 Einträge/s ≈ 1,6 h); vermutlich `DELETE … WHERE path …` ohne `mediumID` → Suchhilfe `item_path` greift nicht | Agent 11.10. (196) | **löst 0.3** (Status-Flag, kein Pfad); bis dahin Scan-Tiefe nicht verringern |
| F26 | Großes WAL nach langem Schreiben: erstes Öffnen danach 116 s (S2) | Agent 11.10. (196) | **in 0.3** regelmäßig `wal_checkpoint(TRUNCATE)` nach Läufen, `journal_size_limit` |
| F2 | Live-Überwachung am echten Stick nach 195 bestätigen: Umbenennen, neuer Ordner, Kopieren, Spalte bleibt sichtbar und aktualisiert sich | Nutzer 09.10. | **bestätigt** 10.10. (erster Test lief mit veraltetem Sabotage-Build → Regel 23) |

Weitere Fehler aus dem Alltag trägt Claude hier ein, sobald der Nutzer sie meldet.



**221. „Über Disk Archive“ und „Einstellungen …“ (0.2, Nutzer 11.10.).**
a) **Rechtsklick-Menü der Menüleiste** (`MenuBar/MenuBarController.swift` `showContextMenu` ~Z. 224): neuer Eintrag **„Über Disk Archive“** ganz oben (vor „Disk Archive anzeigen“, danach Trennlinie). Öffnet das **Standard-Infofenster von macOS** (`NSApp.orderFrontStandardAboutPanel(options:)`) mit Name, Symbol, Version (0.2.0) und Build; in den Zusatzangaben (`.credits`) ein klickbarer Link **https://diskarchive.app**. Fenster vorne (App kurz aktivieren ist hier erlaubt, es ist eine Nutzeraktion).
b) **Programm-Menü** (sichtbar, solange das Hauptfenster offen ist): „Über Disk Archive“ öffnet dasselbe Fenster (eine Stelle im Code). **„Einstellungen …“ (⌘,)** öffnet heute ein **leeres** Fenster (`diskindexApp.swift` ~Z. 40: `Settings { EmptyView() }`) → stattdessen das Hauptfenster mit dem Bereich **Einstellungen** öffnen (`CommandGroup(replacing: .appSettings)`), die leere `Settings`-Szene entfernen, ohne dass ein zusätzliches Fenster entsteht.
c) Neue Texte de/en über `L10n` („Über Disk Archive“ / „About Disk Archive“; „Einstellungen …“ / „Settings…“), im Status als „Neue Texte:“.
d) Tests: Menüeintrag vorhanden und an erster Stelle; die Inhalte des Infofensters (Version, Build, Link) kommen aus einer Funktion, die getestet wird; ⌘,-Befehl setzt `mainWindowDestination == .settings`. Kein echtes Fenster auf dem Bildschirm (Regel 19). Sabotage → rot ✓. Seriell, Warnungen 0, Regel 23.
Status: `App/AboutPanel.swift` (neu: Inhalt aus `AboutPanel.content/options/credits`, Link diskarchive.app; `AppMenuCommands.openSettings`), `MenuBarController.swift` (`makeContextMenu()`, „Über Disk Archive“ ganz oben + Trennlinie), `diskindexApp.swift` (`.appInfo` und `.appSettings` ersetzt, ⌘, → `.settings`), `LayoutCopy+Menus.swift`, `Localizable.xcstrings`. Test `AboutAndSettingsMenuTests` (4); Sabotage (Reihenfolge, Link, Ziel) rot ✓; seriell 429 grün.
Neue Texte: `copy.menubar.about` „Über Disk Archive“ / „About Disk Archive“; `copy.appmenu.settings` „Einstellungen …“ / „Settings…“.
Frage: Die leere `Settings { EmptyView() }`-Szene steht noch in `diskindexApp.swift`: Ohne Szene gibt es in SwiftUI keinen Träger für `.commands` (`defaultLaunchBehavior` erst ab macOS 15, Ziel 14). Sie lässt sich nicht mehr öffnen (⌘, ist ersetzt), es entsteht kein Fenster. Menü-Texte wechseln erst nach Neustart die Sprache.
Bereit zur Prüfung.

### Version 0.3 — Neue Datenbankstruktur (begonnen 11.10.)

**196 abgenommen (Claude 11.10.):** 0 Warnungen, 423 Tests seriell grün, App 18:58:57 aktuell. Ergebnisse: `Werkzeuge/messung/2026-10-11-vorher.md`. Rest von g): `DebugTools/ColumnLoadBench.swift` und `Werkzeuge/column-load-bench.sh` löscht der Nutzer (Agent durfte nicht).

**220 abgenommen (Claude 11.10.):** `MARKETING_VERSION` 0.2.0 überall, Build-Nummer = Zeitstempel `jjjjMMtthhmm` (Skript-Phase, gebaute App: 0.2.0 / 202610111927, Signatur gültig), 425 Tests seriell grün, 0 Warnungen. Version erscheint heute nur in Protokoll, Fehler- und Absturzbericht.

**Plan 0.3 (Claude 11.10., Grundlage `datenbank-konzeption.md`: „Grundsatz ab 0.3“, „Schema-Skizze“, „Besprechung“, „Überprüfung“, „Messung 196“).** Die neue Speicherschicht entsteht **neben** der alten; die App läuft bis zum Umschalten (233) unverändert weiter. Reihenfolge, je eine Aufgabe mit Abnahme:
- **230** Schema und Grundbausteine (diese Aufgabe, unten).
- **231** Schreibwege auf dem neuen Schema (Indizieren, Abgleich, Überwachung, Entfernen über Laufnummer, Medien in `storages`/`storage_meta`, Favoriten).
- **232** Lesewege (Spalten natürlich sortiert und gemischt, Suche `LIKE` auf `slug` **parallel in Bereichen** inkl. Mediennamen, Zahl, Filter über `kind`/`extID`/`modifiedAt`, Favoriten, Pfad durch Verkettung).
- **233** Umschalten: App nutzt nur noch die neue Schicht, alte Datenbank wird beim Start verworfen, alter Code (`item_fts`, `path`, `pruneToMatch`, `checksNames` …) entfernt.
- **234** Status-Flag und Warteschlange für Regeländerungen (ersetzt Bereinigen nach Bereich; Suche wartet, Spalten „Inhalte werden geladen“; Pflicht: nie hängen bleiben).
- **235** Umbenennen/Verschieben erkennen (fileID auf APFS/HFS+, Ereignispaare live, FAT-Merkmale ±1 h, Teil-Prüfsumme für Favoriten).
- **236** Wartung (Zeit + Zähler), WAL nach Läufen kürzen (F26).
- **237** Einstellungen in die Tabelle `settings` (außer Sprache, Fensterposition).
- **238** Messung „nachher“ mit 196 und Vergleich; danach Schema einfrieren.

**230. Neues Schema und Grundbausteine (0.3).** *Nur anlegen und testen, die App benutzt es noch nicht.*
a) **Neue Datei(en)** unter `Storage/V3/` (z. B. `SchemaV3.swift`): Funktion, die in einer **leeren** Datenbank das Schema aus `datenbank-konzeption.md` → „Schema-Skizze“ anlegt – **alle** Tabellen: `storages`, `storage_meta`, `items`, `item_details`, `item_meta`, `item_checksum`, `favorites`, `extensions`, `meta_keys`, `settings`, `api_queue`. Spalten, Typen und Bedeutungen genau wie dort; Kennungen `INTEGER PRIMARY KEY AUTOINCREMENT` (nie wiederverwendet); Verweise `ON DELETE CASCADE` (auch `items.parentID` → `items.id`); Zeiten `INTEGER` (Sekunden seit 1970), Ja/Nein und Aufzählungen `INTEGER`; `storages.uuid`/`volumeUUID` `BLOB` 16; `item_checksum.partial/full` `BLOB`; `item_meta.source` `INTEGER`. `PRAGMA foreign_keys = ON`, WAL, `journal_size_limit` (z. B. 64 MB).
b) **Suchhilfen** wie in der Skizze: Eindeutigkeit `items(storageID, ifnull(parentID,0), name)`; Spalten `items(storageID, parentID, status, slug COLLATE natural)`; Suche `items(slug, status)`; `items(modifiedAt)`; `items(storageID, fileID) WHERE fileID IS NOT NULL`; `items(storageID, lastSeenRun)`; `item_checksum(full) WHERE full IS NOT NULL`; `storages(slug)`.
c) **Grundbausteine (je eine Stelle im Code, mit Tests):**
- `Slug.make(_:)`: klein, Umlaute/Akzente → Stammlaut (ä→a, ö→o, ü→u, é→e …), ß→ss; dieselbe Funktion für Suchbegriffe.
- Sortierung **„natural“**: als SQLite-Sortierfolge auf **jeder** Verbindung registriert (GRDB `DatabaseCollation`) und dieselbe Vergleichsfunktion in Swift; Zahlenfolgen werden als Zahl verglichen („datei 2“ < „datei 10“), sonst wie `slug`. Ordner und Dateien **gemischt** (kein `isFolder` in der Sortierung).
- `ItemKind`: feste Zahlen je Kategorie, **genau** die Gruppen von `SearchFileTypeFilter` (pdf, text, documents, image, video, audio, archive, programs, scripts; 0 = sonstige; Ordner über `isFolder`), Zuordnung aus der heutigen Endungsliste übernommen (eine Quelle für Filter und Schema).
- Zeit: `Date` ↔ `INTEGER` Sekunden (eine Hilfsfunktion).
- Status: `Storage/V3/` neu: `SchemaV3.swift` (11 Tabellen, 8 Suchhilfen, AUTOINCREMENT, Kaskaden, WAL, `journal_size_limit` 64 MB), `Slug.swift`, `NaturalOrder.swift` (Swift + GRDB-Sortierfolge `natural` auf jeder Verbindung), `ItemKind.swift` (Kategorien aus `SearchFileTypeFilter`, Status, Herkunft, Zeit). `SchemaV3Tests` (9: Tests (1)–(6) + Kind/Zeit); Sabotage je Baustein (AUTOINCREMENT, Kaskade, Index, Slug-ß, Sortierung, Suchhilfe) rot ✓. App und alte Datenbank unverändert.
Befunde: `natural` ist in SQL ein Schlüsselwort → Sortierfolge in Anführungszeichen (`COLLATE "natural"`). `journal_size_limit` gilt nur für die Schreibverbindung (Leser schreibgeschützt). `extID` kaskadiert wie verlangt (Löschen einer Endung löscht Einträge; Endungen werden nie gelöscht). Frage: Soll `storages.uuid` eine eindeutige Suchhilfe bekommen (steht nicht in der Skizze)?
Seriell 438 grün, parallel 2/2 grün, Warnungen 0, Build 20:09:04, neueste Swift 19:58:46. Bereit zur Prüfung.
d) **Tests:** (1) Schema in Temp-Datenbank anlegen → alle 11 Tabellen und alle Suchhilfen vorhanden (`sqlite_master`), Spalten und Typen wie vorgegeben (`PRAGMA table_info`); (2) `AUTOINCREMENT`: Eintrag löschen, neuen anlegen → neue Kennung größer als alle bisherigen; (3) Löschen eines Mediums entfernt `items`, `item_details`, `item_meta`, `item_checksum`, `favorites`, `storage_meta` (Kaskade); (4) `Slug.make`: „Ärger Über Öl“ → „arger uber ol“, „Straße“ → „strasse“, „Café“ → „cafe“; (5) natürliche Sortierung in SQL **und** Swift gleich: [„Datei 10“, „datei 2“, „Ordner“, „Älter“] → „alter“, „datei 2“, „datei 10“, „ordner“; (6) Abfrageplan (`EXPLAIN QUERY PLAN`) der Spalten-Abfrage nutzt die Spalten-Suchhilfe ohne Zwischensortierung, die Suche (`slug LIKE '%x%' AND status = 0`) die Suche-Suchhilfe. Sabotage je Baustein → rot ✓.
e) Die bestehende Datenbank und alle bisherigen Abfragen bleiben **unverändert**. Seriell, Warnungen 0, Regel 23.
Status:

---

---

---

### Vor 0.4: Voraussetzungen für die Weitergabe

Siehe README, Abschnitt „Roadmap“ (0.4). Cursor arbeitet nicht daran; die Liste steht in B unter 0.4. Merkhilfe für den Nutzer (bleibt hier):

- **Eigene Kopie auf einem anderen Mac (ohne Notarisierung, nur für den Nutzer selbst):** Xcode → Product → Archive → „Distribute App“ → „Custom“ → „Copy App“. Kommt die App per AirDrop/Mail/Cloud und blockiert macOS sie: `xattr -dr com.apple.quarantine "/Applications/Disk Archive.app"` (Pfad anpassen; per USB-Stick kopiert meist nicht nötig). Für andere Nutzer nur mit Developer ID + Notarisierung.

### Offen, ohne Cursor

- **Nutzer:** (1) Kurztest am Stick für 107: großen Ordner öffnen, Pfeiltasten, Mehrfachauswahl, Rechtsklick. (2) Layout nachziehen: alte Chip-Beschreibungstexte, Menüleisten-Symbol „blauer Spinner (Abgleich)“ (112 Punkt 3), Texte der roten Vorschläge (Debug-App prüfen). (3) Entscheiden: T5 (ausführliches Protokoll) freigeben?
- **Claude:** Layout (Stand 07.10.) gegen README abgleichen; danach neue Aufgaben für Cursor schreiben. Spezifikationen der abgenommenen Aufgaben: `archiv/todo-stand-2026-10-07.md`.

---

## B. Backlog (nicht freigegeben, Cursor arbeitet nicht daran) — nach Zielversion

### Ohne feste Version (klein)


### 0.3 — Neue Datenbankstruktur (Roadmap 0.3, `datenbank-konzeption.md`)

Reihenfolge: (1) Messwerkzeug 196 und Messung „vorher“ → (2) Architektur entscheiden (eine Datei oder Datei je Medium plus Register) → (3) Konvention Seitentabellen (`item_<funktion>`, `itemID`, `ON DELETE CASCADE`, `srcSize`, `srcModifiedAt`, `extractorVersion`; Thumbnails in eigener Datei) → (4) Zuschnitt `item`/`medium` → (5) Schema neu, Abfragen umstellen (erst Schreib-, dann Lesewege, kleine Aufgaben mit Zwischenabnahme) → (6) Messung „nachher“ gegen die Schwelle → (7) Altlasten entfernen.


### 0.4 — Letzte Fixes, Beta für Beta-Tester

- **Signatur und Notarisierung:** Release signiert heute mit „Apple Development“ (`CODE_SIGN_IDENTITY`). Nötig: **Developer ID Application** + Notarisierung (`notarytool`) + Stapeln (Bezahl-Mitgliedschaft Apple Developer Program). Hardened Runtime ist an, Sandbox aus.
- **Download-Seite** auf `https://diskarchive.app/` mit stabilem Link (Nutzer, nicht Cursor).
- **Versions-Check:** `version.json` bzw. `GET …/api/version/` (existiert), Dialog „Neue Version verfügbar“ **einmal je Version**, Link **nur** auf `diskarchive.app`, Schalter in den Einstellungen; Datenschutztext, README 8 und 9 anpassen.
- **Beta-Verfallsdatum** mit freundlicher Meldung.
- **`FeatureAccess`:** zentrale Stelle „Darf der Nutzer das?“, in der Beta immer „ja“ (Vorbereitung 0.9).
- **macOS 14:** Mindestversion entschieden (184 erledigt); **Laufzeittest auf macOS 14** (z. B. VM) steht aus.
- **Fehlerbericht:** Ziel live `https://diskarchive.app/api/issues` (193 erledigt). **Datenschutz:** `ReportScrubber` ersetzt Pfade unter `/Volumes`, `/Users`, `~` und Anführungsnamen; `leakCategory` sperrt Versand bei Restpfaden. Test mit **echten Protokollzeilen** (`reread … /Volumes/NO NAME/…`).
- **Name:** „Disk Archive“, Bundle-ID `app.diskarchive` (185 erledigt).
- **Release-Prüfung:** Release-Build mit `DEAD_CODE_STRIPPING = YES`; Debug-Werkzeuge sauber abgegrenzt (`#if DEBUG`/`#if BENCH` in allen `DebugTools`-Dateien geprüft).
- **Update durch Ersetzen der App:** Bundle-ID und Datenordner gleich, Einzelinstanz-Übergabe nach Version (neuere übernimmt), Launch Agent beim Start neu registrieren.
- **Ab 0.4 echte Migrationen:** Sicherungskopie vor jeder Migration, Schutz vor Rückschritt (GRDB `hasBeenSuperseded`, Namen prüfen).

### 0.5 — Metadaten und EXIF
Wartet auf das **Layout vom Nutzer** und eine eigene Besprechung (README Roadmap). Felder: `datenbank-konzeption.md`.

### 0.6 — Vorschaubilder
Eigene Datei, **Abschalter global und je Medium**. Größe laut README **250 px** lange Seite (Nutzer 10.10.). Wird vor dem Start besprochen.

### 0.7 — CSV-Export
Noch nicht ausgearbeitet; vier offene Fragen in README (Roadmap).

### 0.8 — Duplikate
Über alle Medien, stufenweise, nur im Hintergrund (README).

### 0.9 — Lizenz
Nach Medienzahl **1 / 50 / 250**; offene Fragen in README.

### Ohne Zielversion (wartet auf Entscheidung des Nutzers)

- **T1. Ladehinweis erst nach 1 s** (Nutzer 06.10.): gehört zu 107; Suche/Favoriten später.
- **T2. Programme als Dateityp „Programme“** (`.app`-Pakete, dmg, pkg).
- **T3. Erweiterte Dateityp-Icons** (Styleguide Sektion 15).
- Cursor hat T1–T3 vorzeitig gebaut; Claude entscheidet bei der Prüfung, was bleibt.
- **T5 (Vorschlag Claude, wartet auf Nutzer): Ausführliches Protokoll („Diagnose-Modus“).** Es gibt schon `~/Library/Logs/Disk Index/diskindex.log` (Kategorien, `crash-last.txt`, „previous run ended without clean exit“). Lücken: (1) **Beenden wird nicht protokolliert** (`applicationShouldTerminate` schreibt nichts; nur `applicationWillTerminate` „app terminate ok“) → Zeilen „quit requested (Quelle)“, „quit: status item entfernt“, „quit: Indizierung gestoppt“ mit Dauer. (2) **Haupt-Thread-Wächter:** blockiert der Hauptfaden > 2 s, Zeile `hang main ms=…` mit Stack (Release tauglich). (3) **Schalter** „Ausführlich“ (Erweitert, nur Debug oder per `defaults`) für Pegel `debug`: je Medium Dauer von Lesen/Schreiben, Cache-Treffer, Ladezeiten Spalten, Speicher. (4) `crash-last.txt` auch bei Beenden durch Signal. Nicht freigegeben.
