//
//  FavoritesLoadingWindowTests.swift
//  diskindexTests
//
//  todo.0.4.043/046: Beim Öffnen der Favoriten erscheint sofort die Ladefläche (Fläche von „Keine Favoriten“, violetter
//  Spinner statt des Icons, Titel mit dem Umfang des Verbindungsfilters) und bleibt mindestens 1 s, auch wenn die
//  Favoriten schneller da sind; danach die Liste bzw. „Keine Favoriten“. Echtes Fenster außerhalb des Bildschirms (Regel 10/19), Pixel hell
//  und dunkel. Der Test schaltet nur die Ansicht um (wie die Seitenleiste) und wartet (Regel 18).
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct FavoritesLoadingWindowTests {
    private static let size = CGSize(width: 900, height: 560)

    @Test(arguments: [false, true])
    func openingFavoritesShowsLoadingForAtLeastOneSecondThenTheList(dark: Bool) async throws {
        let rig = try await Self.makeRig(favorites: ["rechnung.pdf", "vertrag.pdf"])
        defer { rig.close() }
        let app = rig.app
        // Wie in der App: erst die Ansicht wählen, dann erscheint die Favoritenansicht. Kein Laden vorab: die Ansicht
        // lädt selbst (`.task`).
        let opened = ContinuousClock.now
        app.mainWindowDestination = .favorites
        #expect(app.favoritesLoading.isShowing, "Ladefläche nicht sofort")
        let session = Self.open(app, dark: dark)
        defer { session.close() }
        let first = session.bitmap()
        _ = ScopeLoadingPixels.expectSpinner(first, region: Self.centerBand, ScopeLoadingPixels.isViolet, "erstes Bild")
        // Daten sind schnell da, die Ladefläche bleibt trotzdem stehen.
        let dataLoaded = await waitUntil { app.favoriteObjects.count == 2 }
        try #require(dataLoaded, "Favoriten nicht geladen")
        let loadingBitmap = session.bitmap()
        let loadingElapsed = opened.duration(to: .now)
        if loadingElapsed < .milliseconds(900) {
            #expect(app.favoritesLoading.isShowing, "Ladefläche vor 1 s verschwunden")
            _ = ScopeLoadingPixels.expectSpinner(loadingBitmap, region: Self.centerBand, ScopeLoadingPixels.isViolet, "während des Ladens")
        }
        let ended = await waitUntil(timeout: 5) { !app.favoritesLoading.isShowing }
        let elapsed = opened.duration(to: .now)
        #expect(ended, "Ladefläche endet nicht")
        #expect(elapsed >= .seconds(1), "Ladefläche kürzer als 1 s: \(elapsed)")
        let listShown = await waitUntil {
            Self.violetPixels(session.bitmap(), dark: dark, region: Self.rowIconColumn) > 10
        }
        #expect(listShown, "Liste nach der Ladefläche nicht sichtbar")
    }

    @Test(arguments: [false, true])
    func withoutFavoritesLoadingIsFollowedByTheEmptyState(dark: Bool) async throws {
        let rig = try await Self.makeRig(favorites: [], minimum: .milliseconds(300))
        defer { rig.close() }
        let app = rig.app
        app.mainWindowDestination = .favorites
        #expect(app.favoritesLoading.isShowing)
        let session = Self.open(app, dark: dark)
        defer { session.close() }
        let early = session.bitmap()
        _ = ScopeLoadingPixels.expectSpinner(early, region: Self.centerBand, ScopeLoadingPixels.isViolet, "„Keine Favoriten“ statt Ladefläche?")
        let ended = await waitUntil(timeout: 5) { !app.favoritesLoading.isShowing }
        #expect(ended)
        // „Keine Favoriten“: das gefüllte Icon (nicht hohl wie der Spinner).
        let emptyShown = await waitUntil {
            let bitmap = session.bitmap()
            guard let box = ScopeLoadingPixels.bounds(bitmap, region: Self.centerBand, ScopeLoadingPixels.isViolet) else { return false }
            let hole = CGRect(x: box.midX - 6, y: box.midY - 6, width: 12, height: 12)
            return ScopeLoadingPixels.count(bitmap, region: hole, ScopeLoadingPixels.isViolet) > 0
        }
        #expect(emptyShown, "„Keine Favoriten“ (violettes Icon) nach der Ladefläche fehlt")
    }

    /// Verlassen der Favoriten während des Ladens: Ladefläche aus; erneutes Öffnen zeigt sie wieder sofort.
    @Test func leavingAndReopeningRestartsTheLoadingSurface() async throws {
        let rig = try await Self.makeRig(favorites: ["a.txt"], minimum: .milliseconds(300))
        defer { rig.close() }
        let app = rig.app
        app.mainWindowDestination = .favorites
        #expect(app.favoritesLoading.isShowing)
        app.mainWindowDestination = .dashboard
        #expect(!app.favoritesLoading.isShowing)
        app.mainWindowDestination = .favorites
        #expect(app.favoritesLoading.isShowing)
    }

    /// todo.0.4.046: Umfang = Medien des gewählten Verbindungsfilters und ihre Dateien (Filter „Offline“ → nur Offline).
    @Test func loadingScopeFollowsTheConnectionFilter() async throws {
        let rig = try await Self.makeRig(favorites: ["a.txt"], minimum: .milliseconds(300))
        defer { rig.close() }
        let app = rig.app
        let offline = try #require(app.indexedMedia.first)
        var online = offline
        online.id = UUID()
        online.name = "Online"
        online.connectionStatus = .connected
        app.media.append(online)
        app.updateMedium(id: offline.id) { $0.fileCount = 7 }
        app.updateMedium(id: online.id) { $0.fileCount = 5 }
        try #require(app.indexedMedia.count == 2, "Voraussetzung: zwei erfasste Medien")
        app.favoritesConnectionFilter = .offline
        app.mainWindowDestination = .favorites
        #expect(app.favoritesLoading.isShowing)
        #expect(app.favoritesLoadingScope.media == 1 && app.favoritesLoadingScope.files == 7, "Offline: \(app.favoritesLoadingScope)")
        app.favoritesConnectionFilter = .online
        #expect(app.favoritesLoadingScope.media == 1 && app.favoritesLoadingScope.files == 5, "Online: \(app.favoritesLoadingScope)")
        app.favoritesConnectionFilter = .all
        #expect(app.favoritesLoadingScope.media == 2 && app.favoritesLoadingScope.files == 12, "Alle: \(app.favoritesLoadingScope)")
        L10n.$languageOverride.withValue(.german) {
            #expect(LayoutCopy.loadingFavoritesTitle(media: 1, files: 7) == "Dein 1 Speichermedium und 7 Dateien werden gefiltert …")
        }
    }

    // MARK: - Hilfen


    @MainActor
    private struct Rig {
        let app: AppState
        let database: TestDatabase
        let directory: URL
        func close() {
            app.prepareForTermination()
            try? database.close()
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private static func makeRig(favorites: [String], minimum: Duration = .seconds(1)) async throws -> Rig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-fav-loading-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Daten", decision: .index, indexStatus: .indexed, completedDepth: 3)
        try await store.upsertMedium(medium)
        medium = try #require(try await store.medium(uuid: medium.uuid))
        let entries = (favorites + ["andere.txt"]).map { ScannedEntry(name: $0, isFolder: false, sizeBytes: 1, modifiedAt: Date()) }
        try await store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: entries, seenAt: Date())
        let rows = try await store.children(mediumUUID: medium.uuid, parentID: nil).filter { favorites.contains($0.name) }
        if !rows.isEmpty { try await store.setFavorites(itemIDs: rows.map(\.id), true) }
        let app = AppState(loadingMinimum: minimum)
        app.attach(store: store)
        await app.loadStoredMedia()
        return Rig(app: app, database: database, directory: directory)
    }

    private static func open(_ app: AppState, dark: Bool) -> PixelProbe.Session {
        PixelProbe.open(
            FavoritesView()
                .environment(app)
                .environment(\.colorScheme, dark ? .dark : .light)
                .environment(\.spinnerFrozenAngle, 0)
                .frame(width: size.width, height: size.height)
                .background(DesignColor.bg),
            size: size,
            appearance: dark ? .darkAqua : .aqua
        )
    }

    /// Mittelstreifen unter der Chip-Leiste und über der Fußzeile (Icon bzw. Spinner des Leerzustands).
    private static let centerBand = CGRect(x: size.width / 2 - 60, y: 60, width: 120, height: size.height - 110)
    /// Platz des Icons/Spinners über dem Titel: Mitte der Fläche, etwas darüber.
    private static let spinnerSlot = CGRect(x: size.width / 2 - 30, y: 222, width: 60, height: 54)
    /// Linke Spalte der Tabellenzeilen (violette Objekt-Icons der Favoriten).
    private static let rowIconColumn = CGRect(x: 0, y: 40, width: 80, height: 200)

    /// Violett der Favoriten (Token hell #9D69D2, dunkel #B98CEA) über den Farbton: Blau und Rot klar über Grün. Das
    /// Blau der Chips (Rot unter Grün) und Grautöne zählen nicht; die helle Füllung des Icons auch nicht.
    private static func violetPixels(_ bitmap: NSBitmapImageRep, dark: Bool, region: CGRect) -> Int {
        count(bitmap, region: region) { r, g, b in
            b - g > 0.25 && r - g > 0.08 && b > r
        }
    }

    /// Pixel in Textfarbe (hell: dunkel, dunkel: hell) – Spinner und Titel.
    private static func inkPixels(_ bitmap: NSBitmapImageRep, dark: Bool, region: CGRect) -> Int {
        count(bitmap, region: region) { r, g, b in
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            return dark ? luminance > 0.6 : luminance < 0.35
        }
    }

    private static func count(_ bitmap: NSBitmapImageRep, region: CGRect, _ match: (CGFloat, CGFloat, CGFloat) -> Bool) -> Int {
        let scale = CGFloat(bitmap.pixelsWide) / max(1, bitmap.size.width)
        let x0 = max(0, Int(region.minX * scale)), x1 = min(bitmap.pixelsWide, Int(region.maxX * scale))
        let y0 = max(0, Int(region.minY * scale)), y1 = min(bitmap.pixelsHigh, Int(region.maxY * scale))
        guard x0 < x1, y0 < y1 else { return 0 }
        var hits = 0
        for y in y0..<y1 {
            for x in x0..<x1 {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                if match(color.redComponent, color.greenComponent, color.blueComponent) { hits += 1 }
            }
        }
        return hits
    }
}
}
