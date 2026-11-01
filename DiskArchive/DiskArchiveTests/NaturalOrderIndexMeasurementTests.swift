//
//  NaturalOrderIndexMeasurementTests.swift
//  DiskArchiveTests
//
//  bug.0.4.077 — Messung vor/nach dem Index `items_search_natural`: Indizieren von gut 1 Mio. Einträgen synthetisch
//  über den Store (`applyDirectories`, Stücke von 2.000 Einträgen wie beim Indexer), Dauer und Größe der Datenbank.
//  Läuft nur mit DISKARCHIVE_MEASURE=1 (Regel 8: Leistung nur im Release-Build), z. B.
//  `TEST_RUNNER_DISKARCHIVE_MEASURE=1 xcodebuild test -configuration Release … -only-testing:DiskArchiveTests/MeasurementTestGroup/NaturalOrderIndexMeasurementTests`.
//  Ergebnis als Zeile `MESSUNG …` im Protokoll und, mit DISKARCHIVE_MEASURE_OUT, angehängt an diese Datei.
//  DISKARCHIVE_MEASURE_VARIANT (Nacharbeit 18.10., beide Fassungen aus demselben Build im Wechsel):
//  `vorher` = Stand vor bug.0.4.077 (ohne `items_search_natural`, alter Vergleich über GRDB-Strings),
//  `ohne-index` = neuer Vergleich ohne `items_search_natural`, `nachher-alt` = alter Vergleich mit dem Index (Stand der
//  ersten Messung), sonst (`nachher`) der heutige Stand.
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

extension MeasurementTestGroup {
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["DISKARCHIVE_MEASURE"] == "1"))
struct NaturalOrderIndexMeasurementTests {
    /// 100 Ordner × 100 Unterordner × 100 Dateien = 1.000.000 Dateien plus 10.100 Ordner.
    private let topFolders = 100
    private let subFolders = 100
    private let filesPerFolder = 100
    private let entriesPerWrite = 2_000

    @Test func indexOneMillionEntries() async throws {
        let free = (try? URL(fileURLWithPath: NSTemporaryDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? 0
        try #require(free > 4_000_000_000, "zu wenig freier Platz")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-natural-measure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("archive.sqlite")
        let database = try TestDatabase(fileURL: fileURL)
        defer { try? database.close() }
        let variant = ProcessInfo.processInfo.environment["DISKARCHIVE_MEASURE_VARIANT"] ?? "nachher"
        if variant != "nachher" {
            // Nur der Schreiber pflegt die Indizes beim Indizieren; dort zählt der Vergleich.
            try await database.pool.writeWithoutTransaction { db in
                if variant == "vorher" || variant == "ohne-index" { try db.execute(sql: "DROP INDEX items_search_natural") }
                if variant == "vorher" || variant == "nachher-alt" { db.add(collation: LegacyNaturalOrder.collation) }
            }
        }
        let store = IndexStoreV3(database: database)
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000_000_000_000, name: "MESSUNG", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        let seenAt = Date(timeIntervalSince1970: 1_700_000_000)
        let base = Date(timeIntervalSince1970: 1_500_000_000)

        let started = ContinuousClock.now
        // Ebene 1
        let level1 = (1...topFolders).map { ScannedEntry(name: "Projekt \($0)", isFolder: true, modifiedAt: base) }
        try await store.applyDirectories(
            mediumUUID: medium.uuid, batches: [(parentID: nil, path: "/", depth: 1, entries: level1, finalize: true)], seenAt: seenAt
        )
        let roots = try await store.children(mediumUUID: medium.uuid, parentID: nil)
        try #require(roots.count == topFolders)
        // Ebene 2: je Ordner 100 Unterordner (ein Schreibvorgang ≈ 2.000 Einträge).
        let kinds = ["Fotos", "Dokumente", "Musik", "Archiv", "Scans", "Rechnungen", "Backup", "Präsentationen"]
        var pending: [(parentID: Int64?, path: String?, depth: Int?, entries: [ScannedEntry], finalize: Bool)] = []
        var pendingCount = 0
        func flush() async throws {
            guard !pending.isEmpty else { return }
            try await store.applyDirectories(mediumUUID: medium.uuid, batches: pending, seenAt: seenAt)
            pending.removeAll(keepingCapacity: true)
            pendingCount = 0
        }
        for root in roots {
            let entries = (1...subFolders).map { index in
                ScannedEntry(name: "\(kinds[index % kinds.count]) \(index)", isFolder: true, modifiedAt: base)
            }
            pending.append((parentID: root.id, path: "/\(root.name)/", depth: 2, entries: entries, finalize: true))
            pendingCount += entries.count
            if pendingCount >= entriesPerWrite { try await flush() }
        }
        try await flush()
        // Ebene 3: je Unterordner 100 Dateien.
        var folderNumber = 0
        for root in roots {
            let subs = try await store.children(mediumUUID: medium.uuid, parentID: root.id)
            try #require(subs.count == subFolders)
            for sub in subs {
                folderNumber += 1
                let entries = (0..<filesPerFolder).map { index in
                    fileEntry(folder: folderNumber, index: index, base: base)
                }
                pending.append((parentID: sub.id, path: "/\(root.name)/\(sub.name)/", depth: 3, entries: entries, finalize: true))
                pendingCount += entries.count
                if pendingCount >= entriesPerWrite { try await flush() }
            }
        }
        try await flush()
        try await store.completeLayer(mediumUUID: medium.uuid, depth: 3)
        let elapsed = started.duration(to: .now)
        store.checkpoint()

        let total = try await database.pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items") ?? 0 }
        let bytes = Self.fileSize(fileURL) + Self.fileSize(URL(fileURLWithPath: fileURL.path + "-wal"))
        let indexes = try await database.pool.read { db -> [String] in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'items_search%' ORDER BY name")
        }
        // Seitengröße je Index, falls `dbstat` verfügbar ist.
        let perIndex: String = (try? await database.pool.read { db -> String in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT name, SUM(pgsize) AS bytes FROM dbstat WHERE name IN ('items', 'items_search', 'items_search_natural') GROUP BY name ORDER BY name"
            )
            return rows.map { "\($0["name"] as String? ?? "-")=\($0["bytes"] as Int64? ?? 0)" }.joined(separator: " ")
        }) ?? "dbstat-nicht-verfuegbar"
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let line = String(
            format: "MESSUNG bug.0.4.077 variante=%@ eintraege=%d dauer=%.3f s groesse=%lld bytes indizes=%@ %@",
            variant, total, seconds, bytes, indexes.joined(separator: ","), perIndex
        )
        print(line)
        if let out = ProcessInfo.processInfo.environment["DISKARCHIVE_MEASURE_OUT"] {
            let url = URL(fileURLWithPath: out)
            let stamped = ISO8601DateFormatter().string(from: Date()) + " " + line + "\n"
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(stamped.utf8))
                try? handle.close()
            } else {
                try stamped.write(to: url, atomically: true, encoding: .utf8)
            }
        }
        #expect(total == topFolders + topFolders * subFolders + topFolders * subFolders * filesPerFolder)
    }

    /// Gemischte, dateinahe Namen mit Zahlen an verschiedenen Stellen (natürliche Ordnung hat zu tun).
    private func fileEntry(folder: Int, index: Int, base: Date) -> ScannedEntry {
        let n = folder * filesPerFolder + index
        let name: String
        switch n % 8 {
        case 0: name = "IMG_\(4_000 + n).JPG"
        case 1: name = "Rechnung \(n).pdf"
        case 2: name = "Scan 20\(10 + n % 15)-\(1 + n % 12)-\(1 + n % 28) \(n).png"
        case 3: name = "Kapitel \(n % 40) – Entwurf \(n).docx"
        case 4: name = "Track \(n % 20 + 1) - Künstler \(n).mp3"
        case 5: name = "DSC0\(n).NEF"
        case 6: name = "notizen_\(n).txt"
        default: name = "Präsentation Q\(n % 4 + 1) \(n).key"
        }
        return ScannedEntry(
            name: name,
            isFolder: false,
            sizeBytes: Int64(1_000 + n % 9_000_000),
            modifiedAt: base.addingTimeInterval(TimeInterval(n * 37))
        )
    }

    private static func fileSize(_ url: URL) -> Int64 {
        let value = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
        return value?.int64Value ?? 0
    }
}
}
