//
//  DirectoryWriterV3.swift
//  diskindex
//
//  Aufgabe 231: eine Ordnerebene auf dem Schema V3 schreiben. Regeln:
//  (Kennungen bleiben, nur Geändertes wird geschrieben, Zähler-Differenzen), aber:
//  - kein gespeicherter Pfad, kein Suchindex; `slug`, `extID`, `kind`, Zeit in Sekunden, `item_details` mit
//  - fehlende Einträge bekommen `status = 2` (verschwunden) statt sofort gelöscht zu werden.
//

import Foundation
import GRDB

nonisolated final class DirectoryWriterV3 {
    private let db: Database
    private let storageID: Int64
    private var extensionIDs: [String: Int64] = [:]

    init(db: Database, storageID: Int64) throws {
        self.db = db
        self.storageID = storageID
    }

    private struct ListedRow {
        var id: Int64
        var name: String
        var isFolder: Bool
        var isPackage: Bool
        var extID: Int64?
        var status: Int
        var modifiedAt: Int64?
        var fileID: Int64?
        var depth: Int
        var sizeBytes: Int64?

        init(_ row: Row) {
            id = row["id"]
            name = row["name"]
            isFolder = row["isFolder"]
            isPackage = (row["isPackage"] as Bool?) ?? false
            extID = row["extID"]
            status = row["status"]
            modifiedAt = row["modifiedAt"]
            fileID = row["fileID"]
            depth = row["depth"]
            sizeBytes = row["sizeBytes"]
        }
    }

    func apply(
        parentID: Int64?,
        path knownPath: String?,
        depth knownDepth: Int?,
        entries: [ScannedEntry],
        seenAt: Date,
        finalize: Bool
    ) throws -> (delta: MediumCountDelta, parentPath: String) {
        let parent = try context(parentID: parentID, knownPath: knownPath, knownDepth: knownDepth)
        let stamp = Self.listingStamp(entries)
        // Vollständig gelesen: nicht mehr „nicht lesbar“ (auch wenn der Inhalt gleich geblieben ist).
        if finalize, let parentID {
            try db.execute(sql: "UPDATE items SET unreadable = 0 WHERE id = ? AND unreadable = 1", arguments: [parentID])
        }
        if finalize, try storedStamp(parentID: parentID) == stamp { return (.zero, parent.path) }
        let seenSeconds = SchemaTime.seconds(seenAt)
        var delta = MediumCountDelta.zero
        var incoming: [String: ScannedEntry] = [:]
        incoming.reserveCapacity(entries.count)
        for entry in entries { incoming[entry.name] = entry }

        var existingByName: [String: ListedRow] = [:]
        let cursor = try Row.fetchCursor(
            db,
            sql: """
                SELECT i.id, i.name, i.isFolder, i.extID, i.status, i.modifiedAt, i.fileID, i.depth, d.sizeBytes, d.isPackage
                FROM items i LEFT JOIN item_details d ON d.itemID = i.id
                WHERE i.storageID = ? AND i.parentID IS ?
                """,
            arguments: [storageID, parentID]
        )
        while let row = try cursor.next() {
            let listed = ListedRow(row)
            existingByName[listed.name] = listed
        }

        for entry in incoming.values {
            let ext = entry.isFolder ? nil : Self.fileExtension(entry.name)
            let extID = try ext.map(extensionID)
            let fileID = entry.fileID.flatMap(Int64.init)
            let modified = entry.modifiedAt.map(SchemaTime.seconds)
            let kind = ItemKind.classify(ext: Self.fileExtension(entry.name), isFolder: entry.isFolder, isPackage: entry.isPackage).rawValue
            if let row = existingByName[entry.name] {
                let same = row.status == 0
                    && row.isFolder == entry.isFolder
                    && row.isPackage == entry.isPackage
                    && row.extID == extID
                    && row.sizeBytes == entry.sizeBytes
                    && row.fileID == fileID
                    && row.depth == parent.childDepth
                    && row.modifiedAt == modified
                if !same {
                    if row.status != 0 { delta.addVisible(isFolder: entry.isFolder) }
                    try db.execute(
                        sql: """
                            UPDATE items SET isFolder = ?, extID = ?, kind = ?, depth = ?, modifiedAt = ?, fileID = ?, status = 0
                            WHERE id = ?
                            """,
                        arguments: [entry.isFolder, extID, kind, parent.childDepth, modified, fileID, row.id]
                    )
                    try writeDetails(itemID: row.id, entry)
                    // Größe oder Datum haben sich geändert: gelesene Zusatzdaten und Prüfsummen sind veraltet.
                    // Werte des Nutzers (`source = 1`) bleiben.
                    if row.sizeBytes != entry.sizeBytes || row.modifiedAt != modified {
                        try db.execute(sql: "DELETE FROM item_meta WHERE itemID = ? AND source = ?", arguments: [row.id, MetaSource.read.rawValue])
                        try db.execute(sql: "DELETE FROM item_checksum WHERE itemID = ?", arguments: [row.id])
                    }
                }
            } else {
                delta.addVisible(isFolder: entry.isFolder)
                try db.execute(
                    sql: """
                        INSERT INTO items (
                            storageID, parentID, name, slug, extID, kind, isFolder, depth, status, modifiedAt, fileID
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
                        """,
                    arguments: [
                        storageID, parentID, entry.name, Slug.make(entry.name), extID, kind, entry.isFolder,
                        parent.childDepth, modified, fileID,
                    ]
                )
                try writeDetails(itemID: db.lastInsertedRowID, entry)
            }
        }

        if finalize {
            for row in existingByName.values where incoming[row.name] == nil && row.status == 0 {
                delta.removeVisible(isFolder: row.isFolder)
                try db.execute(
                    sql: "UPDATE items SET status = ?, contentStamp = NULL WHERE id = ? AND status = 0",
                    arguments: [ItemStatus.gone.rawValue, row.id]
                )
                if row.isFolder {
                    let subtree = try markSubtreeGone(folderID: row.id)
                    delta.files -= subtree.files
                    delta.folders -= subtree.folders
                }
            }
        }
        if finalize {
            try saveStamp(stamp, parentID: parentID)
            if let parentID {
                try db.execute(sql: "UPDATE items SET listedAt = ? WHERE id = ?", arguments: [seenSeconds, parentID])
            }
        }
        return (delta, parent.path)
    }

    // MARK: Hilfen

    private func context(parentID: Int64?, knownPath: String?, knownDepth: Int?) throws -> (path: String, childDepth: Int) {
        guard let parentID else { return (knownPath ?? "/", knownDepth ?? 1) }
        guard let row = try Row.fetchOne(
            db, sql: "SELECT depth, storageID FROM items WHERE id = ?", arguments: [parentID]
        ), row["storageID"] as Int64 == storageID else {
            throw IndexStoreError.unknownParent
        }
        let depth: Int = row["depth"]
        if let knownPath, let knownDepth { return (knownPath, knownDepth) }
        return (try Self.path(db, itemID: parentID), knownDepth ?? depth + 1)
    }

    /// Namen vom Medium bis zum Eintrag, z. B. `["A", "B"]`.
    static func segments(_ db: Database, itemID: Int64) throws -> [String] {
        var names: [String] = []
        var current: Int64? = itemID
        while let id = current {
            guard let row = try Row.fetchOne(db, sql: "SELECT name, parentID FROM items WHERE id = ?", arguments: [id]) else { break }
            names.append(row["name"])
            current = row["parentID"]
        }
        return names.reversed()
    }

    /// Gespeicherter Pfad-Stil der alten Schicht: `/A/B/`.
    static func path(_ db: Database, itemID: Int64) throws -> String {
        "/" + (try segments(db, itemID: itemID).map { $0 + "/" }.joined())
    }

    private func extensionID(_ ext: String) throws -> Int64 {
        if let known = extensionIDs[ext] { return known }
        if let id = try Int64.fetchOne(db, sql: "SELECT id FROM extensions WHERE ext = ?", arguments: [ext]) {
            extensionIDs[ext] = id
            return id
        }
        try db.execute(sql: "INSERT INTO extensions (ext) VALUES (?)", arguments: [ext])
        let id = db.lastInsertedRowID
        extensionIDs[ext] = id
        return id
    }

    private func writeDetails(itemID: Int64, _ entry: ScannedEntry) throws {
        try db.execute(
            sql: """
                INSERT INTO item_details (itemID, sizeBytes, isPackage) VALUES (?, ?, ?)
                ON CONFLICT(itemID) DO UPDATE SET sizeBytes = excluded.sizeBytes, isPackage = excluded.isPackage
                """,
            arguments: [itemID, entry.sizeBytes, entry.isPackage]
        )
    }

    private func markSubtreeGone(folderID: Int64) throws -> (files: Int, folders: Int) {
        let subtree = "WITH RECURSIVE sub(id) AS (SELECT id FROM items WHERE parentID = ?1 UNION ALL SELECT i.id FROM items i JOIN sub ON i.parentID = sub.id)"
        let row = try Row.fetchOne(
            db,
            sql: subtree + " SELECT SUM(isFolder = 0), SUM(isFolder = 1) FROM items WHERE id IN (SELECT id FROM sub) AND status = 0",
            arguments: [folderID]
        )
        try db.execute(
            sql: subtree + " UPDATE items SET status = 2, contentStamp = NULL WHERE id IN (SELECT id FROM sub) AND status = 0",
            arguments: [folderID]
        )
        return (files: row?[0] as Int? ?? 0, folders: row?[1] as Int? ?? 0)
    }

    private func storedStamp(parentID: Int64?) throws -> Int64? {
        if let parentID {
            return try Int64.fetchOne(db, sql: "SELECT contentStamp FROM items WHERE id = ?", arguments: [parentID])
        }
        return try MediumCodecV3.metaValue(db, storageID, .rootContentStamp).flatMap(Int64.init)
    }

    private func saveStamp(_ stamp: Int64, parentID: Int64?) throws {
        if let parentID {
            try db.execute(sql: "UPDATE items SET contentStamp = ? WHERE id = ?", arguments: [stamp, parentID])
        } else {
            try MediumCodecV3.setMeta(db, storageID, .rootContentStamp, value: String(stamp))
        }
    }

    /// Fingerabdruck des Inhalts einer Ordnerebene als eine Zahl.
    static func listingStamp(_ entries: [ScannedEntry]) -> Int64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        func mix(_ text: String) {
            for byte in text.utf8 {
                hash ^= UInt64(byte)
                hash &*= 1_099_511_628_211
            }
            hash &*= 1_099_511_628_211
        }
        for entry in entries.sorted(by: { $0.name < $1.name }) {
            mix(entry.name)
            mix(entry.isFolder ? "d" : "f")
            mix(entry.isPackage ? "p" : "-")
            mix(String(entry.sizeBytes ?? -1))
            mix(String(entry.modifiedAt.map(SchemaTime.seconds) ?? 0))
            mix(entry.fileID ?? "")
        }
        return Int64(bitPattern: hash)
    }

    static func fileExtension(_ name: String) -> String? {
        let ext = (name as NSString).pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }
}
