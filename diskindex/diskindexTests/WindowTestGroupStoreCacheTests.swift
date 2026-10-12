//
//  WindowTestGroupStoreCacheTests.swift
//  diskindexTests
//
//  Aufgabe 192 f — parallel-sensitive Store/Cache-Tests seriell.
//

import Foundation
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct WindowTestGroupStoreCacheTests {
    @Test func largeOpenFolderSurvivesMetaTicksDuringLiveSync() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("diskindex-cache-big-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }
        let app = AppState()
        app.attach(store: store)
        app.startChangeLoop()
        var medium = StoredMedium(
            fsType: "apfs",
            volumeTotalBytes: 10,
            name: "Groß",
            decision: .index,
            indexStatus: .indexing,
            completedDepth: 3
        )
        try await store.upsertMedium(medium)
        medium = try #require(try await store.medium(uuid: medium.uuid))
        try await store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "Big", isFolder: true)],
            seenAt: Date()
        )
        let bigFolder = try #require(try await store.folderID(mediumUUID: medium.uuid, path: ["Big"]))
        let fileCount = 14_300
        let files = (0..<fileCount).map { index in
            ScannedEntry(name: "file-\(index).txt", isFolder: false, sizeBytes: 1, modifiedAt: Date())
        }
        try await store.applyDirectory(mediumUUID: medium.uuid, parentID: bigFolder, entries: files, seenAt: Date())
        await app.loadStoredMedia()
        if let index = app.media.firstIndex(where: { $0.id == medium.uuid }) {
            app.media[index].indexStatus = .indexing
        }
        app.beginMediumLiveSync(medium.uuid)
        let seeded = await app.indexRepository.loadChildren(mediumID: medium.uuid, path: ["Big"])
        #expect(!seeded.isEmpty)
        app.cancelPendingColumnCacheInvalidatesForTesting()
        IndexRepository.resetLoadSessionsCounterForTesting()
        #expect(app.indexRepository.hasCachedChildren(mediumID: medium.uuid, path: ["Big"]))
        let loadsBefore = IndexRepository.loadSessionsStartedForTesting
        for _ in 0..<40 {
            try await store.flushMediumMeta(mediumUUID: medium.uuid, force: true)
            try await Task.sleep(for: .milliseconds(20))
        }
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if app.indexRepository.hasCachedChildren(mediumID: medium.uuid, path: ["Big"])
                && IndexRepository.loadSessionsStartedForTesting == loadsBefore {
                break
            }
            try await Task.sleep(for: .milliseconds(40))
        }
        let hasCacheAfter = app.indexRepository.hasCachedChildren(mediumID: medium.uuid, path: ["Big"])
        let loadsAfter = IndexRepository.loadSessionsStartedForTesting
        #expect(hasCacheAfter)
        #expect(loadsAfter == loadsBefore)
    }

    @Test func layerWholeMediumInvalidateSurvivesCountsMetaTick() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("diskindex-layer-counts-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }
        let app = AppState()
        app.attach(store: store)
        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Layer", decision: .index, indexStatus: .indexed)
        try await store.upsertMedium(medium)
        medium = try #require(try await store.medium(uuid: medium.uuid))
        try await store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "Ordner", isFolder: true)],
            seenAt: Date()
        )
        await app.loadStoredMedia()
        app.indexRepository.seedScreenshotCache(
            mediumID: medium.uuid,
            entries: [([], [
                IndexedItem(
                    id: IndexedItem.stableID(mediumID: medium.uuid, rowID: 1),
                    rowID: 1,
                    name: "Ordner",
                    kind: .folder,
                    parentPath: [],
                    modifiedAt: Date(),
                    sizeBytes: 0,
                    listedAt: Date()
                ),
            ])]
        )
        let staleBefore = app.indexRepository.stale.count
        await app.scheduleIndexChange(.counts(medium.uuid), dropped: false)
        await app.scheduleIndexChange(.layer(medium: medium.uuid, depth: 1), dropped: false)
        await app.scheduleIndexChange(.counts(medium.uuid), dropped: false)
        let staleAfterLayer = await waitUntil(timeout: 2.5) {
            app.indexRepository.stale.count > staleBefore
        }
        #expect(staleAfterLayer)
    }
}
}
