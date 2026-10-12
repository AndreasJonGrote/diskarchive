//
//  AppState+Media.swift
//  diskindex
//
//  Aus AppState.swift aufgeteilt (Aufgabe 111). Keine Logikänderung.
//

import SwiftUI

extension AppState {
    // MARK: - Ignorieren (Einstellungen → Ignorierte Objekte)

    func isIgnoredPattern(_ pattern: String) -> Bool {
        appSettings.excludedPatterns.contains(pattern)
    }

    func toggleIgnoredPattern(_ pattern: String) {
        toggleIgnoredPatterns([pattern])
    }

    func toggleIgnoredPatterns(_ patterns: [String]) {
        appSettings.excludedPatterns = IgnoreBatch.applying(patterns, to: appSettings.excludedPatterns)
    }

    /// `.pdf` / `pdf` / `*.pdf` → `*.pdf`
    nonisolated static func ignorePattern(forExtension ext: String) -> String {
        if ext.hasPrefix("*") { return ext }
        if ext.hasPrefix(".") { return "*\(ext)" }
        return "*.\(ext)"
    }

    // MARK: - Medien

    func medium(with id: UUID) -> Medium? {
        media.first { $0.id == id }
    }

    func updateMedium(id: UUID, persist: Bool = false, _ change: (inout Medium) -> Void) {
        guard let index = media.firstIndex(where: { $0.id == id }) else { return }
        let before = media[index]
        change(&media[index])
        let after = media[index]
        if after.indexStatus == .indexing {
            reindexRequested.remove(id)
        }
        if after.lastIndexedAt != before.lastIndexedAt
            || (before.indexStatus == .indexing && after.indexStatus != .indexing) {
            armReindexGate(id)
        }
        if persist {
            scheduleMediumWrite(id)
            if before.decision != after.decision || before.allowIndexing != after.allowIndexing {
                onMediumDecisionChanged?(id, after.decision, after.allowIndexing)
            }
        }
        noteIndexSample(id: id, status: after.indexStatus, fraction: after.indexProgressFraction, now: Date())
    }

    func noteIndexSample(id: UUID, status: IndexStatus, fraction: Double, now: Date) {
        indexProgressDisplay.note(id: id, status: status, fraction: fraction, now: now)
    }

    /// Anzeige 0…1 während eines Laufs, `nil` = Endzustand.
    func displayedProgress(_ id: UUID, now: Date = Date()) -> Double? {
        let current = medium(with: id)
        return indexProgressDisplay.displayed(
            id: id,
            indexing: current?.indexStatus == .indexing,
            fallback: current?.indexProgressFraction ?? 0,
            now: now
        )
    }

    func hasLiveProgress(_ id: UUID) -> Bool {
        indexProgressDisplay.runs[id] != nil
    }

    /// Falsch, solange ein Klick schon zählt, ein Lauf läuft oder das letzte Ende keine 59 s her ist.
    func canReindex(_ id: UUID, now: Date = Date()) -> Bool {
        if reindexRequested.contains(id) { return false }
        guard let medium = medium(with: id) else { return false }
        guard medium.decision == .index else { return false }
        if medium.indexStatus == .indexing { return false }
        if let end = medium.lastIndexedAt, now < end.addingTimeInterval(59) { return false }
        return true
    }

    func armReindexGate(_ id: UUID) {
        reindexGateTasks[id]?.cancel()
        reindexGateTasks[id] = nil
        guard let end = medium(with: id)?.lastIndexedAt else { return }
        let delay = end.addingTimeInterval(59).timeIntervalSinceNow
        guard delay > 0 else { return }
        reindexGateTasks[id] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000) + 20_000_000)
            guard !Task.isCancelled else { return }
            reindexGateTick = Date()
        }
    }

    /// Startet eine neue Indizierung. Ohne Dienst nur die Oberfläche (Testdaten).
    func reindexMedium(id: UUID) {
        guard canReindex(id) else { return }
        reindexRequested.insert(id)
        DiskIndexLog.shared.ui("reindex id=\(id)")
        if let onReindexMedium {
            onReindexMedium(id)
            return
        }
        updateMedium(id: id) {
            $0.indexStatus = .indexing
            $0.indexingProgress = 0
        }
    }

    func enqueueNewMediumDecision(_ id: UUID) {
        guard !pendingNewMediumDecisionIDs.contains(id) else { return }
        pendingNewMediumDecisionIDs.append(id)
        dismissedNewMediumPanelIDs.remove(id)
    }

    func completeNewMediumDecision(_ id: UUID) {
        pendingNewMediumDecisionIDs.removeAll { $0 == id }
    }

    func clearNewMediumDecisionQueue() {
        pendingNewMediumDecisionIDs.removeAll()
    }

    func forgetMedium(id: UUID) {
        DiskIndexLog.shared.ui("forget id=\(id)")
        completeNewMediumDecision(id)
        pendingMediumWrites[id]?.cancel()
        pendingMediumWrites[id] = nil
        media.removeAll { $0.id == id }
        if detailMediumID == id { detailMediumID = nil }
        if columnBrowserState.selectedMediumID == id { columnBrowserState.selectedMediumID = nil }
        let store = indexStore
        Task {
            await onMediaForgotten?([id])
            do {
                try await store?.deleteMedium(uuid: id)
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { return }
                DiskIndexLog.shared.record(.store, .error, "deleteMedium \(error)")
            }
        }
    }

    func forgetAllMedia() {
        let ids = registryMedia.map(\.id)
        DiskIndexLog.shared.record(.store, .info, "forget all count=\(ids.count)")
        pendingMediumWrites.values.forEach { $0.cancel() }
        pendingMediumWrites.removeAll()
        media.removeAll()
        favoriteObjects = []
        popoverResults = PopoverSearchResults()
        searchMatch = SearchMatch()
        searchState.submittedQuery = ""
        detailMediumID = nil
        clearNewMediumDecisionQueue()
        columnBrowserState = ColumnBrowserState()
        indexRepository.invalidateAll()
        indexingFailure = nil
        let store = indexStore
        Task {
            await onMediaForgotten?(ids)
            // Ein Löschlauf; `deleteMedium` ist idempotent (kein Doppel-Log bei schon gelöscht).
            for id in ids {
                do {
                    try await store?.deleteMedium(uuid: id)
                } catch {
                    guard DiskIndexLog.isOperationalFailure(error) else { continue }
                    DiskIndexLog.shared.record(.store, .error, "deleteMedium \(error)")
                }
            }
        }
        SystemNotice.post(body: LayoutCopy.noticeForgetAll, settings: appSettings)
    }

    func applyFactoryDefaults() {
        appSettings.resetGeneral()
        appSettings.resetIgnoredObjects()
        appSettings.appearance = .system
        appSettings.notificationsEnabled = true
        appSettings.notifySystem = true
        appSettings.notifyIndexed = true
        appSettings.notifyFavorites = true
        appSettings.appearance.apply()
        setAutoSendCrashReports(false)
        SystemNotice.post(body: LayoutCopy.noticeDefaultsApplied, settings: appSettings)
    }

    func reportIndexStoreOpenFailure() {
        indexStoreOpenFailed = true
        storeReady = false
        indexStoreOpenFailureAlert = true
    }

    func clearIndexStoreOpenFailure() {
        indexStoreOpenFailed = false
        indexStoreOpenFailureAlert = false
    }

    /// Menüleisten-Status-Badge (Mockup Sektion 01 / Aufgabe 19.3).
    /// Priorität: Index nicht offen → Fehler → Neu erkannt (Dialog) → Wird indiziert → Pausiert → kein Badge.
    var effectiveMenuBarBadge: MenuBarBadgePreview {
        if indexStoreOpenFailed {
            return .error
        }
        let active = registryMedia

        if active.contains(where: { $0.connectionStatus == .connected && $0.indexStatus == .error }) {
            return .error
        }
        if hasPendingNewMediumDecisions {
            return .newlyDetected
        }
        if globalAutoIndexPaused {
            return .paused
        }
        if active.contains(where: { $0.connectionStatus == .connected && menuBarIndexingSpinnerIDs.contains($0.id) }) {
            return .indexing
        }
        return .idle
    }

    func noteMenuBarIndexingSpinner(_ id: UUID, active: Bool) {
        if active {
            menuBarIndexingSpinnerIDs.insert(id)
        } else {
            menuBarIndexingSpinnerIDs.remove(id)
        }
    }

    func clearMenuBarRunIndicators(_ id: UUID) {
        menuBarIndexingSpinnerIDs.remove(id)
    }

    var connectedMedia: [Medium] {
        media.filter { $0.connectionStatus == .connected && !$0.isForgotten }
    }

    var registryMedia: [Medium] {
        media.filter { !$0.isForgotten }
    }

    /// Dashboard, Seitenleiste, Suche, Favoriten.
    var indexedMedia: [Medium] {
        registryMedia.filter(\.isBrowsable)
    }

    /// Nur die Spaltenansicht.
    var columnBrowserMedia: [Medium] {
        indexedMedia
    }

    func loadStoredMedia() async {
        guard let indexStore else { return }
        let stored: [StoredMedium]
        do {
            stored = try await indexStore.media()
        } catch {
            guard DiskIndexLog.isOperationalFailure(error) else { return }
            DiskIndexLog.shared.record(.store, .error, "media \(error)")
            return
        }
        let connections = Dictionary(media.map { ($0.id, $0.connectionStatus) }, uniquingKeysWith: { first, _ in first })
        let progress = Dictionary(media.map { ($0.id, $0.indexingProgress) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<UUID>()
        media = stored.compactMap { row in
            guard seen.insert(row.uuid).inserted else { return nil }
            var medium = row.asMedium(connection: connections[row.uuid] ?? .offline)
            if medium.indexStatus == .indexing, let kept = progress[medium.id] {
                medium.indexingProgress = kept
            }
            return medium
        }
        await normalizeInterruptedIndexingStatuses()
    }

    /// Nach Absturz/Beenden kann `indexStatus = indexing` in der DB stehen, obwohl kein Lauf läuft.
    func normalizeInterruptedIndexingStatuses() async {
        guard let indexStore else { return }
        mediumLiveSyncIDs.removeAll()
        var cleared = 0
        for index in media.indices {
            guard media[index].indexStatus == .indexing else { continue }
            let id = media[index].id
            let resolved: IndexStatus = media[index].lastIndexedAt != nil ? .indexed : .pending
            media[index].indexStatus = resolved
            cleared += 1
            do {
                guard var stored = try await indexStore.medium(uuid: id) else { continue }
                stored.indexStatus = StoredIndexStatus(rawValue: resolved.rawValue) ?? .pending
                try await indexStore.updateMedium(uuid: id, stored)
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { continue }
                DiskIndexLog.shared.record(.store, .error, "normalizeInterrupted \(error)")
            }
        }
        if cleared > 0 {
            DiskIndexLog.shared.record(.app, .info, "index status stale indexing cleared count=\(cleared)")
        }
    }

}

/// Hält die Fortschrittsanzeige mindestens `minimumDuration` und danach `holdAtFull` bei 100 %.
final class IndexProgressDisplay {
    static let minimumDuration: TimeInterval = 0.6
    static let holdAtFull: TimeInterval = 0.3

    struct Run {
        var startedAt: Date
        var real: Double
        var endedAt: Date?

        var expiresAt: Date? {
            endedAt.map { max(startedAt.addingTimeInterval(IndexProgressDisplay.minimumDuration), $0)
                .addingTimeInterval(IndexProgressDisplay.holdAtFull) }
        }
    }

    var runs: [UUID: Run] = [:]

    func note(id: UUID, status: IndexStatus, fraction: Double, now: Date) {
        runs = runs.filter { _, run in run.expiresAt.map { now < $0 } ?? true }
        if status == .indexing {
            if var run = runs[id], run.endedAt == nil {
                run.real = max(run.real, min(fraction, 0.99))
                runs[id] = run
            } else {
                runs[id] = Run(startedAt: now, real: min(fraction, 0.99), endedAt: nil)
            }
        } else if var run = runs[id], run.endedAt == nil {
            run.endedAt = now
            run.real = 1
            runs[id] = run
        }
    }

    func displayed(id: UUID, indexing: Bool, fallback: Double, now: Date) -> Double? {
        guard let run = runs[id] else {
            return indexing ? fallback : nil
        }
        let clock = min(1, max(0, now.timeIntervalSince(run.startedAt) / Self.minimumDuration))
        guard let expiresAt = run.expiresAt else { return min(run.real, clock) }
        if clock < 1 { return clock }
        return now < expiresAt ? 1 : nil
    }
}
