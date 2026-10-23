//
//  AppState+ColumnSelection.swift
//  diskindex
//
//  bug.0.4.148: Auswahl und Tastenlogik der Spaltenansicht liegen im `AppState` (testbar ohne Ansicht). Nutzeraktionen
//  (Klick, Taste) erhöhen `columnScrollToken` – nur sie lösen das Scrollen aus; Nachführen bei Live-Änderungen nicht.
//

import Foundation

extension AppState {
    /// Zustand eines Ordners in der Spalte (Scan-Tiefe, noch nicht indiziert, nicht lesbar …).
    func columnFolderOpenState(
        columnIndex: Int,
        medium: Medium,
        folderName: String? = nil,
        folderListedAt: Date? = nil,
        folderUnreadable: Bool = false
    ) -> ColumnFolderOpenState {
        ColumnFolderOpenState.resolve(
            columnIndex: columnIndex,
            medium: medium,
            settings: appSettings,
            folderName: folderName,
            folderListedAt: folderListedAt,
            folderUnreadable: folderUnreadable
        )
    }

    /// Übernimmt die Auswahl einer Spalte samt Pfadwirkung. `userInitiated`: Klick oder Taste → Scroll-Auftrag; das
    /// Nachführen der Auswahl bei Live-Änderungen (`false`) scrollt nicht.
    func commitColumnSelection(
        _ selection: ColumnSelection,
        items: [IndexedItem],
        columnIndex: Int,
        medium: Medium,
        userInitiated: Bool = true
    ) {
        var state = columnBrowserState
        let ordered = selection.ordered(in: items)
        let folder = ordered.count == 1 ? ordered[0] : nil
        let open = columnFolderOpenState(
            columnIndex: columnIndex,
            medium: medium,
            folderName: folder?.name,
            folderListedAt: folder?.listedAt,
            folderUnreadable: folder?.unreadable ?? false
        )
        let uncaptured: Bool = {
            guard ordered.count == 1, ordered[0].isFolder else { return false }
            if case .uncaptured = open { return true }
            return false
        }()
        let effect = ColumnPathEffect.make(
            columnIndex: columnIndex,
            existingPath: state.pathStack,
            selected: ordered,
            uncapturedFolder: uncaptured
        )
        state.selection = selection
        // Zeilenkennungen der offenen Ordner mitführen (bug.0.4.147): bis zu dieser Spalte behalten, dann der gewählte Ordner.
        var knownIDs = Array(state.openFolderRowIDs.prefix(columnIndex))
        if knownIDs.count == columnIndex, ordered.count == 1, let folder = ordered.first, folder.isFolder, let rowID = folder.rowID {
            knownIDs.append(rowID)
        }
        state.pathStack = effect.path
        state.openFolderRowIDs = knownIDs
        state.selectedUncapturedFolderID = effect.uncapturedID
        columnBrowserState = state
        if userInitiated { columnScrollToken += 1 }
        DiskIndexLog.shared.ui("selection count=\(selection.ids.count) column=\(columnIndex)")
    }

    /// Pfeiltaste: Auswahl um `step` bewegen (mit `extend` erweitern) und zur neuen Auswahl scrollen.
    func moveColumnSelection(
        step: Int,
        extend: Bool,
        items: [IndexedItem],
        visible: [IndexedItem],
        columnIndex: Int,
        medium: Medium
    ) {
        var selection = columnBrowserState.selection
        selection.move(step: step, extend: extend, visible: visible.map(\.id), column: columnIndex)
        commitColumnSelection(selection, items: items, columnIndex: columnIndex, medium: medium)
    }
}
