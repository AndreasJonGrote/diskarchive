//
//  FavoriteEditConsistencyTests.swift
//  DiskArchiveTests
//
//  bug.0.3.9.006: Favoriten — Zahl bei Umschalten während der Zählung (a), Rücknahme bei fehlgeschlagenem Schreiben
//  (b), fertige Aufgaben werden entfernt (c), Beenden wartet auf die Schreibkette mit Zeitgrenze (d), volle Seite
//  rückt nach dem Abwählen nach (e).
//

import Foundation
import Testing
@testable import DiskArchive

/// Tor für die Favoriten-Zählung: hält jede Zählung an, bis `open()` gerufen wurde.
private actor FavoriteCountGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var arrivals = 0

    func pass() async {
        arrivals += 1
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        for waiter in pending { waiter.resume() }
    }
}

@MainActor
private struct FavoriteEditRig {
    let rig: SurfaceRig
    let medium: StoredMedium
    let mountURL: URL

    var app: AppState { rig.app }
    var store: IndexStoreV3 { rig.store }

    /// Ein Medium mit `names` in der Wurzel; `favorite` davon sind Favoriten. Die Dateien liegen auch auf „Platte“
    /// (`mountPath`), damit beim Setzen die Prüfsummen-Aufgabe läuft.
    static func make(names: [String], favorite: (String) -> Bool = { _ in true }) async throws -> FavoriteEditRig {
        let rig = try await SurfaceRig.make()
        let mountURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-favedit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mountURL, withIntermediateDirectories: true)
        var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Favoriten", decision: .index, indexStatus: .indexed, completedDepth: 3)
        try await rig.store.upsertMedium(medium)
        medium = try #require(try await rig.store.medium(uuid: medium.uuid))
        let entries = names.map { ScannedEntry(name: $0, isFolder: false, sizeBytes: 1, modifiedAt: Date()) }
        try await rig.store.applyDirectory(mediumUUID: medium.uuid, parentID: nil, entries: entries, seenAt: Date())
        let rows = try await rig.store.children(mediumUUID: medium.uuid, parentID: nil)
        let favorites = rows.filter { favorite($0.name) }.map(\.id)
        if !favorites.isEmpty { try await rig.store.setFavorites(itemIDs: favorites, true) }
        rig.app.attach(store: rig.store)
        await rig.app.loadStoredMedia()
        let path = mountURL.path
        rig.app.mountPath = { _ in path }
        return FavoriteEditRig(rig: rig, medium: medium, mountURL: mountURL)
    }

    func target(named name: String) async throws -> ObjectContextTarget {
        let rows = try await store.children(mediumUUID: medium.uuid, parentID: nil)
        let row = try #require(rows.first { $0.name == name })
        let medium = try #require(app.medium(with: self.medium.uuid))
        return .fromIndexedItem(IndexedItem(stored: row), medium: medium)
    }
}

@Suite(.serialized) @MainActor
struct FavoriteEditConsistencyTests {
    /// a) Abwählen, während die Zählung am Tor hängt: das alte Ergebnis überschreibt die Zahl nicht.
    @Test func unfavoriteDuringTheCountKeepsTheCountCurrent() async throws {
        // Typfilter: die Seite ist vollständig, gezählt wird die Gesamtzahl ohne Filter („x von y“).
        let names = (0..<10).map { String(format: "bild-%02d.jpg", $0) } + (0..<5).map { String(format: "text-%02d.pdf", $0) }
        let rig = try await FavoriteEditRig.make(names: names)
        rig.app.mainWindowDestination = .favorites
        rig.app.searchState.filters.fileTypes = [.image]
        let gate = FavoriteCountGate()
        let app = rig.app
        let load = Task {
            await AppState.$favoriteCountGateForTesting.withValue({ await gate.pass() }) {
                await app.reloadFavorites()
            }
        }
        let arrived = await waitUntil(timeout: 10) { await gate.arrivals >= 1 }
        try #require(arrived, "Zählung erreicht das Tor nicht")
        #expect(rig.app.favoriteObjects.count == 10)
        let first = try #require(rig.app.favoriteObjects.first)
        rig.app.toggleFavorite(.fromSearchResult(first))
        await gate.open()
        await load.value
        await rig.app.waitForFavoriteWrites()
        #expect(rig.app.favoriteItemCount == 9)
        #expect(rig.app.favoriteUnfilteredCount == 14, "Gesamtzahl nach dem Abwählen (Zählung lief vor dem Abwählen)")
    }

    /// b) Schreiben schlägt fehl (unbekannte Zeile): lokaler Stand kehrt zurück, Datenbank unverändert.
    @Test func failedWriteRevertsTheLocalState() async throws {
        let rig = try await FavoriteEditRig.make(names: ["a.pdf", "b.pdf"], favorite: { $0 == "b.pdf" })
        await rig.app.reloadFavorites()
        let real = try await rig.target(named: "a.pdf")
        let realID = try #require(real.rowID)
        let missing = ObjectContextTarget(id: UUID(), name: "fehlt.pdf", kind: .file, mediumID: rig.medium.uuid, rowID: 9_999_999)
        rig.app.toggleFavorites([real, missing])
        #expect(rig.app.isFavorite(real), "lokal sofort gesetzt")
        await rig.app.waitForFavoriteWrites()
        #expect(!rig.app.isFavorite(real), "nach dem Fehler zurückgenommen")
        #expect(!rig.app.isFavorite(missing))
        #expect(rig.app.favoriteRowIDs?.contains(realID) == false)
        #expect(try await !rig.store.favoriteItemIDs().contains(realID))
        let other = try await rig.target(named: "b.pdf")
        #expect(rig.app.isFavorite(other), "unbeteiligter Favorit bleibt")
    }

    /// b) Zwei nacheinander scheiternde Schreibvorgänge derselben Zeile (an, ab): es gilt der Stand der Datenbank,
    /// nicht der zuletzt zurückgespielte Vorher-Stand.
    @Test func twoFailedWritesOfTheSameRowRestoreTheStoredState() async throws {
        let rig = try await FavoriteEditRig.make(names: ["a.pdf"], favorite: { _ in false })
        await rig.app.reloadFavorites()
        let real = try await rig.target(named: "a.pdf")
        let realID = try #require(real.rowID)
        let missing = ObjectContextTarget(id: UUID(), name: "fehlt.pdf", kind: .file, mediumID: rig.medium.uuid, rowID: 9_999_998)
        rig.app.toggleFavorites([real, missing])
        #expect(rig.app.isFavorite(real))
        rig.app.toggleFavorites([real, missing])
        #expect(!rig.app.isFavorite(real))
        await rig.app.waitForFavoriteWrites()
        #expect(!rig.app.isFavorite(real), "Datenbank: kein Favorit")
        #expect(rig.app.favoriteRowIDs?.contains(realID) == false)
        #expect(try await !rig.store.favoriteItemIDs().contains(realID))
    }

    /// c) Fertige Schreib- und Prüfsummen-Aufgaben bleiben nicht liegen.
    @Test func finishedFavoriteTasksAreRemoved() async throws {
        let rig = try await FavoriteEditRig.make(names: ["a.pdf"], favorite: { _ in false })
        try Data("inhalt".utf8).write(to: rig.mountURL.appendingPathComponent("a.pdf"))
        let target = try await rig.target(named: "a.pdf")
        for _ in 0..<6 { rig.app.toggleFavorite(target) }
        #expect(!rig.app.favoriteChecksumTasks.isEmpty, "Aufgaben laufen")
        await rig.app.waitForFavoriteWrites()
        let drained = await waitUntil(timeout: 10) { rig.app.favoriteChecksumTasks.isEmpty }
        #expect(drained, "übrig: \(rig.app.favoriteChecksumTasks.count)")
    }

    /// d) Beenden gleich nach dem Umschalten: die Umschaltung steht in der Datenbank.
    @Test func terminationWaitsForTheFavoriteWrites() async throws {
        let rig = try await FavoriteEditRig.make(names: ["a.pdf", "b.pdf"], favorite: { _ in false })
        let first = try await rig.target(named: "a.pdf")
        let second = try await rig.target(named: "b.pdf")
        rig.app.toggleFavorite(first)
        rig.app.toggleFavorite(second)
        rig.app.toggleFavorite(first)
        await rig.app.prepareForTerminationAsync()
        let ids = try await rig.store.favoriteItemIDs()
        #expect(ids == Set([second.rowID].compactMap { $0 }), "gespeichert: \(ids)")
    }

    /// d) Hängt die Kette, endet das Beenden nach der Zeitgrenze.
    @Test func terminationGivesUpOnAHungFavoriteChain() async throws {
        let rig = try await FavoriteEditRig.make(names: ["a.pdf"])
        let hung = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
        defer { hung.cancel() }
        rig.app.favoriteWriteTail = hung
        let started = ContinuousClock.now
        await rig.app.prepareForTerminationAsync(favoriteWriteTimeout: .milliseconds(200))
        let elapsed = started.duration(to: .now)
        // Notfall-Grenze großzügig (Zeitgrenze 0,2 s, die Kette hinge 60 s).
        #expect(elapsed < .seconds(20), "Beenden dauerte \(elapsed)")
    }

    /// d) Kommt während des Wartens ein weiterer hängender Schreibvorgang dazu, gilt trotzdem eine Frist (keine neue
    /// Zeitgrenze je Runde).
    @Test func terminationDeadlineCoversChainedWrites() async throws {
        let rig = try await FavoriteEditRig.make(names: ["a.pdf"])
        let bag = ChainedTailBag()
        defer { bag.cancelAll() }
        // Jedes Kettenglied hängt vor seinem Ende das nächste an (40 × 150 ms): ohne gemeinsame Frist dauerte das 6 s.
        rig.app.favoriteWriteTail = bag.chainedTail(rig.app, rounds: 40)
        let started = ContinuousClock.now
        let finished = await rig.app.waitForFavoriteWriteTail(timeout: .milliseconds(400))
        let elapsed = started.duration(to: .now)
        #expect(!finished, "Zeitgrenze erreicht")
        #expect(elapsed < .seconds(3), "Warten dauerte \(elapsed) (Frist 0,4 s)")
    }

    /// e) Volle Seite: nach dem Abwählen rückt der nächste Favorit nach.
    @Test func fullPageRefillsAfterUnfavorite() async throws {
        let names = (0..<(SearchIndex.pageLimit + 20)).map { String(format: "rechnung-%04d.pdf", $0) }
        let rig = try await FavoriteEditRig.make(names: names)
        rig.app.mainWindowDestination = .favorites
        await rig.app.reloadFavorites()
        try #require(rig.app.favoriteObjects.count == SearchIndex.pageLimit)
        let first = try #require(rig.app.favoriteObjects.first)
        rig.app.toggleFavorite(.fromSearchResult(first))
        await rig.app.waitForFavoriteWrites()
        #expect(rig.app.favoriteObjects.count == SearchIndex.pageLimit, "Zeile fehlt bis zum Neuladen")
        #expect(!rig.app.favoriteObjects.contains { $0.id == first.id })
        #expect(rig.app.favoriteItemCount == SearchIndex.pageLimit + 19)
    }
}

/// Hält die Glieder einer künstlichen Favoriten-Kette, damit der Test sie am Ende abbricht.
@MainActor
private final class ChainedTailBag {
    private var tasks: [Task<Void, Never>] = []

    func chainedTail(_ app: AppState, rounds: Int) -> Task<Void, Never> {
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard rounds > 0, !Task.isCancelled, let self else { return }
            app.favoriteWriteTail = self.chainedTail(app, rounds: rounds - 1)
        }
        tasks.append(task)
        return task
    }

    func cancelAll() {
        for task in tasks { task.cancel() }
    }
}
