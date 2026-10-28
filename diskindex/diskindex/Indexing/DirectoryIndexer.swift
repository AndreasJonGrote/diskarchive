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
                    DiskIndexLog.shared.record(.index, .error, "resetCompletedDepth \(DiskIndexLog.errorSummary(error))")
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
                DiskIndexLog.shared.record(.store, .error, "store error medium \(DiskIndexLog.errorSummary(error))")
            }
            return await failedBeforeBegin(store, mediumUUID, IndexRunOutcome(status: .error, readErrors: 0, progress: [], completedDepths: [], firstIndexedAt: nil, failureReason: IndexFailureReason.classify(error)))
        }
        let began: Bool
        do {
            began = try await store.beginIndexing(mediumUUID: mediumUUID, token: token)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "store error beginIndexing \(DiskIndexLog.errorSummary(error))")
            }
            return await failedBeforeBegin(store, mediumUUID, IndexRunOutcome(status: .error, readErrors: 0, progress: [], completedDepths: [], firstIndexedAt: stored.firstIndexedAt, failureReason: IndexFailureReason.classify(error)))
        }
        guard began else {
            DiskIndexLog.shared.record(.index, .error, "begin abgelehnt medium=\(mediumUUID)")
            return IndexRunOutcome(status: .pending, readErrors: 0, progress: [], completedDepths: [], firstIndexedAt: stored.firstIndexedAt)
        }
        var backgroundRecount: Task<Void, Never>?
        defer { backgroundRecount?.cancel() }
        // bug.0.4.200 (c): ein Medium mit Lücke gleicht ab wie ein `.indexed`-Medium (liest dabei jeden Ordner neu).
        let fullReconcile = !fromScratch && stored.hasCompleteIndexExceptGaps && stored.completedDepth > 0
        // bug.0.4.127: unvollständig wegen nicht lesbarer Ordner (alle Ebenen fertig) → von oben nachlesen, sonst
        // begänne der Lauf unterhalb des Baums und meldete ohne Nachlesen „indiziert“.
        var rereadsGaps = false
        if !fromScratch, !fullReconcile, stored.completedDepth > 0 {
            rereadsGaps = (try? await store.hasUnreadableFolders(mediumUUID: mediumUUID)) ?? false
        }
        let startDepth: Int
        if fromScratch || stored.completedDepth == 0 || rereadsGaps {
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
        // bug.0.4.210: Zähler = wirklich gespeicherte Einträge (erneut gelesene zählen nicht doppelt, siehe unten);
        // bei „Neu indizieren“ nur, was dieser Lauf schreibt.
        var entriesCompleted = fromScratch ? 0 : stored.fileCount + stored.folderCount
        var scanTotal = stored.scanTotal
        var highWater = 0.0
        var samples: [Double] = []
        var completedDepths: [Int] = []
        var consecutiveTimeouts = 0
        var queuedParents: [(id: Int64?, path: String?)]?
        var lastProgressNote: ContinuousClock.Instant?
        var lastNotedPercent = -1
        let matcher = configuration.matcher
        let seenAt = Date()
        var foldersProcessed = 0
        var needsCounting = false
        let preludeEnd = min(2, configuration.maxDepth ?? 2)
        // bug.0.4.054 (REPORT 95): eine angehaltene Zählung hat keine Gesamtzahl gespeichert → beim Fortsetzen neu zählen.
        var countingIncomplete = false
        if !fromScratch, let flagged = try? await store.scanTotalIsIncomplete(mediumUUID: mediumUUID) {
            countingIncomplete = flagged
        }

        func markCountingIncomplete() async {
            do {
                try await store.markScanTotalIncomplete(mediumUUID: mediumUUID)
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.store, .error, "store error markScanTotalIncomplete \(DiskIndexLog.errorSummary(error))")
                }
            }
        }

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
            ).total
        }

        func noteIndexing(finished: Bool) async {
            let ratio = finished ? 1 : IndexProgress.displayed(entries: entriesCompleted, total: scanTotal, indexed: false)
            highWater = max(highWater, ratio)
            if samples.count < 1_000, samples.last != highWater {
                samples.append(highWater)
            }
            // Vorlauf: Anzeige wie in der Zählphase, keine Ereignisse (und keine Prozentzahl) vor der Zählung.
            if needsCounting { return }
            let now = ContinuousClock.now
            // bug.0.4.222: gedrosselt nur, solange der ganze Prozentwert gleich bleibt – sonst zeigte die Anzeige beim
            // Abziehen einen älteren Wert als den gespeicherten.
            let percent = IndexProgress.percent(highWater)
            if !finished, let lastProgressNote, lastProgressNote.duration(to: now) < .milliseconds(250), percent == lastNotedPercent {
                return
            }
            lastProgressNote = now
            lastNotedPercent = percent
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
                    ratio: IndexProgress.displayed(entries: entriesCompleted, total: scanTotal, indexed: false),
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
                        // Die alte Gesamtzahl bleibt gültig, eine abgebrochene Nachzählung braucht keinen Merker.
                        marksIncomplete: false,
                        // Nur `scanTotal` aktualisieren; Phase und Fortschritt meldet allein die Ebenen-Schleife.
                        onProgress: { _ in }
                    )
                    guard await store.indexingIsActive(mediumUUID: mediumUUID, token: token) else { return }
                    if recount.complete, recount.total > 0 {
                        do {
                            try await store.setScanTotal(mediumUUID: mediumUUID, total: recount.total)
                        } catch {
                            if DiskIndexLog.isOperationalFailure(error) {
                                DiskIndexLog.shared.record(.store, .error, "store error setScanTotal \(DiskIndexLog.errorSummary(error))")
                            }
                        }
                    }
                }
            } else {
                // Vorlauf (README 4): erst Ebene 1 und 2 über die normale Ebenen-Schleife schreiben,
                // danach den ganzen Baum zählen.
                needsCounting = true
                // bug.0.4.066: Merker schon zu Beginn des Vorlaufs, sonst fehlt er bei einem Halt nach Ebene 2
                // vor Zählbeginn, und das Fortsetzen nimmt `scanTotal = entriesCompleted` (sofort 99 %).
                await markCountingIncomplete()
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
        } else if countingIncomplete || (scanTotal <= 0 && startDepth <= preludeEnd) {
            // Fortsetzen nach einer angehaltenen Zählung oder mitten im Vorlauf (noch keine Gesamtzahl):
            // wie beim ersten Lauf zählen, nicht die Teilsumme bzw. die gespeicherten Einträge nehmen.
            needsCounting = true
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
            if startDepth > preludeEnd {
                await countWholeTree()
            } else if !countingIncomplete {
                // bug.0.4.066: der fortgesetzte Vorlauf behält den Merker bis zur vollständigen Zählung
                // (nur schreiben, wenn er noch nicht steht).
                await markCountingIncomplete()
            }
        } else if scanTotal <= 0 {
            scanTotal = max(entriesCompleted, 1)
        }

        var depth = startDepth
        while true {
            if let halt = await stopped(shouldHalt), halt != .none {
                try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                return await stop(store, mediumUUID, token, halt, fullReconcile, stored, readErrors, samples, completedDepths, volume.mountPath)
            }
            if let maxDepth = configuration.maxDepth, depth > maxDepth { break }
            let levelStarted = ContinuousClock.now
            let parents: [(id: Int64?, path: String?)]
            if let queuedParents {
                parents = queuedParents
            } else {
                do {
                    parents = try await parentsFor(depth: depth, store: store, mediumUUID: mediumUUID, volume: volume)
                } catch {
                    try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                    return await failWrite(error, store, mediumUUID, token, stored, readErrors, samples, completedDepths)
                }
            }
            queuedParents = nil
            if parents.isEmpty { break }

            var batch: [(parentID: Int64?, path: String?, depth: Int?, entries: [ScannedEntry], finalize: Bool)] = []
            var batchCount = 0

            func flushBatch() async -> IndexRunOutcome? {
                guard !batch.isEmpty else { return nil }
                do {
                    let started = ContinuousClock.now
                    let written = try await store.applyDirectories(
                        mediumUUID: mediumUUID, batches: batch, seenAt: seenAt, mountPath: volume.mountPath
                    )
                    DiskIndexLog.shared.perfIfSlow("applyDirectories", since: started)
                    // bug.0.4.210: die Wurzel kommt nur hier; sonst zählt der Abschluss nur, was er entfernt.
                    entriesCompleted += fromScratch
                        ? batch.filter { $0.parentID == nil }.reduce(0) { $0 + $1.entries.count }
                        : written.files + written.folders
                } catch {
                    if error is CancellationError {
                        try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                        return await stop(store, mediumUUID, token, .cancel, fullReconcile, stored, readErrors, samples, completedDepths, volume.mountPath)
                    }
                    try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                    return await failWrite(error, store, mediumUUID, token, stored, readErrors, samples, completedDepths)
                }
                batch.removeAll(keepingCapacity: true)
                batchCount = 0
                if let halt = await stopped(shouldHalt) {
                    try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                    return await stop(store, mediumUUID, token, halt, fullReconcile, stored, readErrors, samples, completedDepths, volume.mountPath)
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
                        return await stop(store, mediumUUID, token, .cancel, fullReconcile, stored, readErrors, samples, completedDepths, volume.mountPath)
                    }
                    let url = directoryURL(mountPath: volume.mountPath, itemPath: parent.path)
                    // bug.0.4.056 (REPORT 97): Pfad je Ordner, nicht je Block/Eintrag.
                    let parentPath = IgnoreMatcher.storedPathSegments(parent.path)
                    // bug.0.4.177: bisherige Namen der Wurzel vor dem Lesen (Vergleich „fehlt alles Bisherige?“).
                    var previousRootNames: Set<String>?
                    if parent.id == nil {
                        previousRootNames = (try? await store.children(mediumUUID: mediumUUID, parentID: nil)).map { Set($0.map(\.name)) }
                    }
                    do {
                        var folderEntries: [ScannedEntry] = []
                        // bug.0.4.210: was dieser Ordner bei „Neu indizieren“ schon gezählt hat (ein neuer Versuch liest neu).
                        var folderCounted = 0
                        try await readFolderWithRetry(
                            access: access, url: url, limits: limits,
                            onAttemptBegin: {
                                folderEntries.removeAll(keepingCapacity: true)
                                entriesCompleted -= folderCounted
                                folderCounted = 0
                            }
                        ) { chunk in
                            let entries = scannedEntries(from: chunk, matcher: matcher, parentPath: parentPath)
                            // bug.0.4.177: die Wurzel erst nach der Prüfung schreiben (ein fremdes Medium unter dem Pfad
                            // käme sonst schon stückweise in den Index); sie geht als ein Stapel unten in `batch`.
                            if !entries.isEmpty, parent.id != nil {
                                let written: MediumCountDelta
                                do {
                                    written = try await store.applyDirectories(
                                        mediumUUID: mediumUUID,
                                        batches: [(parentID: parent.id, path: parent.path ?? "/", depth: depth, entries: entries, finalize: false)],
                                        seenAt: seenAt,
                                        mountPath: volume.mountPath
                                    )
                                } catch {
                                    throw IndexWriteFailed(underlying: error)
                                }
                                // Fortsetzen und Abgleich: nur neu gespeicherte Zeilen (erneut gelesene zählen nicht).
                                if fromScratch {
                                    entriesCompleted += entries.count
                                    folderCounted += entries.count
                                } else {
                                    entriesCompleted += written.files + written.folders
                                }
                                await noteIndexing(finished: false)
                            }
                            folderEntries.append(contentsOf: entries)
                            if let halt = await stopped(shouldHalt), halt != .none {
                                throw DirectoryIndexInterrupted(halt: halt)
                            }
                        }
                        // bug.0.4.177: Liest ein Ordner leer, der Inhalt hatte (bzw. fehlt in der Wurzel alles Bisherige),
                        // erst prüfen, ob das Medium noch eingehängt ist – ein leerer Einhängeordner nach dem Auswerfen
                        // würde sonst den Index samt Favoriten als entfernt markieren. Nicht eingehängt: Lauf endet wie
                        // beim Aushängen, nichts wird entfernt.
                        if await VanishedMediumGuard.vanished(
                            folderEntries: folderEntries, parentID: parent.id, previousRootNames: previousRootNames,
                            store: store, access: access, mediumUUID: mediumUUID, stored: stored, mountPath: volume.mountPath
                        ) {
                            DiskIndexLog.shared.record(.index, .error, "medium nicht mehr eingehängt medium=\(mediumUUID)")
                            try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                            return await stop(store, mediumUUID, token, .cancel, fullReconcile, stored, readErrors, samples, completedDepths, volume.mountPath)
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
                        return await stop(store, mediumUUID, token, interrupted.halt, fullReconcile, stored, readErrors, samples, completedDepths, volume.mountPath)
                    } catch let writeFailed as IndexWriteFailed {
                        try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                        return await failWrite(writeFailed.underlying, store, mediumUUID, token, stored, readErrors, samples, completedDepths)
                    } catch is DirectoryReadStalled {
                        consecutiveTimeouts += 1
                        readErrors += 1
                        DiskIndexLog.shared.record(.index, .error, "ordner lesestall")
                        if let folderID = parent.id {
                            try? await store.markFolderUnreadable(mediumUUID: mediumUUID, folderID: folderID)
                        }
                        if IndexRunGuard.shouldPending(consecutiveTimeouts: consecutiveTimeouts, limit: limits.consecutiveTimeoutLimit) {
                            try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                            _ = try? await store.finishIndexing(
                                mediumUUID: mediumUUID, token: token, status: .pending, firstIndexedAt: stored.firstIndexedAt,
                                mountPath: volume.mountPath
                            )
                            return IndexRunOutcome(status: .pending, readErrors: readErrors, progress: samples, completedDepths: completedDepths, firstIndexedAt: stored.firstIndexedAt, failureReason: .timeout)
                        }
                    } catch is CancellationError {
                        try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                        return await stop(store, mediumUUID, token, .cancel, fullReconcile, stored, readErrors, samples, completedDepths, volume.mountPath)
                    } catch {
                        consecutiveTimeouts = 0
                        if parent.id == nil {
                            DiskIndexLog.shared.record(.index, .error, "wurzel \(DiskIndexLog.errorSummary(error))", privateDetail: url.path)
                            do {
                                _ = try await store.finishIndexing(mediumUUID: mediumUUID, token: token, status: .error, firstIndexedAt: nil)
                            } catch {
                                if DiskIndexLog.isOperationalFailure(error) {
                                    DiskIndexLog.shared.record(.index, .error, "finish nach stapel \(DiskIndexLog.errorSummary(error))")
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
                        DiskIndexLog.shared.record(.index, .error, "ordner übersprungen \(DiskIndexLog.errorSummary(error))", privateDetail: url.path)
                    }
                }
                offset = end
            }

            if !batch.isEmpty {
                if let early = await flushBatch() { return early }
            }

            if await store.indexingIsActive(mediumUUID: mediumUUID, token: token) == false {
                try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                return await stop(store, mediumUUID, token, .cancel, fullReconcile, stored, readErrors, samples, completedDepths, volume.mountPath)
            }
            do {
                try await store.completeLayer(mediumUUID: mediumUUID, depth: depth)
                completedDepths.append(depth)
                DiskIndexLog.shared.record(.index, .info, "ebene \(depth) fertig medium=\(mediumUUID)")
                DiskIndexLog.shared.perfIfSlow("ebene", since: levelStarted)
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else {
                    return await stop(store, mediumUUID, token, .cancel, fullReconcile, stored, readErrors, samples, completedDepths, volume.mountPath)
                }
                DiskIndexLog.shared.record(.index, .error, "ebene \(depth) \(DiskIndexLog.errorSummary(error))")
                do {
                    _ = try await store.finishIndexing(mediumUUID: mediumUUID, token: token, status: .error, firstIndexedAt: nil)
                } catch {
                    if DiskIndexLog.isOperationalFailure(error) {
                        DiskIndexLog.shared.record(.index, .error, "finish nach ebenenfehler \(DiskIndexLog.errorSummary(error))")
                    }
                }
                return IndexRunOutcome(status: .error, readErrors: readErrors, progress: samples, completedDepths: completedDepths, firstIndexedAt: stored.firstIndexedAt, failureReason: IndexFailureReason.classify(error))
            }
            if let halt = await stopped(shouldHalt) {
                try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                return await stop(store, mediumUUID, token, halt, fullReconcile, stored, readErrors, samples, completedDepths, volume.mountPath)
            }
            if needsCounting, depth >= preludeEnd { await countWholeTree() }
            if let maxDepth = configuration.maxDepth, depth >= maxDepth { break }
            let next: [(id: Int64?, path: String?)]
            do {
                next = try await parentsFor(depth: depth + 1, store: store, mediumUUID: mediumUUID, volume: volume)
            } catch {
                try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
                return await failWrite(error, store, mediumUUID, token, stored, readErrors, samples, completedDepths)
            }
            if next.isEmpty { break }
            queuedParents = next
            depth += 1
        }

        if needsCounting { await countWholeTree() }
        // bug.0.4.177 (b): vor dem Abschluss eines bis zum Ende gelaufenen Laufs (danach wird Verschwundenes gelöscht)
        // noch einmal prüfen, ob das Medium eingehängt ist; sonst endet der Lauf wie beim Aushängen.
        // bug.0.4.182: einmal wiederholen (Zeitgrenze, kurzes Stocken eines langsamen Mediums), bevor es als
        // „nicht eingehängt“ gilt.
        var confirmed = await store.confirmMounted(stored, mountPath: volume.mountPath, access: access)
        if !confirmed { confirmed = await store.confirmMounted(stored, mountPath: volume.mountPath, access: access) }
        if !confirmed {
            DiskIndexLog.shared.record(.index, .error, "medium vor dem abschluss nicht eingehängt medium=\(mediumUUID)")
            try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
            // Ein Aushängen (Halt) bleibt ein stiller Abbruch. Fehlt es, obwohl die Erkennung das Medium noch als
            // eingehängt führt, endet der Lauf als Fehler mit eigenem Grund – sonst bliebe er für immer unvollständig.
            if await unmountEventArrives(shouldHalt, grace: limits.unmountGrace) {
                return await stop(store, mediumUUID, token, .cancel, fullReconcile, stored, readErrors, samples, completedDepths, volume.mountPath)
            }
            return await failUnconfirmed(store, mediumUUID, token, stored, readErrors, samples, completedDepths)
        }
        await noteIndexing(finished: true)
        let stamped = Date()
        try? await store.flushMediumMeta(mediumUUID: mediumUUID, force: true)
        let committed: Bool
        // bug.0.4.127 (README 4): nicht lesbare Ordner → Index unvollständig, nicht `.indexed`. bug.0.4.199: die
        // dauerhafte Lücke ist ein Fehler mit eigenem Grund (Merker `indexGaps` und Fortschritt bleiben gespeichert).
        let hasGaps = readErrors > 0
        do {
            committed = try await store.finishIndexing(
                mediumUUID: mediumUUID,
                token: token,
                status: hasGaps ? .error : .indexed,
                firstIndexedAt: hasGaps ? nil : stamped,
                mountPath: volume.mountPath,
                ranToEnd: true
            )
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "finish \(DiskIndexLog.errorSummary(error))")
            }
            committed = false
        }
        DiskIndexLog.shared.record(.index, .info, "ende medium=\(mediumUUID) committed=\(committed) lesefehler=\(readErrors)")
        let fresh = try? await store.medium(uuid: mediumUUID)
        return IndexRunOutcome(
            status: committed ? (hasGaps ? .error : .indexed) : (fresh?.indexStatus ?? .pending),
            readErrors: readErrors,
            progress: samples,
            completedDepths: completedDepths,
            firstIndexedAt: fresh?.firstIndexedAt,
            failureReason: committed && hasGaps ? .unreadableFolders : nil,
            ranToEnd: committed
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
        marksIncomplete: Bool = true,
        onProgress: @escaping @Sendable (IndexProgress) async -> Void
    ) async -> (total: Int, complete: Bool) {
        var total = 0
        var lastNote: ContinuousClock.Instant?
        let matcher = configuration.matcher
        let root = directoryURL(mountPath: volume.mountPath, itemPath: nil)
        var queue: [(url: URL, depth: Int)] = [(root, 1)]
        var queueHead = 0
        // bug.0.4.054: Merker vor dem Zählen; nur eine vollständige Zählung speichert die Gesamtzahl und löscht ihn.
        var complete = true
        if marksIncomplete {
            do {
                try await store.markScanTotalIncomplete(mediumUUID: mediumUUID)
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.store, .error, "store error markScanTotalIncomplete \(DiskIndexLog.errorSummary(error))")
                }
            }
        }

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
            if Task.isCancelled { complete = false; break }
            if let halt = await stopped(shouldHalt), halt != .none { complete = false; break }
            let item = queue[queueHead]
            queueHead += 1
            if let maxDepth = configuration.maxDepth, item.depth > maxDepth { continue }
            if await store.indexingIsActive(mediumUUID: mediumUUID, token: token) == false { complete = false; break }
            // bug.0.4.056 (REPORT 97): Pfad je Ordner statt zwei URL-Standardisierungen je Eintrag.
            let scanPath = relativePathSegments(from: root, to: item.url)
            do {
                try await readFolderWithRetry(access: access, url: item.url, limits: configuration.limits, counting: true) { chunk in
                    for entry in chunk {
                        if BulkDirectoryReader.shouldIgnoreName(entry.name) { continue }
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
                    DiskIndexLog.shared.record(.index, .error, "zählen \(DiskIndexLog.errorSummary(error))", privateDetail: item.url.path)
                }
            }
        }
        if complete, total > 0, await store.indexingIsActive(mediumUUID: mediumUUID, token: token) {
            try? await store.setScanTotal(mediumUUID: mediumUUID, total: total)
        }
        return (max(total, 1), complete)
    }

    private func readFolderWithRetry(
        access: any MediumAccess,
        url: URL,
        limits: IndexingRunLimits,
        counting: Bool = false,
        onAttemptBegin: @escaping () -> Void = {},
        onChunk: @escaping ([ListedDirectoryEntry]) async throws -> Void
    ) async throws {
        var lastError: Error = CocoaError(.fileReadUnknown)
        for attempt in 0..<(limits.readRetryDelays.count + 1) {
            onAttemptBegin()
            do {
                for try await chunk in Self.directoryChunks(access: access, at: url, limits: limits, counting: counting) {
                    try await onChunk(chunk)
                }
                return
            } catch {
                if error is IndexWriteFailed || error is DirectoryIndexInterrupted || error is CancellationError
                    || error is DirectoryReadStalled {
                    throw error
                }
                lastError = error
                if attempt < limits.readRetryDelays.count {
                    try await Task.sleep(for: limits.readRetryDelays[attempt])
                }
            }
        }
        throw lastError
    }

    /// bug.0.4.182: Nichts wird gelöscht (`completesRun` bleibt aus); der Lauf endet als Fehler mit eigenem Grund.
    private func failUnconfirmed(
        _ store: IndexStoreV3,
        _ mediumUUID: UUID,
        _ token: UUID,
        _ stored: StoredMedium,
        _ readErrors: Int,
        _ samples: [Double],
        _ completedDepths: [Int]
    ) async -> IndexRunOutcome {
        do {
            _ = try await store.finishIndexing(mediumUUID: mediumUUID, token: token, status: .error, firstIndexedAt: nil)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "finish nach unbestätigt \(DiskIndexLog.errorSummary(error))")
            }
        }
        return IndexRunOutcome(
            status: .error,
            readErrors: readErrors,
            progress: samples,
            completedDepths: completedDepths,
            firstIndexedAt: stored.firstIndexedAt,
            failureReason: .unconfirmed
        )
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
            DiskIndexLog.shared.record(.index, .error, "stapel \(DiskIndexLog.errorSummary(error))")
        }
        do {
            _ = try await store.finishIndexing(mediumUUID: mediumUUID, token: token, status: .error, firstIndexedAt: nil)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "finish nach stapel \(DiskIndexLog.errorSummary(error))")
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

    /// bug.0.4.201 (e): Fehler vor dem Beginn (kein `finishIndexing`): der letzte Fehler ist nicht mehr die Lücke, der
    /// Merker fällt weg (sonst übersprünge das Aktivieren der App das Medium weiter).
    private func failedBeforeBegin(_ store: IndexStoreV3, _ mediumUUID: UUID, _ outcome: IndexRunOutcome) async -> IndexRunOutcome {
        do {
            try await store.clearIndexGaps(mediumUUID: mediumUUID)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.store, .error, "store error clearIndexGaps \(DiskIndexLog.errorSummary(error))")
            }
        }
        return outcome
    }

    private func stop(
        _ store: IndexStoreV3,
        _ mediumUUID: UUID,
        _ token: UUID,
        _ halt: ScanHalt,
        _ fullReconcile: Bool,
        _ stored: StoredMedium,
        _ readErrors: Int,
        _ samples: [Double],
        _ completedDepths: [Int],
        _ mountPath: String
    ) async -> IndexRunOutcome {
        let reconcileInterrupted = fullReconcile && (halt == .none || halt == .pause || halt == .cancel)
        // bug.0.4.200 (c): unterbrochener Abgleich behält den Stand davor (`.indexed` bzw. „Fehler“ wegen Lücke).
        let status: StoredIndexStatus = reconcileInterrupted ? stored.indexStatus : .pending
        let interrupted = reconcileInterrupted
        do {
            _ = try await store.finishIndexing(
                mediumUUID: mediumUUID,
                token: token,
                status: status,
                firstIndexedAt: nil,
                interrupted: interrupted,
                // bug.0.4.104: Wiederverbinden beim unterbrochenen Ende mit Teil-Prüfsumme (wie am Ende des Laufs).
                mountPath: mountPath
            )
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "abbruch \(DiskIndexLog.errorSummary(error))")
            }
        }
        let fresh = try? await store.medium(uuid: mediumUUID)
        return IndexRunOutcome(
            status: fresh?.indexStatus ?? status,
            readErrors: readErrors,
            progress: samples,
            completedDepths: completedDepths,
            firstIndexedAt: fresh?.firstIndexedAt ?? stored.firstIndexedAt,
            interrupted: interrupted
        )
    }

    /// bug.0.4.182: Meldet sich innerhalb der Karenz ein Halt (Aushängen, Abbruch, Pause)? Bedingung, kein fester Schlaf:
    /// alle 50 ms nachfragen, höchstens bis zum Ablauf.
    private func unmountEventArrives(_ shouldHalt: @Sendable () async -> ScanHalt, grace: Duration) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + grace
        while true {
            if await stopped(shouldHalt) != nil { return true }
            if clock.now >= deadline { return false }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func stopped(_ shouldHalt: @Sendable () async -> ScanHalt) async -> ScanHalt? {
        let halt = await shouldHalt()
        return halt == .none ? nil : halt
    }

    /// Takt, in dem der Wächter des Lesestroms den Stillstand prüft (`directoryChunks`; Tests leiten ihre Grenze ab).
    static let stallWatchdogTick: Duration = .seconds(1)

    private static func directoryChunks(
        access: any MediumAccess,
        at url: URL,
        limits: IndexingRunLimits,
        counting: Bool = false
    ) -> AsyncThrowingStream<[ListedDirectoryEntry], Error> {
        AsyncThrowingStream { continuation in
            final class CancelFlag: @unchecked Sendable {
                var value = false
            }
            let cancelled = CancelFlag()
            continuation.onTermination = { @Sendable _ in
                cancelled.value = true
            }
            let chunkSize = limits.directoryChunkSize
            let cancelCheck: @Sendable () -> Bool = { cancelled.value }
            let stream: AsyncStream<Result<[ListedDirectoryEntry], Error>>
            if access is DirectMediumAccess {
                stream = counting
                    ? BulkDirectoryReader.chunkedStream(at: url, mode: .nameAndTypeOnly, chunkSize: chunkSize, isCancelled: cancelCheck)
                    : BulkDirectoryReader.chunkedStream(at: url, mode: .fullMetadata, chunkSize: chunkSize, isCancelled: cancelCheck)
            } else {
                stream = counting
                    ? access.listDirectoryCountChunks(at: url, chunkSize: chunkSize)
                    : access.listDirectoryChunks(at: url, chunkSize: chunkSize)
            }
            Task {
                var lastLifeSign = ContinuousClock.now
                let watchdog = Task {
                    while !cancelled.value {
                        try await Task.sleep(for: DirectoryIndexer.stallWatchdogTick)
                        let now = ContinuousClock.now
                        if lastLifeSign.duration(to: now) > .seconds(limits.directoryStallTimeout) {
                            continuation.finish(throwing: DirectoryReadStalled())
                            return
                        }
                    }
                }
                defer { watchdog.cancel() }
                for await result in stream {
                    if cancelled.value {
                        continuation.finish(throwing: CancellationError())
                        return
                    }
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
    ) async throws -> [(id: Int64?, path: String?)] {
        if depth == 1 {
            return [(id: nil, path: nil)]
        }
        var result: [(id: Int64?, path: String?)] = []
        var offset = 0
        while true {
            let page = try await store.folders(mediumUUID: mediumUUID, depth: depth - 1, offset: offset)
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
        var fileIDCounts: [Int64: Int] = [:]
        for entry in listed {
            if let id = entry.fileID { fileIDCounts[id, default: 0] += 1 }
        }
        return listed.compactMap { entry in
            if matcher.shouldSkip(name: entry.name, isHidden: entry.isHidden, parentPath: parentPath) { return nil }
            let asFile = entry.isSymbolicLink || entry.isPackage || !entry.isDirectory
            let duplicateFileID = entry.fileID.map { fileIDCounts[$0, default: 0] > 1 } ?? false
            return ScannedEntry(
                name: entry.name,
                isFolder: !asFile,
                isPackage: entry.isPackage && !entry.isSymbolicLink,
                sizeBytes: asFile && !entry.isPackage && !entry.isSymbolicLink ? entry.fileSize : nil,
                modifiedAt: entry.modifiedAt,
                fileID: FileIdentity.scannedFileID(entry.fileID),
                linkCount: duplicateFileID ? 2 : entry.linkCount
            )
        }
    }
}
