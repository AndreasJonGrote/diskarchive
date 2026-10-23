//
//  V3ReadTests.swift
//  diskindexTests
//
//  Aufgabe 232 g (2)–(7): SQL-Filter gegen das Swift-Modell, natürliche gemischte Sortierung über Seiten, Suche nach Stammlauten und
//  Mediennamen, parallele gegen einzelne Abfrage, Pfad über sechs Ebenen, Abfragepläne.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

private struct SeededRandom {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func int(_ range: ClosedRange<Int>) -> Int { range.lowerBound + Int(next() % UInt64(range.count)) }
}

@MainActor
struct V3ReadTests {
    // (2) Die SQL-Filter liefern dieselben Treffer wie das Swift-Modell der Filter (`SearchItemFilter`)
    @Test func twelveSearchesAgreeWithTheSwiftFilterModel() async throws {
        let store = try TestStore.make()
        let recent = Date()
        let aged = Date(timeIntervalSince1970: 1_000_000_000)
        let words = ["bericht", "rechnung", "urlaub", "foto", "notiz", "vertrag", "plan"]
        let extensions = ["pdf", "txt", "jpg", "mov", "zip", "docx", "html", "mp3"]
        var random = SeededRandom(state: 7)
        var media: [StoredMedium] = []
        for name in ["Eins", "Zwei", "Drei"] {
            let medium = try await store.insert(name: name)
            media.append(medium)
            var rootEntries: [ScannedEntry] = []
            for index in 0..<40 {
                let ext = extensions[random.int(0...(extensions.count - 1))]
                rootEntries.append(ScannedEntry(
                    name: "\(words[random.int(0...(words.count - 1))])-\(index).\(ext)", isFolder: false, sizeBytes: Int64(index),
                    modifiedAt: random.int(0...1) == 0 ? recent : aged
                ))
            }
            for folder in ["Ordner A", "Ordner B"] { rootEntries.append(ScannedEntry(name: folder, isFolder: true, modifiedAt: recent)) }
            _ = try await store.addRoot(medium: medium, entries: rootEntries, seenAt: recent)
            for folder in ["Ordner A", "Ordner B"] {
                let id = try #require(try await store.writer.folderID(mediumUUID: medium.uuid, path: [folder]))
                let inner = (0..<15).map {
                    ScannedEntry(name: "\(words[$0 % words.count]) innen \($0).\(extensions[$0 % extensions.count])", isFolder: false, modifiedAt: aged)
                } + [ScannedEntry(name: "Tief", isFolder: true)]
                _ = try await store.apply(medium: medium, parentID: id, entries: inner, seenAt: recent)
            }
        }
        var all: [StoredItem] = []
        for medium in media {
            var pending: [Int64?] = [nil]
            while let parent = pending.popLast() {
                for child in try await store.children(medium: medium, parentID: parent) {
                    all.append(child)
                    if child.isFolder { pending.append(child.id) }
                }
            }
        }
        var pdf = SearchFilters(); pdf.fileTypes = [.pdf]
        var docs = SearchFilters(); docs.fileTypes = [.documents]
        var media2 = SearchFilters(); media2.fileTypes = [.image, .video, .audio]
        var recentOnly = SearchFilters(); recentOnly.age = .lastMonth
        var older = SearchFilters(); older.age = .older
        var both = SearchFilters(); both.fileTypes = [.pdf, .text]; both.age = .lastMonth; both.combineWithAnd = true
        var folders = SearchFilters(); folders.fileTypes = [.folder]
        var oneMedium = SearchFilters(); oneMedium.selectAllMedia = false; oneMedium.mediumIDs = [try #require(media.dropFirst().first).uuid]
        var custom = SearchFilters(); custom.customExtensions = [".html"]
        let searches: [(String, SearchFilters)] = [
            ("bericht", SearchFilters()), ("RECHN", SearchFilters()), ("urlaub", pdf), ("foto", docs), ("", media2),
            ("notiz", recentOnly), ("vertrag", older), ("", both), ("ordner", folders), ("plan", oneMedium), ("", custom), ("innen", SearchFilters()),
        ]
        for (query, filters) in searches {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let expected = Set(all.filter { row in
                let item = IndexedItem(stored: row)
                let nameOK = trimmed.isEmpty || item.name.localizedCaseInsensitiveContains(trimmed)
                let mediumOK = filters.selectAllMedia || filters.mediumIDs.contains(row.mediumUUID)
                return nameOK && mediumOK && SearchItemFilter.matches(item, filters: filters, hasSearchTerm: !trimmed.isEmpty)
            }.map(\.id))
            let found = try await store.reader.search(query: query, filters: filters, limit: 500, maxDepth: nil, scope: nil)
            #expect(Set(found.map(\.id)) == expected, "\(query) \(filters)")
            let counted = try await store.reader.searchCount(query: query, filters: filters, maxDepth: nil, scope: nil)
            #expect(counted == expected.count, "\(query)")
            #expect(found.count == min(expected.count, 500))
        }
        #expect(try await store.reader.search(query: "bericht", filters: SearchFilters(), limit: 500, maxDepth: nil, scope: nil).isEmpty == false)
        for medium in media {
            let counts = try await store.counts(medium: medium)
            let stored = try #require(try await store.writer.medium(uuid: medium.uuid))
            #expect(stored.fileCount == counts.files && stored.folderCount == counts.folders)
        }
    }

    // (3) natürliche gemischte Sortierung über 3 Seiten
    @Test func mixedNaturalOrderHoldsAcrossThreePagesWithoutGaps() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Sortierung")
        var names: [String] = []
        for number in 1...70 { names.append("Datei \(number).txt") }
        for number in 1...20 { names.append("ordner \(number)") }
        for number in 1...10 { names.append("Äpfel \(number).md") }
        let entries = names.map { ScannedEntry(name: $0, isFolder: $0.hasPrefix("ordner")) }
        _ = try await store.addRoot(medium: medium, entries: entries)
        var seen: [StoredItem] = []
        var cursor: ItemChildrenCursor?
        var pages = 0
        while pages < 10 {
            let page = try await store.reader.childrenPage(mediumUUID: medium.uuid, parentID: nil, limit: 35, after: cursor, offset: 0, scope: nil)
            seen += page.items
            pages += 1
            guard let next = page.nextCursor else { break }
            cursor = next
        }
        #expect(pages >= 3)
        #expect(seen.count == names.count)
        let expected = names.map(Slug.make).sorted { NaturalOrder.compare($0, $1) == .orderedAscending }
        #expect(seen.map { Slug.make($0.name) } == expected)
        #expect(seen.map(\.name).starts(with: ["Äpfel 1.md", "Äpfel 2.md"]))
        // Ordner stehen zwischen den Dateien, nicht davor.
        let firstFolder = try #require(seen.firstIndex { $0.isFolder })
        #expect(firstFolder > 5)
        #expect(Set(seen.map(\.id)).count == names.count)
    }

    // (4) Stammlaute und Mediennamen
    @Test func searchFindsUmlautNamesByStemAndMediaByName() async throws {
        let store = try TestStore.make()
        let v3 = store.store
        var stick = StoredMedium(fsType: "exfat", volumeTotalBytes: 1, name: "Café Übergabe")
        stick.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        try await v3.upsertMedium(stick)
        _ = try await store.addRoot(medium: stick, entries: [
            ScannedEntry(name: "Ärger im Büro.txt", isFolder: false),
            ScannedEntry(name: "Straße.png", isFolder: false),
            ScannedEntry(name: "nichts.txt", isFolder: false),
        ])
        for term in ["arg", "ÄRG", "Ärger", "ärger im bu"] {
            let hits = try await v3.search(query: term, filters: SearchFilters(), limit: 10, maxDepth: nil, scope: nil)
            #expect(hits.map(\.name) == ["Ärger im Büro.txt"], "\(term)")
        }
        #expect(try await v3.search(query: "strasse", filters: SearchFilters(), limit: 10, maxDepth: nil, scope: nil).map(\.name) == ["Straße.png"])
        for term in ["cafe", "UBERGABE", "Café", "ü"] {
            let found = try await v3.searchMedia(query: term)
            #expect(found.map(\.uuid) == [stick.uuid], "\(term)")
        }
        #expect(try await v3.searchMedia(query: "kein").isEmpty)
        #expect(try await v3.searchCount(query: "arg", filters: SearchFilters(), maxDepth: nil, scope: nil) == 1)
    }

    // (5) parallele Suche = einzelne Abfrage
    @Test func parallelSearchGivesExactlyTheSameHitsAsOneQuery() async throws {
        let store = try TestStore.make()
        let v3 = store.store
        let medium = try await store.insert(name: "Viele")
        let syllables = ["bil", "der", "laub", "ber", "ich", "tag", "bü", "ro", "Ent", "wurf", "Ma", "rie", "Ur", "kunde"]
        var random = SeededRandom(state: 99)
        var allNames: [String] = []
        var entries: [ScannedEntry] = []
        for index in 0..<50_000 {
            let name = "\(syllables[random.int(0...13)])\(syllables[random.int(0...13)]) \(syllables[random.int(0...13)])-\(index).txt"
            allNames.append(name)
            entries.append(ScannedEntry(name: name, isFolder: false, sizeBytes: 1))
        }
        try await v3.applyDirectories(mediumUUID: medium.uuid, batches: [(nil, "/", 1, entries, true)], seenAt: Date())
        await v3.setSearchParallelism(4)
        let ranges = try await v3.idRanges()
        #expect(ranges.count == 4)
        for terms in 0..<1_000 {
            let name = Slug.make(allNames[random.int(0...(allNames.count - 1))])
            let length = random.int(3...6)
            let start = random.int(0...max(0, name.count - length))
            let term = String(name.dropFirst(start).prefix(length))
            await v3.setSearchParallelism(1)
            let single = try await v3.search(query: term, filters: SearchFilters(), limit: 500, maxDepth: nil, scope: nil).map(\.id)
            let singleCount = try await v3.searchCount(query: term, filters: SearchFilters(), maxDepth: nil, scope: nil)
            await v3.setSearchParallelism(4)
            let parallel = try await v3.search(query: term, filters: SearchFilters(), limit: 500, maxDepth: nil, scope: nil).map(\.id)
            let parallelCount = try await v3.searchCount(query: term, filters: SearchFilters(), maxDepth: nil, scope: nil)
            #expect(single == parallel, "\(terms): '\(term)'")
            #expect(singleCount == parallelCount, "\(terms): '\(term)'")
        }
    }

    // (6) Pfad über 6 Ebenen
    @Test func pathIsRightOverSixLevelsInEveryReadingWay() async throws {
        let store = try TestStore.make()
        let medium = try await store.insert(name: "Pfad")
        var parent: Int64?
        let names = ["eins", "zwei", "drei", "vier", "fünf", "sechs"]
        for name in names {
            let created = try await store.apply(medium: medium, parentID: parent, entries: [ScannedEntry(name: name, isFolder: true)])
            parent = try #require(created.first { $0.name == name }?.id)
        }
        let file = try await store.apply(medium: medium, parentID: parent, entries: [ScannedEntry(name: "Blatt.txt", isFolder: false)])
        let fileID = try #require(file.first?.id)
        let expected = "/eins/zwei/drei/vier/fünf/sechs/Blatt.txt"
        #expect(file.first?.path == expected)
        #expect(file.first?.depth == 7)
        #expect(try await store.item(id: fileID)?.path == expected)
        #expect(try await store.reader.search(query: "blatt", filters: SearchFilters(), limit: 5, maxDepth: nil, scope: nil).first?.path == expected)
        try await store.writer.setFavorite(itemID: fileID, true)
        #expect(try await store.reader.favorites(maxDepth: nil, scope: nil).first?.path == expected)
        let folder = try await store.reader.search(query: "sechs", filters: SearchFilters(), limit: 5, maxDepth: nil, scope: nil)
        #expect(folder.first?.path == "/eins/zwei/drei/vier/fünf/sechs/")
        let folders = try await store.writer.folders(mediumUUID: medium.uuid, depth: 6, limit: 10, offset: 0)
        #expect(folders.map(\.path) == ["/eins/zwei/drei/vier/fünf/sechs/"])
    }

    // (7) Abfragepläne
    @Test func queryPlansUseTheColumnIndexAndTheSearchIndex() async throws {
        let store = try TestStore.make()
        let v3 = store.store
        let medium = try await store.insert(name: "Plan")
        _ = try await store.addRoot(medium: medium, entries: [ScannedEntry(name: "a.txt", isFolder: false)])
        let (columns, search, byDate, byNameDesc): (String, String, String, String) = try await v3.pool.read { db in
            let plan = try SearchPlanV3.make(db, query: "abc", filters: SearchFilters(), maxDepth: nil)
            func detail(_ sql: String, _ arguments: StatementArguments) throws -> String {
                try Row.fetchAll(db, sql: "EXPLAIN QUERY PLAN " + sql, arguments: arguments).map { (row: Row) -> String in row["detail"] }.joined(separator: " | ")
            }
            return (
                try detail(IndexStoreV3.columnFirstPageSQL, [1, 5, 100, 0]),
                try detail(IndexStoreV3.searchHitsSQL(whereClause: plan.whereClause), plan.statementArguments(extra: [500.databaseValue])),
                // bug.0.4.038: Datum absteigend über die Suchhilfe `items_modified`, ohne Nachsortieren.
                try detail(
                    IndexStoreV3.searchSortedHitsSQL(whereClause: plan.whereClause, sort: SearchSort(column: .date, direction: .descending)),
                    plan.statementArguments(extra: [500.databaseValue, 0.databaseValue])
                ),
                // Review 038: Name absteigend in natürlicher Reihenfolge, ebenfalls über eine Suchhilfe.
                try detail(
                    IndexStoreV3.searchSortedHitsSQL(whereClause: plan.whereClause, sort: SearchSort(column: .name, direction: .descending)),
                    plan.statementArguments(extra: [500.databaseValue, 0.databaseValue])
                )
            )
        }
        #expect(byDate.contains("items_modified"), "\(byDate)")
        #expect(!byDate.contains("TEMP B-TREE FOR ORDER BY"), "\(byDate)")
        // bug.0.4.077: genauer Indexname (`items_search` wäre auch Teil von `items_search_natural`).
        #expect(planIndexNames(byNameDesc).contains("items_search_natural"), "\(byNameDesc)")
        #expect(!byNameDesc.contains("TEMP B-TREE FOR ORDER BY"), "\(byNameDesc)")
        #expect(columns.contains("items_children"), "\(columns)")
        #expect(!columns.contains("TEMP B-TREE"), "\(columns)")
        #expect(planIndexNames(search).contains("items_search_natural"), "\(search)")
        // Der Index liefert die Treffer nach Suchname; nur gleiche Namen werden nach Kennung nachsortiert („RIGHT PART“).
        #expect(!search.contains("TEMP B-TREE FOR ORDER BY"), "\(search)")
    }
}
