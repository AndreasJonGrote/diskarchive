//
//  ReplaceMediumFavoritesTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.012 (Layout 02.03): „Altes vergessen“ entfernt das alte Medium mit Index und Favoriten; „Behalten“ führt
//  beide getrennt weiter. Ohne Coordinator geht „Altes vergessen“ über den Vergessen-Weg von `AppState`.
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

@MainActor
struct ReplaceMediumFavoritesTests {
    /// Altes Medium (offline) mit indizierter Datei als Favorit, neues gleichen Namens.
    private static func rig() async throws -> (AppState, IndexStoreV3, old: UUID, new: UUID) {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        access.file("Projekt/a.txt")
        _ = try await harness.run(access: access, maxDepth: nil)
        let itemID = try #require(try await harness.store.pool.read { db in
            try Int64.fetchOne(db, sql: "SELECT id FROM items WHERE name = 'a.txt'")
        })
        try await harness.store.setFavorite(itemID: itemID, true)
        let fresh = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "TEST", type: .usb, decision: .undecided)
        try await harness.store.upsertMedium(fresh)
        let app = AppState(store: harness.store)
        await app.loadStoredMedia()
        app.updateMedium(id: fresh.uuid) { $0.connectionStatus = .connected }
        return (app, harness.store, harness.mediumID, fresh.uuid)
    }

    @Test func forgetOldRemovesItsIndexAndFavorites() async throws {
        let (app, store, old, new) = try await Self.rig()
        try #require(try await store.favoriteItemIDs().count == 1, "Voraussetzung: ein Favorit am alten Medium")
        #expect(app.offerReplaceMediumPrompt(newID: new), "keine Rückfrage bei bekanntem, nicht angeschlossenem Namen")
        app.resolveReplaceMediumPrompt(forgetOld: true)
        let gone = await waitUntil { (try? await store.medium(uuid: old)) == nil }
        #expect(gone, "altes Medium nicht vergessen")
        #expect(await waitUntil { (try? await store.favoriteItemIDs())?.isEmpty == true }, "Favorit des alten Mediums blieb")
        let stillNew = try await store.medium(uuid: new)
        #expect(app.medium(with: new) != nil && stillNew != nil, "neues Medium mit vergessen")
    }

    @Test func keepLeavesBothMediaAndTheFavorite() async throws {
        let (app, store, old, new) = try await Self.rig()
        #expect(app.offerReplaceMediumPrompt(newID: new))
        app.resolveReplaceMediumPrompt(forgetOld: false)
        try await Task.sleep(for: .milliseconds(200))
        #expect(app.medium(with: old) != nil && app.medium(with: new) != nil)
        let favorites = try await store.favoriteItemIDs()
        #expect(favorites.count == 1)
    }

    /// Nur bei bekanntem, **nicht angeschlossenem** Namen; ein angeschlossenes gleichnamiges Medium fragt nicht.
    @Test func noPromptWhenTheNamesakeIsConnected() async throws {
        let (app, _, old, new) = try await Self.rig()
        app.updateMedium(id: old) { $0.connectionStatus = .connected }
        #expect(!app.offerReplaceMediumPrompt(newID: new))
        #expect(app.replaceMediumPrompt == nil)
    }
}
