//
//  IndexingTestSupport.swift
//  diskindexTests
//
//  ScanHarness und Hilfen aus dem früheren IndexingTests.swift (Aufgabe 111).
//

import Foundation
import Testing
@testable import diskindex


@Test func stableRowIDIsDeterministicAndUnique() {
    let medium = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    let first = IndexedItem.stableID(mediumID: medium, rowID: 1)
    let again = IndexedItem.stableID(mediumID: medium, rowID: 1)
    let other = IndexedItem.stableID(mediumID: medium, rowID: 2)
    let otherMedium = IndexedItem.stableID(mediumID: UUID(), rowID: 1)
    #expect(first == again)
    #expect(first != other)
    #expect(first != otherMedium)
    var seen = Set<UUID>()
    for row in 0..<1_000 {
        #expect(seen.insert(IndexedItem.stableID(mediumID: medium, rowID: Int64(row))).inserted)
    }
}

final class Arm: @unchecked Sendable {
    var value = true
}

final class StatusLog: @unchecked Sendable {
    var values: [StoredIndexStatus] = [.pending]
}

struct ScanHarness {
    let store: IndexStoreV3
    let mediumID: UUID
    private let indexer = DirectoryIndexer()

    static func make() async throws -> ScanHarness {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-scan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "TEST", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        return ScanHarness(store: store, mediumID: medium.uuid)
    }

    func volume(at path: String) -> VolumeInfo {
        VolumeInfo(
            mountPath: path,
            name: "TEST",
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            volumeFreeBytes: nil,
            diskSizeBytes: nil,
            volumeUUID: nil,
            createdAt: nil,
            isRemovable: true,
            isEjectable: true,
            isInternal: false,
            isLocal: true,
            deviceProtocol: "USB",
            model: nil,
            isTimeMachineSnapshot: false
        )
    }

    func run(
        access: any MediumAccess,
        maxDepth: Int?,
        fromScratch: Bool = true,
        ignoreHidden: Bool = true,
        patterns: [String] = [],
        volume: VolumeInfo? = nil,
        limits: IndexingRunLimits = .standard,
        shouldHalt: @escaping @Sendable () async -> ScanHalt = { .none },
        onProgress: @escaping @Sendable (IndexProgress) async -> Void = { _ in }
    ) async throws -> IndexRunOutcome {
        await indexer.run(
            store: store,
            access: access,
            mediumUUID: mediumID,
            volume: volume ?? self.volume(at: "/Volumes/T"),
            configuration: ScanConfiguration(maxDepth: maxDepth, ignoreHiddenFiles: ignoreHidden, excludedPatterns: patterns, limits: limits),
            fromScratch: fromScratch,
            token: UUID(),
            shouldHalt: shouldHalt,
            onProgress: onProgress
        )
    }

    func names() async throws -> Set<String> {
        var found: [StoredItem] = []
        func walk(_ parent: Int64?) async throws {
            let children = try await store.children(mediumUUID: mediumID, parentID: parent)
            found.append(contentsOf: children)
            for child in children where child.isFolder {
                try await walk(child.id)
            }
        }
        try await walk(nil)
        return Set(found.map(\.name))
    }

    func item(named name: String) async throws -> StoredItem? {
        var found: StoredItem?
        func walk(_ parent: Int64?) async throws {
            let children = try await store.children(mediumUUID: mediumID, parentID: parent)
            for child in children {
                if child.name == name { found = child }
                if child.isFolder { try await walk(child.id) }
            }
        }
        try await walk(nil)
        return found
    }
}

