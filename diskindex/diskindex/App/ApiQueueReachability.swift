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
    private var online = false
    private var periodicTimer: Timer?
    var onFlush: @Sendable () -> Void = {}
    var queueHasWork: @Sendable () -> Bool = { false }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let satisfied = path.status == .satisfied
            if satisfied, !self.online {
                self.onFlush()
            }
            self.online = satisfied
            self.syncPeriodicTimer()
        }
        monitor.start(queue: monitorQueue)
    }

    func stop() {
        monitor.cancel()
        DispatchQueue.main.async { [weak self] in
            self?.periodicTimer?.invalidate()
            self?.periodicTimer = nil
        }
    }

    func syncPeriodicTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let shouldRun = self.queueHasWork()
            if shouldRun, self.periodicTimer == nil {
                self.periodicTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                    self?.onFlush()
                }
            } else if !shouldRun {
                self.periodicTimer?.invalidate()
                self.periodicTimer = nil
            }
        }
    }
}
