# SUBTASK2 — Oberfläche (Agent 2)

Kennungen: `bug.0.4.034` bis `bug.0.4.040` (Paket 6). Freigegeben vom Nutzer am 16.10.; unabhängig von Paket 4 (Agent 1 arbeitet parallel an Medien-I/O, Protokoll, Absturzschreiber).

**Dateien (nur diese Bereiche):** Views der Spaltenansicht, Suche, Favoriten und Popover (`ColumnFolderTableView`, `ObjectResultsTable`, Suchansichten), `IndexRepository`, `ColumnSelection`, `IgnoreBatch`/`ContextMenuPlan`, in `AppState*.swift` nur Favoriten-/Online-/Popover-Such-Teile (`toggleFavorite(s)`, Favoriten-ID-Menge, `isOnline`-Ableitung, Popover-Suche), in `Storage/V3/IndexStoreV3.swift` **nur** `search` (und Hilfsfunktionen für Medien-IDs/Gruppen); die zugehörigen Tests. **Nicht:** `ChangeWatcher*`, `PartialChecksum`, `MediumAccess`, `IssueReporter`, Protokoll/Absturzschreiber, `AppDelegate`, `wireStore` (gehören Agent 1).

**Hinweise:** `bug.0.4.035`: Der Teil „Dateinamen ignorieren mit sehr vielen Zielen“ wartet auf die Entscheidung `todo.0.4.031` (neuer Text nötig) — nur die Laufzeit-Teile umsetzen. Neue sichtbare Texte nur über „Frage:“ (TODO.md, Entscheidungen). Echtes Fenster außerhalb des Bildschirms (Regeln 10, 19, 21): keine echte Maus/Tastatur, keine Screenshots.

## Aufgaben (Wortlaut aus TODO.md)

**bug.0.4.034 — Spaltenansicht: Zustand „wird indiziert“ richtig (REPORT 81, 126).**
- a) `rowOpacity` übergibt `folderName`, `folderListedAt` und `folderUnreadable` wie `iconColor`. Den Zustand **einmal je Zeile** berechnen und für Farbe und Deckkraft verwenden.
- b) `ColumnFolderOpenState.resolve`: `folderDepth >= maxDepth` → `.uncaptured(.scanDepth)` (der Indexer öffnet Ordner auf Tiefe = Scan-Tiefe nicht). Den Test `ProtocolAndSelectionTests` Z. ~290 auf `columnIndex: 1` bei Tiefe 2 umstellen.
- **Akzeptanz (echtes Fenster außerhalb des Bildschirms, Regel 10/19):**
  - Indizierter Ordner → Deckkraft 1.
  - Ordner mit `listedAt == nil` bei laufender Indizierung → 0,55.
  - Bei Scan-Tiefe 2 sind Ordner der Ebene 2 gelb mit „Inhalt wird nicht indiziert“, nicht grün.
Status:

**bug.0.4.035 — ⌘A in großen Ordnern ohne quadratischen Aufwand (REPORT 65).**
- `ColumnSelection` führt zusätzlich ein `Set<UUID>` für `contains`.
- In `folderColumn`, `commit`, `multipleSelectionItems` und `contextTargets` einmal ein Dictionary `id → item` bzw. ein Set je Body/Aufruf.
- `IgnoreBatch`/`ContextMenuPlan` über Sets.
- Für „Dateinamen ignorieren“ mit sehr vielen Zielen: Entscheidung `todo.0.4.031` abwarten (Obergrenze oder Warnung braucht einen Text); bis dahin nur die Laufzeit-Teile umsetzen.
- **Akzeptanz:** 50.000 künstliche Items, `selectAll`, `commit` und `selectedIDs` jeweils < 50 ms (Messung im Status).
Status:

**bug.0.4.036 — Spalten-Cache verdrängt keine sichtbaren Spalten (REPORT 125, 98).**
- `IndexRepository.children()` setzt den Schlüssel bei jedem Lesen ans Ende von `cacheOrder`. Schlüssel der sichtbaren Spalten (`pathStack`) werden nie verdrängt.
- `pruneSelectionToVisibleItems` läuft nur, wenn der Ordner tatsächlich geladen ist (nicht bei fehlendem Cache oder `isLoading`).
- 98: `replaceStore` erhöht die Generationen (wie `invalidateAll`) statt sie zu löschen. Das `defer` des Loads räumt `loading`/`loadingTotals` nur bei passendem Token ab.
- **Akzeptanz:**
  - Wurzel offen, Ordner gewählt, danach 35 andere Ordner laden → Wurzel bleibt im Cache, Auswahl und `pathStack` bleiben.
  - `invalidateAll` während Auswahl → Auswahl bleibt.
Status:

**bug.0.4.037 — Favorit und Online-Status in Listen aktuell (REPORT 80, 82, 103).**
- `AppState` führt eine Menge der Favoriten-IDs als Quelle für `isFavorite(_:)` bei Dateien. `toggleFavorite`/`toggleFavorites` patchen `favoriteObjects` und `searchMatch.items` lokal.
- `isOnline` in Suche, Favoriten und `ObjectContextTarget` beim Rendern und Filtern aus einem Dictionary `mediumID → connected` ableiten (einmal je Body), nicht speichern.
- 103: `ColumnFolderTableView.updateNSView` lädt sichtbare Zeilen neu, wenn `coordinator.items != items`.
- **Akzeptanz:**
  - In Favoriten einen Favoriten abwählen → Zeile verschwindet sofort; zweiter Klick setzt ihn wieder.
  - Medium per `updateMedium` offline → Filter „Offline“ enthält dessen Favoriten.
  - Tabelle ab 50k: Favorit umschalten → Zeile zeigt neuen Zustand.
Status:

**bug.0.4.038 — Suche: Sortierung und Gruppen nicht nur über die erste Seite (REPORT 83, 130, 131).**
- `store.search` bekommt Sortierspalte und -richtung für **Name, Datum, Medium** (SQL `ORDER BY`, `items_modified` existiert). Bei Klick wird neu abgefragt.
- Für **Pfad** und **Status**: Client-Sortierung nur bei `itemCount <= pageLimit`, sonst diesen Spaltenkopf deaktivieren (kein neuer Text).
- 130: Das Popover holt Ordner und Dateien je mit eigener kleiner Abfrage (`LIMIT 3`).
- 131: Medien-IDs für die Kacheln per `SELECT DISTINCT storageID` mit denselben Filtern.
- **Akzeptanz:**
  - 600 Treffer, neuester heißt „zzz“ → Datum absteigend zeigt ihn zuerst; Name absteigend zeigt den alphabetisch letzten.
  - „rechnung“ mit 600 Dateien `Rechnung_…` und Ordner „Rechnungen“ → Gruppe „ORDNER“ vorhanden.
Status:

**bug.0.4.039 — Popover-Suche entprellen und abbrechen (REPORT 85).**
- Den Task in `AppState` halten und bei neuer Eingabe `cancel()`. 150 ms Entprellung.
- Die Seite mit `withCount: false` holen, die Zahl getrennt und abbrechbar nachreichen.
- **Akzeptanz:** 5 Eingaben schnell hintereinander → höchstens eine Zählabfrage (Zähler im Test).
Status:

**bug.0.4.040 — Favoriten-Tabelle lazy und seitenweise (REPORT 86).**
- `ObjectResultsTable` mit `LazyVStack`.
- Favoriten seitenweise wie die Suche (500 + Zählung).
- Mediennamen und Verbindungsstatus einmal als Dictionary übergeben, nicht je Zeile `appState.medium(with:)`.
- **Akzeptanz:** 10.000 Favoriten → erste Darstellung < 300 ms; Fortschritts-Tick baut nicht alle Zeilen neu (Zähler im Test).
Status:

## Spielregeln

**Dieser Plan ist in sich vollständig.** Du arbeitest alles darin direkt ab, ohne Rückfrage an Claude, in der Reihenfolge der Abschnitte. TODO.md bleibt der Takt und das Register; du änderst sie **nicht**. Claude führt deine Ergebnisse nach der Fertigmeldung in TODO.md zusammen und nimmt ab.

## Spielregeln (zusätzlich zu TODO.md Regeln 1–30, die du vorher liest)
- **Zwei Agenten arbeiten gleichzeitig**, jeder in einer **eigenen Kopie** des Projekts (eigenes Gerät, eigener Klon oder Ordner). Regel 26 gilt so: Fremde Änderungen an Dateien **außerhalb der Dateiliste unten** sind erwartet und kein Grund anzuhalten. Fasse Dateien außerhalb deiner Liste nicht an; brauchst du eine, schreibe „Frage:“ unter die Aufgabe und mach mit der nächsten weiter.
- **Status nur hier**, im Feld „Status:“ jeder Aufgabe (höchstens 5 Zeilen, Kennung, Belege mit Uhrzeit, „Bereit zur Prüfung“). Nicht in TODO.md, nicht in PROMPT.md.
- **Regel 23 entfällt** in diesem Plan; Claude baut die App nach dem Zusammenführen. Alles andere (Regeln 20, 22, 25, Parallellauf-Kommando) gilt.
- **Eigener Build-Ordner:** immer `-derivedDataPath <eigener Ordner>` (nicht den Standard-Ordner, nicht den des anderen Agenten), danach löschen. Xcode muss das Projekt nicht offen haben; ist die Entwicklerumgebung nicht gesetzt: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- **Befehle:** Build `xcodebuild clean build-for-testing -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath <Ordner>`; Warnungen `| grep "warning:" | grep -v appintents | sort -u | wc -l` (Ziel 0); seriell `xcodebuild test-without-building … -only-testing:diskindexTests -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`; parallel derselbe Befehl mit `-parallel-testing-enabled YES`; Release `xcodebuild build … -configuration Release -derivedDataPath <anderer Ordner>`.
- **Testrhythmus:** je Aufgabe nur die betroffenen Suites (`-only-testing:diskindexTests/<Suite>`), danach am **Ende des Plans** einmal Debug+Testziel 0 Warnungen, Release 0 Warnungen, seriell Gesamtlauf, **zwei** Parallelläufe. Keine neuen `Disk Archive*.ips` in ~/Library/Logs/DiagnosticReports (Zeitpunkt vorher merken).
- **Testaufbau-Standard (neu):** keine statischen/prozessweiten Variablen für Test-Verzögerungen oder Schalter (der Parallellauf teilt Prozesse); Verzögerung, Zeitgrenze und Fake als Parameter oder injizierten Provider. Zeitgrenzen mit Reserve (kein Test, der genau an seiner eigenen Zeitgrenze liegt). Kein `lock()` über ein `await`.
- Kein Git außer status/log/diff/show. Der Nutzer committet.

## Abschluss
Sobald alles „Bereit zur Prüfung“ ist: HALT. Antworte nach Regel 30 (Prompt für Claude im Codeblock, Kennungen, geänderte Dateien je Aufgabe, Belege mit Uhrzeiten) und nenne eine Commit-Nachricht in einem eigenen Codeblock.
