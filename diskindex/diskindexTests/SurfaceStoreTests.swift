//
//  SurfaceStoreTests.swift
//  diskindexTests
//

import AppKit
import Foundation
import GRDB
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor struct SurfaceStoreTests {
    @Test func emptyStartRendersEmptyStates() throws {
        let app = AppState()
        #expect(app.media.isEmpty)
        let dashboard = ImageRenderer(content: EmptyStateView(
            title: EmptyStateCopy.noMediumTitle,
            message: EmptyStateCopy.noMediumMessage
        ).frame(width: 420, height: 220))
        dashboard.scale = 2
        let image = try #require(dashboard.nsImage)
        #expect(image.size.width > 100)
        let popover = ImageRenderer(content: Text(EmptyStateCopy.popoverNoneConnected)
            .font(.system(size: 13))
            .frame(width: 280, height: 40))
        #expect(popover.nsImage != nil)
    }

    @Test func storedMediaLoadOfflineBeforeRecognition() async throws {
        let rig = try await SurfaceRig.make()
        let first = StoredMedium(volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-0000000000A1", fsType: "apfs", volumeTotalBytes: 10, name: "Eins", decision: .index, indexStatus: .indexed)
        let second = StoredMedium(volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-0000000000A2", fsType: "apfs", volumeTotalBytes: 10, name: "Zwei", decision: .index, indexStatus: .indexed)
        try await rig.store.upsertMedium(first)
        try await rig.store.upsertMedium(second)
        rig.app.attach(store: rig.store)
        await rig.app.loadStoredMedia()
        #expect(rig.app.media.count == 2)
        #expect(rig.app.media.allSatisfy { $0.connectionStatus == .offline })
        await rig.coordinator.handle(.appeared(rig.volume(name: "Eins", uuid: first.volumeUUID)))
        #expect(rig.app.medium(with: first.uuid)?.connectionStatus == .connected)
        #expect(rig.app.medium(with: second.uuid)?.connectionStatus == .offline)
    }

    @Test func writeMediumDoesNotOverwriteFileCount() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Zähler", fsType: "apfs", bytes: 100)
        let app = AppState(store: harness.store)
        await app.loadStoredMedia()
        let hook: @Sendable (UUID, IndexStoreV3) async throws -> Void = { id, store in
            try await store.pool.write { db in
                guard let storageID = try MediumCodecV3.storageRowID(db, uuid: id) else { return }
                try IndexStoreV3.commitMediumMeta(
                    db: db,
                    storageID: storageID,
                    activityAt: Date(),
                    delta: MediumCountDelta(files: 100, folders: 0)
                )
            }
        }
        await AppState.$writeMediumBeforePersistHook.withValue(hook) {
            app.updateMedium(id: medium.uuid, persist: true) { $0.isFavorite = true }
            await app.flushMediumEdits()
        }
        let stored = try #require(try await harness.store.medium(uuid: medium.uuid))
        #expect(stored.fileCount == 100)
        #expect(stored.isFavorite)
    }

    @Test func prepareForTerminationPersistsSettingsImmediately() async throws {
        let harness = try StoreHarness.make()
        let suite = "diskindex-term-settings-\(UUID().uuidString)"
        let defaults = TestDefaults.make()
        let app = AppState(store: harness.store, defaults: defaults)
        app.attach(store: harness.store)
        await app.hydrateSettingsFromStore()
        app.appSettings.scanDepth = 4
        await app.prepareForTerminationAsync()
        let restored = AppState(store: harness.store, defaults: defaults)
        restored.attach(store: harness.store)
        await restored.hydrateSettingsFromStore()
        #expect(restored.appSettings.scanDepth == 4)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func prepareForTerminationFlushesPendingMediumWrite() async throws {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Flush", fsType: "apfs", bytes: 100)
        let app = AppState(store: harness.store)
        await app.hydrateSettingsFromStore()
        await app.loadStoredMedia()
        app.updateMedium(id: medium.uuid, persist: true) { $0.isFavorite = true }
        await app.prepareForTerminationAsync()
        let stored = try #require(try await harness.store.medium(uuid: medium.uuid))
        #expect(stored.isFavorite)
    }

    @Test func mediumEditsSurviveANewAppState() async throws {
        let rig = try await SurfaceRig.make()
        let stored = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Platte", decision: .index, indexStatus: .indexed)
        try await rig.store.upsertMedium(stored)
        rig.app.attach(store: rig.store)
        await rig.app.loadStoredMedia()
        rig.app.updateMedium(id: stored.uuid, persist: true) {
            $0.showAbsoluteCapacity = true
            $0.isFavorite = true
            $0.autoIndexPaused = true
        }
        await rig.app.flushMediumEdits()
        let reloaded = AppState(store: rig.store)
        await reloaded.loadStoredMedia()
        let medium = try #require(reloaded.medium(with: stored.uuid))
        #expect(medium.showAbsoluteCapacity)
        #expect(medium.isFavorite)
        #expect(medium.autoIndexPaused == true)
    }

    @Test func settingsSurviveRestartAndReset() async throws {
        let harness = try StoreHarness.make()
        let suite = "diskindex-settings-\(UUID().uuidString)"
        let defaults = TestDefaults.make()
        defaults.removePersistentDomain(forName: suite)
        let app = AppState(defaults: defaults)
        app.attach(store: harness.store)
        await app.hydrateSettingsFromStore()
        app.appSettings.scanDepth = 2
        app.appSettings.ignoreHiddenFiles = false
        app.appSettings.excludedPatterns = ["Cache"]
        await app.persistAppSettingsNow()
        let restored = AppState(defaults: defaults)
        restored.attach(store: harness.store)
        await restored.hydrateSettingsFromStore()
        #expect(restored.appSettings.scanDepth == 2)
        #expect(restored.appSettings.ignoreHiddenFiles == false)
        #expect(restored.appSettings.excludedPatterns == ["Cache"])
        restored.appSettings.resetGeneral()
        restored.appSettings.resetIgnoredObjects()
        await restored.persistAppSettingsNow()
        let cleared = AppState(defaults: defaults)
        cleared.attach(store: harness.store)
        await cleared.hydrateSettingsFromStore()
        #expect(cleared.appSettings.scanDepth == AppSettings.defaultScanDepth)
        #expect(cleared.appSettings.excludedPatterns == AppSettings.defaultExcludedPatterns)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func forgetAllContinuesWhenOneDeleteFails() async throws {
        let rig = try await SurfaceRig.make()
        let first = StoredMedium(volumeUUID: "A", fsType: "apfs", volumeTotalBytes: 10, name: "Eins", decision: .index, indexStatus: .indexed)
        let second = StoredMedium(volumeUUID: "B", fsType: "apfs", volumeTotalBytes: 10, name: "Zwei", decision: .index, indexStatus: .indexed)
        try await rig.store.upsertMedium(first)
        try await rig.store.upsertMedium(second)
        await rig.store.setDeleteMediumFailUUIDs([first.uuid])
        rig.app.attach(store: rig.store)
        await rig.app.loadStoredMedia()
        rig.app.forgetAllMedia()
        let settled = try await waitUntil {
            guard rig.app.registryMedia.isEmpty else { return false }
            return try await rig.store.medium(uuid: second.uuid) == nil
        }
        #expect(settled)
        #expect(try await rig.store.medium(uuid: first.uuid) != nil)
        #expect(try await rig.store.medium(uuid: second.uuid) == nil)
    }

    @Test func forgetAllClearsUIAndDatabase() async throws {
        let rig = try await SurfaceRig.make()
        let first = StoredMedium(volumeUUID: "A", fsType: "apfs", volumeTotalBytes: 10, name: "Eins", decision: .index, indexStatus: .indexed)
        let second = StoredMedium(volumeUUID: "B", fsType: "apfs", volumeTotalBytes: 10, name: "Zwei", decision: .undecided, indexStatus: .pending)
        try await rig.store.upsertMedium(first)
        try await rig.store.upsertMedium(second)
        rig.app.attach(store: rig.store)
        await rig.app.loadStoredMedia()
        rig.app.forgetAllMedia()
        let cleared = try await waitUntil {
            guard rig.app.registryMedia.isEmpty, rig.app.indexedMedia.isEmpty else { return false }
            return try await rig.store.media().isEmpty
        }
        #expect(cleared)
        #expect(rig.app.registryMedia.isEmpty)
        #expect(rig.app.indexedMedia.isEmpty)
        #expect(try await rig.store.media().isEmpty)
    }

    @Test func forgetDeletesMediumAndRows() async throws {
        let rig = try await SurfaceRig.make()
        let stored = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Weg", decision: .index, indexStatus: .indexed)
        try await rig.store.upsertMedium(stored)
        try await rig.store.applyDirectory(
            mediumUUID: stored.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1)],
            seenAt: Date()
        )
        rig.app.attach(store: rig.store)
        await rig.app.loadStoredMedia()
        rig.app.forgetMedium(id: stored.uuid)
        // bug.0.3.8.007: statt fester 50 ms warten, bis das Löschen in der Datenbank angekommen ist.
        let deleted = try await waitUntil {
            let medium = try await rig.store.medium(uuid: stored.uuid)
            let rows = try await rig.store.children(mediumUUID: stored.uuid, parentID: nil)
            return medium == nil && rows.isEmpty
        }
        #expect(deleted)
        #expect(rig.app.media.isEmpty)
        #expect(try await rig.store.medium(uuid: stored.uuid) == nil)
        #expect(try await rig.store.children(mediumUUID: stored.uuid, parentID: nil).isEmpty)
    }

    @Test func appSourcesDoNotReferenceMockData() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("diskindex")
        let files = try swiftFiles(in: root)
        var mockData: [String] = []
        var mockIndex: [String] = []
        for url in files {
            if url.path.contains("/Diagnostics/") { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            let lines = text.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() where !line.contains("#Preview") && !line.contains("PreviewData") {
                if line.contains("MockData") { mockData.append("\(url.lastPathComponent):\(index + 1)") }
                if line.contains("MockIndex") { mockIndex.append("\(url.lastPathComponent):\(index + 1)") }
            }
        }
        #expect(mockData.isEmpty)
        #expect(mockIndex.isEmpty)
    }
}
}
