//
//  MediumRecognitionStartupTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@MainActor
struct MediumRecognitionStartupTests {
    @Test func bootstrapStartsMonitorBeforeMediaLoad() async throws {
        MediumRecognitionStartup.resetStartupFlagsForTests()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-startup-\(UUID().uuidString)", isDirectory: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let access = ScriptedAccess()
        let appState = AppState()
        let coordinator = MediumCoordinator(store: store, access: access, appState: appState)

        MediumRecognitionStartup.bootstrap(
            appState: appState,
            store: store,
            coordinator: coordinator,
            startChangeLoop: { appState.startChangeLoop() }
        )
        for _ in 0..<50 where !MediumRecognitionStartup.didHydrateSettingsBeforeRecognition {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(MediumRecognitionStartup.didHydrateSettingsBeforeRecognition)
        #expect(MediumRecognitionStartup.didStartCoordinatorBeforeLoad)
        coordinator.stop()
    }

    @Test func firstIndexUsesScanDepthFromDatabase() async throws {
        let harness = try StoreHarness.make()
        var persisted = PersistedAppSettings()
        persisted.scanDepth = 2
        try await harness.store.savePersistedAppSettings(persisted)
        let app = AppState(store: harness.store)
        await app.hydrateSettingsFromStore()
        #expect(app.appSettings.scanDepth == 2)

        let scan = try await ScanHarness.make()
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("a/b/deep.txt")
        let outcome = try await scan.run(
            access: inner,
            maxDepth: app.appSettings.scanDepth,
            fromScratch: true
        )
        #expect(outcome.status == .indexed)
        #expect(!inner.listed.contains { $0.hasSuffix("/a/b") })
    }
}

private final class ScriptedAccess: MediumAccess, @unchecked Sendable {
    var result: MediumAccessResult = .granted
    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { result }
    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] { [] }
}
