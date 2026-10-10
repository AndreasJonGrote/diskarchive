//
//  IndexedItem.swift
//  diskindex
//

import Foundation

struct IndexedItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case folder
        case file
    }

    let id: UUID
    /// Zeile in `item`. Leer nur bei Vorschauen ohne Datenbank.
    var rowID: Int64?
    let name: String
    let kind: Kind
    /// Ordnerpfad, in dem das Objekt liegt (ohne Medium).
    let parentPath: [String]
    let modifiedAt: Date?
    let sizeBytes: Int64?
    let lastSeenAt: Date?
    var listedAt: Date?
    var unreadable: Bool = false
    var isFavorite: Bool = false
    var isPackage: Bool = false
    /// Dateityp-Icon — einmal beim Laden, nicht je Zeile neu.
    let fileKind: FileKind

    var isFolder: Bool { kind == .folder }

    static func fileKind(for name: String, kind: Kind, isPackage: Bool) -> FileKind {
        FileKind(fileName: name, isFolder: kind == .folder, isPackage: isPackage)
    }

    /// Stabile Kennung aus Medium-UUID und Zeilennummer, ohne Hash.
    /// Die ersten acht Bytes sind Medium XOR Zeile, die letzten acht bleiben vom Medium.
    static func stableID(mediumID: UUID, rowID: Int64) -> UUID {
        let medium = mediumID.uuid
        var bytes: [UInt8] = [
            medium.0, medium.1, medium.2, medium.3,
            medium.4, medium.5, medium.6, medium.7,
            medium.8, medium.9, medium.10, medium.11,
            medium.12, medium.13, medium.14, medium.15,
        ]
        var row = UInt64(bitPattern: rowID).bigEndian
        withUnsafeBytes(of: &row) { raw in
            for index in 0..<8 {
                bytes[index] ^= raw[index]
            }
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    init(
        id: UUID,
        rowID: Int64? = nil,
        name: String,
        kind: Kind,
        parentPath: [String],
        modifiedAt: Date?,
        sizeBytes: Int64?,
        lastSeenAt: Date?,
        listedAt: Date? = nil,
        unreadable: Bool = false,
        isFavorite: Bool = false,
        isPackage: Bool = false,
        fileKind: FileKind? = nil
    ) {
        self.id = id
        self.rowID = rowID
        self.name = name
        self.kind = kind
        self.parentPath = parentPath
        self.modifiedAt = modifiedAt
        self.sizeBytes = sizeBytes
        self.lastSeenAt = lastSeenAt
        self.listedAt = listedAt
        self.unreadable = unreadable
        self.isFavorite = isFavorite
        self.isPackage = isPackage
        self.fileKind = fileKind ?? Self.fileKind(for: name, kind: kind, isPackage: isPackage)
    }

    init(stored: StoredItem, parentPath: [String]? = nil) {
        let resolvedParent: [String]
        if let parentPath {
            resolvedParent = parentPath
        } else {
            let parts = stored.path.split(separator: "/").map(String.init)
            resolvedParent = Array(parts.dropLast())
        }
        let kind: Kind = stored.isFolder ? .folder : .file
        self.id = Self.stableID(mediumID: stored.mediumUUID, rowID: stored.id)
        self.rowID = stored.id
        self.name = stored.name
        self.kind = kind
        self.parentPath = resolvedParent
        self.modifiedAt = stored.modifiedAt
        self.sizeBytes = stored.sizeBytes
        self.lastSeenAt = stored.lastSeenAt
        self.listedAt = stored.listedAt
        self.unreadable = stored.unreadable
        self.isFavorite = stored.isFavorite
        self.isPackage = stored.isPackage
        self.fileKind = Self.fileKind(for: stored.name, kind: kind, isPackage: stored.isPackage)
    }
}
