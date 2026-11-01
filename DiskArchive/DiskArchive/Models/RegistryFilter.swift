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
    case type
    case indexing
}

struct RegistrySortState: Equatable {
    var column: RegistrySortColumn = .name
    var ascending: Bool = true
}
