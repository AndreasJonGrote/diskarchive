//
//  ColumnFolderOpenState.swift
//  diskindex
//
//  Spaltenansicht: Ordner noch nicht indiziert (grün) vs. bewusst nicht erfasst (gelb).
//

import Foundation

enum ColumnFolderUncapturedReason: Equatable {
    case scanDepth
    case excluded
    case unreadable
}

enum ColumnFolderOpenState: Equatable {
    case normal
    case uncaptured(ColumnFolderUncapturedReason)
    case pendingIndex

    static func resolve(
        columnIndex: Int,
        medium: Medium,
        settings: AppSettings,
        folderName: String? = nil,
        folderListedAt: Date? = nil,
        folderUnreadable: Bool = false
    ) -> ColumnFolderOpenState {
        #if DEBUG
        if let simulated = ColumnStateSimulation.resolveOpenState(mediumID: medium.id, folderName: folderName) {
            return simulated
        }
        #endif
        if folderUnreadable {
            return .uncaptured(.unreadable)
        }
        let folderDepth = columnIndex + 1
        if let name = folderName {
            let matcher = IgnoreMatcher(
                ignoreHiddenFiles: settings.ignoreHiddenFiles,
                excludedPatterns: settings.excludedPatterns,
                artifactsIgnored: settings.artifactsIgnored
            )
            if matcher.shouldSkip(name: name, isHidden: name.hasPrefix(".")) {
                return .uncaptured(.excluded)
            }
        }
        if let maxDepth = settings.indexedMaxDepth, folderDepth > maxDepth {
            return .uncaptured(.scanDepth)
        }
        if folderListedAt != nil {
            return .normal
        }
        guard medium.decision == .index else {
            return .uncaptured(.scanDepth)
        }
        return .pendingIndex
    }
}
