//
//  SelectionMovedAwayTests.swift
//  diskindexTests
//
//  bug.0.4.214 — Ausgewähltes Objekt von außen verschoben oder gelöscht (Konzept `suche-navigation.md`, „Live-Änderung an
//  der Auswahl“): Auswahl weg, die Ansicht bleibt im bisherigen Ordner, Spalten rechts davon schließen. Umbenennen am
//  selben Ort behält die Auswahl. Regel 18: echte Dateien, dann nur der Änderungsweg der Überwachung
//  (`applyLiveRename` bzw. `applyDirectory`), dann warten und lesen. Spaltenansicht im Fenster außerhalb des Bildschirms.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct SelectionMovedAwayTests {
    @MainActor
    private struct Tree {
        let mount: URL
        let app: AppState
        let store: IndexStoreV3
        let mediumID: UUID
        let session: PixelProbe.Session

        func items(_ path: [String]) -> [IndexedItem] {
            app.indexRepository.children(mediumID: mediumID, path: path)
        }

        func url(_ relative: String) -> URL { mount.appendingPathComponent(relative) }

        var state: ColumnBrowserState { app.columnBrowserState }

        /// Wie ein Klick auf die Zeile (Nutzeraktion).
        func select(_ name: String, in path: [String]) throws {
            let items = items(path)
            let item = try #require(items.first { $0.name == name }, "\(name) fehlt in \(path)")
            let medium = try #require(app.media.first { $0.id == mediumID })
            app.commitColumnSelection(
                ColumnSelection(ids: [item.id], anchorID: item.id, focusColumnIndex: path.count, lastClickedID: item.id),
                items: items, columnIndex: path.count, medium: medium
            )
        }

        /// Wie die Überwachung bei einem Verschieben oder Umbenennen (Paar alt → neu).
        func liveMove(_ from: String, _ to: String) async throws {
            try FileManager.default.moveItem(at: url(from), to: url(to))
            let applied = try await store.applyLiveRename(
                mediumUUID: mediumID, mountPath: mount.path, fromPath: url(from).path, toPath: url(to).path
            )
            try #require(applied, "Verschieben nicht angewendet")
        }

        func close() {
            session.close()
            app.prepareForTermination()
            try? FileManager.default.removeItem(at: mount.deletingLastPathComponent())
        }
    }

    /// Wurzel: Alpha/ (a.txt, b.txt, Sub/ mit s.txt), Beta/. Spaltenansicht offen, „Alpha“ geöffnet.
    private static func tree() async throws -> Tree {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-moved-away-\(UUID().uuidString)", isDirectory: true)
        let mount = base.appendingPathComponent("BAUM", isDirectory: true)
        for folder in ["Alpha/Sub", "Beta"] {
            try FileManager.default.createDirectory(at: mount.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        for file in ["Alpha/a.txt", "Alpha/b.txt", "Alpha/Sub/s.txt"] {
            try Data("x".utf8).write(to: mount.appendingPathComponent(file))
        }
        let store = IndexStoreV3(database: try TestDatabase(fileURL: base.appendingPathComponent("archive.sqlite")))
        let app = AppState(store: store)
        app.startChangeLoop()
        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Baum", decision: .index, indexStatus: .indexed, completedDepth: 5)
        try await store.upsertMedium(medium)
        medium = try #require(try await store.medium(uuid: medium.uuid))
        try await store.applyDirectory(
            mediumUUID: medium.uuid, parentID: nil,
            entries: [ScannedEntry(name: "Alpha", isFolder: true), ScannedEntry(name: "Beta", isFolder: true)],
            seenAt: Date()
        )
        let root = try await store.children(mediumUUID: medium.uuid, parentID: nil)
        let alpha = try #require(root.first { $0.name == "Alpha" })
        try await store.applyDirectory(
            mediumUUID: medium.uuid, parentID: alpha.id,
            entries: [
                ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1),
                ScannedEntry(name: "b.txt", isFolder: false, sizeBytes: 1),
                ScannedEntry(name: "Sub", isFolder: true),
            ],
            seenAt: Date()
        )
        let sub = try #require(try await store.children(mediumUUID: medium.uuid, parentID: alpha.id).first { $0.name == "Sub" })
        try await store.applyDirectory(
            mediumUUID: medium.uuid, parentID: sub.id,
            entries: [ScannedEntry(name: "s.txt", isFolder: false, sizeBytes: 1)], seenAt: Date()
        )
        let beta = try #require(root.first { $0.name == "Beta" })
        try await store.applyDirectory(mediumUUID: medium.uuid, parentID: beta.id, entries: [], seenAt: Date())
        await app.loadStoredMedia()
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = medium.uuid
        let size = CGSize(width: 1400, height: 700)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size
        )
        let tree = Tree(mount: mount, app: app, store: store, mediumID: medium.uuid, session: session)
        try #require(await waitUntil { tree.items([]).contains { $0.name == "Alpha" } }, "Wurzel nicht geladen")
        try tree.select("Alpha", in: [])
        try #require(await waitUntil { tree.items(["Alpha"]).contains { $0.name == "a.txt" } }, "Alpha nicht geladen")
        return tree
    }

    /// Datei in „Alpha“ gewählt, live nach „Beta“ verschoben → „Alpha“ bleibt offen, nichts gewählt, keine Details.
    @Test func movedFileLosesTheSelectionAndTheViewStays() async throws {
        let tree = try await Self.tree()
        defer { tree.close() }
        try tree.select("a.txt", in: ["Alpha"])
        let file = try #require(tree.state.selection.ids.first)
        try await tree.liveMove("Alpha/a.txt", "Beta/a.txt")
        try #require(await waitUntil { !tree.items(["Alpha"]).contains { $0.name == "a.txt" } }, "Spalte nicht neu gelesen")
        let dropped = await waitUntil { !tree.state.selection.ids.contains(file) }
        #expect(dropped, "verschobene Datei bleibt ausgewählt: \(tree.state.selection.ids)")
        try await Task.sleep(for: .milliseconds(300))
        #expect(tree.state.pathStack == ["Alpha"], "Ansicht folgt dem Objekt: \(tree.state.pathStack)")
        #expect(tree.state.selection.ids.isEmpty || tree.state.selection.focusColumnIndex == 0,
                "in „Alpha“ ist noch etwas gewählt: \(tree.state.selection)")
    }

    /// Geöffneter Unterordner „Alpha/Sub“ live nach „Beta“ verschoben → Pfad endet bei „Alpha“, „Alpha“ bleibt offen.
    @Test func movedOpenFolderEndsThePathAtItsOldParent() async throws {
        let tree = try await Self.tree()
        defer { tree.close() }
        try tree.select("Sub", in: ["Alpha"])
        let sub = try #require(tree.state.selection.ids.first)
        try #require(tree.state.pathStack == ["Alpha", "Sub"], "Gegenprobe: Sub nicht geöffnet")
        try #require(await waitUntil { tree.items(["Alpha", "Sub"]).contains { $0.name == "s.txt" } }, "Sub nicht geladen")
        try await tree.liveMove("Alpha/Sub", "Beta/Sub")
        let ended = await waitUntil { tree.state.pathStack == ["Alpha"] }
        #expect(ended, "Pfad endet nicht bei „Alpha“: \(tree.state.pathStack)")
        try await Task.sleep(for: .milliseconds(300))
        #expect(tree.state.pathStack == ["Alpha"], "Ansicht folgt dem Ordner: \(tree.state.pathStack)")
        #expect(!tree.state.selection.ids.contains(sub), "verschobener Ordner bleibt ausgewählt")
    }

    /// Gegenprobe: Umbenennen am selben Ort behält Auswahl und Pfad.
    @Test func renameInPlaceKeepsTheSelection() async throws {
        let tree = try await Self.tree()
        defer { tree.close() }
        try tree.select("a.txt", in: ["Alpha"])
        let file = try #require(tree.state.selection.ids.first)
        try await tree.liveMove("Alpha/a.txt", "Alpha/c.txt")
        try #require(await waitUntil { tree.items(["Alpha"]).contains { $0.name == "c.txt" } }, "Umbenennen nicht in der Spalte")
        try await Task.sleep(for: .milliseconds(300))
        #expect(tree.state.selection.ids == [file], "Umbenennen am selben Ort verliert die Auswahl")
        #expect(tree.state.pathStack == ["Alpha"])
    }

    /// Gegenprobe: Umbenennen des geöffneten Ordners am selben Ort – der Pfad folgt dem neuen Namen, Auswahl bleibt.
    @Test func renameOpenFolderInPlaceKeepsThePath() async throws {
        let tree = try await Self.tree()
        defer { tree.close() }
        try tree.select("Sub", in: ["Alpha"])
        let sub = try #require(tree.state.selection.ids.first)
        try #require(await waitUntil { tree.items(["Alpha", "Sub"]).contains { $0.name == "s.txt" } }, "Sub nicht geladen")
        try await tree.liveMove("Alpha/Sub", "Alpha/Neu")
        let followed = await waitUntil { tree.state.pathStack == ["Alpha", "Neu"] }
        #expect(followed, "Pfad folgt dem Umbenennen nicht: \(tree.state.pathStack)")
        #expect(tree.state.selection.ids == [sub])
    }

    /// Löschen wirkt wie Verschieben.
    @Test func deletedFileLosesTheSelection() async throws {
        let tree = try await Self.tree()
        defer { tree.close() }
        try tree.select("a.txt", in: ["Alpha"])
        let file = try #require(tree.state.selection.ids.first)
        try FileManager.default.removeItem(at: tree.url("Alpha/a.txt"))
        let alpha = try #require(try await tree.store.children(mediumUUID: tree.mediumID, parentID: nil).first { $0.name == "Alpha" })
        try await tree.store.applyDirectory(
            mediumUUID: tree.mediumID, parentID: alpha.id,
            entries: [ScannedEntry(name: "b.txt", isFolder: false, sizeBytes: 1), ScannedEntry(name: "Sub", isFolder: true)],
            seenAt: Date()
        )
        let dropped = await waitUntil { !tree.state.selection.ids.contains(file) }
        #expect(dropped, "gelöschte Datei bleibt ausgewählt")
        #expect(tree.state.pathStack == ["Alpha"])
    }
}
}
