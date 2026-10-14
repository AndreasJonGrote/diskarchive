//
//  IndexStoreV3TestHooks.swift
//  diskindexTests
//
//  todo.0.4.010 — Test-only APIs aus der App hierher verschoben.
//

import Foundation
import GRDB
@testable import diskindex

extension IndexStoreV3 {
    /// Erste Seite einer Spalte (Abfrageplan-Tests).
    nonisolated static let columnFirstPageSQL = """
        SELECT id FROM items
        WHERE storageID = ? AND parentID IS ? AND status = 0
        ORDER BY slug COLLATE "\(NaturalOrder.collationName)", id LIMIT ? OFFSET ?
        """

    func statusOfItem(id: Int64) async throws -> Int? {
        try await pool.read { db in try Int.fetchOne(db, sql: "SELECT status FROM items WHERE id = ?", arguments: [id]) }
    }

    func searchMedia(query: String) async throws -> [StoredMedium] {
        let slug = Slug.make(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return try await pool.read { db in
            let all = try MediumCodecV3.fetchAll(
                db,
                whereClause: slug.isEmpty ? "" : "WHERE slug LIKE ? ESCAPE '\\'",
                arguments: slug.isEmpty ? [] : ["%" + SearchPlanV3.escapeLike(slug) + "%"]
            )
            return all.filter { !$0.isForgotten }
        }
    }

    func storedNames() async throws -> [String] {
        try await pool.read { db in try String.fetchAll(db, sql: "SELECT name FROM items WHERE status = 0 ORDER BY id") }
    }

    func recordMaintenanceDebt(_ rows: Int) async {
        guard rows > 0 else { return }
        try? await pool.write { db in
            try DatabaseMaintenance.addDebt(db, rows: rows)
        }
    }

    func orphanCount() async throws -> Int {
        try await pool.read { db in
            try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM items AS child
                    LEFT JOIN items AS parent ON parent.id = child.parentID
                    WHERE child.parentID IS NOT NULL AND parent.id IS NULL
                    """
            ) ?? 0
        }
    }

    func databaseFileBytes() -> Int {
        let path = pool.path
        let main = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue ?? 0
        let wal = (try? FileManager.default.attributesOfItem(atPath: path + "-wal")[.size] as? NSNumber)?.intValue ?? 0
        return main + wal
    }
}
