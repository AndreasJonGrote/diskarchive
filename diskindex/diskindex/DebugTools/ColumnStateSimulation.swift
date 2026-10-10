//
//  ColumnStateSimulation.swift
//  diskindex
//
//  Debug-Demo: Medium mit Ordnern für Spalten-Sonderzustände (Layout 07).
//

import Foundation

#if DEBUG

enum ColumnStateSimulation {
    private static let mediumIDString = "D0600001-0000-4000-8000-000000000001"

    /// Feste Kennung — nicht in der Datenbank, nur im Speicher (nur Hex-Ziffern, RFC 4122).
    static let mediumID: UUID = {
        guard let id = UUID(uuidString: mediumIDString) else {
            preconditionFailure("ColumnStateSimulation: ungültige mediumID \(mediumIDString)")
        }
        return id
    }()

    static let mediumName = "Spalten-Zustände (Demo)"

    enum FolderName {
        /// Container unter dem Demo-Medium (wie im Layout „Projekte“).
        static let projects = "Projekte"
        /// README §5 (1): Ordner wird noch indiziert — Hinweis in der nächsten Spalte.
        static let pendingIndexing = "Beispiel 1 — Wird indiziert"
        /// README §5 (2): Scan-Tiefe — virtuelle Spalte, kein Pfad.
        static let uncapturedScanDepth = "Beispiel 2 — Scan-Tiefe"
        /// README §5 (3): Sehr großer Ordner — Ladehinweis in der Spalte.
        static let loadingContents = "Beispiel 3 — Inhalte werden geladen"
    }

    static let simulatedLoadingTotal = 41_902
    /// Angehaltener Ladestand (Layout Screen 07) — Demo endet absichtlich nicht.
    static let simulatedLoadingFrozenCount = 12_480
    static let simulatedLoadingSteps: [Int] = [
        2_400, 5_800, 9_200, simulatedLoadingFrozenCount,
    ]

    /// Ladehinweis in der Demo-Spalte sofort (kein 1-s-T1-Delay).
    static let demoLoadingHintTiming = DelayedLoadingTiming(
        delayBeforeHint: .zero,
        minimumHintVisible: .zero
    )

    static func isSimulationMedium(_ id: UUID) -> Bool {
        id == mediumID
    }

    static func isLoadingColumnPath(_ path: [String]) -> Bool {
        path == [FolderName.projects, FolderName.loadingContents]
    }

    /// Tests schalten die Demo ein, ohne den XCTest-Schutz für die übrige Suite aufzuheben.
    static var injectOverrideForTesting = false

    static func shouldInjectIntoMediaList() -> Bool {
        #if DEBUG
        if injectOverrideForTesting { return true }
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil { return false }
        if env["XCTestSessionIdentifier"] != nil { return false }
        return true
        #else
        return false
        #endif
    }

    static func makeMedium() -> Medium {
        Medium(
            id: mediumID,
            name: mediumName,
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexing,
            allowIndexing: true,
            autoIndexPaused: false,
            decision: .index,
            capacityTotalBytes: 120_000_000_000,
            capacityUsedBytes: 45_000_000_000,
            fileCount: 20_997,
            folderCount: 3,
            scanTotal: 50_000,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: Date(),
            completedDepth: 5,
            isForgotten: false,
            indexingProgress: 0
        )
    }

    static func rootItems(mediumID: UUID) -> [IndexedItem] {
        [
            folderItem(mediumID: mediumID, rowID: 9001, name: FolderName.projects, parentPath: [], listedAt: Date()),
        ]
    }

    static func children(mediumID: UUID, path: [String]) -> [IndexedItem]? {
        switch path {
        case []:
            return nil
        case [FolderName.projects]:
            return [
                folderItem(
                    mediumID: mediumID,
                    rowID: 9002,
                    name: FolderName.pendingIndexing,
                    parentPath: path,
                    listedAt: nil
                ),
                folderItem(
                    mediumID: mediumID,
                    rowID: 9003,
                    name: FolderName.uncapturedScanDepth,
                    parentPath: path,
                    listedAt: Date()
                ),
                folderItem(
                    mediumID: mediumID,
                    rowID: 9004,
                    name: FolderName.loadingContents,
                    parentPath: path,
                    listedAt: Date()
                ),
            ]
        case [FolderName.projects, FolderName.loadingContents]:
            // Während des Ladens leer; danach `loadedChildren`.
            return []
        default:
            return []
        }
    }

    static func loadedChildren(mediumID: UUID) -> [IndexedItem] {
        [
            IndexedItem(
                id: IndexedItem.stableID(mediumID: mediumID, rowID: 9010),
                rowID: 9010,
                name: "Beispiel nach dem Laden.txt",
                kind: .file,
                parentPath: [FolderName.projects, FolderName.loadingContents],
                modifiedAt: Date(),
                sizeBytes: 4096,
                lastSeenAt: Date(),
                listedAt: Date()
            ),
        ]
    }

    static func resolveOpenState(mediumID: UUID, folderName: String?) -> ColumnFolderOpenState? {
        guard isSimulationMedium(mediumID), let folderName else { return nil }
        switch folderName {
        case FolderName.pendingIndexing:
            return .pendingIndex
        case FolderName.uncapturedScanDepth:
            return .uncaptured(.scanDepth)
        default:
            return nil
        }
    }

    private static func folderItem(
        mediumID: UUID,
        rowID: Int64,
        name: String,
        parentPath: [String],
        listedAt: Date?
    ) -> IndexedItem {
        IndexedItem(
            id: IndexedItem.stableID(mediumID: mediumID, rowID: rowID),
            rowID: rowID,
            name: name,
            kind: .folder,
            parentPath: parentPath,
            modifiedAt: Date(),
            sizeBytes: nil,
            lastSeenAt: Date(),
            listedAt: listedAt
        )
    }
}

#endif
