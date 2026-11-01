//
//  MediumCustomNameTests.swift
//  DiskArchiveTests
//
//  todo.0.4.2.002 (Konzept `medien.md`, Layout ab 0.4.2 „Eigener Name“, Kachel „Lauras Platte“): Ein eigener Name
//  steht als Schlüssel `customName` in `storage_meta` (Schema unverändert). `name` bleibt der Originalname vom System;
//  Anzeige und Suche nehmen den eigenen Namen, die Suche findet auch den Originalnamen.
//

import AppKit
import Foundation
import GRDB
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@MainActor
@Suite(.serialized)
struct MediumCustomNameTests {
    private struct Rig {
        let directory: URL
        let store: IndexStoreV3
        let mediumID: UUID
        let otherID: UUID

        func close() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private static func makeRig() async throws -> Rig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-custom-name-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let studio = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Studio Backup", decision: .index, indexStatus: .indexed, completedDepth: 1)
        let archiv = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Archiv", decision: .index, indexStatus: .indexed, completedDepth: 1)
        try await store.upsertMedium(studio)
        try await store.upsertMedium(archiv)
        return Rig(directory: directory, store: store, mediumID: studio.uuid, otherID: archiv.uuid)
    }

    /// Wert des Schlüssels `customName` (`nil` = Zeile fehlt) und die Spalten `name`, `slug` aus `storages`.
    private static func stored(_ rig: Rig) async throws -> (custom: String?, rows: Int, name: String, slug: String) {
        let uuid = rig.mediumID
        return try await rig.store.pool.read { db in
            let storageID = try #require(try MediumCodecV3.storageRowID(db, uuid: uuid))
            let rows = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM storage_meta m JOIN meta_keys k ON k.id = m.keyID WHERE m.storageID = ? AND k.key = 'customName'",
                arguments: [storageID]
            ) ?? -1
            let row = try #require(try Row.fetchOne(db, sql: "SELECT name, slug FROM storages WHERE id = ?", arguments: [storageID]))
            return (try MediumCodecV3.metaValue(db, storageID, .customName), rows, row["name"], row["slug"])
        }
    }

    private static func schema(_ store: IndexStoreV3) async throws -> [String] {
        try await store.pool.read { db in
            try String.fetchAll(db, sql: "SELECT type || ' ' || name || ' ' || COALESCE(sql, '') FROM sqlite_master ORDER BY name")
        }
    }

    private static func app(_ rig: Rig) async -> AppState {
        let app = AppState(store: rig.store)
        await app.loadStoredMedia()
        return app
    }

    // 1. Datenbank: Schlüssel in `storage_meta`, `storages` und Schema unverändert; leer oder Originalname → weg.
    @Test func customNameIsAMetaKeyAndEmptyOrOriginalRemovesIt() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let schemaBefore = try await Self.schema(rig.store)

        try await rig.store.setCustomName(mediumUUID: rig.mediumID, input: "  Lauras Platte ")
        var now = try await Self.stored(rig)
        #expect(now.custom == "Lauras Platte" && now.rows == 1, "Schlüssel \(String(describing: now.custom)), Zeilen \(now.rows)")
        #expect(now.name == "Studio Backup" && now.slug == Slug.make("Studio Backup"), "storages geändert: \(now.name), \(now.slug)")
        #expect(try await Self.schema(rig.store) == schemaBefore, "Schema geändert")

        try await rig.store.setCustomName(mediumUUID: rig.mediumID, input: "   ")
        now = try await Self.stored(rig)
        #expect(now.rows == 0, "leerer Name gespeichert (\(String(describing: now.custom)))")

        try await rig.store.setCustomName(mediumUUID: rig.mediumID, input: "Lauras Platte")
        try await rig.store.setCustomName(mediumUUID: rig.mediumID, input: "Studio Backup")
        now = try await Self.stored(rig)
        #expect(now.rows == 0, "Originalname als eigener Name gespeichert (\(String(describing: now.custom)))")

        try await rig.store.setCustomName(mediumUUID: rig.mediumID, input: String(repeating: "x", count: 150))
        now = try await Self.stored(rig)
        #expect(now.custom?.count == Medium.customNameMaxLength, "Länge \(now.custom?.count ?? 0)")
        #expect(try await Self.schema(rig.store) == schemaBefore, "Schema geändert")
    }

    // 2. Neu laden: eigener Name bleibt; 3. Umbenennen im Finder ändert nur den Originalnamen.
    @Test func customNameSurvivesReloadAndRename() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let first = await Self.app(rig)
        first.setCustomName(mediumID: rig.mediumID, input: "Lauras Platte")
        #expect(first.medium(with: rig.mediumID)?.shownName == "Lauras Platte", "nicht sofort sichtbar")
        try #require(await waitUntil { (try? await Self.stored(rig).custom) == "Lauras Platte" }, "nicht gespeichert")

        let reloaded = await Self.app(rig)
        let medium = try #require(reloaded.medium(with: rig.mediumID))
        #expect(medium.customName == "Lauras Platte" && medium.name == "Studio Backup")
        #expect(reloaded.indexedMedia.map(\.shownName) == ["Archiv", "Lauras Platte"], "Reihenfolge \(reloaded.indexedMedia.map(\.shownName))")

        var renamed = try #require(try await rig.store.medium(uuid: rig.mediumID))
        renamed.name = "Studio Neu"
        try await rig.store.updateMediumRecognition(uuid: rig.mediumID, renamed)
        let after = await Self.app(rig)
        let shown = try #require(after.medium(with: rig.mediumID))
        #expect(shown.customName == "Lauras Platte", "eigener Name nach Umbenennen weg")
        #expect(shown.name == "Studio Neu", "Originalname nicht nachgeführt")
        #expect(try await Self.stored(rig).slug == Slug.make("Studio Neu"))
    }

    // 4. Ansicht im echten Fenster: Kachel mit zwei Zeilen; Seitenleiste mit dem eigenen Namen.
    @Test func cardShowsTwoLinesAndSidebarTheCustomName() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = await Self.app(rig)
        let plain = try #require(app.medium(with: rig.mediumID))
        var named = plain
        named.customName = "Lauras Platte"

        func cardHeight(_ medium: Medium) -> CGFloat {
            let host = NSHostingView(rootView: MediumDashboardCard(medium: medium).environment(app).frame(width: 240))
            let window = PixelProbe.offscreenWindow(hosting: host, size: CGSize(width: 240, height: 300))
            defer { window.orderOut(nil); window.contentView = nil; window.close() }
            host.layoutSubtreeIfNeeded()
            return host.fittingSize.height
        }
        let one = cardHeight(plain)
        let two = cardHeight(named)
        #expect(two >= one + 12, "Kachel mit eigenem Namen \(two) pt, ohne \(one) pt – zweite Zeile fehlt")

        // Seitenleiste und Spaltenkopf: „Lauras Platte“ (Original „Studio Backup“) sieht aus wie ein Medium, das so heißt.
        let size = CGSize(width: 900, height: 360)
        func sidebarImage(_ media: [Medium]) async -> Data? {
            let state = AppState()
            state.media = media
            state.mainWindowDestination = .columnBrowser
            state.columnBrowserState.selectedMediumID = media.first?.id
            let view = ColumnBrowserView().environment(state).environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height)
            return await PixelProbe.render(view, size: size).representation(using: .png, properties: [:])
        }
        var original = plain
        original.name = "Lauras Platte"
        let withCustom = try #require(await sidebarImage([named]))
        let withOriginal = try #require(await sidebarImage([original]))
        #expect(withCustom == withOriginal, "Seitenleiste zeigt nicht den eigenen Namen")
    }

    // 5. Suche: Medien-Kacheln über eigenen und Originalnamen.
    @Test func searchFindsCustomAndOriginalName() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = await Self.app(rig)
        app.setCustomName(mediumID: rig.mediumID, input: "Lauras Platte")
        let media = app.indexedMedia
        for query in ["Laura", "lauras platte", "Studio", "backup"] {
            let match = await SearchIndex.matching(store: nil, query: query, filters: SearchFilters(), media: media, maxDepth: nil)
            #expect(match.media.map(\.id) == [rig.mediumID], "„\(query)“: \(match.media.map(\.shownName))")
            let popover = await SearchIndex.popoverPage(store: nil, query: query, filters: SearchFilters(), media: media, maxDepth: nil, perGroup: 5)
            #expect(popover.media.map(\.id) == [rig.mediumID], "Popover „\(query)“: \(popover.media.map(\.shownName))")
        }
        let none = await SearchIndex.matching(store: nil, query: "Platten", filters: SearchFilters(), media: media, maxDepth: nil)
        #expect(none.media.isEmpty)
    }

    // 9. Vergessen entfernt den eigenen Namen mit.
    @Test func forgettingRemovesTheCustomName() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        try await rig.store.setCustomName(mediumUUID: rig.mediumID, input: "Lauras Platte")
        try await rig.store.deleteMedium(uuid: rig.mediumID)
        let left = try await rig.store.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM storage_meta m JOIN meta_keys k ON k.id = m.keyID WHERE k.key = 'customName'") ?? -1
        }
        #expect(left == 0, "eigener Name nach dem Vergessen noch da (\(left))")
    }
}
}
