//
//  VersionCheckCalendarTests.swift
//  diskindexTests
//
//  todo.0.4.028: Versions-Check nach Kalenderzeit (Start, Aufwachen, stündlich; injizierbare Uhr je Instanz).
//

import Foundation
import GRDB
import Testing
@testable import diskindex

/// Uhr für Tests, threadsicher (der Planer liest sie im Hintergrund).
private final class SchedulerClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    init(_ value: Date) { current = value }

    var value: Date {
        get { lock.lock(); defer { lock.unlock() }; return current }
        set { lock.lock(); current = newValue; lock.unlock() }
    }
}

/// Ergebnisse der Prüfungen (`true` = eingereiht), threadsicher.
private final class CheckRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Bool] = []

    func record(_ due: Bool) {
        lock.lock(); results.append(due); lock.unlock()
    }

    var snapshot: [Bool] {
        lock.lock(); defer { lock.unlock() }
        return results
    }
}

@MainActor
@Suite(.serialized)
struct VersionCheckCalendarTests {
    private let hour: TimeInterval = 60 * 60

    @Test func dueRuleUsesTwentyFourHoursOfCalendarTime() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(VersionCheckCoordinator.isCheckDue(lastCheckAt: nil, now: last))
        #expect(!VersionCheckCoordinator.isCheckDue(lastCheckAt: last, now: last.addingTimeInterval(23 * hour)))
        #expect(VersionCheckCoordinator.isCheckDue(lastCheckAt: last, now: last.addingTimeInterval(24 * hour)))
        // Uhr deutlich vor den letzten Check zurückgestellt → nicht bis dahin warten.
        #expect(VersionCheckCoordinator.isCheckDue(lastCheckAt: last, now: last.addingTimeInterval(-hour)))
    }

    @Test func startEnqueuesWhenNeverCheckedAndStoresTheTime() async throws {
        let testStore = try TestStore.make()
        let clock = SchedulerClock(Date().addingTimeInterval(-60))
        let recorder = CheckRecorder()
        let (wakes, wakeInput) = AsyncStream<Void>.makeStream()
        defer { wakeInput.finish() }
        let scheduler = VersionCheckScheduler(
            now: { clock.value }, tickInterval: .seconds(3_600), wakeEvents: { wakes },
            flush: {}, databaseWasNewThisLaunch: false, onCheckFinished: { recorder.record($0) }
        )
        // Der Planer hält `appState` nur schwach (wie im Produkt, dort hält ihn `AppDelegateBridge`).
        let appState = AppState()
        scheduler.start(appState: appState, store: testStore.store)
        defer { withExtendedLifetime(appState) { scheduler.stop() } }
        #expect(await waitUntil { recorder.snapshot == [true] })
        #expect(try queuedVersionChecks(testStore.pool) == 1)
        #expect(try lastCheck(testStore.pool) == stored(clock.value))
    }

    @Test func startWithinTwentyFourHoursDoesNotEnqueue() async throws {
        let testStore = try TestStore.make()
        let clock = SchedulerClock(Date().addingTimeInterval(-60))
        try storeLastCheck(clock.value.addingTimeInterval(-23 * hour), pool: testStore.pool)
        let recorder = CheckRecorder()
        let (wakes, wakeInput) = AsyncStream<Void>.makeStream()
        defer { wakeInput.finish() }
        let scheduler = VersionCheckScheduler(
            now: { clock.value }, tickInterval: .seconds(3_600), wakeEvents: { wakes },
            flush: {}, databaseWasNewThisLaunch: false, onCheckFinished: { recorder.record($0) }
        )
        // Der Planer hält `appState` nur schwach (wie im Produkt, dort hält ihn `AppDelegateBridge`).
        let appState = AppState()
        scheduler.start(appState: appState, store: testStore.store)
        defer { withExtendedLifetime(appState) { scheduler.stop() } }
        #expect(await waitUntil { recorder.snapshot == [false] })
        #expect(try queuedVersionChecks(testStore.pool) == 0)
    }

    /// Aufwachen nach mehr als 24 h Kalenderzeit holt den fälligen Check nach (ohne auf den nächsten Takt zu warten;
    /// `Task.sleep(for:)` läuft auf der `ContinuousClock` und zählt die Schlafzeit mit).
    @Test func wakeAfterTwentyFourHoursEnqueues() async throws {
        let testStore = try TestStore.make()
        let clock = SchedulerClock(Date().addingTimeInterval(-60))
        try storeLastCheck(clock.value.addingTimeInterval(-hour), pool: testStore.pool)
        let recorder = CheckRecorder()
        let (wakes, wakeInput) = AsyncStream<Void>.makeStream()
        defer { wakeInput.finish() }
        let scheduler = VersionCheckScheduler(
            now: { clock.value }, tickInterval: .seconds(3_600), wakeEvents: { wakes },
            flush: {}, databaseWasNewThisLaunch: false, onCheckFinished: { recorder.record($0) }
        )
        // Der Planer hält `appState` nur schwach (wie im Produkt, dort hält ihn `AppDelegateBridge`).
        let appState = AppState()
        scheduler.start(appState: appState, store: testStore.store)
        defer { withExtendedLifetime(appState) { scheduler.stop() } }
        #expect(await waitUntil { recorder.snapshot == [false] })
        #expect(try queuedVersionChecks(testStore.pool) == 0)

        clock.value = clock.value.addingTimeInterval(23 * hour + 1)
        wakeInput.yield()
        #expect(await waitUntil { recorder.snapshot == [false, true] })
        #expect(try queuedVersionChecks(testStore.pool) == 1)
        #expect(try lastCheck(testStore.pool) == stored(clock.value))
    }

    /// Stündliche Prüfung: erst nach 24 h Kalenderzeit seit dem letzten Check wird eingereiht.
    @Test func hourlyTickEnqueuesOnlyAfterTwentyFourHours() async throws {
        let testStore = try TestStore.make()
        let clock = SchedulerClock(Date().addingTimeInterval(-60))
        let lastCheckAt = clock.value.addingTimeInterval(-hour)
        try storeLastCheck(lastCheckAt, pool: testStore.pool)
        let recorder = CheckRecorder()
        let (wakes, wakeInput) = AsyncStream<Void>.makeStream()
        defer { wakeInput.finish() }
        let scheduler = VersionCheckScheduler(
            now: { clock.value }, tickInterval: .milliseconds(50), wakeEvents: { wakes },
            flush: {}, databaseWasNewThisLaunch: false, onCheckFinished: { recorder.record($0) }
        )
        // Der Planer hält `appState` nur schwach (wie im Produkt, dort hält ihn `AppDelegateBridge`).
        let appState = AppState()
        scheduler.start(appState: appState, store: testStore.store)
        defer { withExtendedLifetime(appState) { scheduler.stop() } }
        // Mindestens Start + ein Takt, alle nicht fällig.
        #expect(await waitUntil { recorder.snapshot.count >= 2 })
        #expect(!recorder.snapshot.contains(true))
        #expect(try queuedVersionChecks(testStore.pool) == 0)

        clock.value = lastCheckAt.addingTimeInterval(24 * hour)
        #expect(await waitUntil { recorder.snapshot.contains(true) })
        #expect(try queuedVersionChecks(testStore.pool) == 1)
        #expect(try lastCheck(testStore.pool) == stored(clock.value))
        // Danach wieder nicht fällig: weitere Takte reihen nichts mehr ein.
        let afterDue = recorder.snapshot.count
        #expect(await waitUntil { recorder.snapshot.count >= afterDue + 2 })
        #expect(recorder.snapshot.filter { $0 }.count == 1)
    }

    /// Korrektur Prüfung: Takt und Aufwachen fast gleichzeitig, die spätere Uhrzeit wird zuerst verarbeitet.
    /// Die frühere (Sekunden davor) gilt nicht als „Uhr zurückgestellt“: genau eine Einreihung, `last` = späterer Wert.
    @Test func nearlySimultaneousChecksOutOfOrderEnqueueOnce() async throws {
        let testStore = try TestStore.make()
        let later = Date().addingTimeInterval(-60)
        let earlier = later.addingTimeInterval(-2)
        try storeLastCheck(later.addingTimeInterval(-25 * hour), pool: testStore.pool)
        let recorder = CheckRecorder()
        let queue = DispatchQueue(label: "VersionCheckCalendarTests.serial")
        VersionCheckCoordinator.enqueueCheckIfDue(
            pool: testStore.pool, queue: queue, now: { later }, flush: {}, completion: { recorder.record($0) }
        )
        VersionCheckCoordinator.enqueueCheckIfDue(
            pool: testStore.pool, queue: queue, now: { earlier }, flush: {}, completion: { recorder.record($0) }
        )
        #expect(await waitUntil { recorder.snapshot.count >= 2 })
        #expect(recorder.snapshot == [true, false])
        #expect(try queuedVersionChecks(testStore.pool) == 1)
        #expect(try lastCheck(testStore.pool) == stored(later))
    }

    /// Deutlich zurückgestellte Uhr (über der Toleranz) gilt weiter als fällig.
    @Test func clockSetBackBeyondToleranceIsDue() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(!VersionCheckCoordinator.isCheckDue(lastCheckAt: last, now: last.addingTimeInterval(-2)))
        #expect(VersionCheckCoordinator.isCheckDue(
            lastCheckAt: last, now: last.addingTimeInterval(-VersionCheckCoordinator.clockSetBackTolerance - 1)
        ))
    }

    // MARK: - Hilfen

    private func stored(_ date: Date) -> Date {
        Date(timeIntervalSince1970: TimeInterval(Int64(date.timeIntervalSince1970)))
    }

    private func storeLastCheck(_ date: Date, pool: DatabasePool) throws {
        try pool.write { db in try SystemSettingsPersistence.writeLastVersionCheckAt(db, at: date) }
    }

    private func lastCheck(_ pool: DatabasePool) throws -> Date? {
        try pool.read(SystemSettingsPersistence.readLastVersionCheckAt)
    }

    private func queuedVersionChecks(_ pool: DatabasePool) throws -> Int {
        try ApiQueuePersistence.count(pool, kind: .versionCheck)
    }
}
