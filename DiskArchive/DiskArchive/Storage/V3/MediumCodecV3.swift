//
//  MediumCodecV3.swift
//  DiskArchive
//
//  Aufgabe 231: `StoredMedium` ↔ `storages` + `storage_meta`. Feste Felder in `storages`, alles Weitere als Schlüssel
//  in `storage_meta`. Zahlencodes für Typ, Dateisystem, Entscheidung und Status stehen hier an einer Stelle.
//

import Foundation
import GRDB

/// Schlüssel in `storage_meta`.
nonisolated enum StorageMetaKey: String, CaseIterable, Sendable {
    case completedDepth
    case scanTotal
    case fsEventsUUID
    case lastEventID
    case rootContentStamp
    case lastIndexActivityAt
    case showAbsoluteCapacity
    case volumeCreatedAt
    case diskSizeBytes
    case fsTypeName
    /// Wirkt noch: `Medium.isForgotten` blendet Medien aus (AppState).
    case isForgotten
    /// Wirkt noch: `Medium.allowIndexing` steuert die Registeransicht.
    case allowIndexing
    /// bug.0.4.224: vergessen, Einträge werden noch gelöscht. Laden, Erkennung, Suche und Zähler übergehen das Medium.
    case pendingDeletion
    /// todo.0.4.2.002: eigener Name (nur Anzeige); fehlt = Originalname aus `storages.name`.
    case customName
    /// todo.0.4.3.010 (Layout 06.03): Grund des letzten Fehlers (`IndexFailureReason.notificationCode`); fehlt = keiner.
    case failureReason
}

nonisolated enum MediumCodecV3 {
    // MARK: Zahlencodes

    static func code(_ type: StoredMediumType) -> Int {
        switch type {
        case .hdd: 0
        case .ssd: 1
        case .usb: 2
        }
    }

    static func type(_ code: Int) -> StoredMediumType {
        switch code {
        case 1: .ssd
        case 2: .usb
        default: .hdd
        }
    }

    static func code(_ decision: StoredIndexDecision) -> Int {
        switch decision {
        case .undecided: 0
        case .index: 1
        case .ignore, .dontIndex: 2
        }
    }

    static func decision(_ code: Int) -> StoredIndexDecision {
        switch code {
        case 1: .index
        case 2: .dontIndex
        default: .undecided
        }
    }

    static func code(_ status: StoredIndexStatus) -> Int {
        switch status {
        case .pending: 0
        case .indexing: 1
        case .indexed: 2
        case .error: 3
        }
    }

    static func status(_ code: Int) -> StoredIndexStatus {
        switch code {
        case 1: .indexing
        case 2: .indexed
        case 3: .error
        default: .pending
        }
    }

    private static let fileSystems = ["apfs", "hfs", "exfat", "msdos", "ntfs", "ufs", "smbfs", "nfs", "afpfs", "webdav", "cd9660", "udf"]

    /// Bekannte Dateisysteme als Zahl ab 1; 0 = anderes (Name steht dann in `storage_meta`).
    static func fileSystemCode(_ name: String) -> Int {
        (fileSystems.firstIndex(of: name) ?? -1) + 1
    }

    static func fileSystemName(_ code: Int) -> String? {
        code >= 1 && code <= fileSystems.count ? fileSystems[code - 1] : nil
    }

    // MARK: Binärkennungen

    static func data(_ uuid: UUID) -> Data {
        withUnsafeBytes(of: uuid.uuid) { Data($0) }
    }

    static func uuid(_ data: Data) -> UUID? {
        guard data.count == 16 else { return nil }
        return UUID(uuid: data.withUnsafeBytes { $0.loadUnaligned(as: uuid_t.self) })
    }

    private static let textMarker = Data(repeating: 0xFF, count: 8)

    /// 16 Byte, wenn die Kennung eine UUID ist; sonst Text mit 8-Byte-Vorsatz (kommt in der Praxis nicht vor).
    static func volumeData(_ value: String?) -> Data? {
        guard let value else { return nil }
        if let uuid = UUID(uuidString: value) { return data(uuid) }
        return textMarker + Data(value.utf8)
    }

    static func volumeString(_ data: Data?) -> String? {
        guard let data else { return nil }
        if data.count > 8, data.prefix(8) == textMarker { return String(data: data.dropFirst(8), encoding: .utf8) }
        return uuid(data)?.uuidString.lowercased()
    }

    /// Ersatz-Erkennung ohne Volume-UUID: Dateisystem, Erstelldatum (Sekunde), Größe. Fehlt das Datum, gibt es keinen.
    static func fingerprint(fsType: String, createdAt: Date?, totalBytes: Int64) -> Int64? {
        guard let created = VolumeIdentity.canonicalCreatedAt(createdAt) else { return nil }
        var hash: UInt64 = 14_695_981_039_346_656_037
        func mix(_ text: String) {
            for byte in text.utf8 {
                hash ^= UInt64(byte)
                hash &*= 1_099_511_628_211
            }
            hash &*= 1_099_511_628_211
        }
        mix(fsType)
        mix(String(SchemaTime.seconds(created)))
        mix(String(totalBytes))
        return Int64(bitPattern: hash)
    }

    // MARK: Wiedererkennung

    /// Wie stark ein gespeichertes Medium zu einem angeschlossenen Volume passt (Volume-UUID, sonst Fingerabdruck
    /// aus Dateisystem, Erstelldatum und Größe, sonst schwach über den Namen).
    static func match(stored: StoredMedium, identity: VolumeIdentity) -> MatchStrength? {
        let storedUUID = VolumeIdentity.canonicalVolumeUUID(stored.volumeUUID)
        let seenUUID = identity.volumeUUID
        if let storedUUID, let seenUUID {
            return storedUUID == seenUUID ? .uuid : nil
        }
        let storedCreated = VolumeIdentity.canonicalCreatedAt(stored.volumeCreatedAt)
        let seenCreated = identity.createdAt
        let sameFileSystem = stored.fsType == identity.fsType
        let sameSize = stored.volumeTotalBytes == identity.volumeTotalBytes
        if let storedCreated, let seenCreated, sameFileSystem, sameSize, VolumeIdentity.sameSecond(storedCreated, seenCreated) {
            return .fingerprint
        }
        let createdMissing = storedCreated == nil || seenCreated == nil
        if createdMissing, sameFileSystem, sameSize, stored.name == identity.name {
            return .weak
        }
        return nil
    }

    // MARK: Schreiben

    static func insert(_ db: Database, _ medium: StoredMedium) throws -> Int64 {
        var insertValues = fixedValues(medium)
        insertValues.insert(SchemaTime.seconds(medium.createdAt), at: 16)  // firstSeenAt vor lastSeenAt
        try db.execute(
            sql: """
                INSERT INTO storages (
                    uuid, volumeUUID, fingerprint, name, slug, type, fsType, totalBytes, usedBytes, decision,
                    rememberDecision, indexStatus, paused, isFavorite, fileCount, folderCount,
                    firstSeenAt, lastSeenAt, firstIndexedAt, lastIndexedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: StatementArguments(insertValues)
        )
        let id = db.lastInsertedRowID
        try writeMeta(db, storageID: id, medium)
        return id
    }

    /// Nur Nutzerfelder (bug.0.4.033); Indexer-Zähler und Ereignis-Cursor bleiben unberührt.
    static func updateUserFields(_ db: Database, storageID: Int64, _ medium: StoredMedium) throws {
        try db.execute(
            sql: """
                UPDATE storages SET
                    decision = ?, rememberDecision = ?, paused = ?, isFavorite = ?, type = ?
                WHERE id = ?
                """,
            arguments: [
                code(medium.decision),
                medium.rememberDecision,
                medium.autoIndexPaused,
                medium.isFavorite,
                code(medium.type),
                storageID,
            ]
        )
        try setMeta(db, storageID, .allowIndexing, value: medium.allowIndexing ? nil : "0")
        try setMeta(db, storageID, .showAbsoluteCapacity, value: medium.showAbsoluteCapacity ? "1" : nil)
        try setMeta(db, storageID, .isForgotten, value: medium.isForgotten ? "1" : nil)
    }

    /// Erkennungs- und Anzeigefelder ohne Indexer-Metadaten.
    static func updateRecognitionFields(_ db: Database, storageID: Int64, _ medium: StoredMedium) throws {
        let volume = VolumeIdentity.canonicalVolumeUUID(medium.volumeUUID)
        let created = VolumeIdentity.canonicalCreatedAt(medium.volumeCreatedAt)
        try db.execute(
            sql: """
                UPDATE storages SET
                    volumeUUID = ?, fingerprint = ?, name = ?, slug = ?, type = ?, fsType = ?, totalBytes = ?, usedBytes = ?,
                    lastSeenAt = ?
                WHERE id = ?
                """,
            arguments: [
                volumeData(volume),
                fingerprint(fsType: medium.fsType, createdAt: created, totalBytes: medium.volumeTotalBytes),
                medium.name,
                Slug.make(medium.name),
                // bug.0.4.230: Typ wird bei jedem Anschließen neu bestimmt (Konzept `medien.md` 2c).
                code(medium.type),
                fileSystemCode(medium.fsType),
                medium.volumeTotalBytes,
                medium.capacityUsedBytes,
                medium.lastSeenAt.map(SchemaTime.seconds),
                storageID,
            ]
        )
        try setMeta(db, storageID, .volumeCreatedAt, date: created.map(SchemaTime.seconds))
        try setMeta(db, storageID, .diskSizeBytes, value: medium.diskSizeBytes.map(String.init))
        let known = fileSystemCode(medium.fsType) != 0
        try setMeta(db, storageID, .fsTypeName, value: known ? nil : medium.fsType)
    }

    static func updateIndexStatus(_ db: Database, storageID: Int64, _ status: StoredIndexStatus) throws {
        try db.execute(
            sql: "UPDATE storages SET indexStatus = ? WHERE id = ?",
            arguments: [code(status), storageID]
        )
    }

    static func updateLastSeen(_ db: Database, storageID: Int64, at date: Date) throws {
        try db.execute(
            sql: "UPDATE storages SET lastSeenAt = ? WHERE id = ?",
            arguments: [SchemaTime.seconds(date), storageID]
        )
    }

    static func updateDecisionFields(_ db: Database, storageID: Int64, _ medium: StoredMedium) throws {
        try db.execute(
            sql: """
                UPDATE storages SET decision = ?, rememberDecision = ?, indexStatus = ?
                WHERE id = ?
                """,
            arguments: [code(medium.decision), medium.rememberDecision, code(medium.indexStatus), storageID]
        )
        try setMeta(db, storageID, .allowIndexing, value: medium.allowIndexing ? nil : "0")
    }

    /// Ersetzt alle Felder (außer `firstSeenAt`, das bleibt).
    static func update(_ db: Database, storageID: Int64, _ medium: StoredMedium) throws {
        try db.execute(
            sql: """
                UPDATE storages SET
                    volumeUUID = ?, fingerprint = ?, name = ?, slug = ?, type = ?, fsType = ?, totalBytes = ?, usedBytes = ?,
                    decision = ?, rememberDecision = ?, indexStatus = ?, paused = ?, isFavorite = ?, fileCount = ?,
                    folderCount = ?, lastSeenAt = ?, firstIndexedAt = ?, lastIndexedAt = ?
                WHERE id = ?
                """,
            arguments: StatementArguments(Array(fixedValues(medium).dropFirst()) + [storageID])
        )
        try writeMeta(db, storageID: storageID, medium)
    }

    /// Reihenfolge wie im INSERT ohne `firstSeenAt`.
    private static func fixedValues(_ medium: StoredMedium) -> [DatabaseValueConvertible?] {
        let volume = VolumeIdentity.canonicalVolumeUUID(medium.volumeUUID)
        let created = VolumeIdentity.canonicalCreatedAt(medium.volumeCreatedAt)
        return [
            data(medium.uuid),
            volumeData(volume),
            fingerprint(fsType: medium.fsType, createdAt: created, totalBytes: medium.volumeTotalBytes),
            medium.name,
            Slug.make(medium.name),
            code(medium.type),
            fileSystemCode(medium.fsType),
            medium.volumeTotalBytes,
            medium.capacityUsedBytes,
            code(medium.decision),
            medium.rememberDecision,
            code(medium.indexStatus),
            medium.autoIndexPaused,
            medium.isFavorite,
            medium.fileCount,
            medium.folderCount,
            medium.lastSeenAt.map(SchemaTime.seconds),
            medium.firstIndexedAt.map(SchemaTime.seconds),
            medium.lastIndexedAt.map(SchemaTime.seconds),
        ]
    }

    /// Alles, was nicht in `storages` steht. `scanTotal` setzt nur `setScanTotal` (wie in der alten Schicht).
    private static func writeMeta(_ db: Database, storageID: Int64, _ medium: StoredMedium) throws {
        let created = VolumeIdentity.canonicalCreatedAt(medium.volumeCreatedAt)
        try setMeta(db, storageID, .volumeCreatedAt, date: created.map(SchemaTime.seconds))
        try setMeta(db, storageID, .diskSizeBytes, value: medium.diskSizeBytes.map(String.init))
        let known = fileSystemCode(medium.fsType) != 0
        try setMeta(db, storageID, .fsTypeName, value: known ? nil : medium.fsType)
        try setMeta(db, storageID, .lastIndexActivityAt, date: medium.lastIndexActivityAt.map(SchemaTime.seconds))
        try setMeta(db, storageID, .isForgotten, value: medium.isForgotten ? "1" : nil)
        try setMeta(db, storageID, .allowIndexing, value: medium.allowIndexing ? nil : "0")
        try setMeta(db, storageID, .showAbsoluteCapacity, value: medium.showAbsoluteCapacity ? "1" : nil)
        try setMeta(db, storageID, .fsEventsUUID, value: medium.fsEventsUUID)
        try setMeta(db, storageID, .lastEventID, value: medium.lastEventID.map(String.init))
        try setMeta(db, storageID, .completedDepth, value: medium.completedDepth == 0 ? nil : String(medium.completedDepth))
    }

    // MARK: Schlüssel/Wert

    static func keyID(_ db: Database, _ key: StorageMetaKey) throws -> Int64 {
        if let id = try Int64.fetchOne(db, sql: "SELECT id FROM meta_keys WHERE key = ?", arguments: [key.rawValue]) {
            return id
        }
        try db.execute(sql: "INSERT INTO meta_keys (key) VALUES (?)", arguments: [key.rawValue])
        return db.lastInsertedRowID
    }

    /// `nil` für Wert und Datum löscht den Schlüssel.
    static func setMeta(_ db: Database, _ storageID: Int64, _ key: StorageMetaKey, value: String? = nil, date: Int64? = nil) throws {
        let keyID = try keyID(db, key)
        if value == nil, date == nil {
            try db.execute(sql: "DELETE FROM storage_meta WHERE storageID = ? AND keyID = ?", arguments: [storageID, keyID])
        } else {
            try db.execute(
                sql: "INSERT OR REPLACE INTO storage_meta (storageID, keyID, value, date) VALUES (?, ?, ?, ?)",
                arguments: [storageID, keyID, value, date]
            )
        }
    }

    static func metaValue(_ db: Database, _ storageID: Int64, _ key: StorageMetaKey) throws -> String? {
        try String.fetchOne(
            db,
            sql: """
                SELECT m.value FROM storage_meta m JOIN meta_keys k ON k.id = m.keyID
                WHERE m.storageID = ? AND k.key = ?
                """,
            arguments: [storageID, key.rawValue]
        )
    }

    // MARK: Lesen

    /// bug.0.4.224: Medien, deren Einträge nach dem Vergessen noch gelöscht werden (älteste zuerst).
    static func pendingDeletionStorageIDs(_ db: Database) throws -> [Int64] {
        try Int64.fetchAll(
            db,
            sql: "SELECT m.storageID FROM storage_meta m JOIN meta_keys k ON k.id = m.keyID WHERE k.key = ? ORDER BY m.storageID",
            arguments: [StorageMetaKey.pendingDeletion.rawValue]
        )
    }

    /// bug.0.4.224: Bedingung „nicht vergessen“ für Abfragen über `storages` (Spalte `id` der Tabelle `storages`).
    static let notPendingDeletionSQL = """
        NOT EXISTS (
            SELECT 1 FROM storage_meta pm JOIN meta_keys pk ON pk.id = pm.keyID
            WHERE pm.storageID = storages.id AND pk.key = '\(StorageMetaKey.pendingDeletion.rawValue)'
        )
        """

    static func storageRowID(_ db: Database, uuid: UUID) throws -> Int64? {
        try Int64.fetchOne(db, sql: "SELECT id FROM storages WHERE uuid = ?", arguments: [data(uuid)])
    }

    static func fetch(_ db: Database, uuid: UUID) throws -> StoredMedium? {
        try fetchAll(db, whereClause: "WHERE uuid = ?", arguments: [data(uuid)]).first
    }

    static func fetchAll(_ db: Database, whereClause: String = "", arguments: StatementArguments = []) throws -> [StoredMedium] {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM storages \(whereClause) ORDER BY slug, uuid", arguments: arguments)
        var result: [StoredMedium] = []
        for row in rows {
            let id: Int64 = row["id"]
            var meta: [String: (value: String?, date: Int64?)] = [:]
            for entry in try Row.fetchAll(
                db,
                sql: "SELECT k.key AS key, m.value AS value, m.date AS date FROM storage_meta m JOIN meta_keys k ON k.id = m.keyID WHERE m.storageID = ?",
                arguments: [id]
            ) {
                meta[entry["key"]] = (entry["value"], entry["date"])
            }
            // bug.0.4.224: ein vergessenes Medium, dessen Einträge noch gelöscht werden, gibt es nicht mehr.
            if meta[StorageMetaKey.pendingDeletion.rawValue] != nil { continue }
            result.append(try medium(row, meta: meta))
        }
        // todo.0.4.2.002: Reihenfolge nach dem angezeigten Namen (ohne eigene Namen dieselbe wie `ORDER BY slug, uuid`).
        guard result.contains(where: { $0.customName != nil }) else { return result }
        return result.sorted { lhs, rhs in
            let left = Slug.make(lhs.customName ?? lhs.name)
            let right = Slug.make(rhs.customName ?? rhs.name)
            return left != right ? left < right : lhs.uuid.uuidString < rhs.uuid.uuidString
        }
    }

    private static func medium(_ row: Row, meta: [String: (value: String?, date: Int64?)]) throws -> StoredMedium {
        guard let uuidData: Data = row["uuid"], let uuid = uuid(uuidData) else { throw IndexStoreError.invalidStoredUUID }
        func value(_ key: StorageMetaKey) -> String? { meta[key.rawValue]?.value }
        func date(_ key: StorageMetaKey) -> Date? { meta[key.rawValue]?.date.map(SchemaTime.date) }
        let fsCode: Int = row["fsType"]
        let fsName = fileSystemName(fsCode) ?? value(.fsTypeName) ?? ""
        func optionalDate(_ column: String) -> Date? {
            (row[column] as Int64?).map(SchemaTime.date)
        }
        var stored = StoredMedium(
            uuid: uuid,
            volumeUUID: volumeString(row["volumeUUID"] as Data?),
            volumeCreatedAt: date(.volumeCreatedAt),
            fsType: fsName,
            volumeTotalBytes: row["totalBytes"],
            diskSizeBytes: value(.diskSizeBytes).flatMap(Int64.init),
            name: row["name"],
            type: type(row["type"]),
            decision: decision(row["decision"]),
            rememberDecision: row["rememberDecision"],
            indexStatus: status(row["indexStatus"]),
            allowIndexing: value(.allowIndexing) != "0",
            autoIndexPaused: row["paused"],
            capacityUsedBytes: (row["usedBytes"] as Int64?) ?? 0,
            fileCount: row["fileCount"],
            folderCount: row["folderCount"],
            lastSeenAt: optionalDate("lastSeenAt"),
            firstIndexedAt: optionalDate("firstIndexedAt"),
            lastIndexedAt: optionalDate("lastIndexedAt"),
            lastIndexActivityAt: date(.lastIndexActivityAt),
            isForgotten: value(.isForgotten) == "1",
            showAbsoluteCapacity: value(.showAbsoluteCapacity) == "1",
            isFavorite: row["isFavorite"],
            fsEventsUUID: value(.fsEventsUUID),
            lastEventID: value(.lastEventID).flatMap(Int64.init),
            completedDepth: value(.completedDepth).flatMap(Int.init) ?? 0,
            scanTotal: value(.scanTotal).flatMap(Int.init) ?? 0,
            createdAt: optionalDate("firstSeenAt") ?? Date(timeIntervalSince1970: 0)
        )
        stored.volumeUUID = VolumeIdentity.canonicalVolumeUUID(stored.volumeUUID)
        stored.hasIndexGaps = meta[IndexStoreV3.indexGapsKey]?.value == "1"
        stored.customName = value(.customName)
        stored.failureReasonCode = value(.failureReason)
        return stored
    }
}
