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
    let trustsFileID: Bool
    /// bug.0.4.156 (a): Segment-Abfragen beim Wiederverbinden (Zähler für Tests, kein Zeitmaß).
    private(set) var reconnectSegmentLookups = 0
    /// bug.0.4.169: Teil-Prüfsummen der eingefügten Zeilen, außerhalb der Schreibtransaktion gelesen. Gesetzt liest das
    /// Wiederverbinden nicht mehr selbst von der Platte; fehlt eine gebrauchte Zeile darin, gilt sie als unlesbar.
    var externalPartials: [Int64: PartialReadOutcome]?
    #if DEBUG
    /// Tests (bug.0.4.169): vor jedem Lesen von der Platte im Rückfall (innerhalb der Transaktion).
    var partialReadHook: (@Sendable (URL) -> Void)?
    /// Tests (bug.0.4.171): vor jedem Nachschlagen einer vorab gelesenen Teil-Prüfsumme; darf werfen (z. B. einen
    /// Datenbankfehler).
    var partialLookupHook: (@Sendable () throws -> Void)?
    #endif
    /// bug.0.4.156 (b): Kandidaten, deren Gegenstück nicht gelesen werden konnte – nicht löschen, im Folgelauf erneut.
    private(set) var unreadableGoneCandidateIDs: Set<Int64> = []
    private let partialMatchingEnabled: Bool
    private var extensionIDs: [String: Int64] = [:]
    private var activePrecomputedPartials: [String: Data]?
    /// bug.0.4.141: Teil-Prüfsumme einer Datei, die nicht vorab berechnet wurde (Wiederverbinden am Laufende), von der Platte.
    private var activePartialFallback: ((String) throws -> Data?)?
    /// Lauf-Tracking für bug.0.4.015 (Verbindungs-Nachlauf).
    var onInsertedItemID: ((Int64) -> Void)?

    init(db: Database, storageID: Int64, partialMatchingEnabled: Bool = true) throws {
        self.db = db
        self.storageID = storageID
        self.partialMatchingEnabled = partialMatchingEnabled
        let fsCode: Int = try Int.fetchOne(db, sql: "SELECT fsType FROM storages WHERE id = ?", arguments: [storageID]) ?? 0
        let fsName = MediumCodecV3.fileSystemName(fsCode) ?? ""
        trustsFileID = FileIdentity.trustsFileID(fsType: fsName)
    }

    private struct ListedRow {
        var id: Int64
        var parentID: Int64?
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
            parentID = row["parentID"]
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
        finalize: Bool,
        mountPath: String? = nil,
        precomputedPartials: [String: Data]? = nil
    ) throws -> (delta: MediumCountDelta, parentPath: String) {
        let priorPartials = activePrecomputedPartials
        activePrecomputedPartials = precomputedPartials
        defer { activePrecomputedPartials = priorPartials }
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
                SELECT i.id, i.parentID, i.name, i.isFolder, i.extID, i.status, i.modifiedAt, i.fileID, i.depth, d.sizeBytes, d.isPackage
                FROM items i LEFT JOIN item_details d ON d.itemID = i.id
                WHERE i.storageID = ? AND i.parentID IS ?
                """,
            arguments: [storageID, parentID]
        )
        while let row = try cursor.next() {
            let listed = ListedRow(row)
            existingByName[listed.name] = listed
        }

        var preservedIDs = Set<Int64>()
        var vacatedNames = Set<String>()
        var pass1Handled = Set<String>()
        let sortedEntries = entries.sorted { $0.name < $1.name }

        for entry in sortedEntries {
            let ext = entry.isFolder ? nil : Self.fileExtension(entry.name)
            let extID = try ext.map(extensionID)
            let fileID = entry.fileID.flatMap(Int64.init)
            let modified = entry.modifiedAt.map(SchemaTime.seconds)
            let kind = ItemKind.classify(ext: Self.fileExtension(entry.name), isFolder: entry.isFolder, isPackage: entry.isPackage).rawValue
            guard shouldRelocateByFileID(entry: entry, fileID: fileID),
                  let fileID,
                  existingByName[entry.name] == nil,
                  let located = try fetchByFileID(fileID) else { continue }
            if located.parentID == parentID, located.name == entry.name { continue }
            if located.parentID == parentID { vacatedNames.insert(located.name) }
            try relocateRow(
                located: located,
                entry: entry,
                parentID: parentID,
                childDepth: parent.childDepth,
                extID: extID,
                kind: kind,
                modified: modified,
                fileID: fileID,
                delta: &delta
            )
            if located.isFolder, located.depth != parent.childDepth {
                try shiftDescendantDepths(folderID: located.id, by: parent.childDepth - located.depth)
            }
            preservedIDs.insert(located.id)
            if located.parentID == parentID {
                existingByName.removeValue(forKey: located.name)
            }
            pass1Handled.insert(entry.name)
        }

        for entry in sortedEntries {
            if pass1Handled.contains(entry.name) { continue }
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
            } else if let revived = try matchVacatedLocalCandidate(
                entry: entry,
                parentID: parentID,
                extID: extID,
                existingByName: existingByName,
                incoming: incoming,
                preservedIDs: preservedIDs,
                mountPath: mountPath
            ) {
                try relocateRow(
                    located: revived,
                    entry: entry,
                    parentID: parentID,
                    childDepth: parent.childDepth,
                    extID: extID,
                    kind: kind,
                    modified: modified,
                    fileID: fileID,
                    delta: &delta
                )
                preservedIDs.insert(revived.id)
                vacatedNames.insert(revived.name)
            } else if let revived = try matchGoneCandidate(
                entry: entry, parentID: parentID, extID: extID, mountPath: mountPath
            ) {
                try relocateRow(
                    located: revived,
                    entry: entry,
                    parentID: parentID,
                    childDepth: parent.childDepth,
                    extID: extID,
                    kind: kind,
                    modified: modified,
                    fileID: fileID,
                    delta: &delta
                )
                preservedIDs.insert(revived.id)
                if revived.parentID == parentID { vacatedNames.insert(revived.name) }
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
                let newID = db.lastInsertedRowID
                try writeDetails(itemID: newID, entry)
                onInsertedItemID?(newID)
            }
        }

        if finalize {
            for row in existingByName.values
            where incoming[row.name] == nil && row.status == 0
                && !preservedIDs.contains(row.id)
                && !vacatedNames.contains(row.name) {
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

    /// bug.0.4.169: Welche eingefügten Dateien brauchen beim Wiederverbinden eine Teil-Prüfsumme von der Platte? Nur
    /// lesend (für `pool.read`): der Abgleich mit den Kandidaten läuft wie beim Verbinden, statt zu lesen wird die Datei
    /// vorgemerkt. Segmente werden nur für diese Dateien geholt (bug.0.4.156 a).
    func partialReadRequests(insertedIDs: Set<Int64>, mountPath: String) throws -> [(id: Int64, url: URL)] {
        guard !trustsFileID, !insertedIDs.isEmpty else { return [] }
        var requests: [(id: Int64, url: URL)] = []
        let priorFallback = activePartialFallback
        let priorPartials = activePrecomputedPartials
        defer { activePartialFallback = priorFallback; activePrecomputedPartials = priorPartials }
        activePrecomputedPartials = nil
        for insertedID in insertedIDs.sorted() {
            guard let inserted = try fetchListedRow(id: insertedID), inserted.status == 0 else { continue }
            let entry = scannedEntry(from: inserted)
            guard !entry.isFolder, !entry.isPackage else { continue }
            var recorded = false
            activePartialFallback = { [unowned self] _ in
                guard !recorded else { return nil }
                recorded = true
                self.reconnectSegmentLookups += 1
                let segments = try Self.segments(self.db, itemID: insertedID)
                let url = Self.fileURL(mountPath: mountPath, parentSegments: Array(segments.dropLast()), name: entry.name)
                requests.append((insertedID, url))
                return nil
            }
            _ = try matchGoneCandidate(entry: entry, parentID: inserted.parentID, extID: inserted.extID, mountPath: mountPath)
        }
        return requests
    }

    /// Verbindet in diesem Lauf neu eingefügte Zeilen mit `status = 2` (bug.0.4.015 a), vor `deleteGoneItems`.
    func reconnectInsertedWithGone(insertedIDs: Set<Int64>, mountPath: String?) throws -> MediumCountDelta {
        guard !trustsFileID, !insertedIDs.isEmpty else { return .zero }
        var delta = MediumCountDelta.zero
        for insertedID in insertedIDs {
            guard let inserted = try fetchListedRow(id: insertedID), inserted.status == 0 else { continue }
            let entry = scannedEntry(from: inserted)
            let extID = inserted.extID
            // bug.0.4.141: ohne vorab berechnete Teil-Prüfsumme (Laufende) nur lesend von der Platte holen, und nur wenn
            // ein Kandidat mit gespeicherter Teil-Prüfsumme sie wirklich braucht.
            let priorFallback = activePartialFallback
            let priorPartials = activePrecomputedPartials
            activePrecomputedPartials = nil
            if let external = externalPartials, !entry.isFolder, !entry.isPackage {
                // bug.0.4.169: vorab außerhalb der Transaktion gelesen – hier nur nachschlagen. Fehlt der Wert (beim Lesen
                // gab es noch keinen Kandidaten, er entstand erst danach): wie unlesbar – der Kandidat bleibt.
                #if DEBUG
                let lookupHook = partialLookupHook
                #endif
                activePartialFallback = { _ in
                    #if DEBUG
                    try lookupHook?()
                    #endif
                    switch external[insertedID] {
                    case .digest(let data): return data
                    case .missing: return nil
                    case .unreadable, nil: throw PartialReadFailure.unreadable
                    }
                }
            } else if let mountPath, !entry.isFolder, !entry.isPackage {
                // bug.0.4.156 (a): Pfad erst holen, wenn ein Kandidat die Teil-Prüfsumme wirklich braucht.
                // (b): Lesefehler werfen (fehlt die Datei: `nil`) – der Kandidat bleibt dann stehen.
                activePartialFallback = { [unowned self] _ in
                    self.reconnectSegmentLookups += 1
                    let segments = try Self.segments(self.db, itemID: insertedID)
                    let url = Self.fileURL(mountPath: mountPath, parentSegments: Array(segments.dropLast()), name: entry.name)
                    #if DEBUG
                    self.partialReadHook?(url)
                    #endif
                    return try PartialChecksum.compute(at: url)?.partial
                }
            }
            defer { activePartialFallback = priorFallback; activePrecomputedPartials = priorPartials }
            guard let gone = try matchGoneCandidate(
                entry: entry, parentID: inserted.parentID, extID: extID, mountPath: mountPath
            ) else { continue }
            let kind = ItemKind.classify(
                ext: Self.fileExtension(entry.name), isFolder: entry.isFolder, isPackage: entry.isPackage
            ).rawValue
            let modified = entry.modifiedAt.map(SchemaTime.seconds)
            let fileID = entry.fileID.flatMap(Int64.init)
            delta.removeVisible(isFolder: entry.isFolder)
            try db.execute(sql: "DELETE FROM item_details WHERE itemID = ?", arguments: [insertedID])
            try db.execute(sql: "DELETE FROM items WHERE id = ?", arguments: [insertedID])
            try relocateRow(
                located: gone,
                entry: entry,
                parentID: inserted.parentID,
                childDepth: inserted.depth,
                extID: extID,
                kind: kind,
                modified: modified,
                fileID: fileID,
                delta: &delta
            )
        }
        return delta
    }

    private enum FolderLookup: Equatable {
        case root
        case found(Int64?)
        case missing
    }

    /// Live-Umbenennen/Verschieben per absolutem Pfad (235b).
    func applyLivePathRename(
        mountPath: String,
        fromAbsolute: String,
        toAbsolute: String,
        seenAt: Date,
        toSizeBytes: Int64? = nil,
        toModifiedAt: Date? = nil,
        toPartialDigest: Data? = nil
    ) throws -> (applied: Bool, delta: MediumCountDelta) {
        guard let fromParts = Self.relativeComponents(absolute: fromAbsolute, mountPath: mountPath),
              let toParts = Self.relativeComponents(absolute: toAbsolute, mountPath: mountPath),
              let fromName = fromParts.last,
              let toName = toParts.last,
              !fromName.isEmpty,
              !toName.isEmpty else { return (false, .zero) }
        let fromParentPath = Array(fromParts.dropLast())
        let toParentPath = Array(toParts.dropLast())
        let fromLookup = try resolveFolderLookup(segments: fromParentPath)
        let toLookup = try resolveFolderLookup(segments: toParentPath)
        if !fromParentPath.isEmpty, fromLookup == .missing { return (false, .zero) }
        if !toParentPath.isEmpty, toLookup == .missing { return (false, .zero) }
        let fromParentID = folderParentID(fromLookup)
        let toParentID = folderParentID(toLookup)
        guard let row = try fetchChildUnique(parentID: fromParentID, name: fromName, allowGone: true) else { return (false, .zero) }
        let sizeBytes = toSizeBytes
        let modifiedAt = toModifiedAt
        guard try liveRenameTargetMatches(
            row: row,
            mountPath: mountPath,
            toAbsolute: toAbsolute,
            toParentID: toParentID,
            toName: toName,
            sizeBytes: sizeBytes,
            toPartialDigest: toPartialDigest
        ) else {
            return (false, .zero)
        }
        if let clash = try fetchChild(parentID: toParentID, name: toName, allowGone: true), clash.id != row.id {
            if clash.status == ItemStatus.gone.rawValue {
                try removeGonePlaceholder(clash.id)
            } else {
                return (false, .zero)
            }
        }
        let childDepth = toParentPath.count + 1
        let entry: ScannedEntry
        let extID: Int64?
        let kind: Int
        if row.isFolder {
            entry = ScannedEntry(
                name: toName,
                isFolder: true,
                isPackage: row.isPackage,
                modifiedAt: modifiedAt,
                fileID: row.fileID.map { String($0) }
            )
            extID = nil
            kind = ItemKind.classify(ext: nil, isFolder: true, isPackage: row.isPackage).rawValue
        } else {
            entry = ScannedEntry(
                name: toName,
                isFolder: false,
                sizeBytes: sizeBytes,
                modifiedAt: modifiedAt,
                fileID: row.fileID.map { String($0) }
            )
            extID = try Self.fileExtension(toName).map(extensionID)
            kind = ItemKind.classify(ext: Self.fileExtension(toName), isFolder: false, isPackage: false).rawValue
        }
        let modified = modifiedAt.map(SchemaTime.seconds)
        var delta = MediumCountDelta.zero
        try relocateRow(
            located: row,
            entry: entry,
            parentID: toParentID,
            childDepth: childDepth,
            extID: extID,
            kind: kind,
            modified: modified,
            fileID: row.fileID,
            delta: &delta
        )
        if row.isFolder {
            try shiftDescendantDepths(folderID: row.id, by: childDepth - row.depth)
        }
        _ = seenAt
        return (true, delta)
    }

    // MARK: Hilfen

    private func folderParentID(_ lookup: FolderLookup) -> Int64? {
        switch lookup {
        case .root: return nil
        case .found(let id): return id
        case .missing: return nil
        }
    }

    private func resolveFolderLookup(segments: [String]) throws -> FolderLookup {
        if segments.isEmpty { return .root }
        var parent: Int64?
        for name in segments {
            guard let id = try fetchFolderRowID(parentID: parent, name: name) else { return .missing }
            parent = id
        }
        return .found(parent)
    }

    private func fetchFolderRowID(parentID: Int64?, name: String) throws -> Int64? {
        if let exact = try Int64.fetchOne(
            db,
            sql: """
                SELECT id FROM items WHERE storageID = ? AND parentID IS ? AND name = ? AND isFolder = 1 AND status = 0
                """,
            arguments: [storageID, parentID, name]
        ) {
            return exact
        }
        let slug = Slug.make(name)
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT id, name FROM items
                WHERE storageID = ? AND parentID IS ? AND slug = ? AND isFolder = 1 AND status = 0
                """,
            arguments: [storageID, parentID, slug]
        )
        let exactName = rows.filter { ($0["name"] as String) == name }
        if exactName.count == 1 { return exactName[0]["id"] }
        if rows.count == 1 { return rows[0]["id"] }
        return nil
    }

    private func liveRenameTargetMatches(
        row: ListedRow,
        mountPath: String,
        toAbsolute: String,
        toParentID: Int64?,
        toName: String,
        sizeBytes: Int64?,
        toPartialDigest: Data?
    ) throws -> Bool {
        if trustsFileID {
            if let expectedID = row.fileID {
                var st = stat()
                guard stat(toAbsolute, &st) == 0 else { return false }
                guard expectedID == Int64(st.st_ino) else { return false }
            }
            return true
        }
        guard sizeBytes == row.sizeBytes else { return false }
        guard partialMatchingEnabled, let stored = try fetchPartial(itemID: row.id) else { return true }
        guard let incoming = toPartialDigest else { return false }
        return stored == incoming
    }

    private func folderID(segments: [String]) throws -> Int64? {
        switch try resolveFolderLookup(segments: segments) {
        case .root: return nil
        case .found(let id): return id
        case .missing: return nil
        }
    }

    private func removeGonePlaceholder(_ itemID: Int64) throws {
        try db.execute(
            sql: "DELETE FROM items WHERE id = ? AND status = ?",
            arguments: [itemID, ItemStatus.gone.rawValue]
        )
    }

    private func fetchChild(parentID: Int64?, name: String, allowGone: Bool) throws -> ListedRow? {
        let rows = try fetchChildRows(parentID: parentID, name: name, allowGone: allowGone)
        guard let row = rows.first else { return nil }
        return ListedRow(row)
    }

    private func fetchChildUnique(parentID: Int64?, name: String, allowGone: Bool) throws -> ListedRow? {
        let rows = try fetchChildRows(parentID: parentID, name: name, allowGone: allowGone)
        guard rows.count == 1, let row = rows.first else { return nil }
        return ListedRow(row)
    }

    private func fetchChildRows(parentID: Int64?, name: String, allowGone: Bool) throws -> [Row] {
        let statusSQL = allowGone ? "i.status IN (0, 2)" : "i.status = 0"
        let exact = try Row.fetchAll(
            db,
            sql: """
                SELECT i.id, i.parentID, i.name, i.isFolder, i.extID, i.status, i.modifiedAt, i.fileID, i.depth, d.sizeBytes, d.isPackage
                FROM items i LEFT JOIN item_details d ON d.itemID = i.id
                WHERE i.storageID = ? AND i.parentID IS ? AND i.name = ? AND \(statusSQL)
                LIMIT 2
                """,
            arguments: [storageID, parentID, name]
        )
        if !exact.isEmpty { return exact }
        let slug = Slug.make(name)
        let slugRows = try Row.fetchAll(
            db,
            sql: """
                SELECT i.id, i.parentID, i.name, i.isFolder, i.extID, i.status, i.modifiedAt, i.fileID, i.depth, d.sizeBytes, d.isPackage
                FROM items i LEFT JOIN item_details d ON d.itemID = i.id
                WHERE i.storageID = ? AND i.parentID IS ? AND i.slug = ? AND \(statusSQL)
                LIMIT 4
                """,
            arguments: [storageID, parentID, slug]
        )
        let nameMatches = slugRows.filter { ($0["name"] as String) == name }
        if !nameMatches.isEmpty { return Array(nameMatches.prefix(2)) }
        if slugRows.count == 1 { return slugRows }
        return []
    }

    private func shiftDescendantDepths(folderID: Int64, by delta: Int) throws {
        guard delta != 0 else { return }
        try db.execute(
            sql: """
                WITH RECURSIVE sub(id) AS (
                    SELECT id FROM items WHERE parentID = ?
                    UNION ALL
                    SELECT i.id FROM items i INNER JOIN sub ON i.parentID = sub.id
                )
                UPDATE items SET depth = depth + ? WHERE id IN (SELECT id FROM sub)
                """,
            arguments: [folderID, delta]
        )
    }

    static func relativeComponents(absolute: String, mountPath: String) -> [String]? {
        let mount = URL(fileURLWithPath: mountPath).standardizedFileURL.path
        let std = URL(fileURLWithPath: absolute).standardizedFileURL.path
        guard std != mount else { return [] }
        let prefix = mount.hasSuffix("/") ? mount : mount + "/"
        guard std.hasPrefix(prefix) else { return nil }
        let tail = std.dropFirst(prefix.count)
        if tail.isEmpty { return [] }
        return tail.split(separator: "/").map(String.init)
    }

    private func fetchByFileID(_ fileID: Int64) throws -> ListedRow? {
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT i.id, i.parentID, i.name, i.isFolder, i.extID, i.status, i.modifiedAt, i.fileID, i.depth, d.sizeBytes, d.isPackage
                FROM items i LEFT JOIN item_details d ON d.itemID = i.id
                WHERE i.storageID = ? AND i.fileID = ? AND i.status IN (0, 1, 2)
                LIMIT 2
                """,
            arguments: [storageID, fileID]
        )
        guard rows.count == 1, let row = rows.first else { return nil }
        return ListedRow(row)
    }

    private func relocateRow(
        located: ListedRow,
        entry: ScannedEntry,
        parentID: Int64?,
        childDepth: Int,
        extID: Int64?,
        kind: Int,
        modified: Int64?,
        fileID: Int64?,
        delta: inout MediumCountDelta
    ) throws {
        if located.status != 0 { delta.addVisible(isFolder: entry.isFolder) }
        try db.execute(
            sql: """
                UPDATE items SET parentID = ?, name = ?, slug = ?, isFolder = ?, extID = ?, kind = ?, depth = ?,
                    modifiedAt = ?, fileID = ?, status = 0
                WHERE id = ?
                """,
            arguments: [
                parentID, entry.name, Slug.make(entry.name), entry.isFolder, extID, kind, childDepth,
                modified, fileID, located.id,
            ]
        )
        try writeDetails(itemID: located.id, entry)
        if located.sizeBytes != entry.sizeBytes || located.modifiedAt != modified {
            try db.execute(sql: "DELETE FROM item_meta WHERE itemID = ? AND source = ?", arguments: [located.id, MetaSource.read.rawValue])
            try db.execute(sql: "DELETE FROM item_checksum WHERE itemID = ?", arguments: [located.id])
        }
    }

    private func shouldRelocateByFileID(entry: ScannedEntry, fileID: Int64?) -> Bool {
        guard trustsFileID, fileID != nil else { return false }
        if let linkCount = entry.linkCount, linkCount > 1 { return false }
        return true
    }

    private func fetchListedRow(id: Int64) throws -> ListedRow? {
        guard let row = try Row.fetchOne(
            db,
            sql: """
                SELECT i.id, i.parentID, i.name, i.isFolder, i.extID, i.status, i.modifiedAt, i.fileID, i.depth, d.sizeBytes, d.isPackage
                FROM items i LEFT JOIN item_details d ON d.itemID = i.id
                WHERE i.id = ? AND i.storageID = ?
                """,
            arguments: [id, storageID]
        ) else { return nil }
        return ListedRow(row)
    }

    private func scannedEntry(from row: ListedRow) -> ScannedEntry {
        if row.isFolder {
            return ScannedEntry(
                name: row.name,
                isFolder: true,
                isPackage: row.isPackage,
                modifiedAt: row.modifiedAt.map(SchemaTime.date),
                fileID: row.fileID.map { String($0) }
            )
        }
        return ScannedEntry(
            name: row.name,
            isFolder: false,
            sizeBytes: row.sizeBytes,
            modifiedAt: row.modifiedAt.map(SchemaTime.date),
            fileID: row.fileID.map { String($0) }
        )
    }

    private func matchVacatedLocalCandidate(
        entry: ScannedEntry,
        parentID: Int64?,
        extID: Int64?,
        existingByName: [String: ListedRow],
        incoming: [String: ScannedEntry],
        preservedIDs: Set<Int64>,
        mountPath: String?
    ) throws -> ListedRow? {
        guard !trustsFileID else { return nil }
        var vacated: [ListedRow] = []
        for (name, row) in existingByName {
            if incoming[name] != nil { continue }
            if row.status != 0 { continue }
            if preservedIDs.contains(row.id) { continue }
            vacated.append(row)
        }
        return try resolveIdentityMatch(
            candidates: vacated.filter { $0.isFolder == entry.isFolder },
            entry: entry,
            parentID: parentID,
            extID: extID,
            mountPath: mountPath
        )
    }

    private func matchGoneCandidate(
        entry: ScannedEntry,
        parentID: Int64?,
        extID: Int64?,
        mountPath: String?
    ) throws -> ListedRow? {
        guard !trustsFileID else { return nil }
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT i.id, i.parentID, i.name, i.isFolder, i.extID, i.status, i.modifiedAt, i.fileID, i.depth, d.sizeBytes, d.isPackage
                FROM items i LEFT JOIN item_details d ON d.itemID = i.id
                WHERE i.storageID = ? AND i.status = 2 AND i.isFolder = ?
                """,
            arguments: [storageID, entry.isFolder]
        )
        let candidates = rows.map { ListedRow($0) }
        return try resolveIdentityMatch(
            candidates: candidates, entry: entry, parentID: parentID, extID: extID, mountPath: mountPath
        )
    }

    private func resolveIdentityMatch(
        candidates: [ListedRow],
        entry: ScannedEntry,
        parentID: Int64?,
        extID: Int64?,
        mountPath: String?
    ) throws -> ListedRow? {
        var matches: [ListedRow] = []
        for listed in candidates {
            if listed.isPackage != entry.isPackage { continue }
            if listed.sizeBytes != entry.sizeBytes { continue }
            if listed.extID != extID, !entry.isFolder { continue }
            if !FileIdentity.timestampsMatchFAT(
                listed.modifiedAt.map(SchemaTime.date),
                entry.modifiedAt
            ) { continue }
            matches.append(listed)
        }
        if matches.isEmpty { return nil }
        if matches.count > 1, let parentID {
            let local = matches.filter { $0.parentID == parentID }
            if local.count == 1 { matches = local }
        }
        if matches.count == 1 {
            return try verifyPartialMatch(
                candidate: matches[0], entry: entry, parentID: parentID, mountPath: mountPath
            )
        }
        return try disambiguateWithPartial(
            candidates: matches, entry: entry, parentID: parentID, mountPath: mountPath
        )
    }

    private func verifyPartialMatch(
        candidate: ListedRow,
        entry: ScannedEntry,
        parentID: Int64?,
        mountPath: String?
    ) throws -> ListedRow? {
        if entry.isFolder {
            return folderGoneCandidateIsConfident(candidate, entry: entry, parentID: parentID) ? candidate : nil
        }
        guard partialMatchingEnabled,
              let mountPath,
              let stored = try fetchPartial(itemID: candidate.id) else { return candidate }
        let incoming: Data?
        do {
            incoming = try incomingPartialDigest(mountPath: mountPath, parentID: parentID, name: entry.name)
        } catch let error as DatabaseError {
            // bug.0.4.165 (d): Datenbankfehler weitergeben, nur Lesefehler der Datei gelten als „unlesbar“.
            throw error
        } catch {
            unreadableGoneCandidateIDs.insert(candidate.id)
            return nil
        }
        guard let incoming else { return nil }
        return stored == incoming ? candidate : nil
    }

    /// FAT/Ordner ohne `fileID`: kein Revive allein wegen `matches.count == 1` ohne Name+Eltern.
    private func folderGoneCandidateIsConfident(
        _ candidate: ListedRow,
        entry: ScannedEntry,
        parentID: Int64?
    ) -> Bool {
        guard entry.isFolder else { return true }
        return candidate.name == entry.name && candidate.parentID == parentID
    }

    private func disambiguateWithPartial(
        candidates: [ListedRow],
        entry: ScannedEntry,
        parentID: Int64?,
        mountPath: String?
    ) throws -> ListedRow? {
        guard !entry.isFolder, partialMatchingEnabled, let mountPath else { return nil }
        // bug.0.4.225: Hat keiner der Kandidaten eine gespeicherte Teil-Prüfsumme, gibt es nichts zu vergleichen – die Datei
        // nicht lesen (sonst las das Laufende bei gleich großen Dateien ohne Favoriten trotzdem).
        let storedPartials = try candidates.compactMap { candidate in
            try fetchPartial(itemID: candidate.id).map { (candidate, $0) }
        }
        guard !storedPartials.isEmpty else { return nil }
        let digest: Data?
        do {
            digest = try incomingPartialDigest(mountPath: mountPath, parentID: parentID, name: entry.name)
        } catch let error as DatabaseError {
            throw error
        } catch {
            unreadableGoneCandidateIDs.formUnion(candidates.map(\.id))
            return nil
        }
        guard let incoming = digest else { return nil }
        let hits = storedPartials.filter { $0.1 == incoming }.map(\.0)
        guard hits.count == 1 else { return nil }
        return hits[0]
    }

    private func fetchPartial(itemID: Int64) throws -> Data? {
        try Data.fetchOne(db, sql: "SELECT partial FROM item_checksum WHERE itemID = ?", arguments: [itemID])
    }

    private func incomingPartialDigest(mountPath: String, parentID: Int64?, name: String) throws -> Data? {
        _ = mountPath
        _ = parentID
        if let precomputed = activePrecomputedPartials?[name] { return precomputed }
        return try activePartialFallback?(name)
    }

    /// bug.0.4.226: ohne Plattenzugriff – `appendPathComponent` fragt bei Datei-URLs die Platte (`getattrlist`), ob der
    /// Pfad ein Ordner ist; auf dem Store-Actor hielt eine langsame Platte so alle anderen Medien auf.
    static func fileURL(mountPath: String, parentSegments: [String], name: String) -> URL {
        var url = URL(fileURLWithPath: mountPath, isDirectory: true)
        for segment in parentSegments {
            url = url.appending(component: segment, directoryHint: .isDirectory)
        }
        return url.appending(component: name, directoryHint: .notDirectory)
    }

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

/// bug.0.4.169: vorab gelesene Datei war nicht lesbar (Fehler oder Zeitgrenze).
nonisolated enum PartialReadFailure: Error {
    case unreadable
}
