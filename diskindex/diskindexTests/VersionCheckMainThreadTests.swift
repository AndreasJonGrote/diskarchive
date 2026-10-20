//
//  VersionCheckMainThreadTests.swift
//  diskindexTests
//
//  bug.0.4.137: Die Antwort des Versions-Checks liest und schreibt die Datenbank nicht auf dem Hauptfaden – so wartet
//  der Main Actor nie hinter einem Schreiber (Indexer-Stapel, `wal_checkpoint`). Fadenprüfung statt Ticker (im
//  Parallellauf teilen sich viele Tests den Hauptfaden; Vorbild bug.0.3.8.004, bug.0.4.086).
//

import Foundation
import GRDB
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct VersionCheckMainThreadTests {
    @Test func apiResultReadsAndWritesOffTheMainThread() async throws {
        let testStore = try TestStore.make()
        let steps = ThreadSteps()
        let appState = AppState()
        await VersionCheckTestHooks.$databaseThreadObserver.withValue({ onMain in steps.add(onMain) }) {
            await VersionCheckCoordinator.handleAPIResult(
                VersionCheckResponse(version: AppVersion(major: 0, minor: 0, patch: 1)),
                appState: appState,
                store: testStore.store,
                databaseWasNewThisLaunch: false
            )
        }
        // Lesen und Schreiben (Antwort vorhanden), beide im Hintergrund.
        #expect(steps.all == [false, false], "Datenbankschritte auf dem Hauptfaden: \(steps.all)")
        let stored = try VersionLockEvaluator.readSettings(pool: testStore.pool)
        #expect(stored.apiLastSeen != nil, "Antwort nicht gespeichert")
    }
}

private final class ThreadSteps: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Bool] = []

    var all: [Bool] { lock.withLock { values } }

    func add(_ onMain: Bool) {
        lock.withLock { values.append(onMain) }
    }
}
