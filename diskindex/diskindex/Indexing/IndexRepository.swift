//
//  IndexRepository.swift
//  diskindex
//

import Foundation
import SwiftUI

/// Zwischenspeicher für Ordnerinhalte. Die Spaltenansicht liest synchron, das Laden läuft danach.
@MainActor
@Observable
final class IndexRepository {
    private var store: IndexStoreV3?
    private var cache: [String: [IndexedItem]] = [:]
    /// Reihenfolge der letzten Nutzung (bug.0.4.036); Lesen in `children` setzt nach hinten. Nicht beobachtet:
    /// das Umsortieren beim Lesen im Body darf keine neue Darstellung auslösen (Regel 15).
    @ObservationIgnored private var cacheOrder: [String] = []
    /// bug.0.4.131: nach dem Neulesen einer Spalte (Medium, Pfad, alter Stand, neuer Stand) – `AppState` prüft damit den
    /// offenen Pfad (gelöschter oder umbenannter Ordner).
    @ObservationIgnored var onColumnReloaded: ((UUID, [String], [IndexedItem]?, [IndexedItem]) -> Void)?
    /// Schlüssel der sichtbaren Spalten (`pathStack`): werden nie verdrängt (bug.0.4.036).
    @ObservationIgnored private var pinnedKeys: Set<String> = []
    /// Welcher Lade-Token `loading` für einen Schlüssel gesetzt hat; nur dieser Load räumt ab (bug.0.4.036, 98).
    @ObservationIgnored private var loadingOwner: [String: UInt] = [:]
    /// bug.0.4.088: Wird die Regel enger (Ignorieren, Unsichtbare, Artefakte, Tiefe), verschwinden betroffene Einträge
    /// sofort aus den geladenen Spalten – an Ort und Stelle, ohne Neuladen und ohne Ladefläche. Die Warteschlange
    /// (`status = 1`) läuft im Hintergrund; danach liest `markAllStale` die Spalten ohne Leeren neu.
    var scope = IndexScope.revealAll {
        didSet {
            guard scope.maxDepth != oldValue.maxDepth || scope.matcher != oldValue.matcher else { return }
            hideCachedItems(by: scope)
        }
    }
    /// bug.0.4.088: Während der Regel-Warteschlange trägt die Datenbank noch alte Stände (`status` noch nicht
    /// umgestellt); neu geladene Spalten werden darum zusätzlich nach `scope` gefiltert. Setzt `AppState`.
    var hidesLoadsByScope = false
    /// Regel-Warteschlange (234): keine neuen Spalten-Ladevorgänge starten.
    var blocksLoadsForRuleReconcile = false
    private var loading: Set<String> = []
    private var loadingLoaded: [String: Int] = [:]
    private var loadingTotals: [String: Int] = [:]
    private var loadErrors: [String: String] = [:]
    private(set) var stale: Set<String> = []
    private(set) var generation = 0
    private var loadGenerations: [String: UInt] = [:]
    private let cacheFolderLimit = 30
    #if DEBUG
    // bug.0.3.8.007: Zähler je Instanz statt prozessweit — parallele Suiten teilen den Prozess
    // und würden sonst die Zählung fremder AppStates mitzählen (Regel 20).
    private(set) var loadSessionsStartedForTesting = 0
    private(set) var loadSessionsCompletedForTesting = 0
    private(set) var requestLoadCallsForTesting = 0

    /// Tests (245): Pause vor missing-folder-Cache-Write, damit `invalidateAll` dazwischen laufen kann.
    /// bug.0.3.8.007: je Instanz statt prozessweit — sonst hält der Schalter Ladevorgänge paralleler Suiten an.
    var awaitMissingFolderCacheGateForTesting: (() async -> Void)?
    /// Tests (bug.0.3.9.007 c): Schritte des Loads rund um den Fortschritt — `.counted` nach der Zählung (vor dem
    /// ersten Schreiben), `.page` nach jeder Seite (nach dem Schreiben, vor dem Yield).
    var loadProgressStepForTesting: ((LoadProgressStep) async -> Void)?

    enum LoadProgressStep: Equatable {
        case counted
        case page
    }
    #endif
    /// Sequentiell aus der DB, damit sehr große Ordner den Ladevorgang nicht abbrechen.
    static let loadBatchSize = 2_000
    /// UI-Aktualisierung des Ladestands (T1: höchstens alle 100 ms).
    private static let loadProgressInterval: Duration = .milliseconds(100)

    init(store: IndexStoreV3?) {
        self.store = store
    }

    func replaceStore(_ store: IndexStoreV3?) {
        // Generationen erhöhen statt löschen (bug.0.4.036, 98): ein Load des alten Stores darf mit seinem Token
        // nichts mehr schreiben und den Ladezustand eines neuen Loads nicht abräumen.
        for key in Set(loading).union(loadGenerations.keys).union(cache.keys) {
            bumpLoadGeneration(key)
        }
        self.store = store
        cache.removeAll()
        cacheOrder.removeAll()
        loading.removeAll()
        loadingOwner.removeAll()
        loadingLoaded.removeAll()
        loadingTotals.removeAll()
        loadErrors.removeAll()
        generation += 1
    }

    /// Nur Cache/Ladezustand lesen — kein Nachladen aus dem View-Aufbau (109).
    func children(mediumID: UUID, path: [String]) -> [IndexedItem] {
        let key = cacheKey(mediumID, path)
        if let cached = cache[key] {
            touch(key)
            return cached
        }
        if loading.contains(key) { return [] }
        return []
    }

    /// Ordner ist geladen (im Cache und nicht im Laden) — erst dann darf die Auswahl beschnitten werden.
    func hasLoadedChildren(mediumID: UUID, path: [String]) -> Bool {
        let key = cacheKey(mediumID, path)
        return cache[key] != nil && !loading.contains(key)
    }

    /// Sichtbare Spalten (Wurzel und jede Stufe von `pathStack`) vor dem Verdrängen schützen (bug.0.4.036).
    func pinVisibleColumns(mediumID: UUID?, pathStack: [String]) {
        guard let mediumID else {
            pinnedKeys = []
            return
        }
        pinnedKeys = Set((0...pathStack.count).map { cacheKey(mediumID, Array(pathStack.prefix($0))) })
    }

    func requestLoad(mediumID: UUID, path: [String]) {
        if blocksLoadsForRuleReconcile { return }
        #if DEBUG
        requestLoadCallsForTesting += 1
        #endif
        let key = cacheKey(mediumID, path)
        if loading.contains(key) { return }
        let needsLoad = cache[key] == nil || stale.contains(key)
        if !needsLoad { return }
        guard store != nil, loading.insert(key).inserted else { return }
        // Token hier binden: sonst liest `load` nach `invalidateAll` die neue Generation und schreibt trotzdem.
        let loadToken = loadGenerations[key, default: 0]
        loadingOwner[key] = loadToken
        Task { await load(mediumID: mediumID, path: path, key: key, loadToken: loadToken) }
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
        loadingOwner = loadingOwner.filter { !$0.key.hasPrefix(prefix) }
        loadingLoaded = loadingLoaded.filter { !$0.key.hasPrefix(prefix) }
        loadingTotals = loadingTotals.filter { !$0.key.hasPrefix(prefix) }
        loadErrors = loadErrors.filter { !$0.key.hasPrefix(prefix) }
        for key in keys { bumpLoadGeneration(key) }
        generation += 1
    }

    func invalidate(mediumID: UUID, path: [String]) {
        let key = cacheKey(mediumID, path)
        stale.insert(key)
        loading.remove(key)
        loadingOwner[key] = nil
        loadingLoaded[key] = nil
        loadingTotals[key] = nil
        loadErrors[key] = nil
        bumpLoadGeneration(key)
        generation += 1
    }

    func invalidateAll() {
        for key in Set(loading).union(loadGenerations.keys).union(cache.keys) {
            bumpLoadGeneration(key)
        }
        cache.removeAll()
        cacheOrder.removeAll()
        // `loading` bleibt: laufende Loads beenden sich per Token und räumen selbst auf.
        // Sonst kann ein zweiter Load starten, während der erste noch läuft (bug.0.4.010).
        loadingLoaded.removeAll()
        loadingTotals.removeAll()
        loadErrors.removeAll()
        generation += 1
    }

    /// Beenden: Demo-Lade-Tasks und laufende Ordner-Ladevorgänge abbrechen.
    func prepareForTermination() {
        for key in loading {
            bumpLoadGeneration(key)
        }
        loading.removeAll()
        loadingOwner.removeAll()
    }

    #if DEBUG
    func hasCachedChildren(mediumID: UUID, path: [String]) -> Bool {
        cache[cacheKey(mediumID, path)] != nil
    }

    /// Tests — Ladezustand ohne IndexStoreV3 (Aufgabe 156).
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

    /// Bildschirmfotos — Ordnerinhalte ohne IndexStoreV3.
    func seedScreenshotCache(mediumID: UUID, entries: [([String], [IndexedItem])]) {
        for (path, items) in entries {
            remember(cacheKey(mediumID, path), items)
        }
    }
    #endif

    /// Tests lesen einen Ordner, ohne auf den Cache-Task zu warten.
    func loadChildren(mediumID: UUID, path: [String]) async -> [IndexedItem] {
        let key = cacheKey(mediumID, path)
        requestLoad(mediumID: mediumID, path: path)
        while loading.contains(key) {
            await Task.yield()
        }
        return cache[key] ?? []
    }

    private func load(mediumID: UUID, path: [String], key: String, loadToken: UInt) async {
        #if DEBUG
        loadSessionsStartedForTesting += 1
        #endif
        defer {
            // Nur der Load, der `loading` gesetzt hat, räumt ab (bug.0.4.036, 98). Nach `invalidateAll` bleibt der
            // Eigentümer bestehen, der alte Load räumt also weiter selbst auf.
            if loadingOwner[key] == loadToken {
                loading.remove(key)
                loadingOwner[key] = nil
                loadingLoaded[key] = nil
                loadingTotals[key] = nil
            }
            #if DEBUG
            loadSessionsCompletedForTesting += 1
            #endif
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
                    #if DEBUG
                    if let gate = awaitMissingFolderCacheGateForTesting {
                        await gate()
                    }
                    #endif
                    guard loadGenerations[key, default: 0] == loadToken else { return }
                    cache[key] = []
                    return
                }
            }
            let totalCount = try await store.childCount(mediumUUID: mediumID, parentID: parentID, scope: scope)
            #if DEBUG
            if let step = loadProgressStepForTesting {
                await step(.counted)
            }
            #endif
            // Fortschritt nur für den eigenen Load schreiben (bug.0.4.036): nach `replaceStore` gehört der Schlüssel
            // keinem bzw. einem neueren Load. bug.0.3.9.007 c: nach `invalidateAll` bleibt der Eigentümer, aber die
            // Generation ist weiter — der alte Load füllt den geleerten Fortschritt nicht wieder.
            let ownsProgress = { self.loadingOwner[key] == loadToken && self.loadGenerations[key, default: 0] == loadToken }
            if ownsProgress() {
                loadingTotals[key] = totalCount
                loadingLoaded[key] = 0
            }

            let parentDirectoryPath = path.isEmpty ? "/" : "/" + path.joined(separator: "/") + "/"
            var accumulated: [IndexedItem] = []
            var lastProgress = ContinuousClock.now
            var cursor: ItemChildrenCursor?
            while true {
                let page = try await store.childrenPage(
                    mediumUUID: mediumID,
                    parentID: parentID,
                    limit: Self.loadBatchSize,
                    after: cursor,
                    scope: scope,
                    parentDirectoryPath: parentDirectoryPath
                )
                let rows = page.items
                cursor = page.nextCursor
                if rows.isEmpty, cursor == nil { break }
                let batch = rows.map { IndexedItem(stored: $0, parentPath: path) }
                accumulated.append(contentsOf: batch)
                let now = ContinuousClock.now
                if lastProgress.duration(to: now) >= Self.loadProgressInterval || cursor == nil, ownsProgress() {
                    loadingLoaded[key] = accumulated.count
                    lastProgress = now
                }
                #if DEBUG
                if let step = loadProgressStepForTesting {
                    await step(.page)
                }
                #endif
                if cursor == nil { break }
                await Task.yield()
                if loadGenerations[key, default: 0] != loadToken { return }
            }
            guard loadGenerations[key, default: 0] == loadToken else { return }
            if hidesLoadsByScope {
                let scope = self.scope
                accumulated.removeAll { scope.shouldHide(name: $0.name, depth: $0.parentPath.count + 1) }
            }
            let previous = cache[key]
            remember(key, accumulated)
            // invalidateAll may race between the guard and remember; drop stale write.
            if loadGenerations[key, default: 0] != loadToken {
                forgetCached(key)
                return
            }
            stale.remove(key)
            onColumnReloaded?(mediumID, path, previous, accumulated)
            if totalCount == 0, !accumulated.isEmpty, ownsProgress() {
                loadingTotals[key] = accumulated.count
            }
            DiskIndexLog.shared.perfIfSlow("children count=\(accumulated.count)", since: started)
        } catch is CancellationError {
            return
        } catch {
            guard loadGenerations[key, default: 0] == loadToken else { return }
            DiskIndexLog.shared.record(.store, .error, "children \(DiskIndexLog.errorSummary(error))")
            loadErrors[key] = LayoutCopy.folderUnreadable
            if cache[key] == nil {
                cache[key] = []
                generation += 1
            }
            if loadGenerations[key, default: 0] != loadToken {
                forgetCached(key)
                loadErrors.removeValue(forKey: key)
                return
            }
        }
    }

    private func bumpLoadGeneration(_ key: String) {
        loadGenerations[key, default: 0] += 1
    }

    private func hideCachedItems(by scope: IndexScope) {
        var changed = false
        for (key, items) in cache {
            let kept = items.filter { !scope.shouldHide(name: $0.name, depth: $0.parentPath.count + 1) }
            guard kept.count != items.count else { continue }
            withAnimation(Self.rowChangeAnimation) { cache[key] = kept }
            changed = true
        }
        if changed { generation += 1 }
    }

    /// Alle geladenen Spalten veraltet, nicht leer (README „Invalidieren heißt veraltet, nicht leeren“): sie bleiben
    /// sichtbar und werden im Hintergrund neu gelesen; das Ergebnis ersetzt sie an Ort und Stelle (bug.0.4.088).
    func markAllStale() {
        for key in cache.keys {
            stale.insert(key)
            bumpLoadGeneration(key)
        }
        // Laufende Loads lesen evtl. noch alte Stände: sie dürfen nicht mehr schreiben, ihr Schlüssel lädt neu.
        for key in loading {
            stale.insert(key)
            bumpLoadGeneration(key)
        }
        loading.removeAll()
        loadingOwner.removeAll()
        loadingLoaded.removeAll()
        loadingTotals.removeAll()
        loadErrors.removeAll()
        generation += 1
    }

    /// Kurzes Weggleiten bzw. Erscheinen der Zeilen, wenn eine geladene Spalte ersetzt wird (bug.0.4.088).
    static let rowChangeAnimation = Animation.easeOut(duration: 0.2)

    private func remember(_ key: String, _ items: [IndexedItem]) {
        if cache[key] != nil {
            // Neu gelesener Stand einer schon sichtbaren Spalte: Zeilen kommen und gehen an ihrem Platz.
            withAnimation(Self.rowChangeAnimation) { cache[key] = items }
        } else {
            cache[key] = items
        }
        touch(key)
        // Den am längsten nicht gelesenen Schlüssel verdrängen, nie eine sichtbare Spalte (bug.0.4.036).
        while cacheOrder.count > cacheFolderLimit,
              let victim = cacheOrder.firstIndex(where: { $0 != key && !pinnedKeys.contains($0) }) {
            cache[cacheOrder.remove(at: victim)] = nil
        }
        generation += 1
    }

    private func touch(_ key: String) {
        if cacheOrder.last == key { return }
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
    }

    private func forgetCached(_ key: String) {
        cache.removeValue(forKey: key)
        cacheOrder.removeAll { $0 == key }
        generation += 1
    }

    private func cacheKey(_ mediumID: UUID, _ path: [String]) -> String {
        ([mediumID.uuidString] + path).joined(separator: "\u{0}")
    }
}
