//
//  ApiQueueReachability.swift
//  diskindex
//
//  Netzwerk für API-Warteschlange (0.3.1): sofort bei „online“, sonst Ping alle 60 s.
//

import Foundation
import Network

nonisolated final class ApiQueueReachability: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "app.diskarchive.apiQueue.path")
    private let onlineLock = NSLock()
    private var online = false
    private var periodicTimer: Timer?
    /// bug.0.4.110: Wecker für den nächsten Fälligkeitstermin (Backoff 1/2/4 h), solange nichts jetzt fällig ist.
    private var wakeTimer: Timer?
    private let scheduleQueue = DispatchQueue(label: "app.diskarchive.apiQueue.schedule", qos: .utility)
    var onFlush: @Sendable () -> Void = {}
    /// Wird im Hintergrund gerufen (bug.0.4.114): fällige Arbeit jetzt, und der nächste Termin.
    var queueSchedule: @Sendable () -> (hasDueWork: Bool, nextDue: Date?) = { (false, nil) }
    var now: @Sendable () -> Date = { Date() }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let satisfied = path.status == .satisfied
            let wasOnline = self.readOnline()
            if satisfied, !wasOnline {
                self.onFlush()
            }
            self.setOnline(satisfied)
            self.syncPeriodicTimer()
        }
        monitor.start(queue: monitorQueue)
    }

    func stop() {
        monitor.cancel()
        DispatchQueue.main.async { [weak self] in
            self?.periodicTimer?.invalidate()
            self?.periodicTimer = nil
            self?.wakeTimer?.invalidate()
            self?.wakeTimer = nil
        }
    }

    func syncPeriodicTimer() {
        // Datenbank im Hintergrund lesen, nur das Umstellen der Zeitgeber läuft auf main.
        scheduleQueue.async { [weak self] in
            guard let self else { return }
            let schedule = self.queueSchedule()
            let moment = self.now()
            DispatchQueue.main.async { [weak self] in
                self?.apply(schedule, now: moment)
            }
        }
    }

    private func apply(_ schedule: (hasDueWork: Bool, nextDue: Date?), now: Date) {
        if schedule.hasDueWork, periodicTimer == nil {
            periodicTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.onFlush()
            }
        } else if !schedule.hasDueWork {
            periodicTimer?.invalidate()
            periodicTimer = nil
        }
        wakeTimer?.invalidate()
        wakeTimer = nil
        // Nichts fällig, aber ein Termin steht aus: genau zu diesem Zeitpunkt aufwachen.
        if !schedule.hasDueWork, let due = schedule.nextDue {
            let delay = max(1, due.timeIntervalSince(now))
            wakeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.wakeTimer = nil
                self?.onFlush()
                self?.syncPeriodicTimer()
            }
        }
    }

    #if DEBUG
    /// Tests: Zustand der Zeitgeber nach `syncPeriodicTimer` (auf main lesen).
    var timersForTesting: (periodic: Bool, wakeFireDate: Date?) {
        (periodicTimer != nil, wakeTimer?.fireDate)
    }
    #endif

    private func readOnline() -> Bool {
        onlineLock.lock()
        defer { onlineLock.unlock() }
        return online
    }

    private func setOnline(_ value: Bool) {
        onlineLock.lock()
        online = value
        onlineLock.unlock()
    }
}
