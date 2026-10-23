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

    /// bug.0.3.9.007 c: Nach `invalidateAll` schreibt der alte Load keinen Fortschritt mehr (vorher bis zum nächsten
    /// Yield wieder gefüllt: kurz veraltete Anzeige).
    @Test func invalidateAllClearsProgressForGood() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-invalidate-progress-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let app = AppState(store: store)
        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Bulk", decision: .index, indexStatus: .indexed, completedDepth: 1)
        try await store.upsertMedium(medium)
        medium = try #require(try await store.medium(uuid: medium.uuid))
        let fileCount = IndexRepository.loadBatchSize + 10
        let entries = (0..<fileCount).map { ScannedEntry(name: "file-\($0).txt", isFolder: false, sizeBytes: 1, modifiedAt: Date()) }
        try await store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: entries, seenAt: Date())

        let repo = app.indexRepository
        let mediumID = medium.uuid
        let gate = MissingFolderLoadGate()
        var counted = false
        var seen: [Int] = []
        var pages = 0
        // Am Tor nach der Zählung anhalten; nach jeder Seite (direkt nach dem Schreiben) den Fortschritt ablesen.
        repo.loadProgressStepForTesting = { step in
            switch step {
            case .counted:
                guard !counted else { return }
                counted = true
                await gate.pauseUntilProceed()
            case .page:
                pages += 1
                let progress = repo.loadingProgress(mediumID: mediumID, path: [])
                seen.append(progress.total)
                seen.append(progress.loaded)
            }
        }
        // Kein neuer Load nach dem Invalidieren: geprüft wird nur, was der alte Load schreibt.
        repo.requestLoad(mediumID: mediumID, path: [])
        await gate.waitUntilLoadAtGate()
        repo.invalidateAll()
        #expect(repo.loadingProgress(mediumID: mediumID, path: []) == (0, 0))
        gate.proceed()
        let loadFinished = await waitUntil(timeout: 10) { !repo.isLoading(mediumID: mediumID, path: []) }
        #expect(loadFinished)
        // Der alte Load läuft bis zur ersten Seite (danach Abbruch per Generation): mindestens ein Messpunkt.
        #expect(pages >= 1)
        #expect(seen.allSatisfy { $0 == 0 }, "Fortschritt nach invalidateAll: \(Set(seen).sorted())")
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
