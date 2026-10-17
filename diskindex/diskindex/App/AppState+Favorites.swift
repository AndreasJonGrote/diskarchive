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
        let reloadsPage = next || !rowIDs.isSubset(of: pageRowIDs)
        patchListsFavorite(rowIDs: rowIDs, next)
        guard let store = indexStore, !rowIDs.isEmpty else { return }
        enqueueFavoriteWrite(store: store, objects: objects, rowIDs: Array(rowIDs), next, reloadsPage: reloadsPage)
        if favoriteRowIDs == nil { scheduleFavoriteIDsLoad() }
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
        let previous = favoriteWriteTail
        let write = Task { [weak self] in
            await previous?.value
            do {
                try await store.setFavorites(itemIDs: rowIDs, next)
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { return }
                DiskIndexLog.shared.record(.store, .error, "setFavorites \(error)")
                return
            }
            // Neu gesetzter Favorit oder abgewählter außerhalb der Seite: die sichtbare Favoriten-Seite holt Zeilen und
            // Zahl neu (Position nach Name kennt nur die Abfrage). Eigene Aufgabe: das Neuladen wartet auf die Kette.
            guard reloadsPage, let self, self.mainWindowDestination == .favorites else { return }
            self.favoritePageReloadTask = Task { [weak self] in await self?.reloadFavoritePage() }
        }
        favoriteWriteTail = write
        favoriteChecksumTasks.append(write)
        guard next else { return }
        let mounts = objects.compactMap { object -> (Int64, String)? in
            guard let rowID = object.rowID, let mount = mountPath?(object.mediumID) else { return nil }
            return (rowID, mount)
        }
        guard !mounts.isEmpty else { return }
        let checksums = Task {
            await write.value
            do {
                for (rowID, mount) in mounts {
                    try Task.checkCancellation()
                    try await store.storePartialChecksum(itemID: rowID, mountPath: mount)
                }
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { return }
                DiskIndexLog.shared.record(.store, .error, "setFavorite \(error)")
            }
        }
        favoriteChecksumTasks.append(checksums)
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
                    DiskIndexLog.shared.record(.store, .error, "favoriteItemIDs \(error)")
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
        while let reload = favoritePageReloadTask {
            await reload.value
            if favoritePageReloadTask == reload { break }
        }
    }
    #endif
}
