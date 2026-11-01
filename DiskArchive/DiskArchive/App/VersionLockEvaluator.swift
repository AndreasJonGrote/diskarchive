//
//  VersionLockEvaluator.swift
//  DiskArchive
//
//  Pure Logik: Sperre, Update-Angebot, Settings-Mutationen (c.0.3.3.001).
//

import Foundation
import GRDB

nonisolated struct VersionLockSettingsMutations: Equatable, Sendable {
    var setBetaExpiryNoticedAt: Date?
    var setApiLastSeen: Date?
    var setLockedVersion: String?
    /// bug.0.4.053 (a): erster Start (Bezug der 30-Tage-Sperre, solange die API nie antwortete).
    var setFirstRunAt: Date? = nil
    var firstRunFresh: Bool = false
    /// bug.0.4.053 (b): höchster je gesehener Zeitpunkt.
    var setHighestSeenAt: Date? = nil
    /// `true` nach einer API-Antwort: `highestSeenAt` wird überschrieben (eine einmal vorgestellte Uhr sperrt nicht dauerhaft).
    var overwriteHighestSeenAt: Bool = false

    /// Nur die Uhr-Werte (dürfen auch ohne API-Antwort gespeichert werden).
    var clockOnly: VersionLockSettingsMutations {
        VersionLockSettingsMutations(
            setFirstRunAt: setFirstRunAt,
            firstRunFresh: firstRunFresh,
            setHighestSeenAt: setHighestSeenAt
        )
    }

    var hasClockChanges: Bool { setFirstRunAt != nil || setHighestSeenAt != nil }
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

    private static var buildExpiryCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

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

        // bug.0.4.053 (b): Eine zurückgestellte Uhr darf die Fristen nicht aufheben. Antwortet die API, gilt die
        // aktuelle Uhr und überschreibt den gespeicherten Höchstwert (Korrektur: vorgestellte Uhr sperrt nicht dauerhaft).
        let now = apiVersion != nil ? now : Self.effectiveNow(now, settings: settings)
        if apiVersion != nil {
            mutations.setHighestSeenAt = now
            mutations.overwriteHighestSeenAt = true
        } else if settings.highestSeenAt.map({ now > $0 }) ?? true {
            mutations.setHighestSeenAt = now
        }
        // bug.0.4.053 (a): ersten Start festhalten, falls noch nicht gespeichert.
        if settings.firstRunAt == nil {
            mutations.setFirstRunAt = now
            mutations.firstRunFresh = isFreshInstall
        }

        if let buildDate,
           let expiry = Self.buildExpiryCalendar.date(byAdding: .day, value: buildExpiryDays, to: buildDate),
           now >= expiry {
            lockReason = .buildExpired
        }

        // bug.0.4.053 (a): API nie erreicht → Frist ab dem ersten Start.
        let effectiveApiLastSeen = apiVersion != nil ? now : (settings.apiLastSeen ?? settings.firstRunAt)
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
            // todo.0.4.047: kein „Update überspringen“ mehr; ob der Dialog erscheint, entscheidet die Einstellung
            // „Auf Updates hinweisen“ (`AppState.applyVersionLockEvaluation`).
            if appOlderThanAPI {
                updateOffer = UpdateOffer(
                    currentDisplay: appVersion.displayString,
                    targetDisplay: apiVersion.displayString,
                    targetMajorMinor: apiVersion,
                    showBetaCountdown: betaPathActive
                )
            } else if betaPathActive {
                updateOffer = UpdateOffer(
                    currentDisplay: appVersion.displayString,
                    targetDisplay: apiVersion.displayString,
                    targetMajorMinor: apiVersion,
                    showBetaCountdown: true
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

    /// `max(Uhr, höchster je gesehener Zeitpunkt)` (bug.0.4.053 b).
    static func effectiveNow(_ now: Date, settings: SystemSettingsSnapshot) -> Date {
        guard let highest = settings.highestSeenAt else { return now }
        return max(now, highest)
    }

    /// Frische Installation (README: „keine Datenbank“): erster Start mit neuer Datenbank (bug.0.4.053 c) **und**
    /// noch kein Medium indiziert (bug.0.4.065, bug.0.4.072: wer offline installiert und schon indiziert hat, bekommt
    /// bei der ersten API-Antwort die 7-Tage-Frist; ein nur angesteckter, unentschiedener Stick zählt nicht).
    /// Gilt bis zur ersten Antwort der API.
    static func isFreshInstall(
        settings: SystemSettingsSnapshot,
        databaseWasNewThisLaunch: Bool,
        indexedMediaCount: Int
    ) -> Bool {
        guard settings.apiLastSeen == nil, indexedMediaCount == 0 else { return false }
        if settings.firstRunAt != nil { return settings.firstRunFresh }
        return databaseWasNewThisLaunch
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
            if let at = mutations.setFirstRunAt {
                try SystemSettingsPersistence.writeFirstRunIfMissing(db, at: at, fresh: mutations.firstRunFresh)
            }
            if let at = mutations.setHighestSeenAt {
                if mutations.overwriteHighestSeenAt {
                    try SystemSettingsPersistence.writeHighestSeenAt(db, at: at)
                } else {
                    try SystemSettingsPersistence.raiseHighestSeenAt(db, to: at)
                }
            }
        }
    }

    #if DEBUG
    static func readSettings(pool: DatabasePool) throws -> SystemSettingsSnapshot {
        try pool.read(SystemSettingsPersistence.read)
    }
    #endif

    /// Einstellungen und Zahl der schon indizierten Medien in einem Lesezugriff (bug.0.4.065). bug.0.4.072: nur
    /// Medien mit Index (`firstIndexedAt IS NOT NULL`); beim bloßen Anstecken legt die Erkennung schon eine Zeile an.
    static func readSettingsAndIndexedMediaCount(pool: DatabasePool) throws -> (SystemSettingsSnapshot, Int) {
        try pool.read { db in
            let settings = try SystemSettingsPersistence.read(db)
            // bug.0.4.224: ein vergessenes Medium zählt nicht mehr, auch solange seine Einträge noch gelöscht werden.
            let count = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM storages WHERE firstIndexedAt IS NOT NULL AND \(MediumCodecV3.notPendingDeletionSQL)"
            ) ?? 0
            return (settings, count)
        }
    }
}
