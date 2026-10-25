//
//  IndexRecords.swift
//  diskindex
//
//  Werte, die der Index speichert. Keine GRDB-Typen.
//

import Foundation

/// Inkrementelle Anpassung von `medium.fileCount` / `folderCount` je Schreibvorgang (Aufgabe 101).
nonisolated struct MediumCountDelta: Equatable, Sendable {
    var files: Int = 0
    var folders: Int = 0

    static let zero = MediumCountDelta()

    mutating func addVisible(isFolder: Bool) {
        if isFolder { folders += 1 } else { files += 1 }
    }

    mutating func removeVisible(isFolder: Bool) {
        if isFolder { folders -= 1 } else { files -= 1 }
    }
}

nonisolated func + (lhs: MediumCountDelta, rhs: MediumCountDelta) -> MediumCountDelta {
    MediumCountDelta(files: lhs.files + rhs.files, folders: lhs.folders + rhs.folders)
}

nonisolated enum StoredMediumType: String, Sendable, Equatable {
    case usb
    case ssd
    case hdd
}

nonisolated enum StoredIndexStatus: String, Sendable, Equatable {
    case indexing
    case indexed
    case error
    case pending
}

nonisolated enum StoredIndexDecision: String, Sendable, Equatable {
    case undecided
    case index
    case ignore
    case dontIndex

    static func resolved(_ raw: String) -> StoredIndexDecision {
        if raw == "ignore" || raw == "dontIndex" { return .dontIndex }
        return StoredIndexDecision(rawValue: raw) ?? .undecided
    }

    var refusesIndexing: Bool {
        self == .ignore || self == .dontIndex
    }
}

nonisolated enum IndexStoreError: Error, Equatable, Sendable {
    case unknownMedium
    case unknownParent
    case unknownItem
    case invalidStoredUUID
    case directoryWriteFailed
    case childrenReadFailed
    /// Migrationen der DB sind neuer als diese App (bug.0.4.013).
    case schemaSuperseded
}

/// Was der Scanner von einem einzelnen Objekt meldet.
nonisolated struct ScannedEntry: Sendable, Equatable {
    var name: String
    var isFolder: Bool
    var isPackage: Bool = false
    var sizeBytes: Int64?
    var modifiedAt: Date?
    var fileID: String?
    /// Hardlink-Zähler aus Bulk-Lesen (`ATTR_FILE_LINKCOUNT`); `nil` = unbekannt.
    var linkCount: Int? = nil
}

/// Wie stark ein gespeichertes Medium zu einem angeschlossenen Volume passt.
nonisolated enum MatchStrength: Int, Sendable, Comparable {
    case weak = 0
    case fingerprint = 1
    case uuid = 2

    static func < (lhs: MatchStrength, rhs: MatchStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

nonisolated struct MediumCandidate: Sendable, Equatable {
    var medium: StoredMedium
    var strength: MatchStrength
}

/// Merkmale eines gerade eingebundenen Volumes, für die Wiedererkennung.
nonisolated struct VolumeIdentity: Sendable, Equatable {
    var volumeUUID: String?
    var fsType: String
    var volumeTotalBytes: Int64
    var diskSizeBytes: Int64?
    var name: String
    var createdAt: Date?

    init(
        volumeUUID: String? = nil,
        fsType: String,
        volumeTotalBytes: Int64,
        diskSizeBytes: Int64? = nil,
        name: String,
        createdAt: Date? = nil
    ) {
        self.volumeUUID = Self.canonicalVolumeUUID(volumeUUID)
        self.fsType = fsType
        self.volumeTotalBytes = volumeTotalBytes
        self.diskSizeBytes = diskSizeBytes
        self.name = name
        self.createdAt = Self.canonicalCreatedAt(createdAt)
    }

    /// Leere und Null-UUIDs zählen als „keine UUID“.
    static func canonicalVolumeUUID(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let lowered = raw.lowercased()
        if lowered == "00000000-0000-0000-0000-000000000000" { return nil }
        return lowered
    }

    /// Fehlend, 1970-01-01 oder 1980-01-01 (jeweils 00:00:00 UTC) zählt als kein Datum.
    static func canonicalCreatedAt(_ date: Date?) -> Date? {
        guard let date else { return nil }
        let second = Int64(date.timeIntervalSince1970.rounded(.towardZero))
        if second == 0 || second == 315_532_800 { return nil }
        return Date(timeIntervalSince1970: TimeInterval(second))
    }

    static func sameSecond(_ lhs: Date, _ rhs: Date) -> Bool {
        Int64(lhs.timeIntervalSince1970.rounded(.towardZero)) == Int64(rhs.timeIntervalSince1970.rounded(.towardZero))
    }
}

/// Eine Zeile aus `medium`. `uuid` ist die stabile App-ID (`Medium.id`).
nonisolated struct StoredMedium: Sendable, Equatable {
    var uuid: UUID
    var volumeUUID: String?
    var volumeCreatedAt: Date?
    var fsType: String
    var volumeTotalBytes: Int64
    var diskSizeBytes: Int64?
    var name: String
    var type: StoredMediumType
    var decision: StoredIndexDecision
    var rememberDecision: Bool
    var indexStatus: StoredIndexStatus
    var allowIndexing: Bool
    var autoIndexPaused: Bool
    var capacityUsedBytes: Int64
    var fileCount: Int
    var folderCount: Int
    var lastSeenAt: Date?
    var firstIndexedAt: Date?
    var lastIndexedAt: Date?
    var lastIndexActivityAt: Date?
    var isForgotten: Bool
    var showAbsoluteCapacity: Bool
    var isFavorite: Bool
    var fsEventsUUID: String?
    var lastEventID: Int64?
    var completedDepth: Int
    var scanTotal: Int
    var createdAt: Date
    /// bug.0.4.200: Merker `indexGaps` (nur gelesen; geschrieben von `finishIndexing`).
    var hasIndexGaps = false

    init(
        uuid: UUID = UUID(),
        volumeUUID: String? = nil,
        volumeCreatedAt: Date? = nil,
        fsType: String,
        volumeTotalBytes: Int64,
        diskSizeBytes: Int64? = nil,
        name: String,
        type: StoredMediumType = .hdd,
        decision: StoredIndexDecision = .undecided,
        rememberDecision: Bool = false,
        indexStatus: StoredIndexStatus = .pending,
        allowIndexing: Bool = true,
        autoIndexPaused: Bool = false,
        capacityUsedBytes: Int64 = 0,
        fileCount: Int = 0,
        folderCount: Int = 0,
        lastSeenAt: Date? = nil,
        firstIndexedAt: Date? = nil,
        lastIndexedAt: Date? = nil,
        lastIndexActivityAt: Date? = nil,
        isForgotten: Bool = false,
        showAbsoluteCapacity: Bool = false,
        isFavorite: Bool = false,
        fsEventsUUID: String? = nil,
        lastEventID: Int64? = nil,
        completedDepth: Int = 0,
        scanTotal: Int = 0,
        createdAt: Date = Date()
    ) {
        self.uuid = uuid
        self.volumeUUID = VolumeIdentity.canonicalVolumeUUID(volumeUUID)
        self.volumeCreatedAt = VolumeIdentity.canonicalCreatedAt(volumeCreatedAt)
        self.fsType = fsType
        self.volumeTotalBytes = volumeTotalBytes
        self.diskSizeBytes = diskSizeBytes
        self.name = name
        self.type = type
        self.decision = decision
        self.rememberDecision = rememberDecision
        self.indexStatus = indexStatus
        self.allowIndexing = allowIndexing
        self.autoIndexPaused = autoIndexPaused
        self.capacityUsedBytes = capacityUsedBytes
        self.fileCount = fileCount
        self.folderCount = folderCount
        self.lastSeenAt = lastSeenAt
        self.firstIndexedAt = firstIndexedAt
        self.lastIndexedAt = lastIndexedAt
        self.lastIndexActivityAt = lastIndexActivityAt
        self.isForgotten = isForgotten
        self.showAbsoluteCapacity = showAbsoluteCapacity
        self.isFavorite = isFavorite
        self.fsEventsUUID = fsEventsUUID
        self.lastEventID = lastEventID
        self.completedDepth = completedDepth
        self.scanTotal = scanTotal
        self.createdAt = createdAt
    }

    /// bug.0.4.200: wie `Medium.hasCompleteIndexExceptGaps` (eine Regel, `IndexGaps.completeExceptGaps`).
    var hasCompleteIndexExceptGaps: Bool {
        IndexGaps.completeExceptGaps(indexed: indexStatus == .indexed, error: indexStatus == .error, gaps: hasIndexGaps)
    }
}

/// Fortschritt für `IndexStoreV3.childrenPage` (Sortierung: Suchname natürlich, Kennung). `name` trägt den Suchnamen
/// des letzten Eintrags; `isFolder` ist ohne Bedeutung.
nonisolated struct ItemChildrenCursor: Sendable, Equatable {
    var isFolder: Bool
    var name: String
    var id: Int64
}

/// Eine Zeile aus `items`. `id` ist der Datenbankschlüssel, nicht die App-UUID.
nonisolated struct StoredItem: Sendable, Equatable, Identifiable {
    var id: Int64
    var mediumUUID: UUID
    var parentID: Int64?
    var name: String
    var isFolder: Bool
    var isPackage: Bool
    var ext: String?
    var sizeBytes: Int64?
    var modifiedAt: Date?
    var fileID: String?
    var depth: Int
    var path: String
    var isFavorite: Bool
    var listedAt: Date?
    var unreadable: Bool = false
}
