//
//  ColumnSelection.swift
//  diskindex
//
//  Mehrfachauswahl in einer Ordnerspalte (Aufgabe 54).
//

import Foundation

struct ColumnSelection: Equatable {
    var ids: [UUID] = [] {
        didSet { idSet = Set(ids) }
    }
    /// Menge zu `ids` für `contains` in O(1) (bug.0.4.035: ⌘A in großen Ordnern ohne quadratischen Aufwand).
    private(set) var idSet: Set<UUID> = []
    var anchorID: UUID?
    var focusColumnIndex: Int?
    var lastClickedID: UUID?

    init(ids: [UUID] = [], anchorID: UUID? = nil, focusColumnIndex: Int? = nil, lastClickedID: UUID? = nil) {
        self.ids = ids
        idSet = Set(ids)
        self.anchorID = anchorID
        self.focusColumnIndex = focusColumnIndex
        self.lastClickedID = lastClickedID
    }

    func contains(_ id: UUID) -> Bool {
        idSet.contains(id)
    }

    /// Gewählte Objekte in Auswahlreihenfolge, über ein Dictionary statt Suche je ID.
    func ordered(in items: [IndexedItem]) -> [IndexedItem] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    var isMultiple: Bool { ids.count > 1 }

    mutating func replace(id: UUID, column: Int) {
        ids = [id]
        anchorID = id
        lastClickedID = id
        focusColumnIndex = column
    }

    mutating func commandClick(id: UUID, column: Int) {
        guard focusColumnIndex == column, !ids.isEmpty else {
            replace(id: id, column: column)
            return
        }
        if idSet.contains(id), let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
            if anchorID == id { anchorID = ids.first }
            if ids.isEmpty {
                focusColumnIndex = nil
                anchorID = nil
            }
        } else {
            ids.append(id)
            if anchorID == nil { anchorID = id }
            focusColumnIndex = column
        }
        lastClickedID = id
    }

    mutating func shiftClick(id: UUID, column: Int, visible: [UUID]) {
        guard focusColumnIndex == column, let anchorID, let start = visible.firstIndex(of: anchorID), let end = visible.firstIndex(of: id) else {
            replace(id: id, column: column)
            return
        }
        ids = Array(visible[min(start, end)...max(start, end)])
        lastClickedID = id
        focusColumnIndex = column
    }

    mutating func selectAll(visible: [UUID], column: Int) {
        ids = visible
        anchorID = visible.first
        lastClickedID = visible.last
        focusColumnIndex = visible.isEmpty ? nil : column
    }

    mutating func collapseToLastClicked() {
        guard ids.count > 1 else { return }
        let kept = lastClickedID.flatMap { idSet.contains($0) ? $0 : nil } ?? ids.last
        guard let kept else { return }
        ids = [kept]
        anchorID = kept
        lastClickedID = kept
    }

    mutating func move(step: Int, extend: Bool, visible: [UUID]) {
        guard let column = focusColumnIndex, !visible.isEmpty else { return }
        let current = lastClickedID ?? ids.last
        let index = current.flatMap { visible.firstIndex(of: $0) } ?? (step > 0 ? -1 : visible.count)
        let next = min(max(index + step, 0), visible.count - 1)
        let id = visible[next]
        if extend {
            shiftClick(id: id, column: column, visible: visible)
        } else {
            replace(id: id, column: column)
        }
    }

    mutating func dropInvisible(_ visible: Set<UUID>) {
        ids.removeAll { !visible.contains($0) }
        if let anchorID, !visible.contains(anchorID) { self.anchorID = ids.first }
        if let lastClickedID, !visible.contains(lastClickedID) { self.lastClickedID = ids.last }
        if ids.isEmpty { focusColumnIndex = nil }
    }
}

/// Finder-Parität: Pfadordner in jeder Spalte markiert (Fußzeilen-Breadcrumb = `pathStack` + Auswahl).
enum ColumnBrowserSelectionHighlight {
    static func isRowSelected(
        item: IndexedItem,
        columnIndex: Int,
        pathStack: [String],
        selection: ColumnSelection,
        selectedUncapturedFolderID: UUID?
    ) -> Bool {
        if selectedUncapturedFolderID == item.id { return true }
        if selection.contains(item.id) { return true }
        if columnIndex < pathStack.count, item.isFolder, item.name == pathStack[columnIndex] {
            return true
        }
        return false
    }

    /// Markierte IDs einer Spalte, einmal je Body statt je Zeile (bug.0.4.035).
    static func selectedIDs(
        items: [IndexedItem],
        columnIndex: Int,
        pathStack: [String],
        selection: ColumnSelection,
        selectedUncapturedFolderID: UUID?
    ) -> Set<UUID> {
        var result = Set<UUID>()
        for item in items where isRowSelected(
            item: item,
            columnIndex: columnIndex,
            pathStack: pathStack,
            selection: selection,
            selectedUncapturedFolderID: selectedUncapturedFolderID
        ) {
            result.insert(item.id)
        }
        return result
    }
}

struct ColumnPathEffect: Equatable {
    var path: [String]
    var uncapturedID: UUID?

    static func make(columnIndex: Int, existingPath: [String], selected: [IndexedItem], uncapturedFolder: Bool) -> ColumnPathEffect {
        let prefix = Array(existingPath.prefix(columnIndex))
        guard selected.count == 1, let item = selected.first else {
            return ColumnPathEffect(path: prefix, uncapturedID: nil)
        }
        if item.isFolder, uncapturedFolder {
            return ColumnPathEffect(path: prefix, uncapturedID: item.id)
        }
        if item.isFolder {
            return ColumnPathEffect(path: prefix + [item.name], uncapturedID: nil)
        }
        return ColumnPathEffect(path: prefix, uncapturedID: nil)
    }
}

enum ColumnFooterLabel {
    static func text(selectedCount: Int, visibleCount: Int, filteredCount: Int, totalCount: Int) -> String {
        if selectedCount > 1 {
            return LayoutCopy.columnSelectedOf(selectedCount, visibleCount)
        }
        return ObjectCountFormatting.label(filtered: filteredCount, total: totalCount)
    }
}

enum ColumnSizeSummary {
    static func totalBytes(_ items: [IndexedItem]) -> Int64 {
        items.reduce(0) { sum, item in
            guard !item.isFolder, let size = item.sizeBytes else { return sum }
            return sum + size
        }
    }

    static func objectLine(count: Int) -> String {
        count == 1 ? LayoutCopy.objectOne : LayoutCopy.objectMany(String(count))
    }
}

enum IgnoreBatch {
    /// Über Mengen statt `contains` auf Arrays (bug.0.4.035); Reihenfolge bleibt erhalten.
    static func applying(_ patterns: [String], to existing: [String]) -> [String] {
        var seen = Set<String>()
        let unique = patterns.filter { seen.insert($0).inserted }
        guard !unique.isEmpty else { return existing }
        let existingSet = Set(existing)
        if unique.allSatisfy(existingSet.contains) {
            return existing.filter { !seen.contains($0) }
        }
        return existing + unique.filter { !existingSet.contains($0) }
    }

    static func extensionPatterns(of targets: [ObjectContextTarget]) -> [String] {
        var seen = Set<String>()
        var patterns: [String] = []
        for target in targets {
            guard let ext = target.fileExtension else { continue }
            let pattern = AppState.ignorePattern(forExtension: ext)
            if seen.insert(pattern).inserted { patterns.append(pattern) }
        }
        return patterns
    }
}

enum FavoriteBatch {
    /// Alle schon Favorit → aus, sonst alle an.
    static func nextValue(current: [Bool]) -> Bool {
        !current.allSatisfy { $0 }
    }
}

struct ContextMenuPlan: Equatable {
    var finderEnabled: Bool
    var favoriteEnabled: Bool
    var favoriteChecked: Bool
    var searchNameEnabled: Bool
    var searchExtensionEnabled: Bool
    var ignoreNameEnabled: Bool
    var ignoreNameChecked: Bool
    var ignoreTypeEnabled: Bool
    var ignoreTypeChecked: Bool

    static func multiple(targets: [ObjectContextTarget], favorites: [Bool], ignored: [String]) -> ContextMenuPlan {
        let names = targets.map(\.name)
        let extensions = IgnoreBatch.extensionPatterns(of: targets)
        let ignoredSet = Set(ignored)
        let namesIgnored = !names.isEmpty && names.allSatisfy(ignoredSet.contains)
        let typesIgnored = !extensions.isEmpty && extensions.allSatisfy(ignoredSet.contains)
        return ContextMenuPlan(
            finderEnabled: false,
            favoriteEnabled: true,
            favoriteChecked: FavoriteBatch.nextValue(current: favorites) == false,
            searchNameEnabled: false,
            searchExtensionEnabled: false,
            ignoreNameEnabled: true,
            ignoreNameChecked: namesIgnored,
            ignoreTypeEnabled: !extensions.isEmpty,
            ignoreTypeChecked: typesIgnored
        )
    }
}
