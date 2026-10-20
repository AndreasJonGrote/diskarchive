//
//  VersionQueueLockPauseTests.swift
//  diskindexTests
//
//  Paket 8b: bug.0.4.051 (REPORT 89), bug.0.4.053 (REPORT 93), bug.0.4.059 (REPORT 105); Paket 10: bug.0.4.072.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

private func makeVersionQueuePool() throws -> (pool: DatabasePool, directory: URL) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("diskindex-version-queue-\(UUID().uuidString)", isDirectory: true)
    let pool = try ApiQueuePersistence.openQueuePool(at: directory.appendingPathComponent("archive.sqlite"))
    return (pool, directory)
}

// MARK: - bug.0.4.051 (REPORT 89)

@Suite(.serialized)
struct VersionCheckQueueTrimTests {
    @Test func repeatedVersionCheckKeepsOneOpenRowAndMakesItDueAgain() throws {
        let (pool, directory) = try makeVersionQueuePool()
        defer { try? FileManager.default.removeItem(at: directory) }
        let payload = Data("{}".utf8)
        for start in 0..<5 {
            try ApiQueuePersistence.enqueue(pool, kind: .versionCheck, payload: payload, createdAt: start)
        }
        #expect(try ApiQueuePersistence.count(pool, kind: .versionCheck) == 1)

        let row = try #require(try ApiQueuePersistence.fetchAllOrdered(pool).first)
        let moment = Date(timeIntervalSince1970: 1_700_000_000)
        try ApiQueuePersistence.recordFailure(
            pool, rowID: row.id, attempts: 3, lastTryAt: Int(moment.timeIntervalSince1970), info: "version-offline"
        )
        #expect(try ApiQueuePersistence.fetchDue(pool, now: moment.addingTimeInterval(1)).isEmpty)

        // Nächster Start: kein zweiter Eintrag, der vorhandene ist sofort wieder fällig.
        try ApiQueuePersistence.enqueue(pool, kind: .versionCheck, payload: payload, createdAt: 99)
        #expect(try ApiQueuePersistence.count(pool, kind: .versionCheck) == 1)
        let due = try ApiQueuePersistence.fetchDue(pool, now: moment.addingTimeInterval(1))
        #expect(due.map(\.id) == [row.id])
    }

    @Test func trimRemovesVersionChecksBeforeConsentedCrashReport() throws {
        let (pool, directory) = try makeVersionQueuePool()
        defer { try? FileManager.default.removeItem(at: directory) }
        let crashID = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
        try ApiQueuePersistence.enqueue(
            pool, kind: .issueReport, payload: Data(#"{"id":"\#(crashID)","kind":"crash"}"#.utf8), createdAt: 1
        )
        // Altbestand aus früheren Versionen: viele Versions-Check-Zeilen (direkt eingefügt).
        try pool.write { db in
            for index in 0..<(ApiQueuePersistence.maxRows - 1) {
                try db.execute(
                    sql: "INSERT INTO api_queue (kind, payload, createdAt, attempts) VALUES (?, '{}', ?, 0)",
                    arguments: [ApiQueueKind.versionCheck.rawValue, 10 + index]
                )
            }
        }
        #expect(try ApiQueuePersistence.count(pool) == ApiQueuePersistence.maxRows)

        try ApiQueuePersistence.enqueue(
            pool, kind: .issueReport, payload: Data(#"{"id":"second","kind":"feedback"}"#.utf8), createdAt: 100
        )
        #expect(try ApiQueuePersistence.count(pool) == ApiQueuePersistence.maxRows)
        #expect(try ApiQueuePersistence.firstQueuedIssueIDForTest(pool) == crashID)
        #expect(try ApiQueuePersistence.count(pool, kind: .issueReport) == 2)
    }
}

private extension ApiQueuePersistence {
    static func firstQueuedIssueIDForTest(_ pool: DatabasePool) throws -> String? {
        guard let data = try firstPayload(pool, kind: .issueReport) else { return nil }
        return issueID(in: data)
    }
}

// MARK: - bug.0.4.053 (REPORT 93)

@Suite(.serialized)
struct VersionLockGapTests {
    private let app03 = AppVersion(major: 0, minor: 3, patch: 1)
    private let api10 = AppVersion(major: 1, minor: 0, patch: 0)
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let day: TimeInterval = 24 * 3600

    private func settings(
        apiLastSeen: Date? = nil,
        firstRunAt: Date? = nil,
        firstRunFresh: Bool = false,
        highestSeenAt: Date? = nil
    ) -> SystemSettingsSnapshot {
        SystemSettingsSnapshot(
            betaExpiryNoticedAt: nil,
            apiLastSeen: apiLastSeen,
            lockedVersion: nil,
            skippedUpdateVersion: nil,
            firstRunAt: firstRunAt,
            firstRunFresh: firstRunFresh,
            highestSeenAt: highestSeenAt
        )
    }

    /// (a) API nie erreicht: die 30-Tage-Frist läuft ab dem ersten Start.
    @Test func apiNeverReachedLocksThirtyDaysAfterFirstRun() {
        let locked = VersionLockEvaluator.evaluate(
            now: now, appVersion: app03, apiVersion: nil,
            settings: settings(firstRunAt: now.addingTimeInterval(-31 * day)),
            isFreshInstall: false, buildDate: now
        )
        #expect(locked.lockState == .locked(.apiUnreachable))

        let open = VersionLockEvaluator.evaluate(
            now: now, appVersion: app03, apiVersion: nil,
            settings: settings(firstRunAt: now.addingTimeInterval(-29 * day)),
            isFreshInstall: false, buildDate: now
        )
        #expect(!open.lockState.isLocked)

        let first = VersionLockEvaluator.evaluate(
            now: now, appVersion: app03, apiVersion: nil,
            settings: settings(), isFreshInstall: false, buildDate: now
        )
        #expect(first.mutations.setFirstRunAt == now)
        #expect(first.mutations.firstRunFresh == false)
    }

    /// (b) Zurückgestellte Uhr hebt weder die 30- noch die 60-Tage-Sperre auf.
    @Test func clockSetBackKeepsLocks() {
        let highest = now.addingTimeInterval(31 * day)
        let api = VersionLockEvaluator.evaluate(
            now: now, appVersion: app03, apiVersion: nil,
            settings: settings(apiLastSeen: now.addingTimeInterval(-1 * day), highestSeenAt: highest),
            isFreshInstall: false, buildDate: now
        )
        #expect(api.lockState == .locked(.apiUnreachable))
        #expect(api.mutations.setHighestSeenAt == nil)

        let build = VersionLockEvaluator.evaluate(
            now: now, appVersion: app03, apiVersion: nil,
            settings: settings(apiLastSeen: now, highestSeenAt: now.addingTimeInterval(61 * day)),
            isFreshInstall: false, buildDate: now
        )
        #expect(build.lockState == .locked(.buildExpired))

        let forward = VersionLockEvaluator.evaluate(
            now: highest.addingTimeInterval(60), appVersion: app03, apiVersion: nil,
            settings: settings(apiLastSeen: highest, highestSeenAt: highest),
            isFreshInstall: false, buildDate: highest
        )
        #expect(forward.mutations.setHighestSeenAt == highest.addingTimeInterval(60))
    }

    /// (b) Korrektur: Uhr einmal vorgestellt, dann API-Antwort bei normaler Uhr → nicht gesperrt, Höchstwert zurückgesetzt.
    @Test func apiAnswerResetsClockSetForward() throws {
        let future = now.addingTimeInterval(61 * day)
        let testStore = try TestStore.make()
        try VersionLockEvaluator.applyMutations(
            VersionLockSettingsMutations(setFirstRunAt: now, firstRunFresh: false, setHighestSeenAt: future),
            pool: testStore.pool
        )
        let before = try VersionLockEvaluator.readSettings(pool: testStore.pool)
        #expect(before.highestSeenAt == future)

        let answered = VersionLockEvaluator.evaluate(
            now: now, appVersion: app03, apiVersion: app03,
            settings: before, isFreshInstall: false, buildDate: now
        )
        #expect(!answered.lockState.isLocked)
        #expect(answered.mutations.setApiLastSeen == now)
        try VersionLockEvaluator.applyMutations(answered.mutations, pool: testStore.pool)
        let after = try VersionLockEvaluator.readSettings(pool: testStore.pool)
        #expect(after.highestSeenAt == now)

        let offlineLater = VersionLockEvaluator.evaluate(
            now: now.addingTimeInterval(3_600), appVersion: app03, apiVersion: nil,
            settings: after, isFreshInstall: false, buildDate: now
        )
        #expect(!offlineLater.lockState.isLocked)
    }

    @Test func storedClockValuesNeverGoBackwards() throws {
        let testStore = try TestStore.make()
        let later = now.addingTimeInterval(10 * day)
        try VersionLockEvaluator.applyMutations(
            VersionLockSettingsMutations(setFirstRunAt: now, firstRunFresh: true, setHighestSeenAt: later),
            pool: testStore.pool
        )
        try VersionLockEvaluator.applyMutations(
            VersionLockSettingsMutations(setFirstRunAt: later, firstRunFresh: false, setHighestSeenAt: now),
            pool: testStore.pool
        )
        let stored = try VersionLockEvaluator.readSettings(pool: testStore.pool)
        #expect(stored.firstRunAt == now)
        #expect(stored.firstRunFresh)
        #expect(stored.highestSeenAt == later)
    }

    /// (c) „Frisch“ nur über den gespeicherten ersten Start (README: keine Datenbank), dazu bug.0.4.065/072: kein Medium indiziert.
    @Test func freshInstallComesFromStoredFirstRun() {
        let existing = settings(firstRunAt: now, firstRunFresh: false)
        #expect(!VersionLockEvaluator.isFreshInstall(settings: existing, databaseWasNewThisLaunch: true, indexedMediaCount: 0))
        let fresh = settings(firstRunAt: now, firstRunFresh: true)
        #expect(VersionLockEvaluator.isFreshInstall(settings: fresh, databaseWasNewThisLaunch: false, indexedMediaCount: 0))
        #expect(!VersionLockEvaluator.isFreshInstall(settings: fresh, databaseWasNewThisLaunch: false, indexedMediaCount: 1))
        let answered = settings(apiLastSeen: now, firstRunAt: now, firstRunFresh: true)
        #expect(!VersionLockEvaluator.isFreshInstall(settings: answered, databaseWasNewThisLaunch: true, indexedMediaCount: 0))
        #expect(VersionLockEvaluator.isFreshInstall(settings: settings(), databaseWasNewThisLaunch: true, indexedMediaCount: 0))
        #expect(!VersionLockEvaluator.isFreshInstall(settings: settings(), databaseWasNewThisLaunch: true, indexedMediaCount: 2))
        #expect(!VersionLockEvaluator.isFreshInstall(settings: settings(), databaseWasNewThisLaunch: false, indexedMediaCount: 0))
    }

    /// (c) Bestandsnutzer ohne Medien (erster Start gespeichert, Datenbank war da) wird bei API ≥ 1.0 nicht sofort gesperrt.
    /// bug.0.4.065: kein prozessweiter Schalter mehr, der Wert „Datenbank neu“ geht als Parameter mit (Regel 20).
    @Test(.enabled(if: AppVersion.currentApp()?.isBeta == true, "nur für Beta-Builds (0.x)"))
    @MainActor func existingUserWithoutMediaIsNotTreatedAsFresh() async throws {
        let testStore = try TestStore.make()
        #expect(try registeredMediaCount(testStore.pool) == 0)
        let firstRun = Date().addingTimeInterval(-2 * day)
        try VersionLockEvaluator.applyMutations(
            VersionLockSettingsMutations(setFirstRunAt: firstRun, firstRunFresh: false),
            pool: testStore.pool
        )
        let appState = AppState()
        await VersionCheckCoordinator.handleAPIResult(
            VersionCheckResponse(version: api10), appState: appState, store: testStore.store,
            databaseWasNewThisLaunch: true
        )
        #expect(!appState.versionLockState.isLocked)
        let stored = try VersionLockEvaluator.readSettings(pool: testStore.pool)
        #expect(stored.lockedVersion == nil)
        #expect(stored.betaExpiryNoticedAt != nil)
    }

    /// bug.0.4.065: frisch installiert (neue Datenbank, kein Medium) → erste API-Antwort ≥ 1.0 sperrt sofort.
    /// Echter Weg: lokale Auswertung beim Start, dann API-Antwort über den Koordinator.
    @Test(.enabled(if: AppVersion.currentApp()?.isBeta == true, "nur für Beta-Builds (0.x)"))
    @MainActor func freshInstallWithoutMediaLocksAtFirstAPIResponse() async throws {
        let testStore = try TestStore.make()
        let appState = AppState()
        VersionCheckCoordinator.reevaluateLocal(
            appState: appState, store: testStore.store, databaseWasNewThisLaunch: true
        )
        #expect(await waitUntil { (try? VersionLockEvaluator.readSettings(pool: testStore.pool))?.firstRunAt != nil })
        #expect(try VersionLockEvaluator.readSettings(pool: testStore.pool).firstRunFresh)
        #expect(try registeredMediaCount(testStore.pool) == 0)

        await VersionCheckCoordinator.handleAPIResult(
            VersionCheckResponse(version: api10), appState: appState, store: testStore.store,
            databaseWasNewThisLaunch: false
        )
        #expect(appState.versionLockState == .locked(.betaExpired))
        let stored = try VersionLockEvaluator.readSettings(pool: testStore.pool)
        #expect(stored.lockedVersion != nil)
        #expect(stored.betaExpiryNoticedAt == nil)
    }

    /// bug.0.4.072: frisch installiert, nur ein angesteckter, unentschiedener Stick (Zeile in `storages` über die
    /// echte Erkennung, ohne Index) → erste API-Antwort ≥ 1.0 sperrt sofort.
    @Test(.enabled(if: AppVersion.currentApp()?.isBeta == true, "nur für Beta-Builds (0.x)"))
    @MainActor func freshInstallWithOnlyUndecidedStickLocksAtFirstAPIResponse() async throws {
        let testStore = try TestStore.make()
        let appState = AppState()
        VersionCheckCoordinator.reevaluateLocal(
            appState: appState, store: testStore.store, databaseWasNewThisLaunch: true
        )
        #expect(await waitUntil { (try? VersionLockEvaluator.readSettings(pool: testStore.pool))?.firstRunAt != nil })
        #expect(try VersionLockEvaluator.readSettings(pool: testStore.pool).firstRunFresh)

        let stick = MemoryVolume(mountPath: "/Volumes/STICK072")
        stick.file("a.txt")
        let rig = WiredRig(store: testStore.store, access: stick, app: appState)
        defer { rig.coordinator.stop() }
        await rig.coordinator.handle(.appeared(testVolume(path: "/Volumes/STICK072", name: "STICK")))
        #expect(await waitUntil { (try? self.registeredMediaCount(testStore.pool)) == 1 })
        let stored = try #require(try await testStore.store.media().first)
        #expect(stored.decision == .undecided)
        #expect(stored.firstIndexedAt == nil)

        await VersionCheckCoordinator.handleAPIResult(
            VersionCheckResponse(version: api10), appState: appState, store: testStore.store,
            databaseWasNewThisLaunch: false
        )
        #expect(appState.versionLockState == .locked(.betaExpired))
        let settingsAfter = try VersionLockEvaluator.readSettings(pool: testStore.pool)
        #expect(settingsAfter.lockedVersion != nil)
        #expect(settingsAfter.betaExpiryNoticedAt == nil)
    }

    /// bug.0.4.065 / bug.0.4.072: offline installiert und schon indiziert (Medium über `upsertMedium` angelegt und über
    /// den Store-Weg indiziert, `finishIndexing` setzt `firstIndexedAt`) → erste API-Antwort ≥ 1.0 gibt die normale
    /// 7-Tage-Frist statt der sofortigen Sperre.
    @Test(.enabled(if: AppVersion.currentApp()?.isBeta == true, "nur für Beta-Builds (0.x)"))
    @MainActor func offlineInstallWithIndexedMediumGetsGracePeriodAtFirstAPIResponse() async throws {
        let harness = try await ScanHarness.make()
        let appState = AppState()
        VersionCheckCoordinator.reevaluateLocal(
            appState: appState, store: harness.store, databaseWasNewThisLaunch: true
        )
        #expect(await waitUntil { (try? VersionLockEvaluator.readSettings(pool: harness.store.pool))?.firstRunAt != nil })
        #expect(try VersionLockEvaluator.readSettings(pool: harness.store.pool).firstRunFresh)

        let volume = MemoryVolume(mountPath: "/Volumes/T")
        volume.file("a.txt")
        let outcome = try await harness.run(access: volume, maxDepth: nil)
        #expect(outcome.status == .indexed)
        let medium = try #require(try await harness.store.medium(uuid: harness.mediumID))
        #expect(medium.firstIndexedAt != nil)

        await VersionCheckCoordinator.handleAPIResult(
            VersionCheckResponse(version: api10), appState: appState, store: harness.store,
            databaseWasNewThisLaunch: true
        )
        #expect(!appState.versionLockState.isLocked)
        let stored = try VersionLockEvaluator.readSettings(pool: harness.store.pool)
        #expect(stored.lockedVersion == nil)
        #expect(stored.betaExpiryNoticedAt != nil)
        #expect(stored.apiLastSeen != nil)
    }

    private func registeredMediaCount(_ pool: DatabasePool) throws -> Int {
        try pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM storages") ?? 0 }
    }

    /// (a)/(b) Auch ohne API-Antwort werden erster Start und höchste Uhrzeit gespeichert.
    @Test @MainActor func localReevaluationStoresClockValues() async throws {
        _ = try #require(AppVersion.currentApp())
        let testStore = try TestStore.make()
        let moment = Date().addingTimeInterval(-60)
        let appState = AppState()
        VersionCheckCoordinator.reevaluateLocal(
            appState: appState, store: testStore.store, now: moment, databaseWasNewThisLaunch: false
        )
        let stored = await waitUntil {
            let snapshot = try? VersionLockEvaluator.readSettings(pool: testStore.pool)
            return snapshot?.firstRunAt != nil && snapshot?.highestSeenAt != nil
        }
        #expect(stored)
        let snapshot = try VersionLockEvaluator.readSettings(pool: testStore.pool)
        #expect(snapshot.highestSeenAt.map { abs($0.timeIntervalSince(moment)) < 1 } == true)
    }
}

// MARK: - bug.0.4.059 (REPORT 105)

@MainActor
@Suite(.serialized)
struct PauseSpanPersistenceTests {
    @Test func chosenHourStaysHourAfterTwentyMinutes() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var pause = GlobalPause()
        pause.pause(span: .hour, now: start)
        #expect(pause.until == start.addingTimeInterval(3_600))
        #expect(PauseSpan.matching(pause, now: start.addingTimeInterval(21 * 60)) == .hour)
    }

    @Test func untilTomorrowStaysTomorrowAfterMidnight() throws {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 10; parts.day = 8; parts.hour = 23; parts.minute = 0
        let start = try #require(Calendar.current.date(from: parts))
        var pause = GlobalPause()
        pause.pause(span: .tomorrow, now: start)
        let afterMidnight = start.addingTimeInterval(2 * 3_600)
        #expect(PauseSpan.matching(pause, now: afterMidnight) == .tomorrow)
    }

    @Test func spanIsSavedAndLoadedWithPause() throws {
        let defaults = try #require(UserDefaults(suiteName: "PauseSpanPersistenceTests-\(UUID().uuidString)"))
        let start = Date()
        let app = AppState()
        let hooks = NoticeTestHooks(post: { _, _ in })
        SystemNotice.$testHooks.withValue(hooks) {
            app.pauseIndexing(span: .hour, defaults: defaults, now: start)
        }
        #expect(app.pauseSnapshot.span == .hour)

        let reloaded = AppState()
        reloaded.loadPause(from: defaults, now: start.addingTimeInterval(21 * 60))
        #expect(reloaded.pauseSnapshot.span == .hour)
        #expect(PauseSpan.matching(reloaded.pauseSnapshot, now: start.addingTimeInterval(21 * 60)) == .hour)
        reloaded.resumeIndexing(defaults: defaults)
        app.resumeIndexing(defaults: defaults)
    }

    @Test func oldStoredPauseWithoutSpanStillDecodes() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let until = start.addingTimeInterval(3_600)
        let json = #"{"active":true,"forever":false,"until":\#(until.timeIntervalSinceReferenceDate)}"#
        let decoded = try JSONDecoder().decode(GlobalPause.self, from: Data(json.utf8))
        #expect(decoded.active)
        #expect(decoded.span == nil)
        #expect(decoded.until == until)
        #expect(PauseSpan.matching(decoded, now: start) == .hour)

        var plain = GlobalPause()
        plain.pause(span: .hour, now: start)
        plain.pause(until: nil)
        #expect(plain.span == nil)
        #expect(PauseSpan.matching(plain, now: start) == .forever)
    }
}
