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
        // Auf die Bedingung warten (Frist mit Reserve), nicht eine feste Zeit.
        let hydrated = await waitUntil(timeout: 10) { appState.didHydrateSettingsBeforeRecognition }
        #expect(hydrated)
        #expect(appState.didHydrateSettingsBeforeRecognition)
        #expect(appState.didStartCoordinatorBeforeLoad)
        coordinator.stop()
    }

    /// Nacharbeit 3 (todo.0.4.033): Scan-Tiefe 2 liegt nur in der DB → `bootstrap` mit festem Monitor →
    /// der erste Lauf liest nicht unter Tiefe 2 (kein Schritt der Kette von Hand).
    @Test func firstRunUsesScanDepthStoredBeforeBootstrap() async throws {
        let harness = try await ScanHarness.make()
        let id = harness.mediumID
        var persisted = PersistedAppSettings()
        persisted.scanDepth = 2
        try await harness.store.savePersistedAppSettings(persisted)
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("a/b/deep.txt")
        let volume = testVolume(path: "/Volumes/T", name: "TEST")
        try await harness.store.recordIdentity(mediumUUID: id, volume.identity)

        let app = AppState(store: harness.store)
        #expect(app.appSettings.scanDepth == AppSettings.defaultScanDepth)
        let rig = WiredRig(store: harness.store, access: inner, app: app)
        MediumRecognitionStartup.bootstrap(
            appState: app,
            store: harness.store,
            coordinator: rig.coordinator,
            startChangeLoop: {},
            makeMonitor: { MediumMonitor(mountedVolumes: { [volume] }, wakeEvents: { AsyncStream { _ in } }) }
        )
        defer { rig.coordinator.stop() }
        let done = await waitUntil { rig.starts(id).count == 1 && !rig.service.isRunActive(id) }
        #expect(done)
        #expect(app.appSettings.scanDepth == 2)
        #expect(inner.listed.contains("/Volumes/T/a"))
        #expect(!inner.listed.contains { $0.hasSuffix("/a/b") })
    }
}

private final class ScriptedAccess: MediumAccess, @unchecked Sendable {
    var result: MediumAccessResult = .granted
    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { result }
    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] { [] }
}
