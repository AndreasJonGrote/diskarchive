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
            (settings, mediaCount) = try VersionLockEvaluator.readSettingsAndIndexedMediaCount(pool: store.pool)
        } catch {
            DiskIndexLog.shared.record(.app, .error, "version lock local read failed \(DiskIndexLog.errorSummary(error))")
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
        guard let appVersion = AppVersion.currentApp() else {
            DiskIndexLog.shared.record(.app, .error, "version lock local no app version")
            return
        }
        let pool = store.pool
        let evaluation = VersionLockEvaluator.evaluate(
            now: now,
            appVersion: appVersion,
            apiVersion: nil,
            settings: settings,
            isFreshInstall: VersionLockEvaluator.isFreshInstall(
                settings: settings,
                databaseWasNewThisLaunch: databaseWasNewThisLaunch ?? freshInstallForVersionCheck,
                indexedMediaCount: mediaCount
            ),
            buildDate: AppVersion.currentBuildDate()
        )
        applyEvaluation(evaluation, appState: appState, pool: pool, persist: false)
    }

    /// bug.0.4.137: Lesen und Schreiben der Datenbank im Hintergrund (wartet sonst auf dem Main Actor hinter
    /// Indexer-Stapeln und `wal_checkpoint`); nur das Anwenden auf `AppState` läuft auf main.
    /// bug.0.4.144: Lesen, Auswerten und Schreiben laufen über zwei `await`; zwei Antworten kurz nacheinander werden
    /// deshalb der Reihe nach verarbeitet (eine Warteschlange), die spätere überschreibt nie mit älterem Stand.
    private static var lastAPIResultTask: Task<Void, Never>?

    static func handleAPIResult(
        _ response: VersionCheckResponse?,
        appState: AppState,
        store: IndexStoreV3,
        now: Date = Date(),
        databaseWasNewThisLaunch: Bool? = nil
    ) async {
        let previous = lastAPIResultTask
        let task = Task { @MainActor in
            await previous?.value
            await processAPIResult(
                response, appState: appState, store: store, now: now, databaseWasNewThisLaunch: databaseWasNewThisLaunch
            )
        }
        lastAPIResultTask = task
        await task.value
    }

    private static func processAPIResult(
        _ response: VersionCheckResponse?,
        appState: AppState,
        store: IndexStoreV3,
        now: Date,
        databaseWasNewThisLaunch: Bool?
    ) async {
        guard let appVersion = AppVersion.currentApp() else { return }
        let pool = store.pool
        let read = await Self.onDatabaseQueue {
            try? VersionLockEvaluator.readSettingsAndIndexedMediaCount(pool: pool)
        }
        guard let (settings, mediaCount) = read else { return }
        // bug.0.4.053 (c) / bug.0.4.065: „frisch“ = Datenbank beim ersten Start neu und bei der ersten
        // API-Antwort noch kein Medium indiziert (README „Netz (API)“, Präzisierung 18.10.).
        let fresh = VersionLockEvaluator.isFreshInstall(
            settings: settings,
            databaseWasNewThisLaunch: databaseWasNewThisLaunch ?? freshInstallForVersionCheck,
            indexedMediaCount: mediaCount
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
        if response != nil {
            let mutations = evaluation.mutations
            await Self.onDatabaseQueue {
                try? VersionLockEvaluator.applyMutations(mutations, pool: pool)
            }
        }
        applyEvaluation(evaluation, appState: appState, pool: pool, persist: response != nil, alreadyPersisted: true)
    }

    /// Blockierende Datenbankarbeit auf einer Dispatch-Queue statt auf dem Pool der Swift-Nebenläufigkeit (wie
    /// `IndexStoreV3.checkpointInBackground`): wartet der Schreiber, hält sie keinen Faden des Pools fest.
    nonisolated private static func onDatabaseQueue<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        #if DEBUG
        let observer = VersionCheckTestHooks.databaseThreadObserver
        #endif
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                #if DEBUG
                observer?(Thread.isMainThread)
                #endif
                continuation.resume(returning: work())
            }
        }
    }

    private static func applyEvaluation(
        _ evaluation: VersionLockEvaluation,
        appState: AppState,
        pool: DatabasePool,
        persist: Bool,
        alreadyPersisted: Bool = false
    ) {
        let wasLocked = appState.versionLockState.isLocked
        if persist {
            if !alreadyPersisted {
                try? VersionLockEvaluator.applyMutations(evaluation.mutations, pool: pool)
            }
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

#if DEBUG
/// bug.0.4.137 (Tests): meldet je Datenbankschritt des Versions-Checks, ob er auf dem Hauptfaden lief; je Task, kein
/// prozessweiter Schalter.
nonisolated enum VersionCheckTestHooks {
    @TaskLocal static var databaseThreadObserver: (@Sendable (Bool) -> Void)?
}
#endif
