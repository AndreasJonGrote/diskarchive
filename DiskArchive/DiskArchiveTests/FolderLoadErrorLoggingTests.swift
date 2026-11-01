//
//  FolderLoadErrorLoggingTests.swift
//  DiskArchiveTests
//
//  Aufgabe 109 — stiller DB-Fehler → Protokoll + „Inhalt konnte nicht gelesen werden“.
//

import Foundation
import Testing
@testable import DiskArchive

@Suite @MainActor struct FolderLoadErrorLoggingTests {
    @Test func childrenReadFailureIsLoggedAndShown() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-load-err-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Err", decision: .index, indexStatus: .indexed)
        try await store.upsertMedium(medium)
        try await store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1, modifiedAt: Date())],
            seenAt: Date()
        )

        // bug.0.4.125: eigene Senke am Repository statt Haken am geteilten Protokoll.
        var tracked: [String] = []
        await store.setChildrenReadsFailing(true)
        let repository = IndexRepository(store: store)
        repository.recordLoadError = { tracked.append($0) }
        _ = await repository.loadChildren(mediumID: medium.uuid, path: [])

        #expect(repository.folderLoadError(mediumID: medium.uuid, path: []) == LayoutCopy.folderUnreadable)
        #expect(repository.children(mediumID: medium.uuid, path: []).isEmpty)
        #expect(tracked.contains(where: { $0.contains("children") }))
        #expect(!tracked.contains(where: { $0.contains("CancellationError") }))
    }
}
