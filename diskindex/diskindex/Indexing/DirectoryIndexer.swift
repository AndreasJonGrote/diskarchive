//
//  DirectoryIndexer.swift
//  diskindex
//

import Foundation

/// Liest ein Medium ebenenweise und schreibt jede fertige Ebene, bevor die nächste beginnt.
nonisolated struct DirectoryIndexer: Sendable {
    func run(
        store: IndexStoreV3,
        access: any MediumAccess,
        mediumUUID: UUID,
        volume: VolumeInfo,
        configuration: ScanConfiguration,
        fromScratch: Bool,
        token: UUID,
        shouldHalt: @escaping @Sendable () async -> ScanHalt,
        onProgress: @escaping @Sendable (IndexProgress) async -> Void = { _ in }
    ) async -> IndexRunOutcome {
        var limits = configuration.limits
        limits.parallelDirectoryReads = IndexingVolumeTuning.parallelDirectoryReads(for: volume)

        if fromScratch {
            do {
                try await store.resetCompletedDepth(mediumUUID: mediumUUID)
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.index, .error, "resetCompletedDepth \(error)")
                }
            }
        }
        let stored: StoredMedium
        do {
            guard let value = try await store.medium(uuid: mediumUUID) else {
                DiskIndexLog.shared.record(.store, .error, "store error medium fehlt \(mediumUUID)")
                return IndexRunOutcome(status: .error, readErrors: 0, progress: [], completedDepths: [], firstIndexedAt: nil)
            }
            stored = value
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "store error medium \(error)")
            }
            return IndexRunOutcome(status: .error, readErrors: 0, progress: [], completedDepths: [], firstIndexedAt: nil, failureReason: IndexFailureReason.classify(error))
        }
        let began: Bool
        do {
            began = try await store.beginIndexing(mediumUUID: mediumUUID, token: token)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "store error beginIndexing \(error)")
            }
            return IndexRunOutcome(status: .error, readErrors: 0, progress: [], completedDepths: [], firstIndexedAt: stored.firstIndexedAt, failureReason: IndexFailureReason.classify(error))
        }
        guard began else {
            DiskIndexLog.shared.record(.index, .error, "begin abgelehnt medium=\(mediumUUID)")
            return IndexRunOutcome(status: .pending, readErrors: 0, progress: [], completedDepths: [], firstIndexedAt: stored.firstIndexedAt)
        }
        var backgroundRecount: Task<Void, Never>?
        defer { backgroundRecount?.cancel() }
        let fullReconcile = !fromScratch && stored.indexStatus == .indexed && stored.completedDepth > 0
        let startDepth: Int
        if fromScratch || stored.completedDepth == 0 {
            startDepth = 1
        } else if fullReconcile {
            startDepth = 1
        } else {
            startDepth = stored.completedDepth + 1
        }
        DiskIndexLog.shared.record(
            .index,
            .info,
            "start medium=\(mediumUUID) scratch=\(fromScratch) abgleich=\(fullReconcile) tiefe=\(stored.completedDepth) start=\(startDepth)"
        )
        var readErrors = 0
        var entriesCompleted = stored.fileCount + stored.folderCount
        var scanTotal = stored.scanTotal
        var highWater = 0.0
        var samples: [Double] = []
        var completedDepths: [Int] = []
        var consecutiveTimeouts = 0
        var queuedParents: [(id: Int64?, path: String?)]?
        var lastProgressNote: ContinuousClock.Instant?
        let matcher = configuration.matcher
        let seenAt = Date()
        var foldersProcessed = 0
        var needsCounting = false
        let preludeEnd = min(2, configuration.maxDepth ?? 2)

        func countWholeTree() async {
            needsCounting = false
            scanTotal = await runCountingPhase(
                store: store,
                access: access,
                mediumUUID: mediumUUID,
                volume: volume,
                configuration: configuration,
                token: token,
                shouldHalt: shouldHalt,
                onProgress: onProgress
            )
        }

        func noteIndexing(finished: Bool) async {
            let ratio: Double
            if finished {
                ratio = 1
            } else if scanTotal <= 0 {
                ratio = 0
            } else {
                ratio = min(0.99, Double(entriesCompleted) / Double(max(scanTotal, entriesCompleted)))
            }
            highWater = max(highWater, ratio)
            if samples.count < 1_000, samples.last != highWater {
                samples.append(highWater)
            }
            // Vorlauf: Anzeige wie in der Zählphase, keine Ereignisse (und keine Prozentzahl) vor der Zählung.
            if needsCounting { return }
            let now = ContinuousClock.now
            if !finished, let lastProgressNote, lastProgressNote.duration(to: now) < .milliseconds(250) {
                return
            }
            lastProgressNote = now
            await onProgress(IndexProgress(
                phase: .indexing,
                ratio: highWater,
                filesStored: entriesCompleted,
                filesDiscovered: scanTotal,
                entriesTotal: scanTotal,
                entriesCompleted: entriesCompleted,
                finished: finished
            ))
        }

        if startDepth == 1 {
            if stored.scanTotal > 0, !fromScratch {
                scanTotal = stored.scanTotal
                entriesCompleted = stored.fileCount + stored.folderCount
                await onProgress(IndexProgress(
                    phase: .indexing,
                    ratio: min(0.99, Double(entriesCompleted) / Double(max(scanTotal, entriesCompleted))),
                    filesStored: entriesCompleted,
                    filesDiscovered: scanTotal,
                    entriesTotal: scanTotal,
                    entriesCompleted: entriesCompleted,
                    finished: false
                ))
                backgroundRecount = Task {
                    let recount = await runCountingPhase(
                        store: store,
                        access: access,
                        mediumUUID: mediumUUID,
                        volume: volume,
                        configuration: configuration,
                        token: token,
                        shouldHalt: shouldHalt,
                        // Nur `scanTotal` aktualisieren; Phase und Fortschritt meldet allein die Ebenen-Schleife.
                        onProgress: { _ in }
                    )
                    guard await store.indexingIsActive(mediumUUID: mediumUUID, token: token) else { return }
                    if recount > 0 {
                        do {
                            try await store.setScanTotal(mediumUUID: mediumUUID, total: recount)
                        } catch {
                            if DiskIndexLog.isOperationalFailure(error) {
                                DiskIndexLog.shared.record(.store, .error, "store error setScanTotal \(error)")
                            }
                        }
                    }
                }
            } else {
                // Vorlauf (README 4): erst Ebene 1 und 2 über die normale Ebenen-Schleife schreiben,
                // danach den ganzen Baum zählen.
                needsCounting = true
                // Anzeige wie in der Zählphase („0 % indiziert“ mit Spinner), solange der Vorlauf läuft.
                await onProgress(IndexProgress(
                    phase: .counting,
                    ratio: 0,
                    filesStored: 0,
                    filesDiscovered: 0,
                    entriesTotal: 0,
                    entriesCompleted: 0,
                    countingCount: 0,
                    finished: false
                ))
            }
        } else if scanTotal <= 0 {
            scanTotal = max(entriesCompleted, 1)
        }

        var depth = startDepth
        while true {
            if let halt = await stopped(shouldHalt), halt != .none {
                try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                return await stop(store, mediumUUID, token, halt, stored, readErrors, samples, completedDepths)
            }
            if let maxDepth = configuration.maxDepth, depth > maxDepth { break }
            let levelStarted = ContinuousClock.now
            let parents: [(id: Int64?, path: String?)]
            if let queuedParents {
                parents = queuedParents
            } else {
                parents = await parentsFor(depth: depth, store: store, mediumUUID: mediumUUID, volume: volume)
            }
            queuedParents = nil
            if parents.isEmpty { break }

            var batch: [(parentID: Int64?, path: String?, depth: Int?, entries: [ScannedEntry], finalize: Bool)] = []
            var batchCount = 0

            func flushBatch() async -> IndexRunOutcome? {
                guard !batch.isEmpty else { return nil }
                do {
                    let started = ContinuousClock.now
                    try await store.applyDirectories(mediumUUID: mediumUUID, batches: batch, seenAt: seenAt)
                    DiskIndexLog.shared.perfIfSlow("applyDirectories", since: started)
                } catch {
                    if error is CancellationError {
                        try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                        return await stop(store, mediumUUID, token, .cancel, stored, readErrors, samples, completedDepths)
                    }
                    try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                    return await failWrite(error, store, mediumUUID, token, stored, readErrors, samples, completedDepths)
                }
                batch.removeAll(keepingCapacity: true)
                batchCount = 0
                if let halt = await stopped(shouldHalt) {
                    try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                    return await stop(store, mediumUUID, token, halt, stored, readErrors, samples, completedDepths)
                }
                return nil
            }

            var offset = 0
            while offset < parents.count {
                let end = min(offset + limits.parallelDirectoryReads, parents.count)
                for parent in parents[offset..<end] {
                    foldersProcessed += 1
                    if foldersProcessed % 50 == 0,
                       await store.indexingIsActive(mediumUUID: mediumUUID, token: token) == false {
                        try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                        return await stop(store, mediumUUID, token, .cancel, stored, readErrors, samples, completedDepths)
                    }
                    let url = directoryURL(mountPath: volume.mountPath, itemPath: parent.path)
                    do {
                        var folderEntries: [ScannedEntry] = []
                        try await readFolderWithRetry(access: access, url: url, limits: limits) { chunk in
                            let parentPath = IgnoreMatcher.storedPathSegments(parent.path)
                            let entries = scannedEntries(from: chunk, matcher: matcher, parentPath: parentPath)
                            if !entries.isEmpty {
                                try await store.applyDirectories(
                                    mediumUUID: mediumUUID,
                                    batches: [(parentID: parent.id, path: parent.path ?? "/", depth: depth, entries: entries, finalize: false)],
                                    seenAt: seenAt
                                )
                                entriesCompleted += entries.count
                                await noteIndexing(finished: false)
                            }
                            folderEntries.append(contentsOf: entries)
                            if let halt = await stopped(shouldHalt), halt != .none {
                                throw DirectoryIndexInterrupted(halt: halt)
                            }
                        }
                        if !folderEntries.isEmpty {
                            batch.append((parentID: parent.id, path: parent.path ?? "/", depth: depth, entries: folderEntries, finalize: true))
                            batchCount += folderEntries.count
                        } else {
                            batch.append((parentID: parent.id, path: parent.path ?? "/", depth: depth, entries: [], finalize: true))
                        }
                        consecutiveTimeouts = 0
                        if batchCount >= limits.batchEntryLimit {
                            if let early = await flushBatch() { return early }
                        }
                    } catch let interrupted as DirectoryIndexInterrupted {
                        try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                        return await stop(store, mediumUUID, token, interrupted.halt, stored, readErrors, samples, completedDepths)
                    } catch is DirectoryReadStalled {
                        consecutiveTimeouts += 1
                        readErrors += 1
                        DiskIndexLog.shared.record(.index, .error, "ordner lesestall")
                        if let folderID = parent.id {
                            try? await store.markFolderUnreadable(mediumUUID: mediumUUID, folderID: folderID)
                        }
                        if IndexRunGuard.shouldPending(consecutiveTimeouts: consecutiveTimeouts, limit: limits.consecutiveTimeoutLimit) {
                            try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                            _ = try? await store.finishIndexing(mediumUUID: mediumUUID, token: token, status: .pending, firstIndexedAt: stored.firstIndexedAt)
                            return IndexRunOutcome(status: .pending, readErrors: readErrors, progress: samples, completedDepths: completedDepths, firstIndexedAt: stored.firstIndexedAt, failureReason: .timeout)
                        }
                    } catch is CancellationError {
                        try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                        return await stop(store, mediumUUID, token, .cancel, stored, readErrors, samples, completedDepths)
                    } catch {
                        consecutiveTimeouts = 0
                        if parent.id == nil {
                            DiskIndexLog.shared.record(.index, .error, "wurzel \(error.localizedDescription)", privateDetail: url.path)
                            do {
                                _ = try await store.finishIndexing(mediumUUID: mediumUUID, token: token, status: .error, firstIndexedAt: nil)
                            } catch {
                                if DiskIndexLog.isOperationalFailure(error) {
                                    DiskIndexLog.shared.record(.index, .error, "finish nach stapel \(error)")
                                }
                            }
                            return IndexRunOutcome(
                                status: .error,
                                readErrors: readErrors,
                                progress: samples,
                                completedDepths: completedDepths,
                                firstIndexedAt: stored.firstIndexedAt,
                                failureReason: IndexFailureReason.classify(error)
                            )
                        }
                        readErrors += 1
                        if let folderID = parent.id {
                            try? await store.markFolderUnreadable(mediumUUID: mediumUUID, folderID: folderID)
                        }
                        DiskIndexLog.shared.record(.index, .error, "ordner übersprungen \(error.localizedDescription)", privateDetail: url.path)
                    }
                }
                offset = end
            }

            if !batch.isEmpty {
                if let early = await flushBatch() { return early }
            }

            if await store.indexingIsActive(mediumUUID: mediumUUID, token: token) == false {
                try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                return await stop(store, mediumUUID, token, .cancel, stored, readErrors, samples, completedDepths)
            }
            do {
                try await store.completeLayer(mediumUUID: mediumUUID, depth: depth)
                completedDepths.append(depth)
                DiskIndexLog.shared.record(.index, .info, "ebene \(depth) fertig medium=\(mediumUUID)")
                DiskIndexLog.shared.perfIfSlow("ebene", since: levelStarted)
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else {
                    return await stop(store, mediumUUID, token, .cancel, stored, readErrors, samples, completedDepths)
                }
                DiskIndexLog.shared.record(.index, .error, "ebene \(depth) \(error)")
                do {
                    _ = try await store.finishIndexing(mediumUUID: mediumUUID, token: token, status: .error, firstIndexedAt: nil)
                } catch {
                    if DiskIndexLog.isOperationalFailure(error) {
                        DiskIndexLog.shared.record(.index, .error, "finish nach ebenenfehler \(error)")
                    }
                }
                return IndexRunOutcome(status: .error, readErrors: readErrors, progress: samples, completedDepths: completedDepths, firstIndexedAt: stored.firstIndexedAt, failureReason: IndexFailureReason.classify(error))
            }
            if let halt = await stopped(shouldHalt) {
                try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                return await stop(store, mediumUUID, token, halt, stored, readErrors, samples, completedDepths)
            }
            if needsCounting, depth >= preludeEnd { await countWholeTree() }
            if let maxDepth = configuration.maxDepth, depth >= maxDepth { break }
            let next = await parentsFor(depth: depth + 1, store: store, mediumUUID: mediumUUID, volume: volume)
            if next.isEmpty { break }
            queuedParents = next
            depth += 1
        }

        if needsCounting { await countWholeTree() }
        await noteIndexing(finished: true)
        let stamped = Date()
        try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
        let committed: Bool
        do {
            committed = try await store.finishIndexing(
                mediumUUID: mediumUUID,
                token: token,
                status: .indexed,
                firstIndexedAt: stamped
            )
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "finish \(error)")
            }
            committed = false
        }
        DiskIndexLog.shared.record(.index, .info, "ende medium=\(mediumUUID) committed=\(committed) lesefehler=\(readErrors)")
        let fresh = try? await store.medium(uuid: mediumUUID)
        return IndexRunOutcome(
            status: committed ? .indexed : (fresh?.indexStatus ?? .pending),
            readErrors: readErrors,
            progress: samples,
            completedDepths: completedDepths,
            firstIndexedAt: fresh?.firstIndexedAt
        )
    }

    private func runCountingPhase(
        store: IndexStoreV3,
        access: any MediumAccess,
        mediumUUID: UUID,
        volume: VolumeInfo,
        configuration: ScanConfiguration,
        token: UUID,
        shouldHalt: @Sendable () async -> ScanHalt,
        onProgress: @escaping @Sendable (IndexProgress) async -> Void
    ) async -> Int {
        var total = 0
        var lastNote: ContinuousClock.Instant?
        let matcher = configuration.matcher
        let root = directoryURL(mountPath: volume.mountPath, itemPath: nil)
        var queue: [(url: URL, depth: Int)] = [(root, 1)]
        var queueHead = 0

        func noteCount() async {
            let now = ContinuousClock.now
            if let lastNote, lastNote.duration(to: now) < .milliseconds(250) { return }
            lastNote = now
            await onProgress(IndexProgress(
                phase: .counting,
                ratio: 0,
                filesStored: 0,
                filesDiscovered: 0,
                entriesTotal: 0,
                entriesCompleted: 0,
                countingCount: total,
                finished: false
            ))
        }

        while queueHead < queue.count {
            if let halt = await stopped(shouldHalt), halt != .none { break }
            let item = queue[queueHead]
            queueHead += 1
            if let maxDepth = configuration.maxDepth, item.depth > maxDepth { continue }
            if await store.indexingIsActive(mediumUUID: mediumUUID, token: token) == false { break }
            do {
                try await readFolderWithRetry(access: access, url: item.url, limits: configuration.limits, counting: true) { chunk in
                    for entry in chunk {
                        if BulkDirectoryReader.shouldIgnoreName(entry.name) { continue }
                        let scanPath = relativePathSegments(from: root, to: item.url)
                        if matcher.shouldSkip(name: entry.name, isHidden: entry.isHidden, parentPath: scanPath) { continue }
                        total += 1
                        if entry.isDirectory, !entry.isPackage, !entry.isSymbolicLink {
                            let childDepth = item.depth + 1
                            if configuration.maxDepth.map({ childDepth <= $0 }) ?? true {
                                queue.append((item.url.appendingPathComponent(entry.name, isDirectory: true), childDepth))
                            }
                        }
                    }
                    await noteCount()
                }
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.index, .error, "zählen \(error.localizedDescription)", privateDetail: item.url.path)
                }
            }
        }
        if total > 0, await store.indexingIsActive(mediumUUID: mediumUUID, token: token) {
            try? await store.setScanTotal(mediumUUID: mediumUUID, total: total)
        }
        return max(total, 1)
    }

    private func readFolderWithRetry(
        access: any MediumAccess,
        url: URL,
        limits: IndexingRunLimits,
        counting: Bool = false,
        onChunk: @escaping ([ListedDirectoryEntry]) async throws -> Void
    ) async throws {
        var lastError: Error = CocoaError(.fileReadUnknown)
        for attempt in 0..<(limits.readRetryDelays.count + 1) {
            do {
                for try await chunk in Self.directoryChunks(access: access, at: url, limits: limits, counting: counting) {
                    try await onChunk(chunk)
                }
                return
            } catch {
                lastError = error
                if attempt < limits.readRetryDelays.count {
                    try await Task.sleep(for: limits.readRetryDelays[attempt])
                }
            }
        }
        throw lastError
    }

    private func failWrite(
        _ error: Error,
        _ store: IndexStoreV3,
        _ mediumUUID: UUID,
        _ token: UUID,
        _ stored: StoredMedium,
        _ readErrors: Int,
        _ samples: [Double],
        _ completedDepths: [Int]
    ) async -> IndexRunOutcome {
        if DiskIndexLog.isOperationalFailure(error) {
            DiskIndexLog.shared.record(.index, .error, "stapel \(error.localizedDescription)")
        }
        do {
            _ = try await store.finishIndexing(mediumUUID: mediumUUID, token: token, status: .error, firstIndexedAt: nil)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "finish nach stapel \(error)")
            }
        }
        return IndexRunOutcome(
            status: .error,
            readErrors: readErrors,
            progress: samples,
            completedDepths: completedDepths,
            firstIndexedAt: stored.firstIndexedAt,
            failureReason: IndexFailureReason.classify(error)
        )
    }

    private func stop(
        _ store: IndexStoreV3,
        _ mediumUUID: UUID,
        _ token: UUID,
        _ halt: ScanHalt,
        _ stored: StoredMedium,
        _ readErrors: Int,
        _ samples: [Double],
        _ completedDepths: [Int]
    ) async -> IndexRunOutcome {
        let status: StoredIndexStatus = switch halt {
        case .none, .pause, .cancel: .pending
        }
        do {
            _ = try await store.finishIndexing(mediumUUID: mediumUUID, token: token, status: status, firstIndexedAt: nil)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "abbruch \(error)")
            }
        }
        let fresh = try? await store.medium(uuid: mediumUUID)
        return IndexRunOutcome(
            status: fresh?.indexStatus ?? .pending,
            readErrors: readErrors,
            progress: samples,
            completedDepths: completedDepths,
            firstIndexedAt: fresh?.firstIndexedAt ?? stored.firstIndexedAt
        )
    }

    private func stopped(_ shouldHalt: @Sendable () async -> ScanHalt) async -> ScanHalt? {
        let halt = await shouldHalt()
        return halt == .none ? nil : halt
    }

    private static func directoryChunks(
        access: any MediumAccess,
        at url: URL,
        limits: IndexingRunLimits,
        counting: Bool = false
    ) -> AsyncThrowingStream<[ListedDirectoryEntry], Error> {
        AsyncThrowingStream { continuation in
            let chunkSize = limits.directoryChunkSize
            let stream = counting
                ? access.listDirectoryCountChunks(at: url, chunkSize: chunkSize)
                : access.listDirectoryChunks(at: url, chunkSize: chunkSize)
            Task {
                var lastLifeSign = ContinuousClock.now
                for await result in stream {
                    let now = ContinuousClock.now
                    if lastLifeSign.duration(to: now) > .seconds(limits.directoryStallTimeout) {
                        continuation.finish(throwing: DirectoryReadStalled())
                        return
                    }
                    switch result {
                    case .success(let chunk):
                        lastLifeSign = ContinuousClock.now
                        continuation.yield(chunk)
                    case .failure(let error):
                        continuation.finish(throwing: error)
                        return
                    }
                }
                continuation.finish()
            }
        }
    }

    private func parentsFor(
        depth: Int,
        store: IndexStoreV3,
        mediumUUID: UUID,
        volume: VolumeInfo
    ) async -> [(id: Int64?, path: String?)] {
        if depth == 1 {
            return [(id: nil, path: nil)]
        }
        var result: [(id: Int64?, path: String?)] = []
        var offset = 0
        while true {
            let page = (try? await store.folders(mediumUUID: mediumUUID, depth: depth - 1, offset: offset)) ?? []
            if page.isEmpty { break }
            result.append(contentsOf: page.map { (id: $0.id, path: $0.path) })
            offset += page.count
            if page.count < 5_000 { break }
        }
        return result
    }

    private func directoryURL(mountPath: String, itemPath: String?) -> URL {
        let base = URL(fileURLWithPath: mountPath, isDirectory: true)
        guard let itemPath, itemPath != "/" else { return base }
        let relative = itemPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return base.appendingPathComponent(relative, isDirectory: true)
    }

    private func relativePathSegments(from root: URL, to directory: URL) -> [String] {
        let rootPath = root.standardizedFileURL.path
        let dirPath = directory.standardizedFileURL.path
        guard dirPath.hasPrefix(rootPath) else { return [] }
        var remainder = String(dirPath.dropFirst(rootPath.count))
        if remainder.hasPrefix("/") { remainder.removeFirst() }
        guard !remainder.isEmpty else { return [] }
        return remainder.split(separator: "/").map(String.init)
    }

    private func scannedEntries(from listed: [ListedDirectoryEntry], matcher: IgnoreMatcher, parentPath: [String]) -> [ScannedEntry] {
        listed.compactMap { entry in
            if matcher.shouldSkip(name: entry.name, isHidden: entry.isHidden, parentPath: parentPath) { return nil }
            let asFile = entry.isSymbolicLink || entry.isPackage || !entry.isDirectory
            return ScannedEntry(
                name: entry.name,
                isFolder: !asFile,
                isPackage: entry.isPackage && !entry.isSymbolicLink,
                sizeBytes: asFile && !entry.isPackage && !entry.isSymbolicLink ? entry.fileSize : nil,
                modifiedAt: entry.modifiedAt,
                fileID: nil
            )
        }
    }
}
