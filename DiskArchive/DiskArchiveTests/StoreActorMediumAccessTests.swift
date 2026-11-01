//
//  StoreActorMediumAccessTests.swift
//  DiskArchiveTests
//
//  bug.0.4.226: Der Actor `IndexStoreV3` greift nie auf ein Speichermedium zu (auch nicht mit `stat`/`getattrlist`
//  beim Pfadbau). Liest oder hängt eine Platte, schreiben die anderen Medien weiter.
//

import Foundation
import Testing
@testable import DiskArchive

@Suite(.serialized) @MainActor
struct StoreActorMediumAccessTests {
    /// Test 1: Medium A hängt beim Lesen einer Teil-Prüfsumme (3 s). Währenddessen beginnt ein Lauf für Medium B und
    /// schreibt einen Stapel – ohne auf A zu warten.
    @Test func slowPartialReadOfOneMediumDoesNotHoldUpAnotherRun() async throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-store-actor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let seen = Date(timeIntervalSince1970: 1_700_000_400)
        let payload = Data(repeating: 0xAA, count: 128)
        let harness = try StoreHarness.make()
        let store = harness.store
        // A: Favorit mit gespeicherter Teil-Prüfsumme, dann verschwunden – die neue Datei gleicher Größe muss gelesen werden.
        let slow = try await harness.insert(name: "Daten I", fsType: "exfat", bytes: 1_000)
        let favorite = try #require(try await harness.addRoot(
            medium: slow, entries: [ScannedEntry(name: "a.bin", isFolder: false, sizeBytes: 128, modifiedAt: seen)], seenAt: seen
        ).first)
        try payload.write(to: mount.appendingPathComponent("a.bin"))
        try await store.setFavorite(itemID: favorite.id, true)
        try await store.storePartialChecksum(itemID: favorite.id, mountPath: mount.path)
        try await store.applyDirectory(mediumUUID: slow.uuid, parentID: nil, entries: [], seenAt: seen)
        try payload.write(to: mount.appendingPathComponent("restored.bin"))
        let other = try await harness.insert(name: "Transfer", fsType: "apfs", bytes: 1_000)

        await store.setPartialChecksumComputeDelayForTesting(3.0)
        let readStarted = Signal()
        let slowDone = Signal()
        store.precomputeReadHookForTesting.set { readStarted.raise() }
        let slowTask = Task {
            try await store.applyDirectories(
                mediumUUID: slow.uuid,
                batches: [(parentID: nil, path: nil, depth: nil, entries: [
                    ScannedEntry(name: "restored.bin", isFolder: false, sizeBytes: 128, modifiedAt: seen),
                ], finalize: true)],
                seenAt: seen, mountPath: mount.path
            )
            slowDone.raise()
        }
        #expect(await waitUntil(timeout: 10) { readStarted.isRaised }, "Lesen auf A hat nicht begonnen")

        let otherDone = Signal()
        let otherTask = Task {
            guard try await store.beginIndexing(mediumUUID: other.uuid, token: UUID()) else { return }
            try await store.applyDirectories(
                mediumUUID: other.uuid,
                batches: [(parentID: nil, path: nil, depth: nil, entries: [
                    ScannedEntry(name: "neu.txt", isFolder: false, sizeBytes: 5, modifiedAt: seen),
                ], finalize: true)],
                seenAt: seen
            )
            otherDone.raise()
        }
        let finished = await waitUntil(timeout: 2) { otherDone.isRaised }
        #expect(finished, "Lauf von B wartete auf das Lesen von A")
        #expect(!slowDone.isRaised, "Vorbedingung: A las noch, als B schrieb")
        try await otherTask.value
        try await slowTask.value
        await store.setPartialChecksumComputeDelayForTesting(nil)
        #expect(try await store.children(mediumUUID: other.uuid, parentID: nil).map(\.name) == ["neu.txt"])
        let restored = try await store.children(mediumUUID: slow.uuid, parentID: nil)
        #expect(restored.map(\.id) == [favorite.id], "Favorit von A nicht wiederverbunden")
    }

    /// Test 2: Quelltext-Wächter – im Actor-Code von `IndexStoreV3` kein `FileManager`, kein Pfadbau mit Plattenzugriff
    /// (`appendPathComponent`), kein Lesen von Dateien; der Pfadbau `DirectoryWriterV3.fileURL` fragt die Platte nicht.
    /// Ausgenommen sind nur `storeFileURL` und `inventoryLabels` (die eigene Datenbank, kein Medium).
    @Test func storeActorCodeHasNoMediumAccess() throws {
        var repo = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { repo.deleteLastPathComponent() }
        let folder = repo.appending(path: "DiskArchive/DiskArchive/Storage/V3", directoryHint: .isDirectory)
        var violations: [String] = []
        for file in ["IndexStoreV3.swift", "IndexStoreV3+Reading.swift"] {
            var code = Self.withoutComments(try String(contentsOf: folder.appending(path: file), encoding: .utf8))
            for name in ["storeFileURL", "inventoryLabels"] {
                code = code.replacingOccurrences(of: Self.function(named: name, in: code), with: "")
            }
            #expect(code.contains("IndexStoreV3 {"), "\(file) nicht gelesen")
            for pattern in Self.forbidden where code.contains(pattern) {
                violations.append("\(file): \(pattern)")
            }
        }
        let writer = Self.withoutComments(try String(contentsOf: folder.appending(path: "DirectoryWriterV3.swift"), encoding: .utf8))
        let pathBuilder = Self.function(named: "fileURL", in: writer)
        #expect(pathBuilder.contains("mountPath"), "DirectoryWriterV3.fileURL nicht gefunden")
        for pattern in Self.forbidden where pathBuilder.contains(pattern) {
            violations.append("DirectoryWriterV3.fileURL: \(pattern)")
        }
        #expect(violations.isEmpty, "Plattenzugriff im Store-Actor: \(violations.joined(separator: "; "))")
    }

    private static let forbidden = [
        "FileManager", "appendPathComponent", "appendingPathComponent", "resourceValues", "attributesOfItem",
        "fileExists", "PartialChecksum.compute(", "FileHandle", "getattrlist", "contentsOfDirectory",
    ]

    private static func withoutComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> Substring in
            guard let range = line.range(of: "//") else { return line }
            return line[..<range.lowerBound]
        }.joined(separator: "\n")
    }

    /// Der Text der Funktion `name` von `func` bis zur passenden schließenden Klammer (leer, wenn es sie nicht gibt).
    private static func function(named name: String, in code: String) -> String {
        guard let start = code.range(of: "func \(name)("),
              let open = code[start.upperBound...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var index = open
        while index < code.endIndex {
            switch code[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(code[start.lowerBound...index]) }
            default: break
            }
            index = code.index(after: index)
        }
        return ""
    }
}

/// Einmal gesetztes Signal, von beliebigen Fäden lesbar.
private final class Signal: @unchecked Sendable {
    private let lock = NSLock()
    private var raised = false
    var isRaised: Bool { lock.withLock { raised } }
    func raise() { lock.withLock { raised = true } }
}
