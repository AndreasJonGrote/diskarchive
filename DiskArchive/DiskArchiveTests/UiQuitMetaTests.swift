//
//  UiQuitMetaTests.swift
//  DiskArchiveTests
//
//  c.0.3.2.007 — Spalten-Reset beim Tab-Wechsel (REPORT 23).
//

import Foundation
import Testing
@testable import DiskArchive

@Suite @MainActor struct UiQuitMetaTests {
    @Test func leavingColumnBrowserClearsNavigationState() {
        let app = AppState()
        let mediumID = testUUID("D0070001-0000-4000-8000-000000000007")
        let sidebar = app.columnBrowserState.sidebarWidth
        let column = app.columnBrowserState.folderColumnWidth(at: 0)
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = mediumID
        app.columnBrowserState.pathStack = ["A", "B"]
        app.columnBrowserState.selectedUncapturedFolderID = UUID()
        app.mainWindowDestination = .dashboard
        app.mainWindowDestination = .columnBrowser
        #expect(app.columnBrowserState.selectedMediumID == nil)
        #expect(app.columnBrowserState.pathStack.isEmpty)
        #expect(app.columnBrowserState.selectedUncapturedFolderID == nil)
        #expect(app.columnBrowserState.sidebarWidth == sidebar)
        #expect(app.columnBrowserState.folderColumnWidth(at: 0) == column)
    }
}
