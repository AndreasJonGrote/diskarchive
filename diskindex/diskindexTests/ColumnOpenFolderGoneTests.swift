//
//  ColumnOpenFolderGoneTests.swift
//  diskindexTests
//
//  bug.0.4.131: Gelöschter oder umbenannter offener Ordner. Löschen → `pathStack` ab dieser Ebene gekürzt, Auswahl auf
//  den Elternordner; Umbenennung → Pfad folgt dem neuen Namen, Auswahl bleibt. Regel 18: nur die Store-Änderung über
//  den echten Änderungsweg (`applyDirectory` bzw. `applyLiveRename` wie die Überwachung), dann warten und lesen.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

@MainActor
private func openFolderFixture(mount: URL) async throws -> (app: AppState, store: IndexStoreV3, medium: StoredMedium) {
    let database = try TestDatabase(fileURL: mount.deletingLastPathComponent().appendingPathComponent("archive.sqlite"))
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
            ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 4),
        ],
        seenAt: Date()
    )
    let alpha = try #require(try await store.children(mediumUUID: medium.uuid, parentID: nil).first { $0.name == "Alpha" })
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
@Suite(.serialized) @MainActor
struct ColumnOpenFolderGoneTests {
    private static let size = CGSize(width: 1280, height: 800)

    private func makeMount() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-open-gone-\(UUID().uuidString)", isDirectory: true)
        let mount = base.appendingPathComponent("BAUM", isDirectory: true)
        try FileManager.default.createDirectory(at: mount.appendingPathComponent("Alpha"), withIntermediateDirectories: true)
        return mount
    }

    private func openAlpha(_ tree: (app: AppState, store: IndexStoreV3, medium: StoredMedium)) async throws -> PixelProbe.Session {
        tree.app.mainWindowDestination = .columnBrowser
        tree.app.columnBrowserState.selectedMediumID = tree.medium.uuid
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(tree.app)
                .environment(\.colorScheme, .light)
                .frame(width: Self.size.width, height: Self.size.height),
            size: Self.size
        )
        let rootLoaded = await waitUntil {
            tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: []).contains { $0.name == "Alpha" }
        }
        try #require(rootLoaded)
        let alpha = try #require(tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: []).first { $0.name == "Alpha" })
        var state = tree.app.columnBrowserState
        state.pathStack = ["Alpha"]
        state.selection = ColumnSelection(ids: [alpha.id], anchorID: alpha.id, focusColumnIndex: 0, lastClickedID: alpha.id)
        tree.app.columnBrowserState = state
        let alphaLoaded = await waitUntil {
            tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: ["Alpha"]).contains { $0.name == "a.txt" }
        }
        try #require(alphaLoaded)
        return session
    }

    @Test func deletedOpenFolderTruncatesThePath() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        let session = try await openAlpha(tree)
        defer { session.close() }
        // Wie die Überwachung: Wurzel neu gelesen, „Alpha“ fehlt.
        try await tree.store.applyDirectory(
            mediumUUID: tree.medium.uuid,
            parentID: nil,
            entries: [ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 4)],
            seenAt: Date()
        )
        let truncated = await waitUntil { tree.app.columnBrowserState.pathStack.isEmpty }
        #expect(truncated, "pathStack: \(tree.app.columnBrowserState.pathStack)")
        #expect(tree.app.columnBrowserState.selection.ids.isEmpty)
    }

    @Test func renamedOpenFolderFollowsTheNewName() async throws {
        let mount = try makeMount()
        let tree = try await openFolderFixture(mount: mount)
        let session = try await openAlpha(tree)
        defer { session.close() }
        let selected = tree.app.columnBrowserState.selection.ids
        try FileManager.default.moveItem(at: mount.appendingPathComponent("Alpha"), to: mount.appendingPathComponent("Beta"))
        // Wie die Überwachung bei einem Umbenennen-Paar.
        let applied = try await tree.store.applyLiveRename(
            mediumUUID: tree.medium.uuid,
            mountPath: mount.path,
            fromPath: mount.appendingPathComponent("Alpha").path,
            toPath: mount.appendingPathComponent("Beta").path
        )
        try #require(applied, "Umbenennen nicht angewendet")
        let followed = await waitUntil { tree.app.columnBrowserState.pathStack == ["Beta"] }
        #expect(followed, "pathStack: \(tree.app.columnBrowserState.pathStack)")
        #expect(tree.app.columnBrowserState.selection.ids == selected, "Auswahl verloren")
        let contents = await waitUntil {
            tree.app.indexRepository.children(mediumID: tree.medium.uuid, path: ["Beta"]).contains { $0.name == "a.txt" }
        }
        #expect(contents, "Spalte „Beta“ zeigt den Inhalt nicht")
    }
}
}
