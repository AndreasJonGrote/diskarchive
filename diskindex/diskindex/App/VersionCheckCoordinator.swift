//
//  VersionCheckCoordinator.swift
//  diskindex
//
//  Wendet Version-Check-Ergebnisse auf AppState + settings an (c.0.3.3.001).
//

import Foundation
import GRDB

@MainActor
enum VersionCheckCoordinator {
    static var freshInstallForVersionCheck = false
    private static var globalLastVersionCheckEnqueue: Date?

    /// Per-test override; mutating `value` avoids assigning to `@TaskLocal` directly.
    final class LastEnqueueTracker: @unchecked Sendable {
        var value: Date?
    }

    @TaskLocal static var lastVersionCheckEnqueueTracker: LastEnqueueTracker?
    private static let enqueueCooldown: TimeInterval = 30

    private static func effectiveLastEnqueue() -> Date? {
        lastVersionCheckEnqueueTracker?.value ?? globalLastVersionCheckEnqueue
    }

    private static func noteEnqueue(at now: Date) {
        if let tracker = lastVersionCheckEnqueueTracker {
            tracker.value = now
        } else {
            globalLastVersionCheckEnqueue = now
        }
    }

    /// `databaseWasNewThisLaunch`: `nil` = Wert des App-Starts (`freshInstallForVersionCheck`); Tests geben ihn je
    /// Aufruf mit (bug.0.4.065, Regel 20: kein prozessweiter Schalter im Test).
    static func reevaluateLocal(
        appState: AppState,
        store: IndexStoreV3,
        now: Date = Date(),
        databaseWasNewThisLaunch: Bool? = nil
    ) {
        let settings: SystemSettingsSnapshot
        let mediaCount: Int
        do {
            (settings, mediaCount) = try VersionLockEvaluator.readSettingsAndMediaCount(pool: store.pool)
        } catch {
            return
        }
        applyLocal(
            settings: settings, mediaCount: mediaCount, appState: appState, store: store, now: now,
            databaseWasNewThisLaunch: databaseWasNewThisLaunch
        )
    }

    /// Lokale Auswertung mit schon gelesenen Werten (todo.0.4.028: der Planer liest im Hintergrund, nur das
    /// Anwenden läuft auf dem Hauptthread).
    static func applyLocal(
        settings: SystemSettingsSnapshot,
        mediaCount: Int,
        appState: AppState,
        store: IndexStoreV3,
        now: Date,
        databaseWasNewThisLaunch: Bool?
    ) {
        guard let appVersion = AppVersion.currentApp() else { return }
        let pool = store.pool
        let evaluation = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: appVersion,
            apiVersion: nil,
            settings: settings,
            isFreshInstall: VersionLockEvaluator.isFreshInstall(
                settings: settings,
                databaseWasNewThisLaunch: databaseWasNewThisLaunch ?? freshInstallForVersionCheck,
                registeredMediaCount: mediaCount
            ),
            buildDate: AppVersion.currentBuildDate()
        )
        applyEvaluation(evaluation, appState: appState, pool: pool, persist: false)
    }

    static func handleAPIResult(
        _ response: VersionCheckResponse?,
        appState: AppState,
        store: IndexStoreV3,
        now: Date = Date(),
        databaseWasNewThisLaunch: Bool? = nil
    ) {
        guard let appVersion = AppVersion.currentApp() else { return }
        let pool = store.pool
        let settings: SystemSettingsSnapshot
        let mediaCount: Int
        do {
            (settings, mediaCount) = try VersionLockEvaluator.readSettingsAndMediaCount(pool: pool)
        } catch {
            return
        }
        // bug.0.4.053 (c) / bug.0.4.065: „frisch“ = Datenbank beim ersten Start neu und bei der ersten
        // API-Antwort noch kein Medium registriert (README „Netz (API)“, Präzisierung 18.10.).
        let fresh = VersionLockEvaluator.isFreshInstall(
            settings: settings,
            databaseWasNewThisLaunch: databaseWasNewThisLaunch ?? freshInstallForVersionCheck,
            registeredMediaCount: mediaCount
        )
        let evaluation = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: appVersion,
            apiVersion: response?.version,
            settings: settings,
            isFreshInstall: fresh,
            buildDate: AppVersion.currentBuildDate()
        )
        if databaseWasNewThisLaunch == nil { freshInstallForVersionCheck = false }
        applyEvaluation(evaluation, appState: appState, pool: pool, persist: response != nil)
    }

    private static func applyEvaluation(
        _ evaluation: VersionLockEvaluation,
        appState: AppState,
        pool: DatabasePool,
        persist: Bool
    ) {
        let wasLocked = appState.versionLockState.isLocked
        if persist {
            try? VersionLockEvaluator.applyMutations(evaluation.mutations, pool: pool)
        } else if evaluation.mutations.hasClockChanges {
            // bug.0.4.053 (a)/(b): erster Start und höchste Uhrzeit auch ohne API-Antwort sichern (im Hintergrund).
            let clock = evaluation.mutations.clockOnly
            Task.detached(priority: .utility) {
                try? VersionLockEvaluator.applyMutations(clock, pool: pool)
            }
        }
        appState.applyVersionLockEvaluation(evaluation)
        if !wasLocked, evaluation.lockState.isLocked {
            appState.onVersionLockEngaged?()
        } else if wasLocked, !evaluation.lockState.isLocked {
            appState.onVersionLockReleased?()
        }
        appState.onVersionCheckEvaluationApplied?()
    }

    static func enqueueCheckIfNeeded(store: IndexStoreV3, now: Date = Date(), force: Bool = false) {
        if !force, let last = effectiveLastEnqueue(), now.timeIntervalSince(last) < enqueueCooldown { return }
        noteEnqueue(at: now)
        let created = Int(now.timeIntervalSince1970)
        let payload = Data("{}".utf8)
        let pool = store.pool
        DispatchQueue.global(qos: .utility).async {
            try? ApiQueuePersistence.enqueue(pool, kind: .versionCheck, payload: payload, createdAt: created)
            IssueReporter.shared.flushInBackground()
        }
    }

    /// todo.0.4.028: Abstand der Versions-Checks nach Kalenderzeit.
    nonisolated static let checkInterval: TimeInterval = 24 * 60 * 60
    /// Erst ab dieser Abweichung gilt die Uhr als zurückgestellt (fast gleichzeitige Prüfungen, Uhrabgleich).
    nonisolated static let clockSetBackTolerance: TimeInterval = 5 * 60

    /// Fällig, wenn noch nie geprüft, 24 h vergangen oder die Uhr deutlich vor den letzten Check zurückgestellt wurde.
    nonisolated static func isCheckDue(lastCheckAt: Date?, now: Date) -> Bool {
        guard let lastCheckAt else { return true }
        if now < lastCheckAt.addingTimeInterval(-clockSetBackTolerance) { return true }
        return now.timeIntervalSince(lastCheckAt) >= checkInterval
    }

    /// todo.0.4.028: reiht einen Versions-Check ein, wenn seit dem gespeicherten letzten Check 24 h (Kalenderzeit)
    /// vergangen sind. Läuft auf der übergebenen **seriellen** Queue; die Uhr wird erst in der Schreib-Transaktion
    /// gelesen, Prüfen, Merken und Einreihen geschehen in derselben `pool.write`. `flush` stößt danach das Senden an
    /// (Produkt: `IssueReporter.shared`), `completion` meldet, ob eingereiht wurde.
    nonisolated static func enqueueCheckIfDue(
        pool: DatabasePool,
        queue: DispatchQueue,
        now: @escaping @Sendable () -> Date,
        flush: @escaping @Sendable () -> Void,
        completion: (@Sendable (Bool) -> Void)? = nil
    ) {
        let payload = Data("{}".utf8)
        queue.async {
            let due = (try? pool.write { db -> Bool in
                let moment = now()
                let last = try SystemSettingsPersistence.readLastVersionCheckAt(db)
                guard isCheckDue(lastCheckAt: last, now: moment) else { return false }
                try SystemSettingsPersistence.writeLastVersionCheckAt(db, at: moment)
                try ApiQueuePersistence.enqueue(
                    db, kind: .versionCheck, payload: payload, createdAt: Int(moment.timeIntervalSince1970)
                )
                return true
            }) ?? false
            if due { flush() }
            completion?(due)
        }
    }

    static func recordSkippedUpdate(target: AppVersion, store: IndexStoreV3) {
        let pool = store.pool
        let version = target.displayString
        Task.detached(priority: .utility) {
            try? pool.write { db in
                try SystemSettingsPersistence.writeSkippedUpdateVersion(db, version: version)
            }
        }
    }
}
