//
//  PartialChecksum.swift
//  diskindex
//
//  Erste + letzte 64 KB für Identität (235, datenbank-konzeption.md).
//

import CryptoKit
import Foundation

nonisolated enum PartialChecksum {
    static let chunkSize = 65_536

    #if DEBUG
    @TaskLocal static var computeDelayForTesting: TimeInterval?
    @TaskLocal static var fileExistsDelayForTesting: TimeInterval?
    #endif

    static func computeOffActor(
        at fileURL: URL,
        timeout: Duration = .seconds(5),
        testComputeDelay: TimeInterval? = nil,
        testFileExistsDelay: TimeInterval? = nil
    ) async throws -> (partial: Data, info: String)? {
        let path = fileURL.path
        #if DEBUG
        let testDelay = testComputeDelay ?? computeDelayForTesting
        let existsDelay = testFileExistsDelay ?? fileExistsDelayForTesting
        #else
        let testDelay: TimeInterval? = nil
        #endif
        let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
        // Arbeit und Zeitgeber setzen dieselbe Continuation höchstens einmal fort; nichts wartet auf ein blockiertes
        // `fileExists`/Lesen (bug.0.3.8.006, gleiche Bauart wie `DirectMediumAccess.probe`).
        return try await withCheckedThrowingContinuation { continuation in
            let once = ChecksumResumeOnce(continuation)
            DispatchQueue.global(qos: .utility).async {
                #if DEBUG
                if let existsDelay {
                    Thread.sleep(forTimeInterval: existsDelay)
                }
                #endif
                guard FileManager.default.fileExists(atPath: path) else {
                    once.resume(.success(nil))
                    return
                }
                once.resume(Result { try compute(at: fileURL, testComputeDelay: testDelay) })
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + seconds) {
                once.resume(.success(nil))
            }
        }
    }

    static func compute(at fileURL: URL, testComputeDelay: TimeInterval? = nil) throws -> (partial: Data, info: String)? {
        #if DEBUG
        dispatchPrecondition(condition: .notOnQueue(.main))
        if let delay = testComputeDelay {
            Thread.sleep(forTimeInterval: delay)
        }
        #endif
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        guard size > 0 else { return nil }
        try handle.seek(toOffset: 0)
        let head = try readUpTo(handle, count: min(size, UInt64(chunkSize)))
        let tail: Data
        if size <= UInt64(chunkSize) {
            tail = Data()
        } else {
            try handle.seek(toOffset: size - UInt64(chunkSize))
            tail = try readUpTo(handle, count: UInt64(chunkSize))
        }
        var hasher = SHA256()
        hasher.update(data: head)
        hasher.update(data: tail)
        let digest = Data(hasher.finalize())
        let info = "\(size)"
        return (digest, info)
    }

    private static func readUpTo(_ handle: FileHandle, count: UInt64) throws -> Data {
        var remaining = count
        var data = Data()
        data.reserveCapacity(Int(min(count, UInt64(chunkSize))))
        while remaining > 0 {
            let chunk = try handle.read(upToCount: Int(min(remaining, 65_536)))
            guard let chunk, !chunk.isEmpty else { break }
            data.append(chunk)
            remaining -= UInt64(chunk.count)
        }
        return data
    }
}

/// bug.0.4.169: Ergebnis des Lesens einer Teil-Prüfsumme außerhalb der Schreibtransaktion.
nonisolated enum PartialReadOutcome: Sendable, Equatable {
    case digest(Data)
    /// Datei fehlt bzw. hat keinen Inhalt (kein Vergleich möglich).
    case missing
    /// Lesefehler oder Zeitgrenze überschritten – der Kandidat bleibt stehen (bug.0.4.156 b).
    case unreadable
}

extension PartialChecksum {
    /// bug.0.4.169: Teil-Prüfsumme auf einer Hintergrund-Queue mit Zeitgrenze; anders als `computeOffActor` zählt die
    /// Zeitgrenze als „unlesbar“, nicht als „fehlt“. `timedOut`: die Zeitgrenze lief ab (das Lesen hängt womöglich
    /// weiter auf seinem Faden – der Aufrufer startet dann kein weiteres Lesen auf demselben Medium).
    /// `mountPath`: ist er mit der fehlenden Datei kein Einhängepunkt mehr (Medium ausgeworfen), ist das „unlesbar“,
    /// nicht „fehlt“.
    static func readOffActor(
        at fileURL: URL,
        mountPath: String? = nil,
        timeout: Duration = .seconds(5),
        beforeRead: (@Sendable (URL) -> Void)? = nil,
        afterRead: (@Sendable () -> Void)? = nil,
        isMountPoint: @escaping @Sendable (String) -> Bool = { MountedMediumCheck.isMountPoint($0) }
    ) async -> (outcome: PartialReadOutcome, timedOut: Bool) {
        let path = fileURL.path
        let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
        return await withCheckedContinuation { continuation in
            let once = PartialReadOnce(continuation)
            DispatchQueue.global(qos: .utility).async {
                // bug.0.4.176 (b): meldet, wann das Lesen wirklich zurückkehrt (auch nach der Zeitgrenze).
                defer { afterRead?() }
                beforeRead?(fileURL)
                guard FileManager.default.fileExists(atPath: path) else {
                    // bug.0.4.177 (c): fehlt die Datei, nur dann „fehlt“, wenn der Einhängepunkt noch einer ist (nach dem
                    // Auswerfen bleibt oft ein leerer Ordner stehen).
                    if let mountPath, !isMountPoint(mountPath) {
                        once.resume((.unreadable, false))
                    } else {
                        once.resume((.missing, false))
                    }
                    return
                }
                do {
                    if let computed = try compute(at: fileURL) {
                        once.resume((.digest(computed.partial), false))
                    } else {
                        once.resume((.missing, false))
                    }
                } catch {
                    once.resume((.unreadable, false))
                }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + seconds) {
                once.resume((.unreadable, true))
            }
        }
    }
}

/// bug.0.4.176 (b): Ende eines Lesevorgangs, der vielleicht über seine Zeitgrenze hinaus hängt. `markHanging` gibt
/// `true`, wenn er noch läuft – dann ruft `finish` später `onEnd` auf (vom lesenden Faden).
nonisolated final class PartialReadCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private var onEnd: (@Sendable () -> Void)?

    func finish() {
        let callback = lock.withLock { () -> (@Sendable () -> Void)? in
            finished = true
            defer { onEnd = nil }
            return onEnd
        }
        callback?()
    }

    func markHanging(onEnd callback: @escaping @Sendable () -> Void) -> Bool {
        lock.withLock {
            guard !finished else { return false }
            onEnd = callback
            return true
        }
    }
}

nonisolated private final class PartialReadOnce: @unchecked Sendable {
    private let lock = NSLock()
    typealias Value = (outcome: PartialReadOutcome, timedOut: Bool)
    private var continuation: CheckedContinuation<Value, Never>?

    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = continuation
    }

    func resume(_ outcome: Value) {
        let pending = lock.withLock { () -> CheckedContinuation<Value, Never>? in
            let value = continuation
            continuation = nil
            return value
        }
        pending?.resume(returning: outcome)
    }
}

/// Setzt die Continuation höchstens einmal fort (Prüfsumme gegen Zeitgrenze, bug.0.3.8.006).
nonisolated private final class ChecksumResumeOnce: @unchecked Sendable {
    typealias Value = (partial: Data, info: String)?
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<Value, Error>) {
        let pending: CheckedContinuation<Value, Error>? = lock.withLock {
            let value = continuation
            continuation = nil
            return value
        }
        pending?.resume(with: result)
    }
}
