//
//  PruneScopeTests.swift
//  diskindexTests
//
//  Aufgabe 216 / 234 — Namensregeln über DB-Status, nicht Swift-Filter.
//

import Foundation
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct PruneScopeTests {
    private func appWithHiddenFile() async throws -> (AppState, IndexStoreV3, StoredMedium) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-prunescope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "PRUNE", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        var entries = (0..<20).map { ScannedEntry(name: "bericht-\($0).pdf", isFolder: false, sizeBytes: 1) }
        entries.append(ScannedEntry(name: ".bericht-versteckt.pdf", isFolder: false, sizeBytes: 1))
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: false)],
            seenAt: Date()
        )
        try await store.completeLayer(mediumUUID: medium.uuid, depth: 1)
        let app = AppState(store: store)
        await app.loadStoredMedia()
        app.mainWindowDestination = .search
        app.searchState.submittedQuery = "bericht"
        app.appSettings.ignoreHiddenFiles = false
        await app.waitForRuleReconcileIdle()
        return (app, store, medium)
    }

    @Test func withoutPendingPruneNoNameIsCheckedInSwift() async throws {
        let (app, store, medium) = try await appWithHiddenFile()
        app.appSettings.ignoreHiddenFiles = false
        try #require(app.pruneAt == nil, "Ausgangslage: keine ausstehende Bereinigung")
        #expect(!app.indexScope.checksNames)

        let before = store.nameChecks.value
        await app.runSearch()
        await app.waitForSearchCount()
        _ = try await store.children(mediumUUID: medium.uuid, parentID: nil, scope: app.indexScope)
        _ = try await store.counts(mediumUUID: medium.uuid, scope: app.indexScope)
        #expect(store.nameChecks.value == before, "Namen wurden in Swift geprüft")
        #expect(app.searchMatch.items.count == 21)
        #expect(app.searchMatch.itemCount == 21)
    }

    @Test func ruleChangeMarksStatusAndPrunePurgesWithoutSwiftChecks() async throws {
        let (app, store, medium) = try await appWithHiddenFile()
        await app.runSearch()
        await app.waitForSearchCount()
        #expect(app.searchMatch.itemCount == 21)

        app.appSettings.ignoreHiddenFiles = true
        try #require(app.pruneAt != nil, "Regeländerung muss eine Bereinigung vormerken")
        await app.waitForRuleReconcileIdle()
        #expect(!app.indexScope.checksNames)
        let beforePending = store.nameChecks.value
        await app.runSearch()
        await app.waitForSearchCount()
        #expect(app.searchMatch.items.count == 20)
        #expect(app.searchMatch.itemCount == 20)
        #expect(!app.searchMatch.items.contains { $0.name.hasPrefix(".") })
        #expect(store.nameChecks.value == beforePending)

        await app.pruneNow()
        try #require(app.pruneAt == nil)
        let beforePure = store.nameChecks.value
        await app.runSearch()
        await app.waitForSearchCount()
        _ = try await store.counts(mediumUUID: medium.uuid, scope: app.indexScope)
        #expect(store.nameChecks.value == beforePure)
        #expect(app.searchMatch.items.count == 20)
        #expect(app.searchMatch.itemCount == 20)
        _ = medium
    }
}
}
