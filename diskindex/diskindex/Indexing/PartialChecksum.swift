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
