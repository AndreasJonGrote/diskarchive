//
//  IndexRepositoryStaleTests.swift
//  diskindexTests
//
//  Aufgabe 176 c — veralteter Spalten-Cache bis zum Nachladen.
//

import Foundation
import Testing
@testable import diskindex

@Suite @MainActor
struct IndexRepositoryStaleTests {
    @Test func invalidateKeepsStaleChildrenUntilReload() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-stale-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let app = AppState(store: store)
        app.startChangeLoop()
        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Baum", decision: .index, indexStatus: .indexed, completedDepth: 3)
        try await store.upsertMedium(medium)
        medium = try #require(try await store.medium(uuid: medium.uuid))
        try await store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [
                ScannedEntry(name: "Alpha", isFolder: true),
                ScannedEntry(name: "Beta", isFolder: true),
                ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 4),
            ],
            seenAt: Date()
        )
        let repo = app.indexRepository
        let loaded = await repo.loadChildren(mediumID: medium.uuid, path: [])
        #expect(loaded.count == 3)
        #expect(loaded.map(\.name).contains("readme.txt"))

        try await store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [
                ScannedEntry(name: "Alpha", isFolder: true),
                ScannedEntry(name: "Beta", isFolder: true),
                ScannedEntry(name: "umbenannt.txt", isFolder: false, sizeBytes: 4),
            ],
            seenAt: Date()
        )
        repo.invalidate(mediumID: medium.uuid, path: [])
        let staleChildren = repo.children(mediumID: medium.uuid, path: [])
        #expect(staleChildren.count == 3)
        #expect(staleChildren.map(\.name).contains("readme.txt"))
        #expect(!repo.isLoading(mediumID: medium.uuid, path: []))

        repo.requestLoad(mediumID: medium.uuid, path: [])
        let refreshed = await waitUntil {
            repo.children(mediumID: medium.uuid, path: []).map(\.name).contains("umbenannt.txt")
        }
        #expect(refreshed)
        #expect(!repo.children(mediumID: medium.uuid, path: []).map(\.name).contains("readme.txt"))
    }
}
