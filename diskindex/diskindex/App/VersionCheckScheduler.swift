//
//  VersionCheckScheduler.swift
//  diskindex
//
//  Version-Check alle 24 h nach Kalenderzeit (c.0.3.3.001, todo.0.4.028): beim Start, beim Aufwachen und
//  stündlich wird geprüft, ob seit dem gespeicherten letzten Check 24 h vergangen sind.
//

import Foundation

@MainActor
final class VersionCheckScheduler {
    nonisolated static let defaultTickInterval: Duration = .seconds(60 * 60)

    private var timerTask: Task<Void, Never>?
    private var wakeTask: Task<Void, Never>?
    private weak var appState: AppState?
    private weak var store: IndexStoreV3?

    /// Uhr je Instanz (Tests: eigene Uhr statt `Date()`); wird im Hintergrund gelesen.
    private let now: @Sendable () -> Date
    private let tickInterval: Duration
    /// Aufwach-Auslöser (vorhandener Weg wie `MediumMonitor`; Tests: eigener Strom).
    private let wakeEvents: @MainActor () -> AsyncStream<Void>
    /// Stößt nach dem Einreihen das Senden an (Produkt: `IssueReporter.shared`; Tests: leer, kein Netz).
    private let flush: @Sendable () -> Void
    /// „Datenbank beim Start neu“ (bug.0.4.065): `nil` = Wert des App-Starts; Tests geben ihn mit.
    private let databaseWasNewThisLaunch: Bool?
    /// Nur Tests: meldet nach jeder Prüfung, ob ein Check eingereiht wurde.
    private let onCheckFinished: (@Sendable (Bool) -> Void)?
    /// Serielle Queue je Instanz: Takt und Aufwachen kommen fast gleichzeitig; Prüfen und Merken nacheinander.
    private let checkQueue = DispatchQueue(label: "diskindex.version-check-scheduler", qos: .utility)

    init(
        now: @escaping @Sendable () -> Date = { Date() },
        tickInterval: Duration = VersionCheckScheduler.defaultTickInterval,
        wakeEvents: @escaping @MainActor () -> AsyncStream<Void> = MediumMonitor.liveWakeEvents,
        flush: @escaping @Sendable () -> Void = { IssueReporter.shared.flushInBackground() },
        databaseWasNewThisLaunch: Bool? = nil,
        onCheckFinished: (@Sendable (Bool) -> Void)? = nil
    ) {
        self.now = now
        self.tickInterval = tickInterval
        self.wakeEvents = wakeEvents
        self.flush = flush
        self.databaseWasNewThisLaunch = databaseWasNewThisLaunch
        self.onCheckFinished = onCheckFinished
    }

    func start(appState: AppState, store: IndexStoreV3) {
        self.appState = appState
        self.store = store
        checkNow()
        timerTask?.cancel()
        let interval = tickInterval
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                self.checkNow()
            }
        }
        wakeTask?.cancel()
        let wakes = wakeEvents()
        wakeTask = Task { [weak self] in
            for await _ in wakes {
                guard !Task.isCancelled, let self else { return }
                self.checkNow()
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        wakeTask?.cancel()
        wakeTask = nil
    }

    /// Lesen im Hintergrund (serielle Queue), nur das Anwenden der lokalen Auswertung auf dem Hauptthread.
    private func checkNow() {
        guard let store else { return }
        let pool = store.pool
        let clock = now
        let databaseNew = databaseWasNewThisLaunch
        checkQueue.async { [weak self] in
            guard let read = try? VersionLockEvaluator.readSettingsAndMediaCount(pool: pool) else { return }
            let (settings, mediaCount) = read
            let moment = clock()
            Task { @MainActor [weak self] in
                guard let self, let appState = self.appState, let store = self.store else { return }
                VersionCheckCoordinator.applyLocal(
                    settings: settings, mediaCount: mediaCount, appState: appState, store: store, now: moment,
                    databaseWasNewThisLaunch: databaseNew
                )
            }
        }
        VersionCheckCoordinator.enqueueCheckIfDue(
            pool: pool, queue: checkQueue, now: clock, flush: flush, completion: onCheckFinished
        )
    }
}
