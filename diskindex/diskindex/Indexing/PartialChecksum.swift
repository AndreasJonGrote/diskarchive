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
    nonisolated(unsafe) static var computeDelayForTesting: TimeInterval?
    #endif

    static func computeOffActor(at fileURL: URL, timeout: Duration = .seconds(5)) async throws -> (partial: Data, info: String)? {
        try await withThrowingTaskGroup(of: (partial: Data, info: String)?.self) { group in
            group.addTask {
                try await Task.detached(priority: .utility) {
                    try compute(at: fileURL)
                }.value
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                return nil
            }
            for try await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }
            return nil
        }
    }

    static func compute(at fileURL: URL) throws -> (partial: Data, info: String)? {
        #if DEBUG
        dispatchPrecondition(condition: .notOnQueue(.main))
        if let delay = computeDelayForTesting {
            Thread.sleep(forTimeInterval: delay)
        }
        #endif
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
