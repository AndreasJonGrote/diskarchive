//
//  VersionCheckTests.swift
//  DiskArchiveTests
//
//  Versions-Check / Sperre (c.0.3.3.001).
//

import Foundation
import GRDB
import Testing
@testable import DiskArchive

@Suite(.serialized)
struct VersionCheckTests {
    private let app03 = AppVersion(major: 0, minor: 3, patch: 1)
    private let api10 = AppVersion(major: 1, minor: 0, patch: 0)
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// todo.0.4.047: kein Überspringen mehr – jede neuere Haupt-/Nebenversion wird angeboten (ob der Dialog erscheint,
    /// entscheidet die Einstellung „Auf Updates hinweisen“).
    @Test func majorMinorComparison() {
        let settings = SystemSettingsSnapshot(
            betaExpiryNoticedAt: nil,
            apiLastSeen: now,
            lockedVersion: nil
        )
        for (api, display) in [(api10, "1.0"), (AppVersion(major: 1, minor: 1, patch: 0), "1.1")] {
            let eval = VersionLockEvaluator.evaluate(
                now: now,
                appVersion: app03,
                apiVersion: api,
                settings: settings,
                isFreshInstall: false,
                buildDate: now
            )
            #expect(eval.updateOffer?.targetDisplay == display)
        }
        let same = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: AppVersion(major: 1, minor: 1, patch: 2),
            apiVersion: AppVersion(major: 1, minor: 1, patch: 0),
            settings: settings,
            isFreshInstall: false,
            buildDate: now
        )
        #expect(same.updateOffer == nil, "gleiche Haupt-/Nebenversion: kein Angebot")
    }

    @Test func betaNoticeAndSevenDayLock() throws {
        let noticed = now.addingTimeInterval(-8 * 24 * 3600)
        let settings = SystemSettingsSnapshot(
            betaExpiryNoticedAt: noticed,
            apiLastSeen: now,
            lockedVersion: nil
        )
        let eval = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: app03,
            apiVersion: api10,
            settings: settings,
            isFreshInstall: false,
            buildDate: now
        )
        #expect(eval.lockState.isLocked)
        #expect(eval.mutations.setLockedVersion == app03.displayString)

        let pool = try makeTempPool()
        try VersionLockEvaluator.applyMutations(eval.mutations, pool: pool)
        let stored = try VersionLockEvaluator.readSettings(pool: pool)
        #expect(stored.lockedVersion == "0.3.1")
    }

    @Test func freshInstallLocksImmediately() {
        let eval = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: app03,
            apiVersion: api10,
            settings: .init(betaExpiryNoticedAt: nil, apiLastSeen: nil, lockedVersion: nil),
            isFreshInstall: true,
            buildDate: now
        )
        #expect(eval.lockState.isLocked)
        #expect(eval.mutations.setLockedVersion != nil)
    }

    @Test func apiLastSeenOlderThanThirtyDaysLocks() {
        let old = now.addingTimeInterval(-31 * 24 * 3600)
        let settings = SystemSettingsSnapshot(
            betaExpiryNoticedAt: nil,
            apiLastSeen: old,
            lockedVersion: nil
        )
        let eval = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: app03,
            apiVersion: nil,
            settings: settings,
            isFreshInstall: false,
            buildDate: now
        )
        #expect(eval.lockState == .locked(.apiUnreachable))

        let afterCheck = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: app03,
            apiVersion: api10,
            settings: settings,
            isFreshInstall: false,
            buildDate: now
        )
        #expect(!afterCheck.lockState.isLocked)
        #expect(afterCheck.mutations.setApiLastSeen != nil)
    }

    @Test func buildOlderThanSixtyDaysLocks() {
        let build = now.addingTimeInterval(-61 * 24 * 3600)
        let eval = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: app03,
            apiVersion: api10,
            settings: .init(betaExpiryNoticedAt: nil, apiLastSeen: now, lockedVersion: nil),
            isFreshInstall: false,
            buildDate: build
        )
        #expect(eval.lockState == .locked(.buildExpired))
    }

    @Test func buildExpiryUsesUTCCalendarDays() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = gmtTimeZone
        let build = try #require(utc.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12, minute: 0)))
        let expiryDay = try #require(utc.date(byAdding: .day, value: 60, to: build))
        let now = expiryDay.addingTimeInterval(3600)
        let eval = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: app03,
            apiVersion: nil,
            settings: .init(betaExpiryNoticedAt: nil, apiLastSeen: now, lockedVersion: nil),
            isFreshInstall: false,
            buildDate: build,
            calendar: Calendar.current
        )
        #expect(eval.lockState == .locked(.buildExpired))
    }

    @Test func lockedVersionBindsSameAppNewerAppIgnores() {
        let settings = SystemSettingsSnapshot(
            betaExpiryNoticedAt: now,
            apiLastSeen: now,
            lockedVersion: "0.3.1"
        )
        let same = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: app03,
            apiVersion: api10,
            settings: settings,
            isFreshInstall: false,
            buildDate: now
        )
        #expect(same.lockState.isLocked)

        let newer = AppVersion(major: 1, minor: 0, patch: 0)
        let unlocked = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: newer,
            apiVersion: api10,
            settings: settings,
            isFreshInstall: false,
            buildDate: now
        )
        #expect(!unlocked.lockState.isLocked)
    }

    @Test @MainActor func featureAccessBlocksReindexAndFavorite() {
        let appState = AppState()
        appState.versionLockState = .locked(.betaExpired)
        #expect(!appState.featureAccess.canWriteIndex)
        #expect(!appState.canReindex(UUID()))
    }

    @Test @MainActor func applyEvaluationUpdatesFeatureAccess() {
        let appState = AppState()
        let eval = VersionLockEvaluation(
            lockState: .locked(.apiUnreachable),
            updateOffer: nil,
            showLockBanner: true,
            mutations: VersionLockSettingsMutations()
        )
        appState.applyVersionLockEvaluation(eval)
        #expect(!appState.featureAccess.canWriteIndex)
        #expect(appState.versionLockBannerText() == LayoutCopy.versionLockBannerApiOffline)
    }

    private func makeStoreURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("version-check-\(UUID().uuidString).sqlite")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        _ = try IndexStoreV3.open(at: url)
        return url
    }

    private func makeTempPool() throws -> DatabasePool {
        let url = try makeStoreURL()
        return try SchemaV3.openPool(at: url)
    }
}
