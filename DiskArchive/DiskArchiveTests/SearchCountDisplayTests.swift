//
//  SearchCountDisplayTests.swift
//  DiskArchiveTests
//
//  Aufgabe 215 — Ergebnisse sofort, Trefferzahl danach („–“), neue Suche bricht die alte Zählung ab.
//

import Foundation
import Testing
@testable import DiskArchive

private final class CountSamples: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Int?] = []
    func add(_ value: Int?) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }
    var all: [Int?] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

extension WindowTestGroup {
@Suite @MainActor
struct SearchCountDisplayTests {
    private func appWithData() async throws -> (AppState, IndexStoreV3) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-countdisplay-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "ZAHL", type: .usb, decision: .index)
        try await store.upsertMedium(medium)
        var entries = (0..<30).map { ScannedEntry(name: "bericht-\($0).pdf", isFolder: false, sizeBytes: 1) }
        entries += (0..<10).map { ScannedEntry(name: "protokoll-\($0).txt", isFolder: false, sizeBytes: 1) }
        try await store.applyDirectories(
            mediumUUID: medium.uuid,
            batches: [(parentID: nil, path: "/", depth: 1, entries: entries, finalize: false)],
            seenAt: Date()
        )
        try await store.completeLayer(mediumUUID: medium.uuid, depth: 1)
        let app = AppState(store: store)
        await app.loadStoredMedia()
        app.mainWindowDestination = .search
        return (app, store)
    }

    @Test func resultsAppearBeforeTheCountAndTheCountFollows() async throws {
        let (app, store) = try await appWithData()
        await store.setSearchCountDelay(.milliseconds(600))
        app.searchState.submittedQuery = "bericht"
        await app.runSearch()
        #expect(app.searchMatch.items.count == 30, "Ergebnisse müssen sofort da sein")
        #expect(app.searchMatch.itemCount == nil, "Zahl muss noch „–“ sein")
        #expect(ObjectCountFormatting.pendingLabel == "–")
        await app.waitForSearchCount()
        #expect(app.searchMatch.itemCount == 30)
        #expect(app.searchMatch.unfilteredItemCount == 30)
    }

    @Test func aNewSearchDropsTheOldCount() async throws {
        let (app, store) = try await appWithData()
        await store.setSearchCountDelay(.milliseconds(500))
        app.searchState.submittedQuery = "bericht"
        await app.runSearch()
        let samples = CountSamples()
        let sampler = Task { @MainActor in
            while !Task.isCancelled {
                samples.add(app.searchMatch.itemCount)
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
        // Zweite Suche, während die erste noch zählt; ihre Zählung dauert länger als der Rest der ersten.
        // bug.0.3.8.007: kein fester Schlaf (60 ms) mehr vor der zweiten Suche — er konnte unter Last länger als
        // die erste Zählung dauern. Die Vorbedingung wird geprüft: Zwischen dieser Prüfung und dem Generations-
        // wechsel am Anfang von `runSearch` gibt der Main Actor nicht ab, die erste Zahl kann also nicht mehr landen.
        await store.setSearchCountDelay(.milliseconds(1_200))
        try #require(app.searchMatch.itemCount == nil, "Vorbedingung: die erste Zählung läuft noch")
        app.searchState.submittedQuery = "protokoll"
        await app.runSearch()
        #expect(app.searchMatch.items.count == 10)
        await app.waitForSearchCount()
        try await Task.sleep(for: .milliseconds(200))
        sampler.cancel()
        #expect(app.searchMatch.itemCount == 10)
        #expect(!samples.all.contains(30), "die Zahl der ersten Suche darf nie erscheinen")
    }
}
}
