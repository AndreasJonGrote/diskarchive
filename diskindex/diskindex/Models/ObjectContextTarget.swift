//
//  ObjectContextTarget.swift
//  diskindex
//

import Foundation

struct ObjectContextTarget: Identifiable, Hashable {
    enum Kind: Hashable {
        case medium
        case folder
        case file
    }

    let id: UUID
    let name: String
    let kind: Kind
    let mediumID: UUID
    let isMediumOnline: Bool
    var rowID: Int64?
    var isFavorite: Bool = false
    /// Gespeicherter Pfad ab der Medium-Wurzel, z. B. `/Ordner/Datei.txt`.
    var itemPath: String?

    /// `.pdf` bei Dateien mit Endung, sonst `nil`.
    var fileExtension: String? {
        guard kind == .file else { return nil }
        let ext = (name as NSString).pathExtension
        return ext.isEmpty ? nil : ".\(ext.lowercased())"
    }

    static func fromSearchResult(_ result: SearchResultItem) -> ObjectContextTarget {
        ObjectContextTarget(
            id: result.id,
            name: result.name,
            kind: result.isFolder ? .folder : .file,
            mediumID: result.mediumID,
            isMediumOnline: result.isOnline,
            rowID: result.item.rowID,
            isFavorite: result.item.isFavorite,
            itemPath: Self.storedPath(parent: result.item.parentPath, name: result.name, isFolder: result.isFolder)
        )
    }

    static func storedPath(parent: [String], name: String, isFolder: Bool) -> String {
        let relative = (parent + [name]).joined(separator: "/")
        return "/" + relative + (isFolder ? "/" : "")
    }

    static func fromIndexedItem(_ item: IndexedItem, medium: Medium) -> ObjectContextTarget {
        fromSearchResult(SearchResultItem(item: item, mediumID: medium.id, isOnline: medium.connectionStatus == .connected))
    }

    static func fromMedium(_ medium: Medium) -> ObjectContextTarget {
        ObjectContextTarget(
            id: medium.id,
            name: medium.name,
            kind: .medium,
            mediumID: medium.id,
            isMediumOnline: medium.connectionStatus == .connected
        )
    }
}
