//
//  ColumnIdleTests.swift
//  diskindexTests
//
//  Aufgabe 186 d — Spalten ruhen bei offenem Fenster.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct ColumnIdleTests {
    @Test func openColumnsDoNotReloadDuringQuiet() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-idle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        defer { try? database.close(); try? FileManager.default.removeItem(at: directory) }

        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 100, name: "Stick", decision: .index, indexStatus: .indexed)
        try await store.upsertMedium(medium)
        medium = try #require(try await store.medium(uuid: medium.uuid))
        try await store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [ScannedEntry(name: "A", isFolder: true), ScannedEntry(name: "B", isFolder: true)],
            seenAt: Date()
        )
        let idA = try #require(try await store.folderID(mediumUUID: medium.uuid, path: ["A"]))
        try await store.applyDirectory(
            mediumUUID: medium.uuid, parentID: idA,
            entries: [ScannedEntry(name: "C", isFolder: true)],
            seenAt: Date()
        )

        let app = AppState(store: store)
        app.startChangeLoop()
        await app.loadStoredMedia()
        app.columnBrowserState.selectedMediumID = medium.uuid
        app.columnBrowserState.pathStack = ["A", "C"]

        let size = CGSize(width: 1280, height: 800)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        _ = await app.indexRepository.loadChildren(mediumID: medium.uuid, path: [])
        _ = await app.indexRepository.loadChildren(mediumID: medium.uuid, path: ["A"])
        _ = await app.indexRepository.loadChildren(mediumID: medium.uuid, path: ["A", "C"])

        try await Task.sleep(for: .seconds(2))
        IndexRepository.resetLoadSessionsCounterForTesting()
        IndexRepository.resetRequestLoadCounterForTesting()
        let loadsAtMark = IndexRepository.loadSessionsStartedForTesting
        let requestsAtMark = IndexRepository.requestLoadCallsForTesting
        let generationAtMark = app.indexRepository.generation

        try await Task.sleep(for: .seconds(5))
        #expect(IndexRepository.loadSessionsStartedForTesting == loadsAtMark)
        #expect(IndexRepository.requestLoadCallsForTesting == requestsAtMark)
        #expect(app.indexRepository.generation == generationAtMark)
    }
}
}
