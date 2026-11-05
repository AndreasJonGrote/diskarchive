//
//  RegistryFilter.swift
//  DiskArchive
//

import Foundation

enum RegistryFilter: String, CaseIterable, Identifiable {
    case all
    case indexed
    case offline
    case notAllowed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: LayoutCopy.filterAll
        case .indexed: LayoutCopy.filterIndexed
        case .offline: LayoutCopy.filterOffline
        case .notAllowed: LayoutCopy.filterNotAllowed
        }
    }

    func matches(_ medium: Medium) -> Bool {
        switch self {
        case .all:
            return true
        case .indexed:
            return medium.indexStatus == .indexed && medium.hasIndex
        case .offline:
            return medium.connectionStatus == .offline && medium.hasIndex
        case .notAllowed:
            return !medium.allowIndexing
        }
    }
}

enum RegistrySortColumn: String, CaseIterable {
    case name
    /// todo.0.4.3.018 (Layout 05.02): „Zuletzt gesehen“ – angeschlossene zuerst („jetzt“), dann jüngstes Datum zuerst.
    case lastSeen
    case indexing
}

struct RegistrySortState: Equatable {
    var column: RegistrySortColumn = .name
    var ascending: Bool = true

    func sorted(_ media: [Medium]) -> [Medium] {
        media.sorted { lhs, rhs in
            let ordered: Bool
            switch column {
            case .name:
                ordered = lhs.shownName.localizedCaseInsensitiveCompare(rhs.shownName) == .orderedAscending
            case .lastSeen:
                ordered = Self.seenRank(lhs) > Self.seenRank(rhs)
            case .indexing:
                ordered = lhs.allowIndexing && !rhs.allowIndexing
            }
            return ascending ? ordered : !ordered
        }
    }

    /// Angeschlossen = jetzt (größter Wert), ohne Datum ganz hinten.
    private static func seenRank(_ medium: Medium) -> Double {
        if medium.connectionStatus == .connected { return .greatestFiniteMagnitude }
        return medium.lastSeenAt?.timeIntervalSinceReferenceDate ?? -.greatestFiniteMagnitude
    }
}
