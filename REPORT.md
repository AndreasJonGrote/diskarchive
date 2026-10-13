# Code-Befunde (technische Fehler)

Stand: 13.10.2026 (nach Abnahme `c.0.3.3.002`). Ursprünglich geprüft gegen Commit `be80c9c`. Nur am Quellcode bestätigte Defekte. Keine Konzept-/Layout-Abweichungen, keine Stilvorschläge. **2–28**, **29–37 / 39**, **42–50:** behoben. **38 / 40 / 41:** Spec bzw. Doku. **51:** 239-Restloch Cache (`c.0.3.245`). **52–53:** niedrige Restfehler (`c.0.3.246`).

## Behoben in `be80c9c`

### 1. Bereinigen: Hard-Delete über Pfad ohne Medium — **behoben**

- **Früher:** Pfadbasiertes `DELETE` ohne `mediumID` in `IndexStore.pruneToMatch` konnte Bäume auf anderen Medien mit gleichem relativen Pfad löschen.
- **Jetzt:** V3 speichert Pfade nur noch als Elternkette; Bereinigung löscht über `DELETE FROM items WHERE id IN (…)` (`deleteItems`) nach gezielter Auswahl (Tiefe, Namensfilter). Kein globales Pfad-Präfix-DELETE mehr.
- **Referenz:** `diskindex/diskindex/Storage/V3/IndexStoreV3.swift`, `pruneToMatch` / `deleteItems` (ca. Z. 530–619).

---

## Übersicht

### Behoben (2–28)

| Nr | Schwere | Kurz | Spur |
|----|---------|------|------|
| 2 | Kritisch | Nach Integritätsfehler laufen Dienste weiter, DB-Handle unbrauchbar | `c.0.3.2.003` |
| 3 | Hoch | Change-Loop bleibt am ersten Store nach Retry | `c.0.3.2.003` |
| 4 | Hoch | `wireStore` stoppt vorherigen Indexer/Watcher nicht | `c.0.3.2.003` |
| 5 | Hoch | Parallele Startup-Tasks ohne Abbruch | `c.0.3.2.003` |
| 6 | Hoch | FSEvents-Watcher während Erstlauf/Abgleich | `c.0.3.2.004` |
| 7 | Hoch | „Indizieren“ Ja/Nein ohne Stop/Start/Watcher | `c.0.3.2.002` |
| 8 | Hoch | FSEvents-Setup scheitert → Watcher-Task hängt | `c.0.3.2.004` |
| 9 | Hoch | Stream-Unmount beendet Watcher ohne Neustart | `c.0.3.2.004` |
| 10 | Hoch | Live-Reread: DB-Fehler, Cursor trotzdem gespeichert | `c.0.3.2.004` |
| 11 | Hoch | Suche: `LIMIT` vor Scope-Filter | `c.0.3.2.005` |
| 12 | Hoch | Spalten-Pagination endet bei leer gefilterter Seite | `c.0.3.2.005` |
| 13 | Hoch | `finish` räumt Task/Spinner vor Token-Prüfung auf | `c.0.3.2.006` |
| 14 | Hoch | Suche: `isSearchInProgress` bleibt bei Abbruch | `c.0.3.2.007` |
| 15 | Mittel | `cancel` bricht detached Index-Task nicht ab | `c.0.3.2.006` |
| 16 | Mittel | `requestedIndex`-Latch bei Pause-No-Op | `c.0.3.2.002` |
| 17 | Mittel | „Nicht indizieren“ setzt `indexStatus = .indexed` ohne Index | `c.0.3.2.002` / `002b` |
| 18 | Mittel | Depth-Bereinigung: globale Metadaten-Updates (teilweise verbessert) | `c.0.3.2.007` |
| 19 | Mittel | `childCount` ignoriert `IndexScope` | `c.0.3.2.005` |
| 20 | Mittel | `searchCount` scannt alle Treffer in Swift | `c.0.3.2.005` |
| 21 | Mittel | `forgetAllMedia` bricht DB-Löschung beim ersten Fehler ab | `c.0.3.2.007` |
| 22 | Mittel | Store-Retry ohne Ladezustand in der UI | `c.0.3.2.003` |
| 23 | Mittel | Spalten-State nur teilweise beim Tab-Wechsel zurückgesetzt | `c.0.3.2.007` |
| 24 | Mittel | Mitteilungs-Delegate ohne Main-Thread-Garantie | `c.0.3.2.007` |
| 25 | Mittel | Quit-Checkpoint nicht abgewartet | `c.0.3.2.007` |
| 26 | Mittel | Hintergrund-Recount ohne Lauf-Kopplung | `c.0.3.2.006` |
| 27 | Niedrig | `autoIndexPaused` aus DB geht in `asMedium` verloren | `c.0.3.2.007` |
| 28 | Mittel | Integritätsfehler: `indexStore`/`changeLoop` nicht zurückgesetzt | `c.0.3.2.003` |

### Behoben (29–37, 39 — Re-Audit / Spur)

| Nr | Alias | Schwere | Kurz | Spur |
|----|-------|---------|------|------|
| 29 | A1 | Hoch | `invalidateAll` löscht Generationen → stale Spalten-Cache | `c.0.3.239` |
| 30 | A2 | Hoch | Fehlerbericht-Enqueue bei busy Index-DB | `c.0.3.240` |
| 31 | A3 | Mittel | Parallele `flush()` → doppelter API-Send | `c.0.3.240` |
| 32 | A4 | Mittel | Leerlauf-Wartung gibt zu früh auf | `c.0.3.241` |
| 33 | A5 | Mittel | Leak-blockierte Queue-Zeilen ewig due | `c.0.3.240` |
| 34 | A6 | Niedrig | FAT: gone-Ordner falsch revived | `c.0.3.242` |
| 35 | N1 | Niedrig | Live-Pfad-Rename Ordner | `c.0.3.243` |
| 36 | N2 | Mittel | Regel-Reconcile kein Restart nach Fehler | `c.0.3.241` |
| 37 | N3 | Niedrig | Reachability `online` ohne Sync | `c.0.3.240` |
| 39 | N5 | Hoch* | Spalten 50k langsamer (F29) | `c.0.3.244` |

### Kein Code-Fix / Doku

| Nr | Alias | Kurz | Spur |
|----|-------|------|------|
| 38 | N4 | `lastCompactionAt` nur Audit (Spec 236) | — |
| 40 | N6 | 238-Bericht `api_queue` Text veraltet | ohne Cursor |
| 41 | N7 | README Layout-Reminder 0.3.2 | ohne Cursor |

### Behoben (42–50 — Read-only-Sperre)

| Nr | Alias | Schwere | Kurz | Spur |
|----|-------|---------|------|------|
| 42 | L1 | Mittel | `connectKnown`: Store-Writes + Backfill trotz Sperre | `c.0.3.3.002` |
| 43 | L2 | Kritisch | `forgetMedium` / `forgetAllMedia` trotz Sperre | `c.0.3.3.002` |
| 44 | L3 | Hoch | `applyChoice` / Entscheidungs-Persistenz trotz Sperre | `c.0.3.3.002` |
| 45 | L4 | Hoch | `writeMedium` / `updateMedium(persist:)` ohne Lock | `c.0.3.3.002` |
| 46 | L5 | Niedrig | `updateNotice` bleibt ohne Offer | `c.0.3.3.002` |
| 47 | L6 | Hoch | Laufender Regel-Reconcile / Restart ohne Lock | `c.0.3.3.002` |
| 48 | L7 | Hoch | Scope unter Sperre verworfen; Unlock ohne Re-Queue | `c.0.3.3.002` |
| 49 | L8 | Mittel | Lock-Cancel → UI `.indexing` | `c.0.3.3.002` |
| 50 | L9 | Mittel | `ChangeWatcher.flush` ohne Lock-Guard | `c.0.3.3.002` |

### Offen (51+)

| Nr | Alias | Schwere | Kurz | Spur-Plan |
|----|-------|---------|------|-----------|
| 51 | A1b | Mittel | `IndexRepository.load`: missing-folder setzt Cache ohne Generations-Check | `c.0.3.245` |
| 52 | R1 | Niedrig | Live-Rename: Clash ignoriert `status=gone` → Namens-Duplikat möglich | `c.0.3.246` |
| 53 | R2 | Niedrig | `AppVersion.buildTimestamp` mit `TimeZone.current` (60-Tage-Kante) | `c.0.3.246` |

\*Produktziel / Schwellen-Guard; mit 244 grün.

---

## Befunde

### 2. Integritätsfehler nach Verdrahtung: Teardown unvollständig

- **Wo:** `StartupSequence.swift` Z. 48–61; `AppDelegate.handleStoreFailure` Z. 277–287; `IndexStoreV3.runIntegrityCheck` Z. 79–86
- **Was:** Nach erfolgreichem `wire(store)` laufen Erkennung, Change-Loop, Indizierung und FSEvents. Schlägt danach `quick_check` fehl, wird die DB quarantänisiert und der Pool geschlossen — Indexer/Watcher/Change-Loop laufen weiter; `AppState.indexStore` zeigt weiter auf den geschlossenen Store.
- **Warum:** `wire` erfolgt vor dem Integritätscheck. `handleStoreFailure` ruft nur `mediumCoordinator?.stop()` auf, nicht `prepareForAppTermination()` (Watcher, Indexer, `appState.prepareForTermination()`). `reportIndexStoreOpenFailure` setzt `storeReady = false`, aber weder `indexStore = nil` noch Abbruch des Change-Loops.
- **Vorschlag:** Bei Integritätsfehler dieselbe Abbruchkette wie beim Beenden; `indexStore`/`storeReady`/`changeLoop` zurücksetzen. Integrität prüfen vor `wire` oder bei Fehler nach `wire` vollständig entkoppeln.
- **Behoben in Cursor-Spur:** `c.0.3.2.003` (Commit `ccd79ce`).

### 3. Change-Loop bleibt am ersten Store

- **Wo:** `AppState+IndexChanges.swift`, `startChangeLoop` Z. 19–28; `MediumRecognitionStartup.bootstrap` Z. 35; `AppDelegate.wireStore` Z. 315–319
- **Was:** Nach DB-Retry mit neuem `IndexStoreV3` kommen DB-Events (`emit`) nicht mehr zuverlässig in der UI an (Suche/Spalten/Favoriten-Refresh).
- **Warum:** `startChangeLoop` startet nur wenn `changeLoop == nil` und iteriert über das beim Start erfasste `indexStore`. Retry ruft erneut `startChangeLoop` auf, ohne alten Loop zu canceln/neu zu binden.
- **Vorschlag:** Vor neuem Loop alten canceln; Loop liest `indexStore` über `weak self` pro Event oder explizit nach `attach(store:)` neu starten.
- **Behoben in Cursor-Spur:** `c.0.3.2.003` (Commit `ccd79ce`).

### 4. Erneutes Verdrahten ohne Stoppen der alten Dienste

- **Wo:** `AppDelegate.wireStore` Z. 289–314; Vergleich `prepareForAppTermination` Z. 160–167
- **Was:** Zweites `wireStore` (Retry) ersetzt Referenzen auf `IndexingService`/`ChangeWatcher`, stoppt aber die vorherigen Instanzen nicht.
- **Warum:** Es wird nur `mediumCoordinator?.stop()` aufgerufen, nicht `changeWatcher?.stopAllForTermination()` / `indexingService?.cancelAllForTermination()`.
- **Vorschlag:** Vor Erzeugen neuer Dienste die alten wie bei `prepareForAppTermination` stoppen; Startup-Task serialisieren (siehe Nr. 5).
- **Behoben in Cursor-Spur:** `c.0.3.2.003` (Commit `ccd79ce`).

### 5. Überlappende Startup-Tasks

- **Wo:** `AppDelegate.startMediumRecognition` Z. 265–274; `StartupSequence.run` Z. 37–63
- **Was:** Mehrfaches Retry oder schnelles erneutes Öffnen kann zwei parallele `wire(store)`-Aufrufe auslösen.
- **Warum:** Jeder Aufruf startet ein neues `Task` ohne Handle, Abbruch oder „single flight“.
- **Vorschlag:** Laufenden Startup-Task speichern und vor neuem Start canceln; oder Mutex bis `wire` abgeschlossen.
- **Behoben in Cursor-Spur:** `c.0.3.2.003` (Commit `ccd79ce`).

### 6. Live-Watcher parallel zum Index-Lauf

- **Wo:** `LiveWiring.connect`, `setIndexHandler` Z. 81–84; `onReconcileRequested` Z. 85–90; `onRunIndexed` Z. 69–71; `IndexStoreV3.applyDirectories` Z. 257–295 (ohne Token-Prüfung; `indexingIsActive` Z. 460–461 ungenutzt)
- **Was:** Während Erstlauf oder Abgleich können FSEvents-Flushes und der Indexer gleichzeitig in dieselbe `items`-Tabelle schreiben. Beim Abgleich wird der Watcher nach `stop` sofort wieder gestartet, bevor der Lauf endet.
- **Warum:** Watcher startet bei Index-Anforderung (`setIndexHandler`), nicht erst zuverlässig nach erfolgreichem Lauf (`onRunIndexed` allein reicht nicht). `applyDirectories` prüft keinen `indexingToken`.
- **Vorschlag:** Watcher erst nach erfolgreichem Lauf starten oder während aktivem Token Watcher-Schreibvorgänge verweigern/queueen; bei Abgleich Watcher bis Laufende gestoppt lassen.
- **Behoben in Cursor-Spur:** `c.0.3.2.004` (Commit `07af1e8`).

### 7. Einstellungen „Indizieren“ ohne Lauf-Steuerung

- **Wo:** `RegistryTableRow.swift` Z. 80–83; `MediumDetailModalView.swift` (analog); `AppState.updateMedium` + `writeMedium` (persistiert nur Entscheidung)
- **Was:** Wechsel auf „Nein“ stoppt weder Indizierung noch FSEvents; Wechsel auf „Ja“ startet keinen Lauf, solange kein anderer Pfad (Mount, Reindex) greift.
- **Warum:** Kein Hook wie `onMediaForgotten` / `LiveWiring` für Entscheidungsänderung — nur UI + debounced DB-Schreiben.
- **Vorschlag:** Bei Entscheidungsänderung `cancel` + Watcher stoppen (Nein) bzw. `start` + Watcher (Ja, wenn verbunden und nicht pausiert), analog Erkennungsdialog.
- **Behoben in Cursor-Spur:** `c.0.3.2.002` (Commit in Spur 002; Entscheidungs-Hook / LiveWiring).

### 8. FSEvents-Stream-Setup: hängender AsyncStream

- **Wo:** `ChangeWatcher.swift`, `FSEventsChangeSource.open` Z. 353–358; `changes()` Z. 319–326
- **Was:** Live-Updates für ein Medium bleiben dauerhaft aus; `ChangeWatcher.tasks[mediumID]` blockiert in `for await`.
- **Warum:** Scheitert `FSEventStreamCreate` oder `FSEventStreamStart`, wird `close()` aufgerufen, aber `continuation.finish()` nie — der Stream liefert keine Events und endet nicht.
- **Vorschlag:** Bei Fehler `continuation.finish()` (optional mit Fehler-Event); Watcher-Task beenden und `tasks`/`sources` aufräumen.
- **Behoben in Cursor-Spur:** `c.0.3.2.004` (Commit `07af1e8`).

### 9. FSEvents-Unmount: Watcher tot, Medium noch verbunden

- **Wo:** `ChangeWatcher.handleStreamUnmount` Z. 164–171; `restartWatchersAfterWake` / `LiveWiring` (nur wenn `isWatching`)
- **Was:** Nach internem Unmount-Event keine Live-Sync mehr, obwohl Coordinator das Medium noch als angeschlossen führt.
- **Warum:** Task und Source werden entfernt, `mounts`/`volumes`/`cursors` bleiben; kein `saveCursor`, kein Restart; Wake-Restart überspringt nicht-watchende Medien.
- **Vorschlag:** Vollständiges `stop(mediumID:)` oder bei verbundenem Medium Watcher neu starten; Cursor speichern.
- **Behoben in Cursor-Spur:** `c.0.3.2.004` (Commit `07af1e8`).

### 10. Live-Reread: Fehler, Cursor dennoch fortgeschrieben

- **Wo:** `ChangeWatcherEngine.processPending` Z. 120–141; `ChangeWatcher.flush` Z. 231–241
- **Was:** Index weicht von der Platte ab; Nutzer sieht keinen Fehler; spätere Events gelten als verarbeitet.
- **Warum:** `applyDirectories`-Fehler werden nur geloggt; Rückgabe bleibt `.ok`; `flush` ruft immer `saveCursor` auf.
- **Vorschlag:** Bei Fehler `.needsFullReconcile` oder Fehlerzustand; Cursor nur bei Erfolg speichern.
- **Behoben in Cursor-Spur:** `c.0.3.2.004` (Commit `07af1e8`).

### 11. Suche: Limit vor Namens-Scope

- **Wo:** `IndexStoreV3+Reading.swift`, `search` Z. 189–199; `topHits` Z. 291–298
- **Was:** Während ausstehender Bereinigung (`pruneAt`, `scope.checksNames`) können Suchlisten leer oder stark unter 500 Treffer sein, obwohl `searchCount` hoch ist.
- **Warum:** SQL wendet `LIMIT` an (`searchHitsSQL`), danach filtert Swift nach Ausschluss/Artefakt-Regeln.
- **Vorschlag:** Bei `checksNames` paginieren bis genug sichtbare Treffer oder Filter in SQL nachziehen (wo möglich).
- **Behoben in Cursor-Spur:** `c.0.3.2.005` (Commit `cb0c60c`).

### 12. Spalten: Pagination bricht bei leerer gefilterter Seite ab

- **Wo:** `IndexStoreV3+Reading.swift`, `childrenPage` Z. 99–106; `IndexRepository` lädt Seiten bis `nextCursor == nil`
- **Was:** Ordner wirkt leer oder unvollständig, obwohl sichtbare Kinder weiter hinten in der DB existieren.
- **Warum:** Liefert die DB-Seite Zeilen, filtert Swift aber alle weg, ist `filtered.count < limit` → `nextCursor = nil` (auch wenn `rows` voll war).
- **Vorschlag:** Weiterblättern in SQL, solange `nextCursor` aus letzter DB-Zeile kommt, nicht aus gefilterter Menge; oder leere Seite ≠ Ende.
- **Behoben in Cursor-Spur:** `c.0.3.2.005` (Commit `cb0c60c`).

### 13. Index-`finish`: UI vor Token-Validierung

- **Wo:** `IndexingService.finish` Z. 176–179
- **Was:** Menüleisten-Spinner verschwindet, obwohl ein neuerer Lauf für dasselbe Medium aktiv ist.
- **Warum:** `tasks[mediumUUID] = nil` und `clearMenuBarRunIndicators` laufen vor `guard runs[mediumUUID] == token`.
- **Vorschlag:** Zuerst Token prüfen, dann Task/Spinner nur für gültigen Lauf zurücksetzen.
- **Behoben in Cursor-Spur:** `c.0.3.2.006` (Commit `90ef0ba`).

### 14. Suche: Fortschrittsflag bei Task-Abbruf

- **Wo:** `AppState+IndexChanges.swift`, `runSearch` Z. 103–114
- **Was:** Nach Verlassen der Suche oder Abbruch der SwiftUI-`.task` bleibt „Suche läuft“ sichtbar.
- **Warum:** `isSearchInProgress = true` ohne `defer`/Cancellation-Handler; bei Abbruch während `await SearchIndex.matching` oder bei `generation != searchGeneration` (Z. 114) wird Z. 127 nicht erreicht.
- **Vorschlag:** `defer { … false }` mit Generation/Cancellation-Prüfung oder bei Cancellation explizit zurücksetzen.
- **Behoben in Cursor-Spur:** `c.0.3.2.007` (Commit `d7dc092`).

### 15. `cancel` ohne Task-Abbruch

- **Wo:** `IndexingService.cancel` Z. 112–125; Vergleich `cancelAllForTermination` Z. 102–107
- **Was:** Nach Abziehen/Vergessen kann der Indexer noch lange I/O auf dem Medium ausführen und spät `finish` aufrufen.
- **Warum:** Es wird nur der Token entfernt und `halt` liefert `.cancel`; `tasks[mediumUUID]?.cancel()` fehlt.
- **Vorschlag:** Detached-Task canceln; danach wie bisher Token/Store/UI.
- **Behoben in Cursor-Spur:** `c.0.3.2.006` (Commit `90ef0ba`).

### 16. `requestedIndex`-Latch bei frühem `start`-Abbruch

- **Wo:** `MediumCoordinator.requestIndex` Z. 340–345; `IndexingService.start` Z. 48
- **Was:** Medium startet nach Pause/Entscheidung keinen Erstlauf, bis Remount.
- **Warum:** Latch wird gesetzt, bevor `start` läuft; bei `isPaused` returniert `start` ohne Lauf, Latch bleibt gesetzt.
- **Vorschlag:** Latch erst nach erfolgreichem Start setzen, oder bei No-Op `requestedIndex.remove(mediumID)`.
- **Behoben in Cursor-Spur:** `c.0.3.2.002` (Commit in Spur 002).

### 17. Erkennungsdialog „Nicht indizieren“: falscher Index-Status

- **Wo:** `MediumCoordinator.applyChoice` Z. 323–325
- **Was:** Medium ohne Index kann in DB/UI als `indexStatus == .indexed` erscheinen (Chip/Filter inkonsistent zu `hasIndex`).
- **Warum:** Bei `allowIndexing == false` wird `indexStatus` auf `.indexed` gesetzt, unabhängig vom vorhandenen Index.
- **Vorschlag:** Status unverändert lassen oder expliziten Zustand „kein Index + Nein“; nicht `.indexed` ohne Daten.
- **Behoben in Cursor-Spur:** `c.0.3.2.002` / `c.0.3.2.002b` (`hasIndex ? .indexed : .pending` in `applyChoice`).

### 18. Depth-Bereinigung: globale Metadaten-Updates (teilweise verbessert)

- **Wo:** `IndexStoreV3.pruneToMatch` Z. 576–596
- **Was:** Unrelated Medien können `completedDepth` und Ordner-`contentStamp` verlieren → unnötiger Abgleich oder falsche Tiefe.
- **Warum:** Eintrags-Löschung ist korrekt über `id`/`storageID`; Metadaten-Updates bei `maxDepth` aber weiter global: `UPDATE items SET contentStamp = NULL WHERE … depth = ?` ohne `storageID`, und `completedDepth` wird für **alle** `storages` gekappt, nicht nur `touchedStorages`.
- **Vorschlag:** `contentStamp`-Update und `completedDepth`-Anpassung auf betroffene `storageID`(s) beschränken.
- **Behoben in Cursor-Spur:** `c.0.3.2.007` (Commit `d7dc092`).

### 19. `childCount` ohne Scope

- **Wo:** `IndexStoreV3+Reading.swift`, `childCount` Z. 17–27
- **Was:** Lade-Fortschritt in großen Ordnern stimmt während ausstehender Bereinigung nicht (`loaded/total`).
- **Warum:** Parameter `scope` wird mit `_ = scope` ignoriert.
- **Vorschlag:** Scope in SQL anwenden oder separaten Zähler für sichtbare Kinder liefern.
- **Behoben in Cursor-Spur:** `c.0.3.2.005` (Commit `cb0c60c`).

### 20. `searchCount` bei Swift-Namensregeln

- **Wo:** `IndexStoreV3+Reading.swift`, `searchCount` Z. 203–224 (Swift-Cursor); Z. 226–248 (parallel ohne Namensfilter)
- **Was:** Trefferzählung bei großen Indizes und aktiven Artefakt-/Ausschlussregeln kann sehr lange dauern (UI blockiert auf Count-Task).
- **Warum:** Voller Cursor über alle SQL-Treffer mit Swift-Filter pro Zeile. Ohne `checksNames` ist Zählung parallelisiert (Verbesserung gegenüber V2).
- **Vorschlag:** Kurzfristig UX (Timeout, Schätzung); mittelfristig Regeln in SQL oder Zähler cache invalidieren bei Scope-Ende.
- **Behoben in Cursor-Spur:** `c.0.3.2.005` (Commit `cb0c60c`).

### 21. `forgetAllMedia`: abgebrochene DB-Löschung

- **Wo:** `AppState+Media.swift`, `forgetAllMedia` Z. 129–155
- **Was:** UI leer, in der DB bleiben Medien/Einträge für nicht gelöschte IDs.
- **Warum:** Bei operativem Fehler in der Schleife `return` statt `continue`.
- **Vorschlag:** Fehler pro ID loggen und weitermachen; optional Gesamtfehler in UI melden.
- **Behoben in Cursor-Spur:** `c.0.3.2.007` (Commit `d7dc092`).

### 22. Store-Retry ohne Ladeanzeige

- **Wo:** `AppState.isStoreLoading` Z. 88; `StoreOpenFailureDialog` Retry Z. 37–39; `reportIndexStoreOpenFailure` Z. 173–176
- **Was:** Während Retry erscheint Hauptinhalt statt Ladezustand, obwohl Store nicht bereit ist.
- **Warum:** Retry ruft `startMediumRecognition` auf (`storeOpening = true`), lässt aber `indexStoreOpenFailed == true` bis erfolgreiches `wireStore` → `isStoreLoading` ist false.
- **Vorschlag:** Beim Retry `indexStoreOpenFailed = false` oder separates `isStoreRetrying`; bis `attach` Lade-UI zeigen.
- **Behoben in Cursor-Spur:** `c.0.3.2.003` (Commit `ccd79ce`).

### 23. Spaltenansicht: unvollständiger Reset beim Tab-Wechsel

- **Wo:** `AppState.mainWindowDestination` `didSet` Z. 125–132; `ColumnBrowserState` behält `pathStack`, `selectedMediumID`
- **Was:** Nach Wechsel Dashboard → Spalten → Dashboard → Spalten können Pfad/Medium zur alten Selection passen, Selection aber geleert sein.
- **Warum:** Nur `selection` und Filter werden zurückgesetzt, nicht Navigationszustand der Spalten.
- **Vorschlag:** Beim Verlassen von `.columnBrowser` in `mainWindowDestination.didSet` zusätzlich `pathStack`, `selectedMediumID` und `selectedUncapturedFolderID` zurücksetzen (oder den kompletten `ColumnBrowserState` außer `sidebarWidth`/`folderColumnWidth` neu initialisieren).
- **Behoben in Cursor-Spur:** `c.0.3.2.007` (Commit `d7dc092`).

### 24. Mitteilungs-Delegate: Main-Actor-Annahme

- **Wo:** `AppDelegate`, `UNUserNotificationCenterDelegate` Z. 342–363
- **Was:** Potentieller Crash oder Race, wenn Apple den Delegate off-main aufruft.
- **Warum:** `MainActor.assumeIsolated` ohne vorheriges Dispatch auf Main.
- **Vorschlag:** `DispatchQueue.main.async` + MainActor-isolated Block oder `@MainActor`-Methoden mit dokumentierter Queue.
- **Behoben in Cursor-Spur:** `c.0.3.2.007` (Commit `d7dc092`).

### 25. Beenden: Checkpoint nicht abgewartet

- **Wo:** `AppDelegate.prepareForAppTermination` Z. 168
- **Was:** WAL/letzte Schreibvorgänge können beim Prozessende verloren gehen → längeres Recovery beim nächsten Start.
- **Warum:** `Task { await checkpoint() }` ohne Warten; `applicationWillTerminate` endet sofort danach.
- **Vorschlag:** Synchronen Checkpoint-Pfad für Terminate (kurzes Timeout) oder Beenden verzögern bis Checkpoint fertig.
- **Behoben in Cursor-Spur:** `c.0.3.2.007` (Commit `d7dc092`).

### 26. Hintergrund-Recount entkoppelt vom Lauf

- **Wo:** `DirectoryIndexer.run` Z. 146–167
- **Was:** `scanTotal` und Fortschritt springen nach Cancel/Reindex/Finish noch nachträglich.
- **Warum:** Unstrukturiertes `Task` ruft `runCountingPhase`/`setScanTotal` ohne Token- oder Cancel-Prüfung auf.
- **Vorschlag:** Recount an `token`/`shouldHalt` binden oder Task canceln, wenn der Lauf endet.
- **Behoben in Cursor-Spur:** `c.0.3.2.006` (Commit `90ef0ba`).

### 27. `autoIndexPaused` aus Persistenz ignoriert

- **Wo:** `MediumCoordinator` / `StoredMedium.asMedium` Z. 434
- **Was:** In DB gespeichertes `autoIndexPaused` wirkt nicht auf `IndexingService.isPaused` nach Reload/Publish.
- **Warum:** `asMedium` setzt `autoIndexPaused: false` fest.
- **Vorschlag:** Wert aus `StoredMedium.autoIndexPaused` übernehmen (Feld ist in DB und `writeMedium` vorhanden).
- **Behoben in Cursor-Spur:** `c.0.3.2.007` (Commit `d7dc092`).

### 28. Integritätsfehler: Change-Loop und Store-Referenz

- **Wo:** `AppState.reportIndexStoreOpenFailure` Z. 173–176; `AppState+IndexChanges.startChangeLoop` Z. 19–28; `StartupSequence.run` Z. 59–61
- **Was:** Nach fehlgeschlagenem Hintergrund-`quick_check` zeigt die UI Fehlerdialog, aber der Change-Loop lauscht weiter auf dem geschlossenen Pool; nach Retry können zwei Loops oder ein Loop am alten Stream aktiv sein (siehe Nr. 3).
- **Warum:** Integritätsfehler nutzt dieselbe `onFailure`-Route wie Öffnen, ohne `changeLoop?.cancel()` und ohne `indexStore = nil` / `indexRepository.replaceStore(nil)`.
- **Vorschlag:** In `handleStoreFailure` nach erstem erfolgreichem Wire unterscheiden oder generell Change-Loop stoppen und Store-Referenz lösen, bevor der Fehlerdialog erscheint.
- **Behoben in Cursor-Spur:** `c.0.3.2.003` (Commit `ccd79ce`; gemeinsam mit Nr. 2).

---

## Neue Befunde (Re-Audit 13.10.)

### 29 / A1. Spalten-Cache: `invalidateAll` löscht Generationen

- **Wo:** `IndexRepository.invalidateAll`; Aufruf aus `AppState+RuleReconcile` (`startRuleReconcileWorker` / nach Idle)
- **Was:** Nach Regel-Reconcile können veraltete Ordner-Loads den Cache überschreiben (falsche / gefilterte Zeilen, Flackern).
- **Warum:** `invalidate` bumpt `loadGenerations`, `invalidateAll` macht `removeAll()` — laufende Loads mit Token `0` matchen danach wieder `default: 0`.
- **Vorschlag:** Wie bei `invalidate` Generationen bumpen (oder globale Generation), nicht löschen; Test: Load während `invalidateAll` schreibt nicht mehr.
- **Spur:** `c.0.3.239`
- **Behoben in Cursor-Spur:** `c.0.3.239` — `invalidateAll` bumpt Generationen wie `invalidate`.

### 30 / A2. Fehlerbericht verloren bei busy Index-DB

- **Wo:** `ApiQueuePersistence.openQueuePool` (zweiter `DatabasePool` auf `archive.sqlite`); `IssueReporter.enqueue` `catch` → log + `return`
- **Was:** Unter Last (langer Index-Write) kann Enqueue scheitern; Bericht ist weg (kein Datei-Outbox-Fallback mehr).
- **Warum:** Kein `busyMode`/Timeout in `SchemaV3.makeConfiguration`; zweiter Pool konkurriert mit dem Index-Pool.
- **Vorschlag:** Busy-Timeout und/oder gemeinsamen Pool / Retry; optional kurzer Datei-Fallback nur für Crash-Enqueue.
- **Spur:** `c.0.3.240`
- **Behoben in Cursor-Spur:** `c.0.3.240` (mit A3/A5/N3).

### 31 / A3. Parallele `flush()` doppelter Send

- **Wo:** `IssueReporter.flush` / `flushInBackground`; Trigger von `ApiQueueReachability` (online) + 60-s-Timer + Enqueue
- **Was:** Dieselbe Queue-Zeile kann zweimal POSTet und gelöscht werden.
- **Warum:** Kein Single-Flight / Mutex um `flush`.
- **Vorschlag:** Ein laufender Flush; weitere Aufrufe warten oder mergen.
- **Spur:** `c.0.3.240`
- **Behoben in Cursor-Spur:** `c.0.3.240`.

### 32 / A4. Leerlauf-Wartung bricht nach kurzer Busy-Phase ab

- **Wo:** `AppState+DatabaseMaintenance.startDatabaseMaintenanceWorker` (wenige Versuche); `endMediumLiveSync` plant nicht neu
- **Was:** Nach Index/Live kann Freelist/Schuld liegen bleiben, bis der nächste Trigger kommt.
- **Warum:** Worker gibt auf, wenn `canRunDatabaseMaintenance` mehrfach false ist.
- **Vorschlag:** Länger/backoff erneut versuchen oder nach `endMediumLiveSync` / Idle erneut `scheduleDatabaseMaintenance`.
- **Spur:** `c.0.3.241`
- **Behoben in Cursor-Spur:** `c.0.3.241` (mit N2).

### 33 / A5. Leak-blockierte Queue-Zeilen bleiben stecken

- **Wo:** `IssueReporter.send` — `ReportScrubber.leakCategory` → `return` ohne Delete/Markierung
- **Was:** Zeile bleibt „due“; Timer läuft weiter; Flush-No-Ops.
- **Warum:** Send korrekt blockiert, Persistenz nicht bereinigt.
- **Vorschlag:** Zeile löschen oder als `blocked`/nicht due markieren; Timer nur bei echtem Work.
- **Spur:** `c.0.3.240`
- **Behoben in Cursor-Spur:** `c.0.3.240`.

### 34 / A6. FAT: einzelner gone-Ordner falsch revived

- **Wo:** `DirectoryWriterV3.matchGoneCandidate` (Ordner ohne Partial-Verify)
- **Was:** Bei genau einem gone-Ordner ohne `fileID` kann ein neuer, unzusammenhängender Ordner dessen ID/Favoriten übernehmen.
- **Warum:** Ordner-Kandidaten ohne Größe/mtime-Unterscheidung; Partial nur für Dateien.
- **Vorschlag:** Strengere Ordner-Disambiguierung (Name/Pfad/Eltern) oder Partial/Inhalt für Ordner; nie automatisch bei `matches.count == 1` ohne Merkmal.
- **Spur:** `c.0.3.242`
- **Behoben in Cursor-Spur:** `c.0.3.242`.

### 35 / N1. Live-Pfad-Rename überspringt Ordner

- **Wo:** `DirectoryWriterV3.applyLivePathRename` — `if row.isFolder { return false }`
- **Was:** Ordner-Umbenennung/-Verschiebung live nur über Eltern-Reread / `fileID` / gone-Match; IDs/Favoriten auf Ordnern können reißen.
- **Warum:** Bewusste 235b-Lücke (nur Dateien im Paar-Pfad).
- **Vorschlag:** Optional Ordner-Relocate inkl. Tiefen-Update der Kinder (eigene Aufgabe).
- **Spur:** `c.0.3.243`
- **Behoben in Cursor-Spur:** `c.0.3.243`.

### 36 / N2. Regel-Reconcile startet nach Fehler nicht neu

- **Wo:** `AppState+RuleReconcile.startRuleReconcileWorker` — `catch` → `return`; `finishRuleReconcileWorker` prüft `needsRerun` nicht
- **Was:** Wenn während eines fehlgeschlagenen Laufs erneut `enqueueRuleReconcile` kam, bleibt `ruleReconcileNeedsRerun == true`, ohne Worker, bis zum nächsten Enqueue.
- **Warum:** Fehlerpfad beendet den Task ohne Re-Schedule.
- **Vorschlag:** In `finishRuleReconcileWorker` bei `needsRerun` erneut starten; oder nach Fehler kurz retry.
- **Spur:** `c.0.3.241`
- **Behoben in Cursor-Spur:** `c.0.3.241`.

### 37 / N3. `ApiQueueReachability.online` ohne Synchronisation

- **Wo:** `ApiQueueReachability` (`@unchecked Sendable`), Feld `online`
- **Was:** Theoretischer Data Race (Monitor-Queue schreibt; Timer-Pfad liest indirekt über Handler-Logik).
- **Warum:** Kein Lock/Actor; Schwere niedrig (Praxis: `online` vor allem auf Monitor-Queue).
- **Vorschlag:** Atomar / Main-Actor-only State; mit `c.0.3.240` mitziehen.
- **Spur:** `c.0.3.240`
- **Behoben in Cursor-Spur:** `c.0.3.240`.

### 38 / N4. `lastCompactionAt` nur geschrieben

- **Wo:** `DatabaseMaintenance.setLastCompaction`; kein Reader als Zeit-Trigger
- **Was:** Kein zeitgesteuerter Compaction-Trigger über dieses Feld.
- **Warum:** Abnahme 236: Compaction über Schuld ≥ 10 000; Zeit = Integrität (7 Tage). **Kein Defekt** — Spec-Notiz.
- **Vorschlag:** Kein Fix; optional später Zeit-Trigger nur nach Konzept-Änderung.
- **Spur:** keiner

### 39 / N5. ROADMAP 0.3 Spalten-Schwelle (F29)

- **Wo:** Messung `Werkzeuge/messung/2026-10-12-nachher-*`; ROADMAP „Fertig wenn“ Spalten nicht langsamer
- **Was:** Spalten „alle Seiten, 50 000“ nachher langsamer (S1 ~+30 %, S2 ~+20 %); Größe und Abfrage-Schwellen bestanden.
- **Warum:** V3-Lese-/Paginierungspfad; Maschinenwechsel M3→M4 erklärt die Verlangsamung nicht weg.
- **Vorschlag:** Profiling + gezielte Optimierung Spalten-Pagination/Cache (Produktcode); **kein** Test abschwächen; **kein** Doku-/Layout-Auftrag.
- **Spur:** `c.0.3.244`
- **Behoben in Cursor-Spur:** `c.0.3.244` — Guard ±10 % grün (`2026-10-13-spalten-244-final-vergleich.md`).

### 40 / N6. Doku: 238-Bericht zu `api_queue`

- **Wo:** `Werkzeuge/messung/2026-10-12-nachher-bericht.md` §5
- **Was:** Text „`api_queue` bewusst ungenutzt“ ist nach `c.0.3.1.001` falsch.
- **Warum:** Bericht vor API-Warteschlange geschrieben.
- **Vorschlag:** Ein Satz korrigieren (Nutzer/Claude; **ohne Cursor-Code**).
- **Spur:** ohne Cursor

### 41 / N7. Doku: README Layout-Reminder 0.3.2

- **Wo:** README „Layout-Reminder (0.3.2, vor Code)“
- **Was:** „Erst Layout, dann Aufgabe“ — Produktcode 0.3.2 ist schon da; Mockups 02/04 fehlen noch.
- **Warum:** Reihenfolge umgedreht.
- **Vorschlag:** Reminder anpassen (Nutzer/Claude; **ohne Cursor-Code**).
- **Spur:** ohne Cursor

---

## Neue Befunde (Abend-Audit 13.10. — Read-only-Sperre)

Nach `c.0.3.3.001` gilt laut Konzept: bei Sperre **keine Index-/Medium-Schreibpfade**. LiveWiring, Index-Start, Reconcile, Prune, Favoriten und „neue Medien“ sind geschützt. Die folgenden Pfade **nicht**.

### 42 / L1. `connectKnown` schreibt trotz Sperre

- **Wo:** `MediumCoordinator.connectKnown` (ca. Z. 130–217); `recordIdentity`, mehrfach `updateMedium`, Task `backfillMissingFavoritePartials`
- **Was:** Bekanntes Medium: DB-Writes + Partial-Backfill trotz `!canWriteIndex`. Erneute Prüfung: `receiveUnknown`/`storeAndPresent`/`requestIndex` sind geschützt; `connectKnown` nicht.
- **Warum:** Guard fehlt am Schreibpfad von `connectKnown` (Anzeige/publish wäre für Read-only ok).
- **Vorschlag:** Store-Writes/Backfill/Dialog/Index nur bei `canWriteIndex`; sonst nur in-memory publish. Test: Sperre → kein Write.
- **Spur:** `c.0.3.3.002`
- **Behoben in Cursor-Spur:** `c.0.3.3.002`.

### 43 / L2. `forgetMedium` / `forgetAllMedia` trotz Sperre

- **Wo:** `AppState+Media.forgetMedium` / `forgetAllMedia` (kein `canWriteIndex`; Store `deleteMedium`)
- **Was:** Nutzer kann Medien aus dem Archiv löschen, obwohl Schreibsperre aktiv ist. Erneute Prüfung + Hintergrund-Audit: bestätigt (**kritisch**).
- **Warum:** Forget-Routen prüfen `canWriteIndex` nicht.
- **Vorschlag:** Guard + UI deaktivieren bei Sperre; Test: Forget No-Op wenn locked.
- **Spur:** `c.0.3.3.002`
- **Behoben in Cursor-Spur:** `c.0.3.3.002`.

### 44 / L3. `applyChoice` schreibt Entscheidung trotz Sperre

- **Wo:** `MediumCoordinator.applyChoice` (ca. Z. 317+); `requestIndex` ist geschützt, `applyChoice` nicht
- **Was:** Indizier-Entscheidung / Remember-Write (`store.updateMedium`) läuft trotz Sperre. Erneute Prüfung + Hintergrund-Audit: bestätigt (**hoch**).
- **Warum:** Kein Lock-Check in `applyChoice`.
- **Vorschlag:** `guard canWriteIndex`; Dialog bei Sperre nicht anbieten bzw. Ablehnung No-Op.
- **Spur:** `c.0.3.3.002`
- **Behoben in Cursor-Spur:** `c.0.3.3.002`.

### 45 / L4. `writeMedium` / `updateMedium(persist:)` ohne Lock

- **Wo:** `AppState+IndexChanges.writeMedium`; `AppState+Media.updateMedium(persist:)` → `scheduleMediumWrite`; Registry/Detail-Entscheidungstoggles
- **Was:** UI-Persistenz (Entscheidung, Kapazität, …) ohne Guard. Favoriten-API geschützt; Entscheidungs-Toggles nicht. Erneute Prüfung + Hintergrund-Audit: bestätigt.
- **Warum:** Schranke nur an ausgewählten Call-Sites.
- **Vorschlag:** Guard in `writeMedium`; bei Entscheidungsänderung unter Sperre auch `updateMedium(persist:)` No-Op oder Revert; Tests.
- **Spur:** `c.0.3.3.002`
- **Behoben in Cursor-Spur:** `c.0.3.3.002`.

### 46 / L5. `updateNotice` bleibt ohne Offer

- **Wo:** `AppState+VersionLock.applyVersionLockEvaluation` Z. 18–27; Clear nur in `dismissUpdateNotice`
- **Was:** Wenn `evaluation.updateOffer == nil`, bleibt bestehendes `updateNotice` stehen. Erneute Prüfung: bestätigt (kein `else`-Clear).
- **Warum:** Nur Setzen/Aktualisieren bei Offer, kein Clear bei fehlendem Offer.
- **Vorschlag:** Bei fehlendem Offer `updateNotice = nil`; kurzer Test.
- **Spur:** `c.0.3.3.002`
- **Behoben in Cursor-Spur:** `c.0.3.3.002`.

### 47 / L6. Regel-Reconcile läuft / startet trotz Sperre

- **Wo:** `AppState+RuleReconcile.startRuleReconcileWorker` / `finishRuleReconcileWorker`; `AppDelegate.onVersionLockEngaged` bricht nur Index + Watcher ab
- **Was:** Ein laufender `reconcileScopeToStatus` schreibt weiter. `finish…` startet bei `needsRerun` erneut **ohne** `canWriteIndex`. Erneute Prüfung (Hintergrund-Audit): bestätigt.
- **Warum:** Lock-Hook ruft nicht `cancelRuleReconcileForTermination` / Worker-Cancel; Restart-Pfad ungeprüft.
- **Vorschlag:** Bei Sperre Reconcile abbrechen; in `finish` und `start` Guard; Test: Lock mitlaufendem Worker → keine weiteren Writes / kein Restart.
- **Spur:** `c.0.3.3.002`
- **Behoben in Cursor-Spur:** `c.0.3.3.002` (+ `cancelRuleReconcileForVersionLock` mit Deferred).

### 48 / L7. Scope-Änderung unter Sperre geht verloren

- **Wo:** `AppState.appSettings` didSet → `enqueueRuleReconcile()`; Guard in `enqueue` returnt ohne Flag
- **Was:** Ignore/Scope-Änderung während Sperre setzt weder Worker noch `ruleReconcileNeedsRerun`. Nach Unlock kein automatischer Abgleich → Status/Scope können falsch bleiben.
- **Warum:** Früher Return verwirft die Dirty-Markierung; Unlock queued nichts nach.
- **Vorschlag:** Unter Sperre Dirty merken (Flag); bei Unlock `enqueueRuleReconcile()`; oder `needsRerun` auch bei Lock setzen und Worker erst bei Unlock starten.
- **Spur:** `c.0.3.3.002`
- **Behoben in Cursor-Spur:** `c.0.3.3.002`.

### 49 / L8. Lock-Cancel lässt UI auf `.indexing`

- **Wo:** `onVersionLockEngaged` → `IndexingService.cancelAllForTermination` (nicht `cancel(mediumUUID:)`)
- **Was:** Tasks/`runs` werden entfernt; `finish` sieht Token-Mismatch und räumt Status nicht → Medium kann in der UI `.indexing` bleiben.
- **Warum:** Termination-Cancel ist für Quit gedacht, nicht für sauberes Lauf-Ende.
- **Vorschlag:** Pro Medium `cancel(mediumUUID:)` (oder gemeinsamer Pfad, der Status auf pending/indexed setzt); Test: Lock während Index → Status nicht `.indexing`.
- **Spur:** `c.0.3.3.002`
- **Behoben in Cursor-Spur:** `c.0.3.3.002` (`cancelAllActiveForVersionLock`).

### 50 / L9. Watcher-Flush nach Lock

- **Wo:** `ChangeWatcher.flush`; `stopAllWatching` erst async nach Lock
- **Was:** Quiet-Period-Flush / in-flight `flush` hat kein `canWriteIndex` → kurzes Schreibfenster nach Sperre.
- **Warum:** Guard fehlt am Flush; Stop ist asynchron.
- **Vorschlag:** `guard canWriteIndex` in `flush` (und ggf. vor `processPending`); Test mit Sabotage-Lock während pending events.
- **Spur:** `c.0.3.3.002`
- **Behoben in Cursor-Spur:** `c.0.3.3.002`.

### 51 / A1b. Missing-Folder-Cache ohne Generations-Check

- **Wo:** `IndexRepository.load` — Zweig `parentID == nil` (nicht-root) setzt `cache[key] = []` und `return` **ohne** `loadToken`-Vergleich (Z. ~226–228)
- **Was:** Nach `invalidateAll` (239 bumpt Generationen) kann ein veralteter Load trotzdem leeren Cache schreiben → Spalten-Loch.
- **Warum:** 239 bumpt Generationen; dieser Early-Exit prüft sie nicht.
- **Vorschlag:** Vor `cache[key] = []` denselben Guard wie bei Erfolgspfad; Test: invalidate während missing-folder-Load.
- **Spur:** `c.0.3.245`

### 52 / R1. Live-Rename Clash ignoriert `gone`

- **Wo:** `DirectoryWriterV3.applyLivePathRename` — Clash mit `allowGone: false`
- **Was:** Zielname mit existierender `status=gone`-Zeile blockiert nicht → mögliche doppelte Namen unter demselben Parent.
- **Warum:** Clash-Query schließt gone aus.
- **Vorschlag:** Clash inkl. gone prüfen bzw. gone-Zeile vor Rename behandeln; Test.
- **Spur:** `c.0.3.246`

### 53 / R2. Build-Timestamp in lokaler Zeitzone

- **Wo:** `AppVersion.buildTimestamp` — `formatter.timeZone = TimeZone.current`
- **Was:** 60-Tage-Sperrkante verschiebt sich mit der System-Zeitzone gegenüber einem festen Kalendertag.
- **Warum:** Kein UTC / feste Zone.
- **Vorschlag:** UTC (oder Bundle-Dokumentation); Test mit fester Zone.
- **Spur:** `c.0.3.246`

---

## Hinweis (kein Code-Defekt, Produktentscheidung)

- **`index.sqlite` → `archive.sqlite`:** `IndexStoreV3.openDefault()` öffnet nur `archive.sqlite`; eine vorhandene `index.sqlite` wird absichtlich nicht migriert (Kommentar Z. 43–44, Test `StoreSwitchTests.freshFolderGetsArchiveWithOneMigrationAndLeavesTheOldFileAlone`). Kein technischer Widerspruch im Code, aber Upgrade ohne Datenübernahme.
