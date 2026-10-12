//
//  StartupSequence.swift
//  diskindex
//
//  Startreihenfolge (Aufgabe 219, F24): Symbol sofort, Datenbank im Hintergrund, danach Verdrahtung auf dem
//  Hauptfaden, `quick_check` nur bei Bedarf und ebenfalls im Hintergrund. Jeder Schritt steht mit Dauer im Protokoll.
//

import Foundation

/// Wann `PRAGMA quick_check` läuft: nach unsauberem Ende oder wenn der letzte Check länger als 7 Tage zurückliegt.
nonisolated enum IntegrityCheckPolicy {
    static let interval: TimeInterval = 7 * 24 * 3600
    static let lastCheckKey = "lastIntegrityCheck"

    static func isDue(previousRunUnclean: Bool, lastCheck: Date?, now: Date) -> Bool {
        if previousRunUnclean { return true }
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= interval
    }
}

@MainActor
enum StartupSequence {
    /// Schritte 2–4: Datenbank im Hintergrund öffnen, auf dem Hauptfaden verdrahten (`wire`), Integritätsprüfung.
    /// Schritt 1 (Menüleistensymbol, Fenster) macht `AppDelegate` vorher und ohne Datenbank.
    @discardableResult
    static func run(
        previousRunUnclean: Bool,
        defaults: UserDefaults,
        now: @escaping @Sendable () -> Date = { Date() },
        open: @escaping @Sendable () throws -> IndexStoreV3,
        wire: @escaping (IndexStoreV3) -> Void,
        integrityCheck: @escaping @Sendable (IndexStoreV3) throws -> Void = { try $0.runIntegrityCheck() },
        onFailure: @escaping (Error) -> Void
    ) -> Task<Void, Never> {
        Task {
            let opened = DispatchTime.now()
            let store: IndexStoreV3
            do {
                store = try await Task.detached(priority: .userInitiated) { try open() }.value
            } catch {
                guard !Task.isCancelled else { return }
                onFailure(error)
                return
            }
            guard !Task.isCancelled else { return }
            log("open", since: opened)
            let wired = DispatchTime.now()
            wire(store)
            log("attach", since: wired)
            let lastCheck = defaults.object(forKey: IntegrityCheckPolicy.lastCheckKey) as? Date
            guard IntegrityCheckPolicy.isDue(
                previousRunUnclean: previousRunUnclean, lastCheck: lastCheck, now: now()
            ) else { return }
            let checked = DispatchTime.now()
            do {
                try await Task.detached(priority: .utility) { try integrityCheck(store) }.value
                defaults.set(now(), forKey: IntegrityCheckPolicy.lastCheckKey)
                log("integrity", since: checked)
            } catch {
                log("integrity", since: checked)
                guard !Task.isCancelled else { return }
                onFailure(error)
            }
        }
    }

    static func log(_ step: String, since start: DispatchTime) {
        let ms = Int((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
        DiskIndexLog.shared.record(.app, .info, "startup \(step) ms=\(ms)")
    }
}
