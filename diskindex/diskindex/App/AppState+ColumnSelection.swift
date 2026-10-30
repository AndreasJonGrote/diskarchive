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

    /// bug.0.4.213 (Finder): → auf einem einzeln gewählten, geöffneten Ordner wählt den ersten sichtbaren Eintrag der
    /// nächsten Spalte. Datei, Mehrfachauswahl, leerer oder nicht geöffneter Ordner: nichts. Rückgabe: neue Fokus-Spalte.
    @discardableResult
    func openColumnSelection(columnIndex: Int, items: [IndexedItem], medium: Medium) -> Int? {
        let state = columnBrowserState
        guard state.selection.ids.count == 1, state.selection.focusColumnIndex == columnIndex,
              let id = state.selection.ids.first,
              let folder = items.first(where: { $0.id == id }), folder.isFolder,
              columnIndex < state.pathStack.count, state.pathStack[columnIndex] == folder.name else { return nil }
        let path = Array(state.pathStack.prefix(columnIndex + 1))
        let next = indexRepository.children(mediumID: medium.id, path: path)
        let visible = ColumnBrowserFiltering.visibleItems(next, filters: searchState.filters)
        guard let first = visible.first else { return nil }
        var selection = ColumnSelection()
        selection.replace(id: first.id, column: columnIndex + 1)
        commitColumnSelection(selection, items: next, columnIndex: columnIndex + 1, medium: medium)
        return columnIndex + 1
    }

    /// bug.0.4.213 (Finder): ← wählt in der Spalte davor den Elternordner; Spalten rechts von dessen Inhalt schließen.
    /// In der ersten Spalte: nichts. Rückgabe: neue Fokus-Spalte.
    @discardableResult
    func selectColumnParent(columnIndex: Int, medium: Medium) -> Int? {
        let state = columnBrowserState
        guard columnIndex > 0, columnIndex <= state.pathStack.count else { return nil }
        let parentPath = Array(state.pathStack.prefix(columnIndex - 1))
        let items = indexRepository.children(mediumID: medium.id, path: parentPath)
        let name = state.pathStack[columnIndex - 1]
        guard let parent = items.first(where: { $0.isFolder && $0.name == name }) else { return nil }
        var selection = ColumnSelection()
        selection.replace(id: parent.id, column: columnIndex - 1)
        commitColumnSelection(selection, items: items, columnIndex: columnIndex - 1, medium: medium)
        return columnIndex - 1
    }
}
