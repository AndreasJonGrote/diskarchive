//
//  AppLaunchTests.swift
//  diskindexTests
//
//  todo.0.4.011 — Kaltstart öffnet Hauptfenster; Anmeldung nur bei Update/Sperre.
//

import Testing
@testable import diskindex

@Suite(.serialized)
@MainActor
struct AppLaunchTests {
    @Test func backgroundArgumentIsASilentLogin() {
        let kind = AppLaunch.kind(arguments: ["Disk Archive", "--background"], environment: [:])
        #expect(kind == .login)
        #expect(!AppLaunch.opensMainWindow(kind))
    }

    @Test func launcherServiceNameIsASilentLogin() {
        let kind = AppLaunch.kind(
            arguments: ["Disk Archive"],
            environment: ["XPC_SERVICE_NAME": "app.diskarchive.launcher"]
        )
        #expect(kind == .login)
        #expect(!AppLaunch.opensMainWindow(kind))
    }

    @Test func coldStartOpensMainWindow() {
        let kind = AppLaunch.kind(arguments: ["Disk Archive"], environment: [:])
        #expect(kind == .click)
        #expect(AppLaunch.opensMainWindow(kind))
        #expect(AppLaunch.opensMainWindow(.handoff))
    }

    /// Sabotage: `.click → false` → rot.
    @Test func sabotageClickMustOpenMainWindow() {
        #expect(AppLaunch.opensMainWindow(.click) == true)
    }

    @Test func loginOpensOnlyWithUpdateOrLock() {
        #expect(!AppLaunch.opensMainWindow(.login, presentsUpdateOrLock: false))
        #expect(AppLaunch.opensMainWindow(.login, presentsUpdateOrLock: true))
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
}
