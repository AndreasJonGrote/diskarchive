//
//  IndexCompletenessTests.swift
//  DiskArchiveTests
//
//  bug.0.4.126: „vollständig“ heißt mindestens ein Lauf bis zum Ende, nicht „eine Ebene fertig“.
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct IndexCompletenessTests {
    /// Erstlauf bis Ebene 1, Prozess endet (Status bleibt `indexing`), Pool neu öffnen → `.pending`.
    @Test func interruptedFirstRunReopensAsPending() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-complete-\(UUID().uuidString)", isDirectory: true)
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

    /// bug.0.4.151: Medium war vollständig (`firstIndexedAt` gesetzt), ein späterer Abgleich fand eine Lücke (seit
    /// bug.0.4.199 `.error`). Endet die App mitten im nächsten Lauf (`indexing`), setzt die Normalisierung beim Öffnen
    /// (`normalizeInterruptedIndexingStatuses`) wegen des Merkers `.pending` statt `.indexed` – das Anschließen liest dann
    /// die Lücke nach.
    @Test func laterGapIsNotIndexedAfterACrashMidRun() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-gap-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("archive.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try TestDatabase(fileURL: fileURL)
        let store = IndexStoreV3(database: database)
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "LUECKE", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        let first = UUID()
        #expect(try await store.beginIndexing(mediumUUID: medium.uuid, token: first))
        #expect(try await store.finishIndexing(mediumUUID: medium.uuid, token: first, status: .indexed, firstIndexedAt: Date(), ranToEnd: true))
        // Späterer Abgleich: Lücke → `.error` trotz `firstIndexedAt` (bug.0.4.199, vorher `.pending`).
        let second = UUID()
        #expect(try await store.beginIndexing(mediumUUID: medium.uuid, token: second))
        #expect(try await store.finishIndexing(mediumUUID: medium.uuid, token: second, status: .error, firstIndexedAt: nil, ranToEnd: true))
        // Nächster Lauf beginnt, Prozess endet.
        #expect(try await store.beginIndexing(mediumUUID: medium.uuid, token: UUID()))
        try database.close()

        let reopened = try TestDatabase(fileURL: fileURL)
        defer { try? reopened.close() }
        let reopenedStore = IndexStoreV3(database: reopened)
        let stored = try #require(try await reopenedStore.medium(uuid: medium.uuid))
        #expect(stored.firstIndexedAt != nil)
        #expect(stored.indexStatus == .pending, "Lücke durch Absturz verdeckt")
        // Ein Lauf ohne Lücke hebt den Merker wieder auf.
        let third = UUID()
        #expect(try await reopenedStore.beginIndexing(mediumUUID: medium.uuid, token: third))
        #expect(try await reopenedStore.finishIndexing(mediumUUID: medium.uuid, token: third, status: .indexed, firstIndexedAt: Date(), ranToEnd: true))
        #expect(try await reopenedStore.beginIndexing(mediumUUID: medium.uuid, token: UUID()))
        try reopened.close()
        let again = try TestDatabase(fileURL: fileURL)
        defer { try? again.close() }
        let final = try #require(try await IndexStoreV3(database: again).medium(uuid: medium.uuid))
        #expect(final.indexStatus == .indexed)
    }
}
