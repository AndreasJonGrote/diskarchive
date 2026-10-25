//
//  AppState+Favorites.swift
//  diskindex
//
//  Aus AppState.swift aufgeteilt (Aufgabe 111).
//  bug.0.4.037 (REPORT 80, 82): Favorit von Dateien/Ordnern aus `favoriteRowIDs` (alle Favoriten, nicht nur die
//  geladene Seite), Umschalten patcht Listen lokal; Verbindungsstatus wird abgeleitet, nicht gespeichert.
//

import SwiftUI

/// Momentaufnahme, ob eine Zeile Favorit ist — einmal je Body gebaut, je Zeile nur nachgeschlagen.
struct FavoriteLookup {
    var rowIDs: Set<Int64>?
    var editsBeforeLoad: [Int64: Bool]

    func isFavorite(rowID: Int64?, fallback: Bool) -> Bool {
        guard let rowID else { return fallback }
        if let rowIDs { return rowIDs.contains(rowID) }
        return editsBeforeLoad[rowID] ?? fallback
    }
}

extension AppState {
    // MARK: - Verbindung (abgeleitet)

    /// `mediumID → angeschlossen`, einmal je Body bzw. Aufruf (bug.0.4.037).
    var mediumConnectivity: [UUID: Bool] {
        Dictionary(media.map { ($0.id, $0.connectionStatus == .connected) }, uniquingKeysWith: { first, _ in first })
    }

    /// todo.0.4.046: Umfang der Ladeansicht der Favoriten – Medien des gewählten Verbindungsfilters und ihre Dateien.
    var favoritesLoadingScope: (media: Int, files: Int) {
        let online = mediumConnectivity
        let media = indexedMedia.filter { favoritesConnectionFilter.includes(isOnline: online[$0.id] ?? false) }
        return (media.count, media.reduce(0) { $0 + $1.fileCount })
    }

    /// todo.0.4.042: Umfang der Ladeansicht der Suche – die Medien, die diese Suche durchsucht (alle erfassten oder die
    /// im Medienfilter gewählten), und ihre Dateien.
    var searchLoadingScope: (media: Int, files: Int) {
        let filters = searchState.filters
        let media = indexedMedia.filter { SearchItemFilter.matchesMedium($0, filters: filters) }
        return (media.count, media.reduce(0) { $0 + $1.fileCount })
    }

    /// todo.0.4.042: Die Suche hat Kriterien, aber noch keine Treffer und keine abgeschlossene Suche für diese Treffermenge
    /// (Leerzustand) – die Ladeansicht steht schon im ersten Bild, bevor `runSearch` sie beginnt.
    var searchAwaitsFirstResults: Bool {
        guard !screenshotFrozenLists, searchMatch.items.isEmpty, searchMatch.media.isEmpty else { return false }
        let current = SearchCountRequest(query: searchState.submittedQuery, filters: searchState.filters)
        return !current.hasSameHits(as: shownSearch)
    }

    func isMediumOnline(_ id: UUID) -> Bool {
        medium(with: id)?.connectionStatus == .connected
    }

    // MARK: - Favoriten

    var favoriteLookup: FavoriteLookup {
        FavoriteLookup(rowIDs: favoriteRowIDs, editsBeforeLoad: favoriteEditsBeforeLoad)
    }

    func isFavorite(_ target: ObjectContextTarget) -> Bool {
        switch target.kind {
        case .medium: medium(with: target.mediumID)?.isFavorite ?? false
        case .file, .folder:
            favoriteLookup.isFavorite(rowID: target.rowID, fallback: target.isFavorite)
        }
    }

    /// Anfrage der Favoriten-Tabelle aus dem aktuellen Zustand (Verbindungsfilter → Medienkennungen).
    var currentFavoritesRequest: FavoritesRequest {
        FavoritesRequest(
            media: indexedMedia,
            connection: favoritesConnectionFilter,
            filters: searchState.filters,
            maxDepth: appSettings.indexedMaxDepth
        )
    }

    func toggleFavorite(_ target: ObjectContextTarget) {
        guard featureAccess.canWriteIndex else { return }
        DiskIndexLog.shared.ui("toggleFavorite kind=\(target.kind) id=\(target.id) rowID=\(target.rowID.map(String.init) ?? "-") view=\(mainWindowDestination)")
        switch target.kind {
        case .medium:
            updateMedium(id: target.mediumID, persist: true) { $0.isFavorite.toggle() }
        case .file, .folder:
            guard target.rowID != nil, indexStore != nil else {
                DiskIndexLog.shared.record(.store, .error, "toggleFavorite ohne Zeile id=\(target.id)")
                return
            }
            // Aus dem aktuellen Zustand, nicht aus dem beim Bau des Ziels (zweiter Klick setzt wieder, REPORT 80).
            setObjectsFavorite([target], !isFavorite(target))
        }
    }

    func toggleFavorites(_ targets: [ObjectContextTarget]) {
        guard featureAccess.canWriteIndex else { return }
        guard !targets.isEmpty else { return }
        let next = FavoriteBatch.nextValue(current: targets.map { isFavorite($0) })
        DiskIndexLog.shared.ui("toggleFavorite kind=multi count=\(targets.count) next=\(next)")
        for target in targets where target.kind == .medium {
            updateMedium(id: target.mediumID, persist: true) { $0.isFavorite = next }
        }
        setObjectsFavorite(targets.filter { $0.kind != .medium }, next)
    }

    /// Lokal sofort (Menge, Spalten-Cache, Suche, Favoriten-Seite), dann in die Datenbank (in Reihenfolge).
    private func setObjectsFavorite(_ objects: [ObjectContextTarget], _ next: Bool) {
        guard !objects.isEmpty else { return }
        let rowIDs = Set(objects.compactMap(\.rowID))
        favoriteEditGeneration += 1
        if var ids = favoriteRowIDs {
            if next { ids.formUnion(rowIDs) } else { ids.subtract(rowIDs) }
            favoriteRowIDs = ids
        } else {
            var edits = favoriteEditsBeforeLoad
            for rowID in rowIDs { edits[rowID] = next }
            favoriteEditsBeforeLoad = edits
        }
        if objects.count == 1, let only = objects.first {
            indexRepository.setFavoriteLocally(mediumID: only.mediumID, id: only.id, isFavorite: next)
        } else {
            indexRepository.setFavoritesLocally(ids: objects.map(\.id), isFavorite: next)
        }
        let pageRowIDs = Set(favoriteObjects.compactMap(\.item.rowID))
        // Neu gesetzt, abgewählt außerhalb der Seite oder eine volle Seite (dann rückt der nächste Favorit nach,
        // bug.0.3.9.006 e): nach dem Schreiben die Seite neu laden.
        let pageWasFull = favoriteObjects.count >= SearchIndex.pageLimit
        let reloadsPage = next || !rowIDs.isSubset(of: pageRowIDs) || pageWasFull
        patchListsFavorite(rowIDs: rowIDs, next)
        guard let store = indexStore, !rowIDs.isEmpty else { return }
        enqueueFavoriteWrite(store: store, objects: objects, rowIDs: Array(rowIDs), next, reloadsPage: reloadsPage)
        if favoriteRowIDs == nil { scheduleFavoriteIDsLoad() }
    }

    /// bug.0.3.9.006 b: Schreiben fehlgeschlagen — den lokalen Stand aus der Datenbank wiederherstellen (nicht einen
    /// gemerkten Vorher-Stand zurückspielen: schlagen mehrere Schreibvorgänge derselben Zeile fehl, stimmte die
    /// Reihenfolge nicht). Nach der Kette Kennungen neu lesen, dann Spalten-Cache, Suche und Favoriten-Seite angleichen.
    private func restoreFavoritesFromStore(objects: [ObjectContextTarget], next: Bool, error: Error) {
        DiskIndexLog.shared.record(.store, .error, "setFavorites fehlgeschlagen, Stand aus der Datenbank count=\(objects.count) next=\(next) \(DiskIndexLog.errorSummary(error))")
        favoriteEditGeneration += 1
        let previousRestore = favoriteRestoreTask
        favoriteRestoreTask = Task { [weak self] in
            await previousRestore?.value
            guard let self else { return }
            await self.reloadFavoriteIDs()
            guard let ids = self.favoriteRowIDs else { return }
            for isFavorite in [true, false] {
                let matching = objects.filter { ($0.rowID.map(ids.contains) ?? false) == isFavorite }
                if !matching.isEmpty { self.indexRepository.setFavoritesLocally(ids: matching.map(\.id), isFavorite: isFavorite) }
            }
            let rowIDs = Set(objects.compactMap(\.rowID))
            let searchIndices = self.searchMatch.items.indices.filter { index in
                self.searchMatch.items[index].item.rowID.map(rowIDs.contains) ?? false
            }
            if !searchIndices.isEmpty {
                var items = self.searchMatch.items
                for index in searchIndices {
                    if let rowID = items[index].item.rowID { items[index].item.isFavorite = ids.contains(rowID) }
                }
                self.searchMatch.items = items
            }
            // Abgewählte Zeilen kommen zurück, neu gesetzte verschwinden: die Seite fragt neu ab.
            if self.mainWindowDestination == .favorites { await self.reloadFavoritePage() }
        }
    }

    /// Suche und Favoriten-Seite: Favorit an den Zeilen umstellen; abgewählte Favoriten verschwinden sofort.
    private func patchListsFavorite(rowIDs: Set<Int64>, _ next: Bool) {
        let searchIndices = searchMatch.items.indices.filter { index in
            searchMatch.items[index].item.rowID.map(rowIDs.contains) ?? false
        }
        if !searchIndices.isEmpty {
            var items = searchMatch.items
            for index in searchIndices { items[index].item.isFavorite = next }
            searchMatch.items = items
        }
        guard !next else { return }
        let kept = favoriteObjects.filter { !($0.item.rowID.map(rowIDs.contains) ?? false) }
        let removed = favoriteObjects.count - kept.count
        guard removed > 0 else { return }
        favoriteObjects = kept
        if let count = favoriteItemCount { favoriteItemCount = max(0, count - removed) }
        if let count = favoriteUnfilteredCount { favoriteUnfilteredCount = max(0, count - removed) }
    }

    /// Schreibvorgänge laufen nacheinander (`favoriteWriteTail`), damit das Nachladen der Kennungen (`reloadFavoriteIDs`)
    /// erst nach ihnen liest. Prüfsummen (Datei-I/O) laufen danach getrennt und halten die Kette nicht auf.
    private func enqueueFavoriteWrite(
        store: IndexStoreV3,
        objects: [ObjectContextTarget],
        rowIDs: [Int64],
        _ next: Bool,
        reloadsPage: Bool
    ) {
        let tail = favoriteWriteTail
        let writeKey = UUID()
        let write = Task { [weak self] in
            // bug.0.3.9.006 c: fertige Aufgaben entfernen sich selbst.
            defer { self?.favoriteChecksumTasks[writeKey] = nil }
            await tail?.value
            do {
                try await store.setFavorites(itemIDs: rowIDs, next)
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { return }
                self?.restoreFavoritesFromStore(objects: objects, next: next, error: error)
                return
            }
            // Neu gesetzter Favorit oder abgewählter außerhalb der Seite: die sichtbare Favoriten-Seite holt Zeilen und
            // Zahl neu (Position nach Name kennt nur die Abfrage). Eigene Aufgabe: das Neuladen wartet auf die Kette.
            guard reloadsPage, let self, self.mainWindowDestination == .favorites else { return }
            self.favoritePageReloadTask = Task { [weak self] in await self?.reloadFavoritePage() }
        }
        favoriteWriteTail = write
        favoriteChecksumTasks[writeKey] = write
        guard next else { return }
        let mounts = objects.compactMap { object -> (Int64, String)? in
            guard let rowID = object.rowID, let mount = mountPath?(object.mediumID) else { return nil }
            return (rowID, mount)
        }
        guard !mounts.isEmpty else { return }
        let checksumKey = UUID()
        let checksums = Task { [weak self] in
            defer { self?.favoriteChecksumTasks[checksumKey] = nil }
            await write.value
            do {
                for (rowID, mount) in mounts {
                    try Task.checkCancellation()
                    try await store.storePartialChecksum(itemID: rowID, mountPath: mount)
                }
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { return }
                DiskIndexLog.shared.record(.store, .error, "setFavorite \(DiskIndexLog.errorSummary(error))")
            }
        }
        favoriteChecksumTasks[checksumKey] = checksums
    }

    private func scheduleFavoriteIDsLoad() {
        guard favoriteIDsLoadTask == nil else { return }
        favoriteIDsLoadTask = Task { [weak self] in
            await self?.reloadFavoriteIDs()
            self?.favoriteIDsLoadTask = nil
        }
    }

    /// Alle Favoriten-Kennungen aus der Datenbank, nach den ausstehenden Schreibvorgängen. Kam währenddessen ein
    /// Umschalten dazu, wird neu gelesen (sonst überschriebe ein alter Stand die lokale Änderung).
    func reloadFavoriteIDs() async {
        while let store = indexStore {
            let generation = favoriteEditGeneration
            await favoriteWriteTail?.value
            let ids: Set<Int64>
            do {
                ids = try await store.favoriteItemIDs()
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.store, .error, "favoriteItemIDs \(DiskIndexLog.errorSummary(error))")
                }
                return
            }
            guard store === indexStore else { return }
            guard generation == favoriteEditGeneration else { continue }
            if favoriteRowIDs != ids { favoriteRowIDs = ids }
            if !favoriteEditsBeforeLoad.isEmpty { favoriteEditsBeforeLoad = [:] }
            return
        }
    }

    /// bug.0.3.9.006 d: Beenden wartet auf die Favoriten-Schreibkette, höchstens `timeout` (wie bug.0.4.033: erst
    /// sichern, dann abbauen). `false` = Zeitgrenze erreicht (Protokollzeile), die Kette läuft dann nicht weiter mit.
    @discardableResult
    func waitForFavoriteWriteTail(timeout: Duration) async -> Bool {
        // Eine Frist für alle Runden (kommt während des Wartens ein Schreibvorgang dazu, gilt nur die Restzeit).
        let deadline = ContinuousClock.now + timeout
        while let tail = favoriteWriteTail {
            let remaining = ContinuousClock.now.duration(to: deadline)
            let finished = remaining > .zero ? await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                let once = FavoriteTailResumeOnce(continuation)
                let timer = Task { try? await Task.sleep(for: remaining); once.resume(false) }
                Task { await tail.value; once.resume(true); timer.cancel() }
            } : false
            guard finished else {
                DiskIndexLog.shared.record(.store, .error, "favoriten beenden zeitgrenze after=\(timeout)")
                return false
            }
            if favoriteWriteTail == tail { return true }
        }
        return true
    }

    #if DEBUG
    /// Tests: wartet auf alle ausstehenden Favoriten-Schreibvorgänge und das Nachladen der Kennungen.
    func waitForFavoriteWrites() async {
        while let tail = favoriteWriteTail {
            await tail.value
            if favoriteWriteTail == tail { break }
        }
        while let load = favoriteIDsLoadTask {
            await load.value
            if favoriteIDsLoadTask == load { break }
        }
        while let restore = favoriteRestoreTask {
            await restore.value
            if favoriteRestoreTask == restore { break }
        }
        while let reload = favoritePageReloadTask {
            await reload.value
            if favoritePageReloadTask == reload { break }
        }
    }
    #endif
}


/// Setzt eine Continuation höchstens einmal fort (Favoriten-Kette gegen Zeitgrenze, bug.0.3.9.006 d).
nonisolated private final class FavoriteTailResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?

    init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: Bool) {
        let pending: CheckedContinuation<Bool, Never>? = lock.withLock {
            let current = continuation
            continuation = nil
            return current
        }
        pending?.resume(returning: value)
    }
}
