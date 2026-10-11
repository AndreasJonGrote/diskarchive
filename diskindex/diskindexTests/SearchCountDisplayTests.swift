//
//  SearchCountDisplayTests.swift
//  diskindexTests
//
//  Aufgabe 215 — Ergebnisse sofort, Trefferzahl danach („–“), neue Suche bricht die alte Zählung ab.
//

import Foundation
import Testing
@testable import diskindex

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
    private func appWithData() async throws -> (AppState, IndexStore) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-countdisplay-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStore(database: try IndexDatabase(fileURL: directory.appendingPathComponent("index.sqlite")))
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
        await store.setSearchCountDelay(.milliseconds(300))
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
        try await Task.sleep(for: .milliseconds(60))
        await store.setSearchCountDelay(.milliseconds(700))
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
