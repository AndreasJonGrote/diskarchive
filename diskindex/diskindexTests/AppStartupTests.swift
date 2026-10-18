//
//  AppStartupTests.swift
//  diskindexTests
//
//  bug.0.4.042 (REPORT 87, 88) — Einzelinstanz vor dem Protokoll, Beenden bei Übergabe ohne Abbau,
//  SIGTERM über eine eingesetzte Signalquelle (kein echtes Signal an den Testprozess, Regel 20), `O_APPEND`.
//

import AppKit
import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct AppStartupTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("diskindex-startup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func snapshot(_ url: URL) -> (data: Data?, modified: Date?) {
        let data = try? Data(contentsOf: url)
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        return (data, modified)
    }

    /// Übergabe: die Zweitinstanz schreibt keine Protokollzeile und fasst `crash-last.txt` nicht an.
    @Test func handOffTouchesNeitherTheLogNorTheCrashFile() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let logURL = folder.appendingPathComponent("diskindex.log")
        let crashURL = folder.appendingPathComponent("crash-last.txt")
        try Data("2026-10-17 erste Instanz start\n".utf8).write(to: logURL)
        try Data("CRASH signal=SEGV\n".utf8).write(to: crashURL)
        let logBefore = snapshot(logURL)
        let crashBefore = snapshot(crashURL)

        let log = DiskIndexLog(directory: folder)
        let handedOff = AppStartup.willFinishLaunching(
            launchKind: .click,
            resolveSingleInstance: { .handOff },
            log: log,
            installHandlers: false
        )
        log.flushPendingWritesForTesting()
        #expect(handedOff)
        #expect(snapshot(logURL).data == logBefore.data)
        #expect(snapshot(logURL).modified == logBefore.modified)
        #expect(snapshot(crashURL).data == crashBefore.data)
        #expect(snapshot(crashURL).modified == crashBefore.modified)
        #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("crash-handled").path))
        #expect(log.crashFDForTesting < 0)
    }

    /// Ohne andere Instanz: Protokoll startet, Startzeile und Absturzdatei sind da.
    @Test func aloneStartsTheLogAfterTheCheck() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = DiskIndexLog(directory: folder)
        var order: [String] = []
        let handedOff = AppStartup.willFinishLaunching(
            launchKind: .click,
            resolveSingleInstance: {
                order.append(FileManager.default.fileExists(atPath: log.fileURL.path) ? "log-schon-da" : "pruefung")
                return .quitOlder(count: 2)
            },
            log: log,
            installHandlers: false
        )
        log.flushPendingWritesForTesting()
        #expect(!handedOff)
        #expect(order == ["pruefung"])
        let text = String(decoding: try Data(contentsOf: log.fileURL), as: UTF8.self)
        #expect(text.contains("instance handoff debug quit older count=2"))
        #expect(text.contains("app launch kind=\(AppLaunchKind.click.rawValue)"))
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("crash-last.txt").path))
    }

    /// Beenden bei Übergabe: sofort, kein Abbau, kein Abschluss (keine Protokollzeile).
    @Test func handedOffTerminationTearsNothingDown() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let flow = TerminationFlow(log: DiskIndexLog(directory: folder))
        var teardowns = 0
        var finishes = 0
        var replies = 0
        let reply = flow.shouldTerminate(
            handedOff: true,
            teardown: { teardowns += 1 },
            finish: { finishes += 1 },
            reply: { replies += 1 }
        )
        #expect(reply == .terminateNow)
        #expect(teardowns == 0)
        #expect(finishes == 0)
        #expect(replies == 0)
    }

    /// SIGTERM-Weg: Auslöser der Signalquelle → Beenden wie `NSApp.terminate` → Abbau, Checkpoint, „app terminate ok“.
    @Test func terminationSignalTerminatesAndCheckpoints() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = DiskIndexLog(directory: folder)
        log.start(installHandlers: false)
        let harness = try StoreHarness.make()
        let app = AppState(store: harness.store)
        let source = FakeTerminationSignalSource()
        let flow = TerminationFlow(log: log)
        var replies: [NSApplication.TerminateReply] = []
        var teardowns = 0
        let finished = FinishFlag()
        // Wie in der App: SIGTERM → terminate → `applicationShouldTerminate` → `TerminationFlow.shouldTerminate`.
        TerminationSignal.install(source) {
            replies.append(flow.shouldTerminate(
                handedOff: false,
                teardown: { teardowns += 1 },
                finish: { await AppStartup.finishTermination(appState: app, log: log) },
                reply: { finished.replies += 1 }
            ))
        }
        let checkpointsBefore = harness.store.checkpointCalls.value
        source.fire()
        let done = await waitUntil { finished.replies > 0 }
        #expect(done)
        #expect(replies == [.terminateLater])
        #expect(teardowns == 1)
        #expect(harness.store.checkpointCalls.value > checkpointsBefore)
        log.flushPendingWritesForTesting()
        let text = String(decoding: try Data(contentsOf: log.fileURL), as: UTF8.self)
        #expect(text.contains("app terminate ok"))
        #expect(!text.contains("app terminate timeout"))
    }

    /// bug.0.3.9.009: Hängt der Abschluss, kommt die Antwort nach der Zeitgrenze (hier 0,3 s statt 8 s) mit Protokollzeile.
    @Test func hangingFinishRepliesAfterTheTimeout() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = DiskIndexLog(directory: folder)
        let timeout: Duration = .milliseconds(300)
        let flow = TerminationFlow(timeout: timeout, log: log)
        let gate = FinishGate()
        let finished = FinishFlag()
        let started = ContinuousClock.now
        let reply = flow.shouldTerminate(
            handedOff: false,
            teardown: {},
            finish: { await gate.wait() },
            reply: { finished.replies += 1 }
        )
        #expect(reply == .terminateLater)
        // Notfall-Grenze großzügig (Last); die Aussage ist „kommt überhaupt, und nicht vor der Zeitgrenze“.
        let done = await waitUntil(timeout: 20) { finished.replies > 0 }
        let elapsed = started.duration(to: .now)
        #expect(done)
        #expect(elapsed >= timeout)
        log.flushPendingWritesForTesting()
        let text = String(decoding: (try? Data(contentsOf: log.fileURL)) ?? Data(), as: UTF8.self)
        #expect(text.contains("app terminate timeout"))
        // Der hängende Abschluss endet später: keine zweite Antwort.
        gate.open()
        try await Task.sleep(for: .milliseconds(200))
        #expect(finished.replies == 1)
    }

    /// bug.0.3.9.009: Zweites SIGTERM oder ⌘Q während `.terminateLater`: Abbau und Abschluss genau einmal, eine Antwort.
    @Test func secondTerminateStartsNothingAgain() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let flow = TerminationFlow(log: DiskIndexLog(directory: folder))
        let gate = FinishGate()
        let counts = FinishFlag()
        var teardowns = 0
        func terminate() -> NSApplication.TerminateReply {
            flow.shouldTerminate(
                handedOff: false,
                teardown: { teardowns += 1 },
                finish: {
                    counts.finishes += 1
                    await gate.wait()
                },
                reply: { counts.replies += 1 }
            )
        }
        #expect(terminate() == .terminateLater)
        #expect(await waitUntil { counts.finishes == 1 })
        #expect(terminate() == .terminateLater)
        #expect(teardowns == 1)
        gate.open()
        #expect(await waitUntil { counts.replies > 0 })
        try await Task.sleep(for: .milliseconds(200))
        #expect(counts.finishes == 1)
        #expect(counts.replies == 1)
        #expect(teardowns == 1)
    }

    /// bug.0.3.9.011: Der Checkpoint hängt synchron (Hook am Store, wie eine gehaltene Schreibsperre). Der Hauptthread
    /// bleibt frei, die Antwort kommt nach der Zeitgrenze, solange der Checkpoint noch hängt, und genau einmal.
    @Test func blockingCheckpointRepliesAfterTheTimeout() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = DiskIndexLog(directory: folder)
        log.start(installHandlers: false)
        let harness = try StoreHarness.make()
        let app = AppState(store: harness.store)
        let hook = BlockingHook()
        // Löst sich spätestens nach 5 s selbst (sonst hinge der Testprozess); der Test öffnet ihn vorher.
        harness.store.checkpointHookForTesting.set { hook.block(atMost: 5) }
        defer { hook.release() }
        let exits = ExitCounter()
        let timeout: Duration = .milliseconds(300)
        let flow = TerminationFlow(timeout: timeout, exitGrace: .seconds(30), log: log, forceExit: { exits.add() })
        let counts = FinishFlag()
        var blockedAtReply: Bool?
        let started = ContinuousClock.now
        let reply = flow.shouldTerminate(
            handedOff: false,
            teardown: {},
            finish: {
                await AppStartup.finishTermination(appState: app, log: log)
                counts.finishes += 1
            },
            reply: {
                counts.replies += 1
                blockedAtReply = hook.isBlocking
            }
        )
        #expect(reply == .terminateLater)
        let replied = await waitUntil(timeout: 20) { counts.replies > 0 }
        #expect(replied)
        #expect(started.duration(to: .now) >= timeout)
        // Die Antwort kam, während der Checkpoint noch hing (vorher: Hauptthread blockiert bis zum Lösen).
        #expect(blockedAtReply == true)
        #expect(hook.entered)
        hook.release()
        #expect(await waitUntil(timeout: 20) { counts.finishes > 0 })
        #expect(counts.replies == 1)
        #expect(exits.value == 0)
        log.flushPendingWritesForTesting()
        let text = String(decoding: try Data(contentsOf: log.fileURL), as: UTF8.self)
        #expect(text.contains("app terminate timeout"))
    }

    /// bug.0.3.9.011: Hängt der Hauptthread selbst, feuert der Zeitgeber trotzdem (GCD, nicht MainActor); kommt die
    /// eingereihte Antwort nicht an, endet der Prozess nach der weiteren Frist (hier: eingesetzter Ausstieg).
    @Test func blockedMainThreadForcesExitAfterTheGrace() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = DiskIndexLog(directory: folder)
        log.start(installHandlers: false)
        let exited = DispatchSemaphore(value: 0)
        let exits = ExitCounter()
        let flow = TerminationFlow(
            timeout: .milliseconds(200),
            exitGrace: .milliseconds(300),
            log: log,
            forceExit: {
                exits.add()
                exited.signal()
            }
        )
        let gate = FinishGate()
        let counts = FinishFlag()
        let reply = flow.shouldTerminate(
            handedOff: false,
            teardown: {},
            finish: { await gate.wait() },
            reply: { counts.replies += 1 }
        )
        #expect(reply == .terminateLater)
        // Hauptthread synchron blockieren, bis der Ausstieg kommt (höchstens 5 s).
        let result = Self.blockMainThread(until: exited, seconds: 5)
        #expect(result == .success)
        #expect(exits.value == 1)
        log.flushPendingWritesForTesting()
        let text = String(decoding: try Data(contentsOf: log.fileURL), as: UTF8.self)
        #expect(text.contains("app terminate timeout"))
        #expect(text.contains("app terminate force exit"))
        // Danach: die eingereihte Antwort läuft einmal, der spätere Abschluss antwortet nicht noch einmal.
        #expect(await waitUntil(timeout: 20) { counts.replies > 0 })
        gate.open()
        try await Task.sleep(for: .milliseconds(200))
        #expect(counts.replies == 1)
        #expect(exits.value == 1)
    }

    private static func blockMainThread(until semaphore: DispatchSemaphore, seconds: Double) -> DispatchTimeoutResult {
        semaphore.wait(timeout: .now() + seconds)
    }

    /// `O_APPEND`: zwei Schreiber auf dieselbe Datei überschreiben sich nicht (vorher: Handle sprang einmal ans Ende).
    @Test func twoWritersBothKeepTheirLines() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = DiskIndexLog(directory: folder)
        let second = DiskIndexLog(directory: folder)
        first.record(.app, .info, "erste-a")
        first.flushPendingWritesForTesting()
        second.record(.app, .info, "zweite-b")
        second.flushPendingWritesForTesting()
        first.record(.app, .info, "erste-c")
        first.flushPendingWritesForTesting()
        let text = String(decoding: try Data(contentsOf: first.fileURL), as: UTF8.self)
        #expect(text.contains("erste-a"))
        #expect(text.contains("zweite-b"))
        #expect(text.contains("erste-c"))
    }
}

@MainActor
private final class FakeTerminationSignalSource: TerminationSignalSource {
    private var handler: (@MainActor () -> Void)?

    func start(onSignal: @escaping @MainActor () -> Void) {
        handler = onSignal
    }

    func cancel() {
        handler = nil
    }

    func fire() {
        handler?()
    }
}

@MainActor
private final class FinishFlag {
    var replies = 0
    var finishes = 0
}

/// Tor für einen hängenden Abschluss (öffnet erst, wenn der Test es sagt).
@MainActor
private final class FinishGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        pending.forEach { $0.resume() }
    }
}

/// Synchron blockierender Checkpoint-Hook (bug.0.3.9.011), Zustand je Test.
nonisolated private final class BlockingHook: @unchecked Sendable {
    private let lock = NSLock()
    private let gate = DispatchSemaphore(value: 0)
    private var blocking = false
    private var didEnter = false
    private var released = false

    var isBlocking: Bool { lock.withLock { blocking } }
    var entered: Bool { lock.withLock { didEnter } }

    func block(atMost seconds: Double) {
        lock.withLock {
            didEnter = true
            blocking = !released
        }
        guard isBlocking else { return }
        _ = gate.wait(timeout: .now() + seconds)
        lock.withLock { blocking = false }
    }

    func release() {
        let wasReleased = lock.withLock { () -> Bool in
            defer { released = true }
            return released
        }
        if !wasReleased { gate.signal() }
    }
}

nonisolated private final class ExitCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func add() { lock.withLock { count += 1 } }
}
