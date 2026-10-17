//
//  ColumnLiveRenameTests.swift
//  diskindexTests
//
//  Aufgabe 176 c — Spalte bleibt gefüllt während Live-Umbenennung.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@MainActor
private func columnRenameFixture() async throws -> (app: AppState, store: IndexStoreV3, medium: StoredMedium) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("diskindex-live-rename-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
    let store = IndexStoreV3(database: database)
    let app = AppState(store: store)
    app.startChangeLoop()
    var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Baum", decision: .index, indexStatus: .indexed, completedDepth: 3)
    try await store.upsertMedium(medium)
    medium = try #require(try await store.medium(uuid: medium.uuid))
    try await store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: nil,
        entries: [
            ScannedEntry(name: "Alpha", isFolder: true),
            ScannedEntry(name: "Beta", isFolder: true),
            ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 4),
        ],
        seenAt: Date()
    )
    let root = try await store.children(mediumUUID: medium.uuid, parentID: nil)
    let alpha = try #require(root.first { $0.name == "Alpha" })
    try await store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: alpha.id,
        entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1)],
        seenAt: Date()
    )
    await app.loadStoredMedia()
    return (app, store, medium)
}

extension WindowTestGroup {
@Suite @MainActor
struct ColumnLiveRenameTests {
    @Test func rootColumnNeverEmptiesDuringLiveRename() async throws {
        let tree = try await columnRenameFixture()
        tree.app.mainWindowDestination = .columnBrowser
        tree.app.columnBrowserState.selectedMediumID = tree.medium.uuid
        tree.app.columnBrowserState.pathStack = ["Alpha"]
        let size = CGSize(width: 1280, height: 800)
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(tree.app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        _ = await tree.app.indexRepository.loadChildren(mediumID: tree.medium.uuid, path: [])
        _ = await tree.app.indexRepository.loadChildren(mediumID: tree.medium.uuid, path: ["Alpha"])
        try await Task.sleep(for: .milliseconds(200))

        try await tree.store.applyDirectory(
            mediumUUID: tree.medium.uuid,
            parentID: nil,
            entries: [
                ScannedEntry(name: "Alpha", isFolder: true),
                ScannedEntry(name: "Beta", isFolder: true),
                ScannedEntry(name: "neu-name.txt", isFolder: false, sizeBytes: 2),
            ],
            seenAt: Date()
        )
        let generationBefore = tree.app.indexRepository.generation
        await tree.app.scheduleIndexChange(.items(tree.medium.uuid, folderPaths: [[]]), dropped: false)
        try await Task.sleep(for: .milliseconds(550))
        if tree.app.indexRepository.generation == generationBefore {
            tree.app.indexRepository.invalidate(mediumID: tree.medium.uuid, path: [])
        }

        let deadline = Date().addingTimeInterval(3)
        var sawNewName = false
        while Date() < deadline {
            tree.app.indexRepository.requestLoad(mediumID: tree.medium.uuid, path: [])
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            try await Task.sleep(for: .milliseconds(16))
            let bitmap = session.bitmap()
            #expect(firstRowHasInk(bitmap), "Wurzelspalte leer während Update")
            let names = tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: [])
            if names.map(\.name).contains("neu-name.txt") {
                sawNewName = true
                break
            }
            if !tree.app.indexRepository.isLoading(mediumID: tree.medium.uuid, path: []) {
                _ = await tree.app.indexRepository.loadChildren(mediumID: tree.medium.uuid, path: [])
                if tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: []).map(\.name).contains("neu-name.txt") {
                    sawNewName = true
                    break
                }
            }
            try await Task.sleep(for: .milliseconds(16))
        }
        #expect(sawNewName)
        #expect(!tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: []).map(\.name).contains("readme.txt"))
    }

    private func firstRowHasInk(_ bitmap: NSBitmapImageRep) -> Bool {
        let rowRect = CGRect(x: 210, y: 100, width: 150, height: 24)
        let background = CGPoint(x: 225, y: 112)
        return PixelProbe.inkBounds(in: bitmap, rect: rowRect, background: background) != nil
    }
}
}
