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

    /// bug.0.4.144: Die Fadenprüfung oben zählt nur den Hilfsweg `onDatabaseQueue`; hier zählt jede Anweisung der
    /// Datei, die auf dem Hauptfaden läuft (auch ein zusätzlicher Zugriff, z. B. beim Anwenden).
    @Test func apiResultRunsNoStatementOnTheMainThread() async throws {
        let testStore = try TestStore.make()
        let url = testStore.directory.appendingPathComponent("archive.sqlite")
        let before = SchemaV3.OpenCounter.shared.mainThreadStatementCount(url)
        let appState = AppState()
        await VersionCheckCoordinator.handleAPIResult(
            VersionCheckResponse(version: AppVersion(major: 0, minor: 0, patch: 1)),
            appState: appState,
            store: testStore.store,
            databaseWasNewThisLaunch: false
        )
        #expect(SchemaV3.OpenCounter.shared.mainThreadStatementCount(url) == before, "Anweisungen auf dem Hauptfaden")
        // Gegenprobe: ein synchroner Zugriff auf dem Hauptfaden wird gezählt.
        try Self.synchronousRead(testStore.pool)
        #expect(SchemaV3.OpenCounter.shared.mainThreadStatementCount(url) > before, "Zähler erfasst den Hauptfaden nicht")
    }

    /// Synchroner Zugriff (kein `async`-Überladen von `read`), läuft auf dem aufrufenden Faden.
    private static func synchronousRead(_ pool: DatabasePool) throws {
        _ = try pool.read { db in try Int.fetchOne(db, sql: "SELECT 1") }
    }

    /// bug.0.4.144: zwei Antworten kurz nacheinander – die zweite gewinnt, auch wenn die erste beim Lesen aufgehalten wird.
    @Test func twoAnswersAreProcessedInOrder() async throws {
        let testStore = try TestStore.make()
        let appState = AppState()
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        let second = first.addingTimeInterval(3_600)
        let calls = ThreadSteps()
        let response = VersionCheckResponse(version: AppVersion(major: 0, minor: 0, patch: 1))
        await VersionCheckTestHooks.$databaseThreadObserver.withValue({ _ in
            // Der erste Datenbankschritt des ersten Aufrufs wird aufgehalten.
            if calls.count == 0 { Thread.sleep(forTimeInterval: 0.3) }
            calls.add(false)
        }) {
            async let a: Void = VersionCheckCoordinator.handleAPIResult(
                response, appState: appState, store: testStore.store, now: first, databaseWasNewThisLaunch: false
            )
            async let b: Void = VersionCheckCoordinator.handleAPIResult(
                response, appState: appState, store: testStore.store, now: second, databaseWasNewThisLaunch: false
            )
            _ = await (a, b)
        }
        let stored = try VersionLockEvaluator.readSettings(pool: testStore.pool)
        let seen = try #require(stored.apiLastSeen)
        #expect(abs(seen.timeIntervalSince(second)) < 1, "ältere Antwort überschreibt die neuere: \(seen)")
    }
}

private final class ThreadSteps: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Bool] = []

    var all: [Bool] { lock.withLock { values } }

    var count: Int { lock.withLock { values.count } }

    func add(_ onMain: Bool) {
        lock.withLock { values.append(onMain) }
    }
}
