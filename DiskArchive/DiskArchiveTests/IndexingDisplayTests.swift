//
//  IndexingDisplayTests.swift
//  DiskArchiveTests
//
//  Aufgabe 210 — ruhige Phase beim Abgleich, drehender Spinner im Dashboard-Chip.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

private final class PhaseLog: @unchecked Sendable {
    private let lock = NSLock()
    private var phases: [IndexRunPhase] = []
    func add(_ phase: IndexRunPhase) {
        lock.lock()
        phases.append(phase)
        lock.unlock()
    }
    var all: [IndexRunPhase] {
        lock.lock()
        defer { lock.unlock() }
        return phases
    }
}

extension WindowTestGroup {
@Suite @MainActor
struct IndexingDisplayTests {
    @Test func reconcileWithStoredTotalReportsOnlyTheIndexingPhase() async throws {
        let harness = try await ScanHarness.make()
        let access = MemoryVolume(mountPath: "/Volumes/T")
        for index in 0..<12 { access.file("d\(index)/e/f.txt") }
        _ = try await harness.run(access: access, maxDepth: nil, fromScratch: true)
        let stored = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(stored.scanTotal > 0)

        access.slowListing(fromDepth: 1)
        let log = PhaseLog()
        let outcome = try await harness.run(access: access, maxDepth: nil, fromScratch: false, onProgress: { progress in
            log.add(progress.phase)
        })
        #expect(outcome.status == .indexed)
        #expect(!log.all.isEmpty)
        #expect(log.all.allSatisfy { $0 == .indexing })
        // Der Nachzähler läuft im Hintergrund weiter und darf nichts mehr melden.
        try await Task.sleep(for: .milliseconds(600))
        #expect(log.all.allSatisfy { $0 == .indexing })
    }

    @Test func spinnerAngleAdvancesWithTime() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let a = IndexingSpinnerRing.angle(at: start)
        let b = IndexingSpinnerRing.angle(at: start.addingTimeInterval(0.3))
        #expect(abs((b - a).truncatingRemainder(dividingBy: 360) - 120) < 0.5 || abs((b - a) + 240) < 0.5)
    }

    @Test func dashboardChipSpinnerRotates() async throws {
        let app = AppState()
        var medium = Medium(
            id: UUID(),
            name: "Wird indiziert",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .indexing,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 1_000,
            capacityUsedBytes: 100,
            fileCount: 40,
            folderCount: 4,
            lastSeenAt: Date(),
            firstIndexedAt: Date(),
            lastIndexedAt: nil,
            isForgotten: false,
            indexingProgress: 0.4
        )
        medium.completedDepth = 1
        app.globalAutoIndexPaused = false
        let size = CGSize(width: 220, height: 60)
        let session = PixelProbe.open(
            StatusChip(medium: medium).environment(app).environment(\.colorScheme, .light)
                .padding(20).frame(width: size.width, height: size.height, alignment: .topLeading)
                .background(Color.white),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        // Spinner links im Chip: kleiner Bereich um sein Zentrum.
        let region = CGRect(x: 24, y: 20, width: 20, height: 20)
        func snapshot() -> [UInt8] {
            session.window.contentView?.layoutSubtreeIfNeeded()
            session.window.display()
            let bitmap = session.bitmap()
            var bytes: [UInt8] = []
            var y = Int(region.minY)
            while y < Int(region.maxY) {
                var x = Int(region.minX)
                while x < Int(region.maxX) {
                    let color = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                    bytes.append(UInt8(max(0, min(255, color.alphaComponent * 255))))
                    bytes.append(UInt8(max(0, min(255, color.greenComponent * 255))))
                    x += 1
                }
                y += 1
            }
            return bytes
        }
        let first = snapshot()
        #expect(!first.isEmpty)
        // bug.0.3.8.007: bis zu 5 s auf eine Änderung warten statt genau einer Aufnahme nach 300 ms —
        // unter Parallel-Last kann ein einzelnes Bild zufällig noch gleich sein.
        let changed = await waitUntil(timeout: 5) { snapshot() != first }
        #expect(changed, "Spinner hat sich zwischen den Aufnahmen nicht verändert")
    }
}
}
