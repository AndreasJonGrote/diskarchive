//
//  LifecycleConcurrencyTests.swift
//  diskindexTests
//
//  bug.0.4.052 (REPORT 92): Pausentimer nach Store-Fehler.
//  bug.0.4.062 (REPORT 132): Nebenläufigkeit – Worker-Handles, FSEvents-Schließen, Reprobe beim Aushängen,
//  `onTrackedError`, „Im Finder anzeigen“ ohne Medien-I/O auf main.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct LifecycleConcurrencyTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-lifecycle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: bug.0.4.052

    /// Store-Fehler bei offenem Store: Abbau bricht den Pausentimer ab; er muss neu geplant werden und ablaufen.
    @Test func storeFailureKeepsThePauseExpiry() async throws {
        let harness = try StoreHarness.make()
        let app = AppState(store: harness.store)
        let defaults = try #require(UserDefaults(suiteName: "diskindex-lifecycle-\(UUID().uuidString)"))
        let now = Date()
        app.pauseIndexing(until: now.addingTimeInterval(0.4), defaults: defaults, now: now)
        #expect(app.globalAutoIndexPaused)
        app.detachAfterStoreFailure(now: now)
        #expect(app.indexStore == nil)
        #expect(app.pauseExpiryTask != nil)
        let expired = await waitUntil(timeout: 10) { !app.globalAutoIndexPaused }
        #expect(expired)
    }

    // MARK: bug.0.4.062 Worker-defer

    /// Abbruch und sofortiger Neustart des Regel-Abgleichs: das `defer` des alten Tasks löscht den neuen Handle nicht.
    @Test func cancelledRuleReconcileDoesNotClearTheNewWorker() async throws {
        let harness = try StoreHarness.make()
        let app = AppState(store: harness.store)
        await app.waitForRuleReconcileIdle()
        await harness.store.setReconcileBatchDelay(.seconds(5))
        app.enqueueRuleReconcile()
        let old = try #require(app.ruleReconcileTask)
        app.cancelRuleReconcileForTermination()
        app.enqueueRuleReconcile()
        let new = try #require(app.ruleReconcileTask)
        #expect(old != new)
        await old.value
        // Das `defer` des alten Tasks reiht sich vor dieser Fortsetzung auf main ein; Reserve für Last.
        try await Task.sleep(for: .milliseconds(200))
        #expect(app.ruleReconcileTask == new)
        #expect(app.isRuleReconcileQueueActive)
        app.cancelRuleReconcileForTermination()
        await new.value
        await harness.store.setReconcileBatchDelay(nil)
    }

    /// Dasselbe für die Datenbank-Wartung (sonst laufen zwei Wartungs-Worker bzw. die Wartung parallel zum Abgleich).
    @Test func cancelledMaintenanceDoesNotClearTheNewWorker() async throws {
        let harness = try StoreHarness.make()
        let app = AppState(store: harness.store)
        await app.waitForRuleReconcileIdle()
        app.cancelDatabaseMaintenanceForTermination()
        // Wartung kann nicht starten (laufende Synchronisierung) → der neue Worker wartet in seiner Schleife.
        app.mediumLiveSyncIDs.insert(UUID())
        app.scheduleDatabaseMaintenance()
        let old = try #require(app.databaseMaintenanceTask)
        app.cancelDatabaseMaintenanceForTermination()
        app.scheduleDatabaseMaintenance()
        let new = try #require(app.databaseMaintenanceTask)
        #expect(old != new)
        await old.value
        try await Task.sleep(for: .milliseconds(200))
        #expect(app.databaseMaintenanceTask == new)
        app.cancelDatabaseMaintenanceForTermination()
        await new.value
        app.mediumLiveSyncIDs.removeAll()
    }

    // MARK: bug.0.4.062 FSEvents

    /// Abbruch von einem fremden Thread während eines laufenden Callbacks: geschlossen wird erst danach, auf der
    /// Callback-Queue (der Kontext hält `self` unretained), und ohne Verklemmung mit dem `yield` des Callbacks.
    @Test func fsEventsCloseWaitsForARunningCallback() async throws {
        let directory = try folder()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = FSEventsChangeSource(mountPath: directory.path)
        let gate = CallbackGate()
        source.setReceiveHookForTesting { gate.hold(atMost: 5) }
        let stream = source.changes()
        let consumer = Task.detached {
            for await _ in stream {}
        }
        defer { gate.release() }
        // Ereignis erzeugen, bis der Callback im Hook steht (FSEvents-Latenz 1 s).
        var entered = false
        for index in 0..<10 where !entered {
            try Data("x".utf8).write(to: directory.appendingPathComponent("datei-\(index).txt"))
            entered = await waitUntil(timeout: 2) { gate.isHolding }
        }
        try #require(entered)
        // Abbruch von einem fremden Thread → `onTermination` → `close`.
        DispatchQueue.global().async { consumer.cancel() }
        try await Task.sleep(for: .milliseconds(300))
        #expect(!source.closeFinishedForTesting)
        gate.release()
        #expect(await waitUntil(timeout: 10) { source.closeFinishedForTesting })
        #expect(source.lastCloseRanOnQueueForTesting == true)
        await consumer.value
    }

    // MARK: bug.0.4.062 Reprobe

    /// Während eines `await` NACH der Zugriffsprobe ausgehängt (Lesen des Mediums in `storeAndPresent`; das Fenster der
    /// Probe selbst deckt bug.0.4.026 ab): kein neues Medium, nicht „verbunden“, kein Dialog.
    @Test func unmountDuringReprobeStoreReadPublishesNothing() async throws {
        let harness = try StoreHarness.make()
        let app = AppState()
        let access = GatedProbeAccess()
        let coordinator = MediumCoordinator(store: harness.store, access: access, appState: app)
        let volume = Self.volume()
        access.setResult(.denied(reason: "NSCocoaErrorDomain 257"))
        await coordinator.handle(.appeared(volume))
        let denied = try #require(app.media.first { $0.name == volume.name })
        #expect(denied.indexStatus == .error)
        #expect(try await harness.store.media().count == 1)

        access.setResult(.granted)
        // 1. Lesen: Schnappschuss in `reprobeDeniedVolumes` (vor der Probe); 2. Lesen: in `storeAndPresent` → dort aushängen.
        let path = volume.mountPath
        harness.store.mediumReadHookForTesting.set(skip: 1) {
            await coordinator.handle(.disappeared(path: path))
        }
        await coordinator.applicationDidBecomeActive()

        #expect(try await harness.store.media().count == 1)
        #expect(app.media.count == 1)
        #expect(app.medium(with: denied.id)?.connectionStatus == .offline)
        #expect(app.newMediumDialogMediumID == nil)
        let stored = try #require(try await harness.store.medium(uuid: denied.id))
        #expect(stored.indexStatus == .error)
        coordinator.stop()
    }

    // MARK: bug.0.4.062 onTrackedError

    /// Setzen und Lesen von verschiedenen Threads (vorher ohne Sperre); danach wirkt der zuletzt gesetzte Handler.
    @Test func trackedErrorHandlerIsSetAndReadConcurrently() throws {
        let directory = try folder()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = DiskIndexLog(directory: directory)
        let early = CallCounter()
        let late = CallCounter()
        DispatchQueue.concurrentPerform(iterations: 200) { index in
            if index.isMultiple(of: 2) {
                log.onTrackedError = { _, _ in early.add() }
            } else {
                log.record(.store, .error, "parallel \(index)")
            }
        }
        log.onTrackedError = { _, _ in late.add() }
        log.record(.store, .error, "danach")
        log.flushPendingWritesForTesting()
        #expect(late.value == 1)
    }

    // MARK: bug.0.4.062 Finder

    /// „Im Finder anzeigen“: `fileExists` auf dem Medium läuft nicht auf main; geöffnet wird das Ziel.
    @Test func revealInFinderChecksTheMediumOffMain() async throws {
        let mount = try folder()
        defer { try? FileManager.default.removeItem(at: mount) }
        let file = mount.appendingPathComponent("Ordner/a.txt")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: file)
        let app = AppState()
        let medium = Medium(
            id: UUID(), name: "Finder", type: .usb, connectionStatus: .connected, indexStatus: .indexed,
            allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1, capacityUsedBytes: 0,
            fileCount: 1, folderCount: 1, lastSeenAt: Date(), firstIndexedAt: nil, lastIndexedAt: nil,
            isForgotten: false, indexingProgress: 0
        )
        app.media = [medium]
        app.mountPath = { _ in mount.path }
        let probe = ThreadProbe()
        app.finderRevealFileExists = { path in
            probe.note(onMain: Thread.isMainThread)
            return FileManager.default.fileExists(atPath: path)
        }
        var opened: [String] = []
        app.finderRevealOpen = { opened.append($0.path) }
        let target = ObjectContextTarget(id: UUID(), name: "a.txt", kind: .file, mediumID: medium.id, itemPath: "/Ordner/a.txt")
        let task = try #require(app.revealInFinder(target))
        await task.value
        #expect(probe.calls >= 1)
        #expect(!probe.anyOnMain)
        #expect(opened == [mount.appendingPathComponent("Ordner/a.txt").path])
    }

    private static func volume() -> VolumeInfo {
        VolumeInfo(
            mountPath: "/Volumes/LIFECYCLE",
            name: "LIFECYCLE",
            fsType: "msdos",
            volumeTotalBytes: 1_000,
            volumeFreeBytes: 400,
            diskSizeBytes: 1_024,
            volumeUUID: "ABABABAB-ABAB-ABAB-ABAB-ABABABABABAB",
            createdAt: Date(timeIntervalSince1970: 1_718_109_000),
            isRemovable: true,
            isEjectable: true,
            isInternal: false,
            isLocal: true,
            deviceProtocol: "USB",
            model: "Stick",
            isTimeMachineSnapshot: false
        )
    }
}

/// Zugriff mit anhaltbarer Probe (Zustand je Test).
nonisolated private final class GatedProbeAccess: MediumAccess, @unchecked Sendable {
    private let lock = NSLock()
    private var result: MediumAccessResult = .granted
    private var holdNext = false
    private var holding = false
    private var waiter: CheckedContinuation<Void, Never>?
    private var released = false

    var isHolding: Bool { lock.withLock { holding } }

    func setResult(_ value: MediumAccessResult) { lock.withLock { result = value } }

    func holdNextProbe() { lock.withLock { holdNext = true; released = false } }

    func releaseProbe() {
        let pending = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            released = true
            defer { waiter = nil }
            return waiter
        }
        pending?.resume()
    }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult {
        let shouldHold = lock.withLock { () -> Bool in
            defer { holdNext = false }
            return holdNext
        }
        if shouldHold {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let resumeNow = lock.withLock { () -> Bool in
                    if released { return true }
                    waiter = continuation
                    holding = true
                    return false
                }
                if resumeNow { continuation.resume() }
            }
            lock.withLock { holding = false }
        }
        return lock.withLock { result }
    }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] { [] }
}

nonisolated private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func add() { lock.withLock { count += 1 } }
}

nonisolated private final class ThreadProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var onMain = false
    var calls: Int { lock.withLock { count } }
    var anyOnMain: Bool { lock.withLock { onMain } }
    func note(onMain main: Bool) {
        lock.withLock {
            count += 1
            onMain = onMain || main
        }
    }
}


/// Hält einen FSEvents-Callback an (Zustand je Test).
nonisolated private final class CallbackGate: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var holding = false
    private var released = false

    var isHolding: Bool { lock.withLock { holding } }

    func hold(atMost seconds: Double) {
        let wait = lock.withLock { () -> Bool in
            guard !released, !holding else { return false }
            holding = true
            return true
        }
        guard wait else { return }
        _ = semaphore.wait(timeout: .now() + seconds)
        lock.withLock { holding = false }
    }

    func release() {
        let signal = lock.withLock { () -> Bool in
            defer { released = true }
            return !released
        }
        if signal { semaphore.signal() }
    }
}
