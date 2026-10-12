//
//  StoreReadTests.swift
//  diskindexTests
//
//  Aufgabe 232 g (1), seit 233 nur noch gegen `IndexStoreV3`: Lese-Tests der früheren Schicht (Suche mit Filtern, Zahl über
//  50.000 mit Bereich, Tiefe, Filter Swift = SQL, Favoriten, Seiten, Namen).
//

import Foundation
import Testing
@testable import diskindex

@MainActor
struct StoreReadTests {
    @Test func searchUsesLikeAndSkipsRemoved() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Platte", fsType: "apfs", bytes: 1_000)
        let other = try await store.insert(name: "Stick", fsType: "msdos", bytes: 2_000)
        let now = Date()
        let old = Calendar.current.date(byAdding: .year, value: -2, to: now) ?? now.addingTimeInterval(-60 * 60 * 24 * 800)
        _ = try await store.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Urlaubsfoto.jpg", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "FOTO_extra.png", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "AB.txt", isFolder: false, modifiedAt: old),
            ScannedEntry(name: "weg-foto.jpg", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "Notiz.txt", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "Fotos", isFolder: true, modifiedAt: now),
        ])
        let gone = try #require(try await store.children(medium: medium, parentID: nil).first { $0.name == "weg-foto.jpg" })
        _ = try await store.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Urlaubsfoto.jpg", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "FOTO_extra.png", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "AB.txt", isFolder: false, modifiedAt: old),
            ScannedEntry(name: "Notiz.txt", isFolder: false, modifiedAt: now),
            ScannedEntry(name: "Fotos", isFolder: true, modifiedAt: now),
        ])
        _ = try await store.addRoot(medium: other, entries: [ScannedEntry(name: "anderes-foto.jpg", isFolder: false, modifiedAt: now)])
        let reader = store.reader

        let foto = try await reader.search(query: "foto", filters: SearchFilters(), limit: 20, maxDepth: nil, scope: nil)
        #expect(Set(foto.map(\.name)) == ["Urlaubsfoto.jpg", "FOTO_extra.png", "anderes-foto.jpg", "Fotos"])
        let upper = try await reader.search(query: "FOTO", filters: SearchFilters(), limit: 20, maxDepth: nil, scope: nil)
        #expect(Set(upper.map(\.name)) == Set(foto.map(\.name)))
        let short = try await reader.search(query: "ab", filters: SearchFilters(), limit: 20, maxDepth: nil, scope: nil)
        #expect(short.map(\.name) == ["AB.txt"])

        var images = SearchFilters()
        images.fileTypes = [.image]
        let imageHits = try await reader.search(query: "foto", filters: images, limit: 20, maxDepth: nil, scope: nil)
        #expect(Set(imageHits.map(\.name)) == ["Urlaubsfoto.jpg", "FOTO_extra.png", "anderes-foto.jpg"])

        var onlyText = SearchFilters()
        onlyText.customExtensions = [".txt"]
        let textHits = try await reader.search(query: "", filters: onlyText, limit: 20, maxDepth: nil, scope: nil)
        #expect(Set(textHits.map(\.name)) == ["AB.txt", "Notiz.txt"])

        var recent = SearchFilters()
        recent.age = .lastWeek
        #expect(try await reader.search(query: "ab", filters: recent, limit: 20, maxDepth: nil, scope: nil).isEmpty)

        var oneMedium = SearchFilters()
        oneMedium.selectAllMedia = false
        oneMedium.mediumIDs = [medium.uuid]
        let limited = try await reader.search(query: "foto", filters: oneMedium, limit: 20, maxDepth: nil, scope: nil)
        #expect(Set(limited.map(\.name)) == ["Urlaubsfoto.jpg", "FOTO_extra.png", "Fotos"])
        #expect(try await store.isGone(gone.id))

        var noMedium = SearchFilters()
        noMedium.selectAllMedia = false
        #expect(try await reader.search(query: "foto", filters: noMedium, limit: 20, maxDepth: nil, scope: nil).isEmpty)
        #expect(try await reader.search(query: "", filters: SearchFilters(), limit: 20, maxDepth: nil, scope: nil).isEmpty)
        #expect(try await reader.searchCount(query: "foto", filters: SearchFilters(), maxDepth: nil, scope: nil) == 4)
    }

    @Test func countIsExactAboveFiftyThousandWithScope() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "ZAHL", fsType: "apfs", bytes: 1_000)
        var entries: [ScannedEntry] = []
        for index in 0..<60_000 {
            entries.append(ScannedEntry(name: "bericht-\(index).html", isFolder: false, sizeBytes: 1))
        }
        entries.append(ScannedEntry(name: "bericht-a.tmp", isFolder: false, sizeBytes: 1))
        entries.append(ScannedEntry(name: ".bericht-versteckt.html", isFolder: false, sizeBytes: 1))
        entries.append(ScannedEntry(name: "._bericht-apple.html", isFolder: false, sizeBytes: 1))
        try await store.writer.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: true)],
            seenAt: Date()
        )
        let scope = IndexScope(
            maxDepth: nil,
            matcher: IgnoreMatcher(ignoreHiddenFiles: true, excludedPatterns: ["*.tmp"], artifactsIgnored: true)
        )
        #expect(try await store.reader.searchCount(query: "bericht", filters: SearchFilters(), maxDepth: nil, scope: scope) == 60_000)
        #expect(try await store.reader.searchCount(query: "bericht", filters: SearchFilters(), maxDepth: nil, scope: nil) == 60_003)
        let counts = try await store.reader.counts(mediumUUID: medium.uuid, scope: scope)
        #expect(counts.files == 60_000)
        #expect(try await store.reader.counts(mediumUUID: medium.uuid, scope: nil).files == 60_003)
    }

    @Test func loweredScanDepthHidesDeeperHits() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Tief")
        let level1 = try await store.addRoot(medium: medium, entries: [ScannedEntry(name: "eins", isFolder: true)])
        let level2 = try await store.apply(medium: medium, parentID: level1[0].id, entries: [ScannedEntry(name: "zwei", isFolder: true)])
        _ = try await store.apply(medium: medium, parentID: level2[0].id, entries: [ScannedEntry(name: "deep.txt", isFolder: false)])
        let reader = store.reader
        #expect(try await reader.search(query: "deep", filters: SearchFilters(), limit: 10, maxDepth: 2, scope: nil).isEmpty)
        #expect(try await reader.search(query: "deep", filters: SearchFilters(), limit: 10, maxDepth: nil, scope: nil).map(\.name) == ["deep.txt"])
        let scoped = IndexScope(maxDepth: 2, matcher: IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [], artifactsIgnored: false))
        #expect(try await reader.search(query: "deep", filters: SearchFilters(), limit: 10, maxDepth: nil, scope: scoped).isEmpty)
        #expect(try await reader.searchCount(query: "deep", filters: SearchFilters(), maxDepth: 2, scope: nil) == 0)
        #expect(try await reader.searchCount(query: "deep", filters: SearchFilters(), maxDepth: nil, scope: nil) == 1)
    }

    @Test func swiftAndSQLFiltersAgree() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Suche")
        let recent = Date()
        let old = Date(timeIntervalSince1970: 1_000_000_000)
        _ = try await store.addRoot(medium: medium, entries: [
            ScannedEntry(name: "Rechnung.pdf", isFolder: false, sizeBytes: 10, modifiedAt: recent),
            ScannedEntry(name: "alt.pdf", isFolder: false, sizeBytes: 10, modifiedAt: old),
            ScannedEntry(name: "foto.jpg", isFolder: false, sizeBytes: 10, modifiedAt: recent),
            ScannedEntry(name: "notiz.txt", isFolder: false, sizeBytes: 10, modifiedAt: old),
            ScannedEntry(name: "Ordner", isFolder: true),
        ])
        var rows: [StoredItem] = []
        var pending: [Int64?] = [nil]
        while let parent = pending.popLast() {
            for child in try await store.children(medium: medium, parentID: parent) {
                rows.append(child)
                if child.isFolder { pending.append(child.id) }
            }
        }
        var filters = SearchFilters()
        filters.fileTypes = [.pdf]
        filters.age = .lastYear
        for and in [true, false] {
            filters.combineWithAnd = and
            let sql = try await store.reader.search(query: "", filters: filters, limit: 500, maxDepth: nil, scope: nil)
            let swift = rows.filter { SearchItemFilter.matches(IndexedItem(stored: $0), filters: filters, hasSearchTerm: false) }
            #expect(Set(sql.map(\.id)) == Set(swift.map(\.id)), "und=\(and)")
        }
    }

    @Test func favoritesAreReadWithPathAndDepthLimit() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Favoriten")
        let root = try await store.addRoot(medium: medium, entries: [
            ScannedEntry(name: "readme.txt", isFolder: false),
            ScannedEntry(name: "Ordner", isFolder: true),
        ])
        let folder = try #require(root.first { $0.isFolder })
        let inner = try await store.apply(medium: medium, parentID: folder.id, entries: [ScannedEntry(name: "tief.txt", isFolder: false)])
        let readme = try #require(root.first { $0.name == "readme.txt" })
        try await store.writer.setFavorites(itemIDs: [readme.id, inner[0].id], true)
        let favorites = try await store.reader.favorites(maxDepth: nil, scope: nil)
        #expect(Set(favorites.map(\.name)) == ["readme.txt", "tief.txt"])
        #expect(favorites.allSatisfy { $0.isFavorite })
        #expect(Set(favorites.map(\.path)) == ["/readme.txt", "/Ordner/tief.txt"])
        #expect(try await store.reader.favorites(maxDepth: 1, scope: nil).map(\.name) == ["readme.txt"])
        try await store.writer.setFavorite(itemID: readme.id, false)
        #expect(try await store.reader.favorites(maxDepth: nil, scope: nil).map(\.name) == ["tief.txt"])
    }

    @Test func columnPagesCoverAFolderWithoutGaps() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Seiten")
        let entries = (1...25).map { ScannedEntry(name: "datei \($0).txt", isFolder: false) }
            + (1...5).map { ScannedEntry(name: "Ordner \($0)", isFolder: true) }
        _ = try await store.addRoot(medium: medium, entries: entries)
        #expect(try await store.reader.childCount(mediumUUID: medium.uuid, parentID: nil, scope: nil) == 30)
        var seen: [String] = []
        var cursor: ItemChildrenCursor?
        var pages = 0
        while true {
            let page = try await store.reader.childrenPage(mediumUUID: medium.uuid, parentID: nil, limit: 10, after: cursor, offset: 0, scope: nil)
            seen += page.items.map(\.name)
            pages += 1
            guard let next = page.nextCursor else { break }
            cursor = next
        }
        #expect(pages == 4)  // volle dritte Seite liefert noch einen Cursor; die vierte ist leer
        #expect(seen.count == 30)
        #expect(Set(seen).count == 30)
        #expect(seen.first == "datei 1.txt" && seen.last == "Ordner 5")
        let slice = try await store.reader.children(mediumUUID: medium.uuid, parentID: nil, limit: 4, offset: 2, scope: nil)
        #expect(slice.count == 4)
        let hidden = IndexScope(maxDepth: 0, matcher: IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [], artifactsIgnored: false))
        #expect(try await store.reader.children(mediumUUID: medium.uuid, parentID: nil, limit: nil, offset: 0, scope: hidden).isEmpty)
    }

    @Test func storedNamesListOnlyVisibleEntries() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Namen")
        _ = try await store.addRoot(medium: medium, entries: [ScannedEntry(name: "a.txt", isFolder: false), ScannedEntry(name: "b.txt", isFolder: false)])
        _ = try await store.addRoot(medium: medium, entries: [ScannedEntry(name: "a.txt", isFolder: false)])
        #expect(try await store.reader.storedNames() == ["a.txt"])
    }
}
