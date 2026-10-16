//
//  StoreStartupLifecycleTests.swift
//  diskindexTests
//
//  c.0.3.2.003 — Change-Loop, Detach, Retry-Lade-UI, Integrität nach Wire.
//

import Foundation
import Testing
@testable import diskindex

@MainActor
struct StoreStartupLifecycleTests {
    @Test func changeLoopRestartsOnSecondStore() async throws {
        let app = AppState()
        let (storeA, dbA, dirA) = try makeTemporaryStore()
        defer { try? dbA.close(); try? FileManager.default.removeItem(at: dirA) }
        let (storeB, dbB, dirB) = try makeTemporaryStore()
        defer { try? dbB.close(); try? FileManager.default.removeItem(at: dirB) }

        var mediumA = StoredMedium(fsType: "apfs", volumeTotalBytes: 1, name: "A", decision: .index, indexStatus: .indexed)
        try await storeA.upsertMedium(mediumA)
        mediumA = try #require(try await storeA.medium(uuid: mediumA.uuid))

        app.attach(store: storeA)
        app.startChangeLoop()
        await storeA.emit(.counts(mediumA.uuid))
        let sawA = await waitUntil { app.lastChangeGeneration >= 1 }
        #expect(sawA)

        var mediumB = StoredMedium(fsType: "apfs", volumeTotalBytes: 1, name: "B", decision: .index, indexStatus: .indexed)
        try await storeB.upsertMedium(mediumB)
        mediumB = try #require(try await storeB.medium(uuid: mediumB.uuid))

        let generationBeforeB = app.lastChangeGeneration
        app.attach(store: storeB)
        app.startChangeLoop()
        await storeB.emit(.counts(mediumB.uuid))
        await storeB.emit(.counts(mediumB.uuid))
        let sawB = await waitUntil { app.lastChangeGeneration > generationBeforeB }
        #expect(sawB)
    }

    @Test func detachFromIndexStoreClearsLoopAndStore() async throws {
        let app = AppState()
        let (store, database, directory) = try makeTemporaryStore()
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        app.attach(store: store)
        app.startChangeLoop()
        #expect(app.indexStore != nil)
        #expect(app.storeReady)

        app.detachFromIndexStore()
        #expect(app.indexStore == nil)
        #expect(!app.storeReady)
        #expect(app.changeLoop == nil)
    }

    @Test func retryEnablesStoreLoading() {
        let app = AppState()
        app.storeOpening = true
        app.reportIndexStoreOpenFailure()
        #expect(!app.isStoreLoading)

        app.clearIndexStoreOpenFailure()
        #expect(app.isStoreLoading)
    }

    @Test func integrityFailureAfterWireDetachesStore() async throws {
        let app = AppState()
        let (store, database, directory) = try makeTemporaryStore()
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }
        let defaults = try #require(UserDefaults(suiteName: "app.diskarchive.tests.store-lifecycle.\(UUID().uuidString)"))
        var didWire = false

        await StartupSequence.run(
            previousRunUnclean: true,
            defaults: defaults,
            open: { store },
            wire: { opened in
                app.attach(store: opened)
                app.startChangeLoop()
                didWire = true
            },
            integrityCheck: { _ in throw DatabaseCareError.unhealthy },
            onFailure: { _ in
                app.prepareForTermination()
                app.detachFromIndexStore()
            }
        ).value

        #expect(didWire)
        #expect(app.indexStore == nil)
        #expect(app.changeLoop == nil)
        #expect(!app.storeReady)
    }
}

@MainActor
private func makeTemporaryStore() throws -> (IndexStoreV3, TestDatabase, URL) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("diskindex-store-lifecycle-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
    let store = IndexStoreV3(database: database)
    return (store, database, directory)
}
