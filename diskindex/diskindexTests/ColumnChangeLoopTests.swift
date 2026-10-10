//
//  ColumnChangeLoopTests.swift
//  diskindexTests
//
//  Aufgabe 183 d — Change-Loop ohne Test-Nachhilfe.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct ColumnChangeLoopTests {
    @Test func rootColumnUpdatesAfterStoreApplyDirectoriesLikeWatcher() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-change-loop-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try IndexDatabase(fileURL: directory.appendingPathComponent("index.sqlite"))
        let store = IndexStore(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 100, name: "Stick", decision: .index, indexStatus: .indexed)
        try await store.upsertMedium(medium)
        medium = try #require(try await store.medium(uuid: medium.uuid))
        try await store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "X", isFolder: true)],
            seenAt: Date()
        )
        let folderX = try #require(try await store.folderID(mediumUUID: medium.uuid, path: ["X"]))
        try await store.applyDirectory(
            mediumUUID: medium.uuid,
            parentID: folderX,
            entries: [ScannedEntry(name: "inner.txt", isFolder: false, sizeBytes: 1)],
            seenAt: Date()
        )

        let app = AppState(store: store)
        app.startChangeLoop()
        await app.loadStoredMedia()
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = medium.uuid
        app.columnBrowserState.pathStack = ["X"]

        let size = CGSize(width: 1280, height: 800)
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        _ = await app.indexRepository.loadChildren(mediumID: medium.uuid, path: [])
        _ = await app.indexRepository.loadChildren(mediumID: medium.uuid, path: ["X"])

        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(nil, nil, nil, [ScannedEntry(name: "Y", isFolder: true)], true)],
            seenAt: Date()
        )
        try await Task.sleep(for: .milliseconds(300))
        let folderY = try #require(try await store.folderID(mediumUUID: medium.uuid, path: ["Y"]))
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(folderY, nil, nil, [ScannedEntry(name: "inner.txt", isFolder: false, sizeBytes: 1)], true)],
            seenAt: Date()
        )

        let rootShowsY = await waitUntil(timeout: 10) {
            let names = app.indexRepository.children(mediumID: medium.uuid, path: [])
            return names.map(\.name).contains("Y") && !names.map(\.name).contains("X")
        }
        #expect(rootShowsY)
        #expect(rootColumnHasInk(session))
    }

    private func rootColumnHasInk(_ session: PixelProbe.Session) -> Bool {
        session.window.contentView?.layoutSubtreeIfNeeded()
        session.window.display()
        let bitmap = session.bitmap()
        let sidebar = DesignSpacing.columnBrowserSidebarWidth
        let width = DesignSpacing.columnBrowserColumnWidth
        let background = CGPoint(x: 1260, y: 12)
        return PixelProbe.inkBounds(
            in: bitmap,
            rect: CGRect(x: sidebar + 8, y: 30, width: width - 24, height: 50),
            background: background
        ) != nil
    }
}
}
