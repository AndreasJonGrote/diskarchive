//
//  VersionLockReadOnlyTests.swift
//  diskindexTests
//
//  Read-only-Sperre schließen (c.0.3.3.002).
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite(.serialized)
struct VersionLockReadOnlyTests {
    @Test @MainActor func updateNoticeClearedWhenOfferMissing() {
        let appState = AppState()
        let offer = UpdateOffer(
            currentDisplay: "0.3",
            targetDisplay: "1.0",
            targetMajorMinor: AppVersion(major: 1, minor: 0, patch: 0),
            showSkipCheckbox: true,
            showBetaCountdown: false
        )
        appState.applyVersionLockEvaluation(
            VersionLockEvaluation(
                lockState: .unlocked,
                updateOffer: offer,
                showLockBanner: false,
                mutations: VersionLockSettingsMutations()
            )
        )
        #expect(appState.updateNotice != nil)
        appState.applyVersionLockEvaluation(
            VersionLockEvaluation(
                lockState: .unlocked,
                updateOffer: nil,
                showLockBanner: false,
                mutations: VersionLockSettingsMutations()
            )
        )
        #expect(appState.updateNotice == nil)
    }

    @Test @MainActor func versionLockCancelPreservesDeferredReconcileIntent() {
        let appState = AppState()
        appState.isRuleReconcileQueueActive = true
        appState.ruleReconcileNeedsRerun = true
        appState.cancelRuleReconcileForVersionLock()
        #expect(appState.ruleReconcileDeferredWhileLocked)
        #expect(!appState.ruleReconcileNeedsRerun)
        #expect(!appState.isRuleReconcileQueueActive)

        appState.ruleReconcileDeferredWhileLocked = false
        appState.cancelRuleReconcileForTermination()
        #expect(!appState.ruleReconcileDeferredWhileLocked)
    }

    @Test @MainActor func deferredRuleReconcileRunsAfterUnlock() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("version-lock-reconcile-\(UUID().uuidString).sqlite")
        let store = try IndexStoreV3.open(at: url)
        let appState = AppState(store: store)
        appState.versionLockState = .locked(.betaExpired)
        appState.enqueueRuleReconcile()
        #expect(appState.ruleReconcileDeferredWhileLocked)
        #expect(!appState.isRuleReconcileQueueActive)

        appState.applyVersionLockEvaluation(
            VersionLockEvaluation(
                lockState: .unlocked,
                updateOffer: nil,
                showLockBanner: false,
                mutations: VersionLockSettingsMutations()
            )
        )
        #expect(!appState.ruleReconcileDeferredWhileLocked)
        await appState.waitForRuleReconcileIdle()
    }

    @Test @MainActor func forgetMediumNoOpWhenLocked() async throws {
        let rig = try await RecognitionRigForLock.make()
        await rig.coordinator.handle(.appeared(rig.volume()))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        await rig.appState.loadStoredMedia()
        let countBefore = rig.appState.media.count
        rig.appState.versionLockState = .locked(.buildExpired)
        rig.appState.forgetMedium(id: id)
        #expect(rig.appState.media.count == countBefore)
        #expect(try await rig.store.medium(uuid: id) != nil)
    }

    @Test @MainActor func updateMediumPersistNoOpWhenLocked() async throws {
        let rig = try await RecognitionRigForLock.make()
        await rig.coordinator.handle(.appeared(rig.volume()))
        let id = try #require(rig.appState.newMediumDialogMediumID)
        await rig.appState.loadStoredMedia()
        let storedBefore = try #require(try await rig.store.medium(uuid: id))
        rig.appState.versionLockState = .locked(.apiUnreachable)
        rig.appState.updateMedium(id: id, persist: true) {
            $0.allowIndexing = !storedBefore.allowIndexing
            $0.decision = storedBefore.allowIndexing ? .dontIndex : .index
        }
        let storedAfter = try #require(try await rig.store.medium(uuid: id))
        #expect(storedAfter.allowIndexing == storedBefore.allowIndexing)
        #expect(storedAfter.decision == storedBefore.decision)
    }

    @Test @MainActor func connectKnownDoesNotWriteWhenLocked() async throws {
        let rig = try await RecognitionRigForLock.make()
        let created = Date(timeIntervalSince1970: 1_718_102_804)
        let existing = StoredMedium(
            volumeUUID: "AAAAAAAA-BBBB-CCCC-DDDD-000000000099",
            volumeCreatedAt: created,
            fsType: "msdos",
            volumeTotalBytes: 1_000,
            name: "STORED_NAME",
            type: .usb,
            decision: .index,
            indexStatus: .indexed,
            fileCount: 1,
            folderCount: 0,
            completedDepth: 1
        )
        try await rig.store.upsertMedium(existing)
        var reconciled: [UUID] = []
        rig.coordinator.onReconcileRequested = { id, _ in reconciled.append(id) }
        rig.appState.versionLockState = .locked(.betaExpired)
        await rig.coordinator.handle(.appeared(rig.volume(name: "LIVE_NAME", uuid: existing.volumeUUID, created: created)))
        let stored = try #require(try await rig.store.medium(uuid: existing.uuid))
        #expect(stored.name == "STORED_NAME")
        #expect(reconciled.isEmpty)
        #expect(rig.appState.medium(with: existing.uuid)?.name == "LIVE_NAME")
    }

    /// bug.0.3.9.004 b, bug.0.4.063: Der Lauf hält an einem Tor (kein Rennen gegen einen Lauf über eine Datei), ein
    /// zweites Medium wird überwacht. Dann rastet die Sperre über den echten Weg ein (lokale Auswertung im
    /// Versions-Koordinator: API seit 100 Tagen nicht erreicht) – der Test ruft keine Abbruch-Funktion selbst auf
    /// (Regel 18). Erwartet: Lauf beendet, Überwachung aus, nach dem Öffnen des Tors kein Eintrag geschrieben.
    @Test @MainActor func versionLockEngagedStopsRunAndWatcher() async throws {
        let harness = try await ScanHarness.make()
        let mediumID = harness.mediumID
        let volume = testVolume(path: "/Volumes/SPERRE", name: "TEST")
        try await harness.store.recordIdentity(mediumUUID: mediumID, volume.identity)
        let inner = MemoryVolume(mountPath: "/Volumes/SPERRE")
        inner.file("ordner/a.txt")
        let access = RunGateAccess([inner]) { $0 == "/Volumes/SPERRE/ordner" }
        let app = AppState(store: harness.store)
        let rig = WiredRig(store: harness.store, access: access, app: app)
        await rig.coordinator.handle(.appeared(volume))
        let held = await waitUntil { await access.heldCount() >= 1 }
        try #require(held)
        #expect(rig.service.isRunActive(mediumID))
        #expect(app.medium(with: mediumID)?.indexStatus == .indexing)
        let watchedID = UUID()
        let source = ScriptedChangeSource()
        rig.watcher.start(mediumID: watchedID, volume: testVolume(path: "/Volumes/WACHE", name: "WACHE"), source: source)
        #expect(rig.watcher.isWatching(mediumID: watchedID))

        try VersionLockEvaluator.applyMutations(
            VersionLockSettingsMutations(setFirstRunAt: Date().addingTimeInterval(-100 * 24 * 60 * 60), firstRunFresh: false),
            pool: harness.store.pool
        )
        VersionCheckCoordinator.reevaluateLocal(appState: app, store: harness.store, databaseWasNewThisLaunch: false)
        try #require(app.versionLockState.isLocked)

        let ended = await waitUntil { !rig.service.isRunActive(mediumID) }
        #expect(ended)
        let cleared = await waitUntil { app.medium(with: mediumID)?.indexStatus != .indexing }
        #expect(cleared)
        #expect(!rig.watcher.isWatching(mediumID: watchedID))
        // Tor auf: der abgebrochene Lauf schreibt nichts mehr.
        await access.open()
        try await Task.sleep(for: .milliseconds(300))
        #expect(try await harness.store.item(mediumUUID: mediumID, path: ["ordner"], name: "a.txt") == nil)
        #expect(!rig.service.isRunActive(mediumID))
    }

    /// bug.0.4.063 (Nacharbeit): Rig mit einem unfertigen (`pending`) und einem indizierten Medium, beide über die
    /// Erkennung verbunden (Überwachung mit der FSEvents-Quelle wie in der App, Pfad wie in WatcherLifecycleTests).
    @MainActor
    private func lockRig() async throws -> LockRig {
        let harness = try await ScanHarness.make()
        let pendingVolume = testVolume(path: "/Volumes/OFFEN", name: "TEST")
        try await harness.store.recordIdentity(mediumUUID: harness.mediumID, pendingVolume.identity)
        let indexed = StoredMedium(
            fsType: "apfs", volumeTotalBytes: 1_000, name: "WACHE", type: .usb,
            decision: .index, indexStatus: .indexed, completedDepth: 1
        )
        try await harness.store.upsertMedium(indexed)
        let watchVolume = testVolume(path: "/Volumes/WACHE", name: "WACHE")
        try await harness.store.recordIdentity(mediumUUID: indexed.uuid, watchVolume.identity)
        let pendingInner = MemoryVolume(mountPath: "/Volumes/OFFEN")
        pendingInner.file("a.txt")
        let watchInner = MemoryVolume(mountPath: "/Volumes/WACHE")
        let access = RunGateAccess([pendingInner, watchInner]) { _ in false }
        let app = AppState(store: harness.store)
        let rig = WiredRig(store: harness.store, access: access, app: app)
        return LockRig(
            harness: harness, pendingVolume: pendingVolume, watchVolume: watchVolume,
            watchedID: indexed.uuid, app: app, rig: rig
        )
    }

    /// Sperre über den echten Weg: lokale Auswertung, API seit 100 Tagen nicht erreicht.
    @MainActor
    private func engageLock(_ lock: LockRig) throws {
        try VersionLockEvaluator.applyMutations(
            VersionLockSettingsMutations(setFirstRunAt: Date().addingTimeInterval(-100 * 24 * 60 * 60), firstRunFresh: false),
            pool: lock.harness.store.pool
        )
        VersionCheckCoordinator.reevaluateLocal(appState: lock.app, store: lock.harness.store, databaseWasNewThisLaunch: false)
    }

    /// bug.0.4.063 (Nacharbeit): Pause und Fortsetzen im gesperrten Zustand starten die Überwachung nicht
    /// (vorher: `applyPause` → `start`).
    @Test @MainActor func pauseEndWhileLockedStartsNoWatcher() async throws {
        let lock = try await lockRig()
        try engageLock(lock)
        try #require(lock.app.versionLockState.isLocked)
        await lock.rig.coordinator.handle(.appeared(lock.watchVolume))
        #expect(lock.rig.coordinator.volume(for: lock.watchedID) != nil)
        let defaults = try #require(UserDefaults(suiteName: "lock-pause-\(UUID().uuidString)"))
        SystemNotice.$testHooks.withValue(NoticeTestHooks(post: { _, _ in })) {
            lock.app.pauseIndexing(until: nil, defaults: defaults)
            lock.app.resumeIndexing(defaults: defaults)
        }
        try await Task.sleep(for: .milliseconds(500))
        #expect(!lock.rig.watcher.isWatching(mediumID: lock.watchedID))
        await lock.rig.watcher.stop(mediumID: lock.watchedID)
    }

    /// bug.0.4.063 (Nacharbeit): Sperre durch Auswertung, Medien verbunden (nichts startet), dann Entsperren durch eine
    /// API-Antwort → Überwachung des indizierten Mediums läuft, das unfertige wird indiziert.
    @Test @MainActor func unlockResumesWatcherAndIndexing() async throws {
        let lock = try await lockRig()
        let version = try #require(AppVersion.currentApp())
        try engageLock(lock)
        try #require(lock.app.versionLockState.isLocked)
        await lock.rig.coordinator.handle(.appeared(lock.pendingVolume))
        await lock.rig.coordinator.handle(.appeared(lock.watchVolume))
        try await Task.sleep(for: .milliseconds(200))
        #expect(!lock.rig.watcher.isWatching(mediumID: lock.watchedID))
        #expect(lock.rig.starts(lock.harness.mediumID).isEmpty)

        VersionCheckCoordinator.handleAPIResult(
            VersionCheckResponse(version: version), appState: lock.app, store: lock.harness.store,
            databaseWasNewThisLaunch: false
        )
        try #require(!lock.app.versionLockState.isLocked)
        #expect(await waitUntil { lock.rig.watcher.isWatching(mediumID: lock.watchedID) })
        #expect(await waitUntil { !lock.rig.starts(lock.harness.mediumID).isEmpty })
        #expect(await waitUntil { !lock.rig.service.isRunActive(lock.harness.mediumID) })
        await lock.rig.watcher.stop(mediumID: lock.watchedID)
    }

    /// bug.0.4.073: Ein vollständiger Abgleich eines indizierten Mediums hält am Tor; die Sperre rastet über die echte
    /// Auswertung ein und bricht ihn ab (Medium bleibt `.indexed`). Entsperren über eine API-Antwort → genau ein neuer
    /// Abgleich. Der Test ruft keinen Kettenschritt selbst auf (Regel 18), er wartet auf die Bedingung.
    @Test @MainActor func unlockRetriesReconcileInterruptedByLock() async throws {
        let harness = try await ScanHarness.make()
        let version = try #require(AppVersion.currentApp())
        let indexed = StoredMedium(
            fsType: "apfs", volumeTotalBytes: 1_000, name: "ABGLEICH", type: .usb,
            decision: .index, indexStatus: .indexed, completedDepth: 1
        )
        try await harness.store.upsertMedium(indexed)
        let volume = testVolume(path: "/Volumes/ABGLEICH", name: "ABGLEICH")
        try await harness.store.recordIdentity(mediumUUID: indexed.uuid, volume.identity)
        let inner = MemoryVolume(mountPath: "/Volumes/ABGLEICH")
        inner.file("ordner/a.txt")
        let access = RunGateAccess([inner]) { $0 == "/Volumes/ABGLEICH" }
        let app = AppState(store: harness.store)
        let rig = WiredRig(store: harness.store, access: access, app: app)
        let id = indexed.uuid

        await rig.coordinator.handle(.appeared(volume))
        try #require(await waitUntil { await access.heldCount() >= 1 })
        #expect(rig.starts(id) == [false])
        #expect(rig.service.isRunActive(id))

        try VersionLockEvaluator.applyMutations(
            VersionLockSettingsMutations(setFirstRunAt: Date().addingTimeInterval(-100 * 24 * 60 * 60), firstRunFresh: false),
            pool: harness.store.pool
        )
        VersionCheckCoordinator.reevaluateLocal(appState: app, store: harness.store, databaseWasNewThisLaunch: false)
        try #require(app.versionLockState.isLocked)
        #expect(await waitUntil { !rig.service.isRunActive(id) })
        #expect(app.medium(with: id)?.indexStatus == .indexed)
        #expect(try await harness.store.medium(uuid: id)?.indexStatus == .indexed)
        #expect(rig.starts(id).count == 1)

        VersionCheckCoordinator.handleAPIResult(
            VersionCheckResponse(version: version), appState: app, store: harness.store,
            databaseWasNewThisLaunch: false
        )
        try #require(!app.versionLockState.isLocked)
        #expect(await waitUntil { rig.starts(id).count >= 2 })
        #expect(await waitUntil { await access.heldCount() >= 2 })
        // bug.0.4.080 b): Solange der nachgeholte Abgleich läuft, startet die Überwachung nicht daneben aus
        // `pauseChanged` (erst nach dem Lauf über `onRunIndexed`; in diesem Aufbau ohne Überwachung).
        try await Task.sleep(for: .milliseconds(300))
        #expect(!rig.watcher.isWatching(mediumID: id))
        await access.open()
        #expect(await waitUntil { !rig.service.isRunActive(id) })
        #expect(rig.starts(id) == [false, false])
        // bug.0.4.080 a): Nachwarten; ein später dritter Start (doppelter Abgleich) fiele hier auf.
        try await Task.sleep(for: .milliseconds(500))
        #expect(!rig.service.isRunActive(id))
        #expect(rig.starts(id) == [false, false])
        await rig.watcher.stop(mediumID: id)
    }

    /// bug.0.4.073 (Prüfung): Entsperren, während der Abbruch noch auf den Lauf wartet (`cancel` hält an einem Tor
    /// je Instanz). Erwartet: nach dem Ende des Abbruchs genau ein neuer Abgleich, danach läuft die Überwachung
    /// (über `onRunIndexed` wie in der App). Der Test ruft keinen Kettenschritt selbst auf (Regel 18).
    @Test @MainActor func unlockDuringPendingCancelStartsOneReconcileAndWatcher() async throws {
        let harness = try await ScanHarness.make()
        let version = try #require(AppVersion.currentApp())
        let indexed = StoredMedium(
            fsType: "apfs", volumeTotalBytes: 1_000, name: "ZAEH", type: .usb,
            decision: .index, indexStatus: .indexed, completedDepth: 1
        )
        try await harness.store.upsertMedium(indexed)
        let volume = testVolume(path: "/Volumes/ZAEH", name: "ZAEH")
        try await harness.store.recordIdentity(mediumUUID: indexed.uuid, volume.identity)
        let inner = MemoryVolume(mountPath: "/Volumes/ZAEH")
        inner.file("ordner/a.txt")
        let access = RunGateAccess([inner]) { $0 == "/Volumes/ZAEH" }
        let app = AppState(store: harness.store)
        let box = WatcherBox()
        let store = harness.store
        let rig = WiredRig(store: store, access: access, app: app) { [box] id, volume in
            guard let watcher = box.watcher else { return }
            await LiveWiring.startWatching(id: id, volume: volume, store: store, watcher: watcher, appState: app)
        }
        box.watcher = rig.watcher
        let probe = CancelHookProbe()
        rig.service.cancelBeforeAwaitHookForTesting = { [probe] _ in await probe.gate.wait() }
        let id = indexed.uuid

        await rig.coordinator.handle(.appeared(volume))
        try #require(await waitUntil { await access.heldCount() >= 1 })
        #expect(rig.starts(id) == [false])

        try VersionLockEvaluator.applyMutations(
            VersionLockSettingsMutations(setFirstRunAt: Date().addingTimeInterval(-100 * 24 * 60 * 60), firstRunFresh: false),
            pool: harness.store.pool
        )
        VersionCheckCoordinator.reevaluateLocal(appState: app, store: harness.store, databaseWasNewThisLaunch: false)
        try #require(app.versionLockState.isLocked)
        try #require(await waitUntil { rig.service.isCancellingForTesting(id) })

        VersionCheckCoordinator.handleAPIResult(
            VersionCheckResponse(version: version), appState: app, store: harness.store,
            databaseWasNewThisLaunch: false
        )
        try #require(!app.versionLockState.isLocked)
        await access.open()
        // Der Abbruch hängt noch: Der Nachholer wartet, bis er fertig ist.
        try await Task.sleep(for: .milliseconds(100))
        #expect(rig.service.isCancellingForTesting(id))
        #expect(rig.starts(id) == [false])
        await probe.gate.signal()
        #expect(await waitUntil { rig.starts(id).count >= 2 })
        #expect(await waitUntil { !rig.service.isRunActive(id) })
        #expect(rig.starts(id) == [false, false])
        #expect(await waitUntil { rig.watcher.isWatching(mediumID: id) })
        // bug.0.4.080 a): Nachwarten; ein später dritter Start (doppelter Abgleich) fiele hier auf.
        try await Task.sleep(for: .milliseconds(500))
        #expect(!rig.service.isRunActive(id))
        #expect(rig.starts(id) == [false, false])
        await rig.watcher.stop(mediumID: id)
    }

    /// bug.0.4.080 a): Zwei Starts während desselben Abbruchs (Nachholer aus LiveWiring und ein Start wie vom
    /// Koordinator) werden zu einem Neustart zusammengefasst: nach dem Abbruch genau ein Abgleich, kein dritter.
    @Test @MainActor func twoStartsDuringPendingCancelRunOnce() async throws {
        let harness = try await ScanHarness.make()
        let version = try #require(AppVersion.currentApp())
        let indexed = StoredMedium(
            fsType: "apfs", volumeTotalBytes: 1_000, name: "DOPPEL", type: .usb,
            decision: .index, indexStatus: .indexed, completedDepth: 1
        )
        try await harness.store.upsertMedium(indexed)
        let volume = testVolume(path: "/Volumes/DOPPEL", name: "DOPPEL")
        try await harness.store.recordIdentity(mediumUUID: indexed.uuid, volume.identity)
        let inner = MemoryVolume(mountPath: "/Volumes/DOPPEL")
        inner.file("ordner/a.txt")
        let access = RunGateAccess([inner]) { $0 == "/Volumes/DOPPEL" }
        let app = AppState(store: harness.store)
        let rig = WiredRig(store: harness.store, access: access, app: app)
        let probe = CancelHookProbe()
        rig.service.cancelBeforeAwaitHookForTesting = { [probe] _ in await probe.gate.wait() }
        let id = indexed.uuid

        await rig.coordinator.handle(.appeared(volume))
        try #require(await waitUntil { await access.heldCount() >= 1 })
        try VersionLockEvaluator.applyMutations(
            VersionLockSettingsMutations(setFirstRunAt: Date().addingTimeInterval(-100 * 24 * 60 * 60), firstRunFresh: false),
            pool: harness.store.pool
        )
        VersionCheckCoordinator.reevaluateLocal(appState: app, store: harness.store, databaseWasNewThisLaunch: false)
        try #require(app.versionLockState.isLocked)
        try #require(await waitUntil { rig.service.isCancellingForTesting(id) })
        VersionCheckCoordinator.handleAPIResult(
            VersionCheckResponse(version: version), appState: app, store: harness.store,
            databaseWasNewThisLaunch: false
        )
        try #require(!app.versionLockState.isLocked)
        // Zweiter Start in derselben Abbruchphase (wie der Koordinator nach dem Entsperren).
        rig.service.start(mediumUUID: id, volume: volume, fromScratch: false)
        await access.open()
        try #require(rig.service.isCancellingForTesting(id))
        await probe.gate.signal()

        #expect(await waitUntil { rig.starts(id).count >= 2 })
        #expect(await waitUntil { !rig.service.isRunActive(id) })
        try await Task.sleep(for: .milliseconds(500))
        #expect(!rig.service.isRunActive(id))
        #expect(rig.starts(id) == [false, false])
    }

    @Test @MainActor func watcherFlushSkipsWritesWhenLocked() async throws {
        // Scripted source statt echter FSEvents/DMG — unter Parallel-Last sonst Wackeln.
        let rig = try await watchRig()
        let mediumID = rig.medium.uuid
        rig.access.listings["/Volumes/DISK"] = [
            ListedDirectoryEntry(
                name: "live.txt",
                isDirectory: false,
                isPackage: false,
                isSymbolicLink: false,
                isHidden: false,
                fileSize: 1,
                modifiedAt: nil
            ),
        ]
        rig.watcher.quietInterval = .milliseconds(40)
        rig.watcher.start(mediumID: mediumID, volume: rig.volume, source: rig.source)
        rig.app.versionLockState = .locked(.betaExpired)
        #expect(!rig.app.featureAccess.canWriteIndex)
        rig.source.emit(VolumeChange(path: "/Volumes/DISK/live.txt", eventID: 7, itemCreated: true))
        try await Task.sleep(for: .milliseconds(200))
        #expect(try await rig.store.item(mediumUUID: mediumID, path: [], name: "live.txt") == nil)
        try await Task.sleep(for: .milliseconds(200))
        #expect(try await rig.store.item(mediumUUID: mediumID, path: [], name: "live.txt") == nil)
        #expect(rig.access.listCount(for: "/Volumes/DISK") == 0)
    }
}

@MainActor
private struct LockRig {
    let harness: ScanHarness
    let pendingVolume: VolumeInfo
    let watchVolume: VolumeInfo
    let watchedID: UUID
    let app: AppState
    let rig: WiredRig
}

@MainActor
private enum RecognitionRigForLock {
    static func make() async throws -> RecognitionRigForLockInstance {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-lock-\(UUID().uuidString)", isDirectory: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let access = ScriptedAccessForLock()
        let appState = AppState(store: store)
        let coordinator = MediumCoordinator(store: store, access: access, appState: appState)
        return RecognitionRigForLockInstance(store: store, appState: appState, coordinator: coordinator, access: access)
    }
}

@MainActor
private struct RecognitionRigForLockInstance {
    let store: IndexStoreV3
    let appState: AppState
    let coordinator: MediumCoordinator
    let access: ScriptedAccessForLock

    func volume(
        name: String = "ZOOM_H4E",
        path: String = "/Volumes/ZOOM_H4E",
        uuid: String? = nil,
        created: Date? = Date(timeIntervalSince1970: 1_718_102_804)
    ) -> VolumeInfo {
        VolumeInfo(
            mountPath: path,
            name: name,
            fsType: "msdos",
            volumeTotalBytes: 1_000,
            volumeFreeBytes: 400,
            diskSizeBytes: 1_024,
            volumeUUID: uuid,
            createdAt: created,
            isRemovable: true,
            isEjectable: true,
            isInternal: true,
            isLocal: true,
            deviceProtocol: "Secure Digital",
            model: "Built In SDXC Reader",
            isTimeMachineSnapshot: false
        )
    }
}

private final class ScriptedAccessForLock: MediumAccess, @unchecked Sendable {
    var result: MediumAccessResult = .granted
    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { result }
    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] { [] }
}

@MainActor
private final class WatcherBox {
    weak var watcher: ChangeWatcher?
}

@MainActor
private final class CancelHookProbe {
    let gate = SurfaceAsyncSignal()
}
