//
//  AppState+Favorites.swift
//  diskindex
//
//  Aus AppState.swift aufgeteilt (Aufgabe 111). Keine Logikänderung.
//

import SwiftUI

extension AppState {
    // MARK: - Favoriten

    func isFavorite(_ target: ObjectContextTarget) -> Bool {
        switch target.kind {
        case .medium: medium(with: target.mediumID)?.isFavorite ?? false
        case .file, .folder:
            target.isFavorite
        }
    }

    func toggleFavorite(_ target: ObjectContextTarget) {
        DiskIndexLog.shared.ui("toggleFavorite kind=\(target.kind) id=\(target.id) rowID=\(target.rowID.map(String.init) ?? "-") view=\(mainWindowDestination)")
        switch target.kind {
        case .medium:
            updateMedium(id: target.mediumID, persist: true) { $0.isFavorite.toggle() }
        case .file, .folder:
            guard let rowID = target.rowID, let store = indexStore else {
                DiskIndexLog.shared.record(.store, .error, "toggleFavorite ohne Zeile id=\(target.id)")
                return
            }
            let next = !target.isFavorite
            indexRepository.setFavoriteLocally(mediumID: target.mediumID, id: target.id, isFavorite: next)
            Task {
                do {
                    try await store.setFavorite(itemID: rowID, next)
                    if next, let mount = mountPath?(target.mediumID) {
                        try await store.storePartialChecksum(itemID: rowID, mountPath: mount)
                    }
                } catch {
                    guard DiskIndexLog.isOperationalFailure(error) else { return }
                    DiskIndexLog.shared.record(.store, .error, "setFavorite \(error)")
                }
            }
        }
    }

    func toggleFavorites(_ targets: [ObjectContextTarget]) {
        guard !targets.isEmpty else { return }
        let next = FavoriteBatch.nextValue(current: targets.map { isFavorite($0) })
        DiskIndexLog.shared.ui("toggleFavorite kind=multi count=\(targets.count) next=\(next)")
        for target in targets where target.kind == .medium {
            updateMedium(id: target.mediumID, persist: true) { $0.isFavorite = next }
        }
        let objects = targets.filter { $0.kind != .medium }
        indexRepository.setFavoritesLocally(ids: objects.map(\.id), isFavorite: next)
        let rowIDs = objects.compactMap(\.rowID)
        guard let store = indexStore, !rowIDs.isEmpty else { return }
        Task {
            do {
                try await store.setFavorites(itemIDs: rowIDs, next)
                if next {
                    for object in objects {
                        guard let rowID = object.rowID, let mount = mountPath?(object.mediumID) else { continue }
                        try await store.storePartialChecksum(itemID: rowID, mountPath: mount)
                    }
                }
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { return }
                DiskIndexLog.shared.record(.store, .error, "setFavorites \(error)")
            }
        }
    }

}
