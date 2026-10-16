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
    #endif

    static func computeOffActor(
        at fileURL: URL,
        timeout: Duration = .seconds(5),
        testComputeDelay: TimeInterval? = nil
    ) async throws -> (partial: Data, info: String)? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        #if DEBUG
        let testDelay = testComputeDelay ?? computeDelayForTesting
        #else
        let testDelay: TimeInterval? = nil
        #endif
        return try await withThrowingTaskGroup(of: (partial: Data, info: String)?.self) { group in
            group.addTask {
                try await Task.detached(priority: .utility) { () -> (partial: Data, info: String)? in
                    try compute(at: fileURL, testComputeDelay: testDelay)
                }.value
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                return nil
            }
            for try await result in group {
                group.cancelAll()
                return result
            }
            return nil
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
