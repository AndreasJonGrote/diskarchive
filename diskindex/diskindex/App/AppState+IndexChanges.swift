//
//  AppState+IndexChanges.swift
//  diskindex
//
//  Aus AppState.swift aufgeteilt (Aufgabe 111). Keine Logikänderung.
//

import SwiftUI

extension AppState {
    func beginMediumLiveSync(_ id: UUID) {
        mediumLiveSyncIDs.insert(id)
    }

    func endMediumLiveSync(_ id: UUID) {
        mediumLiveSyncIDs.remove(id)
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

    /// Tests schreiben die Einstellungen aus, ohne die Debounce abzuwarten.
    func flushSettings() {
        settingsSaveTask?.cancel()
        settingsSaveTask = nil
        guard persistsSettings else { return }
        appSettings.save(to: settingsDefaults)
    }

    /// Vor Prozessende: Hintergrund-Tasks stoppen, Einstellungen sichern, Spalten-Laden abbrechen.
    func prepareForTermination() {
        cancelChangeLoop()
        settingsSaveTask?.cancel()
        settingsSaveTask = nil
        pauseExpiryTask?.cancel()
        pauseExpiryTask = nil
        searchCountTask?.cancel()
        searchCountTask = nil
        trailingLiveSearch?.cancel()
        trailingLiveSearch = nil
        for task in pendingMediumWrites.values { task.cancel() }
        pendingMediumWrites.removeAll()
        for task in trailingIndexReload.values { task.cancel() }
        trailingIndexReload.removeAll()
        trailingMediumRefreshOperations.removeAll()
        for task in columnInvalidateTasks.values { task.cancel() }
        columnInvalidateTasks.removeAll()
        pendingColumnFolderPathKeys.removeAll()
        pendingColumnInvalidateWholeMedium.removeAll()
        accumulatedItemRefreshPathKeys.removeAll()
        flushSettings()
        indexRepository.prepareForTermination()
        mediumLiveSyncIDs.removeAll()
        menuBarIndexingSpinnerIDs.removeAll()
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
            searchMatch = SearchMatch()
            searchState.isSearchInProgress = false
            return
        }
        // Alte Ergebnisse bleiben sichtbar, bis die neuen da sind (kein Flackern).
        searchState.isSearchInProgress = true
        let scope = indexScope
        var match = await SearchIndex.matching(
            store: indexStore,
            query: query,
            filters: filters,
            media: indexedMedia,
            maxDepth: appSettings.indexedMaxDepth,
            scope: scope,
            withCount: false
        )
        guard generation == searchGeneration else { return }
        // Gleiche Anfrage (z. B. Neustart durch Live-Meldung): bisherige Zahl bleibt stehen; neue Anfrage: „–“.
        let request = SearchCountRequest(query: query, filters: filters)
        let countPending = match.itemCount == nil
        if match.itemCount == nil, request == lastCountedSearch {
            match.itemCount = searchMatch.itemCount
            match.unfilteredItemCount = searchMatch.unfilteredItemCount
        } else if match.itemCount == nil {
            match.unfilteredItemCount = nil
        } else {
            match.unfilteredItemCount = filters.hasActiveFilters ? nil : match.itemCount
        }
        searchMatch = match
        searchState.isSearchInProgress = false
        // Ergebnisse stehen; die Zahl(en) kommen in einer eigenen Aufgabe nach.
        let needsCount = countPending || filters.hasActiveFilters
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

    /// Tests: wartet, bis die nachgereichte Trefferzahl da (oder verworfen) ist.
    func waitForSearchCount() async {
        var task = searchCountTask
        while let current = task {
            await current.value
            let next = searchCountTask
            task = next == current ? nil : next
        }
    }

    /// Suche nach einer Live-Meldung: Während ein Medium indiziert wird höchstens alle 2 s neu (die Meldungen
    /// kommen im Takt des Fortschritts). Eine vom Nutzer abgeschickte Suche läuft immer sofort (`runSearch`).
    func runSearchAfterLiveChange() async {
        let interval = Duration.seconds(2)
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

    func reloadFavorites() async {
        favoriteGeneration += 1
        let generation = favoriteGeneration
        let objects = await SearchIndex.favoriteObjects(
            store: indexStore,
            media: indexedMedia,
            maxDepth: appSettings.indexedMaxDepth,
            scope: indexScope
        )
        guard generation == favoriteGeneration else { return }
        favoriteObjects = objects
    }

    func schedulePopoverSearch() {
        popoverGeneration += 1
        let generation = popoverGeneration
        let query = popoverSearchText
        // Leeres Feld (auch nach dem X): keine Suche, auch nicht über Filter der Hauptsuche.
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            popoverResults = PopoverSearchResults()
            NotificationCenter.default.post(name: .menuBarPopoverLayoutInvalidated, object: nil)
            return
        }
        Task {
            let results = await PopoverSearch.results(query: query, appState: self)
            await MainActor.run {
                guard generation == popoverGeneration else { return }
                popoverResults = results
                NotificationCenter.default.post(name: .menuBarPopoverLayoutInvalidated, object: nil)
            }
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
            var replacement = fresh
            replacement.connectionStatus = connection
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
            self.appSettings.save(to: self.settingsDefaults)
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
        guard let indexStore, let current = medium(with: id) else { return }
        do {
            guard var stored = try await indexStore.medium(uuid: id) else { return }
            stored.showAbsoluteCapacity = current.showAbsoluteCapacity
            stored.isFavorite = current.isFavorite
            stored.autoIndexPaused = current.autoIndexPaused
            stored.allowIndexing = current.decision == .index
            stored.decision = current.decision
            if let type = StoredMediumType(rawValue: current.type.rawValue) { stored.type = type }
            stored.isForgotten = current.isForgotten
            try await indexStore.updateMedium(uuid: id, stored)
        } catch {
            guard DiskIndexLog.isOperationalFailure(error) else { return }
            DiskIndexLog.shared.record(.store, .error, "writeMedium \(error)")
        }
    }

}
