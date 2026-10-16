//
//  ScopeChangeAcceptanceTests.swift
//  diskindexTests
//
//  bug.0.4.030 — Nacharbeit 2 Akzeptanztests.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct ScopeChangeAcceptanceTests {
    @Test func excludeTmpHidesAfterRuleReconcile() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "SCOPE", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [
                ScannedEntry(name: "keep.txt", isFolder: false, sizeBytes: 1),
                ScannedEntry(name: "drop.tmp", isFolder: false, sizeBytes: 1),
            ],
            seenAt: Date()
        )
        try await harness.store.completeLayer(mediumUUID: medium.uuid, depth: 1)
        let app = AppState(store: harness.store)
        await app.loadStoredMedia()
        app.appSettings.excludedPatterns = ["*.tmp"]
        await app.waitForRuleReconcileIdle()
        let visible = try await harness.store.children(
            mediumUUID: medium.uuid,
            parentID: nil,
            scope: IndexScope.from(app.appSettings)
        )
        #expect(!visible.contains { $0.name == "drop.tmp" })
        let counts = try await harness.store.counts(mediumUUID: medium.uuid, scope: IndexScope.from(app.appSettings))
        #expect(counts.files == 1)
    }

    @Test func excludeNodeModulesClearsSearchAndFileCount() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "NM", fsType: "apfs", bytes: 1_000)
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "node_modules", isFolder: true)],
            seenAt: Date()
        )
        let nmID = try #require(try await harness.store.folderID(mediumUUID: medium.uuid, path: ["node_modules"]))
        try await harness.store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nmID,
            entries: [
                ScannedEntry(name: "a.js", isFolder: false, sizeBytes: 1),
                ScannedEntry(name: "b.js", isFolder: false, sizeBytes: 1),
                ScannedEntry(name: "c.js", isFolder: false, sizeBytes: 1),
            ],
            seenAt: Date()
        )
        try await harness.store.completeLayer(mediumUUID: medium.uuid, depth: 2)
        let app = AppState(store: harness.store)
        await app.loadStoredMedia()
        app.appSettings.excludedPatterns = ["node_modules"]
        await app.waitForRuleReconcileIdle()
        await app.pruneNow()
        let hits = try await harness.store.search(query: "a.js", filters: SearchFilters(), scope: IndexScope.from(app.appSettings))
        #expect(hits.isEmpty)
        let stored = try #require(try await harness.store.medium(uuid: medium.uuid))
        let visibleFiles = try await harness.store.counts(mediumUUID: medium.uuid, scope: IndexScope.from(app.appSettings))
        #expect(visibleFiles.files == stored.fileCount)
    }

}

private func scopeMedium(from stored: StoredMedium) -> Medium {
    Medium(
        id: stored.uuid,
        name: stored.name,
        type: .usb,
        connectionStatus: .connected,
        indexStatus: .indexed,
        allowIndexing: true,
        autoIndexPaused: false,
        decision: stored.decision,
        capacityTotalBytes: stored.volumeTotalBytes,
        capacityUsedBytes: 0,
        fileCount: stored.fileCount,
        folderCount: stored.folderCount,
        scanTotal: stored.scanTotal,
        lastSeenAt: Date(),
        firstIndexedAt: stored.firstIndexedAt,
        lastIndexedAt: stored.lastIndexedAt,
        completedDepth: stored.completedDepth,
        isForgotten: false,
        indexingProgress: 1
    )
}
