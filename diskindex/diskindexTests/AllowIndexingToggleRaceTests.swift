//
//  AllowIndexingToggleRaceTests.swift
//  diskindexTests
//
//  bug.0.4.043 — „Ja“ nach „Nein“ springt auf „Nein“ zurück.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized)
@MainActor
struct AllowIndexingToggleRaceTests {
    /// Sabotage: In `reloadMedium` Nutzerfelder trotz `pendingMediumWrites` überschreiben → rot.
    @Test func yesAfterNoKeepsAllowIndexingWhenReloadBeatsWrite() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-043-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer {
            try? database.close()
            try? FileManager.default.removeItem(at: directory)
        }

        var stored = StoredMedium(
            fsType: "msdos",
            volumeTotalBytes: 1_000,
            name: "zoom_h4e",
            decision: .dontIndex,
            indexStatus: .pending,
            allowIndexing: false
        )
        try await store.upsertMedium(stored)
        stored = try #require(try await store.medium(uuid: stored.uuid))

        let app = AppState(store: store)
        app.startChangeLoop()
        await app.loadStoredMedia()
        let id = stored.uuid
        #expect(app.medium(with: id)?.allowIndexing == false)
        #expect(app.medium(with: id)?.decision == .dontIndex)

        app.updateMedium(id: id, persist: true) {
            $0.decision = .index
            $0.allowIndexing = true
        }
        #expect(app.medium(with: id)?.allowIndexing == true)
        #expect(!app.pendingMediumWrites.isEmpty)

        // Wie ein Index-/Change-Event vor dem verzögerten writeMedium.
        await app.reloadMedium(id)

        let stayed = await waitUntil(timeout: 2) {
            app.medium(with: id)?.allowIndexing == true
                && app.medium(with: id)?.decision == .index
        }
        #expect(stayed, "bug.0.4.043: nach reload vor writeMedium ist allowIndexing wieder false (decision=\(String(describing: app.medium(with: id)?.decision)), allow=\(String(describing: app.medium(with: id)?.allowIndexing)))")

        await app.flushMediumEdits()
        let db = try #require(try await store.medium(uuid: id))
        #expect(db.decision == .index)
        #expect(db.allowIndexing == true)
    }
}
