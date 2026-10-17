//
//  StartupSequenceTests.swift
//  diskindexTests
//
//  Aufgabe 219: Datenbank im Hintergrund öffnen, Hauptfaden bleibt frei; quick_check nur bei Bedarf.
//

import Foundation
import Testing
@testable import diskindex

// Parallel: Startup-Sequenzen nicht mit anderen Store-Opens kreuzen.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func add() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}

private func freshDefaults() throws -> UserDefaults {
    try #require(UserDefaults(suiteName: "app.diskarchive.tests.startup.\(UUID().uuidString)"))
}

@Suite(.serialized)
@MainActor
struct StartupSequenceTests {
    @Test func slowOpenKeepsTheMainThreadFreeAndStillRecognisesMedia() async throws {
        let rig = try await SurfaceRig.make()
        let defaults = try freshDefaults()
        let store = rig.store
        let app = rig.app
        let coordinator = rig.coordinator
        let (events, continuation) = AsyncStream.makeStream(of: MediumEvent.self)
        continuation.yield(.appeared(rig.volume(name: "Spät", path: "/Volumes/SPAET", uuid: "UUID-SPAET")))

        // bug.0.3.8.004: statt Ticks zu zählen: Öffnen läuft nicht auf main, und ein MainActor-Sprung kommt
        // an, solange das Öffnen noch 2 s schläft.
        let (opens, report) = AsyncStream.makeStream(of: (onMain: Bool, at: ContinuousClock.Instant).self)
        app.storeOpening = true
        let task = StartupSequence.run(
            previousRunUnclean: false,
            defaults: defaults,
            open: {
                report.yield((Thread.isMainThread, .now))
                Thread.sleep(forTimeInterval: 2.0)
                return store
            },
            wire: { opened in
                app.attach(store: opened)
                coordinator.start(events: events)
            },
            integrityCheck: { _ in },
            onFailure: { _ in }
        )
        #expect(!app.storeReady)
        #expect(app.isStoreLoading)
        // Ruft der Start `open` nie auf, endet der Strom mit ihm (rot statt Hängen).
        Task { await task.value; report.finish() }
        var reports = opens.makeAsyncIterator()
        let began = try #require(await reports.next())
        #expect(began.onMain == false)
        // Der Sprung muss vor dem Ende der 2-s-Pause in `open` ankommen.
        await Task { @MainActor in }.value
        #expect(ContinuousClock.now < began.at + .seconds(2))
        await task.value
        report.finish()
        #expect(app.storeReady)
        #expect(!app.isStoreLoading)
        let recognised = try await waitUntil { try await store.media().count == 1 }
        #expect(recognised)
        coordinator.stop()
        continuation.finish()
    }

    @Test func integrityCheckRunsOnlyWhenDue() async throws {
        let rig = try await SurfaceRig.make()
        let store = rig.store
        let now = Date()

        func run(unclean: Bool, lastCheck: Date?) async throws -> Int {
            let defaults = try freshDefaults()
            if let lastCheck { defaults.set(lastCheck, forKey: IntegrityCheckPolicy.lastCheckKey) }
            let counter = Counter()
            await StartupSequence.run(
                previousRunUnclean: unclean,
                defaults: defaults,
                now: { now },
                open: { store },
                wire: { _ in },
                integrityCheck: { _ in counter.add() },
                onFailure: { _ in }
            ).value
            return counter.value
        }

        #expect(try await run(unclean: true, lastCheck: now) == 1)
        #expect(try await run(unclean: false, lastCheck: now.addingTimeInterval(-3 * 86400)) == 0)
        #expect(try await run(unclean: false, lastCheck: now.addingTimeInterval(-8 * 86400)) == 1)
        #expect(try await run(unclean: false, lastCheck: nil) == 1)
    }

    @Test func policyDecidesByUncleanEndOrAge() {
        let now = Date()
        #expect(IntegrityCheckPolicy.isDue(previousRunUnclean: true, lastCheck: now, now: now))
        #expect(!IntegrityCheckPolicy.isDue(previousRunUnclean: false, lastCheck: now.addingTimeInterval(-6 * 86400), now: now))
        #expect(IntegrityCheckPolicy.isDue(previousRunUnclean: false, lastCheck: now.addingTimeInterval(-7 * 86400), now: now))
        #expect(IntegrityCheckPolicy.isDue(previousRunUnclean: false, lastCheck: nil, now: now))
    }

    @Test func successfulCheckStoresTheDateAndFailureReports() async throws {
        let rig = try await SurfaceRig.make()
        let store = rig.store
        let defaults = try freshDefaults()
        let now = Date()
        await StartupSequence.run(
            previousRunUnclean: false, defaults: defaults, now: { now },
            open: { store }, wire: { _ in }, integrityCheck: { _ in }, onFailure: { _ in }
        ).value
        let saved = try #require(defaults.object(forKey: IntegrityCheckPolicy.lastCheckKey) as? Date)
        #expect(abs(saved.timeIntervalSince(now)) < 1)

        let failures = Counter()
        let other = try freshDefaults()
        await StartupSequence.run(
            previousRunUnclean: true, defaults: other, now: { now },
            open: { store }, wire: { _ in },
            integrityCheck: { _ in throw DatabaseCareError.unhealthy },
            onFailure: { _ in failures.add() }
        ).value
        #expect(failures.value == 1)
        #expect(other.object(forKey: IntegrityCheckPolicy.lastCheckKey) == nil)
    }

    @Test func realIntegrityCheckPassesOnAHealthyDatabase() async throws {
        let rig = try await SurfaceRig.make()
        try rig.store.runIntegrityCheck()
    }
}
