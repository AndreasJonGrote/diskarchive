//
//  IndexRepository.swift
//  diskindex
//

import Foundation

/// Zwischenspeicher für Ordnerinhalte. Die Spaltenansicht liest synchron, das Laden läuft danach.
@MainActor
@Observable
final class IndexRepository {
    private var store: IndexStore?
    private var cache: [String: [IndexedItem]] = [:]
    private var cacheOrder: [String] = []
    var scope = IndexScope.revealAll
    private var loading: Set<String> = []
    private var loadingLoaded: [String: Int] = [:]
    private var loadingTotals: [String: Int] = [:]
    private var loadErrors: [String: String] = [:]
    private(set) var stale: Set<String> = []
    private(set) var generation = 0
    private var loadGenerations: [String: UInt] = [:]
    private let cacheFolderLimit = 30
    #if DEBUG
    private var simulationLoadTasks: [String: Task<Void, Never>] = [:]
    private(set) static var loadSessionsStartedForTesting = 0
    private(set) static var requestLoadCallsForTesting = 0

    static func resetLoadSessionsCounterForTesting() {
        loadSessionsStartedForTesting = 0
    }

    static func resetRequestLoadCounterForTesting() {
        requestLoadCallsForTesting = 0
    }
    #endif
    /// Sequentiell aus der DB, damit sehr große Ordner den Ladevorgang nicht abbrechen.
    static let loadBatchSize = 2_000
    /// UI-Aktualisierung des Ladestands (T1: höchstens alle 100 ms).
    private static let loadProgressInterval: Duration = .milliseconds(100)

    init(store: IndexStore?) {
        self.store = store
    }

    func replaceStore(_ store: IndexStore?) {
        self.store = store
        cache.removeAll()
        cacheOrder.removeAll()
        loading.removeAll()
        loadingLoaded.removeAll()
        loadingTotals.removeAll()
        loadErrors.removeAll()
        loadGenerations.removeAll()
        generation += 1
    }

    /// Nur Cache/Ladezustand lesen — kein Nachladen aus dem View-Aufbau (109).
    func children(mediumID: UUID, path: [String]) -> [IndexedItem] {
        #if DEBUG
        if ColumnStateSimulation.isSimulationMedium(mediumID) {
            return simulationChildrenReadOnly(mediumID: mediumID, path: path)
        }
        #endif
        let key = cacheKey(mediumID, path)
        if let cached = cache[key] { return cached }
        if loading.contains(key) { return [] }
        return []
    }

    func requestLoad(mediumID: UUID, path: [String]) {
        #if DEBUG
        Self.requestLoadCallsForTesting += 1
        if ColumnStateSimulation.isSimulationMedium(mediumID) {
            requestSimulationLoad(mediumID: mediumID, path: path)
            return
        }
        #endif
        let key = cacheKey(mediumID, path)
        if loading.contains(key) { return }
        let needsLoad = cache[key] == nil || stale.contains(key)
        if !needsLoad { return }
        guard store != nil, loading.insert(key).inserted else { return }
        Task { await load(mediumID: mediumID, path: path, key: key) }
    }

    func folderLoadError(mediumID: UUID, path: [String]) -> String? {
        loadErrors[cacheKey(mediumID, path)]
    }

    func isLoading(mediumID: UUID, path: [String]) -> Bool {
        let key = cacheKey(mediumID, path)
        if cache[key] != nil { return false }
        return loading.contains(key)
    }

    func loadingProgress(mediumID: UUID, path: [String]) -> (loaded: Int, total: Int) {
        let key = cacheKey(mediumID, path)
        if cache[key] != nil { return (0, 0) }
        let loaded = loadingLoaded[key] ?? 0
        let total = loadingTotals[key] ?? 0
        return (loaded, total)
    }

    func setFavoriteLocally(mediumID: UUID, id: UUID, isFavorite: Bool) {
        setFavoritesLocally(ids: [id], isFavorite: isFavorite, mediumID: mediumID)
    }

    func setFavoritesLocally(ids: [UUID], isFavorite: Bool, mediumID: UUID? = nil) {
        let wanted = Set(ids)
        for key in cache.keys {
            if let mediumID, !key.hasPrefix(mediumID.uuidString) { continue }
            guard var items = cache[key] else { continue }
            var changed = false
            for index in items.indices where wanted.contains(items[index].id) {
                items[index].isFavorite = isFavorite
                changed = true
            }
            if changed { cache[key] = items }
        }
    }

    func invalidate(_ mediumID: UUID) {
        let prefix = mediumID.uuidString
        let keys = Set(cache.keys.filter { $0.hasPrefix(prefix) }).union(loading.filter { $0.hasPrefix(prefix) })
        for key in keys { stale.insert(key) }
        loading = loading.filter { !$0.hasPrefix(prefix) }
        loadingLoaded = loadingLoaded.filter { !$0.key.hasPrefix(prefix) }
        loadingTotals = loadingTotals.filter { !$0.key.hasPrefix(prefix) }
        loadErrors = loadErrors.filter { !$0.key.hasPrefix(prefix) }
        for key in keys { bumpLoadGeneration(key) }
        generation += 1
    }

    func invalidate(mediumID: UUID, path: [String]) {
        #if DEBUG
        if ColumnStateSimulation.isSimulationMedium(mediumID),
           ColumnStateSimulation.isLoadingColumnPath(path) {
            return
        }
        #endif
        let key = cacheKey(mediumID, path)
        stale.insert(key)
        loading.remove(key)
        loadingLoaded[key] = nil
        loadingTotals[key] = nil
        loadErrors[key] = nil
        bumpLoadGeneration(key)
        generation += 1
    }

    func invalidateAll() {
        cache.removeAll()
        cacheOrder.removeAll()
        loading.removeAll()
        loadingLoaded.removeAll()
        loadingTotals.removeAll()
        loadErrors.removeAll()
        loadGenerations.removeAll()
        generation += 1
    }

    /// Beenden: Demo-Lade-Tasks und laufende Ordner-Ladevorgänge abbrechen.
    func prepareForTermination() {
        #if DEBUG
        for task in simulationLoadTasks.values { task.cancel() }
        simulationLoadTasks.removeAll()
        #endif
        for key in loading {
            bumpLoadGeneration(key)
        }
        loading.removeAll()
    }

    #if DEBUG
    func hasCachedChildren(mediumID: UUID, path: [String]) -> Bool {
        cache[cacheKey(mediumID, path)] != nil
    }

    /// Tests — Ladezustand ohne IndexStore (Aufgabe 156).
    func setLoadingForUITest(mediumID: UUID, path: [String], loading isOn: Bool, total: Int = 20_000, loaded: Int = 0) {
        let key = cacheKey(mediumID, path)
        if isOn {
            loading.insert(key)
            loadingTotals[key] = total
            loadingLoaded[key] = loaded
        } else {
            loading.remove(key)
            loadingTotals[key] = nil
            loadingLoaded[key] = nil
        }
        generation += 1
    }

    /// Bildschirmfotos — Ordnerinhalte ohne IndexStore.
    func seedScreenshotCache(mediumID: UUID, entries: [([String], [IndexedItem])]) {
        for (path, items) in entries {
            remember(cacheKey(mediumID, path), items)
        }
    }
    #endif

    /// Tests lesen einen Ordner, ohne auf den Cache-Task zu warten.
    func loadChildren(mediumID: UUID, path: [String]) async -> [IndexedItem] {
        let key = cacheKey(mediumID, path)
        #if DEBUG
        if ColumnStateSimulation.isSimulationMedium(mediumID) {
            if ColumnStateSimulation.isLoadingColumnPath(path) {
                requestSimulationLoad(mediumID: mediumID, path: path)
                while loading.contains(key),
                      (loadingLoaded[key] ?? 0) < ColumnStateSimulation.simulatedLoadingFrozenCount {
                    await Task.yield()
                }
                return []
            }
            if loading.contains(key) {
                while loading.contains(key) {
                    await Task.yield()
                }
                return cache[key] ?? []
            }
            requestSimulationLoad(mediumID: mediumID, path: path)
            return cache[key] ?? simulationChildrenReadOnly(mediumID: mediumID, path: path)
        }
        #endif
        requestLoad(mediumID: mediumID, path: path)
        while loading.contains(key) {
            await Task.yield()
        }
        return cache[key] ?? []
    }

    private func load(mediumID: UUID, path: [String], key: String) async {
        #if DEBUG
        Self.loadSessionsStartedForTesting += 1
        #endif
        let loadToken = loadGenerations[key, default: 0]
        defer {
            loading.remove(key)
            loadingLoaded[key] = nil
            loadingTotals[key] = nil
        }
        loadErrors[key] = nil
        guard let store else {
            guard loadGenerations[key, default: 0] == loadToken else { return }
            cache[key] = []
            return
        }
        let started = ContinuousClock.now
        do {
            let parentID: Int64?
            if path.isEmpty {
                parentID = nil
            } else {
                parentID = try await store.folderID(mediumUUID: mediumID, path: path)
                if parentID == nil {
                    cache[key] = []
                    return
                }
            }
            let totalCount = try await store.childCount(mediumUUID: mediumID, parentID: parentID, scope: scope)
            loadingTotals[key] = totalCount
            loadingLoaded[key] = 0

            var accumulated: [IndexedItem] = []
            var lastProgress = ContinuousClock.now
            var cursor: ItemChildrenCursor?
            while true {
                let page = try await store.childrenPage(
                    mediumUUID: mediumID,
                    parentID: parentID,
                    limit: Self.loadBatchSize,
                    after: cursor,
                    scope: scope
                )
                let rows = page.items
                cursor = page.nextCursor
                if rows.isEmpty, cursor == nil { break }
                let batch = rows.map { IndexedItem(stored: $0, parentPath: path) }
                accumulated.append(contentsOf: batch)
                let now = ContinuousClock.now
                if lastProgress.duration(to: now) >= Self.loadProgressInterval || cursor == nil {
                    loadingLoaded[key] = accumulated.count
                    lastProgress = now
                }
                if cursor == nil { break }
                await Task.yield()
                if loadGenerations[key, default: 0] != loadToken { return }
            }
            guard loadGenerations[key, default: 0] == loadToken else { return }
            remember(key, accumulated)
            stale.remove(key)
            if totalCount == 0, !accumulated.isEmpty {
                loadingTotals[key] = accumulated.count
            }
            DiskIndexLog.shared.perfIfSlow("children count=\(accumulated.count)", since: started)
        } catch is CancellationError {
            return
        } catch {
            guard loadGenerations[key, default: 0] == loadToken else { return }
            DiskIndexLog.shared.record(.store, .error, "children \(error)")
            loadErrors[key] = ProposalCopy.folderUnreadable
            if cache[key] == nil {
                cache[key] = []
                generation += 1
            }
        }
    }

    private func bumpLoadGeneration(_ key: String) {
        loadGenerations[key, default: 0] += 1
    }

    private func remember(_ key: String, _ items: [IndexedItem]) {
        cache[key] = items
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
        while cacheOrder.count > cacheFolderLimit {
            let oldest = cacheOrder.removeFirst()
            if oldest != key { cache[oldest] = nil }
        }
        generation += 1
    }

    private func cacheKey(_ mediumID: UUID, _ path: [String]) -> String {
        ([mediumID.uuidString] + path).joined(separator: "\u{0}")
    }

    #if DEBUG
    // MARK: - Spalten-Zustände (Demo)

    private func simulationChildrenReadOnly(mediumID: UUID, path: [String]) -> [IndexedItem] {
        let key = cacheKey(mediumID, path)
        if loading.contains(key) { return [] }
        if let cached = cache[key] { return cached }
        if path.isEmpty {
            return ColumnStateSimulation.rootItems(mediumID: mediumID)
        }
        return ColumnStateSimulation.children(mediumID: mediumID, path: path) ?? []
    }

    private func requestSimulationLoad(mediumID: UUID, path: [String]) {
        let key = cacheKey(mediumID, path)
        if ColumnStateSimulation.isLoadingColumnPath(path) {
            startSimulationLoadingColumn(mediumID: mediumID, key: key)
            return
        }
        if cache[key] != nil || loading.contains(key) { return }
        if path.isEmpty {
            remember(key, ColumnStateSimulation.rootItems(mediumID: mediumID))
            return
        }
        if let simulated = ColumnStateSimulation.children(mediumID: mediumID, path: path) {
            remember(key, simulated)
        } else {
            remember(key, [])
        }
    }

    private func startSimulationLoadingColumn(mediumID: UUID, key: String) {
        simulationLoadTasks[key]?.cancel()
        _ = loading.insert(key)
        cache[key] = nil
        cacheOrder.removeAll { $0 == key }
        bumpLoadGeneration(key)
        simulationLoadTasks[key] = Task {
            await loadSimulationLoadingColumn(mediumID: mediumID, key: key)
            simulationLoadTasks[key] = nil
        }
    }

    private func loadSimulationLoadingColumn(mediumID: UUID, key: String) async {
        loadingTotals[key] = ColumnStateSimulation.simulatedLoadingTotal
        loadingLoaded[key] = 0
        for loaded in ColumnStateSimulation.simulatedLoadingSteps {
            guard loading.contains(key) else { return }
            loadingLoaded[key] = loaded
            try? await Task.sleep(for: .milliseconds(280))
        }
        loadingLoaded[key] = ColumnStateSimulation.simulatedLoadingFrozenCount
        // Demo: Ladehinweis bleibt sichtbar (kein `remember`, `loading` bleibt gesetzt).
    }
    #endif
}
