//
//  StoreLaunchSequenceTests.swift
//  diskindexTests
//
//  bug.0.4.074: Versions-Sperre beim Start sofort auswerten. Gesperrter Zustand liegt in der Datenbank → Startablauf
//  wie in `AppDelegate.wireStore` (`StoreLaunchSequence.startServices`) → kein Lauf, kein Schreibvorgang im Index.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct StoreLaunchSequenceTests {
    private func fixedMonitor(_ volume: VolumeInfo) -> @MainActor () -> MediumMonitor {
        {
            MediumMonitor(
                mountedVolumes: { [volume] },
                wakeEvents: { AsyncStream { _ in } },
                notificationCenter: NotificationCenter()
            )
        }
    }

    @Test func lockedVersionInDatabaseBlocksRecognitionRunAtLaunch() async throws {
        let appVersion = try #require(AppVersion.currentApp())
        let harness = try await ScanHarness.make()
        let id = harness.mediumID
        let volume = testVolume(path: "/Volumes/LOCK074", name: "TEST")
        try await harness.store.recordIdentity(mediumUUID: id, volume.identity)
        // Gesperrter Zustand in der Datenbank: diese Version wurde schon gesperrt (wie nach Ablauf der Beta).
        try VersionLockEvaluator.applyMutations(
            VersionLockSettingsMutations(setLockedVersion: appVersion.displayString), pool: harness.store.pool
        )
        let inner = MemoryVolume(mountPath: "/Volumes/LOCK074")
        inner.file("a.txt")
        let app = AppState(store: harness.store)
        let rig = WiredRig(store: harness.store, access: inner, app: app)
        let scheduler = VersionCheckScheduler(
            wakeEvents: { AsyncStream { _ in } }, flush: {}, databaseWasNewThisLaunch: false
        )
        defer {
            scheduler.stop()
            rig.coordinator.stop()
        }

        StoreLaunchSequence.startServices(
            appState: app,
            store: harness.store,
            coordinator: rig.coordinator,
            versionCheck: scheduler,
            startChangeLoop: {},
            makeMonitor: fixedMonitor(volume)
        )
        // Synchron ausgewertet: Die Sperre steht schon, wenn `startServices` zurückkehrt (vor der Erkennung).
        #expect(app.versionLockState.isLocked)
        #expect(!app.featureAccess.canWriteIndex)

        // Die Erkennung lief (Medium verbunden), aber es startet kein Lauf und nichts wird indiziert.
        #expect(await waitUntil { app.medium(with: id)?.connectionStatus == .connected })
        try await Task.sleep(for: .milliseconds(300))
        #expect(rig.starts(id).isEmpty)
        #expect(!rig.service.isRunActive(id))
        #expect(inner.listed.isEmpty)
        #expect(try await harness.names().isEmpty)
        let stored = try #require(try await harness.store.medium(uuid: id))
        #expect(stored.firstIndexedAt == nil)
        #expect(stored.fileCount == 0)
        #expect(app.versionLockState.isLocked)
    }
}
