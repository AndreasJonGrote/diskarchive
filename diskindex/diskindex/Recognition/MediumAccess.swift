//
//  MediumAccess.swift
//  diskindex
//

import Foundation

nonisolated protocol MediumAccess: Sendable {
    func probe(_ volume: VolumeInfo) async -> MediumAccessResult
    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry]
    func listDirectoryChunks(at url: URL, chunkSize: Int) -> AsyncStream<Result<[ListedDirectoryEntry], Error>>
    func listDirectoryCountChunks(at url: URL, chunkSize: Int) -> AsyncStream<Result<[ListedDirectoryEntry], Error>>
}

extension MediumAccess {
    func listDirectoryCountChunks(at url: URL, chunkSize: Int = IndexingRunLimits.standard.directoryChunkSize) -> AsyncStream<Result<[ListedDirectoryEntry], Error>> {
        listDirectoryChunks(at: url, chunkSize: chunkSize)
    }

    func listDirectoryChunks(at url: URL, chunkSize: Int = IndexingRunLimits.standard.directoryChunkSize) -> AsyncStream<Result<[ListedDirectoryEntry], Error>> {
        AsyncStream { continuation in
            Task {
                do {
                    let all = try await listDirectory(at: url)
                    var start = 0
                    while start < all.count {
                        let end = min(start + chunkSize, all.count)
                        continuation.yield(.success(Array(all[start..<end])))
                        start = end
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(.failure(error))
                    continuation.finish()
                }
            }
        }
    }
}

nonisolated struct ListedDirectoryEntry: Sendable, Equatable {
    var name: String
    var isDirectory: Bool
    var isPackage: Bool
    var isSymbolicLink: Bool
    var isHidden: Bool
    var fileSize: Int64?
    var modifiedAt: Date?
    var fileID: Int64?
    var linkCount: Int? = nil
}

enum MediumAccessResult: Sendable, Equatable {
    case granted
    case denied(reason: String)
}

nonisolated struct DirectMediumAccess: MediumAccess {
    #if DEBUG
    @TaskLocal static var probeDelayForTesting: TimeInterval?
    #endif

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult {
        #if DEBUG
        let testDelay = Self.probeDelayForTesting
        #else
        let testDelay: TimeInterval? = nil
        #endif
        return await withTaskGroup(of: MediumAccessResult?.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .utility).async {
                        #if DEBUG
                        dispatchPrecondition(condition: .notOnQueue(.main))
                        if let delay = testDelay {
                            Thread.sleep(forTimeInterval: delay)
                        }
                        #endif
                        let url = URL(fileURLWithPath: volume.mountPath, isDirectory: true)
                        do {
                            _ = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                            continuation.resume(returning: .granted)
                        } catch {
                            let nsError = error as NSError
                            let posix = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.code
                            let posixText = posix.map { ", POSIX \($0)" } ?? ""
                            continuation.resume(returning: .denied(reason: "\(nsError.domain) \(nsError.code)\(posixText)"))
                        }
                    }
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(5))
                return nil
            }
            for await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }
            return .denied(reason: "timeout")
        }
    }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(with: Result { try BulkDirectoryReader.readEntries(at: url) })
            }
        }
    }

    func listDirectoryChunks(at url: URL, chunkSize: Int = IndexingRunLimits.standard.directoryChunkSize) -> AsyncStream<Result<[ListedDirectoryEntry], Error>> {
        BulkDirectoryReader.chunkedStream(at: url, mode: .fullMetadata, chunkSize: chunkSize)
    }

    func listDirectoryCountChunks(at url: URL, chunkSize: Int = IndexingRunLimits.standard.directoryChunkSize) -> AsyncStream<Result<[ListedDirectoryEntry], Error>> {
        BulkDirectoryReader.chunkedStream(at: url, mode: .nameAndTypeOnly, chunkSize: chunkSize)
    }
}
