//
//  FavoritesPagingTests.swift
//  diskindexTests
//
//  bug.0.4.040 (REPORT 86): Favoriten-Tabelle lazy und seitenweise (500 + Zählung), Filter in der Abfrage,
//  Zeilen ohne Beobachtung von `media` (ein Fortschritts-Tick baut sie nicht neu).
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@MainActor
private struct FavoritesRig {
    let rig: SurfaceRig
    let medium: StoredMedium

    var app: AppState { rig.app }
    var store: IndexStoreV3 { rig.store }

    /// Ein Medium mit `names` als Dateien in der Wurzel, alle als Favorit markiert.
    static func make(names: [String], mediumName: String = "Favoriten") async throws -> FavoritesRig {
        let rig = try await SurfaceRig.make()
        let medium = try await addMedium(rig, name: mediumName, files: names)
        rig.app.attach(store: rig.store)
        await rig.app.loadStoredMedia()
        return FavoritesRig(rig: rig, medium: medium)
    }

    @discardableResult
    static func addMedium(_ rig: SurfaceRig, name: String, files: [String]) async throws -> StoredMedium {
        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: name, decision: .index, indexStatus: .indexed, completedDepth: 3)
        try await rig.store.upsertMedium(medium)
        medium = try #require(try await rig.store.medium(uuid: medium.uuid))
        let entries = files.map { ScannedEntry(name: $0, isFolder: false, sizeBytes: 1, modifiedAt: Date()) }
        try await rig.store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: entries, seenAt: Date())
        let rows = try await rig.store.children(mediumUUID: medium.uuid, parentID: nil)
        try await rig.store.setFavorites(itemIDs: rows.map(\.id), true)
        return medium
    }
}

extension MeasurementTestGroup {
@Suite(.serialized) @MainActor
struct FavoritesPagingTests {
    @Test func pageHoldsAtMost500AndTheCountIsComplete() async throws {
        let names = (0..<600).map { String(format: "rechnung-%04d.pdf", $0) }
        let rig = try await FavoritesRig.make(names: names)
        await rig.app.reloadFavorites()
        #expect(rig.app.favoriteObjects.count == SearchIndex.pageLimit)
        #expect(rig.app.favoriteItemCount == 600)
        #expect(rig.app.favoriteUnfilteredCount == 600)
        #expect(rig.app.favoriteRowIDs?.count == 600, "Kennungen vollständig, nicht nur die Seite")
    }

    @Test func connectionFilterWorksBeyondTheFirstPage() async throws {
        let names = (0..<600).map { String(format: "aaa-%04d.pdf", $0) }
        let rig = try await FavoritesRig.make(names: names)
        let online = try await FavoritesRig.addMedium(rig.rig, name: "Online", files: ["zzz.pdf"])
        await rig.app.loadStoredMedia()
        rig.app.updateMedium(id: online.uuid) { $0.connectionStatus = .connected }
        rig.app.favoritesConnectionFilter = .online
        await rig.app.reloadFavorites()
        #expect(rig.app.favoriteObjects.map(\.name) == ["zzz.pdf"])
        #expect(rig.app.favoriteItemCount == 1)
        rig.app.favoritesConnectionFilter = .offline
        await rig.app.reloadFavorites()
        #expect(rig.app.favoriteObjects.count == SearchIndex.pageLimit)
        #expect(!rig.app.favoriteObjects.contains { $0.name == "zzz.pdf" })
        #expect(rig.app.favoriteItemCount == 600)
    }

    @Test func typeFilterWorksBeyondTheFirstPage() async throws {
        let names = (0..<600).map { String(format: "aaa-%04d.pdf", $0) } + ["zzz.jpg"]
        let rig = try await FavoritesRig.make(names: names)
        rig.app.searchState.filters.fileTypes = [.image]
        await rig.app.reloadFavorites()
        #expect(rig.app.favoriteObjects.map(\.name) == ["zzz.jpg"])
        #expect(rig.app.favoriteItemCount == 1)
        #expect(rig.app.favoriteUnfilteredCount == 601, "Zähler „1 von 601“")
    }

    /// Nacharbeit 3: Abwählen eines Favoriten jenseits der Seite (z. B. aus der Suche) senkt die Zahl.
    @Test func unfavoritingBeyondThePageLowersTheCount() async throws {
        let names = (0..<600).map { String(format: "rechnung-%04d.pdf", $0) }
        let rig = try await FavoritesRig.make(names: names)
        rig.app.mainWindowDestination = .favorites
        await rig.app.reloadFavorites()
        let rows = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: nil)
        let last = try #require(rows.first { $0.name == "rechnung-0599.pdf" })
        #expect(!rig.app.favoriteObjects.contains { $0.item.rowID == last.id }, "liegt jenseits der Seite")
        let medium = try #require(rig.app.medium(with: rig.medium.uuid))
        rig.app.toggleFavorite(.fromIndexedItem(IndexedItem(stored: last), medium: medium))
        await rig.app.waitForFavoriteWrites()
        #expect(rig.app.favoriteItemCount == 599)
        #expect(rig.app.favoriteObjects.count == SearchIndex.pageLimit)
    }

    @Test func unfavoritingKeepsTheCountInStep() async throws {
        let names = (0..<600).map { String(format: "rechnung-%04d.pdf", $0) }
        let rig = try await FavoritesRig.make(names: names)
        rig.app.mainWindowDestination = .favorites
        await rig.app.reloadFavorites()
        let first = try #require(rig.app.favoriteObjects.first)
        rig.app.toggleFavorite(.fromSearchResult(first))
        #expect(rig.app.favoriteObjects.count == SearchIndex.pageLimit - 1)
        #expect(rig.app.favoriteItemCount == 599)
        await rig.app.waitForFavoriteWrites()
    }
}
}

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct FavoritesTableWindowTests {
    private static let size = CGSize(width: 1000, height: 600)

    private func open(_ app: AppState, probe: ObjectRowRenderProbe) -> PixelProbe.Session {
        PixelProbe.open(
            FavoritesView()
                .environment(app)
                .environment(\.objectRowRenderProbe, probe)
                .environment(\.colorScheme, .light)
                .frame(width: Self.size.width, height: Self.size.height)
                .background(Color.white),
            size: Self.size
        )
    }

    /// bug.0.3.9.005 a/b: Laden über die echte Kette (Fenster → `.task` → Seite), ohne Wanduhr-Grenze. Geprüft wird
    /// gezählt: eine Seite (500) statt 10.000 Zeilen geladen, nur sichtbare Zeilen gebaut; die Dauer wird protokolliert.
    @Test func tenThousandFavoritesLoadOnePageAndBuildOnlyVisibleRows() async throws {
        let names = (0..<10_000).map { String(format: "datei-%05d.txt", $0) }
        let rig = try await FavoritesRig.make(names: names)
        rig.app.mainWindowDestination = .favorites
        let probe = ObjectRowRenderProbe()
        let started = ContinuousClock.now
        let session = open(rig.app, probe: probe)
        defer { session.close() }
        let loaded = await waitUntil(timeout: 20) {
            rig.app.favoriteObjects.count == SearchIndex.pageLimit && rig.app.favoriteItemCount == 10_000
        }
        await PixelProbe.settleOpenWindow(session)
        let elapsed = started.duration(to: .now)
        let ms = Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000
        print("bug.0.4.040 Messung: 10.000 Favoriten, Fenster bis geladen \(String(format: "%.1f", ms)) ms, Zeilen gebaut \(probe.rowBodies)")
        #expect(loaded, "Ansicht lädt die Favoriten nicht (Seite \(rig.app.favoriteObjects.count), Zahl \(String(describing: rig.app.favoriteItemCount)))")
        #expect(rig.app.favoriteObjects.count == SearchIndex.pageLimit, "nur eine Seite geladen")
        #expect(probe.rowBodies > 0, "Zeilen gezeichnet")
        #expect(probe.rowBodies < 100, "nur sichtbare Zeilen gebaut (lazy), gebaut: \(probe.rowBodies)")
    }

    @Test func progressTickDoesNotRebuildTheRows() async throws {
        let names = (0..<2_000).map { String(format: "datei-%05d.txt", $0) }
        let rig = try await FavoritesRig.make(names: names)
        rig.app.mainWindowDestination = .favorites
        let probe = ObjectRowRenderProbe()
        let session = open(rig.app, probe: probe)
        defer { session.close() }
        // bug.0.3.9.005 b: die Ansicht lädt selbst (`.task`), kein Neuladen von Hand, kein Einfrieren.
        let loaded = await waitUntil(timeout: 20) {
            rig.app.favoriteObjects.count == SearchIndex.pageLimit && rig.app.favoriteItemCount == 2_000
        }
        try #require(loaded, "Ansicht lädt die Favoriten nicht")
        await PixelProbe.settleOpenWindow(session)
        let built = probe.rowBodies
        #expect(built > 5, "sichtbare Zeilen gebaut: \(built)")

        let id = rig.medium.uuid
        for step in 1...5 {
            rig.app.updateMedium(id: id) {
                $0.indexingProgress = Double(step) / 10
                $0.fileCount += 1
            }
            await PixelProbe.settleOpenWindow(session)
        }
        let rebuilt = probe.rowBodies - built
        print("bug.0.4.040 Messung: 5 Fortschritts-Ticks, sichtbare Zeilen \(built), neu gebaut \(rebuilt)")
        #expect(rebuilt < built, "Tick baut nicht alle Zeilen neu (neu gebaut: \(rebuilt), sichtbar: \(built))")
        #expect(rebuilt <= 2, "neu gebaut: \(rebuilt)")
    }
}
}
