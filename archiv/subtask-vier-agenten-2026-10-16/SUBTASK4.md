# SUBTASK4 — Suche, Favoriten, Popover (Agent 4 von 4)

## Freigaben (hier eintragen)
(noch keine)

## Dir gehört (ganze Dateien)
- Quelle: `App/AppState.swift`, `AppState+Media.swift`, `AppState+IndexChanges.swift` (alle drei nur in Schritt 0, dann FREI), `App/AppState+Favorites.swift`, `App/AppStateBindings.swift`; alles unter `Views/Search/`, `Views/Favorites/`, `MenuBar/`; `Models/PopoverSearch.swift`, `Models/SearchIndex.swift`; `Storage/V3/IndexStoreV3+Reading.swift`, `Storage/V3/SearchPlanV3.swift`; `DesignSystem/MediumCompactSearchField.swift`.
- Tests: `Search*Tests`, `SearchView`-/`ResultsTable*Tests`, `MenuBar*Tests`, `PopoverPercentAlignmentTests`, `ColumnAndSearchTests`, `StoreReadTests`, `V3ReadTests`, `FavoriteRepro`-/Favoriten-Tests.
- **Nicht:** alles andere. `IndexStoreV3.swift` gehört Agent 1 (dann Agent 3); `search` liegt in `IndexStoreV3+Reading.swift` und ist deins.

## Aufgaben (Wortlaut aus TODO.md)

**Schritt 0 (zuerst):** Lege alle für `037`, `039`, `040` nötigen neuen Eigenschaften und Methoden in `App/AppState.swift`, `App/AppState+Media.swift` und `App/AppState+IndexChanges.swift` an (kompilierend, auch als einfache Stümpfe), trage dann `FREI: AppState.swift, AppState+Media.swift, AppState+IndexChanges.swift <Uhrzeit>` oben unter „Freigaben“ ein und fasse diese drei Dateien nie wieder an. Agent 3 wartet darauf. Danach arbeite `037`, `038`, `039`, `040` in dieser Reihenfolge in deinen übrigen Dateien ab.

**Abgrenzung:** In `bug.0.4.037` gehört der Punkt 103 (`ColumnFolderTableView.updateNSView`) Agent 1; lass ihn weg.

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

## Arbeitsweise (vier Agenten, ein Gerät, ein Arbeitsordner)
**Dieser Plan ist in sich vollständig.** Du arbeitest alles darin direkt ab, ohne Rückfrage an Claude, in der Reihenfolge der Abschnitte. TODO.md bleibt der Takt und das Register; du änderst sie **nicht**. Claude führt deine Ergebnisse nach der Fertigmeldung in TODO.md zusammen und nimmt ab. Lies vorher TODO.md Regeln 1–30.

**Vier Agenten arbeiten gleichzeitig in denselben Ordner** (SUBTASK1 bis SUBTASK4). Damit nichts kollidiert, gilt:
1. **Eigentum an ganzen Dateien.** Nur Dateien aus deiner Liste „Dir gehört“ darfst du ändern. Jede Quelldatei gehört genau einem Agenten (oder ist unten als Torwächter-Datei mit fester Reihenfolge geregelt). Brauchst du eine fremde Datei: „Frage:“ unter die Aufgabe, nächste Aufgabe weiter. Keine „Mini-Änderung nebenbei“.
2. **Torwächter-Dateien** (zwei Agenten brauchen sie, nacheinander, nie gleichzeitig): Der **erste** Besitzer erledigt **alle** seine Änderungen an der Datei in „Schritt 0“ seines Plans (kompilierend), schreibt dann in seinem Plan oben unter „Freigaben“ die Zeile `FREI: <Datei> <Uhrzeit>` und fasst die Datei danach **nie wieder** an. Der **zweite** Besitzer öffnet die Datei erst, wenn er die FREI-Zeile im Plan des ersten gelesen hat; bis dahin arbeitet er an anderen Aufgaben. Tabelle:
   | Datei | zuerst | danach |
   |---|---|---|
   | `Storage/V3/IndexStoreV3.swift`, `Indexing/ChangeWatcher.swift`, `Indexing/ChangeWatcherEngine.swift` | Agent 1 | Agent 3 |
   | `App/AppDelegate.swift` | Agent 2 | Agent 3 |
   | `App/AppState.swift`, `App/AppState+Media.swift`, `App/AppState+IndexChanges.swift` | Agent 4 | Agent 3 |
3. **Tests:** Eigene neue Tests als **neue Dateien** `<Thema>Agent<N>Tests.swift` anlegen (die Projektgruppe nimmt neue Dateien selbst auf; `project.pbxproj` nicht anfassen). Die Regressions-Zeile (Regel 11) kommt in eine neue Datei `RegressionSmokeAgent<N>Tests.swift`; `RegressionSmokeTests.swift`, `SurfaceTestSupport.swift`, `IndexStoreV3TestHooks.swift`, `IndexingTestSupport.swift`, `V3TestSupport.swift` gehören Agent 1 (andere bauen eigene Hilfen in ihre neue Testdatei). Eine **bestehende** Testdatei änderst du nur, wenn sie zu deiner Dateiliste gehört oder ihr Thema allein deine Aufgabe ist und keine andere Liste sie nennt; sonst neue Datei oder „Frage:“.
4. **Kompilierbar bleiben:** Ändere in kleinen Schritten, die jeweils bauen. Eine halbfertige Änderung bricht den Build für alle drei anderen.
5. **Fremde Build-/Testfehler:** Fehler in einer Datei **außerhalb deiner Liste** sind meist halbfertige Arbeit eines anderen Agenten. Nicht beheben, nicht zurückrollen. 3 Minuten warten, neu bauen; besteht er nach 10 Minuten noch, „Frage:“ und an der nächsten Aufgabe weiterarbeiten.
6. **Regel 26 gilt so:** Geänderte `.swift`-Dateien der anderen Agenten sind erwartet; du hältst nur an, wenn jemand **deine** Dateien ändert. `git checkout/stash/reset/restore` bleiben verboten (Regel 22): sie vernichten fremde Arbeit.

**Build und Test**
- Bauen in eigenem Ordner: `xcodebuild build-for-testing -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/diskindex-dd-agent<N>` (ohne `clean`, außer beim ersten Mal; bei verdächtigem Zustand `clean`). Ist die Entwicklerumgebung nicht gesetzt: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Warnungen zählen: `| grep "warning:" | grep -v appintents | sort -u`; **in deinen eigenen Dateien muss es 0 sein** (Warnungen in Fremddateien nur melden).
- **Testläufe nur unter der Sperre** und nur deine Suites (`-only-testing:diskindexTests/<Suite>`, seriell, `-test-timeouts-enabled YES -maximum-test-execution-time-allowance 120`):
  `until mkdir /private/tmp/diskindex-test.lock 2>/dev/null; do find /private/tmp/diskindex-test.lock -maxdepth 0 -mmin +30 -exec rmdir {} \; 2>/dev/null; sleep 20; done; <xcodebuild test-without-building …>; rmdir /private/tmp/diskindex-test.lock`
  Die Sperre immer freigeben, auch bei Fehlschlag.
- **Gesamtlauf seriell, Parallelläufe und Release-Build macht Claude** nach dem Zusammenführen (vier Agenten würden sich sonst 45 Minuten an der Sperre stauen). Du lieferst: Build ohne Warnung in deinen Dateien, alle deine Suites grün (Name, Zahl, Uhrzeit), Sabotage rot ✓ wo gefordert (Regel 25), keine neuen `Disk Archive*.ips` (Zeitpunkt vorher merken).
- **Testaufbau-Standard:** keine statischen/prozessweiten Variablen für Test-Verzögerungen oder Schalter (parallele Läufe teilen Prozesse), sondern Parameter oder injizierte Provider. Zeitgrenzen mit Reserve. Kein `lock()` über ein `await`. Regel 20 (Tests stürzen nie ab) gilt.
- **Regel 23 entfällt**; Claude baut die App. **Status nur in deinem Plan** im Feld „Status:“ (höchstens 5 Zeilen, Kennung, Belege, „Bereit zur Prüfung“). Kein Git außer status/log/diff/show; der Nutzer committet.

## Abschluss
Sobald alles „Bereit zur Prüfung“ ist: HALT. Antworte nach Regel 30 (Prompt für Claude im Codeblock, Kennungen, geänderte Dateien je Aufgabe, Belege mit Uhrzeiten) und nenne eine Commit-Nachricht in einem eigenen Codeblock.
