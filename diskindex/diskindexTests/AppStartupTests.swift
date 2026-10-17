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
    @Test func handedOffTerminationTearsNothingDown() {
        var teardowns = 0
        var finishes = 0
        let reply = AppStartup.shouldTerminate(handedOff: true, teardown: { teardowns += 1 }, finish: { finishes += 1 })
        #expect(reply == .terminateNow)
        #expect(teardowns == 0)
        #expect(finishes == 0)
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
        var replies: [NSApplication.TerminateReply] = []
        var teardowns = 0
        let finished = FinishFlag()
        // Wie in der App: SIGTERM → terminate → `applicationShouldTerminate` → `AppStartup.shouldTerminate`.
        TerminationSignal.install(source) {
            replies.append(AppStartup.shouldTerminate(
                handedOff: false,
                teardown: { teardowns += 1 },
                finish: {
                    await AppStartup.finishTermination(appState: app, log: log)
                    finished.done = true
                }
            ))
        }
        let checkpointsBefore = harness.store.checkpointCalls.value
        source.fire()
        let done = await waitUntil { finished.done }
        #expect(done)
        #expect(replies == [.terminateLater])
        #expect(teardowns == 1)
        #expect(harness.store.checkpointCalls.value > checkpointsBefore)
        log.flushPendingWritesForTesting()
        let text = String(decoding: try Data(contentsOf: log.fileURL), as: UTF8.self)
        #expect(text.contains("app terminate ok"))
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
    var done = false
}
