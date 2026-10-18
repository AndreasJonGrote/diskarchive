//
//  AppState+IndexChanges.swift
//  diskindex
//
//  Aus AppState.swift aufgeteilt (Aufgabe 111). Keine Logikänderung.
//

import SwiftUI

extension AppState {
    #if DEBUG
    /// Tests (bug.0.4.033): z. B. `commitMediumMeta` zwischen Lesen und Schreiben.
    @TaskLocal static var writeMediumBeforePersistHook: (@Sendable (UUID, IndexStoreV3) async throws -> Void)?
    @TaskLocal static var writeMediumDelayForTesting: Duration?
    /// Tests (bug.0.3.9.003): Abstand der Live-Suche während der Indizierung statt 2 s.
    @TaskLocal static var liveSearchIntervalForTesting: Duration?
    /// Tests (bug.0.3.9.006 a): Tor nach jeder Favoriten-Zählung, bevor das Ergebnis übernommen wird.
    @TaskLocal static var favoriteCountGateForTesting: (@Sendable () async -> Void)?
    #endif

    func beginMediumLiveSync(_ id: UUID) {
        mediumLiveSyncIDs.insert(id)
    }

    func endMediumLiveSync(_ id: UUID) {
        mediumLiveSyncIDs.remove(id)
        if mediumLiveSyncIDs.isEmpty {
            scheduleDatabaseMaintenance()
        }
    }

    func startChangeLoop() {
        let previous = changeLoop
        changeLoop = nil
        previous?.cancel()
        guard let indexStore else { return }
        let store = indexStore
        changeLoop = Task { [weak self] in
            if let previous { await previous.value }
            guard !Task.isCancelled else { return }
            for await event in store.changes {
                guard let self else { return }
                let dropped = event.generation > self.lastChangeGeneration + 1
                self.lastChangeGeneration = event.generation
                await self.scheduleIndexChange(event.change, dropped: dropped)
            }
        }
    }

    /// Tests schreiben aus, ohne die 500 ms Debounce abzuwarten.
    func flushMediumEdits() async {
        let ids = Array(pendingMediumWrites.keys)
        for id in ids { pendingMediumWrites[id]?.cancel() }
        pendingMediumWrites.removeAll()
        for id in ids { await writeMedium(id) }
    }

    /// Schreibt ausstehende Nutzer-Medium- und Einstellungs-Updates (bug.0.4.033).
    @MainActor
    func flushPendingWritesForTermination() async {
        let pendingIDs = Array(pendingMediumWrites.keys)
        for task in pendingMediumWrites.values { task.cancel() }
        pendingMediumWrites.removeAll()
        for id in pendingIDs { await writeMedium(id) }
        settingsSaveTask?.cancel()
        settingsSaveTask = nil
        if persistsSettings, storeReady, indexStore != nil {
            await persistAppSettingsNow()
        }
    }

    /// Vor Prozessende: ausstehende Nutzer-Schreibvorgänge sichern (bug.0.4.033), zuerst die Favoriten-Schreibkette
    /// (höchstens `favoriteWriteTimeout`, bug.0.3.9.006 d), denn der Abbau bricht ihre Aufgaben ab.
    @MainActor
    func prepareForTerminationAsync(favoriteWriteTimeout: Duration = .seconds(3)) async {
        await waitForFavoriteWriteTail(timeout: favoriteWriteTimeout)
        prepareForTerminationTeardown()
        let pendingIDs = Array(pendingMediumWrites.keys)
        let shouldFlush = !pendingIDs.isEmpty || (persistsSettings && storeReady && indexStore != nil)
        if shouldFlush {
            await flushPendingWritesForTermination()
        }
        indexRepository.prepareForTermination()
        mediumLiveSyncIDs.removeAll()
        menuBarIndexingSpinnerIDs.removeAll()
    }

    /// Synchroner Abbau ohne Flush (Flush: `prepareForTerminationAsync` bzw. AppDelegate `.terminateLater`).
    func prepareForTermination() {
        prepareForTerminationTeardown()
        indexRepository.prepareForTermination()
        mediumLiveSyncIDs.removeAll()
        menuBarIndexingSpinnerIDs.removeAll()
    }

    private func prepareForTerminationTeardown() {
        cancelChangeLoop()
        pauseExpiryTask?.cancel()
        pauseExpiryTask = nil
        searchCountTask?.cancel()
        searchCountTask = nil
        cancelPopoverSearch()
        trailingLiveSearch?.cancel()
        trailingLiveSearch = nil
        for task in favoriteChecksumTasks.values { task.cancel() }
        favoriteRestoreTask?.cancel()
        favoriteRestoreTask = nil
        favoriteChecksumTasks.removeAll()
        for task in trailingIndexReload.values { task.cancel() }
        trailingIndexReload.removeAll()
        trailingMediumRefreshOperations.removeAll()
        for task in columnInvalidateTasks.values { task.cancel() }
        columnInvalidateTasks.removeAll()
        pendingColumnFolderPathKeys.removeAll()
        pendingColumnInvalidateWholeMedium.removeAll()
        accumulatedItemRefreshPathKeys.removeAll()
        cancelRuleReconcileForTermination()
        cancelPruneScheduleForTermination()
        cancelDatabaseMaintenanceForTermination()
    }

    #if DEBUG
    /// Tests: ausstehende Spalten-Cache-Invalidierungen verwerfen (Setup-`.items` vor der Messung).
    func cancelPendingColumnCacheInvalidatesForTesting() {
        for task in columnInvalidateTasks.values { task.cancel() }
        columnInvalidateTasks.removeAll()
        pendingColumnFolderPathKeys.removeAll()
        pendingColumnInvalidateWholeMedium.removeAll()
        accumulatedItemRefreshPathKeys.removeAll()
        for task in trailingIndexReload.values { task.cancel() }
        trailingIndexReload.removeAll()
        trailingMediumRefreshOperations.removeAll()
    }
    #endif

    func runSearch() async {
        searchGeneration += 1
        let generation = searchGeneration
        searchCountTask?.cancel()
        searchCountTask = nil
        let query = searchState.submittedQuery
        let filters = searchState.filters
        let hasCriteria = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || filters.hasActiveFilters
        guard hasCriteria else {
            cancelTrailingLiveSearch()
            searchMatch = SearchMatch()
            searchState.isSearchInProgress = false
            return
        }
        let sort = searchState.sort.serverOrder
        // Gleiche Anfrage (z. B. Neustart durch Live-Meldung): bisherige Zahl bleibt stehen; neue Anfrage: „–“.
        let request = SearchCountRequest(query: query, filters: filters, sort: sort)
        let sameHits = request.hasSameHits(as: lastCountedSearch)
        // Nur die Reihenfolge geändert (Klick auf einen Spaltenkopf): die gezählte Zahl gilt weiter, keine neue Zählung.
        let sortOnly = sameHits && lastCountedSearch?.sort != sort && searchMatch.itemCount != nil
        // bug.0.3.9.003/014 b: Diese Suche deckt den ausstehenden Nachlauf der Live-Suche ab, schon ab ihrem Start
        // (sonst feuert er während einer langsamen Suche als zweite Suche), außer ein reiner Sortierklick (zählt nicht
        // neu; der Nachlauf bringt dann die Zahl auf den neuen Stand).
        if !sortOnly { cancelTrailingLiveSearch() }
        // Alte Ergebnisse bleiben sichtbar, bis die neuen da sind (kein Flackern).
        searchState.isSearchInProgress = true
        defer {
            if generation == searchGeneration {
                searchState.isSearchInProgress = false
            }
        }
        await waitForRuleReconcileIdle()
        guard generation == searchGeneration else { return }
        let scope = indexScope
        var match = await SearchIndex.matching(
            store: indexStore,
            query: query,
            filters: filters,
            media: indexedMedia,
            maxDepth: appSettings.indexedMaxDepth,
            scope: scope,
            withCount: false,
            sort: sort
        )
        guard generation == searchGeneration else { return }
        let countPending = match.itemCount == nil
        if match.itemCount == nil, sameHits {
            match.itemCount = searchMatch.itemCount
            match.unfilteredItemCount = searchMatch.unfilteredItemCount
        } else if match.itemCount == nil {
            match.unfilteredItemCount = nil
        } else {
            match.unfilteredItemCount = filters.hasActiveFilters ? nil : match.itemCount
        }
        searchMatch = match
        searchState.isSearchInProgress = false
        clampSearchSortToAvailableColumns()
        // Ergebnisse stehen; die Zahl(en) kommen in einer eigenen Aufgabe nach.
        let needsCount = !sortOnly && (countPending || filters.hasActiveFilters)
        guard needsCount else {
            lastCountedSearch = request
            return
        }
        searchCountTask = Task { [weak self] in
            guard let self else { return }
            let media = self.indexedMedia
            let depth = self.appSettings.indexedMaxDepth
            var itemCount = match.itemCount
            if countPending {
                let counted = await SearchIndex.count(
                    store: self.indexStore, query: query, filters: filters, media: media, maxDepth: depth, scope: scope
                )
                guard !Task.isCancelled, generation == self.searchGeneration else { return }
                itemCount = counted
                self.searchMatch.itemCount = counted
                self.clampSearchSortToAvailableColumns()
            }
            if filters.hasActiveFilters {
                let unfiltered = await SearchIndex.unfilteredItemCount(
                    store: self.indexStore, query: query, media: media, maxDepth: depth, scope: scope
                )
                guard !Task.isCancelled, generation == self.searchGeneration else { return }
                self.searchMatch.unfilteredItemCount = unfiltered
            } else {
                self.searchMatch.unfilteredItemCount = itemCount
            }
            self.lastCountedSearch = request
        }
    }

    /// bug.0.4.038: Pfad und Status sortiert nur der Client, und nur, wenn alle Treffer auf der Seite stehen. Steht
    /// fest, dass es mehr sind, fällt eine solche Sortierung auf Name zurück (der Spaltenkopf ist dann deaktiviert).
    func clampSearchSortToAvailableColumns() {
        guard !SearchSort.serverColumns.contains(searchState.sort.column) else { return }
        guard let count = searchMatch.itemCount, count > SearchIndex.pageLimit else { return }
        searchState.sort = SearchSort()
    }

    /// Tests: wartet, bis die nachgereichte Trefferzahl da (oder verworfen) ist.
    func waitForSearchCount() async {
        var task = searchCountTask
        while let current = task {
            await current.value
            let next = searchCountTask
            task = next == current ? nil : next
        }
    }

    private func cancelTrailingLiveSearch() {
        trailingLiveSearch?.cancel()
        trailingLiveSearch = nil
    }

    /// Suche nach einer Live-Meldung: Während ein Medium indiziert wird höchstens alle 2 s neu (die Meldungen
    /// kommen im Takt des Fortschritts). Eine vom Nutzer abgeschickte Suche läuft immer sofort (`runSearch`).
    func runSearchAfterLiveChange() async {
        var interval = Duration.seconds(2)
        #if DEBUG
        if let override = Self.liveSearchIntervalForTesting { interval = override }
        #endif
        guard media.contains(where: { $0.indexStatus == .indexing }) else {
            await runSearch()
            return
        }
        let now = ContinuousClock.now
        if let last = lastLiveSearchAt, last.duration(to: now) < interval {
            guard trailingLiveSearch == nil else { return }
            let wait = interval - last.duration(to: now)
            trailingLiveSearch = Task { [weak self] in
                try? await Task.sleep(for: wait)
                guard !Task.isCancelled, let self else { return }
                self.trailingLiveSearch = nil
                self.lastLiveSearchAt = .now
                if self.mainWindowDestination == .search { await self.runSearch() }
            }
            return
        }
        lastLiveSearchAt = now
        await runSearch()
    }

    /// Favoriten-Seite samt Zahl und alle Favoriten-Kennungen (bug.0.4.037/040).
    func reloadFavorites() async {
        await reloadFavoritePage()
        await reloadFavoriteIDs()
    }

    /// bug.0.4.040 (REPORT 86): erste Seite (`SearchIndex.pageLimit`) wie die Suche, Filter in der Abfrage; die Zahl
    /// kommt danach (bis dahin „–“, bei gleicher Anfrage bleibt die bisherige Zahl stehen).
    func reloadFavoritePage() async {
        favoriteGeneration += 1
        let generation = favoriteGeneration
        let request = currentFavoritesRequest
        let scope = indexScope
        let store = indexStore
        // Erst nach den ausstehenden Favoriten-Schreibvorgängen lesen; kam währenddessen ein Umschalten dazu, neu
        // lesen. Sonst brächte ein Neuladen vor dem Schreiben einen eben abgewählten Favoriten zurück.
        var objects: [SearchResultItem]
        while true {
            let edits = favoriteEditGeneration
            await favoriteWriteTail?.value
            objects = await SearchIndex.favoritePage(store: store, request: request, scope: scope)
            guard generation == favoriteGeneration else { return }
            if edits == favoriteEditGeneration { break }
        }
        let sameRequest = request == lastFavoritesRequest
        favoriteObjects = objects
        let hasObjectFilters = request.filters.hasActiveObjectFilters
        // Seite nicht voll: das ist die ganze Treffermenge, keine Zählabfrage.
        let pageComplete = objects.count < SearchIndex.pageLimit
        if pageComplete {
            favoriteItemCount = objects.count
        } else if !sameRequest {
            favoriteItemCount = nil
        }
        if hasObjectFilters {
            if !sameRequest { favoriteUnfilteredCount = nil }
        } else if pageComplete {
            favoriteUnfilteredCount = objects.count
        }
        // bug.0.3.9.006 a: Wird während einer Zählung umgeschaltet, gilt das alte Ergebnis nicht (es überschriebe die
        // lokal gesenkte Zahl); nach dem Schreiben neu zählen.
        if !pageComplete {
            guard let counted = await countFavoritesAfterWrites(store: store, request: request, objectFilters: true, scope: scope, generation: generation) else { return }
            favoriteItemCount = counted
        }
        if hasObjectFilters {
            guard let unfiltered = await countFavoritesAfterWrites(store: store, request: request, objectFilters: false, scope: scope, generation: generation) else { return }
            favoriteUnfilteredCount = unfiltered
        } else {
            favoriteUnfilteredCount = favoriteItemCount
        }
        lastFavoritesRequest = request
    }

    /// Zählt so lange, bis während der Zählung kein Umschalten dazwischenkam; `nil` = Seite inzwischen neu angefragt.
    private func countFavoritesAfterWrites(
        store: IndexStoreV3?,
        request: FavoritesRequest,
        objectFilters: Bool,
        scope: IndexScope,
        generation: Int
    ) async -> Int? {
        while true {
            let edits = favoriteEditGeneration
            let counted = await SearchIndex.favoriteCount(store: store, request: request, objectFilters: objectFilters, scope: scope)
            #if DEBUG
            if let gate = Self.favoriteCountGateForTesting { await gate() }
            #endif
            guard generation == favoriteGeneration else { return nil }
            if edits == favoriteEditGeneration { return counted }
            await favoriteWriteTail?.value
        }
    }

    /// bug.0.4.039 (REPORT 85): Eingabe entprellt (`popoverSearchDebounce`), jede neue Eingabe bricht Seite und
    /// Zählung der vorigen ab. Die Seite kommt ohne Zahl, die Zahl getrennt und abbrechbar.
    func schedulePopoverSearch() {
        popoverGeneration += 1
        let generation = popoverGeneration
        cancelPopoverSearch()
        let query = popoverSearchText
        // Leeres Feld (auch nach dem X): keine Suche, auch nicht über Filter der Hauptsuche.
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            popoverResults = PopoverSearchResults()
            NotificationCenter.default.post(name: .menuBarPopoverLayoutInvalidated, object: nil)
            return
        }
        let debounce = popoverSearchDebounce
        popoverSearchTask = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled, let self, generation == self.popoverGeneration else { return }
            let page = await PopoverSearch.page(query: query, appState: self)
            guard !Task.isCancelled, generation == self.popoverGeneration else { return }
            guard let request = page.pendingCount else {
                self.popoverResults = page.results
                NotificationCenter.default.post(name: .menuBarPopoverLayoutInvalidated, object: nil)
                return
            }
            // Fußzeile zeigt nie eine erfundene Zahl: Bis die Zählung da ist, bleibt die zuletzt bekannte Zahl stehen.
            // Ohne bekannte Zahl (erste Suche nach leerem Feld) erscheint die Seite erst mit der Zahl, wie vor 0.4.039.
            let known = self.popoverResults.totalCount
            let pendingPage = page.results
            let showsPageEarly = known > 0
            if showsPageEarly {
                var early = pendingPage
                early.totalCount = known
                self.popoverResults = early
                NotificationCenter.default.post(name: .menuBarPopoverLayoutInvalidated, object: nil)
            }
            let mediumCount = page.mediumCount
            let store = self.indexStore
            let media = self.indexedMedia
            let depth = self.appSettings.indexedMaxDepth
            let scope = self.indexScope
            self.popoverCountTask = Task { [weak self] in
                let counted = await SearchIndex.count(
                    store: store, query: request.query, filters: request.filters, media: media, maxDepth: depth, scope: scope
                )
                guard !Task.isCancelled, let self, generation == self.popoverGeneration else { return }
                var final = showsPageEarly ? self.popoverResults : pendingPage
                final.totalCount = mediumCount + counted
                final.isCountPending = false
                self.popoverResults = final
                NotificationCenter.default.post(name: .menuBarPopoverLayoutInvalidated, object: nil)
            }
        }
    }

    func cancelPopoverSearch() {
        popoverSearchTask?.cancel()
        popoverSearchTask = nil
        popoverCountTask?.cancel()
        popoverCountTask = nil
    }

    /// Tests: wartet, bis Seite und nachgereichte Zahl der letzten Popover-Eingabe da (oder verworfen) sind.
    func waitForPopoverSearch() async {
        while let search = popoverSearchTask {
            await search.value
            if popoverSearchTask == search { break }
        }
        while let count = popoverCountTask {
            await count.value
            if popoverCountTask == count { break }
        }
    }

    func scheduleIndexChange(_ change: IndexChange, dropped: Bool) async {
        if case .removed(let id) = change {
            media.removeAll { $0.id == id }
            indexRepository.invalidate(id)
            await reloadFavoritesIfVisible()
            return
        }
        if dropped {
            let id = change.mediumID
            trailingIndexReload[id]?.cancel()
            trailingIndexReload[id] = nil
            trailingMediumRefreshOperations[id] = nil
            await flushIndexChange(id, dropAll: true, columnFolders: nil, refreshLists: true)
            return
        }
        switch change {
        case .counts(let id):
            await debouncedMediumRefresh(id) {
                await self.reloadMedium(id)
            }
        case .medium(let id):
            await debouncedMediumRefresh(id) {
                await self.reloadMedium(id)
            }
        case .layer(let id, _):
            await debouncedMediumRefresh(id) {
                await self.flushIndexChange(
                    id,
                    dropAll: false,
                    columnFolders: nil,
                    refreshLists: true,
                    invalidateWholeMediumColumns: true
                )
            }
        case .items(let id, let folderPaths):
            accumulateItemRefreshPaths(id, folderPaths: folderPaths)
            await debouncedMediumRefresh(id) {
                let paths = self.drainAccumulatedItemRefreshPaths(id)
                guard !paths.isEmpty else { return }
                await self.flushIndexChange(
                    id,
                    dropAll: false,
                    columnFolders: paths,
                    refreshLists: true,
                    invalidateWholeMediumColumns: false
                )
            }
        case .removed:
            break
        case .ruleReconcileIdle:
            await resumeAfterRuleReconcile()
        }
    }

    func debouncedMediumRefresh(_ id: UUID, operation: @escaping () async -> Void) async {
        let now = ContinuousClock.now
        if let last = lastIndexReload[id], last.duration(to: now) < .milliseconds(750) {
            trailingMediumRefreshOperations[id, default: []].append(operation)
            if trailingIndexReload[id] == nil {
                trailingIndexReload[id] = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(750))
                    guard let self else { return }
                    let ops = self.trailingMediumRefreshOperations.removeValue(forKey: id) ?? []
                    for op in ops { await op() }
                    self.trailingIndexReload[id] = nil
                }
            }
            return
        }
        lastIndexReload[id] = .now
        await operation()
    }

    func flushIndexChange(
        _ id: UUID,
        dropAll: Bool,
        columnFolders: [[String]]?,
        refreshLists: Bool,
        invalidateWholeMediumColumns: Bool = false
    ) async {
        if dropAll {
            await loadStoredMedia()
            indexRepository.invalidate(id)
        } else {
            await reloadMedium(id)
            if invalidateWholeMediumColumns {
                scheduleColumnCacheInvalidate(id, folderPaths: nil)
            } else if let columnFolders {
                scheduleColumnCacheInvalidate(id, folderPaths: columnFolders)
            }
        }
        if refreshLists {
            await reloadFavoritesIfVisible()
            if mainWindowDestination == .search { await runSearchAfterLiveChange() }
            if !popoverSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                schedulePopoverSearch()
            }
        }
    }

    func reloadFavoritesIfVisible() async {
        guard mainWindowDestination == .favorites else { return }
        await reloadFavorites()
    }

    func isMediumIndexing(_ id: UUID) -> Bool {
        medium(with: id)?.indexStatus == .indexing || mediumLiveSyncIDs.contains(id)
    }

    /// Spalten-Cache gezielt; Meta-Ticks (`.counts`) invalidieren nie. Während Indizierung höchstens alle 2 s.
    func scheduleColumnCacheInvalidate(_ id: UUID, folderPaths: [[String]]?) {
        if folderPaths == nil {
            pendingColumnInvalidateWholeMedium.insert(id)
            pendingColumnFolderPathKeys[id] = nil
        } else if let folderPaths {
            var keys = pendingColumnFolderPathKeys[id, default: []]
            for path in folderPaths {
                keys.insert(Self.columnPathKey(path))
            }
            pendingColumnFolderPathKeys[id] = keys
        }
        guard columnInvalidateTasks[id] == nil else { return }
        let delay: Duration = isMediumIndexing(id) ? .milliseconds(2_000) : .milliseconds(450)
        columnInvalidateTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            self.flushPendingColumnInvalidation(id)
            self.columnInvalidateTasks[id] = nil
        }
    }

    func accumulateItemRefreshPaths(_ id: UUID, folderPaths: [[String]]) {
        var keys = accumulatedItemRefreshPathKeys[id, default: []]
        for path in folderPaths {
            keys.insert(Self.columnPathKey(path))
        }
        accumulatedItemRefreshPathKeys[id] = keys
    }

    func drainAccumulatedItemRefreshPaths(_ id: UUID) -> [[String]] {
        guard let keys = accumulatedItemRefreshPathKeys.removeValue(forKey: id) else { return [] }
        return keys.map(Self.columnPath(fromKey:)).sorted { $0.joined() < $1.joined() }
    }

    private func flushPendingColumnInvalidation(_ id: UUID) {
        let whole = pendingColumnInvalidateWholeMedium.remove(id) != nil
        let keys = pendingColumnFolderPathKeys.removeValue(forKey: id)
        if whole {
            indexRepository.invalidate(id)
        } else if let keys {
            for key in keys {
                indexRepository.invalidate(mediumID: id, path: Self.columnPath(fromKey: key))
            }
        }
    }

    nonisolated private static func columnPathKey(_ path: [String]) -> String {
        path.joined(separator: "\u{0}")
    }

    nonisolated private static func columnPath(fromKey key: String) -> [String] {
        guard !key.isEmpty else { return [] }
        return key.split(separator: "\u{0}", omittingEmptySubsequences: false).map(String.init)
    }

    func reloadMedium(_ id: UUID) async {
        guard let indexStore else { return }
        let stored: StoredMedium
        do {
            guard let row = try await indexStore.medium(uuid: id) else { return }
            stored = row
        } catch {
            guard DiskIndexLog.isOperationalFailure(error) else { return }
            DiskIndexLog.shared.record(.store, .error, "reloadMedium \(error)")
            return
        }
        let fresh = stored.asMedium(connection: medium(with: id)?.connectionStatus ?? .offline)
        if let index = media.firstIndex(where: { $0.id == id }) {
            let progress = media[index].indexingProgress
            let connection = media[index].connectionStatus
            let preserveUserFields = pendingMediumWrites[id] != nil
            var replacement = fresh
            replacement.connectionStatus = connection
            if preserveUserFields {
                // bug.0.4.043: ausstehende UI-Entscheidung nicht mit alter DB-Zeile überschreiben.
                replacement.decision = media[index].decision
                replacement.allowIndexing = media[index].allowIndexing
                replacement.autoIndexPaused = media[index].autoIndexPaused
                replacement.isFavorite = media[index].isFavorite
                replacement.showAbsoluteCapacity = media[index].showAbsoluteCapacity
            }
            if replacement.indexStatus == .indexing {
                replacement.indexingProgress = progress
            } else if replacement.indexStatus == .indexed {
                replacement.indexingProgress = 1
            }
            media[index] = replacement
        } else {
            media.append(fresh)
        }
    }

    func scheduleSettingsSave() {
        settingsSaveTask?.cancel()
        settingsSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            await self.persistAppSettingsNow()
        }
    }

    func scheduleMediumWrite(_ id: UUID) {
        pendingMediumWrites[id]?.cancel()
        pendingMediumWrites[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            await self.writeMedium(id)
            self.pendingMediumWrites[id] = nil
        }
    }

    func writeMedium(_ id: UUID) async {
        guard featureAccess.canWriteIndex else { return }
        guard let indexStore else { return }
        guard let current = medium(with: id) else {
            // bug.0.4.080 d): Medium unbekannt (vergessen, entfernt): die Marke bliebe sonst für immer stehen.
            userDecisionIDs[id] = nil
            return
        }
        // bug.0.4.075: nur eine Änderung in 05/06 schreibt die Entscheidung und gilt als gemerkt (auch wenn ihr eigener
        // Write abgelöst wurde: Debounce, Beenden). Ein fremder Write (Favorit, Kapazität) lässt die Entscheidung der DB
        // stehen, sonst schriebe er eine veraltete Entscheidung der Oberfläche zurück (Bereich bug.0.4.043).
        let userChange = userDecisionIDs[id]
        let decisionByUser = userChange != nil
        do {
            guard var stored = try await indexStore.medium(uuid: id) else {
                // bug.0.4.080 d): nicht in der Datenbank – nichts zu schreiben, Marke dieser Änderung entfernen.
                if let userChange, userDecisionIDs[id] == userChange { userDecisionIDs[id] = nil }
                return
            }
            if decisionByUser {
                stored.rememberDecision = true
                stored.allowIndexing = current.decision == .index
                stored.decision = current.decision
            }
            stored.showAbsoluteCapacity = current.showAbsoluteCapacity
            stored.isFavorite = current.isFavorite
            stored.autoIndexPaused = current.autoIndexPaused
            if let type = StoredMediumType(rawValue: current.type.rawValue) { stored.type = type }
            stored.isForgotten = current.isForgotten
            #if DEBUG
            if let hook = Self.writeMediumBeforePersistHook {
                try await hook(id, indexStore)
            }
            if let delay = Self.writeMediumDelayForTesting {
                try await Task.sleep(for: delay)
            }
            #endif
            try await indexStore.updateMediumUserFields(uuid: id, stored)
            if let userChange, userDecisionIDs[id] == userChange { userDecisionIDs[id] = nil }
        } catch {
            // Nicht geschrieben: die Änderung aus 05/06 bleibt für den nächsten Write vorgemerkt.
            guard DiskIndexLog.isOperationalFailure(error) else { return }
            DiskIndexLog.shared.record(.store, .error, "writeMedium \(error)")
        }
    }

}
