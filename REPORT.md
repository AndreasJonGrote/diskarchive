# Code-Befunde (technische Fehler)

Stand: 13.10.2026 (nach Abnahme `c.0.3.246`). **Neu: Audit „claude seitenweise“ vom 13.10.2026 (Befunde 54–109) und Zweitprüfung am selben Abend (Urteile zu 54–109, neue Befunde 110–132), siehe Abschnitte am Ende.** Ursprünglich geprüft gegen Commit `be80c9c`. Nur am Quellcode bestätigte Defekte. Keine Konzept-/Layout-Abweichungen, keine Stilvorschläge. **2–28**, **29–37 / 39**, **42–53:** behoben (Code). **38 / 40 / 41:** Spec bzw. Doku (ohne Cursor).

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

### Behoben (51 — A1b)

| Nr | Alias | Schwere | Kurz | Spur |
|----|-------|---------|------|------|
| 51 | A1b | Mittel | `IndexRepository.load`: missing-folder ohne Generations-Check | `c.0.3.245` |

### Behoben (52–53)

| Nr | Alias | Schwere | Kurz | Spur |
|----|-------|---------|------|------|
| 52 | R1 | Niedrig | Live-Rename: Clash ignoriert `status=gone` | `c.0.3.246` |
| 53 | R2 | Niedrig | `buildTimestamp` / 60-Tage-Kante in lokaler TZ | `c.0.3.246` |

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
- **Behoben in Cursor-Spur:** `c.0.3.245` (`loadToken`-Guard + `invalidateAllDuringMissingFolderLoadDoesNotCacheEmpty`).

### 52 / R1. Live-Rename Clash ignoriert `gone`

- **Wo:** `DirectoryWriterV3.applyLivePathRename` — Clash mit `allowGone: false`
- **Was:** Zielname mit existierender `status=gone`-Zeile blockiert nicht → mögliche doppelte Namen unter demselben Parent.
- **Warum:** Clash-Query schließt gone aus.
- **Vorschlag:** Clash inkl. gone prüfen bzw. gone-Zeile vor Rename behandeln; Test.
- **Spur:** `c.0.3.246`
- **Behoben in Cursor-Spur:** `c.0.3.246` (`allowGone: true` + `removeGonePlaceholder`).

### 53 / R2. Build-Timestamp in lokaler Zeitzone

- **Wo:** `AppVersion.buildTimestamp` — `formatter.timeZone = TimeZone.current`
- **Was:** 60-Tage-Sperrkante verschiebt sich mit der System-Zeitzone gegenüber einem festen Kalendertag.
- **Warum:** Kein UTC / feste Zone.
- **Vorschlag:** UTC (oder Bundle-Dokumentation); Test mit fester Zone.
- **Spur:** `c.0.3.246`
- **Behoben in Cursor-Spur:** `c.0.3.246` (UTC-Parse + `buildExpiryCalendar` UTC).

---

## Hinweis (kein Code-Defekt, Produktentscheidung)

- **`index.sqlite` → `archive.sqlite`:** `IndexStoreV3.openDefault()` öffnet nur `archive.sqlite`; eine vorhandene `index.sqlite` wird absichtlich nicht migriert (Kommentar Z. 43–44, Test `StoreSwitchTests.freshFolderGetsArchiveWithOneMigrationAndLeavesTheOldFileAlone`). Kein technischer Widerspruch im Code, aber Upgrade ohne Datenübernahme.

---

# Audit 13.10.2026 — claude seitenweise

**Kennung:** `claude seitenweise` · **Datum:** 13.10.2026 · **Stand:** Commit `76b6a71` (`c.0.3.246`), Arbeitsbaum sauber.
**Umfang:** nur Programmcode (`diskindex/diskindex/**`, dazu Tests und Build-Einstellungen, soweit für Befunde nötig). Konzept- und Layout-Themen stehen getrennt am Ende unter „Hinweise (kein Audit)“.
**Vorgehen:** Code in fünf Bereichen gelesen (Speicher V3, Indizierung/Live-Überwachung, App-Zustand/Erkennung, Fehlerbericht/Netz/Datenschutz, Oberfläche/Modelle). Jeder Befund ist am Code gegengeprüft. Die mit **(ausprobiert)** markierten habe ich zusätzlich ausgeführt. Befunde 1–53 sind nicht wiederholt. Wo ein Befund eine frühere Behebung unvollständig nennt, steht das dabei.
**Ausprobiert:** Debug-Build plus alle Unit-Tests (`xcodebuild test`, eigener DerivedData-Ordner): Build grün, **586 von 590 Tests grün, 4 rot** (Auswertung in Nr. 109). Den Datenschutzfilter (`ReportScrubber`) habe ich als Kopie mit echten Beispielzeilen ausgeführt (Nr. 54/55).
**Nummerierung:** fortlaufend ab **54**. Spur-Spalte bleibt leer, bis Claude eine Aufgabe in `TODO.md` anlegt.
**Hinweis:** Gültige Schwere, Korrekturen an Lösungsvorschlägen und neue Befunde 110–132 stehen in der **Zweitprüfung** weiter unten. Bei Abweichung gilt die Zweitprüfung.

## Übersicht

| Nr | Schwere | Bereich | Kurz | Konfidenz |
|----|---------|---------|------|-----------|
| 54 | Hoch | Datenschutz | Scrubber: Apostroph/Anführungszeichen im Pfad → Ordnernamen im Klartext im Bericht | sicher (ausprobiert) |
| 55 | Hoch | Datenschutz | Leak-Wächter vor dem Senden greift nie (`\/` im JSON, `knownNames` leer) | sicher (ausprobiert) |
| 56 | Hoch | Speicher/Live | Live-Rename: nicht gefundener Elternordner gilt als Wurzel → falsche Zeile umbenannt | sicher |
| 57 | Hoch | Speicher | `apply`: fileID-Verschiebung entfernt gleichnamige Zeile des Zielordners → UNIQUE-Fehler oder Leiche | sicher |
| 58 | Hoch | Speicher | `finishIndexing` löscht verschwundene Einträge auch bei Abbruch → Favoriten/Nutzer-Meta weg | sicher |
| 59 | Hoch | Indizierung | Abgebrochener Abgleich wird `.pending` → nächster Lauf überspringt alle Ebenen | sicher |
| 60 | Hoch | Erkennung | `requestedIndex` bleibt nach Lauf gesetzt → „Ja“ nach „Nein“ startet nichts | sicher |
| 61 | Hoch | Erkennung | Reprobe bei App-Aktivierung setzt Entscheidung bekannter Medien mit Status `error` zurück | sicher |
| 62 | Hoch | Speicher/App | Medium-Zeile: Lesen → `await` → ganze Zeile zurückschreiben überschreibt Indexer-Felder | wahrscheinlich |
| 63 | Hoch | Speicher | FAT/exFAT: `matchGoneCandidate` durchsucht pro neuem Eintrag das ganze Medium | sicher |
| 64 | Hoch | Live | Neues FSEvent bricht laufenden Flush ab → `CancellationError` → Voll-Abgleich | wahrscheinlich |
| 65 | Hoch | Oberfläche | ⌘A in großen Ordnern: quadratischer Aufwand in Body, Commit, Kontextmenü | sicher |
| 66 | Mittel | Live | Zurückgestellter Flush wird aus dem Quiet-Task nie neu eingeplant | sicher |
| 67 | Mittel | Speicher | `beginIndexing`: Token bleibt nach Schreibfehler hängen → Watcher und Wartung blockiert | sicher |
| 68 | Mittel | Speicher | Regel-Abgleich versteckt nur den Treffer, nicht dessen Inhalt; Zähler nach Bereinigung veraltet | sicher |
| 69 | Mittel | Speicher | Ordner-Verschiebung über fileID: Tiefe der Unterzeilen wird nicht angepasst | sicher |
| 70 | Mittel | Live | Live-Rename-Paar ohne Identitätsprüfung (Löschen + Anlegen = Umbenennung) | sicher |
| 71 | Mittel | App | `normalizeInterruptedIndexingStatuses` läuft zur Laufzeit und setzt aktive Läufe zurück | sicher |
| 72 | Mittel | Erkennung | Aufwachen: Doppel-Abgleich, Status eines laufenden Laufs überschrieben | sicher |
| 73 | Mittel | Erkennung | Dialog-Entscheidung nach dem Abziehen → Medium „verbunden“; Panel bleibt offen | sicher |
| 74 | Mittel | App | Beenden verwirft entprellte Schreibvorgänge (Einstellungen, Medium-Entscheidung) | sicher |
| 75 | Mittel | API-Queue | Offline-Fehlversuch → 1 h Backoff, 60-s-Timer stoppt; „online sofort senden“ greift nicht | sicher |
| 76 | Mittel | Absturz | Absturzschreiber nicht signalsicher (Heap, nach Dialog sogar `FileManager` im Handler) | sicher |
| 77 | Mittel | Indizierung | Stall-Erkennung greift bei hängendem Lesen nicht; Leser läuft nach Abbruch weiter | sicher |
| 78 | Mittel | Erkennung/Live | Umbenennen des Volumes wird nicht verarbeitet → veralteter `mountPath` | wahrscheinlich |
| 79 | Mittel | Live | `ChangeWatcher.stop` leert Zustand erst nach `await` → toter Watcher bei Pause an/aus | wahrscheinlich |
| 80 | Mittel | Oberfläche | Favorit umschalten in Suche/Favoriten: Liste veraltet, zweiter Klick wirkt gleich | sicher |
| 81 | Mittel | Oberfläche | Spaltenansicht: jede Ordnerzeile wird als „wird indiziert“ abgedunkelt | sicher |
| 82 | Mittel | Oberfläche | Online/Offline der Treffer ist ein Schnappschuss (Favoriten-Filter falsch) | sicher |
| 83 | Mittel | Oberfläche | Sortieren nach Datum/Medium/Pfad/Status sortiert nur die ersten 500 Namen-Treffer | sicher |
| 84 | Mittel | Oberfläche | Pfeiltasten in anderer Spalte → Auswahl mit falschem Spaltenindex | wahrscheinlich |
| 85 | Mittel | Oberfläche | Popover-Suche: pro Tastendruck volle Suche plus Zählung, nie abgebrochen | sicher |
| 86 | Mittel | Oberfläche | Favoriten-Tabelle nicht lazy und ohne Limit | sicher |
| 87 | Mittel | App/Protokoll | Zweitinstanz schreibt Protokoll/Absturzmarker vor der Einzelinstanz-Prüfung | sicher |
| 88 | Niedrig | Absturz | SIGTERM: sofortiges Ende ohne Aufräumen, trotzdem als „sauber“ protokolliert | sicher |
| 89 | Niedrig | API-Queue | Versions-Check-Zeilen ohne Entdoppelung verdrängen Absturzberichte | sicher |
| 90 | Niedrig | API-Queue | Outbox-Datei wird gelöscht, auch wenn die Übernahme scheitert (Nr. 30 unvollständig) | sicher |
| 91 | Niedrig | Datenschutz | Unified Log: Suchbegriffe und Fehlertexte als `.public` | sicher |
| 92 | Niedrig | App | Nach Store-Fehler läuft der Pausentimer nicht mehr ab | sicher |
| 93 | Niedrig | Versions-Sperre | Lücken: API nie erreicht, Uhr zurückgestellt, 0 Medien = „frisch“ | sicher |
| 94 | Niedrig | Indizierung | `readFolderWithRetry` wiederholt auch Pause/Halt und hängt Chunks doppelt an | sicher |
| 95 | Niedrig | Indizierung | Pause in der Zählphase speichert Teilsumme als `scanTotal` | sicher |
| 96 | Niedrig | Indizierung | `getattrlistbulk` mit `PACK_INVAL_ATTRS`, Offsets nur bei gesetztem Bit | sicher (je Dateisystem) |
| 97 | Niedrig | Indizierung | Hot Path: Muster je Eintrag neu geparst, Pfad je Eintrag standardisiert | sicher |
| 98 | Niedrig | Oberfläche/Cache | `IndexRepository.replaceStore` löscht Generationen (Nr. 29/51 unvollständig) | sicher |
| 99 | Niedrig | Speicher | `commitPendingMetaIfNeeded`: Reentrancy über `await` verdoppelt/verliert Deltas | sicher |
| 100 | Niedrig | Speicher | Suche, Folgeseiten: Sortierung binär auf Seite 1, natürlich im Cursor (latent) | sicher |
| 101 | Niedrig | Speicher | Kein Schutz, wenn eine ältere App eine neuere Datenbank öffnet | sicher |
| 102 | Niedrig | Indizierung | `parentsFor` verschluckt Lesefehler → Lauf endet als `.indexed` | sicher |
| 103 | Niedrig | Oberfläche | NSTableView-Pfad (≥ 50k): Zeilen bei gleichen IDs nicht neu aufgebaut | wahrscheinlich |
| 104 | Niedrig | Oberfläche | Fest verdrahtete deutsche Texte; Datum/Größe/Zahl nach System- statt App-Sprache | sicher |
| 105 | Niedrig | Oberfläche | Pausentimer leitet die gewählte Dauer aus der Restzeit ab | sicher |
| 106 | Niedrig | Oberfläche | Popover-Höhe bei „Keine Treffer“ fest auf eine Zeile | wahrscheinlich |
| 107 | Niedrig | Oberfläche | `DelayedLoadingState` wird während der Body-Auswertung verändert | wahrscheinlich |
| 108 | Niedrig | Build | Compiler-Warnungen, die in Swift 6 Fehler sind (Actor-Aufruf synchron, captured var) | sicher |
| 109 | Niedrig | Tests | 4 rote Tests: Testisolation (globaler Schalter, geteilter Cache) und Zeitgrenzen | sicher (ausprobiert) |

**Empfohlene Reihenfolge:** zuerst 54/55 (Datenschutz, vor 0.4 zwingend). Danach 56–59 (Datenverlust/falscher Index), dann 60/61 (Entscheidung geht verloren), 62/64 (stille Drift), 63/65 (Last). 59, 71 und 72 haben dieselbe Wurzel (Status eines Laufs wird von außen überschrieben) und sollten in einer Aufgabe zusammen gelöst werden. Ebenso 56 und 70 (Live-Rename) sowie 54, 55 und 91 (Protokoll-Datenschutz).

Pfade unten relativ zu `diskindex/diskindex/`.

---

## Befunde (Hoch)

### 54. Scrubber: Apostroph oder Anführungszeichen im Pfad → Namen im Klartext im Bericht — **Hoch**

- **Wo:** `App/ReportScrubber.swift` Z. 14 (`text`, Muster `(?:/Volumes|/Users|~)[^\n\"']*`), Z. 20–36 (`scrubRemainder`). Pfad-Quellen im Datei-Protokoll: `App/DiskIndexLog.swift` Z. 126 (`lineBody = message + privateDetail`, Klartext in die Datei), z. B. `Recognition/MediumCoordinator.swift` Z. 290 („ausgehängt“, bei jedem Aushängen), `Indexing/ChangeWatcherEngine.swift` Z. 91/101/134/136 (bei jeder Live-Änderung). Übernahme in den Bericht: `App/IssueTracker.swift` (`logTail(100)` → `prepare`).
- **Was:** Aus `ausgehängt id=X /Volumes/Jon's Passport/Clients/Acme Corp` wird `…‹path depth=2›'s Passport/Clients/Acme Corp`. **Ausprobiert** mit einer Kopie des Scrubbers. Der Rest geht im Klartext an `diskarchive.app`. Volumes wie „Jon's Passport“ sind häufig.
- **Warum:** Die Pfad-Regex endet am ersten `'`/`"`. `scrubRemainder` ersetzt den Rest nur, wenn er „unübliche“ Zeichen enthält; reines ASCII bleibt stehen. Außerdem übernimmt `scrubRemainder` alles zwischen `‹…›` ungeprüft (Z. 30): Ein Ordner namens `‹Kunde X›` geht als vermeintliches Profil durch.
- **Vorschlag:** (1) `privateDetail` nicht mehr ins Datei-Protokoll schreiben (dort nur Länge/Tiefe bzw. Medium-ID). Der volle Pfad nur in `os_log` als `.private`. (2) Hilfsweise die Pfad-Regex bis Zeilenende laufen lassen (`[^\n]*`). (3) In `scrubRemainder` nur die selbst erzeugten Profilmuster `‹(path|name|query) [^‹›]*›` durchlassen.
- **Test:** `ReportScrubber.text` mit `/Volumes/Jon's Passport/Clients/Acme Corp`, `/Volumes/A/My "Best" Photos`, `/Volumes/A/‹Kunde Acme›/x`. Im Ergebnis darf weder `Passport` noch `Acme` noch `Photos` stehen.
- **Konfidenz:** sicher (ausprobiert).

### 55. Leak-Wächter vor dem Senden greift praktisch nie — **Hoch**

- **Wo:** `App/ReportScrubber.swift` Z. 38–48 (`leakCategory`); `App/IssueTracker.swift` (`JSONSerialization … options: [.sortedKeys]`, `knownNames = { [] }` wird nirgends gesetzt, Aufruf in `send`).
- **Was:** `JSONSerialization` schreibt `/` als `\/`: `{"logTail":["\/Volumes\/KUNDE\/geheim"]}`. `leakCategory` sucht `"/Volumes/"` und liefert `nil` (**ausprobiert**). Der Namensabgleich läuft immer gegen eine leere Liste. Die zweite Schutzschicht ist wirkungslos, also gehen die Reste aus Nr. 54 ungebremst hinaus.
- **Vorschlag:** Den Body dekodieren und alle String-Werte rekursiv prüfen, oder mit `.withoutEscapingSlashes` serialisieren. `knownNames` beim Start mit den Mediennamen aus der DB füllen (nicht auf dem Main-Thread).
- **Test:** Payload mit `/Volumes/X/geheim` direkt in die Queue legen, `flush` → Zeile `blocked:leak=path`, kein Request beim Mock. Der bestehende Test (`IssueTrackerTests` Z. 212–217) prüft nur von Hand geschriebenes, unescaptes JSON.
- **Konfidenz:** sicher (ausprobiert).

### 56. Live-Rename: nicht gefundener Elternordner wird als Medienwurzel behandelt — **Hoch**

- **Wo:** `Storage/V3/DirectoryWriterV3.swift` Z. 225–227 (`applyLivePathRename`) und Z. 290–302 (`folderID(segments:)` liefert `nil` für „Wurzel“ **und** „nicht gefunden“). Paare entstehen in `Indexing/ChangeWatcher.swift` (`pendingItemEvents`, Z. 251–259) **vor** Matcher-, Tiefen- und Scope-Filter.
- **Was:** Scan-Tiefe 2, Umbenennung `/A/B/C/readme.txt` → `readme2.txt` (C nicht indiziert). `fromParentID = nil`, also wird `readme.txt` **in der Wurzel** gesucht und umbenannt, mit `depth = 4`; `shiftDescendantDepths` verschiebt bei Ordnern den ganzen Unterbaum. Neu gelesen wird nur `/A/B`, die Wurzel bleibt falsch (Stempel-Abkürzung). Gleiches gilt für Ziele in `.Trashes/501/…` oder in ausgeschlossenen Ordnern. Dann wird die Zeile in die Wurzel verschoben, und die Engine findet für `.Trashes/501` keine Elternzeile → nach drei Versuchen Voll-Abgleich. Mit gesetzter Scan-Tiefe markiert der nächste Regel-Abgleich den verschobenen Unterbaum als „zu löschen“ und löscht ihn nach 1 h samt Favoriten.
- **Nebenbefund:** War die Zeile `status = gone`, wird `delta` verworfen (`_ = delta`, ca. Z. 283); `fileCount` bleibt zu niedrig.
- **Vorschlag:** `folderID` dreiwertig (`.root` / `.found(id)` / `.missing`); bei `.missing` auf einer Seite `return false`. In `ChangeWatcher.flush` die Item-Events vor dem Paaren durch dieselbe Scope-Logik wie `directoryToReread` filtern; Eltern aus Paaren nur übernehmen, wenn sie im Scope liegen. Delta über `commitMediumMeta` mitschreiben.
- **Test:** Wurzel enthält `readme.txt`; Events entfernen `/Vol/X/Y/Z/readme.txt` und legen `…/Z/readme2.txt` an, Z nicht im Index → Wurzelzeile bleibt `readme.txt`.
- **Konfidenz:** sicher.

### 57. `apply`: fileID-Verschiebung entfernt die gleichnamige Zeile des Zielordners — **Hoch**

- **Wo:** `Storage/V3/DirectoryWriterV3.swift` Z. 105–123, Ursache Z. 121: `existingByName.removeValue(forKey: located.name)`. Betrifft APFS/HFS+ (`trustsFileID`).
- **Was:** P enthält `a.txt` (R1, fileID F1). Q/`a.txt` (R2, F2) wird nach P/`b.txt` verschoben (offline oder ohne Live-Paar). Beim Lesen von P findet `b.txt` über F2 die Zeile R2; Z. 121 entfernt den Schlüssel `a.txt`, also **R1**.
  - Kommt `a.txt` in der (zufälligen) Dictionary-Reihenfolge danach: `existingByName["a.txt"]` ist `nil`, `matchGoneCandidate` ist bei `trustsFileID` `nil` → `INSERT` → Verstoß gegen `items_identity` (`SchemaV3.swift` Z. 206) → ganze Transaktion scheitert. Watcher meldet `.needsFullReconcile`, der Voll-Lauf scheitert mit derselben Wahrscheinlichkeit erneut und endet mit `error`.
  - Ist P/`a.txt` gelöscht: R1 wird in `finalize` nicht als verschwunden markiert (nicht mehr in `existingByName`) und bleibt als Leiche sichtbar, der Stempel wird gespeichert.
- **Vorschlag:** Nur bei Umbenennung im selben Ordner entfernen: `if located.parentID == parentID { existingByName.removeValue(forKey: located.name) }`.
- **Test:** P {a.txt F1}, Q {a.txt F2}; neue Liste P {a.txt F1, b.txt F2}, 30-mal auf frischen DBs → kein Fehler. Variante P {b.txt F2} → R1 hat danach Status 2.
- **Konfidenz:** sicher.

### 58. `finishIndexing` löscht verschwundene Einträge auch bei abgebrochenem Lauf — **Hoch**

- **Wo:** `Storage/V3/IndexStoreV3.swift` Z. 534 (`deleteGoneItems` ohne Bedingung in `finishIndexing`); aufgerufen auch mit `.pending`/`.error` (`DirectoryIndexer.stop`, `failWrite`, Timeout-Pfad, `IndexingService.cancel` Z. 150).
- **Was:** Offline wird Ordner X mit Favoriten von Ebene 1 nach Ebene 3 verschoben. Beim Anschließen markiert der Abgleich auf Ebene 1 X samt Unterbaum als `gone`. Dann Pause, Auswerfen, Ruhezustand oder drei Lese-Timeouts → `finishIndexing(.pending)` → `deleteGoneItems` löscht X. Per CASCADE verschwinden `favorites`, `item_meta` (auch Nutzerwerte `source = 1`) und `item_checksum`. Der Folgelauf legt X auf Ebene 3 neu an, ohne Favoriten. Gegen die Regel „gelöscht am Ende des Laufs, nachdem Umbenennungen verbunden wurden“.
- **Vorschlag:** `deleteGoneItems` nur bei `status == .indexed`. Bei pending/error bleiben die Zeilen, `fetchByFileID`/`matchGoneCandidate` verbinden sie im Fortsetzungslauf.
- **Test:** Favorit in /X/f.txt, X nach /A/B/X verschieben, `shouldHalt` liefert `.pause` nach Ebene 1 → Favoriten-Zeile existiert noch; nach dem Folgelauf hängt der Favorit an /A/B/X/f.txt.
- **Konfidenz:** sicher.

### 59. Abgebrochener Abgleich wird `.pending` → nächster Lauf überspringt alle schon indizierten Ebenen — **Hoch**

- **Wo:** `Indexing/DirectoryIndexer.swift` Z. 524–526 (`stop()`: `.none, .pause, .cancel → .pending`), Z. 61 (`fullReconcile` nur bei `stored.indexStatus == .indexed`), Z. 63–69 (`startDepth = completedDepth + 1`); `Indexing/IndexingService.swift` Z. 150 und 157–159 (`cancel` schreibt `.pending` in DB und UI); `Recognition/MediumCoordinator.swift` Z. 217 (`.pending` → `requestIndex`). Auch der Sperr-Abbruch (`cancelAllActiveForVersionLock`) nutzt diesen Pfad.
- **Was:** Medium ist vollständig indiziert, beim Anschließen läuft der Abgleich. Ruhezustand, Auswerfen oder Pause → `.pending`. Beim nächsten Anschluss oder Aufwachen gilt der Lauf nicht als Abgleich und beginnt bei `completedDepth + 1`, also hinter der letzten Ebene. Er endet sofort als `.indexed`, **ohne Ebene 1…n neu zu lesen**. Änderungen, die anderswo gemacht wurden, fehlen dauerhaft. Dazu kommt: Offline-Status falsch („x % indiziert“), grüner Spinner und „indiziert“-Mitteilung ohne Grund.
- **Vorschlag:** Laufart merken (`storedBeforeRun.indexStatus == .indexed`). Bei `stop()`/`cancel()` eines Abgleichs `.indexed` zurückschreiben, der nächste Anschluss startet ohnehin einen Abgleich. Alternative: Meta-Flag „Abgleich offen“, das `fullReconcile` erzwingt. Mit Nr. 71/72 in einer Aufgabe lösen.
- **Test:** Medium `.indexed`, `completedDepth = 3`; Abgleich nach Ebene 1 pausieren → Status `.indexed`; Folgelauf liest Ordner der Ebenen 2 und 3 (`listCount > 0`).
- **Konfidenz:** sicher.

### 60. `requestedIndex` bleibt nach erfolgreichem Lauf gesetzt → „Ja“ nach „Nein“ startet nichts — **Hoch**

- **Wo:** `Recognition/MediumCoordinator.swift` Z. 20, `requestIndex` Z. 353–360 (`guard requestedIndex.insert(mediumID).inserted else { … return }`), `requestIndexingAfterDecision` Z. 366–369. Geleert wird nur in `volumeDisappeared` (Z. 291), `forget` (Z. 373) und `clearIndexRequest`, und das nur auf Ablehnungspfaden (`Indexing/IndexingService.swift` Z. 51/67/72). Aufruf aus `App/LiveWiring.swift` Z. 151–163.
- **Was:** Neuer Stick → „Indizieren“ → Lauf endet sauber. Später in Einstellungen/Details „Nein“, dann „Ja“ → Log „index bereits angefordert“, **kein Lauf, keine Überwachung**, kein Hinweis. Gleiches gilt für einen abgebrochenen Erstlauf. Erst Aus- und Einstecken hilft. Rest des Latch-Fixes aus Nr. 16.
- **Vorschlag:** In `IndexingService.finish` und `cancel(mediumUUID:)` `coordinator?.clearIndexRequest` aufrufen, oder das Set nur bis `runs[...] = token` (tatsächlicher Start) halten.
- **Test:** `applyChoice(allowIndexing: true)` → Lauf fertig → Entscheidung `.dontIndex` → `.index` → `service.start` wird erneut aufgerufen.
- **Konfidenz:** sicher.

### 61. Reprobe bei App-Aktivierung setzt die Entscheidung bekannter Medien zurück — **Hoch**

- **Wo:** `Recognition/MediumCoordinator.swift` `applicationDidBecomeActive` Z. 87–89 → `reprobeDeniedVolumes` Z. 278–285 → `storeAndPresent(…, status: .pending, openDialog: true)` Z. 236–251, Z. 242: `if status == .pending { existing.decision = .undecided }`.
- **Was:** Jedes angeschlossene Medium mit `indexStatus == .error` wird beim nächsten Fensteröffnen oder Dock-Klick zurückgesetzt. Den Status `error` schreibt der Indexer bei Wurzel-, Ebenen- oder Stapelfehler (`DirectoryIndexer.swift` Z. 300/344/498). Folgen: Entscheidung `.undecided`, Status `.pending`, **Erkennungsdialog für ein längst bekanntes Medium**. Ein vollständiger Index wird ebenfalls `.pending` (nach „Ja“ folgt eine Fortsetzung statt Abgleich, siehe Nr. 59).
- **Vorschlag:** Reprobe nur für Medien mit `decision == .undecided` über `storeAndPresent` führen. Für entschiedene Medien `indexStatus` auf `.pending`/`.indexed` (je nach `lastIndexedAt`) setzen und den passenden Lauf anstoßen.
- **Test:** Medium `.index` + `.error` in `mounted` → `applicationDidBecomeActive()` → `decision` bleibt `.index`, kein Eintrag in `pendingNewMediumDecisionIDs`.
- **Konfidenz:** sicher.

### 62. Medium-Zeile: Lesen → `await` → ganze Zeile zurückschreiben überschreibt Indexer-Felder — **Hoch**

- **Wo:** `Storage/V3/MediumCodecV3.swift` `update` ab Z. 182 (alle Spalten inkl. `indexStatus`, `fileCount`, `folderCount`, `lastIndexedAt`), `writeMeta` ab Z. 224 (`completedDepth`, `lastEventID`, `fsEventsUUID`). Aufrufer mit getrennten Transaktionen: `App/AppState+IndexChanges.swift` `writeMedium` (ca. Z. 460–472), `Recognition/MediumCoordinator.swift` `connectKnown` (Z. 154 → 170, Z. 204), `volumeDisappeared` (Z. 295–297), `applyChoice` (Z. 326–340), `App/AppState+Media.swift` `normalizeInterruptedIndexingStatuses` (Z. 298–300).
- **Was:** Während eines Laufs schaltet der Nutzer Favorit, Kapazitätsanzeige oder Entscheidung um, oder das Medium wird ausgeworfen. Ablauf: `writeMedium` liest S0, dann committet der Indexer einen Stapel bzw. `completeLayer`/`finishIndexing` (S1), dann schreibt `writeMedium` S0 zurück. Zähler, `completedDepth`, FSEvents-Cursor und `indexStatus = .indexing` fallen zurück. Kommt das nach `finishIndexing`, bleibt die DB auf `.indexing`. Watcher-Deltas (`fileCount + ?`) heilen nie, neu gezählt wird nur bei `completeLayer`/Reconcile.
- **Vorschlag:** Gezielte UPDATEs je Feldgruppe: Nutzerfelder (`isFavorite`, `decision`, `showAbsoluteCapacity`, `autoIndexPaused`, `type`), Erkennungsfelder (`name`, Kapazität, `lastSeenAt`). Indexer-Felder nur über eigene Setter. Mindestens Lesen/Ändern/Schreiben in **einem** `pool.write` (`updateMedium(uuid:mutate:)`).
- **Test:** Hook zwischen Lesen und Schreiben von `writeMedium`, dort `commitMediumMeta(delta: +100)` → `fileCount` enthält +100.
- **Konfidenz:** wahrscheinlich (Zeitfenster je Stapel; beim Auswerfen während eines Laufs typisch).

### 63. FAT/exFAT/NTFS: `matchGoneCandidate` durchsucht pro neuem Eintrag das ganze Medium — **Hoch** (Medien ohne fileID)

- **Wo:** `Storage/V3/DirectoryWriterV3.swift` Z. 409–424 (Abfrage `WHERE storageID=? AND status=2 AND isFolder=?`), Aufruf aus `apply` Z. 151; `incomingPartialDigest` Z. 511–520 liest Dateien **innerhalb** von `pool.write`.
- **Was:** Ohne `trustsFileID` läuft für **jeden** neuen Eintrag eine Abfrage, deren Plan `SEARCH i USING INDEX items_children (storageID=?)` über alle Einträge des Mediums geht, auch wenn es keine verschwundenen gibt. Gemessen (Prüfer, Schemakopie): ca. 4,5 ms je Aufruf bei 200.000 Zeilen, also beim Erstindex mit 200.000 Einträgen etwa 7–8 min zusätzlich, bei 1 Mio. mehrere Stunden. Zusätzlich hält das Lesen der Teil-Prüfsumme vom USB-Medium die Schreibsperre.
- **Vorschlag:** Neue Migration (reine Erweiterung, schemakonform): `CREATE INDEX items_gone ON items(storageID, isFolder) WHERE status = 2`. Pro Writer einmal `EXISTS`-Vorabtest; ohne gone-Zeilen den Aufruf überspringen. Teil-Prüfsummen vor der Transaktion berechnen.
- **Test:** Abfrageplan-Test zeigt `items_gone`; Erstindex FAT mit 50.000 Dateien unter Zeitgrenze (Messwerkzeug aus 0.3).
- **Konfidenz:** sicher.

### 64. Neues FSEvent bricht laufenden Flush ab → `CancellationError` → Voll-Abgleich — **Hoch**

- **Wo:** `Indexing/ChangeWatcher.swift` Z. 270 und 276 (`quietTasks[mediumID]?.cancel()`), Z. 278–283 (der Quiet-Task führt `flush` selbst aus und bleibt in `quietTasks` eingetragen), Z. 315 (`engine.processPending`); `Indexing/ChangeWatcherEngine.swift` Z. 128–137 (jeder Fehler aus `applyDirectories` → `.needsFullReconcile`).
- **Was:** Nach 2 s Ruhe läuft ein Flush und liest Ordner. Durch Actor-Reentrancy kommt währenddessen ein neues Event an, und Z. 276 bricht **genau diesen laufenden** Task ab. GRDB wirft bei abgebrochenem Task `CancellationError` (Prüfer: `DatabasePool` mit `Task.checkCancellation()`), die Engine wertet das als Schreibfehler → Voll-Abgleich des ganzen Mediums mit gestopptem Watcher. Bei großen USB-HDDs dauert das Minuten bis Stunden, und es wiederholt sich bei jeder normalen Schreibaktivität.
- **Vorschlag:** Timer und Flush trennen: Der Quiet-Task setzt sich vor dem Flush aus `quietTasks` aus (vgl. Nr. 66) und ruft einen pro Medium serialisierten Flush auf (`flushInFlight` + Folge-Flush). Laufende Flushes nur in `stop` abbrechen. In der Engine `CancellationError` gesondert behandeln: `pending` zurücklegen, kein Voll-Abgleich.
- **Test:** `BlockingListAccess` blockiert `listDirectory` im ersten Flush; zweites Event; freigeben → kein `onFullReconcile`, beide Ordner gelesen.
- **Konfidenz:** wahrscheinlich (Codepfad sicher; Häufigkeit hängt vom Timing ab).

### 65. ⌘A in großen Ordnern: quadratischer Aufwand — **Hoch**

- **Wo:** `Models/ColumnSelection.swift` Z. 11 (`ids: [UUID]` als Array), Z. 102 (`selection.ids.contains(item.id)` je Zeile); `Views/ColumnBrowser/ColumnBrowserView.swift` Z. 479 (`selectedIDs: Set(items.filter { isRowSelected… })`, bei jedem Body), Z. 580 (`commit`), Z. 635–637 (`contextTargets`), Z. 788 (`multipleSelectionItems`, je Body) jeweils `ids.compactMap { id in items.first { $0.id == id } }`; `Models/ColumnSelection.swift` Z. 152–165 (`IgnoreBatch.applying`, `contains` auf Arrays), Z. 200 (`ContextMenuPlan.multiple`, je Menü-Hover).
- **Was:** Bei 50.000 Einträgen und ⌘A sind das ca. 1,25 Mrd. UUID-Vergleiche je Body-Auswertung, und der Body wird bei jedem Fortschritts-Tick von `appState.media` neu ausgewertet. Die Spaltenansicht hängt (Beachball), während einer Indizierung immer wieder. „Dateinamen ignorieren“ für 50.000 Ziele ist ebenfalls O(n²).
- **Vorschlag:** `ColumnSelection` führt zusätzlich ein `Set<UUID>` (oder einmal je Body `let selected = Set(selection.ids)`); in `commit`/`multipleSelectionItems`/`contextTargets` einmal ein Dictionary `id → item` bauen; `IgnoreBatch` über ein Set deduplizieren.
- **Test:** 50.000 künstliche Items, `selectAll`, `commit` und `selectedIDs` messen (Ziel unter 50 ms).
- **Konfidenz:** sicher (Komplexität).

---

## Befunde (Mittel)

### 66. Zurückgestellter Flush wird aus dem Quiet-Task nie neu eingeplant — **Mittel**

- **Wo:** `Indexing/ChangeWatcher.swift` Z. 278–283 (Quiet-Task setzt `quietTasks[mediumID]` nicht auf `nil`), Z. 289–291 und 329–332 (`scheduleDeferredFlush`), Z. 344 (`guard quietTasks[mediumID] == nil else { return }`).
- **Was:** Ist beim Flush ein Lauf aktiv (`isIndexingActive`) oder liefert die Engine `.deferred`, soll `scheduleDeferredFlush` neu planen. Der Guard sieht aber den eigenen, gerade laufenden Task und tut nichts. Nach Laufende stößt nichts den Flush an; Live-Änderungen bleiben liegen, bis zufällig das nächste Event kommt. Der Cursor-Timer speichert die Event-ID trotzdem weiter. Watcher und Lauf überlappen tatsächlich, z. B. über `resumePausedRuns` und den Ruhezustand.
- **Vorschlag:** Im Quiet-Task vor `flush` `self.quietTasks[mediumID] = nil` (wie Z. 349 in `scheduleDeferredFlush`).
- **Test:** `flushDeferredWhileIndexingSkipsApply` erweitern: danach `isIndexingActive = { _ in false }`, ohne neues Event warten → `listCount > 0`.
- **Konfidenz:** sicher.

### 67. `beginIndexing`: Token bleibt nach Schreibfehler hängen — **Mittel**

- **Wo:** `Storage/V3/IndexStoreV3.swift` Z. 485 (`indexingToken[mediumUUID] = token` **vor** `pool.write`); `Indexing/DirectoryIndexer.swift` Z. 47–54 gibt bei Fehler `.error` zurück, ohne `finishIndexing`.
- **Was:** Wirft `beginIndexing` (Medium inzwischen vergessen → `unknownMedium`, `CancellationError`, IO-Fehler), bleibt das Token gesetzt. `hasActiveIndexingToken` ist dauerhaft wahr → `ChangeWatcherEngine` antwortet für dieses Medium immer `.deferred` (Live steht). `hasAnyActiveIndexingToken` ist wahr → Leerlauf-Wartung läuft bis zum Neustart nie.
- **Vorschlag:** Im Fehlerfall `if indexingToken[mediumUUID] == token { indexingToken[mediumUUID] = nil }` und erneut werfen.
- **Test:** `deleteMedium`, dann `beginIndexing` (wirft) → `hasAnyActiveIndexingToken() == false`.
- **Konfidenz:** sicher.

### 68. Regel-Abgleich versteckt nur den Treffer, nicht dessen Inhalt; Zähler nach Bereinigung veraltet — **Mittel**

- **Wo:** `Storage/V3/IndexStoreV3.swift` `reconcileScopeToStatus` ca. Z. 724–785 (`scope.shouldHide(name:depth:)` je Zeile), `purgeMarkedItems` ca. Z. 788–824.
- **Was:** Neuer Ausschluss `node_modules` oder „Unsichtbare Dateien“ an: Nur der Ordner selbst bekommt Status 1, alles darin bleibt `status = 0`. Bis zur Bereinigung (1 h) findet die Suche die Inhalte, Favoriten zeigen sie, und `applyReconcileMeta` zählt sie mit. Danach löscht `purgeMarkedItems` per Kaskade, zählt aber nicht neu: `storages.fileCount` bleibt um den Unterbaum zu hoch, bei Offline-Medien unbegrenzt lange.
- **Vorschlag:** Beim Verstecken eines Ordners den Unterbaum per rekursivem CTE auf 1 setzen (wie `markSubtreeGone`); beim Wieder-Einblenden zurücksetzen und neu bewerten. `purgeMarkedItems` sammelt die betroffenen `storageID`s und ruft `commitMediumMeta(forceRecount: true)`.
- **Test:** `node_modules` mit 3 Dateien, Ausschluss setzen, abgleichen → Suche liefert 0; nach `purgeMarkedItems` gilt `fileCount == COUNT(status=0)`.
- **Konfidenz:** sicher.

### 69. Ordner-Verschiebung über fileID: Tiefe der Unterzeilen wird nicht angepasst — **Mittel**

- **Wo:** `Storage/V3/DirectoryWriterV3.swift` Z. 105–123 mit `relocateRow` (ab ca. Z. 379); `shiftDescendantDepths` wird nur im Live-Weg aufgerufen (ca. Z. 281). Stempel-Abkürzung Z. 74.
- **Was:** /A/B/M (Tiefe 3) wird offline oder ohne Live-Paar in die Wurzel verschoben. M bekommt Tiefe 1, behält aber seinen `contentStamp`. Beim Lesen von M greift die Stempel-Abkürzung, die Kinder behalten Tiefe 4, Enkel 5. Folgen: falsche Ebenen in `folders(depth:)`; Suche, `childCount` und Favoriten filtern sie mit `depth <= maxDepth` weg; der Regel-Abgleich markiert sie zum Löschen, die Bereinigung löscht sie samt Favoriten.
- **Vorschlag:** Im fileID-Zweig bei Ordnern mit `located.depth != parent.childDepth` `shiftDescendantDepths(folderID:by:)` aufrufen.
- **Test:** /A/B/M/x/y.txt indizieren, M in die Wurzel verschieben, neu laufen lassen → x Tiefe 2, y Tiefe 3; mit `maxDepth = 3` bleibt y sichtbar.
- **Konfidenz:** sicher.

### 70. Live-Rename-Paar ohne Identitätsprüfung — **Mittel**

- **Wo:** `Indexing/LiveRenamePairs.swift` Z. 46–53 (genau ein „weg“ und ein „da“ ergeben ein Paar); `Storage/V3/DirectoryWriterV3.swift` Z. 211–282 (`applyLivePathRename` übernimmt die Zeile, ohne Inode/Größe des Ziels zu prüfen).
- **Was:** Nutzer löscht `alt.jpg` und kopiert innerhalb von 2 s `neu.jpg` in denselben Ordner. Aus ItemRemoved und ItemCreated wird ein Paar, die Zeile `alt.jpg` wird zu `neu.jpg`. Beim Nachlesen (APFS) unterscheidet sich die fileID, aber `existingByName["neu.jpg"]` existiert, also nur `UPDATE … fileID`. **Favorit und Nutzer-Meta wandern dauerhaft auf die fremde Datei.** Nicht durch Nr. 35/52 abgedeckt.
- **Vorschlag:** Bei `trustsFileID` `stat(toPath).st_ino == row.fileID` verlangen. Bei FAT gleiche Größe plus Teil-Prüfsumme, falls gespeichert. Sonst `false`. Für das Paaren nur `itemRenamed` auf beiden Seiten zulassen.
- **Test:** Removed `/A/alt.jpg`, Created `/A/neu.jpg` mit anderem Inode → `alt` gone, `neu` neue Zeile ohne Favorit.
- **Konfidenz:** sicher.

### 71. `normalizeInterruptedIndexingStatuses` läuft zur Laufzeit und setzt aktive Läufe zurück — **Mittel**

- **Wo:** `App/AppState+Media.swift` `loadStoredMedia` Z. 262–284 ruft immer `normalizeInterruptedIndexingStatuses` (Z. 287–309, inkl. `mediumLiveSyncIDs.removeAll()` Z. 289). Laufzeit-Aufrufer: `AppState.pruneNow` Z. 398, `AppState+RuleReconcile.resumeAfterRuleReconcile` Z. 107, `AppState+IndexChanges.flushIndexChange` Z. 329.
- **Was:** Erstlauf läuft → Nutzer ändert eine Ignorier-Regel oder die Tiefe → Regel-Abgleich endet → `loadStoredMedia` → das laufende Medium wird in UI und DB auf `.indexed` (nach Ebene 1 ist `lastIndexedAt` gesetzt) bzw. `.pending` gesetzt. `IndexingService.publish` setzt `.indexing` danach nie wieder (`if $0.indexStatus != .indexed`). `canReindex` wird wahr. `mediumLiveSyncIDs` wird geleert, also kann die DB-Wartung während eines Live-Flushs starten.
- **Vorschlag:** Normalisierung nur einmal beim Start, vor den Koordinator-Läufen. Zur Laufzeit Medien mit aktivem Lauf (`IndexingService.isRunActive`/`hasAnyActiveIndexingToken`) überspringen, `mediumLiveSyncIDs` nicht leeren.
- **Test:** Lauf aktiv → `resumeAfterRuleReconcile()` → Status bleibt `.indexing`, DB unverändert.
- **Konfidenz:** sicher.

### 72. Aufwachen: jedes Medium wie neu eingesteckt → Doppel-Abgleich, Statusüberschreibung — **Mittel**

- **Wo:** `Recognition/MediumMonitor.swift` Z. 31–35 (`didWake` → `.appeared` für alle Volumes); `Recognition/MediumCoordinator.swift` `connectKnown` Z. 201–216; parallel `App/AppDelegate.swift` `observeSleep` (ca. Z. 244–251) → `IndexingService.pauseChanged`/`resumePausedRuns` (Z. 284–303) und `restartWatchersAfterWake`.
- **Was:** (a) Pro Medium starten nach jedem Aufwachen zwei Abgleiche: `resumePausedRuns` → `start`, und `connectKnown` → `onReconcileRequested` → `start`. Der zweite landet in `rerunAfterFinish` (Z. 56) und läuft danach noch einmal **komplett**. (b) Läuft beim Aufwachen ein Erst- oder Neu-Lauf, überschreibt `connectKnown` Z. 201–205 den DB-Status `.indexing` mit `.indexed`/`.pending`; die UI verliert „indexing“ (wie Nr. 71).
- **Vorschlag:** Wake-Re-Emit nur für Pfade, die nicht schon mit gleicher Identität in `mounted` stehen; oder `connectKnown` bei bereits verbundenem Medium auf Metadaten beschränken. Statuskorrektur nur bei `!service.isRunActive(id)`.
- **Test:** Medium verbunden und indiziert → `didWake` → genau ein `service.start`; Lauf aktiv → `didWake` → DB-Status bleibt `.indexing`.
- **Konfidenz:** sicher (Mechanik); dass der Nachlauf voll läuft: wahrscheinlich.

### 73. Dialog-Entscheidung nach dem Abziehen → Medium „verbunden“; Panel bleibt offen — **Mittel**

- **Wo:** `Recognition/MediumCoordinator.swift` `applyChoice` Z. 347 (`publish(stored, connection: .connected)` bedingungslos); `volumeDisappeared` Z. 287–319 ruft `AppWindowPresenter.syncNewMediumPanels` nicht auf.
- **Was:** Dialog offen → Stick abziehen → Panel bleibt → „Indizieren“ → das Medium steht als `.connected` in Menü, Dashboard und „Im Finder anzeigen“, bis zum nächsten Ein- oder Ausstecken. Beim Wieder-Anschließen ist `wasOffline` falsch, der Favoriten-Hinweis fehlt (Z. 172).
- **Vorschlag:** In `applyChoice` `volume(for:) != nil ? .connected : .offline`. In `volumeDisappeared` nach `publish(.offline)` `syncNewMediumPanels` aufrufen.
- **Test:** `requestDialog` → `.disappeared` → `onNewMediumChoice(id, true, true)` → `connectionStatus == .offline`, Panel geschlossen.
- **Konfidenz:** sicher.

### 74. Beenden verwirft entprellte Schreibvorgänge — **Mittel**

- **Wo:** `App/AppState+IndexChanges.swift` `prepareForTermination` Z. 60–86: Z. 70–71 brechen `pendingMediumWrites` ab, ohne zu schreiben; `flushSettings` Z. 49–57 schreibt per `Task { await persistAppSettingsNow() }` (Z. 55). Aufruf aus `applicationWillTerminate`; der Prozess endet direkt danach.
- **Was:** Der Task läuft nach `applicationWillTerminate` nicht mehr. Die letzte Änderung an Einstellungen oder Medium geht verloren. Kritisch: „Nicht indizieren“ kurz vor ⌘Q → beim nächsten Start wird wieder indiziert.
- **Vorschlag:** Synchron schreiben (`store.pool` ist `nonisolated`): `try? pool.write { SettingsPersistence.writeAppSettings($0, snapshot) }`, ausstehende Medium-Felder ebenso mit gezielten UPDATEs (siehe Nr. 62). Alternativ `.terminateLater` und `reply(toApplicationShouldTerminate:)` nach dem `await`.
- **Test:** Einstellung bzw. Entscheidung ändern → sofort `prepareForTermination()` → neuen Store öffnen → Wert gespeichert.
- **Konfidenz:** sicher.

### 75. API-Queue: Offline-Fehlversuch → 1 h Backoff, Timer stoppt — **Mittel**

- **Wo:** `App/IssueTracker.swift` `IssueRetry.delay` Z. 146–149 (1 h, 2 h, … 24 h), `send`-`catch` (ca. Z. 455: `scheduleRetry(… "offline")`); `Storage/V3/ApiQueuePersistence.swift` `isDue` Z. 77–82; `App/ApiQueueReachability.swift` Z. 25 (Flush nur beim Wechsel zu online) und Z. 45–52 (Timer nur bei *fälliger* Arbeit).
- **Was:** Absturzbericht offline eingereiht → Sofortversuch scheitert → `attempts = 1`, fällig erst in 1 h → `hasDueWork` false → 60-s-Timer stoppt. Netz kommt nach 5 min → `onFlush` holt nur fällige Zeilen → nichts. Danach stößt bis zum 24-h-Versions-Check, Neustart oder nächsten Netzwechsel nichts an. Verfehlt „online sofort leeren, offline alle 60 s“ (Roadmap 0.3.1). Folge der Behebung von Nr. 33/37.
- **Vorschlag:** Bei `URLError` wie `.notConnectedToInternet`, `.networkConnectionLost`, `.cannotFindHost`, `.cannotConnectToHost`, `.timedOut` nur `lastTryAt` setzen, `attempts` nicht erhöhen (oder `info = "offline"`, und `isDue` ignoriert den Backoff dafür). Timer läuft, solange nicht blockierte Zeilen existieren.
- **Test:** Mock-Session liefert erst `notConnectedToInternet`, dann 201; danach `onFlush` → Zeile gelöscht, ohne die Uhr vorzustellen.
- **Konfidenz:** sicher.

### 76. Absturzschreiber nicht signalsicher — **Mittel**

- **Wo:** `App/DiskIndexLog.swift` `writeRing` Z. 403–427 (Z. 407 String-Interpolation + `Array` auf dem Heap, Z. 422 `Array(repeating:)`), Z. 404 `if crashFD < 0 { openCrashFile() }`, `openCrashFile` Z. 429–439 (`FileManager`, `String(contentsOf:)` mit 64 KB); `consumeCrashMarker` Z. 247–250 setzt `crashFD = -1` (nach jedem beantworteten Dialog). SIGTERM-Pfad (ca. Z. 202–213).
- **Was:** Nach einem beantworteten Absturzdialog ist der Deskriptor zu. Der nächste Absturz in derselben Sitzung führt **im Signal-Handler** `FileManager`, Datei-Lesen und Objective-C aus. Auch im Normalfall wird im Handler Speicher reserviert. Bei Heap-Korruption oder wenn der abstürzende Thread einen malloc-Lock hält: Bericht verloren oder Hänger. Widerspricht „signalsicher“.
- **Vorschlag:** Header-Puffer je Signal und Frame-Puffer einmalig in `start(installHandlers:)` anlegen (statischer Speicher). In `writeRing` nur `guard crashFD >= 0 else { return }`, nie öffnen. `consumeCrashMarker` öffnet die Datei nach dem Verschieben sofort neu (außerhalb des Signalkontexts). SIGTERM-Pfad nur mit vorab angelegten Bytes.
- **Test:** Nach `acknowledgeCrashDialog()` existiert `crash-last.txt` wieder (64 KB), Debug-Accessor `crashFD >= 0`.
- **Konfidenz:** sicher (Allokation/FileManager im Handler); Folge wahrscheinlich.

### 77. Stall-Erkennung greift bei hängendem Lesen nicht; Leser läuft nach Abbruch weiter — **Mittel**

- **Wo:** `Indexing/DirectoryIndexer.swift` `directoryChunks` Z. 549–580 (Zeitprüfung Z. 564 nur beim Eintreffen eines Chunks; innerer `Task` wird nie abgebrochen; kein `continuation.onTermination`); `Indexing/BulkDirectoryReader.swift` `chunkedStream` Z. 58–78 (Leser auf globaler Queue ohne Abbruch).
- **Was:** (a) `getattrlistbulk` blockiert (defekte SD-Karte): Es kommt nie ein Chunk, also nie `DirectoryReadStalled`; die 30-s-Wächterzeit und `IndexRunGuard` greifen nicht, der Lauf hängt unbegrenzt. (b) Ein gültiger, aber langsamer erster Chunk (> 30 s; beim FileManager-Fallback kommt er erst nach dem ganzen Ordner) wird verworfen; nach 4 Versuchen gilt der Ordner als „nicht lesbar“. (c) Nach Abbruch/Auswerfen liest der Hintergrund-Leser den Ordner mit offenem fd zu Ende. Verdacht: Das kann das Auswerfen mit „wird verwendet“ blockieren.
- **Vorschlag:** Watchdog-Timer, der `finish(throwing:)` auch ohne Chunk auslöst; Stall-Zeit ab letztem Lebenszeichen messen. `onTermination` setzt ein Abbruch-Flag, das `readStreaming` zwischen den `getattrlistbulk`-Aufrufen prüft, und bricht den inneren Task ab. Optional bei `willUnmount` den Lauf abbrechen.
- **Test:** Fake-Access, dessen Stream nie etwas liefert → `DirectoryReadStalled` nach `directoryStallTimeout`.
- **Konfidenz:** sicher für (a)/(c) als Codefakt; Auswerfen-Blockade: Verdacht.

### 78. Umbenennen des Volumes wird nicht verarbeitet — **Mittel**

- **Wo:** `Recognition/MediumMonitor.swift` Z. 12–37 (nur Mount, WillUnmount, Unmount, Wake; kein `NSWorkspace.didRenameVolumeNotification`); `Indexing/ChangeWatcher.swift` Z. 262–263 und 357 (Präfixprüfung gegen gespeichertes `mounts[id]`), Stream ohne `kFSEventStreamCreateFlagWatchRoot` (ca. Z. 453), deshalb ist der `rootChanged`-Zweig (Z. 233–237) toter Code.
- **Was:** Stick im Finder umbenennen: `/Volumes/USB` wird zu `/Volumes/Neu`. Watcher-Events werden verworfen. Der nächste Lauf liest den alten Pfad → ENOENT an der Wurzel → `.error` samt Fehlerdialog (und über Nr. 61 danach Entscheidung zurückgesetzt). `didUnmount` mit neuem Pfad findet `mediumByPath` nicht, das Medium bleibt „verbunden“.
- **Vorschlag:** `didRenameVolumeNotification` (`NSWorkspaceVolumeOldURLKey`/`NSWorkspaceVolumeURLKey`) als `MediumEvent`: Pfadschlüssel im Coordinator umbiegen, Watcher `stop`/`start` mit neuem `VolumeInfo`. `WatchRoot` setzen.
- **Test:** Coordinator mit Rename-Event → `volume(for:)` liefert neuen Pfad; Unmount mit neuem Pfad setzt das Medium offline.
- **Konfidenz:** wahrscheinlich.

### 79. `ChangeWatcher.stop` leert Zustand erst nach `await` — **Mittel**

- **Wo:** `Indexing/ChangeWatcher.swift` Z. 138–153 (Z. 150 `await saveCursor`, erst danach Z. 151–152 `mounts`/`volumes = nil`); `pauseChanged` Z. 155–157 erzeugt unserialisierte Tasks; `applyPause` Z. 159–185.
- **Was:** Pause an und gleich wieder aus: Task A stoppt Medium m (`tasks = nil`) und wartet auf den DB-Schreibvorgang. Task B startet m (`tasks`, `mounts` gesetzt). A läuft weiter und setzt `mounts[m] = nil`. Ergebnis: `isWatching` ist wahr, aber alle Events werden verworfen, bis zum nächsten Aushängen. Spätere `start`-Aufrufe sind No-Ops (`tasks != nil`).
- **Vorschlag:** In `stop()` den Zustand synchron leeren (Cursor vorher in eine lokale Variable). `applyPause` serialisieren und nach dem `await` erneut `globalAutoIndexPaused` prüfen.
- **Test:** Store mit verzögertem `recordEventCursor`, `pauseChanged` an/aus → `isWatching` und Event → `listCount > 0`.
- **Konfidenz:** wahrscheinlich.

### 80. Favorit umschalten in Suche/Favoriten: Liste veraltet, zweiter Klick wirkt gleich — **Mittel**

- **Wo:** `Models/ObjectContextTarget.swift` Z. 40 (`isFavorite` als Schnappschuss); `App/AppState+Favorites.swift` Z. 13–19 (`isFavorite(_:)` liest für Dateien nur `target.isFavorite`), Z. 31–33 (`next = !target.isFavorite`, nur `indexRepository.setFavoriteLocally`); `Indexing/IndexRepository.swift` Z. 103–118 (keine `generation`-Erhöhung); `Storage/V3/IndexStoreV3.swift` ca. Z. 631 (`emit(.counts)` → nur `reloadMedium`); `Views/Favorites/FavoritesView.swift` Z. 58–61 (`favoriteRequest` ändert sich nicht).
- **Was:** In „Favoriten“ Rechtsklick → Favorit abwählen: DB-Zeile gelöscht, Zeile bleibt violett in der Liste. Erneuter Klick: `next` ist wieder `false`, nichts passiert. In der Suche umgekehrt: Der zweite Klick setzt erneut „an“.
- **Vorschlag:** Nach dem Umschalten `favoriteObjects` und `searchMatch.items[i].item.isFavorite` lokal anpassen, oder `reloadFavoritesIfVisible()` + `runSearch` auslösen. Im Kontextmenü den aktuellen Zustand aus dieser Quelle lesen, nicht aus dem Ziel.
- **Test:** `reloadFavorites`, `toggleFavorite(.fromSearchResult(fav))` → `favoriteObjects` ohne den Eintrag; zweiter Aufruf setzt ihn wieder.
- **Konfidenz:** sicher.

### 81. Spaltenansicht: jede Ordnerzeile wird als „wird indiziert“ abgedunkelt — **Mittel**

- **Wo:** `Views/ColumnBrowser/ColumnBrowserView.swift` `rowOpacity` Z. 198–211, Z. 209: `folderOpenState(columnIndex:medium:)` **ohne** `folderName`/`folderListedAt`/`folderUnreadable`; `Models/ColumnFolderOpenState.swift` Z. 46–52 liefert bei `folderListedAt == nil` und `decision == .index` immer `.pendingIndex`. `iconColor` (Z. 178–196) übergibt die Werte korrekt.
- **Was:** Bei jedem Medium mit Entscheidung „Ja“ sind alle nicht markierten Ordnerzeilen innerhalb der Scan-Tiefe auf 0,55 abgedunkelt, auch vollständig indizierte. Ein echter „wird indiziert“-Ordner ist nicht mehr unterscheidbar. Das ist ein Logikfehler (falscher Zustand), nicht nur Optik. Seit dem ersten Commit vorhanden.
- **Vorschlag:** `folderName: item.name, folderListedAt: item.listedAt, folderUnreadable: item.unreadable` übergeben; Zustand einmal je Zeile berechnen und für Farbe und Deckkraft nutzen.
- **Test:** Extrahierte Funktion: Ordner mit `listedAt != nil` → Deckkraft 1; `listedAt == nil` bei laufender Indizierung → 0,55.
- **Konfidenz:** sicher.

### 82. Online/Offline der Treffer ist ein Schnappschuss — **Mittel**

- **Wo:** `Models/SearchIndex.swift` Z. 91–97 und 156 (`isOnline` beim Laden eingefroren); `Views/Favorites/FavoritesView.swift` Z. 18–20 (Filter auf `$0.isOnline`), Z. 58–61; `Views/Search/SearchView.swift` Z. 46–61; `Views/Search/ObjectResultsTable.swift` Z. 200 (Chip aus `result.isOnline`). Aushängen (`MediumCoordinator` Z. 287–319) aktualisiert die Listen nicht.
- **Was:** Favoriten offen, Stick abziehen: Zeilen zeigen weiter „Online“; mit Filter „Offline“ fehlen genau die Favoriten dieses Sticks. Umgekehrt beim Anstecken ohne Indexänderung (Sperre, „Nicht indizieren“).
- **Vorschlag:** `isOnline` beim Rendern/Filtern aus `appState.medium(with:)?.connectionStatus` ableiten, oder den Verbindungsstatus in `favoriteRequest`/`searchRequest` aufnehmen.
- **Test:** `favoriteObjects` setzen, Medium per `updateMedium` auf `.offline` → gefilterte Menge `.offline` enthält den Eintrag.
- **Konfidenz:** sicher.

### 83. Sortieren nach Datum/Medium/Pfad/Status sortiert nur die ersten 500 Namen-Treffer — **Mittel**

- **Wo:** `Views/Search/ObjectResultsTable.swift` Z. 96–124 (`sortedResults`/`SearchSort.sorted`, im Client); `Models/SearchIndex.swift` Z. 46/68 (`pageLimit = 500`, keine Folgeseiten); `Storage/V3/IndexStoreV3+Reading.swift` Z. 229 (`ORDER BY i.slug, i.id LIMIT ?`).
- **Was:** Filter „Bilder“ mit 30.000 Treffern, Klick auf „Datum“: Oben stehen die neuesten der alphabetisch ersten 500, nicht die neuesten insgesamt. Kein Hinweis.
- **Vorschlag:** Sortierspalte und -richtung an `store.search` übergeben (`ORDER BY modifiedAt …` usw., Index `items_modified` existiert) und neu abfragen. Bis dahin Client-Sortierung nur bei `itemCount <= pageLimit`.
- **Test:** 600 Treffer, neuester heißt „zzz“ → Datum absteigend liefert ihn zuerst.
- **Konfidenz:** sicher.

### 84. Pfeiltasten in anderer Spalte → Auswahl mit falschem Spaltenindex — **Mittel**

- **Wo:** `Models/ColumnSelection.swift` `move` Z. 71–82 (`guard let column = focusColumnIndex`, danach `replace(id:column:)`); Aufruf `Views/ColumnBrowser/ColumnBrowserView.swift` Z. 621–626 mit `visible` der **fokussierten** Spalte.
- **Was:** Auswahl in Spalte 0, Fokus wechselt (Tab/Klick auf Leerfläche) in Spalte 1, ↓: Die Auswahl enthält eine ID aus Spalte 1, aber `focusColumnIndex = 0`. Detailspalte und „Im Finder anzeigen“ fehlen; ein späterer Filterwechsel in Spalte 0 verwirft die Auswahl.
- **Vorschlag:** `move(step:extend:visible:column:)` mit `column.columnIndex`; bei abweichender Spalte neue Auswahl in dieser Spalte beginnen.
- **Test:** `replace(id: a, column: 0)`, dann `move(…, visible: col1, column: 1)` → `focusColumnIndex == 1`.
- **Konfidenz:** wahrscheinlich (Mechanik sicher; Häufigkeit des Zustands offen).

### 85. Popover-Suche: pro Tastendruck volle Suche plus Zählung, nie abgebrochen — **Mittel**

- **Wo:** `MenuBar/MenuBarPopoverView.swift` Z. 30–32 (`onChange(of: popoverSearchText)` → `schedulePopoverSearch()` ohne Debounce); `App/AppState+IndexChanges.swift` Z. 238–245 (unstrukturierter `Task`, nie gecancelt); `Models/PopoverSearch.swift` Z. 47–54 (`SearchIndex.matching` mit Standard `withCount: true`).
- **Was:** „rechnung“ tippen: 8 parallele Suchen plus Zählungen, gerade die kurzen Präfixe über große Mengen. Ergebnisse kommen spät, die CPU ist während der Eingabe ausgelastet. Die Ergebnisse stimmen (Generationsprüfung), nur Last und Verzögerung.
- **Vorschlag:** Task in `AppState` halten, bei neuer Eingabe `cancel()`, ca. 150 ms Debounce; Seite mit `withCount: false`, Zahl getrennt und abbrechbar nachreichen.
- **Test:** 5 schnelle Eingaben → höchstens eine Zählabfrage.
- **Konfidenz:** sicher.

### 86. Favoriten-Tabelle nicht lazy und ohne Limit — **Mittel**

- **Wo:** `Views/Search/ObjectResultsTable.swift` Z. 81–91 (`ScrollView { VStack { ForEach(rows) … } }`, je Zeile ein `RightClickCatcher`-NSView); `Models/SearchIndex.swift` Z. 134–159 und `Storage/V3/IndexStoreV3+Reading.swift` Z. 281–291 (`favoriteObjects` ohne `LIMIT`); Z. 98/190 lesen `appState.media` je Zeile bzw. je Body.
- **Was:** Nach „⌘A → Favorit“ in einem großen Ordner (z. B. 20.000) werden alle Zeilen und NSViews auf einmal gebaut, bei jedem Indizierungs-Tick erneut. Die Favoritenansicht hängt.
- **Vorschlag:** `LazyVStack`; Favoriten seitenweise wie die Suche (500 + Zählung); Mediennamen einmal als Dictionary übergeben.
- **Test:** 10.000 Favoriten-Fixture, Zeit bis zur ersten Darstellung messen.
- **Konfidenz:** sicher (Mechanik); Ausmaß wahrscheinlich.

### 87. Zweitinstanz schreibt Protokoll und Absturzmarker vor der Einzelinstanz-Prüfung — **Mittel**

- **Wo:** `App/AppDelegate.swift` Z. 37 (`DiskIndexLog.shared.start()`) vor Z. 45 (`ensureSingleInstance()`); `applicationWillTerminate` Z. 155–160 läuft auch bei `handedOff`; `App/DiskIndexLog.swift` Z. 72–86 (Marker-Auswertung, automatisches Senden, `consumeCrashMarker`), Protokoll-Handle ohne `O_APPEND`.
- **Was:** Jede kurzlebige Zweitinstanz (Dock/Spotlight auf laufende App, `SMAppService.register()` mit `RunAtLoad`) schreibt „previous run ended without clean exit“ (falsch) und „app terminate ok“ ins Protokoll der laufenden Instanz. Endet diese danach hart, hält der nächste Start den Lauf für sauber und überspringt `quick_check`. Beide Prozesse schreiben ohne `O_APPEND` → Zeilen überschreiben sich. Sonderfall: offener, unbeantworteter Absturzdialog plus „automatisch senden“ an → die Zweitinstanz sendet und verschiebt `crash-last.txt`, die die Erstinstanz offen hält; Doppelbericht möglich.
- **Vorschlag:** `ensureSingleInstance()` vor `DiskIndexLog.shared.start()`; bei `handedOff` in `applicationWillTerminate` nichts protokollieren und nichts abbauen; Protokoll mit `O_APPEND` öffnen.
- **Test:** Release-Build zweimal starten → Protokoll ohne Zeilen der Zweitinstanz, `crash-last.txt` unberührt.
- **Konfidenz:** sicher.

---

## Befunde (Niedrig)

### 88. SIGTERM: sofortiges Ende ohne Aufräumen, als „sauber“ protokolliert — **Niedrig**
- **Wo:** `App/DiskIndexLog.swift` Z. 116 (SIGTERM in der sigaction-Liste), Z. 189–195, ca. Z. 205 (schreibt „app terminate ok“), Z. 81 (Erkennung „sauber“).
- **Was:** Bei `kill`/launchd-bootout endet die App ohne `applicationWillTerminate`, Checkpoint und Indexer-Stopp, gilt aber als sauber → kein `quick_check` beim nächsten Start. Verdacht: Ausschalten des Autostarts im Login-gestarteten Lauf (`LaunchAtLogin.swift` Z. 71, `unregister()`) beendet die laufende App.
- **Vorschlag:** SIGTERM per `DispatchSource.makeSignalSource` auf `NSApp.terminate(nil)` umleiten; hilfsweise im Handler „app sigterm“ schreiben.
- **Konfidenz:** sicher (Verhalten); Verdacht (`unregister`).

### 89. Versions-Check-Zeilen verdrängen Absturzberichte — **Niedrig**
- **Wo:** `App/VersionCheckCoordinator.swift` Z. 83–90 (Sperrfrist 30 s, nur im Speicher); `App/IssueTracker.swift` Z. 403–418; `Storage/V3/ApiQueuePersistence.swift` Z. 47–60 (`trim` löscht die älteste Zeile jeder Art).
- **Was:** Ohne Netz oder bei 5xx kommt je Start bzw. Tag eine `versionCheck`-Zeile hinzu; bei 50 Zeilen wirft `trim` auch einen zugestimmten, noch nicht gesendeten Absturzbericht hinaus.
- **Vorschlag:** Höchstens eine offene `versionCheck`-Zeile; `trim` entfernt zuerst Nicht-Berichte.
- **Konfidenz:** sicher.

### 90. Outbox-Datei wird gelöscht, auch wenn die Übernahme scheitert — **Niedrig** (Nr. 30 unvollständig)
- **Wo:** `App/IssueTracker.swift` `migrateLegacyOutboxFiles` Z. 389–401 (`try? …enqueue`, danach bedingungslos `try? removeItem`); `Storage/V3/ApiQueuePersistence.swift` Z. 34 (`enqueue` kehrt bei Nicht-UTF-8 ohne Fehler zurück).
- **Was:** Ist die DB beim Start wieder kurz belegt (häufig nach einem Absturz), ist der Bericht weg. Übernahme nur in `start()`, nicht zur Laufzeit.
- **Vorschlag:** Datei nur nach erfolgreichem `enqueue` löschen; `enqueue` wirft bei Nicht-UTF-8; Übernahme auch in `flushOnce`.
- **Konfidenz:** sicher.

### 91. Unified Log: Suchbegriffe und Fehlertexte als `.public` — **Niedrig**
- **Wo:** `App/DiskIndexLog.swift` Z. 146–150 (`message` immer `privacy: .public`); `App/AppState.swift` Z. 19 (`ui("search query=…")`); Fehlertexte mit Pfaden über `localizedDescription`/`\(error)` (`ChangeWatcherEngine.swift` Z. 101/136, `DirectoryIndexer.swift` Z. 298/319/450).
- **Was:** Suchbegriffe und Ordnernamen stehen im Systemprotokoll (lesbar für Admins, in jedem sysdiagnose). Fehlerbericht nicht betroffen.
- **Vorschlag:** `message` standardmäßig `.private`, nur feste technische Präfixe öffentlich; Suchbegriff-Zeile im `os_log` weglassen.
- **Konfidenz:** sicher.

### 92. Nach Store-Fehler läuft der Pausentimer nicht mehr ab — **Niedrig**
- **Wo:** `App/AppDelegate.swift` `handleStoreFailure` (ca. Z. 302–308) → `appState.prepareForTermination()` bricht `pauseExpiryTask` ab; `schedulePauseExpiryCheck` (`AppState+Pause.swift` Z. 66–78) wird nach Retry nicht neu aufgerufen.
- **Vorschlag:** Eigener Abbau für Store-Fehler ohne Pause-/Settings-Teil, oder nach Neu-Verdrahtung `schedulePauseExpiryCheck()`.
- **Konfidenz:** sicher.

### 93. Versions-Sperre: Lücken — **Niedrig**
- **Wo:** `App/VersionLockEvaluator.swift` Z. 50–61; `App/VersionCheckCoordinator.swift` Z. 51–54.
- **Was:** (a) API nie erreicht (`apiLastSeen == nil`) → 30-Tage-Sperre greift nie. (b) Zurückgestellte Systemuhr hebt 60- und 30-Tage-Sperre auf. (c) Bestandsnutzer mit 0 Medien gilt als „frisch installiert“ → bei API ≥ 1.0 sofort dauerhaft gesperrt.
- **Vorschlag:** (a) `firstRunAt` speichern und dagegen prüfen. (b) Höchsten je gesehenen Zeitpunkt speichern, `max(now, letzter)`. (c) „Frisch“ nur über gespeichertes Installationsdatum.
- **Konfidenz:** sicher (Code); (c) berührt die Konzeptauslegung.

### 94. `readFolderWithRetry` wiederholt auch Pause/Halt und hängt Chunks doppelt an — **Niedrig**
- **Wo:** `Indexing/DirectoryIndexer.swift` Z. 460–482 (`catch` fängt alles), Z. 249–265.
- **Was:** Bei Pause wird der Ordner noch 3-mal mit 1 + 3 + 10 s Wartezeit gelesen. Bei Fehler mitten im Ordner werden die Chunks des ersten Versuchs erneut angehängt: `listingStamp` über Duplikate, `entriesCompleted` überhöht.
- **Vorschlag:** `DirectoryIndexInterrupted`/`CancellationError` sofort weiterwerfen; `folderEntries` je Versuch zurücksetzen.
- **Konfidenz:** sicher.

### 95. Pause in der Zählphase speichert Teilsumme als `scanTotal` — **Niedrig**
- **Wo:** `Indexing/DirectoryIndexer.swift` Z. 427 (`break` bei Halt), Z. 454–456 (`setScanTotal(total)`), Z. 63–69/187–189 (kein neues Zählen beim Fortsetzen).
- **Was:** Fortschritt steht nach dem Fortsetzen sofort bei 99 %.
- **Vorschlag:** Bei Halt nicht speichern; Meta-Flag „Zählung unvollständig“ → beim Fortsetzen neu zählen.
- **Konfidenz:** sicher.

### 96. `getattrlistbulk` mit `FSOPT_PACK_INVAL_ATTRS`, Offsets nur bei gesetztem Bit — **Niedrig**
- **Wo:** `Indexing/BulkDirectoryReader.swift` Z. 162 (Flag), Z. 217–260 (`parseBulkRecord`).
- **Was:** Mit dem Flag wird jedes angeforderte Attribut gepackt, auch ungültige. Liefert ein Dateisystem MODTIME nicht, wird `fileID` aus dem Zeitfeld gelesen und die Größe aus dem FILEID-Feld (manche FUSE-/Netz-Dateisysteme).
- **Vorschlag:** Offset immer um die Attributgröße erhöhen, Wert nur bei gesetztem Bit übernehmen.
- **Konfidenz:** sicher (Widerspruch zur man-page); Auslösung hängt vom Dateisystem ab.

### 97. Hot Path: Muster je Eintrag neu geparst — **Niedrig**
- **Wo:** `Indexing/IgnoreMatcher.swift` Z. 31–33 (`NamePattern.parse` je Eintrag und Muster); `Indexing/ArtifactRules.swift` Z. 29–31/53–55 (`lowercased()` je Muster, ca. 40× je Eintrag); `Indexing/DirectoryIndexer.swift` Z. 436 (`relativePathSegments` mit zwei URL-Standardisierungen je Eintrag, obwohl `parentPath` im Matcher ignoriert wird).
- **Vorschlag:** Muster einmal in `init` parsen; Namen einmal kleinschreiben, Artefakte über Set bzw. Präfix-/Suffixlisten; Pfad je Ordner statt je Eintrag.
- **Konfidenz:** sicher.

### 98. `IndexRepository.replaceStore` löscht Generationen — **Niedrig** (Nr. 29/51 unvollständig)
- **Wo:** `Indexing/IndexRepository.swift` Z. 60 (`loadGenerations.removeAll()`); `defer` des alten Loads (ca. Z. 208–211) räumt `loading`/`loadingTotals` des neuen Loads mit gleichem Schlüssel ab.
- **Was:** Ein Load gegen den alten Store besteht nach `replaceStore` die Token-Prüfung (0) und schreibt alte Daten/Fehler in den Cache. Nach `invalidate` beendet der alte Load den Ladezustand des neuen; ein dritter Load startet.
- **Vorschlag:** In `replaceStore` Generationen erhöhen statt löschen; im `defer` nur bei `loadGenerations[key] == loadToken` aufräumen.
- **Konfidenz:** sicher (selten).

### 99. `commitPendingMetaIfNeeded`: Reentrancy über `await` — **Niedrig**
- **Wo:** `Storage/V3/IndexStoreV3.swift` Z. 900–912 (Delta wird erst nach dem `await` genullt).
- **Was:** Zwei überlappende Aufrufe für dasselbe Medium zählen das Delta doppelt oder verlieren es; im reinen Live-Betrieb heilt das nie.
- **Vorschlag:** Vor dem `await` entnehmen und nullen, bei Fehler wieder addieren.
- **Konfidenz:** sicher (selten).

### 100. Suche, Folgeseiten: Sortierung binär auf Seite 1, natürlich im Cursor — **Niedrig** (latent)
- **Wo:** `Storage/V3/IndexStoreV3+Reading.swift` Z. 229 (`ORDER BY i.slug, i.id`) gegen Z. 460–471 (`COLLATE "natural"` im Cursor), genutzt in `visibleSearchHitIDs` Z. 489–503.
- **Was:** Bei mehr als einer Seite Doppelte/Lücken („img10“/„img9“). Heute nur mit `checksNames == true` erreichbar (`revealAll`, Tests).
- **Vorschlag:** Cursor ebenfalls binär.
- **Konfidenz:** sicher.

### 101. Kein Schutz, wenn eine ältere App eine neuere Datenbank öffnet — **Niedrig**
- **Wo:** `Storage/V3/SchemaV3.swift` Z. 71–82 (`openPool` → `migrator.migrate`; GRDB ignoriert unbekannte Migrationen).
- **Was:** Ein älterer Build öffnet und beschreibt still eine Datei mit neuerem Schema. README fordert „Schutz vor Rückschritt“ ab 0.4.
- **Vorschlag:** Vor `migrate` `try pool.read(migrator.hasBeenSuperseded)` prüfen und mit eigenem Fehler abbrechen (Fehlerdialog statt Öffnen).
- **Test:** Zeile `grdb_migrations('9.9-future')` einfügen → `openPool` wirft.
- **Konfidenz:** sicher.

### 102. `parentsFor` verschluckt Lesefehler → Lauf endet als `.indexed` — **Niedrig**
- **Wo:** `Indexing/DirectoryIndexer.swift` Z. 594 (`(try? await store.folders(...)) ?? []`), Z. 358–359 (`if next.isEmpty { break }`).
- **Was:** Ein DB-Lesefehler beendet die Ebenenschleife still; tiefere Ebenen bleiben ungelesen, Status `.indexed`.
- **Vorschlag:** Fehler weitergeben und über `failWrite` als `.error` beenden.
- **Konfidenz:** sicher (selten).

### 103. NSTableView-Pfad (≥ 50.000 Einträge): Zeilen bei gleichen IDs nicht neu aufgebaut — **Niedrig**
- **Wo:** `Views/ColumnBrowser/ColumnFolderTableView.swift` Z. 71–90 (`reloadData` nur bei `idsChanged`).
- **Was:** Live-Rename (ID bleibt) oder Favorit umschalten ändert die sichtbare Zeile nicht; das gespeicherte `contextTarget` ist veraltet (vgl. Nr. 80).
- **Vorschlag:** Inhalts-Fingerabdruck (Name, `isFavorite`, `listedAt`) vergleichen und sichtbare Zeilen neu laden.
- **Konfidenz:** wahrscheinlich.

### 104. Feste deutsche Texte; Datum/Größe/Zahl nach System- statt App-Sprache — **Niedrig**
- **Wo:** `Models/PopoverSearch.swift` Z. 79–81 („SPEICHERMEDIEN“, „DATEIEN“, „ORDNER“); `MenuBar/MenuBarPopoverView.swift` Z. 107 („ANGESCHLOSSEN“); `Views/Search/SearchFilterPopover.swift` Z. 36/68/108/190 (`Text(String)` verbatim, keine Katalogschlüssel). Formatierung: `ObjectResultsTable.swift` Z. 185, `ColumnBrowserView.swift` Z. 704/917 (`.formatted(date:time:)` ohne `L10n.locale()`), `DesignSystem/ByteCountFormatting.swift` Z. 9–13, `Models/Medium.swift` Z. 105, `Models/ColumnSelection.swift` Z. 147 (`String(count)` ohne Tausendertrenner).
- **Was:** In der englischen Oberfläche deutsche Überschriften; nach DE → EN bleiben „13. Okt. 2026“/„1,5 GB“; „50000 Objekte“ ohne Punkt. Die Hilfen `DisplayNumberFormat`/`IndexedDateFormatting` existieren bereits.
- **Vorschlag:** Schlüssel anlegen (`LayoutCopy`/`L10n`), überall `.locale(L10n.locale())` bzw. `DisplayNumberFormat.groupedInteger`.
- **Konfidenz:** sicher.

### 105. Pausentimer leitet die gewählte Dauer aus der Restzeit ab — **Niedrig**
- **Wo:** `MenuBar/PauseDurationMenu.swift` Z. 25–32 (`PauseSpan.matching`), Z. 157–162; `App/GlobalPause.swift` Z. 8–11 speichert die Spanne nicht.
- **Was:** „1 Stunde“ gewählt, nach ca. 21 min: Anzeige „30 Minuten“, und „30 Minuten“ ist gesperrt. „Bis morgen“ um 23:00 gewählt, nach Mitternacht: „1 Stunde“.
- **Vorschlag:** Gewählte `PauseSpan` in `GlobalPause` persistieren und anzeigen.
- **Konfidenz:** sicher.

### 106. Popover-Höhe bei „Keine Treffer“ fest auf eine Zeile — **Niedrig**
- **Wo:** `MenuBar/MenuBarPopoverLayout.swift` Z. 87–89 (`searchVerticalPadding * 2 + 20`); Text in `MenuBar/MenuBarPopoverSearchContent.swift` Z. 44–48 ohne `lineLimit`.
- **Was:** Lange Suchbegriffe brechen „Keine Treffer für …“ auf zwei Zeilen um; `clipsToBounds` schneidet die zweite ab.
- **Vorschlag:** `.lineLimit(1).truncationMode(.middle)` oder Höhe aus der gemessenen Größe.
- **Konfidenz:** wahrscheinlich.

### 107. `DelayedLoadingState` wird während der Body-Auswertung verändert — **Niedrig**
- **Wo:** `Views/ColumnBrowser/ColumnFolderContents.swift` Z. 43–49 (`hintVisible` ruft `syncDelayedState()` und `catchUpToClock()`, beide schreiben `@Observable`-Zustand).
- **Was:** Zusätzliche Invalidierung während des Renderns, mögliche Laufzeitwarnung; ein schnell erneuter Ladevorgang während der Mindestanzeige blendet den Hinweis mitten im Laden aus.
- **Vorschlag:** `hintVisible` rein lesend; Synchronisierung in `onChange`/`.task`, `catchUpToClock` per `TimelineView`.
- **Konfidenz:** wahrscheinlich.

### 108. Compiler-Warnungen, die in Swift 6 Fehler sind — **Niedrig**
- **Wo / Was** (aus dem Build-Log, **ausprobiert**):
  - `App/AppDelegate.swift` Z. 170: `appState.indexStore?.checkpoint()` ruft eine **actor-isolierte** Methode synchron vom Main Actor auf. Sie läuft damit ohne Actor-Isolation; heute harmlos, weil sie nur den (thread-sicheren) Pool nutzt.
  - `Storage/V3/IndexStoreV3.swift` Z. 210 und Z. 815: captured `var` in `@Sendable`-Closure (`freelistBefore`, `removed`).
  - `Storage/V3/IndexStoreV3.swift` Z. 219/223: `try? await pool.read { … } ?? freelistBefore` (`??` wirkt in der Closure auf einen Nicht-Optional; `freelistAfter` ist Optional und erscheint als „Optional(…)“ im Protokoll).
  - `App/AppSettingsRuntimeCache.swift` Z. 48: Main-Actor-Methode aus nonisolated-Kontext.
- **Vorschlag:** `checkpoint()` als `nonisolated func` markieren (der Pool ist `let`); Werte aus den Closures zurückgeben statt captured `var`; `(try? await pool.read {…}) ?? freelistBefore`; `loadLegacyPersisted` `nonisolated` machen. Ziel: Build ohne Warnungen.
- **Konfidenz:** sicher.

### 109. Vier rote Unit-Tests: Testisolation und Zeitgrenzen — **Niedrig** (ausprobiert)
- **Ergebnis Gesamtlauf:** 586/590 grün. Rot: `ItemIdentityTests/fatPartialDisambiguatesGoneCandidates`, `AutoSendToggleTests/autoSendPersistsInDatabase`, `ChangeWatcherTests/newFileAppearsAfterQuiet`, `ChangeWatcherTests/liveRenamePairMovesFolderAndShiftsChildDepth`.
- **Einzeln wiederholt:** Die drei letzten sind grün, `fatPartialDisambiguatesGoneCandidates` scheitert reproduzierbar **zusammen mit seiner Suite**, allein ist er grün.
- **Ursache 1:** `Storage/V3/DirectoryWriterV3.swift` Z. 16 `nonisolated(unsafe) static var partialMatchingEnabled` (globaler Schalter). `ItemIdentityTests.swift` Z. 166 (`sabotagePartialDisabledDoesNotReconnectAmbiguous`) setzt ihn auf `false`; die Suite ist nicht `.serialized`, die Tests verzahnen sich an `await`-Stellen → der Nachbartest läuft ohne Teil-Prüfsumme.
- **Ursache 2:** `AutoSendToggleTests` nutzen den globalen `AppSettingsRuntimeCache` und eine feste Wartezeit von 600 ms; unter Last verloren.
- **Ursache 3:** `ChangeWatcherTests` warten mit 800-ms-Grenze auf FSEvents; unter Last zu knapp.
- **Vorschlag:** Schalter als Parameter von `DirectoryWriterV3`/`IndexStoreV3` (Testeinstieg) statt global, oder betroffene Suiten `.serialized`. Runtime-Cache je Test injizieren. Warte-Grenzen auf Bedingung statt fester Zeit (bzw. großzügiger). Ein Testlauf ist nur aussagekräftig, wenn er unter Last stabil grün ist.
- **Konfidenz:** sicher (ausprobiert).

---

## Hinweise (kein Audit)

Konzept-, Layout- und Doku-Themen, die beim Lesen aufgefallen sind. Keine Code-Befunde, nur als Hinweis für Nutzer/Claude.

- **„Für dieses Medium merken“:** `rememberDecision` wird in `applyChoice` geschrieben, aber nirgends gelesen. README §2.3 beschreibt, dass der Dialog ohne Haken wieder erscheint. Es ist zu klären, ob das noch gilt.
- **README „Architektur“ (Stand 04.10.)** beschreibt noch das alte Schema (`index.sqlite`, `item`/`item_fts`, `removedAt`, Migrationen v1–v5, Ordner „Disk Index“). Gilt seit V3 nicht mehr.
- **Abgelaufene Pause beim Start** wird still beendet (ohne Mitteilung „Medien werden wieder indiziert.“). Es ist zu klären, ob das Konzept die Meldung auch hier erwartet.
- **Versions-Check-Takt:** `VersionCheckScheduler` schläft per `Task.sleep` (Uptime). Auf Laptops mit Ruhezustand ist das deutlich seltener als „alle 24 h“. Es ist zu klären, ob Kalenderzeit gemeint ist.
- **Login-Start und Fenster:** Beim Einschalten des Autostarts kann die per `RunAtLoad` gestartete Zweitinstanz `showMainWindow` an die laufende Instanz schicken. Das widerspricht „Anmeldung still“ (siehe Nr. 87).
- **„Verwerfen“ im Absturzdialog** löscht alle offenen Fehlerberichte, auch früher zugestimmte, noch nicht gesendete. Es ist zu klären, ob das gewollt ist.
- **Antwort 201 ohne JSON-`id`** gilt als Fehlschlag und wird erneut gesendet, auf dem Server entstehen dann Doppel. Das API-Verhalten ist mit der Server-Seite abzustimmen.

---

# Zweitprüfung 13.10.2026 — claude seitenweise

**Kennung:** `claude seitenweise` · **Datum:** 13.10.2026 (zweiter Durchlauf, gleicher Abend) · **Stand:** Commit `76b6a71`, Code unverändert seit dem Audit oben.
**Ziel:** Den Audit (54–109) unabhängig gegenprüfen und Lücken finden. Weil sich der Code nicht geändert hatte, war das kein bloßes Wiederholen. Drei neue Wege:
1. **Gegenprüfung:** Jeden Befund 54–109 mit neuen Prüfern gezielt zu widerlegen versucht (Guards an anderer Stelle? erreichbar? Schwere? Lösung nebenwirkungsfrei?).
2. **Nachgestellt:** In einer **Kopie** des Projekts im Scratchpad (Original unangetastet) Repro-Tests geschrieben und ausgeführt. Gegenprobe: dieselben Tests in einer zweiten Kopie mit den vorgeschlagenen Korrekturen.
3. **Lückensuche quer über alle Ordner:** zwei Themen, *Nebenläufigkeit/Lebensdauer* und *Datenintegrität entlang der Abläufe*.

**Ausprobiert:**
- **Repro-Suite `ReproAuditTests` (11 Tests, Swift Testing, `.serialized`):** gegen den Originalcode **11/11 rot**, mit den Korrekturen aus dem Audit **11/11 grün** (zweimal gelaufen, Ergebnisbündel selbst gegengeprüft). Belegt sind damit **56, 57 (beide Varianten), 58, 59, 60, 66, 67, 69, 70, 99**. Die Testdatei liegt nur im Scratchpad. Für Cursor kann sie bei Bedarf als Vorlage übernommen werden.
- **`ReportScrubber`** mit weiteren Beispielzeilen ausgeführt (54/55, neu 124).
- **Build-Log:** `-enable-upcoming-feature NonisolatedNonsendingByDefault` ist aktiv (über `SWIFT_APPROACHABLE_CONCURRENCY`). Das ist die Grundlage von 117–121.
- **NFC/NFD:** `URL(fileURLWithPath:).standardizedFileURL.path` macht aus `ä` = `c3 a4` die Form `61 cc 88`; Swift-`==` ist wahr, die Bytes nicht (Grundlage von 113).
- **Abfragepläne:** `sqlite3` auf nachgebautem Schema (63: 6 ms je Aufruf bei 200.000 Zeilen, mit Teilindex < 0,1 ms).
- **Hardlinks:** APFS liefert für Hardlinks dieselbe `ATTR_CMN_FILEID` (112).

**Ergebnis kurz:** **Kein Befund aus 54–109 ist widerlegt.** Sieben sind in der Schwere angepasst, vier gelten nur teilweise, und bei elf ist der Lösungsvorschlag zu korrigieren oder zu ergänzen. Das ist wichtig für das Briefing, vor allem 58 nur zusammen mit 59 und der falsche Erstvorschlag zu 75. Dazu kommen **23 neue Befunde (110–132)**, davon 5 Hoch.

## A. Urteile zu 54–109

„bestätigt“ = Mechanik und Erreichbarkeit am Code nachvollzogen; **„Repro“** = zusätzlich durch roten Test belegt. Spalte „Schwere gültig“ ersetzt die Schwere aus dem Audit.

| Nr | Urteil | Schwere gültig | Anmerkung der Zweitprüfung |
|----|--------|----------------|----------------------------|
| 54 | bestätigt (ausprobiert) | Hoch | Auch `O'Brien Backup`, `A"B/…`, `file:///Volumes/Jon's…`. URL-kodierte Pfade und Zeilenumbrüche werden erfasst. Mediennamen ohne Pfad loggt der Code nicht. `‹Kunde X›` geht nur außerhalb eines Pfads durch (heute theoretisch). |
| 55 | bestätigt (ausprobiert) | Hoch | Siehe Korrektur B-55. |
| 56 | **Repro** | Hoch | Wurzelzeile wird `readme2.txt`, `depth = 4`. Häufigster Auslöser: **jedes Löschen in den Papierkorb** (`X/f` → `.Trashes/501/f`) auf einem überwachten Medium endet im Voll-Abgleich. |
| 57 | **Repro** | Hoch | UNIQUE-Fehler in 14–16 von 30 Läufen; Leiche immer. Folge im Indexer: Ordner P gilt danach als „nicht lesbar“ und der Lauf endet **`.indexed`** (siehe 123), nur bei P = Wurzel `.error`. Häufig durch Finder „Beide behalten“. |
| 58 | **Repro** | Hoch | Siehe Korrektur B-58 (nur mit 59). |
| 59 | **Repro** | Hoch | Folgelauf liest **keinen** Ordner und endet `.indexed`. Siehe Korrektur B-59. |
| 60 | **Repro** | **Mittel** (statt Hoch) | Heilt auch nach Aufwachen/Neustart (`connectKnown` nutzt das Set nicht), „Neu indizieren“ umgeht es. Siehe B-60. |
| 61 | bestätigt | Hoch | Realistischster Weg: Zugriff verweigert → `.error` → Nutzer erteilt Freigabe → App wird aktiv → Entscheidung zurückgesetzt. Trifft auch gemerkte „Nein“-Medien. Ergänzung: bei `.dontIndex` nur Status setzen, keinen Lauf. |
| 62 | bestätigt | **Mittel** (statt Hoch) | Fenster real, aber Zähler/Tiefe heilen beim nächsten `completeLayer`, Ereignis-ID durch Wiedergabe. Keine Item-Daten verloren. |
| 63 | bestätigt (gemessen) | Hoch | Siehe B-63. |
| 64 | bestätigt | Hoch | GRDB 7.11.1 prüft Abbruch (`DatabasePool.swift` 815–825). Auch `stop()`/`handleStreamUnmount` brechen laufende Flushes so ab. Verdacht: Bei Unmount kann dann ein Voll-Abgleich auf das ausgeworfene Medium starten. |
| 65 | bestätigt | Hoch | Rechnung eher zu niedrig (zusätzlich `multipleSelectionItems` je Body). Die 50k-Tabellenschwelle hilft nicht (Z. 479 läuft immer). Ergänzung: Nach „Ignorieren“ für 50.000 Ziele stehen 50.000 Muster in `excludedPatterns`, und `ColumnFolderOpenState.resolve` baut je Zeile einen Matcher darüber. Obergrenze/Warnung für Batch-Ignorieren aufnehmen. |
| 66 | **Repro** | Mittel | — |
| 67 | **Repro** (Code), Folgen teilweise | **Niedrig** (statt Mittel) | `CancellationError` heilt über `cancel` → `finishIndexing` mit demselben Token. Bleibt nur bei echten Schreibfehlern bzw. gelöschtem Medium; nächster Lauf ersetzt das Token. |
| 68 | bestätigt | Mittel | — |
| 69 | **Repro**, aber **teilweise** | Mittel | Im **Indexer** heilt es (Chunk-Pfad umgeht die Stempel-Abkürzung). Der Fehler bleibt im **Watcher-Pfad** (nur `finalize: true`), z. B. beim Verschieben von 2+ Ordnern auf einmal. |
| 70 | **Repro** | Mittel | Die Inode-Prüfung ist der eigentliche Schutz; „nur `itemRenamed`“ reicht allein nicht (FSEvents fasst Flags zusammen). |
| 71 | bestätigt | Mittel | `beginIndexing` schreibt bei **jedem** Lauf `.indexing`, auch beim Abgleich. Siehe B-71. |
| 72 | bestätigt | Mittel | Wake-Re-Emit ist nur 1 s entprellt. Bei abgelaufener Pause läuft `resumePausedRuns` zweimal (didSet + `AppDelegate` Z. 248), also bis zu drei Startanfragen. (b) eher „wahrscheinlich“. |
| 73 | bestätigt | Mittel | Bei einem einzigen Medium bleibt das Panel sicher offen. |
| 74 | bestätigt | **Niedrig** (statt Mittel) | Fenster nur 500 ms; die Entscheidung im Erkennungsdialog schreibt `applyChoice` sofort. Betroffen nur Änderungen in Einstellungen/Details. Siehe B-74. |
| 75 | bestätigt | Mittel | **Erstvorschlag falsch**, siehe B-75. |
| 76 | bestätigt | Mittel | Auch `Self.name(for:)` (Interpolation) reserviert im Handler. |
| 77 | bestätigt | Mittel | (b) trifft auch den Bulk-Pfad (`isPackageKey` je Ordner). |
| 78 | bestätigt (wahrscheinlich) | Mittel | Kette „über 61 Entscheidung zurückgesetzt“ **streichen**: Der Reprobe prüft den alten Pfad und bekommt „denied“. Neu: Nach dem Aufwachen zeigen zwei Pfade auf dieselbe ID, `volume(for:)` liefert zufällig einen davon. WatchRoot hilft nur zusammen mit dem Rename-Event. |
| 79 | bestätigt | Mittel | `applyPause` stoppt zusätzlich Watcher, die Task B gerade gestartet hat. |
| 80 | bestätigt | Mittel | Auch Popover-Treffer betroffen. Besser lokal patchen statt `runSearch` (setzt Zähler/Seite zurück). |
| 81 | bestätigt | Mittel | `listedAt` wird befüllt (`DirectoryWriterV3` Z. 204), `iconColor` stimmt also. **Zusammen mit 126 beheben**, sonst bleibt die letzte Ebene „pending“. |
| 82 | bestätigt | Mittel | Auch `ObjectContextTarget.isMediumOnline`: „Im Finder anzeigen“ bleibt nach Wiederanstecken gesperrt. Ableitung über ein Dictionary je Body, nicht `medium(with:)` je Zeile. |
| 83 | bestätigt | Mittel | Auch **Name absteigend** ist falsch (zeigt den 500. zuerst). Nur Datum, Name und Medium sind in SQL sortierbar; Status/Pfad: Client-Sortierung nur bei `itemCount <= 500`, sonst Kopf deaktivieren. |
| 84 | bestätigt | **Niedrig** (statt Mittel) | Selten erreichbar (kein →, Zeilenklick setzt korrekt). |
| 85 | bestätigt | Mittel | — |
| 86 | bestätigt | Mittel | Z. 98 gilt nur in der Suche (mit `sort`). |
| 87 | bestätigt | Mittel | Schärfer: Nach dem Verschieben von `crash-last.txt` durch die Zweitinstanz schreibt die Erstinstanz spätere Abstürze in die verschobene Datei, die nie wieder erkannt wird. |
| 88 | bestätigt | Niedrig | `unregister` → launchd-bootout → SIGTERM ist plausibel, nicht ausprobiert. |
| 89 | bestätigt | Niedrig | Jeder Start fügt eine Zeile hinzu. |
| 90 | bestätigt | Niedrig | — |
| 91 | bestätigt | Niedrig | — |
| 92 | bestätigt | Niedrig | Heilt erst beim nächsten Aufwachen nach Ablauf oder beim Neustart. |
| 93 | **teilweise** | Niedrig | (a) wird durch die 60-Tage-Sperre gemildert; (b)/(c) bestätigt. |
| 94 | bestätigt | Niedrig | Indirekt gemessen: Eine Pause im Abgleich wird erst nach ca. 14 s wirksam (1 + 3 + 10 s). Duplikate werden in `apply` zusammengeführt. |
| 95 | bestätigt | Niedrig | Gleiches für die Hintergrund-Zählung. |
| 96 | bestätigt | Niedrig | Nur MODTIME → FILEID betroffen (DATALENGTH ist letztes Feld). |
| 97 | bestätigt | Niedrig | — |
| 98 | bestätigt | Niedrig | Realistisch: Ordner zeigt nach Store-Retry „nicht lesbar“ bis zur Invalidierung. Das `defer`-Problem gilt allgemein für `invalidate`. |
| 99 | **Repro** | **Mittel** (statt Niedrig) | Repro mit 40 parallelen Flushes: gespeichert 4.100 Dateien statt 200. Erreichbar über überlappende Flushes (Deferred-Task plus neuer Quiet-Task, 30-s-Inline-Flush). Auch `lastMetaCommitTime` vor dem `await` setzen. |
| 100 | bestätigt (latent) | Niedrig | — |
| 101 | bestätigt | Niedrig | Muss **vor** der ersten Schema-Erweiterung ausgeliefert sein. |
| 102 | bestätigt | Niedrig | — |
| 103 | bestätigt | Niedrig | Statt Fingerabdruck reicht `coordinator.items != items` (`IndexedItem` ist Equatable). |
| 104 | **teilweise** | Niedrig | Feste Texte und `String(count)` bestätigt. Datum folgt nach dem nächsten Start `AppleLanguages`, „bleibt deutsch“ gilt also nur bis zum Neustart. Trenner folgen der System-Region. |
| 105 | bestätigt | Niedrig | — |
| 106 | bestätigt (wahrscheinlich) | Niedrig | Umbruch ab ca. 25 Zeichen. |
| 107 | **teilweise** | Niedrig | Erneutes Laden während der Mindestanzeige ist **nicht** erreichbar (zwei getrennte Exemplare). Tatsächlicher Defekt: Die **400-ms-Mindestanzeige wirkt nie**, weil das Lade-Exemplar samt `@State` beim Ladeende verworfen wird; das führt zu Flackern knapp über 1 s. Lösung: ein Exemplar mit `isLoading` als Parameter. |
| 108 | bestätigt | Niedrig | Auch im Testziel Warnungen, die in Swift 6 Fehler wären (`IndexingFinishCancelTests` 170–224, `IssueTrackerTests` 283, `AppSettingsPersistenceTests` 39–43). Ziel „ohne Warnungen“ inkl. Testziel. |
| 109 | bestätigt | Niedrig | Die Repro-Suite nutzt `.serialized`, als Muster. |

## B. Korrekturen an Lösungsvorschlägen (für das Briefing verbindlich)

- **B-55:** `knownNames` **nicht** naiv mit Mediennamen füllen. Backtrace-Zeilen enthalten „Disk Archive“; ein Medium „Disk“ oder „Archive“ würde jeden Bericht dauerhaft blockieren (`markBlocked`). Nur dekodierte String-Werte prüfen, mit Wortgrenzen und Ausschlussliste (App-/Image-Namen). Für Pfade reicht `.withoutEscapingSlashes` plus Prüfung der dekodierten Werte.
- **B-58:** **Nur zusammen mit 59 umsetzen.** Allein ist die Korrektur wirkungslos: Der Fortsetzungslauf endet wegen 59 sofort `.indexed`, und `deleteGoneItems` löscht dieselben Zeilen dann trotzdem. Nebenwirkung der Korrektur: gone-Zeilen leben bis zum nächsten `.indexed`-Lauf (bei FAT mehr Kandidaten, daher 63 mit lösen).
- **B-59:** Schreibt `stop()` bei einem Abgleich `.indexed` zurück, liefert es heute auch `fresh.indexStatus = .indexed` an `IndexingService.finish`. Dann laufen „Indizierung abgeschlossen“, `onRunIndexed` (Watcher-Start, auch bei Pause) und die Wartung. `stop()` muss das Ergebnis **getrennt als unterbrochen** melden, auch wenn die DB `.indexed` erhält.
- **B-60:** Nur die erste Variante (in `finish` und `cancel` leeren). Die Alternative „nur bis zum Start halten“ verschlechtert die Lage: Doppelanfragen während eines Laufs landen in `rerunAfterFinish` und lösen einen zusätzlichen Voll-Abgleich aus.
- **B-63:** Im SQL `status = 2` als **Literal** schreiben, damit der Teilindex sicher greift. Den `EXISTS`-Vorabtest **nicht je Writer zwischenspeichern** (gone-Zeilen entstehen im `finalize` früherer Ordner desselben Aufrufs). Mit dem Index ist er überflüssig.
- **B-71:** „Einmal beim Start vor den Koordinator-Läufen“ widerspricht `MediumRecognitionStartup.swift` 31–39 (Koordinator startet absichtlich vor `loadStoredMedia`). Die Normalisierung gehört als SQL-`UPDATE` in das **Öffnen der Datenbank** (vor `wire`); zur Laufzeit gar nicht normalisieren.
- **B-74:** Synchron schreiben kann das Beenden bis zum Busy-Timeout (10 s) auf dem Main-Thread blockieren. Besser gezielte `UPDATE`s oder `.terminateLater`.
- **B-75:** „`attempts` nicht erhöhen“ hilft **nicht**: `delay(afterAttempt: 0)` = `2^max(0,-1)` h = **1 h**. `isDue` muss Offline-Fehlversuche ohne Wartezeit als fällig behandeln (`info = "offline"` → kein Backoff). Timer an „nicht blockierte Zeilen vorhanden“ koppeln. Zusammen mit 120 lösen, sonst öffnet jeder Tick einen neuen Pool.
- **B-81:** Zusammen mit 126.
- **B-83:** Siehe Tabelle (sortierbare Spalten in SQL, sonst Client-Sortierung nur bis 500).
- **B-101:** Vor der ersten Schema-Erweiterung ausliefern.

---

## C. Neue Befunde (110–132)

| Nr | Schwere | Bereich | Kurz | Konfidenz |
|----|---------|---------|------|-----------|
| 110 | Hoch | Speicher/Indizierung | FAT/exFAT/NTFS: Wiederverbinden nach Umbenennen/Verschieben (selbe oder höhere Ebene) greift praktisch nie → Favorit und Nutzer-Meta weg | sicher |
| 111 | Hoch | Live | Jede Änderung **innerhalb eines Pakets** (.photoslibrary, .app, .logicx) → Voll-Abgleich des Mediums | sicher |
| 112 | Hoch (Backup-Medien) | Speicher | Hardlinks teilen die fileID → eine Zeile je Inode, springt bei jedem Lauf zwischen den Pfaden | sicher (ausprobiert) |
| 113 | Mittel | Live | FSEvents-Pfade werden zu NFD; NFC-Namen werden in SQL nicht gefunden | sicher (ausprobiert) |
| 114 | Mittel | App | Bereinigungstermin („nach 1 Stunde“) wird nur beim Aufwachen geprüft, nie nach Zeit, nie beim Start | sicher |
| 115 | Mittel | App/Indizierung | Regeländerung während eines Laufs: Lauf arbeitet nach alten Regeln; Erweitern startet bei fertigen Medien keinen Lauf | sicher |
| 116 | Mittel | Erkennung | Zwei gleichzeitig angeschlossene Klone mit gleicher Identität → ein Medium, Einträge des anderen gelöscht | sicher (Mechanik) |
| 117 | Hoch | Erkennung/Nebenläufigkeit | `MediumAccess.probe` liest die Medienwurzel **auf dem Main-Thread**, bei jeder App-Aktivierung | sicher (Mechanik) |
| 118 | Mittel | Erkennung/Nebenläufigkeit | `MediumMonitor` fragt alle Volumes (auch Netz) auf dem Main-Thread ab (Start, Aufwachen) | wahrscheinlich |
| 119 | Mittel | Live/Nebenläufigkeit | `stat()` je Ereignispfad auf dem Main-Thread, Ergebnis fast immer verworfen | sicher (Mechanik) |
| 120 | Mittel | API-Queue/Nebenläufigkeit | Synchrone DB-Schreibzugriffe auf dem Main-Thread; `queuePool` wird nie gesetzt → neuer Pool je Aufruf | sicher |
| 121 | Mittel | Speicher/Nebenläufigkeit | Teil-Prüfsumme liest Mediendateien im Store-Actor bzw. unter der SQLite-Schreibsperre | sicher (Mechanik) |
| 122 | Mittel | Protokoll | Jede Protokollzeile `chmod` + `fsync` unter globalem Lock, 1–2 Zeilen je gelesenem Ordner | sicher (Mechanik) |
| 123 | Mittel | Indizierung | Schreibfehler im Chunk-Pfad gelten als Lesefehler → Ordner „nicht lesbar“, Lauf endet `.indexed` | sicher |
| 124 | Mittel | Fehlerbericht | Scrubber macht jede deutsche Protokollzeile mit Umlaut komplett unlesbar | sicher (ausprobiert) |
| 125 | Mittel | Oberfläche/Cache | Spalten-Cache verdrängt sichtbare Spalten → Auswahl und geöffneter Pfad gehen verloren | sicher |
| 126 | Mittel | Oberfläche | Scan-Tiefe 1–4: Ordner der letzten Ebene stehen dauerhaft auf „Wird indiziert“ | wahrscheinlich-hoch |
| 127 | Niedrig | Fehlerbericht | „Verwerfen“ im Absturzdialog löscht frühere, schon zugestimmte Berichte | sicher |
| 128 | Niedrig | Absturz | Kürzung der Aktionszeile auf 239 Bytes kann UTF-8 zerschneiden → Absturz nicht erkannt | sicher (selten) |
| 129 | Niedrig | Speicher | Umbenennen + neue Datei mit altem Namen: Ergebnis hängt von der Dictionary-Reihenfolge ab | sicher |
| 130 | Niedrig | Oberfläche | Popover: Gruppe „ORDNER“/„DATEIEN“ fehlt trotz Treffern (nur erste 500) | sicher |
| 131 | Niedrig | Oberfläche | Suche nur mit Filter: Medien-Kacheln nur aus der ersten Seite | wahrscheinlich |
| 132 | Niedrig | Nebenläufigkeit | Sammelzeile Verdachtsfälle (FSEvents-Kontext, Worker-`defer`, Reprobe beim Aushängen u. a.) | Verdacht |

### 110. FAT/exFAT/NTFS: Wiederverbinden greift praktisch nie — **Hoch**
- **Wo:** `Storage/V3/DirectoryWriterV3.swift` Z. 151–181 (`matchGoneCandidate` sucht nur `status = 2`), Z. 184–200 (gone erst in `finalize`, nach den Neueinträgen); `Indexing/DirectoryIndexer.swift` Z. 249–262 (Chunks sofort mit `finalize: false`), Z. 267–275/325–327 (`finalize` erst am Ebenenende bzw. bei 5.000 Einträgen); `Storage/V3/IndexStoreV3.swift` Z. 534 (`deleteGoneItems`).
- **Was:** Favorit `alt.jpg` auf exFAT wird am Windows-PC in `neu.jpg` umbenannt. Beim Anschließen schreibt der Chunk `neu.jpg`, wenn `alt.jpg` noch `status = 0` hat, also kein Kandidat ist → `INSERT`. Danach wird `alt.jpg` gone und am Laufende samt Favorit, Nutzer-Meta und Prüfsumme gelöscht. Gleiches gilt für Verschieben in dieselbe Ebene (je nach Reihenfolge) und **immer** für Verschieben nach oben; verbunden wird nur nach unten. Genau der Fall, für den Aufgabe 235 gebaut wurde. Die Tests verdecken es durch einen künstlichen `applyDirectory(entries: [])` dazwischen.
- **Vorschlag:** Für Medien ohne `trustsFileID` ein Verbindungs-Nachlauf **vor** `deleteGoneItems`: in diesem Lauf neu eingefügte Zeilen gegen gone-Zeilen nach den bestehenden Regeln abgleichen (Größe, Datum ±1 h, Endung, Teil-Prüfsumme). Bei eindeutigem Treffer behält die alte Zeile ihre Kennung samt Favorit/Meta und übernimmt Platz und Namen, die neue wird gelöscht. Zusätzlich im `finalize` eines Ordners die verschwindenden Zeilen desselben Ordners vorab als Kandidaten zulassen. Mit 58/59 in eine Aufgabe.
- **Test:** Echter Lauf über `DirectoryIndexer` mit Fake-Liste: `alt.txt` (Favorit) → nur `neu.txt` → gleiche `id`, Favorit bleibt. Ebenso P/a → Q/a (gleiche Ebene) und /A/B/x → /x.

### 111. Live: Änderung in einem Paket → Voll-Abgleich — **Hoch**
- **Wo:** Pakete werden mit `isFolder = 0` gespeichert (`Indexing/DirectoryIndexer.swift` Z. 623–627, `ChangeWatcherEngine.swift` Z. 169–174); `Storage/V3/IndexStoreV3.swift` Z. 441–445 (`folderID` verlangt `isFolder = 1`); `Indexing/ChangeWatcher.swift` Z. 354–375 (`directoryToReread` kennt keine Pakete); `Indexing/ChangeWatcherEngine.swift` Z. 52–93 (Eltern fehlen → nach 3 Versuchen `.needsFullReconcile`).
- **Was:** Ist Photos mit einer Mediathek auf dem Medium geöffnet, kommt laufend `…/Photos Library.photoslibrary/database/Photos.sqlite-wal`. Ergebnis: Voll-Abgleich bei jedem Flush, mit gestopptem Watcher und Minuten bis Stunden Lesen auf HDDs. Gleiches bei Updates in `.app`, `.logicx`, `.fcpbundle`. Typische Nutzung externer Platten.
- **Vorschlag:** Liegt ein Vorfahr als Paket vor (DB `isPackage = 1` bzw. `URLResourceValues.isPackage`), den **Elternordner des Pakets** neu lesen (aktualisiert dessen Datum) und Ereignisse unterhalb verwerfen, kein Voll-Abgleich.
- **Test:** Wurzel mit Paketzeile `X.app`; Ereignis `/Volumes/DISK/X.app/Contents/Info.plist` → `.ok`, Wurzel gelesen, kein `onFullReconcile`.

### 112. Hardlinks: eine Zeile je Inode, springt zwischen den Pfaden — **Hoch** auf Backup-Medien, sonst Niedrig
- **Wo:** `Indexing/BulkDirectoryReader.swift` Z. 147, 249–253 (`ATTR_CMN_FILEID` = `st_ino`, für Hardlinks gleich, ausprobiert); `Storage/V3/DirectoryWriterV3.swift` Z. 105–123, `fetchByFileID` Z. 364–377.
- **Was:** A/x und B/y sind Hardlinks mit gleicher fileID. Stück B findet über die fileID die Zeile von x und verschiebt sie nach B/y; `finalize` A holt sie zurück, `finalize` B wieder weg. Es bleibt **eine** Zeile am zuletzt bearbeiteten Pfad, bei jedem Abgleich neu. Bei Ordner-Hardlinks (HFS+-Time-Machine `Backups.backupdb`) wandert ein ganzer Unterbaum (mit falscher Tiefe, vgl. 69). Auf Time-Machine-Platten (HFS+) und `rsync --link-dest`-Backups fehlen so fast alle Pfade in der Suche, Favoriten springen.
- **Vorschlag:** `ATTR_FILE_LINKCOUNT` mitlesen; bei `linkCount > 1`, bei Ordner-Hardlinks oder wenn dieselbe fileID im Listing mehrfach vorkommt, fileID nur speichern, **nicht** zum Verbinden nutzen. Alternativ vor `relocateRow` prüfen, ob der alte Pfad noch mit demselben Inode existiert.
- **Test:** Temp-Ordner mit `link()`, zweimal `DirectoryIndexer` → zwei Zeilen, stabile `id`s.

### 113. Live: NFC-Namen werden nicht gefunden (Pfade werden zu NFD) — **Mittel**
- **Wo:** `Indexing/ChangeWatcher.swift` Z. 252, 355, 379 und `Indexing/ChangeWatcherEngine.swift` Z. 35, 158–165 (`URL(fileURLWithPath:).standardizedFileURL.path`); Namensvergleich per Bytes in `Storage/V3/DirectoryWriterV3.swift` Z. 290–303/324–336/353–362 und `IndexStoreV3.swift` Z. 441–445. Gespeicherte Namen kommen unverändert aus getattrlistbulk.
- **Was:** NFC-Namen auf der Platte (von Windows/Linux, aus Zip/Git; bei Umlauten häufig) liefern im Live-Pfad die NFD-Form. **Ebene 1:** Ordner nicht gefunden → nur die Wurzel wird neu gelesen; die neue Datei kommt bis zum nächsten Anschließen nie in den Index. **Ab Ebene 2:** Voll-Abgleich je Änderung. Live-Rename greift nicht; über `relocateRow` entstehen NFD-Namen, und `items_identity` lässt NFC- und NFD-Zeile gleichen Namens nebeneinander zu.
- **Vorschlag:** FSEvents-Pfade als Rohstring behandeln (Mount-Präfix per String, ohne `URL…standardizedFileURL`). Zusätzlich `folderID`/`fetchChildRows` zweistufig: erst exakt, sonst über `slug` im selben Elternordner suchen und in Swift kanonisch vergleichen (ohne Schemaänderung).
- **Test:** NFC-Zeile `Fotos März` in der Wurzel; Engine mit NFC-Pfad → Ordner gefunden, kein `.needsFullReconcile`.

### 114. Bereinigungstermin wird nur beim Aufwachen geprüft — **Mittel**
- **Wo:** `App/AppState.swift` Z. 387–390 (`pruneIfDue`), einziger Aufrufer `App/AppDelegate.swift` Z. 249 (`didWakeNotification`); `armPrune`/`loadPruneDeadline` (Z. 369–379) planen nichts ein.
- **Was:** Konzept: „nach 1 Stunde endgültig gelöscht … ist er beim Start überfällig, wird sofort bereinigt“. Im Code: Ein Mac ohne Ruhezustand bereinigt **nie**; ein Laptop zu einem zufälligen Zeitpunkt beim Aufwachen, parallel zu anlaufenden Läufen. `status = 1`-Zeilen bleiben unbegrenzt in der Datei. `IndexPruneTests` ruft `pruneIfDue` von Hand auf und verdeckt das.
- **Vorschlag:** Nach `hydrateSettingsFromStore()`/`loadStoredMedia()` `pruneIfDue()` aufrufen. In `armPrune` und beim Laden einen Task bis `pruneAt` planen (bei neuem Termin ersetzen). In `pruneNow` den Termin nur löschen, wenn er seit Beginn nicht neu gesetzt wurde.
- **Test:** `pruneAt` in der Vergangenheit, Start-Ablauf → bereinigt; wache App mit injizierbarer Uhr → bereinigt ohne `didWake`.

### 115. Regeländerung während eines Laufs — **Mittel**
- **Wo:** `Indexing/IndexingService.swift` Z. 79–85 (`ScanConfiguration` beim Start fest); `App/AppState.swift` Z. 41–55 (`shrinks` → nur Termin + Regel-Abgleich; `grows` → Neustart nur bei `.indexing`); `Storage/V3/DirectoryWriterV3.swift` Z. 125–143 (`UPDATE … status = 0`).
- **Was:** (a) Neuer Ausschluss während eines Laufs: Der Regel-Abgleich versteckt vorhandene Treffer, der Lauf liest offene Ordner mit dem **alten** Matcher und macht sie wieder sichtbar bzw. fügt neue Treffer sichtbar ein. (b) Tiefe verringert: Der Lauf schreibt tiefere Zeilen mit `status = 0`; `forceRecount` zählt sie, `completedDepth` steigt über max. (c) Tiefe erhöht oder Ausschluss entfernt bei fertigen, angeschlossenen Medien: **nichts startet**, Inhalte kommen erst beim nächsten Anschließen, Status bleibt „Online“ statt „x % indiziert“.
- **Vorschlag:** Bei jeder Scope-Änderung aktive Läufe abbrechen und als Abgleich mit neuer Konfiguration neu starten; bei `grows` für jedes angeschlossene `.index`-Medium einen Abgleich anstoßen. Alternativ Matcher je Ordner frisch lesen.
- **Test:** Lauf blockiert nach Ebene 1, `excludedPatterns += ["*.tmp"]`, freigeben → keine sichtbare `.tmp`-Zeile, `fileCount == COUNT(status=0)`.

### 116. Zwei angeschlossene Klone mit gleicher Identität → ein Medium — **Mittel**
- **Wo:** `Recognition/MediumCoordinator.swift` Z. 104–108 (`singleStrongMatch` ohne Prüfung „schon angeschlossen“), Z. 171 (`mediumByPath[path] = uuid` ohne Kollisionsprüfung), Z. 376–385 (`volume(for:)` = erster Treffer); `Indexing/IndexingService.swift` Z. 53–57/275–279; `Storage/V3/MediumCodecV3.swift` Z. 141–146.
- **Was:** Per `dd`/Etcher geklonte Sticks/SD-Karten oder ab Werk gleich formatierte FAT-Sticks (UUID aus der FAT-Seriennummer): B wird als Medium A verbunden. Ein Abgleich mit B markiert alles nur auf A Vorhandene als gone und löscht es samt Favoriten, dann umgekehrt. Watcher beobachtet nur eines; Auswerfen von A setzt das Medium offline, obwohl B steckt.
- **Vorschlag:** In `volumeAppeared` einen Treffer verwerfen, dessen ID schon unter einem anderen, noch eingehängten Pfad steht; wie mehrdeutig behandeln (neues Medium mit Dialog). Nie zwei Pfade einem Medium zuordnen.
- **Test:** Zwei `.appeared` mit gleicher `volumeUUID`, verschiedenen Pfaden → zwei IDs, Einträge des ersten unverändert.

### 117. `MediumAccess.probe` liest die Medienwurzel auf dem Main-Thread — **Hoch**
- **Wo:** `Recognition/MediumAccess.swift` Z. 8–9 (`nonisolated protocol … func probe … async`), Z. 56–68 (`DirectMediumAccess.probe`: `FileManager.contentsOfDirectory` synchron, ohne Queue-Wechsel; anders als `listDirectory` Z. 71–77). Aufrufer auf dem MainActor: `MediumCoordinator.swift` Z. 139 (`connectKnown`), 225 (`receiveUnknown`), 281 (`reprobeDeniedVolumes`, bei **jeder** App-Aktivierung).
- **Was:** Durch `NonisolatedNonsendingByDefault` (im Build aktiv, kein `@concurrent` im Projekt) läuft eine `nonisolated async`-Funktion auf dem Actor des Aufrufers, hier dem Main-Thread. Medien mit Status `error` sind gerade die problematischen (defekte Sektoren, hängende USB-Brücke, Platte im Standby). Bei jedem Klick ins Fenster oder in die Menüleiste wird deren Wurzel synchron im UI-Thread gelesen: Beachball, so lange die Platte nicht antwortet, und das immer wieder. Die Annahme „async = Hintergrund“ gilt im Projekt allgemein nicht.
- **Vorschlag:** `probe` `@concurrent` markieren oder wie `listDirectory` per Continuation auf eine eigene Queue legen; Zeitgrenze (z. B. 5 s → `.denied("timeout")`). In DEBUG `dispatchPrecondition(.notOnQueue(.main))` in allen `nonisolated async`-Funktionen mit blockierender Arbeit. Dieselbe Prüfung für das ganze Projekt durchführen (siehe 118–121).
- **Test:** Fake-`MediumAccess`, dessen `probe` `!Thread.isMainThread` prüft und 2 s schläft; `applicationDidBecomeActive()` → MainActor-Ticker läuft weiter.

### 118. `MediumMonitor`: Volume-Abfragen auf dem Main-Thread, auch für Netz-Volumes — **Mittel**
- **Wo:** `Recognition/MediumMonitor.swift` Z. 8 (`@MainActor`), Z. 31–37/48–60 (`emitMounted` beim Start und bei `didWake`); `Recognition/VolumeLookup.swift` Z. 16–18 (`resourceValues`, `statfs`); `Recognition/DiskArbitrationLookup.swift` Z. 19–24 (synchroner IPC). Der Filter „lokal/`/Volumes/`“ (`VolumeCandidateRule.swift` Z. 22–23) greift erst **nach** `info()`.
- **Was:** `mountedVolumeURLs(…, options: [])` liefert auch SMB/NFS-Freigaben und versteckte Volumes. Wacht der Laptop in einem anderen Netz auf, blockiert `statfs` auf der toten Freigabe bis zum Timeout (NFS „hard“: unbegrenzt), so lange hängt die UI.
- **Vorschlag:** Billig vorfiltern ohne Volume-Zugriff (`getfsstat(MNT_NOWAIT)`, `MNT_LOCAL`, Präfix `/Volumes/`, `.skipHiddenVolumes`); `info()`/DiskArbitration auf einer Hintergrund-Queue, nur das Ergebnis auf main.
- **Konfidenz:** Mechanik sicher, Hänger je nach Mount-Typ wahrscheinlich.

### 119. Live-Watcher: `stat()` je Ereignispfad auf dem Main-Thread — **Mittel**
- **Wo:** `Indexing/ChangeWatcher.swift` Z. 25 (`@MainActor`), Z. 38–40 (`pathExistsForLiveRename` = `fileExists`), Z. 251–260, 298–299; `Indexing/LiveRenamePairs.swift` Z. 30–46 (`stat()` auf **jeden** Pfad, Ergebnis zählt nur bei genau 2 Pfaden). Dazu je Ereignis zweimal `appSettings.matcher` (neuer `IgnoreMatcher`) und 3–5 URL-Standardisierungen auf main.
- **Was:** 20.000 Dateien auf das Medium kopiert oder FSEvents-Verlauf beim Wiederanschließen: alle 2–30 s ein Flush mit Tausenden `stat()` im UI-Thread, Ruckeln, auf USB-HDD Sekunden. Das Ergebnis wird praktisch immer verworfen.
- **Vorschlag:** `guard byPath.count == 2 else { return [] }` **vor** jedem `fileExists`; Paarbildung und `stat` in den `ChangeWatcherEngine`-Actor; Matcher einmal je Flush.
- **Test:** `LiveRenamePairs.pair` mit 10.000 Ereignissen und zählendem `fileExists` → 0 Aufrufe.

### 120. Synchrone DB-Schreibzugriffe auf dem Main-Thread; `queuePool` nie gesetzt — **Mittel**
- **Wo:** (a) `Views/CrashReportDialog.swift` Z. 48–50 und `App/DiskIndexLog.swift` Z. 72–76 (Auto-Senden in `applicationWillFinishLaunching`) → `IssueReporter.enqueue` (`App/IssueTracker.swift` Z. 244–272) synchron auf main: `inventoryLabels()` (`IndexStoreV3.swift` Z. 62–77, `COUNT(*)` über alle `items`), `logTail` (bis 5 MB), `persistReport` (Z. 351–366, bis 3 Versuche gegen Busy-Timeout 10 s plus `Thread.sleep`). (b) `queuePool` wird nur im Initialisierer gesetzt (`IssueTracker.swift` Z. 158/185) → `resolvePool()` (Z. 346–349) öffnet in Produktion bei **jedem** Aufruf einen neuen `DatabasePool` inkl. Migrator und `FilePrivacy.restrict`; `queueHasWork` läuft per `syncPeriodicTimer` auf main (`ApiQueueReachability.swift` Z. 42–45). Auf dem Startweg „Absturz + automatisch senden“ wird die DB schon vor `StartupSequence` geöffnet und migriert (umgeht „Datenbank im Hintergrund“). (c) `App/VersionCheckCoordinator.swift` (`@MainActor`) Z. 75, 88, 93: synchrones `pool.write` wartet auf laufende lange Writes (`deleteMedium`, `deleteGoneItems`, `incremental_vacuum`).
- **Was:** Bis ca. 30 s Main-Freeze, typisch beim Absturzdialog direkt nach dem Start während des Abgleichs (Nebenwirkung der Behebung von Nr. 30).
- **Vorschlag:** In `wireStore` `IssueReporter.shared.queuePool = store.pool`; vor dem DB-Öffnen Berichte nur in die Outbox. Alle `IssueReporter`-DB-Arbeit auf eine serielle Queue bzw. in einen Actor. Bestand aus `storages.fileCount + folderCount` statt `COUNT(*)`. `VersionCheckCoordinator` auf `await pool.write`.
- **Test:** Hintergrund-Write von 2 s halten; `enqueue` und `enqueueCheckIfNeeded` kehren auf main in < 100 ms zurück; genau ein Pool geöffnet.

### 121. Teil-Prüfsumme liest Mediendateien im Store-Actor bzw. unter der Schreibsperre — **Mittel**
- **Wo:** `Storage/V3/IndexStoreV3.swift` Z. 685–720 (`storePartialChecksum`: `fileExists` + `PartialChecksum.compute` synchron im Actor); Aufrufer `App/AppState+Favorites.swift` Z. 34–41/60–68 (Tasks nicht gehalten), `Recognition/MediumCoordinator.swift` Z. 180–190 (Backfill bei jedem Anschließen). Unter `pool.write`: `Storage/V3/DirectoryWriterV3.swift` Z. 511–520 (`incomingPartialDigest`), Z. 236–241 (`resourceValues` in `applyLivePathRename`).
- **Was:** Hängt ein Lesevorgang (Standby, defekter Sektor), ist der **eine** Store-Actor blockiert: Spaltenansicht, Suche, Favoriten, Indexer und Live-Abgleich **aller** Medien warten. Im Writer-Fall hängen zusätzlich alle Schreibzugriffe, auch die synchronen Main-Writes aus 120.
- **Vorschlag:** Prüfsumme außerhalb des Actors rechnen (`@concurrent`-Helfer/eigene Queue, mit Zeitgrenze), dem Actor nur das fertige `Data` geben; im Writer Digests vor `pool.write` berechnen; Favoriten-Tasks halten und beim Beenden abbrechen.
- **Test:** Prüfsummen-Provider, der 5 s blockiert; parallel `childrenPage`/`search` → < 100 ms.

### 122. Protokoll: jede Zeile `chmod` + `fsync` unter globalem Lock — **Mittel**
- **Wo:** `App/DiskIndexLog.swift` Z. 316–346 (`write`: je Zeile `createDirectory`, `FilePrivacy.restrict` = Verzeichnis lesen + `chmod` je Datei, `write`, `synchronizeFile()`); `Indexing/BulkDirectoryReader.swift` Z. 88/90 (1–2 Zeilen je gelesenem Ordner).
- **Was:** Ein Medium mit 200.000 Ordnern erzeugt ca. 400.000 `fsync` und über 1 Mio. `chmod` auf der Systemplatte. Alle Leser serialisieren sich am selben Lock, und jeder Log-Aufruf auf main wartet mit. Nebenbei füllen diese Zeilen die 3 × 5 MB Rotation, sodass der Fehlerbericht fast nur noch „lesen bulk=ja“ enthält.
- **Vorschlag:** `restrict` nur beim Öffnen und bei der Rotation; `fsync` nur für Fehler-, Absturz- und Ende-Zeilen oder Schreiben über eine serielle Hintergrund-Queue; „lesen“-Zeilen je Lauf zusammenfassen.

### 123. Schreibfehler im Chunk-Pfad gelten als Lesefehler — **Mittel**
- **Wo:** `Indexing/DirectoryIndexer.swift` Z. 249–266 (`applyDirectories` in `onChunk`), Z. 460–481 (`readFolderWithRetry`: catch-all mit 1 + 3 + 10 s Wartezeit), Z. 295–320 (generischer `catch` → `markFolderUnreadable`, Lauf geht weiter).
- **Was:** Jeder DB-Fehler beim Chunk-Schreiben (SQLITE_FULL, BUSY nach 10 s, UNIQUE aus 57, `unknownMedium`) wird dreimal mit Neulesen wiederholt und danach als „ordner übersprungen“ verbucht. Der Lauf endet **`.indexed` mit Lücken**, nur die Wurzel endet `.error`. Bei voller Platte kostet das 14 s je Ordner. Der gleiche Fehler in `flushBatch` führt dagegen korrekt zu `failWrite`.
- **Vorschlag:** Schreibfehler in `onChunk` in eigenen Typ (`IndexWriteFailed`) verpacken; `readFolderWithRetry` wirft ihn (wie `DirectoryIndexInterrupted`/`CancellationError`, siehe 94) sofort weiter; Lauf endet über `failWrite`.

### 124. Scrubber macht deutsche Protokollzeilen im Bericht unlesbar — **Mittel**
- **Wo:** `App/ReportScrubber.swift` Z. 20–35 (`scrubRemainder`), Z. 119–134.
- **Was (ausprobiert):** `2026-10-13T20:01:02Z medium info candidate=ja eingehängt id=1234 stärke=uuid` wird zu `‹name chars=76 bytes=78 nf=NFC ext=‹odd› flags=none U+00E4›`. Jede Zeile mit Umlaut oder typografischem Apostroph verliert **Zeitstempel, Medium-ID und Status**. Das selbst erzeugte `ext=‹odd›` verschachtelt `‹…›` und verwirrt `scrubRemainder` zusätzlich. Kein Leck, aber der Bericht verliert seinen Diagnosewert (Roadmap 0.4: „Fehlerbericht mit echten Protokollzeilen“).
- **Vorschlag:** Mit 54 lösen: nur die abgetrennten Pfad-/Namensteile profilieren, feste Meldungstexte nie; `ext=odd` ohne Winkelklammern.
- **Test:** Obige Zeile → Zeitstempel, `id=1234` und `stärke=uuid` bleiben erhalten.

### 125. Spalten-Cache verdrängt sichtbare Spalten → Auswahl und Pfad gehen verloren — **Mittel**
- **Wo:** `Indexing/IndexRepository.swift` Z. 65–70 (`children()` frischt die LRU-Reihenfolge nicht auf), Z. 295–304 (`remember`, `cacheFolderLimit = 30`); `Views/ColumnBrowser/ColumnBrowserView.swift` Z. 519–521 (`onChange(of: column.items.count)` → `pruneSelectionToVisibleItems`) → `commit` → `pathStack` gekürzt.
- **Was:** Nach 30 weiteren geladenen Ordnern seit dem Laden der Wurzel wird `cache[root]` verdrängt, obwohl sichtbar; `children(root)` liefert `[]`, Anzahl 0. Liegt der Fokus dort, wird die Auswahl gelöscht und `pathStack = []`, der geöffnete Ordner klappt zu. Derselbe Ablauf bei jedem `invalidateAll` (Regel-Abgleich, „Index jetzt bereinigen“). Widerspricht „Invalidieren heißt veraltet, nicht leeren“.
- **Vorschlag:** Beim Lesen in `children()` den Schlüssel ans Ende von `cacheOrder` setzen bzw. Schlüssel der sichtbaren Spalten anheften; `prune` nur ausführen, wenn der Ordner tatsächlich geladen ist (nicht bei fehlendem Cache/`isLoading`).
- **Konfidenz:** Mechanik sicher; Häufigkeit wahrscheinlich (normales Durchklicken).

### 126. Scan-Tiefe 1–4: letzte Ebene dauerhaft „Wird indiziert“ — **Mittel**
- **Wo:** `Models/ColumnFolderOpenState.swift` Z. 43 (`folderDepth > maxDepth`); der Indexer öffnet Ordner auf Tiefe = `maxDepth` nicht (`Indexing/DirectoryIndexer.swift` Z. 357 `depth >= maxDepth → break`; ebenso `ChangeWatcher.swift` Z. 365–366, `ChangeWatcherEngine.swift` Z. 140).
- **Was:** Ordner der letzten Ebene sind gespeichert, aber ohne `listedAt` → `.pendingIndex`: graues Icon, abgedunkelte Zeile, Pfad wird erweitert, Folgespalte zeigt dauerhaft den grünen Spinner „Wird indiziert“ statt gelb „Inhalt wird nicht indiziert“ mit „Scan-Tiefe ändern“. Die ungenutzte `AppSettings.isFolderContentUncaptured` (Z. 106–110) verwendet richtig `>=`; der Test `ProtocolAndSelectionTests` Z. 290 prüft einen Ordner, den es bei Tiefe 2 nicht geben kann.
- **Vorschlag:** `folderDepth >= maxDepth` → `.uncaptured(.scanDepth)`; Test auf `columnIndex: 1` bei Tiefe 2. Zusammen mit 81.

### 127. „Verwerfen“ im Absturzdialog löscht frühere Berichte — **Niedrig**
- **Wo:** `Views/CrashReportDialog.swift` Z. 40 → `IssueReporter.discardPendingCrash` (`App/IssueTracker.swift` Z. 312–316) → `ApiQueuePersistence.deleteAll(kind: .issueReport)`.
- **Was:** Der aktuelle Bericht ist zu diesem Zeitpunkt noch gar nicht eingereiht (erst bei „Senden“). „Verwerfen“ löscht also nur **frühere, schon zugestimmte** Berichte, z. B. einen, der wegen 75 noch offline wartet.
- **Vorschlag:** „Verwerfen“ fasst die Warteschlange nicht an, nur `acknowledgeCrashDialog`.

### 128. Gekürzte Aktionszeile kann den Absturzbericht unlesbar machen — **Niedrig**
- **Wo:** `App/DiskIndexLog.swift` Z. 389 (`line.utf8.prefix(239)`) → `writeRing`; gelesen mit `String(contentsOf:encoding: .utf8)` (Z. 72/260/278).
- **Was:** Die Kürzung kann ein Mehrbyte-Zeichen zerschneiden → `crash-last.txt` ist kein gültiges UTF-8 → Lesen liefert leer → „CRASH“ nicht erkannt, Absturz still verloren (nur „unclean“).
- **Vorschlag:** Auf UTF-8-Zeichengrenze kürzen oder beim Lesen `String(decoding:as: UTF8.self)`.

### 129. Umbenennen + neue Datei mit dem alten Namen: Ergebnis hängt von der Reihenfolge ab — **Niedrig**
- **Wo:** `Storage/V3/DirectoryWriterV3.swift` Z. 99 (`for entry in incoming.values`), Z. 105–123 gegen 125–150.
- **Was:** `a.txt` (F1) umbenannt, neue `a.txt` (F2) angelegt: Je nach Dictionary-Reihenfolge bleibt der Favorit am Namen oder folgt der fileID; zwischen Läufen springt er. Die Korrektur zu 57 behebt das nicht.
- **Vorschlag:** Zwei Durchgänge: zuerst fileID-Umbenennungen (Einträge ohne Namenstreffer), dann Namenstreffer; oder `incoming` sortieren und die Regel festlegen.

### 130. Popover: Gruppe „ORDNER“/„DATEIEN“ fehlt trotz Treffern — **Niedrig**
- **Wo:** `Models/PopoverSearch.swift` Z. 64–77 (Gruppen aus den ersten 500 nach `slug`).
- **Was:** „rechnung“ mit über 500 Dateien „Rechnung_…“: Der Ordner „Rechnungen“ fällt heraus (`_` sortiert vor `e`), die Gruppe fehlt.
- **Vorschlag:** Für das Popover je eine kleine Abfrage `isFolder = 1`/`0` mit `LIMIT 3`.

### 131. Suche nur mit Filter: Medien-Kacheln nur aus der ersten Seite — **Niedrig**
- **Wo:** `Models/SearchIndex.swift` Z. 101–103.
- **Was:** Ohne Suchbegriff erscheinen nur Medien, die unter den ersten 500 Treffern vorkommen.
- **Vorschlag:** Medien-IDs per `SELECT DISTINCT storageID` mit denselben Filtern.
- **Konfidenz:** wahrscheinlich (Konzept legt nicht ausdrücklich fest, dass alle Medien mit Treffern als Kachel erscheinen).

### 132. Sammelzeile Nebenläufigkeit (Verdacht, ohne sicher erreichbares Szenario) — **Niedrig**
- **FSEvents-Kontext ohne Retain:** `Indexing/ChangeWatcher.swift` Z. 445–451 (`passUnretained`, `retain: nil`), `close()` aus `onTermination` auf fremdem Thread (Z. 433–435, 475–481). Ein noch eingereihter Callback nach dem Freigeben wäre Use-after-free. Abhilfe: Retain/Release im Kontext oder `close` per `queue.sync`.
- **Worker-`defer` ohne Generation:** `App/AppState+RuleReconcile.swift` Z. 59–63, `App/AppState+DatabaseMaintenance.swift` Z. 28–40. Bei Abbruch und schnellem Neustart (Sperre an/aus) löscht der alte Task den Handle des neuen; dann laufen zwei Worker bzw. die Wartung parallel zum Abgleich.
- **Reprobe beim Aushängen:** `reprobeDeniedVolumes` arbeitet auf einem Schnappschuss; wird währenddessen ausgehängt, legt `storeAndPresent` ein **neues** Medium an (Z. 238 gegen 253–271).
- **`DiskIndexLog.onTrackedError`** ohne Lock gesetzt (`AppDelegate.swift` Z. 88), von allen Threads gelesen.
- **„Im Finder anzeigen“:** `fileExists` auf dem Medium synchron auf main (`AppState.swift` Z. 354–358).

---

## D. Gültige Reihenfolge nach der Zweitprüfung

1. **Datenschutz:** 54 + 55 + 124 (+ 91) in einer Aufgabe, B-55 beachten.
2. **Datenverlust/Inventar:** 58 + 59 + 110 (+ 63 Teilindex) in einer Aufgabe, B-58/B-59 beachten. Danach 56 + 70 + 113 (Live-Rename/Pfadabgleich), 57 + 129 + 112 (fileID-Zweig), 111 (Pakete).
3. **UI-Hänger durch Medien-I/O auf main:** 117 (+ 118, 119, 121): ein gemeinsames Muster, `@concurrent`/eigene Queue plus Zeitgrenze.
4. **Entscheidung/Status:** 61, 60 (B-60), 71 + 72 (B-71), 114, 115, 116.
5. **Live-Robustheit:** 64 + 66 + 99 (Flush pro Medium serialisieren), 123, 77, 79.
6. **Oberfläche:** 81 + 126, 65, 125, 80, 82, 83 (B-83), 85, 86.
7. **Fehlerbericht/Queue:** 75 (B-75) + 120, 76, 87, 127, 128, 89, 90.
8. **Rest:** Niedrig-Befunde, 108/109 als laufende Pflege (Build und Testlauf ohne Warnungen und stabil grün).

## E. Hinweise (kein Audit) — Ergänzungen

- **Medium neu formatiert (neue UUID, gleicher Name):** Es entsteht ein neues Medium mit Dialog, das alte bleibt dauerhaft „Offline“ mit totem Index. Zu klären: Hinweis anbieten oder automatisch vergessen?
- **`IndexStoreV3.purgeGoneItems`** ist laut Kommentar für die Überwachung gedacht, wird aber nirgends aufgerufen. Im reinen Live-Betrieb verschwundene Zeilen werden erst beim nächsten Lauf gelöscht. Unschädlich, aber Doku und Code passen nicht zusammen.
- **README 4 „Inhaltsstempel an der neuen Tiefengrenze zurücksetzen“:** Durch die stempelfreien Chunk-Schreibvorgänge technisch nicht mehr nötig. Den Satz ggf. anpassen.
- **Startreihenfolge (Verdacht):** `MediumRecognitionStartup.bootstrap` startet den Koordinator vor `hydrateSettingsFromStore()`. Endet das Laden der Einstellungen später als der erste Lauf, liefe dieser mit Voreinstellungen (z. B. „Unsichtbare Dateien ignorieren“ an, obwohl beim Nutzer aus). Dann würden Punkt-Dateien samt Favoriten gelöscht. Praktisch gewinnt fast immer das Laden; die Reihenfolge sollte trotzdem fest sein.
- **Testlücken, die Befunde verdecken:** `ItemIdentityTests` (künstlicher Zwischen-Apply → 110), `IndexPruneTests` (manuelles `pruneIfDue` → 114), `ProtocolAndSelectionTests` Z. 290 (unmöglicher Ordner → 126).
