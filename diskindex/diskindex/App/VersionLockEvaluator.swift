//
//  VersionLockEvaluator.swift
//  diskindex
//
//  Pure Logik: Sperre, Update-Angebot, Settings-Mutationen (c.0.3.3.001).
//

import Foundation
import GRDB

nonisolated struct VersionLockSettingsMutations: Equatable, Sendable {
    var setBetaExpiryNoticedAt: Date?
    var setApiLastSeen: Date?
    var setLockedVersion: String?
    var clearSkippedUpdateVersion: Bool = false
}

nonisolated struct VersionLockEvaluation: Equatable, Sendable {
    var lockState: VersionLockState
    var updateOffer: UpdateOffer?
    var showLockBanner: Bool
    var mutations: VersionLockSettingsMutations
}

nonisolated enum VersionLockEvaluator {
    static let betaGraceDays = 7
    static let apiOfflineDays = 30
    static let buildExpiryDays = 60

    private static let apiOneZero = AppVersion(major: 1, minor: 0, patch: 0)

    static func evaluate(
        now: Date,
        appVersion: AppVersion,
        apiVersion: AppVersion?,
        settings: SystemSettingsSnapshot,
        isFreshInstall: Bool,
        buildDate: Date?,
        calendar: Calendar = .current
    ) -> VersionLockEvaluation {
        var mutations = VersionLockSettingsMutations()
        var lockReason: VersionLockReason?

        if let buildDate,
           let expiry = calendar.date(byAdding: .day, value: buildExpiryDays, to: buildDate),
           now >= expiry {
            lockReason = .buildExpired
        }

        let effectiveApiLastSeen = apiVersion != nil ? now : settings.apiLastSeen
        if lockReason == nil, let lastSeen = effectiveApiLastSeen,
           let cutoff = calendar.date(byAdding: .day, value: -apiOfflineDays, to: now),
           lastSeen < cutoff {
            lockReason = .apiUnreachable
        }

        let apiIsOneOrNewer = apiVersion.map { !$0.isOlderThanMajorMinor(apiOneZero) } ?? false

        if lockReason == nil, appVersion.isBeta, apiIsOneOrNewer {
            if isFreshInstall {
                lockReason = .betaExpired
                mutations.setLockedVersion = appVersion.displayString
            } else if let noticed = settings.betaExpiryNoticedAt,
                      let deadline = calendar.date(byAdding: .day, value: betaGraceDays, to: noticed),
                      now >= deadline {
                lockReason = .betaExpired
                mutations.setLockedVersion = appVersion.displayString
            }
        }

        if lockReason == nil,
           let lockedRaw = settings.lockedVersion,
           let locked = AppVersion.parse(lockedRaw),
           appVersion.compareFull(to: locked) == .orderedSame {
            lockReason = .betaExpired
        }

        let lockState: VersionLockState = lockReason.map { .locked($0) } ?? .unlocked

        if apiVersion != nil {
            mutations.setApiLastSeen = now
        }

        if appVersion.isBeta, apiIsOneOrNewer, settings.betaExpiryNoticedAt == nil, !isFreshInstall, lockReason == nil {
            mutations.setBetaExpiryNoticedAt = now
        }

        let betaPathActive = appVersion.isBeta && apiIsOneOrNewer && !isFreshInstall && lockReason == nil
        var updateOffer: UpdateOffer?

        if let apiVersion {
            let appOlderThanAPI = appVersion.isOlderThanMajorMinor(apiVersion)
            let skipped = settings.skippedUpdateVersion.flatMap(AppVersion.parse)
            let skipHidesModal = skipped.map { apiVersion.compareMajorMinor(to: $0) == .orderedSame } ?? false

            if appOlderThanAPI, !skipHidesModal {
                let showSkip = !betaPathActive && lockReason == nil
                updateOffer = UpdateOffer(
                    currentDisplay: appVersion.displayString,
                    targetDisplay: apiVersion.displayString,
                    targetMajorMinor: apiVersion,
                    showSkipCheckbox: showSkip,
                    showBetaCountdown: betaPathActive
                )
            } else if betaPathActive, !skipHidesModal {
                updateOffer = UpdateOffer(
                    currentDisplay: appVersion.displayString,
                    targetDisplay: apiVersion.displayString,
                    targetMajorMinor: apiVersion,
                    showSkipCheckbox: false,
                    showBetaCountdown: true
                )
            } else if lockReason != nil, appOlderThanAPI, !skipHidesModal {
                updateOffer = UpdateOffer(
                    currentDisplay: appVersion.displayString,
                    targetDisplay: apiVersion.displayString,
                    targetMajorMinor: apiVersion,
                    showSkipCheckbox: false,
                    showBetaCountdown: false
                )
            }
        }

        let showLockBanner = lockReason != nil

        return VersionLockEvaluation(
            lockState: lockState,
            updateOffer: updateOffer,
            showLockBanner: showLockBanner,
            mutations: mutations
        )
    }

    static func applyMutations(_ mutations: VersionLockSettingsMutations, pool: DatabasePool) throws {
        try pool.write { db in
            if let at = mutations.setBetaExpiryNoticedAt {
                try SystemSettingsPersistence.writeBetaExpiryNoticedAt(db, at: at)
            }
            if let at = mutations.setApiLastSeen {
                try SystemSettingsPersistence.writeApiLastSeen(db, at: at)
            }
            if let version = mutations.setLockedVersion {
                try SystemSettingsPersistence.writeLockedVersion(db, version: version)
            }
            if mutations.clearSkippedUpdateVersion {
                try SystemSettingsPersistence.writeSkippedUpdateVersion(db, version: nil)
            }
        }
    }

    static func readSettings(pool: DatabasePool) throws -> SystemSettingsSnapshot {
        try pool.read(SystemSettingsPersistence.read)
    }
}
