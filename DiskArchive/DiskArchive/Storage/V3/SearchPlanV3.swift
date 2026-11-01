//
//  SearchPlanV3.swift
//  DiskArchive
//
//  Aufgabe 232: Such- und Filterbedingungen auf dem Schema V3. Nur Spalten aus `items` (`slug`, `kind`, `extID`,
//  `modifiedAt`, `storageID`, `depth`, `status`), damit Zählen und Auflisten ohne Verknüpfungen auskommen.
//  Regeln: Und/Oder, „ohne Datum schließt der Altersfilter nicht aus“.
//

import Foundation
import GRDB

nonisolated struct SearchPlanV3: Sendable {
    var conditions: [String]
    var arguments: [DatabaseValue]

    func statementArguments(extra: [DatabaseValue] = []) -> StatementArguments {
        StatementArguments(arguments + extra)
    }

    /// `nil`: nichts kann passen (z. B. leere Medienauswahl).
    static func make(
        _ db: Database,
        query: String,
        filters: SearchFilters,
        maxDepth: Int?,
        isFolder: Bool? = nil,
        now: Date = Date()
    ) throws -> SearchPlanV3 {
        var conditions = ["i.status = 0"]
        var arguments: [DatabaseValue] = []
        let slug = Slug.make(query)
        if !slug.isEmpty {
            conditions.append("i.slug LIKE ? ESCAPE '\\'")
            arguments.append(("%" + escapeLike(slug) + "%").databaseValue)
        }
        if filters.selectAllMedia {
            // bug.0.4.224: Einträge vergessener Medien, die noch gelöscht werden, sind nie Treffer.
            let pending = try MediumCodecV3.pendingDeletionStorageIDs(db)
            if !pending.isEmpty {
                conditions.append("i.storageID NOT IN (\(pending.map(String.init).joined(separator: ",")))")
            }
        } else {
            let uuids = filters.mediumIDs.map { MediumCodecV3.data($0).databaseValue }
            if uuids.isEmpty {
                conditions.append("0")
            } else {
                let marks = uuids.map { _ in "?" }.joined(separator: ",")
                let ids = try Int64.fetchAll(db, sql: "SELECT id FROM storages WHERE uuid IN (\(marks))", arguments: StatementArguments(uuids))
                if ids.isEmpty {
                    conditions.append("0")
                } else {
                    conditions.append("i.storageID IN (\(ids.map(String.init).joined(separator: ",")))")
                }
            }
        }
        let type = try typeClause(db, filters)
        let age = ageClause(filters.age, now: now)
        if let type, let age {
            if filters.effectiveCombineWithAnd(hasSearchTerm: !query.isEmpty) {
                conditions.append("\(type) AND \(age.sql)")
            } else {
                conditions.append("(\(type) OR \(age.sql))")
            }
            arguments.append(contentsOf: age.arguments)
        } else if let type {
            conditions.append(type)
        } else if let age {
            conditions.append(age.sql)
            arguments.append(contentsOf: age.arguments)
        }
        if let maxDepth {
            conditions.append("i.depth <= ?")
            arguments.append(maxDepth.databaseValue)
        }
        // bug.0.4.038 (REPORT 130): Popover holt Ordner und Dateien je mit eigener kleiner Abfrage.
        if let isFolder {
            conditions.append(isFolder ? "i.isFolder = 1" : "i.isFolder = 0")
        }
        return SearchPlanV3(conditions: conditions, arguments: arguments)
    }

    var whereClause: String { conditions.joined(separator: " AND ") }

    // MARK: Dateityp

    /// Dateityp-Gruppe als Bedingung über `kind`/`isFolder`/`extID`; `nil` ohne Typfilter.
    private static func typeClause(_ db: Database, _ filters: SearchFilters) throws -> String? {
        guard filters.hasFileTypeFilter else { return nil }
        var parts: [String] = []
        let programs = ItemKind.programs.rawValue
        if filters.fileTypes.contains(.folder) {
            parts.append("(i.isFolder = 1 AND i.kind <> \(programs) AND NOT EXISTS (SELECT 1 FROM item_details d WHERE d.itemID = i.id AND d.isPackage = 1))")
        }
        if filters.fileTypes.contains(.programs) {
            parts.append("(i.kind = \(programs))")
        }
        var kinds = Set<ItemKind>()
        for type in filters.fileTypes where type != .folder && type != .programs {
            kinds.formUnion(ItemKind.kinds(for: type))
        }
        if !kinds.isEmpty {
            parts.append("(i.isFolder = 0 AND i.kind IN (\(kinds.map(\.rawValue).sorted().map(String.init).joined(separator: ","))))")
        }
        // Eigene Endungen: vorher in `extensions` nachschlagen.
        var customNames: [String] = []
        for raw in filters.customExtensions {
            let lowered = raw.lowercased()
            customNames.append(lowered.hasPrefix(".") ? String(lowered.dropFirst()) : lowered)
        }
        if !customNames.isEmpty {
            let marks = customNames.map { _ in "?" }.joined(separator: ",")
            let ids = try Int64.fetchAll(db, sql: "SELECT id FROM extensions WHERE ext IN (\(marks))", arguments: StatementArguments(customNames))
            if !ids.isEmpty {
                parts.append("(i.isFolder = 0 AND i.extID IN (\(ids.map(String.init).joined(separator: ","))))")
            }
        }
        if parts.isEmpty { return "0" }
        return "(" + parts.joined(separator: " OR ") + ")"
    }

    // MARK: Alter

    private struct Clause {
        var sql: String
        var arguments: [DatabaseValue]
    }

    private static func ageClause(_ age: SearchAgeFilter?, now: Date) -> Clause? {
        guard let age else { return nil }
        let calendar = Calendar.current
        func limit(_ component: Calendar.Component, _ value: Int) -> Date {
            calendar.date(byAdding: component, value: -value, to: now) ?? now
        }
        let boundary: Date
        let comparison: String
        switch age {
        case .last24Hours: (boundary, comparison) = (limit(.hour, 24), ">=")
        case .last2Days: (boundary, comparison) = (limit(.day, 2), ">=")
        case .lastWeek: (boundary, comparison) = (limit(.day, 7), ">=")
        case .lastMonth: (boundary, comparison) = (limit(.month, 1), ">=")
        case .last3Months: (boundary, comparison) = (limit(.month, 3), ">=")
        case .last6Months: (boundary, comparison) = (limit(.month, 6), ">=")
        case .last9Months: (boundary, comparison) = (limit(.month, 9), ">=")
        case .lastYear: (boundary, comparison) = (limit(.year, 1), ">=")
        case .older: (boundary, comparison) = (limit(.year, 1), "<")
        }
        // Ohne Datum schließt der Filter nicht aus, analog zu SearchItemFilter.
        return Clause(
            sql: "(i.modifiedAt IS NULL OR i.modifiedAt \(comparison) ?)",
            arguments: [SchemaTime.seconds(boundary).databaseValue]
        )
    }

    static func escapeLike(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
