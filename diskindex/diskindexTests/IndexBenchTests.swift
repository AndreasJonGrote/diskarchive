//
//  IndexBenchTests.swift
//  diskindexTests
//
//  Aufgabe 196 — Messwerkzeug Datenbank („vorher“). Nur mit DA_BENCH=1, sonst übersprungen. Misst nur, ändert das
//  App-Schema nicht (Hilfstabelle `bench_names` liegt nur in der Mess-Datenbank). Start: `Werkzeuge/db-messung.sh`.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

// MARK: - Zufall, Namen

private struct BenchRNG {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

private enum BenchNames {
    static let syllables = [
        "bil", "der", "ur", "laub", "fa", "mi", "lie", "ber", "ich", "tag", "büro", "über", "Rech", "nung", "Scan",
        "Foto", "Pro", "jekt", "Ent", "wurf", "Mü", "ller", "Kö", "ln", "Grün", "Be", "richt", "Ver", "trag", "Ma",
        "rie", "sommer", "Hoch", "zeit", "Ur", "kunde", "Fähre", "Schloß", "Äpfel", "Straße", "Wei", "hnachten",
        "Ur", "laub", "Kon", "zert", "Mit", "schnitt", "Archiv", "Notiz", "Rohdaten", "Export", "final", "neu", "alt",
    ]
    static let separators = [" ", " ", "-", "_", "", " "]
    static let folderWords = [
        "Projekte", "Fotos", "Dokumente", "Musik", "Filme", "Archiv", "Scans", "Rechnungen", "Urlaub", "Arbeit",
        "Privat", "Schule", "Backup", "Entwürfe", "Übergabe", "Größen", "Kunden", "Bilder", "Verträge", "Sonstiges",
    ]
    static let otherExtensions = ["png", "doc", "docx", "xls", "xlsx", "mp3", "zip", "html", "swift", "dmg", "key", "psd", "wav", "csv", "json"]
    static let rare = "Quartzit"
    static let common = "bil"

    static func fileExtension(_ rng: inout BenchRNG) -> String? {
        let roll = rng.unit()
        switch roll {
        case ..<0.30: return "jpg"
        case ..<0.40: return "pdf"
        case ..<0.45: return "mov"
        case ..<0.55: return "txt"
        case ..<0.70: return nil
        default: return otherExtensions[rng.int(0...(otherExtensions.count - 1))]
        }
    }

    static func base(_ rng: inout BenchRNG, length: Int) -> String {
        var text = ""
        while text.count < length {
            text += syllables[rng.int(0...(syllables.count - 1))]
            text += separators[rng.int(0...(separators.count - 1))]
        }
        var trimmed = String(text.prefix(length)).trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { trimmed = "datei" }
        return trimmed
    }

    static func file(_ rng: inout BenchRNG) -> String {
        let ext = fileExtension(&rng)
        let extLength = ext.map { $0.count + 1 } ?? 0
        var length = rng.int(4...60) - extLength
        length = max(3, length)
        var name = base(&rng, length: length)
        if rng.unit() < 0.00002 { name = rare + " " + name }
        return ext.map { name + "." + $0 } ?? name
    }

    static func folder(_ rng: inout BenchRNG) -> String {
        let word = folderWords[rng.int(0...(folderWords.count - 1))]
        return word + " " + base(&rng, length: rng.int(2...20))
    }
}

// MARK: - Aufbau

private struct BuildResult {
    var written = 0
    var applySeconds = 0.0
    var specials: [(kids: Int, folderID: Int64)] = []
    var partial = false
}

private struct FolderContext {
    var id: Int64?
    var path: String
    var depth: Int
    var special: Int?
}

/// Seitengröße der Spaltenansicht (`IndexRepository.loadBatchSize`).
private let benchBatch = 2_000
/// Nur zum Erproben des Werkzeugs: `DA_BENCH_SCALE=0.01` verkleinert alle Mengen. Die echte Messung läuft mit 1.
private let benchScale = Double(ProcessInfo.processInfo.environment["DA_BENCH_SCALE"] ?? "") ?? 1
private func scaled(_ count: Int) -> Int { max(2_000, Int(Double(count) * benchScale)) }
private let referenceDate = Date(timeIntervalSince1970: 1_791_700_000)

private func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
}

private func freeBytes() -> Int64 {
    let values = try? URL(fileURLWithPath: NSTemporaryDirectory())
        .resourceValues(forKeys: [.volumeAvailableCapacityKey])
    return values?.volumeAvailableCapacity.map(Int64.init) ?? 0
}

private func buildMedium(
    store: IndexStore,
    uuid: UUID,
    total: Int,
    seed: UInt64,
    specialKids: [Int],
    floorBytes: Int64 = 0
) async throws -> BuildResult {
    var rng = BenchRNG(state: seed)
    var result = BuildResult()
    var remaining = total
    var specialsLeft = specialKids
    var level = [FolderContext(id: nil, path: "/", depth: 1, special: nil)]
    let seenAt = referenceDate

    while !level.isEmpty, remaining > 0 {
        var batch: [(parentID: Int64?, path: String?, depth: Int?, entries: [ScannedEntry], finalize: Bool)] = []
        var batchEntries = 0
        let depth = level[0].depth
        var lowOnSpace = false

        func flush() async throws {
            guard !batch.isEmpty else { return }
            let start = ContinuousClock.now
            try await store.applyDirectories(mediumUUID: uuid, batches: batch, seenAt: seenAt)
            result.applySeconds += seconds(start.duration(to: .now))
            batch.removeAll(keepingCapacity: true)
            batchEntries = 0
            if floorBytes > 0, freeBytes() < floorBytes { lowOnSpace = true }
        }

        for context in level {
            guard remaining > 0, !lowOnSpace else { break }
            var kids = depth == 1 ? 60 : rng.int(4...30)
            var special: Int?
            if depth == 2, !specialsLeft.isEmpty {
                kids = specialsLeft.removeFirst()
                special = kids
            }
            kids = min(kids, remaining)
            let folderShare = special != nil ? 0.05 : 0.30
            let folderCount = depth <= 5 ? Int(Double(kids) * folderShare) : 0
            var names = Set<String>()
            names.reserveCapacity(kids)
            var entries: [ScannedEntry] = []
            entries.reserveCapacity(kids)
            var counter = 0
            while entries.count < kids {
                let isFolder = entries.count < folderCount
                var name = isFolder ? BenchNames.folder(&rng) : BenchNames.file(&rng)
                if !names.insert(name).inserted {
                    counter += 1
                    name += " \(counter)"
                    guard names.insert(name).inserted else { continue }
                }
                let age = rng.unit() * 10 * 365 * 86_400
                let size: Int64? = isFolder ? nil : Int64(exp(log(1_024.0) + rng.unit() * (log(4e9) - log(1_024.0))))
                entries.append(ScannedEntry(
                    name: name,
                    isFolder: isFolder,
                    sizeBytes: size,
                    modifiedAt: referenceDate.addingTimeInterval(-age)
                ))
            }
            batch.append((parentID: context.id, path: context.path, depth: context.depth, entries: entries, finalize: false))
            batchEntries += entries.count
            remaining -= entries.count
            result.written += entries.count
            if special != nil, let id = context.id { result.specials.append((kids: kids, folderID: id)) }
            if batchEntries >= 20_000 || batch.count >= 200 { try await flush() }
        }
        try await flush()
        if lowOnSpace {
            result.partial = true
            break
        }
        let folders = try store.database.pool.read { db -> [Row] in
            try Row.fetchAll(
                db,
                sql: "SELECT id, path FROM item WHERE depth = ? AND isFolder = 1 AND mediumID = (SELECT id FROM medium WHERE uuid = ?)",
                arguments: [depth, uuid.uuidString]
            )
        }
        level = folders.map { FolderContext(id: $0["id"], path: $0["path"], depth: depth + 1, special: nil) }
    }
    return result
}

// MARK: - Bericht

private final class BenchReport: @unchecked Sendable {
    static let shared = BenchReport()
    struct Row: Codable {
        var szenario: String
        var gruppe: String
        var messpunkt: String
        var medianMs: Double?
        var laeufeMs: [Double]
        var wert: String
        var bemerkung: String
    }

    private let lock = NSLock()
    private var rows: [Row] = []
    private var notes: [String] = []
    private let started = Date()

    func add(_ scenario: String, _ group: String, _ name: String, ms: Double? = nil, runs: [Double] = [], value: String = "", note: String = "") {
        lock.lock()
        rows.append(Row(szenario: scenario, gruppe: group, messpunkt: name, medianMs: ms, laeufeMs: runs, wert: value, bemerkung: note))
        lock.unlock()
        print("BENCH \(scenario) | \(group) | \(name) | \(ms.map { String(format: "%.1f ms", $0) } ?? value) | \(note)")
    }

    func note(_ text: String) {
        lock.lock()
        notes.append(text)
        lock.unlock()
        print("BENCH Hinweis: \(text)")
    }

    private static func machine() -> (model: String, cpu: String, memoryGB: Int) {
        func text(_ name: String) -> String {
            var size = 0
            sysctlbyname(name, nil, &size, nil, 0)
            var buffer = [CChar](repeating: 0, count: max(size, 1))
            sysctlbyname(name, &buffer, &size, nil, 0)
            return String(cString: buffer)
        }
        return (text("hw.model"), text("machdep.cpu.brand_string"), Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
    }

    func write(to folder: URL) throws {
        lock.lock()
        var snapshot = rows
        var noteList = notes
        lock.unlock()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        let base = folder.appendingPathComponent("\(day.string(from: Date()))-vorher")
        let machine = Self.machine()
        var total = Date().timeIntervalSince(started)
        // Läuft S1 und S2 in getrennten Aufrufen, bleibt das Ergebnis des anderen Szenarios erhalten.
        struct Previous: Codable {
            var laufzeitGesamtSekunden: Double
            var hinweise: [String]
            var messungen: [Row]
        }
        if let data = try? Data(contentsOf: base.appendingPathExtension("json")),
           let previous = try? JSONDecoder().decode(Previous.self, from: data) {
            let current = Set(snapshot.map(\.szenario))
            snapshot = previous.messungen.filter { !current.contains($0.szenario) } + snapshot
            noteList = previous.hinweise.filter { !noteList.contains($0) } + noteList
            total += previous.laufzeitGesamtSekunden
        }
        var markdown = "# Messung Datenbank — vorher (Aufgabe 196)\n\n"
        markdown += "- Rechner: \(machine.model), \(machine.cpu), \(machine.memoryGB) GB RAM\n"
        markdown += "- macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        markdown += "- Übersetzung: Debug mit `-O` (Release-Tests bauen nicht, Debug-Testhilfen)\n"
        markdown += "- Laufzeit gesamt: \(Int(total)) s\n\n"
        if !noteList.isEmpty {
            markdown += "## Hinweise\n\n" + noteList.map { "- \($0)" }.joined(separator: "\n") + "\n\n"
        }
        for scenario in Array(Set(snapshot.map(\.szenario))).sorted() {
            markdown += "## \(scenario)\n\n"
            var groups: [String] = []
            for row in snapshot where row.szenario == scenario && !groups.contains(row.gruppe) { groups.append(row.gruppe) }
            for group in groups {
                markdown += "### \(group)\n\n| Messpunkt | Median (ms) | Läufe (ms) | Wert | Bemerkung |\n|---|---:|---|---|---|\n"
                for row in snapshot where row.szenario == scenario && row.gruppe == group {
                    let median = row.medianMs.map { String(format: "%.1f", $0) } ?? ""
                    let runs = row.laeufeMs.map { String(format: "%.0f", $0) }.joined(separator: ", ")
                    markdown += "| \(row.messpunkt) | \(median) | \(runs) | \(row.wert) | \(row.bemerkung) |\n"
                }
                markdown += "\n"
            }
        }
        try markdown.write(to: base.appendingPathExtension("md"), atomically: true, encoding: .utf8)
        struct Output: Codable {
            var rechner: String
            var macOS: String
            var laufzeitGesamtSekunden: Double
            var hinweise: [String]
            var messungen: [Row]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Output(
            rechner: "\(machine.model), \(machine.cpu), \(machine.memoryGB) GB",
            macOS: ProcessInfo.processInfo.operatingSystemVersionString,
            laufzeitGesamtSekunden: total,
            hinweise: noteList,
            messungen: snapshot
        ))
        try data.write(to: base.appendingPathExtension("json"))
    }
}

private func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    guard !sorted.isEmpty else { return 0 }
    return sorted[sorted.count / 2]
}

/// Mehrere Läufe; liefert Median und alle Zeiten in ms.
private func timed(runs: Int = 5, _ body: () async throws -> Void) async throws -> (median: Double, all: [Double]) {
    var times: [Double] = []
    for _ in 0..<runs {
        let start = ContinuousClock.now
        try await body()
        times.append(seconds(start.duration(to: .now)) * 1_000)
    }
    return (median(times), times)
}

// MARK: - Messungen

private struct Scenario {
    let name: String
    let directory: URL
    let fileURL: URL
    var database: IndexDatabase
    var store: IndexStore
    var mediumUUIDs: [UUID] = []
    var largest: (uuid: UUID, items: Int)?
    var specials: [(kids: Int, folderID: Int64)] = []
    var totalItems = 0

    static func make(_ name: String) throws -> Scenario {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-dbbench-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("index.sqlite")
        let database = try IndexDatabase(fileURL: fileURL)
        return Scenario(name: name, directory: directory, fileURL: fileURL, database: database, store: IndexStore(database: database))
    }

    mutating func reopen() throws {
        try database.close()
        database = try IndexDatabase(fileURL: fileURL)
        store = IndexStore(database: database)
    }

    func addMedium(_ title: String) async throws -> UUID {
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: title, type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        return medium.uuid
    }

    func fileSizes() -> (db: Int64, wal: Int64) {
        func size(_ path: String) -> Int64 {
            ((try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? NSNumber)?.int64Value ?? 0
        }
        return (size(fileURL.path), size(fileURL.path + "-wal"))
    }
}

private func gigabytes(_ bytes: Int64) -> String {
    String(format: "%.3f GB", Double(bytes) / 1_073_741_824)
}

private func recordSizes(_ scenario: Scenario, label: String) async throws {
    let report = BenchReport.shared
    let sizes = scenario.fileSizes()
    report.add(scenario.name, "Größe", "\(label): Datenbankdatei", value: gigabytes(sizes.db))
    report.add(scenario.name, "Größe", "\(label): WAL", value: gigabytes(sizes.wal))
    let pool = scenario.store.database.pool
    let pathBytes = try await pool.read { db in try Int64.fetchOne(db, sql: "SELECT SUM(LENGTH(path)) FROM item") ?? 0 }
    report.add(scenario.name, "Größe", "\(label): Bytes der Spalte path (SUM(LENGTH(path)))", value: gigabytes(pathBytes), note: "\(pathBytes) Bytes")
    let pages = try await pool.read { db -> (count: Int, size: Int, free: Int) in
        (
            try Int.fetchOne(db, sql: "PRAGMA page_count") ?? 0,
            try Int.fetchOne(db, sql: "PRAGMA page_size") ?? 0,
            try Int.fetchOne(db, sql: "PRAGMA freelist_count") ?? 0
        )
    }
    report.add(
        scenario.name, "Größe", "\(label): Seiten",
        value: "\(pages.count) × \(pages.size) B", note: "frei: \(pages.free)"
    )
    do {
        let rows = try pool.read { db -> [Row] in
            try Row.fetchAll(db, sql: "SELECT name, SUM(pgsize) AS bytes FROM dbstat GROUP BY name")
        }
        var tables: Int64 = 0
        var indexes: Int64 = 0
        var fts: Int64 = 0
        var details: [String] = []
        for row in rows {
            let name: String = row["name"]
            let bytes: Int64 = row["bytes"]
            if name == "item" {
                tables += bytes
            } else if name.hasPrefix("item_fts") {
                fts += bytes
            } else if name.hasPrefix("item_") || name.hasPrefix("sqlite_autoindex_item") {
                indexes += bytes
                details.append("\(name) \(gigabytes(bytes))")
            }
        }
        report.add(scenario.name, "Größe", "\(label): Tabelle item", value: gigabytes(tables))
        report.add(scenario.name, "Größe", "\(label): Indizes auf item", value: gigabytes(indexes), note: details.joined(separator: "; "))
        report.add(scenario.name, "Größe", "\(label): item_fts (inkl. Hilfstabellen)", value: gigabytes(fts))
    } catch {
        report.add(scenario.name, "Größe", "\(label): dbstat nicht verfügbar", value: "-", note: "\(error)")
    }
}

private func runMeasurements(_ scenario: inout Scenario, deleteLargest: Bool) async throws {
    let report = BenchReport.shared
    let name = scenario.name

    // Größe
    try await recordSizes(scenario, label: "nach Aufbau")

    // Öffnen
    let openRuns = name == "S1" ? 5 : 3
    var openTimes: [Double] = []
    var checkTimes: [Double] = []
    for _ in 0..<openRuns {
        try scenario.database.close()
        let start = ContinuousClock.now
        let opened = try IndexDatabase(fileURL: scenario.fileURL)
        openTimes.append(seconds(start.duration(to: .now)) * 1_000)
        let checkStart = ContinuousClock.now
        try opened.runIntegrityCheck()
        checkTimes.append(seconds(checkStart.duration(to: .now)) * 1_000)
        scenario.database = opened
        scenario.store = IndexStore(database: opened)
    }
    report.add(name, "Öffnen", "Datenbank öffnen ohne quick_check (nach Neuöffnen, OS-Cache warm)", ms: median(openTimes), runs: openTimes)
    report.add(
        name, "Öffnen", "quick_check allein", ms: median(checkTimes), runs: checkTimes,
        note: "mit quick_check gesamt ≈ \(Int(median(openTimes) + median(checkTimes))) ms; \(openRuns) Läufe; echter Kaltstart ohne `purge` (Root) nicht möglich"
    )

    // Spaltenansicht
    for special in scenario.specials {
        let uuid = scenario.largest?.uuid ?? scenario.mediumUUIDs[0]
        let store = scenario.store
        let count = try await timed { _ = try await store.childCount(mediumUUID: uuid, parentID: special.folderID) }
        report.add(name, "Spaltenansicht", "childCount, \(special.kids) Kinder", ms: count.median, runs: count.all)
        let first = try await timed {
            _ = try await store.childrenPage(mediumUUID: uuid, parentID: special.folderID, limit: benchBatch)
        }
        report.add(name, "Spaltenansicht", "erste Seite childrenPage (\(benchBatch)), \(special.kids) Kinder", ms: first.median, runs: first.all)
        var pages = 0
        let all = try await timed {
            var cursor: ItemChildrenCursor?
            pages = 0
            while true {
                let page = try await store.childrenPage(
                    mediumUUID: uuid, parentID: special.folderID, limit: benchBatch, after: cursor
                )
                pages += 1
                guard let next = page.nextCursor else { break }
                cursor = next
            }
        }
        report.add(name, "Spaltenansicht", "alle Seiten, \(special.kids) Kinder", ms: all.median, runs: all.all, note: "\(pages) Seiten")
    }

    // Suche
    var typeFilter = SearchFilters()
    typeFilter.fileTypes = [.pdf]
    var ageFilter = SearchFilters()
    ageFilter.age = .lastMonth
    var bothFilter = SearchFilters()
    bothFilter.fileTypes = [.pdf]
    bothFilter.age = .lastMonth
    let filters: [(String, SearchFilters)] = [
        ("ohne Filter", SearchFilters()), ("Dateityp pdf", typeFilter), ("Alter letzter Monat", ageFilter), ("beide", bothFilter),
    ]
    let terms: [(String, String)] = [("häufig, 3 Zeichen", BenchNames.common), ("selten, 8 Zeichen", BenchNames.rare)]
    for (termLabel, term) in terms {
        for (filterLabel, filter) in filters {
            let store = scenario.store
            let list = try await timed { _ = try await store.search(query: term, filters: filter, limit: 500) }
            report.add(name, "Suche", "search (Limit 500) '\(term)' (\(termLabel)), \(filterLabel)", ms: list.median, runs: list.all)
            var hits = 0
            let counted = try await timed { hits = try await store.searchCount(query: term, filters: filter) }
            report.add(name, "Suche", "searchCount '\(term)' (\(termLabel)), \(filterLabel)", ms: counted.median, runs: counted.all, note: "Treffer \(hits)")
        }
    }

    // Favoriten
    do {
        let step = max(1, scenario.totalItems / 1_000)
        let ids = try await scenario.store.database.pool.read { db in
            try Int64.fetchAll(db, sql: "SELECT id FROM item WHERE isFolder = 0 AND id % ? = 0 ORDER BY id LIMIT 1000", arguments: [step])
        }
        let start = ContinuousClock.now
        for chunk in stride(from: 0, to: ids.count, by: 100) {
            try await scenario.store.setFavorites(itemIDs: Array(ids[chunk..<min(chunk + 100, ids.count)]), true)
        }
        report.add(name, "Favoriten", "\(ids.count) Favoriten setzen (10 × 100)", ms: seconds(start.duration(to: .now)) * 1_000)
        let store = scenario.store
        var returned = 0
        let favorites = try await timed { returned = try await store.favorites().count }
        report.add(name, "Favoriten", "favorites() bei \(ids.count) Favoriten", ms: favorites.median, runs: favorites.all, note: "geliefert \(returned)")
    }

    // LIKE ohne Suchindex (h)
    try await measureLike(&scenario)

    // deleteMedium
    if deleteLargest, let largest = scenario.largest {
        let before = scenario.fileSizes()
        let start = ContinuousClock.now
        try await scenario.store.deleteMedium(uuid: largest.uuid)
        report.add(name, "Löschen", "deleteMedium (\(largest.items) Einträge)", ms: seconds(start.duration(to: .now)) * 1_000)
        let afterDelete = scenario.fileSizes()
        let vacuumStart = ContinuousClock.now
        try await scenario.store.database.pool.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA incremental_vacuum")
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
        let afterVacuum = scenario.fileSizes()
        report.add(name, "Löschen", "incremental_vacuum + Checkpoint", ms: seconds(vacuumStart.duration(to: .now)) * 1_000)
        report.add(
            name, "Löschen", "Dateigröße vor / nach Löschen / nach Vacuum",
            value: "\(gigabytes(before.db)) / \(gigabytes(afterDelete.db)) / \(gigabytes(afterVacuum.db))",
            note: "WAL: \(gigabytes(before.wal)) / \(gigabytes(afterDelete.wal)) / \(gigabytes(afterVacuum.wal))"
        )
    }

    // pruneToMatch
    let maxDepth = try await scenario.store.database.pool.read { db in try Int.fetchOne(db, sql: "SELECT MAX(depth) FROM item") ?? 0 }
    let scope = IndexScope(
        maxDepth: maxDepth - 1,
        matcher: IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [], artifactsIgnored: false)
    )
    // Zeitfenster: Das Löschen tiefer Ordner ist bei großen Datenmengen sehr langsam (Aufgabe 196, Befund). Deshalb in
    // kleinen Schritten (`maxBatches`) bis zum Ende oder bis 10 Minuten, danach Rate und Rest-Schätzung.
    let pruneStart = ContinuousClock.now
    let remainingBefore = try await scenario.store.database.pool.read { db in
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item WHERE depth > ?", arguments: [maxDepth - 1]) ?? 0
    }
    var removed = 0
    var finished = false
    while seconds(pruneStart.duration(to: .now)) < 600 {
        let step = try await scenario.store.pruneToMatch(scope, maxBatches: 20)
        removed += step
        let left = try await scenario.store.database.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item WHERE depth > ?", arguments: [maxDepth - 1]) ?? 0
        }
        if left == 0 { finished = true; break }
    }
    let pruneSeconds = seconds(pruneStart.duration(to: .now))
    let rate = Double(removed) / max(pruneSeconds, 0.001)
    report.add(
        name, "Bereinigen", "pruneToMatch nach Tiefe \(maxDepth) → \(maxDepth - 1)", ms: pruneSeconds * 1_000,
        note: "zu entfernen \(remainingBefore), entfernt \(removed) (\(Int(rate))/s), \(finished ? "fertig" : "ABGEBROCHEN nach 10 min; \(removed > 0 ? "Schätzung gesamt ≈ \(Int(Double(remainingBefore) / rate)) s" : "keine Schätzung (nichts entfernt)")")"
    )
}

private func measureLike(_ scenario: inout Scenario) async throws {
    let report = BenchReport.shared
    let name = scenario.name
    let pool = scenario.store.database.pool
    let freeBefore = freeBytes()
    guard freeBefore > 4_000_000_000 else {
        report.note("\(name): LIKE-Messung auf bench_names übersprungen (zu wenig freier Platz)")
        return
    }
    let createStart = ContinuousClock.now
    try await pool.writeWithoutTransaction { db in
        try db.execute(sql: "CREATE TABLE bench_names(id INTEGER PRIMARY KEY, name TEXT)")
        try db.execute(sql: "INSERT INTO bench_names SELECT id, name FROM item WHERE removedAt IS NULL")
        try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
    }
    report.add(name, "LIKE ohne Suchindex", "bench_names anlegen", ms: seconds(createStart.duration(to: .now)) * 1_000)
    if let bytes = try? await pool.read({ db in
        try Int64.fetchOne(db, sql: "SELECT SUM(pgsize) FROM dbstat WHERE name = 'bench_names'")
    }), bytes > 0 {
        let rows = try await pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM bench_names") ?? 0 }
        report.add(name, "LIKE ohne Suchindex", "Größe bench_names", value: gigabytes(bytes), note: "\(rows) Zeilen")
    } else {
        report.add(name, "LIKE ohne Suchindex", "Größe bench_names", value: "dbstat nicht verfügbar")
    }

    struct Query { let label: String; let sql: String; let isCount: Bool }
    let queries = [
        Query(
            label: "item, Liste 500",
            sql: """
                SELECT item.*, medium.uuid AS mediumUUID FROM item JOIN medium ON medium.id = item.mediumID
                WHERE item.removedAt IS NULL AND item.name LIKE ? ORDER BY item.name COLLATE NOCASE, item.id LIMIT 500
                """,
            isCount: false
        ),
        Query(
            label: "item, Zahl",
            sql: "SELECT COUNT(*) FROM item JOIN medium ON medium.id = item.mediumID WHERE item.removedAt IS NULL AND item.name LIKE ?",
            isCount: true
        ),
        Query(
            label: "bench_names, Liste 500",
            sql: "SELECT id, name FROM bench_names WHERE name LIKE ? ORDER BY name COLLATE NOCASE, id LIMIT 500",
            isCount: false
        ),
        Query(label: "bench_names, Zahl", sql: "SELECT COUNT(*) FROM bench_names WHERE name LIKE ?", isCount: true),
    ]
    func run(_ query: Query, term: String, on pool: DatabasePool) async throws -> Int {
        try await pool.read { db in
            if query.isCount {
                return try Int.fetchOne(db, sql: query.sql, arguments: ["%\(term)%"]) ?? 0
            }
            return try Row.fetchAll(db, sql: query.sql, arguments: ["%\(term)%"]).count
        }
    }
    for term in [BenchNames.common, BenchNames.rare] {
        for query in queries {
            var result = 0
            _ = try await run(query, term: term, on: scenario.store.database.pool)
            let warm = try await timed { result = try await run(query, term: term, on: scenario.store.database.pool) }
            report.add(name, "LIKE ohne Suchindex", "warm: \(query.label), '\(term)'", ms: warm.median, runs: warm.all, note: "Ergebnis \(result)")
            var cold: [Double] = []
            for _ in 0..<3 {
                try await scenario.store.database.pool.write { db in try db.execute(sql: "PRAGMA shrink_memory") }
                try scenario.reopen()
                try await scenario.store.database.pool.read { db in try db.execute(sql: "PRAGMA shrink_memory") }
                let start = ContinuousClock.now
                _ = try await run(query, term: term, on: scenario.store.database.pool)
                cold.append(seconds(start.duration(to: .now)) * 1_000)
            }
            report.add(
                name, "LIKE ohne Suchindex", "kalt (shrink_memory + neu öffnen): \(query.label), '\(term)'",
                ms: median(cold), runs: cold, note: "OS-Seitencache bleibt warm (kein purge)"
            )
        }
    }
    try await scenario.store.database.pool.writeWithoutTransaction { db in
        try db.execute(sql: "DROP TABLE bench_names")
        try db.execute(sql: "PRAGMA incremental_vacuum")
        try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
    }
}

private func buildMedia(
    _ scenario: inout Scenario,
    plan: [(title: String, items: Int, seed: UInt64, specials: [Int])],
    floorBytes: Int64
) async throws -> (seconds: Double, aborted: Bool) {
    var applySeconds = 0.0
    for entry in plan {
        let uuid = try await scenario.addMedium(entry.title)
        let result = try await buildMedium(
            store: scenario.store, uuid: uuid, total: entry.items, seed: entry.seed, specialKids: entry.specials, floorBytes: floorBytes
        )
        scenario.mediumUUIDs.append(uuid)
        scenario.totalItems += result.written
        applySeconds += result.applySeconds
        if !entry.specials.isEmpty {
            scenario.specials = result.specials
            scenario.largest = (uuid, result.written)
        } else if scenario.largest == nil || result.written > (scenario.largest?.items ?? 0) {
            scenario.largest = (uuid, result.written)
        }
        if result.partial { return (applySeconds, true) }
    }
    return (applySeconds, false)
}

private func concurrentWrites(_ scenario: inout Scenario, items: Int) async throws {
    let report = BenchReport.shared
    let a = try await scenario.addMedium("Gleichzeitig A")
    let b = try await scenario.addMedium("Gleichzeitig B")
    let store = scenario.store
    let sequentialStart = ContinuousClock.now
    let first = try await buildMedium(store: store, uuid: a, total: items, seed: 701, specialKids: [])
    let second = try await buildMedium(store: store, uuid: b, total: items, seed: 702, specialKids: [])
    let sequential = seconds(sequentialStart.duration(to: .now))
    report.add(
        scenario.name, "Schreiben", "nacheinander 2 × \(items)", ms: sequential * 1_000,
        value: "\(Int(Double(first.written + second.written) / sequential)) Einträge/s gesamt"
    )
    try await store.deleteMedium(uuid: a)
    try await store.deleteMedium(uuid: b)
    let c = try await scenario.addMedium("Gleichzeitig C")
    let d = try await scenario.addMedium("Gleichzeitig D")
    let concurrentStart = ContinuousClock.now
    var perMedium: [Double] = []
    var written = 0
    try await withThrowingTaskGroup(of: (Int, Double).self) { group in
        for (uuid, seed) in [(c, UInt64(703)), (d, UInt64(704))] {
            group.addTask {
                let start = ContinuousClock.now
                let result = try await buildMedium(store: store, uuid: uuid, total: items, seed: seed, specialKids: [])
                return (result.written, seconds(start.duration(to: .now)))
            }
        }
        for try await (count, elapsed) in group {
            written += count
            perMedium.append(Double(count) / elapsed)
        }
    }
    let concurrent = seconds(concurrentStart.duration(to: .now))
    report.add(
        scenario.name, "Schreiben", "gleichzeitig 2 × \(items)", ms: concurrent * 1_000,
        value: "\(Int(Double(written) / concurrent)) Einträge/s gesamt",
        note: "je Medium: " + perMedium.map { "\(Int($0)) Einträge/s" }.joined(separator: " / ")
    )
    try await store.deleteMedium(uuid: c)
    try await store.deleteMedium(uuid: d)
    try await store.database.pool.writeWithoutTransaction { db in
        try db.execute(sql: "PRAGMA incremental_vacuum")
        try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
    }
}

private func outputFolder() -> URL {
    if let path = ProcessInfo.processInfo.environment["DA_BENCH_OUT"], !path.isEmpty {
        return URL(fileURLWithPath: path, isDirectory: true)
    }
    return URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Werkzeuge/messung", isDirectory: true)
}

@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["DA_BENCH"] == "1"))
struct IndexBenchTests {
    private static let minimumFree: Int64 = 15 * 1_073_741_824
    /// Notbremse beim Schreiben, damit der Mac nicht vollläuft.
    private static let emergencyFree: Int64 = 3 * 1_073_741_824

    @Test func s1OneMediumOneMillion() async throws {
        let report = BenchReport.shared
        let free = freeBytes()
        report.note("Freier Platz zu Beginn von S1: \(gigabytes(free))")
        guard free >= Self.minimumFree else {
            report.note("S1 und S2 abgebrochen: unter 15 GB frei (\(gigabytes(free)))")
            try report.write(to: outputFolder())
            Issue.record("zu wenig freier Platz: \(gigabytes(free))")
            return
        }
        var scenario = try Scenario.make("S1")
        defer { try? FileManager.default.removeItem(at: scenario.directory) }
        let build = try await buildMedia(
            &scenario,
            plan: [("S1", scaled(1_000_000), 11, [100, 5_000, 50_000])],
            floorBytes: Self.emergencyFree
        )
        report.add(
            "S1", "Schreiben", "Aufbau 1 Medium", ms: build.seconds * 1_000,
            value: "\(Int(Double(scenario.totalItems) / max(build.seconds, 0.001))) Einträge/s",
            note: "\(scenario.totalItems) Einträge, ein Lauf (nicht wiederholbar)\(build.aborted ? ", ABGEBROCHEN: Platz" : "")"
        )
        try await concurrentWrites(&scenario, items: scaled(100_000))
        try await runMeasurements(&scenario, deleteLargest: false)
        try await recordSizes(scenario, label: "nach Bereinigung")
        try report.write(to: outputFolder())
    }

    @Test func s2ManyMedia() async throws {
        let report = BenchReport.shared
        let free = freeBytes()
        report.note("Freier Platz zu Beginn von S2: \(gigabytes(free))")
        guard free >= Self.minimumFree else {
            report.note("S2 abgebrochen: unter 15 GB frei (\(gigabytes(free)))")
            try report.write(to: outputFolder())
            return
        }
        var scenario = try Scenario.make("S2")
        defer { try? FileManager.default.removeItem(at: scenario.directory) }
        let rest = max(500, (scaled(9_000_000) - scaled(3_000_000) - 20 * scaled(200_000)) / 279)
        var plan: [(title: String, items: Int, seed: UInt64, specials: [Int])] = [("S2 groß", scaled(3_000_000), 21, [100, 5_000, 50_000])]
        for index in 0..<20 { plan.append(("S2 mittel \(index)", scaled(200_000), 100 + UInt64(index), [])) }
        for index in 0..<279 { plan.append(("S2 klein \(index)", rest, 1_000 + UInt64(index), [])) }
        let build = try await buildMedia(&scenario, plan: plan, floorBytes: Self.emergencyFree)
        report.add(
            "S2", "Schreiben", "Aufbau \(scenario.mediumUUIDs.count) Medien", ms: build.seconds * 1_000,
            value: "\(Int(Double(scenario.totalItems) / max(build.seconds, 0.001))) Einträge/s",
            note: "\(scenario.totalItems) Einträge, ein Lauf\(build.aborted ? ", ABGEBROCHEN: weniger als 3 GB frei" : "")"
        )
        if build.aborted {
            report.note("S2 nach \(scenario.totalItems) Einträgen abgebrochen (Platz); S1 liegt vollständig vor.")
            try await recordSizes(scenario, label: "Abbruchstand")
            try report.write(to: outputFolder())
            return
        }
        try await concurrentWrites(&scenario, items: scaled(100_000))
        // Das größte Medium (3 Mio.) enthält die Sonderordner; es wird beim Löschen gemessen, deshalb zuerst die Spalten.
        try await runMeasurements(&scenario, deleteLargest: true)
        try await recordSizes(scenario, label: "nach Bereinigung")
        try report.write(to: outputFolder())
    }
}
