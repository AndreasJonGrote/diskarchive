//
//  FolderLoadErrorLoggingTests.swift
//  diskindexTests
//
//  Aufgabe 109 — stiller DB-Fehler → Protokoll + „Inhalt konnte nicht gelesen werden“.
//

import Foundation
import Testing
@testable import diskindex

@Suite @MainActor struct FolderLoadErrorLoggingTests {
    @Test func childrenReadFailureIsLoggedAndShown() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-load-err-\(UUID().uuidString)", isDirectory: true)
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

        let previous = DiskIndexLog.shared.onTrackedError
        defer { DiskIndexLog.shared.onTrackedError = previous }
        var tracked: [String] = []
        DiskIndexLog.shared.onTrackedError = { _, message in
            tracked.append(message)
        }

        await store.setChildrenReadsFailing(true)
        let repository = IndexRepository(store: store)
        _ = await repository.loadChildren(mediumID: medium.uuid, path: [])

        #expect(repository.folderLoadError(mediumID: medium.uuid, path: []) == LayoutCopy.folderUnreadable)
        #expect(repository.children(mediumID: medium.uuid, path: []).isEmpty)
        #expect(tracked.contains(where: { $0.contains("children") }))
        #expect(!tracked.contains(where: { $0.contains("CancellationError") }))
    }
}
