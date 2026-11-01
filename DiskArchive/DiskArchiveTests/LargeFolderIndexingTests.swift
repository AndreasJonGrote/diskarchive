//
//  LargeFolderIndexingTests.swift
//  DiskArchiveTests
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized) struct LargeFolderIndexingTests {
    @Test func abortMidLargeFolderThenResumeWithoutLossOrDuplicates() async throws {
        let harness = try await LargeScanHarness.make(batchEntryLimit: 800)
        let access = MemoryVolume(mountPath: "/Volumes/T")
        let fileCount = 6_100
        for index in 0..<fileCount {
            access.file("big/f-\(index).txt", size: Int64(index))
        }
        let savedID = IDBox()
        let first = try await harness.run(access: access, maxDepth: nil, shouldHalt: {
            let live = try? await harness.liveVisibleEntryCount()
            if (live ?? 0) >= 500, savedID.value == nil {
                savedID.value = try? await harness.item(named: "f-100.txt")?.id
            }
            return (live ?? 0) >= 2_500 ? .cancel : .none
        })
        #expect(first.status == .pending)
        let midCount = try await harness.liveVisibleEntryCount()
        #expect(midCount >= 500)
        #expect(midCount < fileCount + 1)

        let second = try await harness.run(access: access, maxDepth: nil, fromScratch: false)
        #expect(second.status == .indexed)
        let names = try await harness.namesUnderBig()
        #expect(names.count == fileCount)
        if let id = savedID.value {
            let again = try #require(try await harness.store.item(id: id))
            #expect(again.name == "f-100.txt")
        }
        let ids = try await harness.fileIDsUnderBig()
        #expect(Set(ids).count == ids.count)
    }

    @Test func tombstoneOnlyAfterFolderFinalize() async throws {
        let harness = try await LargeScanHarness.make(batchEntryLimit: 800)
        let access = MemoryVolume(mountPath: "/Volumes/T")
        for index in 0..<6_000 {
            access.file("big/f-\(index).txt")
        }
        _ = try await harness.run(access: access, maxDepth: nil, shouldHalt: {
            let live = try? await harness.liveVisibleEntryCount()
            return (live ?? 0) >= 2_000 ? .cancel : .none
        })
        let indexed = try await harness.anyFileUnderBig()
        let removePath = "big/\(indexed.name)"
        access.remove(removePath)
        _ = try await harness.run(access: access, maxDepth: nil, fromScratch: false)
        #expect(try await harness.store.item(id: indexed.id) == nil)
    }
}

private final class IDBox: @unchecked Sendable {
    var value: Int64?
}

private struct LargeScanHarness {
    let store: IndexStoreV3
    let mediumID: UUID
    let batchEntryLimit: Int
    private let indexer = DirectoryIndexer()

    static func make(batchEntryLimit: Int = IndexingRunLimits.standard.batchEntryLimit) async throws -> LargeScanHarness {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-large-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000_000, name: "BIG", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        return LargeScanHarness(store: store, mediumID: medium.uuid, batchEntryLimit: batchEntryLimit)
    }

    func run(
        access: MemoryVolume,
        maxDepth: Int?,
        fromScratch: Bool = true,
        shouldHalt: @escaping @Sendable () async -> ScanHalt = { .none }
    ) async throws -> IndexRunOutcome {
        await indexer.run(
            store: store,
            access: access,
            mediumUUID: mediumID,
            volume: VolumeInfo(
                mountPath: "/Volumes/T",
                name: "BIG",
                fsType: "apfs",
                volumeTotalBytes: 1_000_000,
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
            ),
            configuration: ScanConfiguration(
                maxDepth: maxDepth,
                ignoreHiddenFiles: true,
                excludedPatterns: [],
                limits: IndexingRunLimits(batchEntryLimit: batchEntryLimit)
            ),
            fromScratch: fromScratch,
            token: UUID(),
            shouldHalt: shouldHalt
        )
    }

    func item(named name: String) async throws -> StoredItem? {
        let big = try await store.folderID(mediumUUID: mediumID, path: ["big"])
        guard let big else { return nil }
        return try await store.children(mediumUUID: mediumID, parentID: big).first { $0.name == name }
    }

    func anyFileUnderBig() async throws -> StoredItem {
        let big = try #require(try await store.folderID(mediumUUID: mediumID, path: ["big"]))
        let file = try #require(try await store.children(mediumUUID: mediumID, parentID: big).first { !$0.isFolder })
        return file
    }

    func namesUnderBig() async throws -> Set<String> {
        let big = try #require(try await store.folderID(mediumUUID: mediumID, path: ["big"]))
        let children = try await store.children(mediumUUID: mediumID, parentID: big)
        return Set(children.map(\.name))
    }

    func fileIDsUnderBig() async throws -> [Int64] {
        let big = try #require(try await store.folderID(mediumUUID: mediumID, path: ["big"]))
        return try await store.children(mediumUUID: mediumID, parentID: big).map(\.id)
    }

    func liveVisibleEntryCount() async throws -> Int {
        var total = 0
        func walk(_ parent: Int64?) async throws {
            let children = try await store.children(mediumUUID: mediumID, parentID: parent)
            total += children.count
            for child in children where child.isFolder {
                try await walk(child.id)
            }
        }
        try await walk(nil)
        return total
    }
}
