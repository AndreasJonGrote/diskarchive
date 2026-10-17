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
                if once.resume(nil) {
                    logTimeout(url.path)
                }
            }
        }
    }

    static func logTimeoutLine(path: String) {
        DiskIndexLog.shared.record(.medium, .error, "volume-lookup zeitgrenze", privateDetail: path)
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

    /// `true`, wenn dieser Aufruf fortgesetzt hat; spätere Aufrufe werden verworfen.
    @discardableResult
    func resume(_ result: VolumeInfo?) -> Bool {
        let pending: CheckedContinuation<VolumeInfo?, Never>? = lock.withLock {
            let value = continuation
            continuation = nil
            return value
        }
        pending?.resume(returning: result)
        return pending != nil
    }
}
