//
//  IndexStoreV3+ColumnFilter.swift
//  DiskArchive
//
//  todo.0.4.2.003 (Konzept `suche-navigation.md` 5): Filter in der Spaltenansicht. Für das ganze geöffnete Medium
//  einmal ausrechnen, welche Ordner irgendwo darunter einen Treffer haben – „passend“ genau wie in der Suche
//  (`SearchPlanV3`), dann über `parentID` bis zur Wurzel hoch. Nur lesen, kein Index, kein Schema.
//

import Foundation
import GRDB

extension IndexStoreV3 {
    /// Ordner (Zeilenkennung) mit Treffer darunter. Beim Dateityp „Ordner“ zählt ein passender Ordner auch selbst
    /// (Treffer sind dann die Ordner). Zwei Lesezugriffe; dazwischen endet ein abgebrochener Auftrag. `@concurrent`:
    /// auch das Hochlaufen läuft nie auf main (Regel 5).
    @concurrent nonisolated func folderIDsWithHits(
        mediumUUID: UUID,
        filters: SearchFilters,
        maxDepth: Int?,
        scope: IndexScope?
    ) async throws -> Set<Int64> {
        let scoped = {
            var copy = filters
            copy.selectAllMedia = false
            copy.mediumIDs = [mediumUUID]
            return copy
        }()
        let foldersCount = filters.fileTypes.contains(.folder)
        let depth = scope?.maxDepth ?? maxDepth
        let checksNames = scope?.checksNames ?? false
        // Elternordner (bzw. beim Typ „Ordner“ der Ordner selbst) aller passenden Einträge.
        let seeds = try await pool.read { db -> Set<Int64> in
            let plan = try SearchPlanV3.make(db, query: "", filters: scoped, maxDepth: depth)
            let rows = try Row.fetchCursor(
                db,
                sql: "SELECT i.id, i.parentID, i.isFolder, i.name, i.depth FROM items i WHERE \(plan.whereClause)",
                arguments: plan.statementArguments()
            )
            var seeds = Set<Int64>()
            while let row = try rows.next() {
                if checksNames, let scope, scope.hides(name: row["name"], depth: row["depth"]) { continue }
                if foldersCount, row["isFolder"] as Bool {
                    seeds.insert(row["id"])
                } else if let parent: Int64 = row["parentID"] {
                    seeds.insert(parent)
                }
            }
            return seeds
        }
        try Task.checkCancellation()
        guard !seeds.isEmpty else { return [] }
        // Ordnerkette des Mediums einmal in den Speicher: Ordner → Elternordner (Ordner der Wurzel fehlen).
        let parents = try await pool.read { db -> [Int64: Int64] in
            guard let storageID = try MediumCodecV3.storageRowID(db, uuid: mediumUUID) else { return [:] }
            let rows = try Row.fetchCursor(
                db,
                sql: "SELECT id, parentID FROM items WHERE storageID = ? AND isFolder = 1 AND status = 0 AND parentID IS NOT NULL",
                arguments: [storageID]
            )
            var parents: [Int64: Int64] = [:]
            while let row = try rows.next() {
                parents[row["id"]] = row["parentID"]
            }
            return parents
        }
        try Task.checkCancellation()
        // Hochlaufen; ein Weg endet am ersten schon markierten Ordner.
        var marked = Set<Int64>()
        for seed in seeds {
            var current: Int64? = seed
            while let id = current, marked.insert(id).inserted {
                current = parents[id]
            }
        }
        return marked
    }
}
