# Code-Befunde (technische Fehler)

Stand: 12.10.2026, geprüft gegen Commit `be80c9c` („Updates“, Schema V3 / `IndexStoreV3`, Datei `archive.sqlite`). Nur am Quellcode bestätigte Defekte. Keine Konzept-/Layout-Abweichungen, keine Stilvorschläge.

## Behoben in `be80c9c`

### 1. Bereinigen: Hard-Delete über Pfad ohne Medium — **behoben**

- **Früher:** Pfadbasiertes `DELETE` ohne `mediumID` in `IndexStore.pruneToMatch` konnte Bäume auf anderen Medien mit gleichem relativen Pfad löschen.
- **Jetzt:** V3 speichert Pfade nur noch als Elternkette; Bereinigung löscht über `DELETE FROM items WHERE id IN (…)` (`deleteItems`) nach gezielter Auswahl (Tiefe, Namensfilter). Kein globales Pfad-Präfix-DELETE mehr.
- **Referenz:** `diskindex/diskindex/Storage/V3/IndexStoreV3.swift`, `pruneToMatch` / `deleteItems` (ca. Z. 530–619).

---

## Übersicht (offen)

| Nr | Schwere | Kurz |
|----|---------|------|
| 2 | Kritisch | Nach Integritätsfehler laufen Dienste weiter, DB-Handle unbrauchbar |
| 3 | Hoch | Change-Loop bleibt am ersten Store nach Retry |
| 4 | Hoch | `wireStore` stoppt vorherigen Indexer/Watcher nicht |
| 5 | Hoch | Parallele Startup-Tasks ohne Abbruch |
| 6 | Hoch | FSEvents-Watcher während Erstlauf/Abgleich |
| 7 | Hoch | „Indizieren“ Ja/Nein ohne Stop/Start/Watcher |
| 8 | Hoch | FSEvents-Setup scheitert → Watcher-Task hängt |
| 9 | Hoch | Stream-Unmount beendet Watcher ohne Neustart |
| 10 | Hoch | Live-Reread: DB-Fehler, Cursor trotzdem gespeichert |
| 11 | Hoch | Suche: `LIMIT` vor Scope-Filter |
| 12 | Hoch | Spalten-Pagination endet bei leer gefilterter Seite |
| 13 | Hoch | `finish` räumt Task/Spinner vor Token-Prüfung auf |
| 14 | Hoch | Suche: `isSearchInProgress` bleibt bei Abbruch |
| 15 | Mittel | `cancel` bricht detached Index-Task nicht ab |
| 16 | Mittel | `requestedIndex`-Latch bei Pause-No-Op |
| 17 | Mittel | „Nicht indizieren“ setzt `indexStatus = .indexed` ohne Index |
| 18 | Mittel | Depth-Bereinigung: globale Metadaten-Updates (teilweise verbessert) |
| 19 | Mittel | `childCount` ignoriert `IndexScope` |
| 20 | Mittel | `searchCount` scannt alle Treffer in Swift |
| 21 | Mittel | `forgetAllMedia` bricht DB-Löschung beim ersten Fehler ab |
| 22 | Mittel | Store-Retry ohne Ladezustand in der UI |
| 23 | Mittel | Spalten-State nur teilweise beim Tab-Wechsel zurückgesetzt |
| 24 | Mittel | Mitteilungs-Delegate ohne Main-Thread-Garantie |
| 25 | Mittel | Quit-Checkpoint nicht abgewartet |
| 26 | Mittel | Hintergrund-Recount ohne Lauf-Kopplung |
| 27 | Niedrig | `autoIndexPaused` aus DB geht in `asMedium` verloren |
| 28 | Mittel | Integritätsfehler: `indexStore`/`changeLoop` nicht zurückgesetzt |

---

## Befunde

### 2. Integritätsfehler nach Verdrahtung: Teardown unvollständig

- **Wo:** `StartupSequence.swift` Z. 48–61; `AppDelegate.handleStoreFailure` Z. 277–287; `IndexStoreV3.runIntegrityCheck` Z. 79–86
- **Was:** Nach erfolgreichem `wire(store)` laufen Erkennung, Change-Loop, Indizierung und FSEvents. Schlägt danach `quick_check` fehl, wird die DB quarantänisiert und der Pool geschlossen — Indexer/Watcher/Change-Loop laufen weiter; `AppState.indexStore` zeigt weiter auf den geschlossenen Store.
- **Warum:** `wire` erfolgt vor dem Integritätscheck. `handleStoreFailure` ruft nur `mediumCoordinator?.stop()` auf, nicht `prepareForAppTermination()` (Watcher, Indexer, `appState.prepareForTermination()`). `reportIndexStoreOpenFailure` setzt `storeReady = false`, aber weder `indexStore = nil` noch Abbruch des Change-Loops.
- **Vorschlag:** Bei Integritätsfehler dieselbe Abbruchkette wie beim Beenden; `indexStore`/`storeReady`/`changeLoop` zurücksetzen. Integrität prüfen vor `wire` oder bei Fehler nach `wire` vollständig entkoppeln.

### 3. Change-Loop bleibt am ersten Store

- **Wo:** `AppState+IndexChanges.swift`, `startChangeLoop` Z. 19–28; `MediumRecognitionStartup.bootstrap` Z. 35; `AppDelegate.wireStore` Z. 315–319
- **Was:** Nach DB-Retry mit neuem `IndexStoreV3` kommen DB-Events (`emit`) nicht mehr zuverlässig in der UI an (Suche/Spalten/Favoriten-Refresh).
- **Warum:** `startChangeLoop` startet nur wenn `changeLoop == nil` und iteriert über das beim Start erfasste `indexStore`. Retry ruft erneut `startChangeLoop` auf, ohne alten Loop zu canceln/neu zu binden.
- **Vorschlag:** Vor neuem Loop alten canceln; Loop liest `indexStore` über `weak self` pro Event oder explizit nach `attach(store:)` neu starten.

### 4. Erneutes Verdrahten ohne Stoppen der alten Dienste

- **Wo:** `AppDelegate.wireStore` Z. 289–314; Vergleich `prepareForAppTermination` Z. 160–167
- **Was:** Zweites `wireStore` (Retry) ersetzt Referenzen auf `IndexingService`/`ChangeWatcher`, stoppt aber die vorherigen Instanzen nicht.
- **Warum:** Es wird nur `mediumCoordinator?.stop()` aufgerufen, nicht `changeWatcher?.stopAllForTermination()` / `indexingService?.cancelAllForTermination()`.
- **Vorschlag:** Vor Erzeugen neuer Dienste die alten wie bei `prepareForAppTermination` stoppen; Startup-Task serialisieren (siehe Nr. 5).

### 5. Überlappende Startup-Tasks

- **Wo:** `AppDelegate.startMediumRecognition` Z. 265–274; `StartupSequence.run` Z. 37–63
- **Was:** Mehrfaches Retry oder schnelles erneutes Öffnen kann zwei parallele `wire(store)`-Aufrufe auslösen.
- **Warum:** Jeder Aufruf startet ein neues `Task` ohne Handle, Abbruch oder „single flight“.
- **Vorschlag:** Laufenden Startup-Task speichern und vor neuem Start canceln; oder Mutex bis `wire` abgeschlossen.

### 6. Live-Watcher parallel zum Index-Lauf

- **Wo:** `LiveWiring.connect`, `setIndexHandler` Z. 81–84; `onReconcileRequested` Z. 85–90; `onRunIndexed` Z. 69–71; `IndexStoreV3.applyDirectories` Z. 257–295 (ohne Token-Prüfung; `indexingIsActive` Z. 460–461 ungenutzt)
- **Was:** Während Erstlauf oder Abgleich können FSEvents-Flushes und der Indexer gleichzeitig in dieselbe `items`-Tabelle schreiben. Beim Abgleich wird der Watcher nach `stop` sofort wieder gestartet, bevor der Lauf endet.
- **Warum:** Watcher startet bei Index-Anforderung (`setIndexHandler`), nicht erst zuverlässig nach erfolgreichem Lauf (`onRunIndexed` allein reicht nicht). `applyDirectories` prüft keinen `indexingToken`.
- **Vorschlag:** Watcher erst nach erfolgreichem Lauf starten oder während aktivem Token Watcher-Schreibvorgänge verweigern/queueen; bei Abgleich Watcher bis Laufende gestoppt lassen.

### 7. Einstellungen „Indizieren“ ohne Lauf-Steuerung

- **Wo:** `RegistryTableRow.swift` Z. 80–83; `MediumDetailModalView.swift` (analog); `AppState.updateMedium` + `writeMedium` (persistiert nur Entscheidung)
- **Was:** Wechsel auf „Nein“ stoppt weder Indizierung noch FSEvents; Wechsel auf „Ja“ startet keinen Lauf, solange kein anderer Pfad (Mount, Reindex) greift.
- **Warum:** Kein Hook wie `onMediaForgotten` / `LiveWiring` für Entscheidungsänderung — nur UI + debounced DB-Schreiben.
- **Vorschlag:** Bei Entscheidungsänderung `cancel` + Watcher stoppen (Nein) bzw. `start` + Watcher (Ja, wenn verbunden und nicht pausiert), analog Erkennungsdialog.

### 8. FSEvents-Stream-Setup: hängender AsyncStream

- **Wo:** `ChangeWatcher.swift`, `FSEventsChangeSource.open` Z. 353–358; `changes()` Z. 319–326
- **Was:** Live-Updates für ein Medium bleiben dauerhaft aus; `ChangeWatcher.tasks[mediumID]` blockiert in `for await`.
- **Warum:** Scheitert `FSEventStreamCreate` oder `FSEventStreamStart`, wird `close()` aufgerufen, aber `continuation.finish()` nie — der Stream liefert keine Events und endet nicht.
- **Vorschlag:** Bei Fehler `continuation.finish()` (optional mit Fehler-Event); Watcher-Task beenden und `tasks`/`sources` aufräumen.

### 9. FSEvents-Unmount: Watcher tot, Medium noch verbunden

- **Wo:** `ChangeWatcher.handleStreamUnmount` Z. 164–171; `restartWatchersAfterWake` / `LiveWiring` (nur wenn `isWatching`)
- **Was:** Nach internem Unmount-Event keine Live-Sync mehr, obwohl Coordinator das Medium noch als angeschlossen führt.
- **Warum:** Task und Source werden entfernt, `mounts`/`volumes`/`cursors` bleiben; kein `saveCursor`, kein Restart; Wake-Restart überspringt nicht-watchende Medien.
- **Vorschlag:** Vollständiges `stop(mediumID:)` oder bei verbundenem Medium Watcher neu starten; Cursor speichern.

### 10. Live-Reread: Fehler, Cursor dennoch fortgeschrieben

- **Wo:** `ChangeWatcherEngine.processPending` Z. 120–141; `ChangeWatcher.flush` Z. 231–241
- **Was:** Index weicht von der Platte ab; Nutzer sieht keinen Fehler; spätere Events gelten als verarbeitet.
- **Warum:** `applyDirectories`-Fehler werden nur geloggt; Rückgabe bleibt `.ok`; `flush` ruft immer `saveCursor` auf.
- **Vorschlag:** Bei Fehler `.needsFullReconcile` oder Fehlerzustand; Cursor nur bei Erfolg speichern.

### 11. Suche: Limit vor Namens-Scope

- **Wo:** `IndexStoreV3+Reading.swift`, `search` Z. 189–199; `topHits` Z. 291–298
- **Was:** Während ausstehender Bereinigung (`pruneAt`, `scope.checksNames`) können Suchlisten leer oder stark unter 500 Treffer sein, obwohl `searchCount` hoch ist.
- **Warum:** SQL wendet `LIMIT` an (`searchHitsSQL`), danach filtert Swift nach Ausschluss/Artefakt-Regeln.
- **Vorschlag:** Bei `checksNames` paginieren bis genug sichtbare Treffer oder Filter in SQL nachziehen (wo möglich).

### 12. Spalten: Pagination bricht bei leerer gefilterter Seite ab

- **Wo:** `IndexStoreV3+Reading.swift`, `childrenPage` Z. 99–106; `IndexRepository` lädt Seiten bis `nextCursor == nil`
- **Was:** Ordner wirkt leer oder unvollständig, obwohl sichtbare Kinder weiter hinten in der DB existieren.
- **Warum:** Liefert die DB-Seite Zeilen, filtert Swift aber alle weg, ist `filtered.count < limit` → `nextCursor = nil` (auch wenn `rows` voll war).
- **Vorschlag:** Weiterblättern in SQL, solange `nextCursor` aus letzter DB-Zeile kommt, nicht aus gefilterter Menge; oder leere Seite ≠ Ende.

### 13. Index-`finish`: UI vor Token-Validierung

- **Wo:** `IndexingService.finish` Z. 176–179
- **Was:** Menüleisten-Spinner verschwindet, obwohl ein neuerer Lauf für dasselbe Medium aktiv ist.
- **Warum:** `tasks[mediumUUID] = nil` und `clearMenuBarRunIndicators` laufen vor `guard runs[mediumUUID] == token`.
- **Vorschlag:** Zuerst Token prüfen, dann Task/Spinner nur für gültigen Lauf zurücksetzen.

### 14. Suche: Fortschrittsflag bei Task-Abbruf

- **Wo:** `AppState+IndexChanges.swift`, `runSearch` Z. 103–114
- **Was:** Nach Verlassen der Suche oder Abbruch der SwiftUI-`.task` bleibt „Suche läuft“ sichtbar.
- **Warum:** `isSearchInProgress = true` ohne `defer`/Cancellation-Handler; bei Abbruch während `await SearchIndex.matching` oder bei `generation != searchGeneration` (Z. 114) wird Z. 127 nicht erreicht.
- **Vorschlag:** `defer { … false }` mit Generation/Cancellation-Prüfung oder bei Cancellation explizit zurücksetzen.

### 15. `cancel` ohne Task-Abbruch

- **Wo:** `IndexingService.cancel` Z. 112–125; Vergleich `cancelAllForTermination` Z. 102–107
- **Was:** Nach Abziehen/Vergessen kann der Indexer noch lange I/O auf dem Medium ausführen und spät `finish` aufrufen.
- **Warum:** Es wird nur der Token entfernt und `halt` liefert `.cancel`; `tasks[mediumUUID]?.cancel()` fehlt.
- **Vorschlag:** Detached-Task canceln; danach wie bisher Token/Store/UI.

### 16. `requestedIndex`-Latch bei frühem `start`-Abbruch

- **Wo:** `MediumCoordinator.requestIndex` Z. 340–345; `IndexingService.start` Z. 48
- **Was:** Medium startet nach Pause/Entscheidung keinen Erstlauf, bis Remount.
- **Warum:** Latch wird gesetzt, bevor `start` läuft; bei `isPaused` returniert `start` ohne Lauf, Latch bleibt gesetzt.
- **Vorschlag:** Latch erst nach erfolgreichem Start setzen, oder bei No-Op `requestedIndex.remove(mediumID)`.

### 17. Erkennungsdialog „Nicht indizieren“: falscher Index-Status

- **Wo:** `MediumCoordinator.applyChoice` Z. 323–325
- **Was:** Medium ohne Index kann in DB/UI als `indexStatus == .indexed` erscheinen (Chip/Filter inkonsistent zu `hasIndex`).
- **Warum:** Bei `allowIndexing == false` wird `indexStatus` auf `.indexed` gesetzt, unabhängig vom vorhandenen Index.
- **Vorschlag:** Status unverändert lassen oder expliziten Zustand „kein Index + Nein“; nicht `.indexed` ohne Daten.

### 18. Depth-Bereinigung: globale Metadaten-Updates (teilweise verbessert)

- **Wo:** `IndexStoreV3.pruneToMatch` Z. 576–596
- **Was:** Unrelated Medien können `completedDepth` und Ordner-`contentStamp` verlieren → unnötiger Abgleich oder falsche Tiefe.
- **Warum:** Eintrags-Löschung ist korrekt über `id`/`storageID`; Metadaten-Updates bei `maxDepth` aber weiter global: `UPDATE items SET contentStamp = NULL WHERE … depth = ?` ohne `storageID`, und `completedDepth` wird für **alle** `storages` gekappt, nicht nur `touchedStorages`.
- **Vorschlag:** `contentStamp`-Update und `completedDepth`-Anpassung auf betroffene `storageID`(s) beschränken.

### 19. `childCount` ohne Scope

- **Wo:** `IndexStoreV3+Reading.swift`, `childCount` Z. 17–27
- **Was:** Lade-Fortschritt in großen Ordnern stimmt während ausstehender Bereinigung nicht (`loaded/total`).
- **Warum:** Parameter `scope` wird mit `_ = scope` ignoriert.
- **Vorschlag:** Scope in SQL anwenden oder separaten Zähler für sichtbare Kinder liefern.

### 20. `searchCount` bei Swift-Namensregeln

- **Wo:** `IndexStoreV3+Reading.swift`, `searchCount` Z. 203–224 (Swift-Cursor); Z. 226–248 (parallel ohne Namensfilter)
- **Was:** Trefferzählung bei großen Indizes und aktiven Artefakt-/Ausschlussregeln kann sehr lange dauern (UI blockiert auf Count-Task).
- **Warum:** Voller Cursor über alle SQL-Treffer mit Swift-Filter pro Zeile. Ohne `checksNames` ist Zählung parallelisiert (Verbesserung gegenüber V2).
- **Vorschlag:** Kurzfristig UX (Timeout, Schätzung); mittelfristig Regeln in SQL oder Zähler cache invalidieren bei Scope-Ende.

### 21. `forgetAllMedia`: abgebrochene DB-Löschung

- **Wo:** `AppState+Media.swift`, `forgetAllMedia` Z. 129–155
- **Was:** UI leer, in der DB bleiben Medien/Einträge für nicht gelöschte IDs.
- **Warum:** Bei operativem Fehler in der Schleife `return` statt `continue`.
- **Vorschlag:** Fehler pro ID loggen und weitermachen; optional Gesamtfehler in UI melden.

### 22. Store-Retry ohne Ladeanzeige

- **Wo:** `AppState.isStoreLoading` Z. 88; `StoreOpenFailureDialog` Retry Z. 37–39; `reportIndexStoreOpenFailure` Z. 173–176
- **Was:** Während Retry erscheint Hauptinhalt statt Ladezustand, obwohl Store nicht bereit ist.
- **Warum:** Retry ruft `startMediumRecognition` auf (`storeOpening = true`), lässt aber `indexStoreOpenFailed == true` bis erfolgreiches `wireStore` → `isStoreLoading` ist false.
- **Vorschlag:** Beim Retry `indexStoreOpenFailed = false` oder separates `isStoreRetrying`; bis `attach` Lade-UI zeigen.

### 23. Spaltenansicht: unvollständiger Reset beim Tab-Wechsel

- **Wo:** `AppState.mainWindowDestination` `didSet` Z. 125–132; `ColumnBrowserState` behält `pathStack`, `selectedMediumID`
- **Was:** Nach Wechsel Dashboard → Spalten → Dashboard → Spalten können Pfad/Medium zur alten Selection passen, Selection aber geleert sein.
- **Warum:** Nur `selection` und Filter werden zurückgesetzt, nicht Navigationszustand der Spalten.
- **Vorschlag:** Beim Verlassen von `.columnBrowser` in `mainWindowDestination.didSet` zusätzlich `pathStack`, `selectedMediumID` und `selectedUncapturedFolderID` zurücksetzen (oder den kompletten `ColumnBrowserState` außer `sidebarWidth`/`folderColumnWidth` neu initialisieren).

### 24. Mitteilungs-Delegate: Main-Actor-Annahme

- **Wo:** `AppDelegate`, `UNUserNotificationCenterDelegate` Z. 342–363
- **Was:** Potentieller Crash oder Race, wenn Apple den Delegate off-main aufruft.
- **Warum:** `MainActor.assumeIsolated` ohne vorheriges Dispatch auf Main.
- **Vorschlag:** `DispatchQueue.main.async` + MainActor-isolated Block oder `@MainActor`-Methoden mit dokumentierter Queue.

### 25. Beenden: Checkpoint nicht abgewartet

- **Wo:** `AppDelegate.prepareForAppTermination` Z. 168
- **Was:** WAL/letzte Schreibvorgänge können beim Prozessende verloren gehen → längeres Recovery beim nächsten Start.
- **Warum:** `Task { await checkpoint() }` ohne Warten; `applicationWillTerminate` endet sofort danach.
- **Vorschlag:** Synchronen Checkpoint-Pfad für Terminate (kurzes Timeout) oder Beenden verzögern bis Checkpoint fertig.

### 26. Hintergrund-Recount entkoppelt vom Lauf

- **Wo:** `DirectoryIndexer.run` Z. 146–167
- **Was:** `scanTotal` und Fortschritt springen nach Cancel/Reindex/Finish noch nachträglich.
- **Warum:** Unstrukturiertes `Task` ruft `runCountingPhase`/`setScanTotal` ohne Token- oder Cancel-Prüfung auf.
- **Vorschlag:** Recount an `token`/`shouldHalt` binden oder Task canceln, wenn der Lauf endet.

### 27. `autoIndexPaused` aus Persistenz ignoriert

- **Wo:** `MediumCoordinator` / `StoredMedium.asMedium` Z. 434
- **Was:** In DB gespeichertes `autoIndexPaused` wirkt nicht auf `IndexingService.isPaused` nach Reload/Publish.
- **Warum:** `asMedium` setzt `autoIndexPaused: false` fest.
- **Vorschlag:** Wert aus `StoredMedium.autoIndexPaused` übernehmen (Feld ist in DB und `writeMedium` vorhanden).

### 28. Integritätsfehler: Change-Loop und Store-Referenz

- **Wo:** `AppState.reportIndexStoreOpenFailure` Z. 173–176; `AppState+IndexChanges.startChangeLoop` Z. 19–28; `StartupSequence.run` Z. 59–61
- **Was:** Nach fehlgeschlagenem Hintergrund-`quick_check` zeigt die UI Fehlerdialog, aber der Change-Loop lauscht weiter auf dem geschlossenen Pool; nach Retry können zwei Loops oder ein Loop am alten Stream aktiv sein (siehe Nr. 3).
- **Warum:** Integritätsfehler nutzt dieselbe `onFailure`-Route wie Öffnen, ohne `changeLoop?.cancel()` und ohne `indexStore = nil` / `indexRepository.replaceStore(nil)`.
- **Vorschlag:** In `handleStoreFailure` nach erstem erfolgreichem Wire unterscheiden oder generell Change-Loop stoppen und Store-Referenz lösen, bevor der Fehlerdialog erscheint.

---

## Hinweis (kein Code-Defekt, Produktentscheidung)

- **`index.sqlite` → `archive.sqlite`:** `IndexStoreV3.openDefault()` öffnet nur `archive.sqlite`; eine vorhandene `index.sqlite` wird absichtlich nicht migriert (Kommentar Z. 43–44, Test `StoreSwitchTests.freshFolderGetsArchiveWithOneMigrationAndLeavesTheOldFileAlone`). Kein technischer Widerspruch im Code, aber Upgrade ohne Datenübernahme.
