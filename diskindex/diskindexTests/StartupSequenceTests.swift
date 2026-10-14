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

        var ticks = 0
        let ticker = Task { @MainActor in
            while !Task.isCancelled {
                ticks += 1
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        app.storeOpening = true
        let task = StartupSequence.run(
            previousRunUnclean: false,
            defaults: defaults,
            open: {
                // 2 s: unter Parallel-Last braucht der MainActor mehr Zeit für ≥5 Ticks.
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
        await task.value
        ticker.cancel()
        // Unter Parallel-Last weniger MainActor-Ticks; ≥5 zeigt weiter freien Hauptfaden.
        #expect(ticks >= 5)
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
