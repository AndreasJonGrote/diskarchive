//
//  ColumnCacheVisibleTests.swift
//  diskindexTests
//
//  bug.0.4.036 — Spalten-Cache verdrängt keine sichtbaren Spalten; `replaceStore` erhöht Generationen;
//  Auswahl wird nur beschnitten, wenn der Ordner geladen ist.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

@MainActor
private func visibleTree(otherFolders: Int) async throws -> (app: AppState, store: IndexStoreV3, medium: StoredMedium, alpha: UUID) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("diskindex-visible-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
    let app = AppState()
    app.attach(store: store)
    var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Sicht", decision: .index, indexStatus: .indexed, completedDepth: 3)
    try await store.upsertMedium(medium)
    medium = try #require(try await store.medium(uuid: medium.uuid))
    var entries = [ScannedEntry(name: "Alpha", isFolder: true)]
    entries += (0..<otherFolders).map { ScannedEntry(name: String(format: "F%02d", $0), isFolder: true) }
    try await store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: entries, seenAt: Date())
    let root = try await store.children(mediumUUID: medium.uuid, parentID: nil)
    let alphaRow = try #require(root.first { $0.name == "Alpha" })
    try await store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: alphaRow.id,
        entries: [ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1, modifiedAt: Date())],
        seenAt: Date()
    )
    await app.loadStoredMedia()
    let alphaID = IndexedItem.stableID(mediumID: medium.uuid, rowID: alphaRow.id)
    return (app, store, medium, alphaID)
}

@Suite(.serialized) @MainActor struct ColumnCacheVisibleTests {
    /// Wurzel offen, Ordner gewählt, danach 35 andere Ordner laden → Wurzel und offene Spalte bleiben im Cache,
    /// Auswahl und `pathStack` bleiben.
    @Test func visibleColumnsSurviveLoadingThirtyFiveOtherFolders() async throws {
        let tree = try await visibleTree(otherFolders: 35)
        let repo = tree.app.indexRepository
        let id = tree.medium.uuid
        tree.app.columnBrowserState.selectedMediumID = id
        tree.app.columnBrowserState.pathStack = ["Alpha"]
        var selection = ColumnSelection()
        selection.replace(id: tree.alpha, column: 0)
        tree.app.columnBrowserState.selection = selection
        _ = await repo.loadChildren(mediumID: id, path: [])
        _ = await repo.loadChildren(mediumID: id, path: ["Alpha"])

        for index in 0..<35 {
            _ = await repo.loadChildren(mediumID: id, path: [String(format: "F%02d", index)])
        }
        #expect(repo.hasCachedChildren(mediumID: id, path: []), "Wurzel verdrängt")
        #expect(repo.hasCachedChildren(mediumID: id, path: ["Alpha"]), "offene Spalte verdrängt")
        #expect(tree.app.columnBrowserState.pathStack == ["Alpha"])
        #expect(tree.app.columnBrowserState.selection.ids == [tree.alpha])
    }

    /// 98: Ein Load, der vor `replaceStore` begann, schreibt danach nichts mehr in den Cache.
    @Test func loadStartedBeforeReplaceStoreWritesNothing() async throws {
        let tree = try await visibleTree(otherFolders: 0)
        let repo = tree.app.indexRepository
        let id = tree.medium.uuid
        let gate = OneShotGate()
        repo.awaitMissingFolderCacheGateForTesting = { await gate.pause() }
        repo.requestLoad(mediumID: id, path: ["Fehlt"])
        let atGate = await waitUntil { await gate.isWaiting }
        try #require(atGate)

        let completedBefore = repo.loadSessionsCompletedForTesting
        repo.replaceStore(tree.store)
        await gate.open()
        // Positives Signal: der alte Load ist zu Ende gelaufen (sein `defer` zählt), erst dann die Negativprüfung.
        let settled = await waitUntil { repo.loadSessionsCompletedForTesting > completedBefore }
        #expect(settled)
        #expect(!repo.hasCachedChildren(mediumID: id, path: ["Fehlt"]), "alter Load schrieb nach replaceStore")
    }
}

extension WindowTestGroup {
@MainActor
@Suite
struct ColumnSelectionSurvivesInvalidateTests {
    /// `invalidateAll` während einer Auswahl → die Spalte ist kurz leer (nicht geladen), die Auswahl bleibt.
    @Test func selectionSurvivesInvalidateAll() async throws {
        let tree = try await visibleTree(otherFolders: 2)
        let id = tree.medium.uuid
        tree.app.mainWindowDestination = .columnBrowser
        tree.app.columnBrowserState.selectedMediumID = id
        var selection = ColumnSelection()
        selection.replace(id: tree.alpha, column: 0)
        tree.app.columnBrowserState.selection = selection
        let size = CGSize(width: 1280, height: 800)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(tree.app).frame(width: size.width, height: size.height),
            size: size
        )
        defer { session.close() }
        let loaded = await waitUntil { tree.app.indexRepository.hasLoadedChildren(mediumID: id, path: []) }
        try #require(loaded)
        await PixelProbe.settleOpenWindow(session)

        tree.app.indexRepository.invalidateAll()
        await PixelProbe.settleOpenWindow(session)
        let reloaded = await waitUntil { tree.app.indexRepository.hasLoadedChildren(mediumID: id, path: []) }
        #expect(reloaded)
        await PixelProbe.settleOpenWindow(session)
        #expect(tree.app.columnBrowserState.selection.ids == [tree.alpha], "Auswahl nach invalidateAll verloren")
    }
}
}

private actor OneShotGate {
    private var waiter: CheckedContinuation<Void, Never>?
    private var opened = false
    private(set) var isWaiting = false

    func pause() async {
        if opened { return }
        isWaiting = true
        await withCheckedContinuation { waiter = $0 }
    }

    func open() {
        opened = true
        waiter?.resume()
        waiter = nil
    }
}
