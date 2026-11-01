//
//  ColumnFilterHitsTests.swift
//  DiskArchiveTests
//
//  todo.0.4.2.003 (Konzept `suche-navigation.md` 5): Treffermenge der Spaltenansicht. Ordner mit einem passenden
//  Eintrag irgendwo darunter sind normal, die übrigen leise; „passend“ genau wie in der Suche. Ordner sind immer
//  sichtbar, ihr eigenes Datum zählt nicht; beim Dateityp „Ordner“ zählt ein passender Ordner selbst.
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

/// Baum für die Testdatenbank: Name, Ordner ja/nein, Datum, Kinder.
struct ColumnFilterTreeNode {
    var name: String
    var isFolder: Bool
    var modifiedAt: Date?
    var children: [ColumnFilterTreeNode] = []

    static func folder(_ name: String, _ children: [ColumnFilterTreeNode] = [], date: Date? = nil) -> Self {
        Self(name: name, isFolder: true, modifiedAt: date, children: children)
    }

    static func file(_ name: String, date: Date? = Date()) -> Self {
        Self(name: name, isFolder: false, modifiedAt: date)
    }
}

/// Testdatenbank mit einem Medium und einem Baum; `ids` ordnet Pfade („A/B“) den Zeilenkennungen zu.
struct ColumnFilterTreeRig {
    let directory: URL
    let store: IndexStoreV3
    let mediumID: UUID
    var ids: [String: Int64] = [:]

    static func make(_ tree: [ColumnFilterTreeNode], name: String = "Baum") async throws -> ColumnFilterTreeRig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-column-filter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: name, decision: .index, indexStatus: .indexed, completedDepth: 9)
        try await store.upsertMedium(medium)
        var rig = ColumnFilterTreeRig(directory: directory, store: store, mediumID: medium.uuid)
        try await rig.insert(tree, medium: medium.uuid, parentID: nil, prefix: "")
        return rig
    }

    /// Zweites Medium mit eigenem Baum in derselben Datenbank (Pfade mit Präfix „<Name>:“).
    mutating func addMedium(_ tree: [ColumnFilterTreeNode], name: String) async throws -> UUID {
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: name, decision: .index, indexStatus: .indexed, completedDepth: 9)
        try await store.upsertMedium(medium)
        try await insert(tree, medium: medium.uuid, parentID: nil, prefix: name + ":")
        return medium.uuid
    }

    private mutating func insert(_ nodes: [ColumnFilterTreeNode], medium: UUID, parentID: Int64?, prefix: String) async throws {
        guard !nodes.isEmpty else { return }
        try await store.applyDirectory(
            mediumUUID: medium,
            parentID: parentID,
            entries: nodes.map { ScannedEntry(name: $0.name, isFolder: $0.isFolder, sizeBytes: $0.isFolder ? nil : 1, modifiedAt: $0.modifiedAt) },
            seenAt: Date()
        )
        let rows = try await store.children(mediumUUID: medium, parentID: parentID)
        for node in nodes {
            let row = try #require(rows.first { $0.name == node.name }, "\(node.name) fehlt")
            let path = prefix.isEmpty || prefix.hasSuffix(":") ? prefix + node.name : prefix + "/" + node.name
            ids[path] = row.id
            if node.isFolder { try await insert(node.children, medium: medium, parentID: row.id, prefix: path) }
        }
    }

    /// Pfade der Ordner mit Treffer.
    func hitPaths(_ filters: SearchFilters) async throws -> Set<String> {
        let hits = try await store.folderIDsWithHits(mediumUUID: mediumID, filters: filters, maxDepth: nil, scope: nil)
        return Set(ids.filter { hits.contains($0.value) }.keys)
    }

    func close() {
        try? FileManager.default.removeItem(at: directory)
    }
}

@Suite(.serialized) @MainActor
struct ColumnFilterHitsTests {
    private static let day: TimeInterval = 86_400
    private static let now = Date()

    private static var sample: [ColumnFilterTreeNode] {
        let old = now.addingTimeInterval(-400 * day)
        return [
            .folder("A", [
                .folder("B", [.folder("C", [.folder("D", [.file("bild.cr2", date: now.addingTimeInterval(-2 * day))], date: old)], date: old)], date: old),
                .folder("X", [.file("text.txt", date: old)], date: old),
            ], date: old),
            .folder("F", [.folder("leer", date: old)], date: old),
        ]
    }

    private static func filters(_ types: Set<SearchFileTypeFilter> = [], age: SearchAgeFilter? = nil, and: Bool = false) -> SearchFilters {
        var filters = SearchFilters()
        filters.fileTypes = types
        filters.age = age
        filters.combineWithAnd = and
        return filters
    }

    // Gegenprobe 1: Treffer beliebig tief, Hochlaufen bis zur Wurzel; Alter und Und/Oder wie in der Suche.
    @Test func foldersWithAHitBelowAreNormal() async throws {
        let rig = try await ColumnFilterTreeRig.make(Self.sample)
        defer { rig.close() }
        let chain: Set<String> = ["A", "A/B", "A/B/C", "A/B/C/D"]
        #expect(try await rig.hitPaths(Self.filters([.image])) == chain)
        #expect(try await rig.hitPaths(Self.filters([.image], age: .lastMonth, and: true)) == chain, "Bild und letzter Monat")
        #expect(try await rig.hitPaths(Self.filters([.image], age: .lastYear, and: true)).isSuperset(of: chain))
        #expect(try await rig.hitPaths(Self.filters([.image], age: .last24Hours, and: true)).isEmpty, "Bild ist zwei Tage alt")
        // Oder: Text passt über den Typ, Bild über das Alter.
        let or = try await rig.hitPaths(Self.filters([.text], age: .lastMonth))
        #expect(or == chain.union(["A/X"]), "Oder: \(or.sorted())")
        // Leise: X (bei Bild), F, leer.
        let quiet = Set(rig.ids.keys).subtracting(try await rig.hitPaths(Self.filters([.image])))
        #expect(quiet.isSuperset(of: ["A/X", "F", "F/leer"]))
    }

    // Gegenprobe 1, Abgleich: dieselbe Menge wie aus `SearchItemFilter.matches` über alle Einträge und Hochlaufen.
    @Test func sameFoldersAsTheSearchRuleOverAGeneratedTree() async throws {
        var generator = SystemRandomNumberGenerator()
        let extensions = ["jpg", "cr2", "txt", "pdf", "mp3", "docx", "zip", "md"]
        func tree(depth: Int, prefix: String) -> [ColumnFilterTreeNode] {
            var nodes: [ColumnFilterTreeNode] = []
            let folders = depth < 4 ? Int.random(in: 2...4, using: &generator) : 0
            for index in 0..<folders {
                let date = Self.now.addingTimeInterval(-Double(Int.random(in: 0...500, using: &generator)) * Self.day - Self.day / 2)
                nodes.append(.folder("\(prefix)o\(index)", tree(depth: depth + 1, prefix: "\(prefix)o\(index)-"), date: date))
            }
            for index in 0..<Int.random(in: 5...40, using: &generator) {
                let ext = extensions[Int.random(in: 0..<extensions.count, using: &generator)]
                let date = Self.now.addingTimeInterval(-Double(Int.random(in: 0...500, using: &generator)) * Self.day - Self.day / 2)
                nodes.append(.file("\(prefix)d\(index).\(ext)", date: date))
            }
            return nodes
        }
        let rig = try await ColumnFilterTreeRig.make(tree(depth: 0, prefix: ""))
        defer { rig.close() }
        // Alle Einträge mit Elternordner.
        var all: [(item: IndexedItem, parent: Int64?)] = []
        func walk(_ parent: Int64?) async throws {
            for row in try await rig.store.children(mediumUUID: rig.mediumID, parentID: parent) {
                all.append((IndexedItem(stored: row, parentPath: []), parent))
                if row.isFolder { try await walk(row.id) }
            }
        }
        try await walk(nil)
        try #require(all.count > 1_000, "Baum zu klein: \(all.count)")
        let parents = Dictionary(all.compactMap { entry in entry.item.rowID.map { ($0, entry.parent) } }, uniquingKeysWith: { first, _ in first })
        let cases: [SearchFilters] = [
            Self.filters([.image]),
            Self.filters([.pdf], age: .lastMonth, and: true),
            Self.filters([.pdf, .audio], age: .lastWeek),
            Self.filters(age: .last3Months),
            Self.filters([.folder]),
            Self.filters([.folder], age: .lastWeek),
            {
                var custom = Self.filters()
                custom.customExtensions = [".md"]
                return custom
            }(),
        ]
        for filters in cases {
            var expected = Set<Int64>()
            for entry in all where SearchItemFilter.matches(entry.item, filters: filters) {
                var current: Int64? = filters.fileTypes.contains(.folder) && entry.item.isFolder ? entry.item.rowID : entry.parent
                while let id = current, expected.insert(id).inserted { current = parents[id] ?? nil }
            }
            let hits = try await rig.store.folderIDsWithHits(mediumUUID: rig.mediumID, filters: filters, maxDepth: nil, scope: nil)
            #expect(hits == expected, "\(filters): Speicher \(hits.count), Suche \(expected.count)")
        }
    }

    // Gegenprobe 2: Das Alter eines Ordners zählt nicht – alter Ordner mit neuer PDF ist normal und sichtbar.
    @Test func folderAgeDoesNotCount() async throws {
        let old = Self.now.addingTimeInterval(-700 * Self.day)
        let rig = try await ColumnFilterTreeRig.make([.folder("Alt", [.file("neu.pdf", date: Self.now)], date: old)])
        defer { rig.close() }
        let filters = Self.filters([.pdf], age: .lastMonth, and: true)
        #expect(try await rig.hitPaths(filters) == ["Alt"])
        let root = try await rig.store.children(mediumUUID: rig.mediumID, parentID: nil).map { IndexedItem(stored: $0, parentPath: []) }
        #expect(ColumnBrowserFiltering.visibleItems(root, filters: filters).map(\.name) == ["Alt"], "alter Ordner ausgeblendet")
    }

    // Gegenprobe 3: Dateityp „Ordner“ – Treffer sind die Ordner selbst; Dateien fallen weg.
    @Test func folderTypeCountsTheFolderItself() async throws {
        let rig = try await ColumnFilterTreeRig.make(Self.sample)
        defer { rig.close() }
        let filters = Self.filters([.folder])
        #expect(try await rig.hitPaths(filters) == Set(rig.ids.filter { !$0.key.contains(".") }.keys), "leerer Ordner leise")
        let leer = try await rig.store.children(mediumUUID: rig.mediumID, parentID: rig.ids["A/X"]).map { IndexedItem(stored: $0, parentPath: ["A", "X"]) }
        #expect(ColumnBrowserFiltering.visibleItems(leer, filters: filters).isEmpty, "Datei bei Typ „Ordner“ sichtbar")
    }

    // Gegenprobe 8: Option entfällt; alte Einstellung „aus“ lädt und Ordner bleiben sichtbar.
    @Test func oldSettingLoadsAndFoldersStayVisible() throws {
        let old = #"{"scanDepth":4,"showFoldersRegardlessOfFilter":false,"excludedPatterns":[]}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(old.utf8))
        #expect(settings.scanDepth == 4)
        let persisted = try JSONDecoder().decode(PersistedAppSettings.self, from: Data(old.utf8))
        #expect(persisted.scanDepth == 4)
        let folder = IndexedItem(id: UUID(), name: "Alt", kind: .folder, parentPath: [], modifiedAt: Date(timeIntervalSince1970: 0), sizeBytes: nil)
        #expect(ColumnBrowserFiltering.visibleItems([folder], filters: Self.filters([.pdf], age: .lastWeek, and: true)).count == 1)
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("DiskArchive/Views/Settings/SettingsGeneralTab.swift")
        let text = try String(contentsOf: source, encoding: .utf8)
        #expect(!text.contains("showFoldersRegardlessOfFilter"), "Option noch in den Einstellungen")
    }
}
