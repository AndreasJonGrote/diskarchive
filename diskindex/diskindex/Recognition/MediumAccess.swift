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
    /// bug.0.4.177: Ist unter `mountPath` noch genau dieses Medium eingehängt? (Leerer Einhängeordner nach Auswurf mitten
    /// im Lauf, anderes Medium unter demselben Pfad.) Abseits des Hauptfadens mit Zeitgrenze.
    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool
    /// bug.0.4.185 (a): wie oben; `completion` meldet, wann die Prüfung wirklich zurückkehrt (hängt sie über ihre
    /// Zeitgrenze hinaus, zählt der Store sie als hängenden Zugriff des Mediums).
    func mediumIsMounted(_ medium: StoredMedium, mountPath: String, completion: PartialReadCompletion?) async -> Bool
}

extension MediumAccess {
    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool {
        await MountedMediumCheck.isMounted(medium, at: mountPath)
    }

    func mediumIsMounted(_ medium: StoredMedium, mountPath: String, completion: PartialReadCompletion?) async -> Bool {
        let mounted = await mediumIsMounted(medium, mountPath: mountPath)
        completion?.finish()
        return mounted
    }

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
    /// Tests: wird zu Beginn der Prüfung mit „läuft auf dem Haupt-Thread?“ aufgerufen und darf dort warten
    /// (Tor des Tests, bug.0.3.8.004), bevor die Prüfung weiterläuft.
    @TaskLocal static var probeThreadObserverForTesting: (@Sendable (Bool) -> Void)?
    #endif

    /// Zeitgrenze der Zugriffsprüfung (bug.0.3.8.006). Ein hängendes Volume darf die Erkennung nicht blockieren.
    var probeTimeout: TimeInterval = 5
    #if DEBUG
    /// bug.0.4.177: Prüfung „unter dem Pfad ist dieses Medium eingehängt“; `nil` = echte Prüfung (`MountedMediumCheck`).
    /// Tests mit einem Testordner als Medium setzen sie je Instanz. bug.0.4.183: nur im Debug-Code, nicht im Release.
    var mountCheck: (@Sendable (StoredMedium, String) async -> Bool)?
    #endif

    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool {
        await mediumIsMounted(medium, mountPath: mountPath, completion: nil)
    }

    func mediumIsMounted(_ medium: StoredMedium, mountPath: String, completion: PartialReadCompletion?) async -> Bool {
        #if DEBUG
        if let mountCheck {
            let mounted = await mountCheck(medium, mountPath)
            completion?.finish()
            return mounted
        }
        #endif
        return await MountedMediumCheck.isMounted(medium, at: mountPath, completion: completion)
    }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult {
        #if DEBUG
        let threadObserver = Self.probeThreadObserverForTesting
        #endif
        let timeout = probeTimeout
        // Prüfung und Zeitgeber setzen dieselbe Continuation fort; der Erste gewinnt, der Verlierer wird verworfen.
        // Nichts wartet auf den womöglich blockierten `contentsOfDirectory`-Aufruf.
        return await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            DispatchQueue.global(qos: .utility).async {
                #if DEBUG
                threadObserver?(Thread.isMainThread)
                dispatchPrecondition(condition: .notOnQueue(.main))
                #endif
                let url = URL(fileURLWithPath: volume.mountPath, isDirectory: true)
                do {
                    _ = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                    once.resume(.granted)
                } catch {
                    let nsError = error as NSError
                    let posix = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.code
                    let posixText = posix.map { ", POSIX \($0)" } ?? ""
                    once.resume(.denied(reason: "\(nsError.domain) \(nsError.code)\(posixText)"))
                }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                if once.resume(.denied(reason: "timeout")) {
                    DiskIndexLog.shared.record(.medium, .error, "zugriffsprüfung zeitgrenze", privateDetail: volume.mountPath)
                }
            }
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

/// Setzt eine Continuation höchstens einmal fort (Prüfung gegen Zeitgrenze, bug.0.3.8.006).
nonisolated private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<MediumAccessResult, Never>?

    init(_ continuation: CheckedContinuation<MediumAccessResult, Never>) {
        self.continuation = continuation
    }

    /// `true`, wenn dieser Aufruf fortgesetzt hat; spätere Aufrufe werden verworfen.
    @discardableResult
    func resume(_ result: MediumAccessResult) -> Bool {
        let pending: CheckedContinuation<MediumAccessResult, Never>? = lock.withLock {
            let value = continuation
            continuation = nil
            return value
        }
        pending?.resume(returning: result)
        return pending != nil
    }
}
