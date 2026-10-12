//
//  StickProgressTests.swift
//  diskindexTests
//
//  Attrappe: Stick-Verteilung 700/700/14_300/14_300/1_400 skaliert ÷100 (Spec 105.7).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct StickProgressTests {
    @Test func scaledStickRunHasManyMonotonicProgressSteps() async throws {
        let harness = try await StickScanHarness.make(
            limits: IndexingRunLimits(batchEntryLimit: 8, directoryChunkSize: 4)
        )
        let access = makeStickVolume()
        let countingItemCount = MaxCounter()
        let outcome = try await harness.run(access: access, onProgress: { progress in
            if progress.phase == .counting {
                let live = (try? await harness.liveVisibleEntryCount()) ?? 0
                countingItemCount.update(live)
            }
        })
        #expect(outcome.status == .indexed)
        // Vorlauf (206): während der Zählung sind genau Ebene 1 und 2 gespeichert (7+1+7+1 Einträge).
        #expect(countingItemCount.value == 16)
        let ratios = outcome.progress
        let percents = ratios.map { Int(floor($0 * 100)) }
        #expect(Set(percents).count >= 20)
        #expect(zip(percents, percents.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(zip(ratios, ratios.dropFirst()).allSatisfy { $0 <= $1 })
        // Der erste Sprung nach der Zählung enthält die schon gespeicherten Ebenen 1 und 2 (16 von 314 ≈ 5 %).
        for pair in zip(percents, percents.dropFirst()).dropFirst() {
            #expect(pair.1 - pair.0 <= 5)
        }
        if let a = percents.first, percents.count > 1 {
            #expect(percents[1] - a <= 6)
        }
        #expect(ratios.last.map { $0 >= 0.98 } ?? false)
    }

    @Test func repeatRunShowsPercentFromStoredScanTotal() async throws {
        let harness = try await StickScanHarness.make()
        let access = makeStickVolume()
        _ = try await harness.run(access: access, fromScratch: true)
        let firstPercent = LockedOptionalInt()
        _ = try await harness.run(access: access, fromScratch: false, onProgress: { progress in
            guard progress.phase == .indexing, !progress.finished, firstPercent.value == nil else { return }
            let stored = try? await harness.store.medium(uuid: harness.mediumID)
            guard let stored else { return }
            await MainActor.run {
                var medium = Medium(
                    id: harness.mediumID,
                    name: "S",
                    type: .usb,
                    connectionStatus: .connected,
                    indexStatus: .indexing,
                    allowIndexing: true,
                    autoIndexPaused: false,
                    capacityTotalBytes: 1,
                    capacityUsedBytes: 0,
                    fileCount: stored.fileCount,
                    folderCount: stored.folderCount,
                    lastSeenAt: nil,
                    firstIndexedAt: Date(),
                    lastIndexedAt: nil,
                    isForgotten: false,
                    indexingProgress: progress.ratio
                )
                medium.scanTotal = stored.scanTotal > 0 ? stored.scanTotal : progress.entriesTotal
                medium.indexingProgress = progress.ratio
                firstPercent.set(medium.indexProgressPercent)
            }
        })
        #expect((firstPercent.value ?? 0) > 0)
    }
}

private final class MaxCounter: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var value = 0
    func update(_ next: Int) {
        lock.lock()
        value = max(value, next)
        lock.unlock()
    }
}

private final class LockedOptionalInt: @unchecked Sendable {
    private let lock = NSLock()
    var value: Int?
    func set(_ next: Int) {
        lock.lock()
        value = next
        lock.unlock()
    }
}

private struct StickScanHarness {
    let store: IndexStoreV3
    let mediumID: UUID
    let limits: IndexingRunLimits
    private let indexer = DirectoryIndexer()

    static func make(limits: IndexingRunLimits = IndexingRunLimits.standard) async throws -> StickScanHarness {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-stick-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000_000, name: "STICK", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        return StickScanHarness(store: store, mediumID: medium.uuid, limits: limits)
    }

    func run(
        access: MemoryVolume,
        fromScratch: Bool = true,
        onProgress: @escaping @Sendable (IndexProgress) async -> Void = { _ in }
    ) async throws -> IndexRunOutcome {
        return await indexer.run(
            store: store,
            access: access,
            mediumUUID: mediumID,
            volume: VolumeInfo(
                mountPath: access.mountPath,
                name: "STICK",
                fsType: "apfs",
                volumeTotalBytes: 1_000_000,
                volumeFreeBytes: nil,
                diskSizeBytes: nil,
                volumeUUID: nil,
                createdAt: nil,
                isRemovable: true,
                isEjectable: true,
                isInternal: false,
                isLocal: true,
                deviceProtocol: "USB",
                model: nil,
                isTimeMachineSnapshot: false
            ),
            configuration: ScanConfiguration(
                maxDepth: nil,
                ignoreHiddenFiles: true,
                excludedPatterns: [],
                limits: limits
            ),
            fromScratch: fromScratch,
            token: UUID(),
            shouldHalt: { .none },
            onProgress: onProgress
        )
    }

    func liveVisibleEntryCount() async throws -> Int {
        var total = 0
        func walk(_ parent: Int64?) async throws {
            let children = try await store.children(mediumUUID: mediumID, parentID: parent)
            total += children.count
            for child in children where child.isFolder {
                try await walk(child.id)
            }
        }
        try await walk(nil)
        return total
    }
}

private func makeStickVolume() -> MemoryVolume {
    let volume = MemoryVolume(mountPath: "/Volumes/STICK")
    for index in 0..<7 { volume.file("r-\(index).txt") }
    for index in 0..<7 { volume.file("l1/r-\(index).txt") }
    for index in 0..<143 { volume.file("l1/l2/f-\(index).txt") }
    for index in 0..<143 { volume.file("l1/l2/l3/f-\(index).txt") }
    for index in 0..<14 { volume.file("l1/l2/l3/l4/f-\(index).txt") }
    return volume
}
