# TODO.md — offene Aufgaben für Cursor

Einzige Aufgabenliste. Erledigtes steht in [DONE.md](DONE.md), Verlauf und alte Spezifikationen in `archiv/`. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

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
10. **Nach Fehlern zurückrollen statt überbauen:** schlägt ein Test fehl, Ursache beheben, nicht Test abschwächen.

---

## A. Jetzt

**Stand 06.10. abends:** Paket 1, 2 und die Spaltenansicht (102, 114, 119, 120, 121) sind abgenommen, siehe DONE.md. Offen: Paket 3 (107, 109), dann Paket 4 (110, 111, 112 Rest, 113). Reihenfolge der Freigabe bestimmt Claude.

## ARBEITSAUFTRAG JETZT

**Kein Auftrag offen.** Pakete 1–4 sind abgenommen (siehe DONE.md). Cursor wartet auf neue Aufgaben von Claude und arbeitet **nicht** am Backlog.

### Claude-Prüfung 06.10. (Code, Unit-Tests, Bildschirmfotos)

- **Abgenommen 06.10. abends** (nach DONE.md): 114 (Köpfe nur Ortsname, Hinweisflächen in der Ordnerspalte, Chip in Detail-Spalte weg, `07-nicht-erfasst` zeigt den Zustand), 119 (Rot sichtbar in `11-favoriten-vorschlag`), 102 (Test jetzt grün; Ursache war die Einrichtung des Tests: der Schreibvorgang löste zu Recht eine Invalidierung aus; Aussage „Meta-Ticks laden nicht neu“ bleibt geprüft), 120, 121. Claude-Testlauf 06.10. ~21:10: **269 Tests, 52 Suiten, seriell grün**; `default.profraw` weg.
- **112 Punkt 2** (Mitteilung bei Indizierungsfehler, Klick öffnet Dialog): vorhanden, Tests grün. Punkte 3–5 offen.
- **113 Button-Regeln:** `06-detail` in Ordnung, übrige Ansichten ungeprüft.
- **109 abgenommen** (06.10. ~22:30): Cancellation sauber, stille `try? store…` behoben (Liste im Status, Test `FolderLoadErrorLoggingTests`). Nach DONE.md.
- **107 abgenommen mit Vorbehalt** (06.10. ~22:40): Umgebungsfehler behoben; `07-*`-Bildschirmfotos (Claude selbst erzeugt) zeigen Zeilen, Mehrfachauswahl und Kontextmenü; **274 Tests, 56 Suiten, seriell grün**. Vorbehalt: Tastatur (Pfeile), Ziehen und Klicks in der echten App sind nur durch Cursors Aussage belegt → **Nutzer testet kurz am Stick** (großen Ordner öffnen, Pfeiltasten, Mehrfachauswahl, Rechtsklick).
- **110, 112 (Punkte 4 und 5), 113 abgenommen** (07.10. ~00:35): `DebugTools/` angelegt, Release enthält laut Cursors `nm`-Nachweis keine Debug-Werkzeuge, Testhilfen verschoben, `LaunchTests` weg; Texte in `LayoutCopy` mit Test; Knopf-Höhen einheitlich (`05-erweitert` im Bildschirmfoto geprüft: gleiche Höhe, Layout-Stil). **Offen:** wackelnder `IconCandidateTests` (Schritt 0), 112 Punkt 3 (blaues Abgleich-Symbol) ist Nutzer-Sache im Layout.
- **Offen ohne Prüfung:** 111.

---

### Offene Spezifikationen

### 107. Große Ordner laden und darstellen: Datenbank, Speicher, Ansicht (alt: 89 D, 90 B8)

**Status (Cursor 06.10. ~22:14):** `ColumnFolderTableView`: Zeilen mit `.environment(appState)` (+ proposal-Highlight); `allowsMultipleSelection=true`. Verhalten: Klick/Mehrfach/Pfad/Kontext/Hover/Fade/Höhe ok (Screenshots). Test `ColumnFolderTableEnvironmentTests`. Runner layoutet Tabellen vor Foto.
Fotos `Werkzeuge/screenshots/2026-10-06-r3/07-*` ~22:10 (hell/dunkel, Zeilen sichtbar).
Debug+Release OK; seriell **274**/56 ~22:13:24; parallel OK ~22:14:29 (`-only-testing:diskindexTests`).
**Bereit zur Prüfung.**

**Testfälle (Nutzer 05.10.: es können wenige Ordner mit vielen Dateien sein, viele Ordner mit vielen oder mit wenigen Dateien):** Alle Messungen, Tests und Abnahmewerte in dieser Aufgabe gelten für **drei Formen**: (a) **wenige Ordner, sehr viele Dateien** (3 × 100.000), (b) **sehr viele Ordner, wenige Dateien** (100.000 Ordner × 5 Dateien = 600.000 Einträge, Tiefe 4), (c) **viele Ordner und viele Dateien** (20.000 Ordner × 50 Dateien, Tiefe 5). Bei (b) und (c) zählt der **Ordner-Durchsatz** (Ordner je Sekunde, Aufwand je Ordner wie Öffnen, Lesen, Prüfen der Stempel) genauso wie der Datei-Durchsatz.

**Harte Anforderung (Nutzer 05.10.): Leistungsprobleme sind keine Option. Die App muss auch Ordner mit sehr vielen Einträgen und sehr große Medien verarbeiten.** Zielgrößen (Nutzer: „weniger Ordner mit sehr vielen Dateien“, Dateigröße ist egal, die App liest nur Metadaten): **wenige Ordner mit sehr vielen Dateien**, z. B. **3 Ordner mit je 100.000 Dateien** und **ein Ordner mit 200.000 Dateien**, **ein Medium mit 1.000.000 Einträgen**. Lesen und Indizieren dürfen dabei nur die Dauer verlängern, nie die Bedienung blockieren oder Speicher aufblähen (< 400 MB zusätzlich).

**Befund (Claude, gemessen):** SQL je Seite mit 500 Zeilen auf 30.000 Kindern **6 bis 23 ms**, Plan `SEARCH item_parent` + **`USE TEMP B-TREE FOR ORDER BY`**; das Protokoll zeigt `children count=14300 ms=600`. Die Zeit steckt im Swift-Teil: `SELECT item.*` inkl. `path` für jede Zeile, GRDB-Dekodierung mit Datumsparsing, je Seite erneutes Sortieren des ganzen Ordners durch `OFFSET`. Dazu hält die Spalte **alle** Zeilen als `[IndexedItem]` im Speicher, `ForEach` über 14.300 bis 200.000 Elemente prüft Kennungen bei jeder Änderung (`filteredItems` mehrfach je Aufbau).

**Laden großer Ordner in der Spaltenansicht**:
1. **Neuer Index** `item_children ON item(mediumID, parentID, isFolder DESC, name COLLATE NOCASE, id)` (Migration v6), damit **kein Sortieren** mehr nötig ist; Abfrage per **Schlüsselseitenwechsel (keyset)** statt `OFFSET`: `WHERE mediumID=? AND parentID IS ? AND removedAt IS NULL AND (isFolder, name COLLATE NOCASE, id) > (?, ?, ?)` bzw. gleichwertig.
2. **Schmale Zeilen:** für die Spalte nur `id, name, isFolder, isPackage, ext, sizeBytes, modifiedAt, isFavorite, depth, contentStamp` laden (kein `path`, kein `JOIN medium`; `mediumUUID` ist bekannt). Datum **nicht pro Zeile als String parsen**: aus der Spalte als `Double`/`Int` oder erst bei Bedarf (sichtbare Zeilen).
3. **Spaltenkopf und Zeilen (Layout 07, Nutzer 06.10.):** Pro Spalte **nur der Ortsname** im Kopf (groß), **keine** Elementanzahl (Zählung in der Fußzeile). **Eine Zeile**, **nicht umbrechen**; bei Überlauf **Fade-Verlauf** statt Auslassungspunkte — **Spaltenkopf und Datei-/Ordnerzeilen** (`FadeMaskText` + `.clipped()`). Seitenleiste Medien: unverändert (kein Overflow-Fade).

4. **Anzeige nach dem neuen Layout 07 (05.10.), verbindlich:** Die Spalte zeigt **keine Einträge, solange der Ordner nicht vollständig geladen ist** (kein schrittweises Füllen). Stattdessen, im Stil der Detail-Spalte **ohne grauen Hintergrund**: **Spinner**, Titel **„Inhalte werden geladen“** (fett), Text **„Dieser Ordner enthält sehr viele Objekte. Die Liste erscheint erst, wenn alle geladen sind.“** (dezent) und darunter der **Ladestand „12 480 von 41 902 Objekten geladen“**. Erst wenn **alles** geladen ist, ersetzt die Liste den Hinweis. Die Gesamtzahl (`y`) kommt aus einer schnellen `COUNT(*)`-Abfrage vor dem Laden (Index `item_children`). Der Hinweis erscheint **erst nach 1 Sekunde Ladezeit** (Nutzer 06.10.: damit es nicht flackert, wenn ein Inhalt nur ein paar Millisekunden braucht). Davor bleibt die Spalte **leer und ruhig** (kein Spinner, kein Hinweis, keine alte Liste). Lädt der Ordner schneller als 1 s, erscheint **direkt die Liste** ohne jede Zwischenanzeige. Wird der Hinweis einmal gezeigt, bleibt er **mindestens 400 ms** stehen, damit er nicht aufblitzt. Test mit Uhr-Attrappe: Laden in 50 ms → nie Hinweis; Laden in 1,2 s → Hinweis ab 1,0 s bis zum Ende, Mindestdauer 400 ms. Das Laden geschieht in **Stücken zu 2.000** (Zähler aktualisiert höchstens alle 100 ms). Die Spaltenüberschrift „Inhalte werden geladen“ neben dem Ordnernamen entfällt. **Ziel:** Ordner mit 14.300 Einträgen **< 0,5 s**, 100.000 Einträge **< 2,5 s**, 200.000 **< 5 s** bis zur vollständigen Liste (der Ladestand läuft sichtbar mit). Texte in `LayoutCopy` (Layout-Test).
5. **Spalten-Zeilen** `LazyVStack` bleibt; Auswahl, Hover und Pfad-Markierung dürfen **nicht je Zeile** über alle 14.300 Einträge laufen (Hash/Set statt Array-Suche); prüfen, dass das Scrollen mit 14.300 Zeilen flüssig bleibt (Instruments „Time Profiler“-Messung als Zahl im Status).
6. **Abnahmewerte (Test mit 30.000 Zeilen, Datei-Datenbank):** Seite 500 Zeilen **< 30 ms** (reine Abfrage), erste Anzeige **< 150 ms**, alle 14.300 Zeilen vollständig **< 1,5 s**, Hauptfaden blockiert nie länger als 50 ms.

**Skalierung (Entscheidung nach Messung):** Nach 1 bis 4 messen Cursor **Anzeige mit 200.000 Zeilen** (Zeit bis zur ersten Zeile, Scrollen, Hauptfaden, Speicher). **Erreicht `LazyVStack`/`ForEach` die Zielwerte nicht** (Ladezeit bis zur vollständigen Liste wie unter 3, Scrollen ohne Ruckeln, Hauptfaden-Blockade < 50 ms, Zusatzspeicher < 400 MB), wird die Zeilenliste durch eine **`NSTableView`** (`NSViewRepresentable`) ersetzt: **Datenquelle liest Fenster aus der Datenbank** (nur sichtbare Zeilen plus Puffer, keyset-Fenster), **keine** vollständige Array-Kopie im Speicher, Auswahl und Pfad-Markierung als `Set` von Kennungen. Entscheidung (SwiftUI bleibt oder AppKit) **mit Zahlen im Status** begründen.

**Debug-Demo „Beispiel 3 — Inhalte werden geladen“:** Ladehinweis bleibt **dauerhaft** (kein Wechsel zur Liste); bei **jedem erneuten Öffnen** des Ordners wird der Ladezustand **neu angestoßen** (Cache-Invalidierung für diesen Pfad greift nicht).

**`ColumnBrowserView.folderColumn` rechnet je Aufbau mehrfach über alle Zeilen** (`filteredItems(column)` für Kopf, Liste, Auswahl-Bereinigung; `Set(items.map(\.id))` bei 14.300 Zeilen; je Zeile `FileKind(fileName:)`, `ObjectContextTarget.fromIndexedItem`, Farbe/Deckkraft): **einmal pro Aufbau** berechnen (nicht im Aufbau jeder Zeile), `isRowSelected` über `Set`, Zeilenwerte (`FileKind`, Symbol) in `IndexedItem` beim Laden vorhalten. Messung mit Instruments (Time Profiler) im Status.

---

### 109. Fehlerbehandlung und Ansichtsseiteneffekte (alt: 90 B4, B5, B10, B11, 89 E a)

**Status (Cursor 06.10. ~22:01):** Stille `try? store`: DirectoryIndexer 35/38/123 abort|abort|weitermachen; IndexingService 59/169/204 weitermachen|weitermachen|abbrechen; ChangeWatcher 159 weitermachen; ChangeWatcherEngine 44/47/78 weitermachen; AppDelegate 292 weitermachen. Test `FolderLoadErrorLoggingTests`.
Debug+Release OK ~22:01; seriell **273**/55 ~21:59:46; parallel OK ~22:00:51 (`-only-testing:diskindexTests`).
**Bereit zur Prüfung.**

1. **`IndexRepository.children(…)` löst Seiteneffekte im View-Body aus** (`loading.insert`, `Task { … }` aus `body`); SwiftUI meldet „Modifying state during view update“ in der Konsole und es kann zu doppeltem Laden kommen. **Fix:** Laden aus `.task(id:)`/`onAppear` der Spalte anstoßen, `children(…)` nur lesen.

2. **Fehler werden verschluckt:** `IndexRepository.load` (`try? await store.children`), `folderID`, `AppState` mehrere `try?`: ein DB-Fehler zeigt eine **leere Spalte** statt einer Meldung. **Fix:** Fehler protokollieren (`store error`), Spalte zeigt „Inhalt konnte nicht gelesen werden“ (Text ins Layout, bis dahin Vorschlag in `LayoutCopy`).

3. **Mehrfach-`Task`-Muster ohne Abbruch:** `AppState.schedulePopoverSearch`, `scheduleMediumWrite`, `Task { … }` in `forgetMedium`/`forgetAllMedia`/`toggleFavorite` ohne Fehlerbehandlung (`try?`/leer): prüfen, dass jeder Fehler protokolliert wird.

4. **`MediumCoordinator`**: drei veraltete `// TODO Aufgabe 41` (Zeilen 141, 168, 336). Entfernen oder in echte Aufgaben umwandeln.

5. **CancellationError:** `index error favorites CancellationError()` steht im Protokoll noch (20:31), obwohl Aufgabe 83/4 das beheben sollte: **alle** `catch`-Pfade (`favorites`, `reloadMedium`, `reread`, `ereignisstand`, `applyDirectories`) prüfen, `CancellationError` nie als `.error` protokollieren und nie `onTrackedError` auslösen.

---

### 110. Toter Code und leere Funktionen entfernen (alt: 90 C)

**Status (Cursor 06.10. ~22:50):** Tot-Symbole entfernt inkl. `ConfirmGate.isArmed` (nur Deklaration). Testhilfen: `ScriptedChangeSource` → Tests; IndexStore/DiskIndexLog-Hooks + `installSchemaForTesting`/`resetStartupFlagsForTests` hinter `#if DEBUG`. `DebugTools/`; `UITestsLaunchTests` weg; `default.profraw` in `.gitignore`. Release-`nm`: keine DebugTools/Testhilfe-Symbole. Debug+Release OK; seriell **276**/56 ~22:47; parallel OK ~22:48 (`-only-testing:diskindexTests`).
**Bereit zur Prüfung.**

**Zusätzlich:** `diskindexUITests/diskindexUITestsLaunchTests.swift` (Xcode-Vorlage, wackelt mit „has not loaded accessibility“, bis 2 Minuten) **löschen**.

**Toter Code und leere Funktionen (Nachweis: Name kommt im gesamten Projekt nur an der Deklaration vor):**
- **Leere/Rumpf-Funktionen entfernen:** `AppState.refreshVisibleCounts()` und `refreshVisibleCounts(for:)` (leer, werden aufgerufen), `AppActivationPolicy.hideDockIconIfMainWindowClosed()` (leer, Aufruf in `AppWindowPresenter`), `MediumCoordinator` leerer Hilfsrumpf bei Zeile 336.
- **Unbenutzt:** `DiskIndexLog.copyDiagnosticReport`, `crashReport`, `crashSignature`; `CrashReportText.isAbnormalEnd`; `IssueTracker.errorSignature`; `IndexRepository.cachedItem`; `ColumnFolderOpenState.isUncaptured`; `IndexStore.unchangedRow`; `AppWindowPresenter.isMainWindowPresented`; `DestructiveBorderButtonStyle` (`MediumDetailModalView`); Farben `neutral400`, `neutral600`, `neutral900`, `windowContent` (`DesignTokens`); `LayoutCopy`: `appearanceAuto/Dark/Light`, `columnName/Status/Type`, `connectedHeading`, `tabAdvanced/Files/General/Media` (die Views benutzen andere Quellen: **eine** Quelle wählen, die doppelte löschen); `ConfirmGate.isArmed`/`reset` nur durch Tests benutzt prüfen.
- **Nur Tests benutzen Produktionscode:** `ScriptedChangeSource` (in `ChangeWatcher.swift`), `holdLockForTest`, `releaseLockForTest`, `installSchemaForTesting`, `resetStartupFlagsForTests`, `IndexStore.schemaSnapshot`, `databaseFileBytes`, `fullTextByteLength`, `orphanCount`, `setDirectoryWritesFailing`, `storedNames`: nach `diskindexTests/` verschieben (Testhilfen, `@testable import`) oder `#if DEBUG`.
- **Mehrere Namen (Prüfung nötig):** Es gibt `PreviewData`/`ScreenshotRunner`/`ScreenshotPlan` (nur Debug), `Diagnostics/*` (nur Debug, 1.486 Zeilen): Debug-Werkzeuge **in eigenen Ordner `DebugTools/`** auslagern, Release-Ziel bleibt ohne.
- **Dateien im Projektordner:** `default.profraw` (750 KB, Wurzel), `.cursor/` (leer), `Scripts/GenerateAppIcons.swift` und `Werkzeuge/…` prüfen: `default.profraw` löschen und in `.gitignore`.

---

### 111. Struktur und Qualität: Dateien teilen, Texte, Zugriffsrechte (alt: 90 D)

**Status (Cursor 07.10. ~00:55):** 0: icon-pruefen ImageIO/`CGContext` (3× seriell **276**/56). 1: RestModels → GlobalPause/SystemNotice/IndexRunGuard/DatabaseCare/MenuBarDropdownLogic + DebugTools/ScreenshotPlan. 2: IndexStore → +Queries/+Search/IndexSQL. 3: AppState → +Favorites/+Media/+IndexChanges/+Pause; ColumnCacheTests grün. 4: ColumnStateSimulation → DebugTools/#if DEBUG; SurfaceTests/IndexingTests geteilt. Debug+Release OK; seriell **276**/56 ~00:54; parallel OK ~00:55 (`-only-testing:diskindexTests`).
**Bereit zur Prüfung.**

**Struktur und Qualität:**
1. **`Storage/IndexStore.swift` (1.364 Zeilen)** trennen: `IndexStore` (Actor, öffentliche API), `IndexSQL` (SQL, `DirectoryWriter`), Medium-Abfragen, Suche. **`AppState.swift` (836 Zeilen)**: Pause, Index-Änderungen/Live-Sync, Favoriten, Medien-Liste in eigene Typen (`PauseController`, `IndexChangeCoordinator`, …). **`App/RestModels.swift` (267 Zeilen, Sammelname „Rest“)**: nach Themen aufteilen (`GlobalPause.swift`, `SystemNotice.swift`, `IndexRunGuard.swift`, `DatabaseCare.swift`, `ScreenshotPlan.swift` → `DebugTools`), Datei löschen.
2. **Übersetzungen/Text:** alle Nutzertexte in `LayoutCopy` (Prüfung: Suche nach `Text("` mit deutschem Literal außerhalb von `LayoutCopy`/`EmptyStateCopy`; Liste im Status).
3. **Zugriff:** `private`/`fileprivate` wo möglich; `MainActor.assumeIsolated`-Blöcke (19 Stellen) prüfen, ob `@MainActor`-Closures reichen.
4. **Tests:** `diskindexTests/` hat teils Sammelnamen (`RestCoverageTests`, `SurfaceTests` 829 Zeilen, `IndexingTests` 733): nach Themen teilen.

Debug- und Release-Build ohne Warnung, alle Tests grün (Zahl und Uhrzeit nennen), Status je Punkt.

---

### 112. Abgleich mit dem Layout, Stand 05.10. (Claude hat das Layout neu gelesen)

**Status (Cursor 06.10. ~22:50):** Pkt 3 unverändert (Nutzer). Pkt 4 ProposalCopy: Zählen-Chip/Popover, Suche/Favoriten-Leer, Filter-Hilfen, `folderUnreadable`/`folderExcluded`, `noticesSystemAndPauses`, Bestätigungs-Mitteilungen (`noticeForgetAll`/`noticePrune`/`noticeDefaultsApplied`). Pkt 5: Audit-Strings in LayoutCopy/xcstrings + Test `columnAndFilterAuditStringsFromLayoutAreInLayoutCopy`. Debug+Release OK; **276**/56 seriell.
**Bereit zur Prüfung.**

Das Layout (`layout/Disk Index App.dc.html`, Sektionen 00 bis 15) wurde am 03.10. geändert. Claude hat alle Beschreibungstexte gelesen und mit README und Aufgaben verglichen. **Übereinstimmend:** Pausentimer (03), Chip-Regeln und „Abgleich = Chip bleibt Online“ (04), Index-Anpassung nach 1 Stunde und „Index jetzt bereinigen“ (05), Bestätigungsmodus mit grünem „Bestätigt“ (05, 15), „Inhalte werden geladen“ und „Wird indiziert“ **ohne Prozent** (07), Filter global (08, 09), Fehlerbericht mit zwei Knöpfen (13), Indizierungsfehler mit höchstens drei Wiederholungen (14).

**Abweichungen, die Cursor prüft und behebt:**
1. **Erscheinungsbild-Animation (05):** Layout: Abstand **3 px** direkt unter den Buttons (Buttons unten ohne Radius, Animation oben ohne Radius, gleicher Rahmen). Cursor-Stand (Dokumentation Punkt 6): **2 px**. Auf 3 px setzen, Bildschirmfoto `05-allgemein` (Hell/Dunkel).
2. **Indizierungsfehler (14):** Layout: „Parallel erscheint eine macOS-Mitteilung (Systemmeldungen); ein Klick darauf öffnet das Hauptfenster **mit diesem Dialog**.“ Prüfen, ob das gebaut ist (Mitteilung beim Fehler, Klick öffnet Fenster und Dialog); sonst bauen. Test mit Attrappe `UNUserNotificationCenter`.
3. **Menüleisten-Symbol (01):** Layout kennt nur grünen Spinner (Wird indiziert), pulsierenden Punkt (Neu erkannt), X (Pausiert), Ausrufezeichen (Fehler). Der **blaue Spinner (Abgleich/Live-Sync)** steht **nur in der README** (Nutzer-Wunsch 04.10.), nicht im Layout: **Nutzer ergänzt 01**; bis dahin gilt die README.
4. **Noch nicht im Layout (Nutzer ergänzt am Ende):** Chip „Zählt …“ und Popover-Zeile „Dateien werden gezählt: …“ (105), Texte der Pausen-Mitteilungen, Texte der Bestätigungs-Mitteilungen (Vergessen, Index bereinigt, Voreinstellungen), Satz „…zu Pausen“ in Erweitert (Layout sagt noch „zu abgelaufenen Pausen“), „Inhalt konnte nicht gelesen werden“ (109), Bestätigungsmodus für „Voreinstellungen anwenden“ (grau umrandet). Bis das Layout nachgezogen ist, stehen sie in `LayoutCopy` mit Kommentar `// Vorschlag, Layout folgt`.
5. **Nach dem Layout-Update des Nutzers:** `LayoutCopyTests` neu laufen lassen (der Test liest das Layout-HTML) und jede Abweichung als Fehler behandeln.
5. **Ergebnis des Text-Audits aus Aufgabe 118 (Claude, 05.10.):** **Im Layout vorhanden, aber nicht in `LayoutCopy`** (ins `LayoutCopy` übernehmen und im Layout-Test absichern): „ALLE SPEICHERMEDIEN“, „Offline — Inhalt aus dem Index, zum Öffnen bitte anschließen“, „DETAIL“, „Größe gesamt:“, „Geändert:“, „Größe:“, „Zuletzt gesehen:“ (`ColumnBrowserView`), „Filter“ (`MainWindowFilterBar`). **Nicht im Layout** (Nutzer ergänzt oder streicht): „Suche läuft…“ (`SearchView`), Leerzustand-Sätze (`SearchView`, Favoriten), „Keine Treffer für …“ (`MenuBarPopoverSearchContent`). Bis dahin in `LayoutCopy` mit Kommentar „Vorschlag, Layout folgt“.

Debug- und Release-Build ohne Warnung, alle Tests grün (Zahl nennen), Status.

---

### 113. Button-Regeln anwenden: gleiche Größe, Breite nach Inhalt (neu, Nutzer 05.10.)

**Status (Cursor 06.10. ~22:50):** Höhen: 06-detail Confirm/Secondary/Primary = 35 (standard); 05 ConfirmButton×3 + „Hinzufügen“ Secondary 35; 02 Primary/Secondary 35; 13/14 `.dialog` 35 (Stretch nur 14/StoreOpen); 03 `compactFooter`; 08/09/10/11/12 nur `.plain` (keine DesignButton-Gruppe). Test `viewGroupsUseUniformButtonSizes`. PNGs neu `Werkzeuge/screenshots/2026-10-06-r4/` (122, ~22:49–22:50). Debug+Release OK; **276**/56 seriell ~22:47; parallel OK ~22:48.
**Bereit zur Prüfung.**

---

## B. Backlog (nicht freigegeben, Cursor arbeitet nicht daran)

- **T1. Ladehinweis erst nach 1 s** (Nutzer 06.10.): gehört zu 107; Suche/Favoriten später.
- **T2. Programme als Dateityp „Programme“** (`.app`-Pakete, dmg, pkg).
- **T3. Erweiterte Dateityp-Icons** (Styleguide Sektion 15).
- Cursor hat T1–T3 vorzeitig gebaut; Claude entscheidet bei der Prüfung, was bleibt.
- **T5 (Vorschlag Claude, wartet auf Nutzer): Ausführliches Protokoll („Diagnose-Modus“).** Es gibt schon `~/Library/Logs/Disk Index/diskindex.log` (Kategorien, `crash-last.txt`, „previous run ended without clean exit“). Lücken: (1) **Beenden wird nicht protokolliert** (`applicationShouldTerminate` schreibt nichts; nur `applicationWillTerminate` „app terminate ok“) → Zeilen „quit requested (Quelle)“, „quit: status item entfernt“, „quit: Indizierung gestoppt“ mit Dauer. (2) **Haupt-Thread-Wächter:** blockiert der Hauptfaden > 2 s, Zeile `hang main ms=…` mit Stack (Release tauglich). (3) **Schalter** „Ausführlich“ (Erweitert, nur Debug oder per `defaults`) für Pegel `debug`: je Medium Dauer von Lesen/Schreiben, Cache-Treffer, Ladezeiten Spalten, Speicher. (4) `crash-last.txt` auch bei Beenden durch Signal. Nicht freigegeben.
