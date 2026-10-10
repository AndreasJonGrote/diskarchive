//
//  AppLaunchTests.swift
//  diskindexTests
//

import Testing
@testable import diskindex

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

    @Test func coldStartDoesNotOpenWindowHandoffDoes() {
        let kind = AppLaunch.kind(arguments: ["Disk Archive"], environment: [:])
        #expect(kind == .click)
        #expect(!AppLaunch.opensMainWindow(kind))
        #expect(AppLaunch.opensMainWindow(.handoff))
    }

    @Test func reopenWithoutAVisibleWindowOpensTheMainWindow() {
        #expect(AppLaunch.reopenOpensMainWindow(hasVisibleWindows: false))
        #expect(!AppLaunch.reopenOpensMainWindow(hasVisibleWindows: true))
    }
}
