//
//  IndexCompletenessTests.swift
//  diskindexTests
//
//  bug.0.4.126: „vollständig“ heißt mindestens ein Lauf bis zum Ende, nicht „eine Ebene fertig“.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct IndexCompletenessTests {
    /// Erstlauf bis Ebene 1, Prozess endet (Status bleibt `indexing`), Pool neu öffnen → `.pending`.
    @Test func interruptedFirstRunReopensAsPending() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-complete-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("archive.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try TestDatabase(fileURL: fileURL)
        let store = IndexStoreV3(database: database)
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "HALB", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        #expect(try await store.beginIndexing(mediumUUID: medium.uuid, token: UUID()))
        try await store.completeLayer(mediumUUID: medium.uuid, depth: 1)
        try database.close()

        let reopened = try TestDatabase(fileURL: fileURL)
        defer { try? reopened.close() }
        let stored = try #require(try await IndexStoreV3(database: reopened).medium(uuid: medium.uuid))
        #expect(stored.indexStatus == .pending)
    }
}
