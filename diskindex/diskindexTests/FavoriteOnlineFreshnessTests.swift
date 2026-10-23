//
//  FavoriteOnlineFreshnessTests.swift
//  diskindexTests
//
//  bug.0.4.037 (REPORT 80, 82, 103): Favorit und Online-Status in Listen aktuell.
//  - Favoriten: abwählen → Zeile sofort weg, zweiter Klick (gleiches, altes Ziel) setzt wieder.
//  - Medium per `updateMedium` offline → Filter „Offline“ enthält dessen Favoriten (echtes Fenster, ohne Nachhilfe).
//  - Tabelle ab 50.000 Zeilen: Favorit umschalten → Zeile zeigt den neuen Zustand (echtes Fenster).
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct FavoriteToggleFreshnessTests {
    @Test func unfavoriteInFavoritesRemovesTheRowAndASecondClickSetsItAgain() async throws {
        let rig = try await searchFixture()
        let rows = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: nil)
        let file = try #require(rows.first { $0.name == "Rechnung.pdf" })
        try await rig.store.setFavorite(itemID: file.id, true)
        rig.app.mainWindowDestination = .favorites
        await rig.app.reloadFavorites()
        let result = try #require(rig.app.favoriteObjects.first { $0.name == "Rechnung.pdf" })
        // Ziel wie aus der Zeile gebaut: trägt den Stand von vorher (Favorit), auch nach dem ersten Klick.
        let target = ObjectContextTarget.fromSearchResult(result)
        #expect(target.isFavorite)

        rig.app.toggleFavorite(target)
        #expect(!rig.app.favoriteObjects.contains { $0.id == result.id }, "Zeile verschwindet sofort")
        #expect(!rig.app.isFavorite(target))

        rig.app.toggleFavorite(target)
        #expect(rig.app.isFavorite(target), "zweiter Klick setzt den Favoriten wieder")
        await rig.app.waitForFavoriteWrites()
        #expect(try await rig.store.favoriteItemIDs().contains(file.id))
        #expect(rig.app.favoriteObjects.contains { $0.id == result.id }, "Favoriten-Seite holt ihn nach dem Schreiben")
    }

    /// Nacharbeit 1: ein Neuladen gleich nach dem Abwählen (Weg einer Live-Änderung) liest erst nach dem Schreiben.
    @Test func reloadRightAfterUnfavoriteKeepsTheRowGone() async throws {
        let rig = try await searchFixture()
        let rows = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: nil)
        let file = try #require(rows.first { $0.name == "Rechnung.pdf" })
        try await rig.store.setFavorite(itemID: file.id, true)
        rig.app.mainWindowDestination = .favorites
        await rig.app.reloadFavorites()
        let result = try #require(rig.app.favoriteObjects.first { $0.name == "Rechnung.pdf" })

        rig.app.toggleFavorite(.fromSearchResult(result))
        await rig.app.reloadFavoritesIfVisible()
        #expect(!rig.app.favoriteObjects.contains { $0.id == result.id }, "abgewählter Favorit kommt nicht zurück")
        #expect(rig.app.favoriteItemCount == 0)
        await rig.app.waitForFavoriteWrites()
        #expect(try await !rig.store.favoriteItemIDs().contains(file.id))
    }

    @Test func attachResetsTheFavoriteIDs() async throws {
        let rig = try await searchFixture()
        await rig.app.reloadFavorites()
        #expect(rig.app.favoriteRowIDs != nil)
        rig.app.attach(store: IndexStoreV3(database: rig.database))
        #expect(rig.app.favoriteRowIDs == nil)
    }

    @Test func secondClickBeforeTheIDsAreLoadedAlsoSetsAgain() async throws {
        let rig = try await searchFixture()
        let rows = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: nil)
        let file = try #require(rows.first { $0.name == "Rechnung.pdf" })
        let medium = try #require(rig.app.medium(with: rig.medium.uuid))
        let target = ObjectContextTarget.fromIndexedItem(IndexedItem(stored: file), medium: medium)
        #expect(!target.isFavorite)
        #expect(rig.app.favoriteRowIDs == nil)

        rig.app.toggleFavorite(target)
        rig.app.toggleFavorite(target)
        #expect(!rig.app.isFavorite(target))
        await rig.app.waitForFavoriteWrites()
        #expect(try await !rig.store.favoriteItemIDs().contains(file.id))
        #expect(rig.app.favoriteRowIDs?.contains(file.id) == false)
    }

    @Test func searchRowsAreUpdatedLocally() async throws {
        let rig = try await searchFixture()
        rig.app.searchState.submittedQuery = "rechnung"
        await rig.app.runSearch()
        let result = try #require(rig.app.searchMatch.items.first { $0.name == "Rechnung.pdf" })
        #expect(!result.item.isFavorite)
        rig.app.toggleFavorite(.fromSearchResult(result))
        #expect(rig.app.searchMatch.items.first { $0.id == result.id }?.item.isFavorite == true)
        await rig.app.waitForFavoriteWrites()
    }

    @Test func lookupPrefersTheSetOverTheRow() {
        #expect(FavoriteLookup(rowIDs: [7], editsBeforeLoad: [:]).isFavorite(rowID: 7, fallback: false))
        #expect(!FavoriteLookup(rowIDs: [], editsBeforeLoad: [:]).isFavorite(rowID: 7, fallback: true))
        #expect(!FavoriteLookup(rowIDs: nil, editsBeforeLoad: [7: false]).isFavorite(rowID: 7, fallback: true))
        #expect(FavoriteLookup(rowIDs: nil, editsBeforeLoad: [:]).isFavorite(rowID: 7, fallback: true))
        #expect(FavoriteLookup(rowIDs: [7], editsBeforeLoad: [:]).isFavorite(rowID: nil, fallback: false) == false)
    }

    @Test func onlineIsDerivedFromTheCurrentMedium() async throws {
        let rig = try await searchFixture()
        let id = rig.medium.uuid
        rig.app.updateMedium(id: id) { $0.connectionStatus = .connected }
        #expect(rig.app.isMediumOnline(id))
        #expect(rig.app.mediumConnectivity[id] == true)
        rig.app.updateMedium(id: id) { $0.connectionStatus = .offline }
        #expect(!rig.app.isMediumOnline(id))
        #expect(rig.app.mediumConnectivity[id] == false)
    }
}

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct FavoriteOnlineWindowTests {
    @Test func offlineFilterShowsFavoritesOfAMediumThatJustWentOffline() async throws {
        let rig = try await searchFixture()
        let id = rig.medium.uuid
        rig.app.updateMedium(id: id) { $0.connectionStatus = .connected }
        let rows = try await rig.store.children(mediumUUID: id, parentID: nil)
        let file = try #require(rows.first { $0.name == "Rechnung.pdf" })
        try await rig.store.setFavorite(itemID: file.id, true)
        rig.app.mainWindowDestination = .favorites
        rig.app.favoritesConnectionFilter = .offline
        let probe = ObjectRowRenderProbe()
        let size = CGSize(width: 1000, height: 500)
        let session = PixelProbe.open(
            FavoritesView()
                .environment(rig.app)
                .environment(\.objectRowRenderProbe, probe)
                .frame(width: size.width, height: size.height),
            size: size
        )
        defer { session.close() }
        // todo.0.4.043: erst nach der Ladefläche (mindestens 1 s) steht die Liste.
        try #require(await waitUntil(timeout: 5) { !rig.app.favoritesLoading.isShowing }, "Ladefläche endet nicht")
        await PixelProbe.settleOpenWindow(session)
        #expect(!rig.app.favoriteObjects.contains { $0.name == "Rechnung.pdf" }, "online: nicht unter „Offline“")

        let rowsBefore = probe.rowBodies
        rig.app.updateMedium(id: id) { $0.connectionStatus = .offline }
        // Nur warten und lesen: die Ansicht lädt selbst nach (Regel 18).
        let deadline = ContinuousClock.now + .seconds(10)
        while !rig.app.favoriteObjects.contains(where: { $0.name == "Rechnung.pdf" }), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
            session.window.display()
        }
        #expect(rig.app.favoriteObjects.contains { $0.name == "Rechnung.pdf" }, "offline: unter „Offline“")
        await PixelProbe.settleOpenWindow(session)
        #expect(probe.rowBodies > rowsBefore, "Zeile im Fenster gezeichnet")
    }

    /// Nacharbeit 2: Abwählen per Klick auf den Eintrag „Favorit“ des Kontextmenüs. Die Menü-Ansicht des Panels liegt
    /// in einem eigenen Fenster außerhalb des Bildschirms (das echte Panel öffnet am Mauszeiger, Regel 19); das Ziel
    /// ist das der Zeile (`fromSearchResult`, Favorit = ja). Der zweite Klick kommt mit demselben, alten Ziel, wie aus
    /// einer Zeile der Suche, die noch sichtbar ist.
    @Test func menuClickUnfavoritesTheRowAndASecondClickSetsItAgain() async throws {
        let rig = try await searchFixture()
        let rows = try await rig.store.children(mediumUUID: rig.medium.uuid, parentID: nil)
        let file = try #require(rows.first { $0.name == "Rechnung.pdf" })
        let other = try #require(rows.first { $0.name == "foto.jpg" })
        try await rig.store.setFavorites(itemIDs: [file.id, other.id], true)
        // Angeschlossen: „Im Finder anzeigen“ ist aktiv und volle Deckkraft (erstes Icon-Band im Menü).
        rig.app.updateMedium(id: rig.medium.uuid) { $0.connectionStatus = .connected }
        rig.app.mainWindowDestination = .favorites
        await rig.app.reloadFavorites()
        let result = try #require(rig.app.favoriteObjects.first { $0.name == "Rechnung.pdf" })
        let target = ObjectContextTarget.fromSearchResult(result)
        #expect(target.isFavorite)

        let size = CGSize(width: 1000, height: 700)
        let favorites = PixelProbe.open(
            FavoritesView()
                .environment(rig.app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height)
                .background(Color.white),
            size: size
        )
        defer { favorites.close() }
        // todo.0.4.043: erst nach der Ladefläche (mindestens 1 s) steht die Liste.
        try #require(await waitUntil(timeout: 5) { !rig.app.favoritesLoading.isShowing }, "Ladefläche endet nicht")
        await PixelProbe.settleOpenWindow(favorites)
        // Zeilen nach Name: foto.jpg (1), Rechnung.pdf (2). Zeile 2 = zweites Tintenband unter dem Kopf.
        let before = inkRows(favorites.bitmap(), x0: 40, x1: 300, y0: 40, y1: 400)
        print("bug.0.4.037 Fenster vorher: Bänder \(before)")
        try #require(before.count >= 3, "Kopf und zwei Zeilen: \(before)")

        try await clickFavoriteEntry(target, app: rig.app)
        #expect(!rig.app.favoriteObjects.contains { $0.id == result.id }, "Zeile verschwindet sofort")
        await PixelProbe.settleOpenWindow(favorites)
        let after = inkRows(favorites.bitmap(), x0: 40, x1: 300, y0: 40, y1: 400)
        print("bug.0.4.037 Fenster nach Abwählen: Bänder \(after)")
        #expect(after.count == before.count - 1, "eine Zeile weniger im Fenster: \(before) → \(after)")

        try await clickFavoriteEntry(target, app: rig.app)
        #expect(rig.app.isFavorite(target), "zweiter Klick setzt ihn wieder")
        await rig.app.waitForFavoriteWrites()
        #expect(try await rig.store.favoriteItemIDs().contains(file.id))
        await PixelProbe.settleOpenWindow(favorites)
        let again = inkRows(favorites.bitmap(), x0: 40, x1: 300, y0: 40, y1: 400)
        print("bug.0.4.037 Fenster nach zweitem Klick: Bänder \(again)")
        #expect(again.count == before.count, "Zeile wieder da: \(again)")
    }

    /// Öffnet die Menü-Ansicht für `target` außerhalb des Bildschirms und klickt (`sendEvent`) auf „Favorit“: zweite
    /// Gruppe, nach „Im Finder anzeigen“ und der Trennlinie.
    private func clickFavoriteEntry(_ target: ObjectContextTarget, app: AppState) async throws {
        let size = CGSize(width: 304, height: 360)
        let menu = PixelProbe.open(
            objectContextMenuForTesting([target]).environment(app).environment(\.colorScheme, .light),
            size: size
        )
        defer { menu.close() }
        await PixelProbe.settleOpenWindow(menu)
        let bands = inkRows(menu.bitmap(), x0: 44, x1: 60, y0: 34, y1: 200)
        print("bug.0.4.037 Menü-Icons: \(bands)")
        let entry = try #require(bands.dropFirst().first, "Icon „Favorit“ nicht gefunden: \(bands)")
        menu.clickThroughHitTest(at: CGPoint(x: 120, y: (entry.lowerBound + entry.upperBound) / 2))
        await PixelProbe.settleOpenWindow(menu)
    }

    /// Zeilenbänder (pt, oben links) mit Tinte gegen Weiß in einem Ausschnitt.
    private func inkRows(_ bitmap: NSBitmapImageRep, x0: CGFloat, x1: CGFloat, y0: CGFloat, y1: CGFloat) -> [ClosedRange<CGFloat>] {
        var bands: [ClosedRange<CGFloat>] = []
        var start: CGFloat?
        var y = y0
        while y < y1 {
            var ink = false
            var x = x0
            while x < x1 {
                let sample = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                if sample.redComponent < 0.6 || sample.greenComponent < 0.6 || sample.blueComponent < 0.6 {
                    ink = true
                    break
                }
                x += 1
            }
            if ink, start == nil { start = y }
            if !ink, let begin = start {
                bands.append(begin...(y - 1))
                start = nil
            }
            y += 1
        }
        if let begin = start { bands.append(begin...(y1 - 1)) }
        return bands
    }

    @Test func folderTableWith50kRowsShowsTheToggledFavorite() async throws {
        let rig = try await SurfaceRig.make()
        var stored = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Gross", decision: .index, indexStatus: .indexed, completedDepth: 3)
        try await rig.store.upsertMedium(stored)
        stored = try #require(try await rig.store.medium(uuid: stored.uuid))
        let entries = (0..<50_000).map { ScannedEntry(name: String(format: "datei-%05d.txt", $0), isFolder: false, sizeBytes: 1) }
        try await rig.store.applyDirectory(mediumUUID: stored.uuid, parentID: nil, entries: entries, seenAt: Date())
        let app = rig.app
        app.attach(store: rig.store)
        await app.loadStoredMedia()
        let medium = try #require(app.medium(with: stored.uuid))
        let loaded = await app.indexRepository.loadChildren(mediumID: medium.id, path: [])
        try #require(loaded.count >= ColumnFolderListThreshold.tableViewMinimum)

        let size = CGSize(width: 280, height: 400)
        let session = PixelProbe.open(
            FolderTableHarness(mediumID: medium.id)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height)
                .background(Color.white),
            size: size
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        let content = try #require(session.window.contentView)
        let table = try #require(findTable(in: content))
        #expect(table.numberOfRows == loaded.count)
        let first = try #require(app.indexRepository.children(mediumID: medium.id, path: []).first)
        #expect(!first.isFavorite)
        #expect(!hasFavoriteInk(session, row: 0), "vorher kein Favorit")

        app.toggleFavorite(.fromIndexedItem(first, medium: medium))
        await PixelProbe.settleOpenWindow(session)
        #expect(hasFavoriteInk(session, row: 0), "Zeile zeigt den Favoriten")

        app.toggleFavorite(.fromIndexedItem(first, medium: medium))
        await PixelProbe.settleOpenWindow(session)
        #expect(!hasFavoriteInk(session, row: 0), "zweiter Klick nimmt ihn wieder weg")
        await app.waitForFavoriteWrites()
    }

    /// Icon der Zeile (links, 34 pt je Zeile mit Abstand) in Favoritenfarbe?
    private func hasFavoriteInk(_ session: PixelProbe.Session, row: Int) -> Bool {
        let bitmap = session.bitmap()
        let favorite = NSColor(DesignColor.favorite).usingColorSpace(.sRGB)
        guard let favorite else { return false }
        let top = CGFloat(row) * 34
        for y in stride(from: top + 4, to: top + 30, by: 1) {
            for x in stride(from: CGFloat(10), to: 48, by: 1) {
                let sample = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                if abs(sample.redComponent - favorite.redComponent) < 0.12,
                   abs(sample.greenComponent - favorite.greenComponent) < 0.12,
                   abs(sample.blueComponent - favorite.blueComponent) < 0.12 {
                    return true
                }
            }
        }
        return false
    }

    private func findTable(in root: NSView) -> NSTableView? {
        if let scroll = root as? NSScrollView, let table = scroll.documentView as? NSTableView {
            return table
        }
        for child in root.subviews {
            if let found = findTable(in: child) { return found }
        }
        return nil
    }
}
}

/// Spalte wie in der Spaltenansicht: Zeilen aus dem Spalten-Cache, Icon-Farbe aus `isFavorite` (wie `ColumnBrowserView`).
private struct FolderTableHarness: View {
    @Environment(AppState.self) private var appState
    let mediumID: UUID

    var body: some View {
        let items = appState.indexRepository.children(mediumID: mediumID, path: [])
        ColumnFolderTableView(items: items, selectedIDs: []) { item in
            ColumnBrowserRow(
                title: item.name,
                isSelected: false,
                iconAsset: item.fileKind.assetName,
                iconColor: item.isFavorite ? DesignColor.favorite : DesignColor.text,
                fadeTitleOnOverflow: true,
                onSelect: {}
            )
        }
    }
}
