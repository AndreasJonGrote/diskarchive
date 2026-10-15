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
    static var lastVersionCheckEnqueue: Date?
    private static let enqueueCooldown: TimeInterval = 30

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
        if !force, let last = lastVersionCheckEnqueue, now.timeIntervalSince(last) < enqueueCooldown { return }
        lastVersionCheckEnqueue = now
        let created = Int(now.timeIntervalSince1970)
        let payload = Data("{}".utf8)
        try? ApiQueuePersistence.enqueue(store.pool, kind: .versionCheck, payload: payload, createdAt: created)
        IssueReporter.shared.flushInBackground()
    }

    static func recordSkippedUpdate(target: AppVersion, store: IndexStoreV3) {
        try? store.pool.write { db in
            try SystemSettingsPersistence.writeSkippedUpdateVersion(db, version: target.displayString)
        }
    }
}
