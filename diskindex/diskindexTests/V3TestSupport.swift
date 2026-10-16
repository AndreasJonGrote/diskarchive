//
//  V3TestSupport.swift
//  diskindexTests
//
//  Prüfstand für `IndexStoreV3` (Aufgaben 231–233).
//

import Foundation
import GRDB
import Testing
@testable import diskindex

/// Prüfstand für die Speicherschicht (Aufgabe 231/232/233): eine frische Datei im Temp-Ordner, Schreiben und Lesen
/// über `IndexStoreV3`, Sammeln der `IndexChange`-Meldungen.
final class TestStore: @unchecked Sendable {
    let directory: URL
    let store: IndexStoreV3
    let pool: DatabasePool
    var writer: IndexStoreV3 { store }
    var reader: IndexStoreV3 { store }
    private let closeDatabase: @Sendable () -> Void

    static func make() throws -> TestStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-store-\(UUID().uuidString)", isDirectory: true)
        let store = try IndexStoreV3.open(at: directory.appendingPathComponent("archive.sqlite"))
        let pool = store.pool
        return TestStore(directory: directory, store: store, pool: pool) { try? pool.close() }
    }

    private init(directory: URL, store: IndexStoreV3, pool: DatabasePool, closeDatabase: @escaping @Sendable () -> Void) {
        self.directory = directory
        self.store = store
        self.pool = pool
        self.closeDatabase = closeDatabase
    }

    deinit {
        closeDatabase()
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: Schreiben

    func insert(name: String, fsType: String = "apfs", bytes: Int64 = 1_000) async throws -> StoredMedium {
        let medium = StoredMedium(fsType: fsType, volumeTotalBytes: bytes, name: name)
        try await writer.upsertMedium(medium)
        return medium
    }

    func apply(medium: StoredMedium, parentID: Int64?, entries: [ScannedEntry], seenAt: Date = Date()) async throws -> [StoredItem] {
        try await writer.applyDirectory(mediumUUID: medium.uuid, parentID: parentID, entries: entries, seenAt: seenAt)
        return try await children(medium: medium, parentID: parentID)
    }

    func addRoot(medium: StoredMedium, entries: [ScannedEntry], seenAt: Date = Date()) async throws -> [StoredItem] {
        try await apply(medium: medium, parentID: nil, entries: entries, seenAt: seenAt)
    }

    // MARK: Lesen (sichtbare Einträge)

    func children(medium: StoredMedium, parentID: Int64?) async throws -> [StoredItem] {
        try await reader.children(mediumUUID: medium.uuid, parentID: parentID, limit: nil, offset: 0, scope: nil)
    }

    func item(id: Int64) async throws -> StoredItem? {
        try await reader.item(id: id)
    }

    func counts(medium: StoredMedium) async throws -> (files: Int, folders: Int) {
        try await reader.counts(mediumUUID: medium.uuid, scope: nil)
    }

    /// Kennungen der sichtbaren Favoriten.
    func favoriteIDs() async throws -> [Int64] {
        try await reader.favorites(maxDepth: nil, scope: nil).map(\.id).sorted()
    }

    /// Der Eintrag steht noch in der Tabelle, ist aber „verschwunden“ (`status = 2`) und für alle Lesewege unsichtbar.
    func isGone(_ id: Int64) async throws -> Bool {
        try await store.statusOfItem(id: id) == ItemStatus.gone.rawValue
    }

    /// Favoriten-Zeile des Eintrags (auch für verschwundene).
    func hasFavoriteRow(_ id: Int64) async throws -> Bool {
        try await store.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM favorites WHERE itemID = ?", arguments: [id]) == 1
        }
    }

    // MARK: Meldungen

    /// Sammelt alle `IndexChange`-Meldungen, die `body` auslöst. Wartet auf die Zahl der Meldungen (Zählung der
    /// Schicht), nicht auf eine Uhrzeit: stabil auch bei voller Auslastung.
    func collectChanges(_ body: () async throws -> Void) async throws -> [IndexChange] {
        let stream = store.changes
        let before = await store.changeGeneration
        let collector = ChangeCollector()
        let listener = Task { @MainActor in
            for await event in stream where event.generation > before { collector.add(event.change) }
        }
        try await body()
        let after = await store.changeGeneration
        let complete = await waitUntil { collector.values.count >= after - before }
        #expect(complete, "Meldungen nicht vollständig angekommen")
        listener.cancel()
        return collector.values
    }
}

final class ChangeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var changes: [IndexChange] = []

    func add(_ change: IndexChange) {
        lock.lock()
        changes.append(change)
        lock.unlock()
    }

    var values: [IndexChange] {
        lock.lock()
        defer { lock.unlock() }
        return changes
    }
}

/// Test-Hilfe: eine Datenbankdatei mit dem Schema V3 (Pool), wie mehrere Prüfstände sie teilen.
final class TestDatabase: @unchecked Sendable {
    let pool: DatabasePool

    init(fileURL: URL) throws {
        pool = try SchemaV3.openPool(at: fileURL)
    }

    func close() throws {
        try pool.close()
    }
}

extension IndexStoreV3 {
    /// Zweiter Speicher auf derselben Datenbank (Neustart-Tests).
    init(database: TestDatabase) {
        self.init(pool: database.pool)
    }
}
