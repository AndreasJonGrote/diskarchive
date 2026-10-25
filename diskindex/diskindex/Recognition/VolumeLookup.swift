//
//  VolumeLookup.swift
//  diskindex
//

import Darwin
import Foundation

nonisolated enum VolumeLookup {
    /// Zeitgrenze je Abfrage (bug.0.3.9.002), wie `DirectMediumAccess.probeTimeout`.
    static let defaultTimeout: TimeInterval = 5

    /// Volume-Daten abseits des Hauptfadens. Jede Abfrage läuft für sich (nebenläufige Queue statt einer seriellen):
    /// ein hängendes Volume hält keine weitere Abfrage auf. Nach `timeout` Sekunden kehrt der Aufruf mit `nil`
    /// (kein Kandidat) zurück und wartet nicht auf die blockierte Abfrage. `lookup` und `logTimeout` (erhält den
    /// Pfad): nur Tests ersetzen sie, damit kein Testlauf in das gemeinsame Protokoll schreibt.
    static func info(
        at url: URL,
        timeout: TimeInterval = defaultTimeout,
        lookup: @escaping @Sendable (URL) -> VolumeInfo? = { infoSync(at: $0) },
        logTimeout: @escaping @Sendable (String) -> Void = { logTimeoutLine(path: $0) }
    ) async -> VolumeInfo? {
        // Abfrage und Zeitgeber setzen dieselbe Continuation fort; der Erste gewinnt, der Verlierer wird verworfen.
        await withCheckedContinuation { continuation in
            let once = LookupResumeOnce(continuation)
            DispatchQueue.global(qos: .utility).async {
                once.resume(lookup(url))
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                // bug.0.4.085 e): erst die Zeitgrenze melden, dann fortsetzen – sonst konnte der Aufrufer schon weiter
                // sein, bevor die Meldung geschrieben war (Test sah einmal keine Meldung).
                once.resume(nil, beforeResume: { logTimeout(url.path) })
            }
        }
    }

    static func logTimeoutLine(path: String) {
        DiskIndexLog.shared.record(.medium, .error, "volume-lookup zeitgrenze", privateDetail: path)
    }

    /// Synchrone Abfrage für `VolumeLookupFlights` (läuft dort auf einer Hintergrund-Queue).
    static func infoSyncForFlights(at url: URL) -> VolumeInfo? {
        infoSync(at: url)
    }

    private static func infoSync(at url: URL) -> VolumeInfo? {
        #if DEBUG
        dispatchPrecondition(condition: .notOnQueue(.main))
        #endif
        let path = url.path
        let keys: Set<URLResourceKey> = [
            .volumeNameKey, .volumeCreationDateKey, .volumeIsRemovableKey, .volumeIsEjectableKey,
            .volumeIsInternalKey, .volumeIsLocalKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        let disk = DiskArbitrationLookup.attributes(path: path)
        let fsType = fileSystemType(path: path)
        let name = values.volumeName ?? url.lastPathComponent
        let snapshot = path.contains("com.apple.TimeMachine") || path.contains(".MobileBackups") || name == "Time Machine Backups"
        return VolumeInfo(
            mountPath: path,
            name: name,
            fsType: fsType,
            volumeTotalBytes: Int64(values.volumeTotalCapacity ?? 0),
            volumeFreeBytes: values.volumeAvailableCapacity.map(Int64.init),
            diskSizeBytes: disk.mediaSizeBytes,
            volumeUUID: disk.volumeUUID,
            createdAt: values.volumeCreationDate,
            isRemovable: values.volumeIsRemovable ?? false,
            isEjectable: values.volumeIsEjectable ?? false,
            isInternal: values.volumeIsInternal ?? false,
            isLocal: (values.volumeIsLocal ?? true) && !disk.isNetwork,
            deviceProtocol: disk.deviceProtocol,
            model: disk.model,
            isTimeMachineSnapshot: snapshot
        )
    }

    private static func fileSystemType(path: String) -> String {
        var info = statfs()
        guard statfs(path, &info) == 0 else { return "" }
        return withUnsafeBytes(of: info.f_fstypename) { raw in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
    }
}

/// Setzt eine Continuation höchstens einmal fort (Abfrage gegen Zeitgrenze, bug.0.3.9.002).
nonisolated private final class LookupResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<VolumeInfo?, Never>?

    init(_ continuation: CheckedContinuation<VolumeInfo?, Never>) {
        self.continuation = continuation
    }

    /// `true`, wenn dieser Aufruf fortgesetzt hat; spätere Aufrufe werden verworfen. `beforeResume` läuft nur beim
    /// Gewinner und vor dem Fortsetzen.
    @discardableResult
    func resume(_ result: VolumeInfo?, beforeResume: () -> Void = {}) -> Bool {
        let pending: CheckedContinuation<VolumeInfo?, Never>? = lock.withLock {
            let value = continuation
            continuation = nil
            return value
        }
        guard let pending else { return false }
        beforeResume()
        pending.resume(returning: result)
        return true
    }
}

/// Ergebnis eines Versuchs mit Zeitgrenze (bug.0.3.9.012).
nonisolated enum VolumeLookupOutcome: Sendable, Equatable {
    case found(VolumeInfo)
    /// Abfrage kam zurück, aber ohne Daten (Volume noch nicht bereit oder schon weg).
    case missing
    /// Zeitgrenze abgelaufen; die Abfrage läuft womöglich noch.
    case timedOut
}

/// Höchstens eine laufende Abfrage je Pfad (bug.0.3.9.012). Hängt eine Abfrage (Platte läuft an), belegt sie einen
/// GCD-Thread; ein neuer Versuch für denselben Pfad hängt sich an die laufende Abfrage an, statt einen weiteren
/// Thread zu blockieren. Andere Pfade laufen unabhängig. Je Instanz (MediumMonitor), kein prozessweiter Zustand.
nonisolated final class VolumeLookupFlights: @unchecked Sendable {
    /// Laufende Abfrage eines Pfads: Generation (eine verlassene Abfrage darf beim Zurückkehren keinen neueren Flug
    /// entfernen) und die noch wartenden Versuche.
    private struct Flight {
        let generation: Int
        var waiters: [FlightWaiter]
    }

    private let lock = NSLock()
    private var running: [String: Flight] = [:]
    private var nextGeneration = 0
    private var startedCount: [String: Int] = [:]
    private let lookup: @Sendable (URL) -> VolumeInfo?

    init(lookup: @escaping @Sendable (URL) -> VolumeInfo? = { VolumeLookup.infoSyncForFlights(at: $0) }) {
        self.lookup = lookup
    }

    #if DEBUG
    /// Gestartete Abfragen für `path` (Tests: belegt „höchstens eine laufende je Pfad“).
    func startedLookups(path: String) -> Int {
        lock.withLock { startedCount[path] ?? 0 }
    }
    #endif

    /// Ein Versuch: an eine laufende Abfrage anhängen oder eine neue starten; nach `timeout` `.timedOut`.
    func attempt(at url: URL, timeout: TimeInterval) async -> VolumeLookupOutcome {
        let path = url.path
        return await withCheckedContinuation { continuation in
            let waiter = FlightWaiter(continuation)
            let generation: Int? = lock.withLock {
                if running[path] != nil {
                    running[path]?.waiters.append(waiter)
                    return nil
                }
                nextGeneration += 1
                running[path] = Flight(generation: nextGeneration, waiters: [waiter])
                startedCount[path, default: 0] += 1
                return nextGeneration
            }
            if let generation {
                let lookup = lookup
                DispatchQueue.global(qos: .utility).async { [self] in
                    let result = lookup(url)
                    // Nur den eigenen Flug beenden; wurde er verlassen, gehört der Eintrag schon einem neueren.
                    let waiters: [FlightWaiter] = lock.withLock {
                        guard running[path]?.generation == generation else { return [] }
                        return running.removeValue(forKey: path)?.waiters ?? []
                    }
                    for waiter in waiters {
                        waiter.resume(result.map(VolumeLookupOutcome.found) ?? .missing)
                    }
                }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { [self] in
                // Abgelaufenen Versuch aus dem Flug nehmen, damit die Liste bei langen Hängern nicht wächst.
                lock.withLock {
                    running[path]?.waiters.removeAll { $0 === waiter }
                }
                waiter.resume(.timedOut)
            }
        }
    }

    /// Ausgehängt: den Flug des Pfads verlassen (kehrt er nie zurück, blockiert er den Pfad sonst dauerhaft) und
    /// wartende Versuche mit `.missing` fortsetzen. Ein späteres Einhängen startet eine neue Abfrage.
    func abandon(path: String) {
        let waiters: [FlightWaiter] = lock.withLock { running.removeValue(forKey: path)?.waiters ?? [] }
        for waiter in waiters {
            waiter.resume(.missing)
        }
    }
}

/// Setzt eine Continuation höchstens einmal fort (Abfrage gegen Zeitgrenze, bug.0.3.9.012).
nonisolated private final class FlightWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<VolumeLookupOutcome, Never>?

    init(_ continuation: CheckedContinuation<VolumeLookupOutcome, Never>) {
        self.continuation = continuation
    }

    func resume(_ outcome: VolumeLookupOutcome) {
        let pending: CheckedContinuation<VolumeLookupOutcome, Never>? = lock.withLock {
            let value = continuation
            continuation = nil
            return value
        }
        pending?.resume(returning: outcome)
    }
}
