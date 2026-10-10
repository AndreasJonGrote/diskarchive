#if BENCH
//
//  ColumnLoadBench.swift
//  diskindex
//
//  Aufgabe 107 — nur mit Build-Flag BENCH:
//  `Disk Index --column-load-bench [ausgabedatei]`
//

import AppKit
import Darwin
import Foundation

nonisolated enum ColumnLoadBench {
    static let argument = "--column-load-bench"

    @MainActor
    static func run(arguments: [String]) {
        let outPath = Self.outputPath(arguments: arguments)
            ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("diskindex-column-load.txt").path
        var lines: [String] = [
            "diskindex column-load bench \(ISO8601DateFormatter().string(from: Date()))",
            "config=\(BuildChannel.isDebug ? "Debug" : "Release")",
            "batchSize=\(IndexRepository.loadBatchSize)",
            "flag=BENCH",
            "display=NSTableView",
        ]
        func keep(_ line: String) {
            lines.append(line)
            let body = lines.joined(separator: "\n") + "\n"
            try? body.write(to: URL(fileURLWithPath: outPath), atomically: true, encoding: .utf8)
            fputs(line + "\n", stderr)
            fflush(stderr)
        }

        let baselineRAM = residentBytes()
        keep("baseline-ram-bytes=\(baselineRAM)")

        Task { @MainActor in
            do {
                for count in [14_300, 100_000, 200_000] {
                    let pair = try await measureWideAndDisplay(childCount: count, baselineRAM: baselineRAM)
                    keep(pair.load)
                    keep(pair.display)
                    await Task.yield()
                }
                keep(try await measureFormA())
                keep(try await measurePageQuery(childCount: 30_000))
                // Skaliert (Referenz)
                keep(try await measureIndexerShape(
                    label: "form-b-scaled",
                    foldersPerDirectory: 10,
                    filesPerDirectory: 5,
                    maxDepth: 4
                ))
                keep(try await measureIndexerShape(
                    label: "form-c-scaled",
                    foldersPerDirectory: 6,
                    filesPerDirectory: 50,
                    maxDepth: 4
                ))
                // Vollgröße Spezifikation
                keep(try await measureIndexerShape(
                    label: "form-b-full",
                    foldersPerDirectory: 18,
                    filesPerDirectory: 5,
                    maxDepth: 4
                ))
                keep(try await measureIndexerShape(
                    label: "form-c-full",
                    foldersPerDirectory: 7,
                    filesPerDirectory: 50,
                    maxDepth: 5
                ))
                keep("done out=\(outPath)")
                exit(0)
            } catch {
                keep("error \(error)")
                exit(1)
            }
        }
    }

    static func outputPath(arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: argument),
              arguments.indices.contains(index + 1),
              !arguments[index + 1].hasPrefix("-") else { return nil }
        return arguments[index + 1]
    }

    @MainActor
    private static func measureFormA() async throws -> String {
        let harness = try BenchStore.make()
        defer { harness.close() }
        let medium = try await harness.insert(name: "FormA")
        let folders = try await harness.addRoot(
            medium: medium,
            entries: (0..<3).map { ScannedEntry(name: "bulk-\($0)", isFolder: true) }
        )
        let seen = Date()
        let seedStart = ContinuousClock.now
        for folder in folders {
            try await seedChildren(store: harness.store, mediumUUID: medium.uuid, parentID: folder.id, count: 100_000, seenAt: seen)
        }
        let seedSeconds = seconds(seedStart.duration(to: .now))
        let target = folders[0]
        let ramBefore = residentBytes()
        let repository = IndexRepository(store: harness.store)
        let loadStart = ContinuousClock.now
        let items = await repository.loadChildren(mediumID: medium.uuid, path: [target.name])
        let loadSeconds = seconds(loadStart.duration(to: .now))
        let ramDeltaMB = Double(Int64(residentBytes()) - Int64(ramBefore)) / 1_048_576
        return "form-a seed-s=\(fmt(seedSeconds)) load-s=\(fmt(loadSeconds)) count=\(items.count) ram-delta-mb=\(fmt(ramDeltaMB)) goal-load=<2.5s"
    }

    @MainActor
    private static func measureWideAndDisplay(childCount: Int, baselineRAM: UInt64) async throws -> (load: String, display: String) {
        let harness = try BenchStore.make()
        defer { harness.close() }
        let medium = try await harness.insert(name: "Wide-\(childCount)")
        _ = try await harness.addRoot(medium: medium, entries: [ScannedEntry(name: "Big", isFolder: true)])
        guard let folderID = try await harness.store.folderID(mediumUUID: medium.uuid, path: ["Big"]) else {
            return ("wide-\(childCount) error=missing-folder", "display-\(childCount) error=missing-folder")
        }
        let seedStart = ContinuousClock.now
        try await seedChildren(store: harness.store, mediumUUID: medium.uuid, parentID: folderID, count: childCount, seenAt: Date())
        let seedSeconds = seconds(seedStart.duration(to: .now))

        let ramBefore = residentBytes()
        let pageStart = ContinuousClock.now
        let firstPage = try await harness.store.childrenPage(
            mediumUUID: medium.uuid,
            parentID: folderID,
            limit: IndexRepository.loadBatchSize,
            after: nil
        )
        let firstPageMs = seconds(pageStart.duration(to: .now)) * 1_000

        let repository = IndexRepository(store: harness.store)
        let loadStart = ContinuousClock.now
        let items = await repository.loadChildren(mediumID: medium.uuid, path: ["Big"])
        let loadSeconds = seconds(loadStart.duration(to: .now))
        let ramAfterLoad = residentBytes()
        let ramDeltaMB = Double(Int64(ramAfterLoad) - Int64(ramBefore)) / 1_048_576
        let vsBaselineMB = Double(Int64(ramAfterLoad) - Int64(baselineRAM)) / 1_048_576
        let pass: Bool = switch childCount {
        case 14_300: loadSeconds < 0.5
        case 100_000: loadSeconds < 2.5
        case 200_000: loadSeconds < 5.0
        default: false
        }
        let goal: String = switch childCount {
        case 14_300: "<0.5s"
        case 100_000: "<2.5s"
        case 200_000: "<5s"
        default: "?"
        }
        let loadLine = [
            "wide-\(childCount)",
            "seed-s=\(fmt(seedSeconds))",
            "load-s=\(fmt(loadSeconds))",
            "first-page-ms=\(fmt(firstPageMs))",
            "first-page-count=\(firstPage.items.count)",
            "count=\(items.count)",
            "ram-delta-mb=\(fmt(ramDeltaMB))",
            "ram-vs-baseline-mb=\(fmt(vsBaselineMB))",
            "goal=\(goal)",
            "pass=\(pass ? "yes" : "no")",
        ].joined(separator: " ")

        let names = items.map(\.name)
        let ramBeforeDisplay = residentBytes()
        let metrics = measureDisplayOnMain(names: names)
        let ramAfterDisplay = residentBytes()
        let firstGoal = 150.0
        let blockGoal = 50.0
        let displayLine = [
            "display-\(childCount)",
            "first-visible-ms=\(fmt(metrics.firstMs))",
            "max-main-block-ms=\(fmt(metrics.blockMs))",
            "count=\(names.count)",
            "ram-delta-mb=\(fmt(Double(Int64(ramAfterDisplay) - Int64(ramBeforeDisplay)) / 1_048_576))",
            "ram-vs-baseline-mb=\(fmt(Double(Int64(ramAfterDisplay) - Int64(baselineRAM)) / 1_048_576))",
            "goal-first-ms=<\(Int(firstGoal))",
            "goal-block-ms=<\(Int(blockGoal))",
            "pass-first=\(metrics.firstMs >= 0 && metrics.firstMs < firstGoal ? "yes" : "no")",
            "pass-block=\(metrics.blockMs < blockGoal ? "yes" : "no")",
        ].joined(separator: " ")
        return (loadLine, displayLine)
    }

    /// Synchron auf dem Hauptfaden: Layout-Dauer = Blockade, onAppear = erste Zeile (NSTableView).
    @MainActor
    private static func measureDisplayOnMain(names: [String]) -> (firstMs: Double, blockMs: Double) {
        var firstMs: Double = -1
        let displayStart = ContinuousClock.now
        return autoreleasepool {
            let scroll = NSScrollView()
            scroll.hasVerticalScroller = true
            scroll.drawsBackground = false
            scroll.frame = NSRect(x: 0, y: 0, width: 320, height: 640)

            let table = BenchNSTable(names: names) {
                if firstMs < 0 {
                    firstMs = seconds(displayStart.duration(to: .now)) * 1_000
                }
            }
            table.headerView = nil
            table.backgroundColor = .clear
            table.rowHeight = 32
            table.style = .plain
            let column = NSTableColumn(identifier: .init("row"))
            table.addTableColumn(column)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 640),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            let blockStart = ContinuousClock.now
            scroll.documentView = table
            window.contentView = scroll
            window.orderFrontRegardless()
            table.reloadData()
            scroll.layoutSubtreeIfNeeded()
            let blockMs = seconds(blockStart.duration(to: .now)) * 1_000

            let deadline = Date().addingTimeInterval(45)
            while firstMs < 0, Date() < deadline {
                CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.01, true)
            }
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.15, false)

            window.contentView = nil
            window.orderOut(nil)
            window.close()
            return (firstMs, blockMs)
        }
    }

    @MainActor
    private static func measurePageQuery(childCount: Int) async throws -> String {
        let harness = try BenchStore.make()
        defer { harness.close() }
        let medium = try await harness.insert(name: "Page")
        _ = try await harness.addRoot(medium: medium, entries: [ScannedEntry(name: "Big", isFolder: true)])
        guard let folderID = try await harness.store.folderID(mediumUUID: medium.uuid, path: ["Big"]) else {
            return "page-500 error=missing-folder"
        }
        try await seedChildren(store: harness.store, mediumUUID: medium.uuid, parentID: folderID, count: childCount, seenAt: Date())
        var times: [Double] = []
        var cursor: ItemChildrenCursor?
        for _ in 0..<3 {
            let start = ContinuousClock.now
            let page = try await harness.store.childrenPage(
                mediumUUID: medium.uuid,
                parentID: folderID,
                limit: 500,
                after: cursor
            )
            times.append(seconds(start.duration(to: .now)) * 1_000)
            cursor = page.nextCursor
        }
        let avg = times.reduce(0, +) / Double(max(times.count, 1))
        return "page-500-on-\(childCount) avg-ms=\(fmt(avg)) samples=\(times.map { fmt($0) }.joined(separator: ",")) goal=<30ms pass=\(avg < 30 ? "yes" : "no")"
    }

    @MainActor
    private static func measureIndexerShape(
        label: String,
        foldersPerDirectory: Int,
        filesPerDirectory: Int,
        maxDepth: Int
    ) async throws -> String {
        let harness = try BenchStore.make()
        defer { harness.close() }
        let medium = try await harness.insert(name: label)
        let access = BenchSyntheticAccess(
            foldersPerDirectory: foldersPerDirectory,
            filesPerDirectory: filesPerDirectory,
            maxDepth: maxDepth
        )
        let volume = VolumeInfo(
            mountPath: "/synthetic-\(label)",
            name: label,
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
        let ramBefore = residentBytes()
        let start = ContinuousClock.now
        let outcome = await DirectoryIndexer().run(
            store: harness.store,
            access: access,
            mediumUUID: medium.uuid,
            volume: volume,
            configuration: ScanConfiguration(
                maxDepth: maxDepth,
                ignoreHiddenFiles: true,
                excludedPatterns: [],
                limits: .standard
            ),
            fromScratch: true,
            token: UUID(),
            shouldHalt: { .none }
        )
        let elapsed = seconds(start.duration(to: .now))
        let ramAfter = residentBytes()
        let truth = try await harness.store.counts(mediumUUID: medium.uuid)
        let foldersPerSec = elapsed > 0 ? Double(truth.folders) / elapsed : 0
        let filesPerSec = elapsed > 0 ? Double(truth.files) / elapsed : 0
        return [
            label,
            "status=\(outcome.status)",
            "dauer-s=\(fmt(elapsed))",
            "folders=\(truth.folders)",
            "files=\(truth.files)",
            "folders-per-s=\(fmt(foldersPerSec))",
            "files-per-s=\(fmt(filesPerSec))",
            "ram-delta-mb=\(fmt(Double(Int64(ramAfter) - Int64(ramBefore)) / 1_048_576))",
            "branch=\(foldersPerDirectory)",
            "depth=\(maxDepth)",
        ].joined(separator: " ")
    }

    private static func seedChildren(
        store: IndexStore,
        mediumUUID: UUID,
        parentID: Int64,
        count: Int,
        seenAt: Date
    ) async throws {
        let entries = (0..<count).map { i in
            ScannedEntry(name: "file-\(i).txt", isFolder: false, sizeBytes: 1, modifiedAt: seenAt)
        }
        try await store.applyDirectory(
            mediumUUID: mediumUUID,
            parentID: parentID,
            entries: entries,
            seenAt: seenAt
        )
    }

    private static func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.stride / MemoryLayout<natural_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

private enum BuildChannel {
    static var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}

private final class BenchNSTable: NSTableView, NSTableViewDataSource, NSTableViewDelegate {
    private let names: [String]
    private let onFirstRow: () -> Void
    private var didReport = false

    init(names: [String], onFirstRow: @escaping () -> Void) {
        self.names = names
        self.onFirstRow = onFirstRow
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 640))
        dataSource = self
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func numberOfRows(in tableView: NSTableView) -> Int { names.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("bench")
        let label: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField {
            label = reused
        } else {
            label = NSTextField(labelWithString: "")
            label.identifier = identifier
            label.font = .systemFont(ofSize: 13)
            label.lineBreakMode = .byTruncatingTail
        }
        label.stringValue = names[row]
        if !didReport {
            didReport = true
            onFirstRow()
        }
        return label
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 32 }
}

private final class BenchStore: @unchecked Sendable {
    let directory: URL
    let store: IndexStore
    private let closeDatabase: () -> Void

    static func make() throws -> BenchStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-column-bench-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try IndexDatabase(fileURL: directory.appendingPathComponent("index.sqlite"))
        return BenchStore(directory: directory, store: IndexStore(database: database)) {
            try? database.close()
        }
    }

    private init(directory: URL, store: IndexStore, closeDatabase: @escaping () -> Void) {
        self.directory = directory
        self.store = store
        self.closeDatabase = closeDatabase
    }

    func close() {
        closeDatabase()
        try? FileManager.default.removeItem(at: directory)
    }

    func insert(name: String) async throws -> StoredMedium {
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: name)
        try await store.upsertMedium(medium)
        return medium
    }

    func addRoot(medium: StoredMedium, entries: [ScannedEntry]) async throws -> [StoredItem] {
        try await store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: entries, seenAt: Date())
        return try await store.children(mediumUUID: medium.uuid, parentID: nil)
    }
}

private struct BenchSyntheticAccess: MediumAccess {
    var foldersPerDirectory: Int
    var filesPerDirectory: Int
    var maxDepth: Int

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        let depth = max(0, url.pathComponents.count - 2)
        let modified = Date(timeIntervalSince1970: 10)
        var entries: [ListedDirectoryEntry] = []
        if depth < maxDepth {
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
#endif
