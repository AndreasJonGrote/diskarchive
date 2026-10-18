//
//  AppLaunchTests.swift
//  diskindexTests
//
//  todo.0.4.013 — Jeder Start öffnet Hauptfenster; Versions-Check sofort.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite(.serialized)
@MainActor
struct AppLaunchTests {
    @Test func backgroundArgumentIsASilentLogin() {
        let kind = AppLaunch.kind(arguments: ["Disk Archive", "--background"], environment: [:])
        #expect(kind == .login)
        #expect(AppLaunch.opensMainWindow(kind))
    }

    @Test func launcherServiceNameIsASilentLogin() {
        let kind = AppLaunch.kind(
            arguments: ["Disk Archive"],
            environment: ["XPC_SERVICE_NAME": "app.diskarchive.launcher"]
        )
        #expect(kind == .login)
        #expect(AppLaunch.opensMainWindow(kind))
    }

    @Test func coldStartOpensMainWindow() {
        let kind = AppLaunch.kind(arguments: ["Disk Archive"], environment: [:])
        #expect(kind == .click)
        #expect(AppLaunch.opensMainWindow(kind))
        #expect(AppLaunch.opensMainWindow(.handoff))
        #expect(AppLaunch.opensMainWindow(.login))
    }

    /// Sabotage: `.click → false` → rot.
    @Test func sabotageClickMustOpenMainWindow() {
        #expect(AppLaunch.opensMainWindow(.click) == true)
    }

    /// Sabotage: `.login → false` → rot.
    @Test func sabotageLoginMustOpenMainWindow() {
        #expect(AppLaunch.opensMainWindow(.login) == true)
    }

    @Test func reopenWithoutAVisibleWindowOpensTheMainWindow() {
        #expect(AppLaunch.reopenOpensMainWindow(hasVisibleWindows: false))
        #expect(!AppLaunch.reopenOpensMainWindow(hasVisibleWindows: true))
    }

    @Test func openMainCreatesVisibleMainWindow() {
        let app = AppState()
        AppWindowPresenter.openMain(appState: app)
        #expect(AppWindowPresenter.isMainWindowVisible)
        AppWindowPresenter.prepareForTermination()
    }

    /// bug.0.4.074: `start` reiht über `enqueueCheckIfDue` ein (kein Abkühl-Zähler mehr, kein TaskLocal).
    @Test @MainActor func schedulerEnqueuesVersionCheckImmediatelyOnStart() async throws {
        let testStore = try TestStore.make()
        let countBefore = try await testStore.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM api_queue WHERE kind = ?", arguments: [ApiQueueKind.versionCheck.rawValue]) ?? 0
        }
        #expect(countBefore == 0)
        let scheduler = VersionCheckScheduler(wakeEvents: { AsyncStream { _ in } }, flush: {}, databaseWasNewThisLaunch: false)
        let appState = AppState()
        scheduler.start(appState: appState, store: testStore.store)
        defer { scheduler.stop() }
        // bug.0.3.8.007: genau 1 bleibt Absicht — `start` reiht genau einen Check sofort ein (kein doppelter),
        // der nächste kommt erst nach 24 h; die Zahl ist also deterministisch. Frist: Standard (10 s) statt 5 s.
        let enqueued = await waitUntil {
            let count = try? await testStore.pool.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM api_queue WHERE kind = ?", arguments: [ApiQueueKind.versionCheck.rawValue]) ?? 0
            }
            return count == 1
        }
        #expect(enqueued)
        #expect(try await testStore.pool.read(SystemSettingsPersistence.readLastVersionCheckAt) != nil)
    }
}
