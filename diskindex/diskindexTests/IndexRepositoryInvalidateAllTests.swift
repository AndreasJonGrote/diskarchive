//
//  IndexRepositoryInvalidateAllTests.swift
//  diskindexTests
//
//  Aufgabe 239 — invalidateAll invalidiert laufende Spalten-Loads (REPORT 29).
//

import Foundation
import Testing
@testable import diskindex

@Suite @MainActor
struct IndexRepositoryInvalidateAllTests {
    @Test func invalidateAllDuringLoadDoesNotRepopulateCache() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-invalidate-all-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let app = AppState(store: store)
        app.startChangeLoop()
        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Bulk", decision: .index, indexStatus: .indexed, completedDepth: 3)
        try await store.upsertMedium(medium)
        medium = try #require(try await store.medium(uuid: medium.uuid))
        let fileCount = IndexRepository.loadBatchSize * 2 + 500
        let entries = (0..<fileCount).map { index in
            ScannedEntry(name: "file-\(index).txt", isFolder: false, sizeBytes: 1, modifiedAt: Date())
        }
        try await store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: entries, seenAt: Date())

        let repo = app.indexRepository
        let mediumID = medium.uuid
        IndexRepository.resetLoadSessionsCounterForTesting()
        var invalidatedDuringLoad = false
        let invalidator = Task { @MainActor in
            let deadline = Date().addingTimeInterval(15)
            while Date() < deadline {
                let started = IndexRepository.loadSessionsStartedForTesting >= 1
                let loading = repo.isLoading(mediumID: mediumID, path: [])
                if started, loading {
                    repo.blocksLoadsForRuleReconcile = true
                    repo.invalidateAll()
                    invalidatedDuringLoad = true
                    return
                }
                if started, !loading {
                    return
                }
                try? await Task.sleep(for: .milliseconds(1))
            }
        }
        repo.requestLoad(mediumID: mediumID, path: [])
        await invalidator.value
        let loadFinished = await waitUntil(timeout: 30) {
            IndexRepository.loadSessionsCompletedForTesting >= 1
        }
        #expect(loadFinished)
        #expect(invalidatedDuringLoad)
        #expect(!repo.hasCachedChildren(mediumID: mediumID, path: []))

        repo.blocksLoadsForRuleReconcile = false
        repo.requestLoad(mediumID: mediumID, path: [])
        let reloaded = await waitUntil(timeout: 30) {
            repo.hasCachedChildren(mediumID: mediumID, path: [])
        }
        #expect(reloaded)
        #expect(repo.children(mediumID: mediumID, path: []).count == fileCount)
    }
}
