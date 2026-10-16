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

    static func reevaluateLocal(appState: AppState, store: IndexStoreV3, now: Date = Date()) {
        guard let appVersion = AppVersion.currentApp() else { return }
        let pool = store.pool
        let settings: SystemSettingsSnapshot
        do {
            settings = try VersionLockEvaluator.readSettings(pool: pool)
        } catch {
            return
        }
        let evaluation = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: appVersion,
            apiVersion: nil,
            settings: settings,
            isFreshInstall: false,
            buildDate: AppVersion.currentBuildDate()
        )
        applyEvaluation(evaluation, appState: appState, pool: pool, persist: false)
    }

    static func handleAPIResult(
        _ response: VersionCheckResponse?,
        appState: AppState,
        store: IndexStoreV3,
        now: Date = Date()
    ) {
        guard let appVersion = AppVersion.currentApp() else { return }
        let pool = store.pool
        let settings: SystemSettingsSnapshot
        do {
            settings = try VersionLockEvaluator.readSettings(pool: pool)
        } catch {
            return
        }
        let storageCount = (try? pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM storages") ?? 0
        }) ?? 0
        let fresh = freshInstallForVersionCheck || storageCount == 0
        let evaluation = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: appVersion,
            apiVersion: response?.version,
            settings: settings,
            isFreshInstall: fresh,
            buildDate: AppVersion.currentBuildDate()
        )
        freshInstallForVersionCheck = false
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
        }
        appState.applyVersionLockEvaluation(evaluation)
        if !wasLocked, evaluation.lockState.isLocked {
            appState.onVersionLockEngaged?()
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
