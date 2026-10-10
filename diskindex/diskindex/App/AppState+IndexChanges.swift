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
        guard changeLoop == nil, let indexStore else { return }
        changeLoop = Task { [weak self] in
            for await event in indexStore.changes {
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
        changeLoop?.cancel()
        changeLoop = nil
        settingsSaveTask?.cancel()
        settingsSaveTask = nil
        pauseExpiryTask?.cancel()
        pauseExpiryTask = nil
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
        let query = searchState.submittedQuery
        let filters = searchState.filters
        let hasCriteria = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || filters.hasActiveFilters
        guard hasCriteria else {
            searchMatch = SearchMatch()
            searchState.isSearchInProgress = false
            return
        }
        searchState.isSearchInProgress = true
        searchMatch = SearchMatch()
        let match = await SearchIndex.matching(
            store: indexStore,
            query: query,
            filters: filters,
            media: indexedMedia,
            maxDepth: appSettings.indexedMaxDepth,
            scope: IndexScope.from(appSettings)
        )
        guard generation == searchGeneration else { return }
        var stored = match
        if filters.hasActiveFilters {
            stored.unfilteredItemCount = await SearchIndex.unfilteredItemCount(
                store: indexStore,
                query: query,
                media: indexedMedia,
                maxDepth: appSettings.indexedMaxDepth,
                scope: IndexScope.from(appSettings)
            )
        } else {
            stored.unfilteredItemCount = match.itemCount
        }
        guard generation == searchGeneration else { return }
        searchMatch = stored
        searchState.isSearchInProgress = false
    }

    func reloadFavorites() async {
        favoriteGeneration += 1
        let generation = favoriteGeneration
        let objects = await SearchIndex.favoriteObjects(
            store: indexStore,
            media: indexedMedia,
            maxDepth: appSettings.indexedMaxDepth,
            scope: IndexScope.from(appSettings)
        )
        guard generation == favoriteGeneration else { return }
        favoriteObjects = objects
    }

    func schedulePopoverSearch() {
        popoverGeneration += 1
        let generation = popoverGeneration
        let query = popoverSearchText
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
                self.discardPendingColumnCacheInvalidation(for: id)
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
            if mainWindowDestination == .search { await runSearch() }
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

    /// Ausstehende Spalten-Invalidierung verwerfen (ohne `stale` zu setzen) — Meta-Ticks `.counts`.
    private func discardPendingColumnCacheInvalidation(for id: UUID) {
        columnInvalidateTasks[id]?.cancel()
        columnInvalidateTasks[id] = nil
        pendingColumnInvalidateWholeMedium.remove(id)
        if let keys = pendingColumnFolderPathKeys[id], !keys.isEmpty {
            scheduleColumnCacheInvalidate(id, folderPaths: keys.map(Self.columnPath(fromKey:)))
        }
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
