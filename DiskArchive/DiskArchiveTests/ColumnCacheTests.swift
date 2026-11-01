//
//  ColumnCacheTests.swift
//  DiskArchiveTests
//
//  Aufgabe 102 — gezielte Spalten-Cache-Invalidierung.
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
private func columnCacheTree() async throws -> (app: AppState, store: IndexStoreV3, medium: StoredMedium) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("diskarchive-cache-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
    let store = IndexStoreV3(database: database)
    let app = AppState()
    app.attach(store: store)
    // Kein startChangeLoop: Index-Change-Events invalidieren den Cache unter Parallel-Last (bug.0.4.044).
    var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Baum", decision: .index, indexStatus: .indexed, completedDepth: 3)
    try await store.upsertMedium(medium)
    medium = try #require(try await store.medium(uuid: medium.uuid))
    try await store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: nil,
        entries: [
            ScannedEntry(name: "Beta", isFolder: true),
            ScannedEntry(name: "Alpha", isFolder: true),
            ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 4, modifiedAt: Date()),
        ],
        seenAt: Date()
    )
    let root = try await store.children(mediumUUID: medium.uuid, parentID: nil)
    let alpha = try #require(root.first { $0.name == "Alpha" })
    try await store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: alpha.id,
        entries: [
            ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1, modifiedAt: Date()),
            ScannedEntry(name: "Inner", isFolder: true),
        ],
        seenAt: Date()
    )
    await app.loadStoredMedia()
    return (app, store, medium)
}

@Suite(.serialized) @MainActor struct ColumnCacheTests {
    @Test func appearanceChangeDoesNotInvalidateColumnCache() async throws {
        let tree = try await columnCacheTree()
        _ = await tree.app.indexRepository.loadChildren(mediumID: tree.medium.uuid, path: [])
        let generation = tree.app.indexRepository.generation
        tree.app.appSettings.appearance = tree.app.appSettings.appearance == .dark ? AppAppearance.light : .dark
        #expect(tree.app.indexRepository.generation == generation)
    }

    @Test func countsChangeDoesNotInvalidateOpenFolderCache() async throws {
        let tree = try await columnCacheTree()
        _ = await tree.app.indexRepository.loadChildren(mediumID: tree.medium.uuid, path: [])
        #expect(tree.app.indexRepository.hasCachedChildren(mediumID: tree.medium.uuid, path: []))
        try await tree.store.flushMediumMeta(mediumUUID: tree.medium.uuid, force: true)
        for _ in 0..<30 {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(tree.app.indexRepository.hasCachedChildren(mediumID: tree.medium.uuid, path: []))
    }

    @Test func targetedInvalidateKeepsStaleFolderCache() async throws {
        let tree = try await columnCacheTree()
        _ = await tree.app.indexRepository.loadChildren(mediumID: tree.medium.uuid, path: ["Alpha"])
        _ = await tree.app.indexRepository.loadChildren(mediumID: tree.medium.uuid, path: [])
        #expect(tree.app.indexRepository.hasCachedChildren(mediumID: tree.medium.uuid, path: ["Alpha"]))
        #expect(tree.app.indexRepository.hasCachedChildren(mediumID: tree.medium.uuid, path: []))
        tree.app.indexRepository.invalidate(mediumID: tree.medium.uuid, path: ["Alpha"])
        #expect(tree.app.indexRepository.hasCachedChildren(mediumID: tree.medium.uuid, path: ["Alpha"]))
        #expect(tree.app.indexRepository.hasCachedChildren(mediumID: tree.medium.uuid, path: []))
        #expect(!tree.app.indexRepository.stale.isEmpty)
    }
}
