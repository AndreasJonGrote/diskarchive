//
//  LiveSyncMetaTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

struct LiveSyncMetaTests {
    @Test func applyDirectoryUpdatesCountsAndActivity() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let seenAt = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "a.txt", isFolder: false),
            ScannedEntry(name: "Docs", isFolder: true),
        ], seenAt: seenAt)
        let stored = try #require(try await harness.store.medium(uuid: medium.uuid))
        #expect(stored.fileCount == 1)
        #expect(stored.folderCount == 1)
        #expect(stored.lastIndexActivityAt == seenAt)
        #expect(stored.lastIndexedAt == nil)
    }

    @Test func completeLayerSetsLastIndexedAndActivity() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        _ = try await harness.addRoot(medium: medium, entries: [
            ScannedEntry(name: "a.txt", isFolder: false),
        ])
        try await harness.store.completeLayer(mediumUUID: medium.uuid, depth: 1)
        let stored = try #require(try await harness.store.medium(uuid: medium.uuid))
        #expect(stored.lastIndexedAt != nil)
        #expect(stored.lastIndexActivityAt == stored.lastIndexedAt)
    }

    /// Aufgabe 171.4 (Layout 01): online und fertig = kein Badge, auch beim Abgleich.
    @Test @MainActor func menuBarBadgeStaysEmptyDuringSync() {
        let app = AppState()
        var online = PreviewData.media[0]
        online.connectionStatus = .connected
        online.indexStatus = .indexed
        app.media = [online]
        #expect(app.effectiveMenuBarBadge == .idle)
        app.beginMediumLiveSync(online.id)
        #expect(app.effectiveMenuBarBadge == .idle)
        app.endMediumLiveSync(online.id)
        #expect(app.effectiveMenuBarBadge == .idle)
    }
}
