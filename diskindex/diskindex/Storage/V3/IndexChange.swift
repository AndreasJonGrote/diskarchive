//
//  IndexChange.swift
//  diskindex
//
//  Meldungen der Speicherschicht (`IndexStoreV3.changes`): was sich im Index geändert hat.
//

import Foundation

struct IndexChangeEvent: Sendable {
    let change: IndexChange
    let generation: Int
}

enum IndexChange: Sendable, Equatable {
    case medium(UUID)
    /// `folderPaths`: Ordner, deren Kindliste sich geändert hat (leeres Array = Medienwurzel).
    case items(UUID, folderPaths: [[String]])
    case layer(medium: UUID, depth: Int)
    case counts(UUID)
    case removed(UUID)

    var mediumID: UUID {
        switch self {
        case .medium(let id), .items(let id, _), .counts(let id), .removed(let id):
            return id
        case .layer(let id, _):
            return id
        }
    }
}

/// Thread-sicherer Zähler für die Namensprüfung in Swift (Lesezugriffe laufen außerhalb des Actors).
/// Tests: ohne ausstehende Bereinigung bleibt er bei 0.
nonisolated final class NameCheckCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var total = 0

    func add(_ count: Int) {
        guard count > 0 else { return }
        lock.lock()
        total += count
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return total
    }
}
