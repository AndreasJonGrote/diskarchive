//
//  ScaleMeasurementTests.swift
//  diskindexTests
//
//  Messung für Aufgabe 59. Läuft nur mit DISKINDEX_SCALE=1, damit der normale Testlauf kurz bleibt.
//

import Darwin
import Foundation
import Testing
@testable import diskindex

struct SyntheticMediumAccess: MediumAccess {
    var foldersPerDirectory: Int
    var filesPerDirectory: Int
    var maxDepth: Int
    var changedPercent: Int = 0

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        let depth = max(0, url.pathComponents.count - 2)
        let changed = changedPercent > 0 && abs(url.path.hashValue) % 100 < changedPercent
        let modified = Date(timeIntervalSince1970: changed ? 80 : 10)
        var entries: [ListedDirectoryEntry] = []
        if depth < maxDepth {
            entries.reserveCapacity(foldersPerDirectory + filesPerDirectory)
            for index in 0..<foldersPerDirectory {
                entries.append(ListedDirectoryEntry(
                    name: "f\(index)",
                    isDirectory: true,
                    isPackage: false,
                    isSymbolicLink: false,
                    isHidden: false,
                    fileSize: nil,
                    modifiedAt: modified
                ))
            }
        }
        for index in 0..<filesPerDirectory {
            entries.append(ListedDirectoryEntry(
                name: "n\(index).txt",
                isDirectory: false,
                isPackage: false,
                isSymbolicLink: false,
                isHidden: false,
                fileSize: 1,
                modifiedAt: modified
            ))
        }
        return entries
    }
}

enum ProcessMeter {
    static func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.stride / MemoryLayout<natural_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    static func cpuSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
        let system = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        return user + system
    }
}

extension MeasurementTestGroup {
@MainActor
struct ScaleMeasurementTests {
    @Test(.enabled(if: FileManager.default.fileExists(atPath: "/tmp/diskindex-scale.on")))
    func measure() async throws {
        var lines: [String] = []
        func keep(_ line: String) throws {
            lines.append(line)
            try lines.joined(separator: "\n").write(to: URL(fileURLWithPath: "/tmp/diskindex-scale.txt"), atomically: true, encoding: .utf8)
            print(line)
        }
        try keep("basis-ram \(ProcessMeter.residentBytes())")
        try keep(try await idleFiveMedia())
        try keep(try await scan(label: "tiefe3", folders: 12, files: 10, depth: 3, fromScratch: true, changed: 0))
        for line in try await cycles(count: 20) {
            try keep(line)
        }
        try keep(try await wideColumn())
        for line in try await fullTree() {
            try keep(line)
        }
        try keep(try await scan(label: "ordner300k", folders: 8, files: 2, depth: 6, fromScratch: true, changed: 0))
        for reads in [1, 4, 8] {
            var limits = IndexingRunLimits.standard
            limits.parallelDirectoryReads = reads
            try keep(try await scan(label: "parallel-\(reads)", folders: 12, files: 10, depth: 4, fromScratch: true, changed: 0, limits: limits))
        }
    }

    private func idleFiveMedia() async throws -> String {
        let harness = try StoreHarness.make()
        let app = AppState(store: harness.store)
        let watcher = ChangeWatcher(
            store: harness.store,
            access: SyntheticMediumAccess(foldersPerDirectory: 1, filesPerDirectory: 1, maxDepth: 1),
            appState: app
        )
        for index in 0..<5 {
            let medium = try await harness.insert(name: "Leerlauf \(index)", fsType: "apfs", bytes: 1_000)
            watcher.start(mediumID: medium.uuid, volume: syntheticVolume(), source: ScriptedChangeSource())
        }
        let before = ProcessMeter.residentBytes()
        let cpu = ProcessMeter.cpuSeconds()
        try await Task.sleep(for: .seconds(60))
        let after = ProcessMeter.residentBytes()
        return "leerlauf medien=5 dauer=60s cpu=\(String(format: "%.2f", ProcessMeter.cpuSeconds() - cpu))s ram-vorher=\(before) ram-nachher=\(after)"
    }

    private func fullTree() async throws -> [String] {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Gross", fsType: "apfs", bytes: 1_000)
        let volume = syntheticVolume()
        let quiet = SyntheticMediumAccess(foldersPerDirectory: 12, filesPerDirectory: 10, maxDepth: 5)
        let changed = SyntheticMediumAccess(foldersPerDirectory: 12, filesPerDirectory: 10, maxDepth: 5, changedPercent: 1)
        var lines: [String] = []
        lines.append(try await run(label: "tiefe5", harness: harness, medium: medium, access: quiet, volume: volume, depth: 5, fromScratch: true))
        fputs("phase tiefe5-nochmal\n", stderr)
        fflush(stderr)
        lines.append(try await run(label: "tiefe5-nochmal", harness: harness, medium: medium, access: quiet, volume: volume, depth: 5, fromScratch: true))
        lines.append(try await run(label: "tiefe5-einProzent", harness: harness, medium: medium, access: changed, volume: volume, depth: 5, fromScratch: true))
        return lines
    }

    private func cycles(count: Int) async throws -> [String] {
        var lines: [String] = []
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Klein", fsType: "apfs", bytes: 1_000)
        let access = SyntheticMediumAccess(foldersPerDirectory: 3, filesPerDirectory: 4, maxDepth: 2)
        let volume = syntheticVolume()
        var previous = ProcessMeter.residentBytes()
        for index in 0..<count {
            let line = try await run(
                label: "zyklus-\(index)",
                harness: harness,
                medium: medium,
                access: access,
                volume: volume,
                depth: 2,
                fromScratch: true
            )
            let now = ProcessMeter.residentBytes()
            lines.append("\(line) ram-delta \(Int64(now) - Int64(previous))")
            previous = now
        }
        return lines
    }

    private func scan(
        label: String,
        folders: Int,
        files: Int,
        depth: Int,
        fromScratch: Bool,
        changed: Int,
        limits: IndexingRunLimits = .standard
    ) async throws -> String {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: label, fsType: "apfs", bytes: 1_000)
        let access = SyntheticMediumAccess(
            foldersPerDirectory: folders,
            filesPerDirectory: files,
            maxDepth: depth,
            changedPercent: changed
        )
        return try await run(
            label: label,
            harness: harness,
            medium: medium,
            access: access,
            volume: syntheticVolume(),
            depth: depth,
            fromScratch: fromScratch,
            limits: limits
        )
    }

    private func run(
        label: String,
        harness: StoreHarness,
        medium: StoredMedium,
        access: SyntheticMediumAccess,
        volume: VolumeInfo,
        depth: Int,
        fromScratch: Bool,
        limits: IndexingRunLimits = .standard
    ) async throws -> String {
        let before = ProcessMeter.residentBytes()
        let cpu = ProcessMeter.cpuSeconds()
        let clock = ContinuousClock.now
        var peak = before
        let outcome = await DirectoryIndexer().run(
            store: harness.store,
            access: access,
            mediumUUID: medium.uuid,
            volume: volume,
            configuration: ScanConfiguration(maxDepth: depth, ignoreHiddenFiles: true, excludedPatterns: [], limits: limits),
            fromScratch: fromScratch,
            token: UUID(),
            shouldHalt: { .none }
        )
        peak = max(peak, ProcessMeter.residentBytes())
        let after = ProcessMeter.residentBytes()
        let elapsed = clock.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let database = harness.directory.appendingPathComponent("archive.sqlite")
        let wal = harness.directory.appendingPathComponent("index.sqlite-wal")
        return "\(label) status=\(outcome.status) proben=\(outcome.progress.count) dauer=\(String(format: "%.2f", seconds))s cpu=\(String(format: "%.2f", ProcessMeter.cpuSeconds() - cpu))s ram-vorher=\(before) ram-nachher=\(after) ram-spitze=\(peak) db=\(size(database)) wal=\(size(wal))"
    }

    private func wideColumn() async throws -> String {
        let harness = try StoreHarness.make()
        let medium = try await harness.insert(name: "Breit", fsType: "apfs", bytes: 1_000)
        let entries = (0..<500_000).map { ScannedEntry(name: "datei-\($0).txt", isFolder: false, sizeBytes: 1) }
        let before = ProcessMeter.residentBytes()
        let clock = ContinuousClock.now
        _ = try await harness.addRoot(medium: medium, entries: entries)
        let stored = clock.duration(to: .now)
        let repository = IndexRepository(store: harness.store)
        fputs("phase spalte-laden\n", stderr)
        fflush(stderr)
        let loadStart = ContinuousClock.now
        _ = await repository.loadChildren(mediumID: medium.uuid, path: [])
        let loaded = loadStart.duration(to: .now)
        let after = ProcessMeter.residentBytes()
        let searchStart = ContinuousClock.now
        let match = await SearchIndex.matching(
            store: harness.store,
            query: "datei-1",
            filters: SearchFilters(),
            media: [],
            maxDepth: nil
        )
        let searched = searchStart.duration(to: .now)
        return "spalte-500000 speichern=\(stored) laden=\(loaded) suche=\(searched) treffer=\(match.itemCount ?? -1) seite=\(match.items.count) ram-vorher=\(before) ram-nachher=\(after)"
    }

    private func syntheticVolume() -> VolumeInfo {
        VolumeInfo(
            mountPath: "/synthetic",
            name: "Synth",
            fsType: "apfs",
            volumeTotalBytes: 1_000,
            volumeFreeBytes: 100,
            diskSizeBytes: nil,
            volumeUUID: UUID().uuidString,
            createdAt: Date(timeIntervalSince1970: 10),
            isRemovable: true,
            isEjectable: true,
            isInternal: false,
            isLocal: true,
            deviceProtocol: "USB",
            model: nil,
            isTimeMachineSnapshot: false
        )
    }

    private func size(_ url: URL) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    }
}
}
