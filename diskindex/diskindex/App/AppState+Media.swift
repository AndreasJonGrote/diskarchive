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

    /// Ab so vielen Zielen auf einmal fragt „Ignorieren“ im Kontextmenü vorher nach (todo.0.4.031).
    static let ignoreConfirmationThreshold = 500

    /// Kontextmenü „Ignorieren“: unter der Schwelle sofort; ab 500 Zielen erst nach Rückfrage. Aufheben (alle schon
    /// ignoriert) fragt nicht nach.
    func requestIgnore(_ patterns: [String], targetCount: Int) {
        let removes = !patterns.isEmpty && Set(patterns).isSubset(of: Set(appSettings.excludedPatterns))
        guard targetCount >= Self.ignoreConfirmationThreshold, !removes else {
            toggleIgnoredPatterns(patterns)
            return
        }
        DiskIndexLog.shared.ui("ignore confirm count=\(targetCount)")
        ignoreConfirmationPrompt = IgnoreConfirmationPrompt(count: targetCount, patterns: patterns)
        if let placement = promptPanelPlacement {
            AppWindowPresenter.openIgnoreConfirmation(appState: self, placement: placement)
        }
    }

    /// „Ignorieren“ wendet an, „Abbrechen“/Esc ändert nichts.
    func resolveIgnoreConfirmation(confirm: Bool) {
        guard let prompt = ignoreConfirmationPrompt else { return }
        ignoreConfirmationPrompt = nil
        DiskIndexLog.shared.ui("ignore confirm ok=\(confirm)")
        if confirm {
            toggleIgnoredPatterns(prompt.patterns)
        }
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
        if persist, !featureAccess.canWriteIndex { return }
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
            let decisionChanged = before.decision != after.decision || before.allowIndexing != after.allowIndexing
            if decisionChanged {
                // bug.0.4.043: Entscheidung sofort schreiben (kein 500-ms-Fenster gegen reloadMedium).
                userDecisionIDs[id, default: 0] += 1
                pendingMediumWrites[id]?.cancel()
                pendingMediumWrites[id] = Task { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    await self.writeMedium(id)
                    self.pendingMediumWrites[id] = nil
                }
                // todo.0.4.026: in 05/06 entschieden → ein noch offener Erkennungs-Dialog ist beantwortet.
                completeNewMediumDecision(id)
                onMediumDecisionChanged?(id, after.decision, after.allowIndexing)
            } else {
                scheduleMediumWrite(id)
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
        guard featureAccess.canWriteIndex else { return false }
        if reindexRequested.contains(id) { return false }
        guard let medium = medium(with: id) else { return false }
        guard medium.decision == .index else { return false }
        // bug.0.4.129: nur angeschlossen und nicht pausiert (sonst startet kein Lauf und die Sperre bliebe stehen).
        guard medium.connectionStatus == .connected else { return false }
        if globalAutoIndexPaused || heldForSleep || medium.autoIndexPaused { return false }
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
        // bug.0.4.221: jedes Anschließen zählt (Konzept `medien.md` 3) – auch für eine schon wartende ID ist der Merker
        // „weggeklickt“ weg, sonst bleibt der Dialog nach dem Wiedereinstecken aus.
        dismissedNewMediumPanelIDs.remove(id)
        guard !pendingNewMediumDecisionIDs.contains(id) else { return }
        pendingNewMediumDecisionIDs.append(id)
    }

    /// Erkennungs-Dialog für dieses Medium zeigen: in der Warteschlange und verbunden. Die Warteschlange enthält
    /// unentschiedene Medien und entschiedene ohne „Für dieses Medium merken“ (todo.0.4.026, erneut gefragt); eine
    /// Änderung in 05/06 nimmt das Medium heraus (`updateMedium(persist:)`).
    func needsNewMediumDialog(_ id: UUID) -> Bool {
        guard pendingNewMediumDecisionIDs.contains(id), let medium = medium(with: id) else { return false }
        return medium.connectionStatus == .connected && medium.decision != .ignore
    }

    func completeNewMediumDecision(_ id: UUID) {
        pendingNewMediumDecisionIDs.removeAll { $0 == id }
    }

    func clearNewMediumDecisionQueue() {
        pendingNewMediumDecisionIDs.removeAll()
    }

    /// bug.0.4.215: neues Medium, genau ein Offline-Medium gleichen Namens → zuerst und allein die Rückfrage (vor dem
    /// Erkennungs-Dialog). Mehrere Treffer oder schon eine offene Rückfrage: keine. Nie automatisch vergessen.
    /// Nicht mitgezählt: mit „Behalten“ beantwortete Paare (bug.0.4.232) und gerade eingehängte Medien (`mountedIDs`,
    /// bug.0.4.233).
    @discardableResult
    func offerReplaceMediumPrompt(newID: UUID, mountedIDs: Set<UUID> = []) -> Bool {
        // Schon gefragt (z. B. umgesteckt, während die Rückfrage offen ist): kein zweiter Dialog daneben.
        if replaceMediumPrompt?.newID == newID { return true }
        guard replaceMediumPrompt == nil, let newMedium = medium(with: newID) else { return false }
        let offlineNamesakes = media.filter {
            $0.id != newID && !$0.isForgotten && $0.connectionStatus == .offline && $0.name == newMedium.name
                && !mountedIDs.contains($0.id) && !isReplaceKept(newID: newID, oldID: $0.id)
        }
        guard offlineNamesakes.count == 1, let old = offlineNamesakes.first else { return false }
        DiskIndexLog.shared.ui("replace prompt new=\(newID) old=\(old.id)")
        replaceMediumPrompt = ReplaceMediumPrompt(newID: newID, oldID: old.id, name: newMedium.name)
        if let placement = promptPanelPlacement {
            AppWindowPresenter.openReplaceMediumPrompt(appState: self, placement: placement)
        }
        return true
    }

    /// „Altes vergessen“ geht über den bestehenden Vergessen-Weg; „Behalten“ ändert nichts. Mit Coordinator übernimmt das
    /// neue Medium die Entscheidung des alten, und der Erkennungs-Dialog folgt, wo er nötig ist (bug.0.4.215).
    func resolveReplaceMediumPrompt(forgetOld: Bool) {
        guard let prompt = replaceMediumPrompt else { return }
        replaceMediumPrompt = nil
        DiskIndexLog.shared.ui("replace prompt forgetOld=\(forgetOld)")
        if !forgetOld { rememberReplaceKept(newID: prompt.newID, oldID: prompt.oldID) }
        if let onReplaceMediumResolved {
            onReplaceMediumResolved(prompt, forgetOld)
            return
        }
        if forgetOld {
            forgetMedium(id: prompt.oldID)
        }
    }

    /// bug.0.4.232: „Behalten“ gilt dauerhaft für das Paar (neues, altes Medium), im App-Zustand (überlebt den Neustart).
    private static let keptReplacePairsKey = "keptReplaceMediumPairs"

    func isReplaceKept(newID: UUID, oldID: UUID) -> Bool {
        keptReplacePairs().contains(Self.replacePairKey(newID: newID, oldID: oldID))
    }

    private func rememberReplaceKept(newID: UUID, oldID: UUID) {
        var pairs = keptReplacePairs()
        pairs.insert(Self.replacePairKey(newID: newID, oldID: oldID))
        guard let data = try? JSONEncoder().encode(pairs.sorted()) else { return }
        settingsDefaults.set(data, forKey: Self.keptReplacePairsKey)
    }

    private func keptReplacePairs() -> Set<String> {
        guard let data = settingsDefaults.data(forKey: Self.keptReplacePairsKey),
              let pairs = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(pairs)
    }

    private static func replacePairKey(newID: UUID, oldID: UUID) -> String {
        "\(newID.uuidString) \(oldID.uuidString)"
    }

    func forgetMedium(id: UUID) {
        guard featureAccess.canWriteIndex else { return }
        DiskIndexLog.shared.ui("forget id=\(id)")
        completeNewMediumDecision(id)
        pendingMediumWrites[id]?.cancel()
        pendingMediumWrites[id] = nil
        userDecisionIDs[id] = nil
        media.removeAll { $0.id == id }
        if detailMediumID == id { detailMediumID = nil }
        if columnBrowserState.selectedMediumID == id {
            // bug.0.4.135: kein alter Pfad und keine alte Auswahl im nächsten Medium.
            columnBrowserState.selectedMediumID = nil
            columnBrowserState.pathStack = []
            columnBrowserState.selection = ColumnSelection()
            columnBrowserState.selectedUncapturedFolderID = nil
        }
        let store = indexStore
        Task {
            await onMediaForgotten?([id])
            do {
                try await store?.deleteMedium(uuid: id)
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { return }
                DiskIndexLog.shared.record(.store, .error, "deleteMedium \(DiskIndexLog.errorSummary(error))")
            }
        }
    }

    func forgetAllMedia() {
        guard featureAccess.canWriteIndex else { return }
        let ids = registryMedia.map(\.id)
        DiskIndexLog.shared.record(.store, .info, "forget all count=\(ids.count)")
        pendingMediumWrites.values.forEach { $0.cancel() }
        pendingMediumWrites.removeAll()
        userDecisionIDs.removeAll()
        media.removeAll()
        favoriteObjects = []
        // bug.0.4.040: Zahlen und Menge der Favoriten mit leeren (alle Medien vergessen).
        favoriteItemCount = 0
        favoriteUnfilteredCount = 0
        favoriteRowIDs = []
        cancelPopoverSearch()
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
            // bug.0.4.224: alle in einer kurzen Transaktion markieren, erst danach die Einträge löschen – sonst blieben
            // beim Beenden während des ersten großen Mediums auch alle folgenden registriert.
            do {
                try await store?.deleteMedia(uuids: ids)
            } catch {
                guard DiskIndexLog.isOperationalFailure(error) else { return }
                DiskIndexLog.shared.record(.store, .error, "deleteMedium \(DiskIndexLog.errorSummary(error))")
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

    /// bug.0.4.135: ohne gewähltes Medium das erste nehmen (früher `onAppear` der Spaltenansicht).
    func ensureColumnBrowserSelection() {
        if columnBrowserState.selectedMediumID == nil {
            columnBrowserState.selectedMediumID = columnBrowserMedia.first?.id
        }
    }

    /// bug.0.4.135: keinen Pfad jenseits der Scan-Tiefe offen lassen (früher `onAppear`; Inhalt der letzten Ebene
    /// bleibt sichtbar, inkl. Hinweisfläche „Inhalt wird nicht indiziert“).
    func clampColumnPathToScanDepth() {
        let selected = columnBrowserState.selectedMediumID
        guard let medium = columnBrowserMedia.first(where: { $0.id == selected && !$0.isForgotten }) ?? columnBrowserMedia.first
        else { return }
        let limit = appSettings.indexedMaxDepth.map { min(medium.completedDepth, $0) } ?? medium.completedDepth
        guard columnBrowserState.pathStack.count > max(0, limit) else { return }
        columnBrowserState.pathStack = Array(columnBrowserState.pathStack.prefix(max(0, limit)))
        columnBrowserState.selection = ColumnSelection()
        columnBrowserState.selectedUncapturedFolderID = nil
    }

    func loadStoredMedia() async {
        guard let indexStore else { return }
        let stored: [StoredMedium]
        do {
            stored = try await indexStore.media()
        } catch {
            guard DiskIndexLog.isOperationalFailure(error) else { return }
            DiskIndexLog.shared.record(.store, .error, "media \(DiskIndexLog.errorSummary(error))")
            return
        }
        let connections = Dictionary(media.map { ($0.id, $0.connectionStatus) }, uniquingKeysWith: { first, _ in first })
        let progress = Dictionary(media.map { ($0.id, $0.indexingProgress) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<UUID>()
        media = stored.compactMap { row in
            guard seen.insert(row.uuid).inserted else { return nil }
            var medium = row.asMedium(connection: connections[row.uuid] ?? .offline)
            if menuBarIndexingSpinnerIDs.contains(medium.id) {
                medium.indexStatus = .indexing
            }
            if medium.indexStatus == .indexing, let kept = progress[medium.id] {
                medium.indexingProgress = kept
            }
            return medium
        }
    }

}

/// Hält die Fortschrittsanzeige mindestens `minimumDuration` und danach `holdAtFull` bei 100 % – nur für einen Lauf, der
/// mit „indiziert“ endet (bug.0.4.210); Abbruch, Pause, Offline und Fehler zeigen sofort den gespeicherten Stand.
final class IndexProgressDisplay {
    static let minimumDuration: TimeInterval = 0.6
    static let holdAtFull: TimeInterval = 0.3

    struct Run {
        var startedAt: Date
        var real: Double
        /// bug.0.4.210: erster Wert des Laufs (gespeicherter Stand beim Fortsetzen) – die Rampe beginnt hier, nicht bei 0.
        var floor: Double
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
                runs[id] = Run(startedAt: now, real: min(fraction, 0.99), floor: min(fraction, 0.99), endedAt: nil)
            }
        } else if var run = runs[id], run.endedAt == nil {
            guard status == .indexed else {
                runs[id] = nil
                return
            }
            run.endedAt = now
            run.real = 1
            runs[id] = run
        }
    }

    func displayed(id: UUID, indexing: Bool, fallback: Double, now: Date) -> Double? {
        guard let run = runs[id] else {
            return indexing ? fallback : nil
        }
        let clock = max(run.floor, min(1, max(0, now.timeIntervalSince(run.startedAt) / Self.minimumDuration)))
        guard let expiresAt = run.expiresAt else { return min(run.real, clock) }
        if clock < 1 { return clock }
        return now < expiresAt ? 1 : nil
    }
}
