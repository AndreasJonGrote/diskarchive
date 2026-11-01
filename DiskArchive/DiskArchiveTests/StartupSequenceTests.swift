//
//  StartupSequenceTests.swift
//  DiskArchiveTests
//
//  Aufgabe 219: Datenbank im Hintergrund öffnen, Hauptfaden bleibt frei; quick_check nur bei Bedarf.
//

import Foundation
import Testing
@testable import DiskArchive

// Parallel: Startup-Sequenzen nicht mit anderen Store-Opens kreuzen.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func add() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}

private func freshDefaults() throws -> AppStateStore {
    TestDefaults.make()
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

        // bug.0.3.8.004: ohne Zeitvergleich. `open` meldet den Thread und wartet auf das Tor, das der Test erst nach
        // einem gelungenen MainActor-Sprung öffnet (Notfall-Zeitgrenze 10 s nur für den roten Fall).
        let gate = MainHopGate()
        app.storeOpening = true
        let task = StartupSequence.run(
            previousRunUnclean: false,
            defaults: defaults,
            open: {
                gate.arrive(onMain: Thread.isMainThread)
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
        Task { await task.value; gate.finish() }
        let report = await gate.arrived()
        try #require(report != nil, "Arbeit endete ohne Meldung")
        #expect(report == false)
        await Task { @MainActor in }.value
        gate.open()
        await task.value
        #expect(gate.timedOut == false, "Öffnen blockierte den MainActor bis zur Notfall-Zeitgrenze")
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
        let saved = try #require(defaults.date(forKey: IntegrityCheckPolicy.lastCheckKey))
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
        #expect(other.date(forKey: IntegrityCheckPolicy.lastCheckKey) == nil)
    }

    @Test func realIntegrityCheckPassesOnAHealthyDatabase() async throws {
        let rig = try await SurfaceRig.make()
        try rig.store.runIntegrityCheck()
    }
}
