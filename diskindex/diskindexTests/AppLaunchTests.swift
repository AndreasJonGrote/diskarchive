//
//  AppLaunchTests.swift
//  diskindexTests
//
//  todo.0.4.013 — Jeder Start öffnet Hauptfenster; Versions-Check sofort.
//

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

    @Test func schedulerEnqueuesVersionCheckImmediatelyOnStart() throws {
        VersionCheckCoordinator.lastVersionCheckEnqueue = nil
        let testStore = try TestStore.make()
        let countBefore = try testStore.store.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM api_queue WHERE kind = ?", arguments: [ApiQueueKind.versionCheck.rawValue]) ?? 0
        }
        #expect(countBefore == 0)
        let scheduler = VersionCheckScheduler()
        let appState = AppState()
        scheduler.start(appState: appState, store: testStore.store)
        defer { scheduler.stop() }
        let countAfter = try testStore.store.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM api_queue WHERE kind = ?", arguments: [ApiQueueKind.versionCheck.rawValue]) ?? 0
        }
        #expect(countAfter == 1)
    }
}
