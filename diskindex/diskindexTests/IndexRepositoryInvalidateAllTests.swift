//
//  IndexRepositoryInvalidateAllTests.swift
//  diskindexTests
//
//  Aufgabe 239 — invalidateAll invalidiert laufende Spalten-Loads (REPORT 29).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct IndexRepositoryInvalidateAllTests {
    @Test func invalidateAllDuringLoadDoesNotRepopulateCache() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-invalidate-all-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let app = AppState(store: store)
        // Kein startChangeLoop: sonst invalidieren Index-Change-Events den Reload unter Parallel-Last.
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
        var invalidatedDuringLoad = false
        let invalidator = Task { @MainActor in
            let deadline = Date().addingTimeInterval(15)
            while Date() < deadline {
                // Kein globaler Load-Zähler (Paralleltests teilen ihn).
                if repo.isLoading(mediumID: mediumID, path: []) {
                    repo.blocksLoadsForRuleReconcile = true
                    repo.invalidateAll()
                    invalidatedDuringLoad = true
                    return
                }
                try? await Task.sleep(for: .milliseconds(1))
            }
        }
        repo.requestLoad(mediumID: mediumID, path: [])
        await invalidator.value
        let loadFinished = await waitUntil(timeout: 30) {
            !repo.isLoading(mediumID: mediumID, path: [])
        }
        #expect(loadFinished)
        #expect(invalidatedDuringLoad)
        #expect(!repo.hasCachedChildren(mediumID: mediumID, path: []))

        repo.blocksLoadsForRuleReconcile = false
        repo.requestLoad(mediumID: mediumID, path: [])
        let reloaded = await waitUntil(timeout: 60) {
            repo.hasCachedChildren(mediumID: mediumID, path: [])
        }
        #expect(reloaded)
        #expect(repo.children(mediumID: mediumID, path: []).count == fileCount)
    }

    @Test func invalidateAllDuringMissingFolderLoadDoesNotCacheEmpty() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-missing-folder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let app = AppState(store: store)
        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Tree", decision: .index, indexStatus: .indexed, completedDepth: 2)
        try await store.upsertMedium(medium)
        medium = try #require(try await store.medium(uuid: medium.uuid))
        try await store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "root.txt", isFolder: false, sizeBytes: 1, modifiedAt: Date())],
            seenAt: Date()
        )

        let repo = app.indexRepository
        let mediumID = medium.uuid
        let missingPath = ["OrdnerFehlt"]
        let gate = MissingFolderLoadGate()
        // bug.0.3.8.007: Tor am eigenen Repository (vorher prozessweit statisch).
        repo.awaitMissingFolderCacheGateForTesting = {
            await gate.pauseUntilProceed()
        }

        repo.requestLoad(mediumID: mediumID, path: missingPath)
        await gate.waitUntilLoadAtGate()
        #expect(repo.isLoading(mediumID: mediumID, path: missingPath))
        repo.invalidateAll()
        gate.proceed()

        let loadFinished = await waitUntil(timeout: 10) {
            !repo.isLoading(mediumID: mediumID, path: missingPath)
        }
        #expect(loadFinished)
        #expect(!repo.hasCachedChildren(mediumID: mediumID, path: missingPath))
    }
}

@MainActor
private final class MissingFolderLoadGate {
    private var loadAtGate: CheckedContinuation<Void, Never>?
    private var testWaitingForGate: CheckedContinuation<Void, Never>?
    private var proceedWaiter: CheckedContinuation<Void, Never>?

    func pauseUntilProceed() async {
        if let testWaitingForGate {
            self.testWaitingForGate = nil
            testWaitingForGate.resume()
        } else {
            await withCheckedContinuation { loadAtGate = $0 }
        }
        await withCheckedContinuation { proceedWaiter = $0 }
    }

    func waitUntilLoadAtGate() async {
        if loadAtGate != nil {
            loadAtGate?.resume()
            loadAtGate = nil
            return
        }
        await withCheckedContinuation { testWaitingForGate = $0 }
    }

    func proceed() {
        proceedWaiter?.resume()
        proceedWaiter = nil
    }
}
