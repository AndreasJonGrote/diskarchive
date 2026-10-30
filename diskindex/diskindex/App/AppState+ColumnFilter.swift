//
//  AppState+ColumnFilter.swift
//  diskindex
//
//  todo.0.4.2.003 (Konzept `suche-navigation.md` 5): Filter in der Spaltenansicht. Ordner ohne Treffer darunter werden
//  leise; dauert die Rechnung länger als 1 s, steht ein Wartescreen. Ein neuer Schlüssel bricht die laufende Rechnung
//  ab (kein spätes Ergebnis des alten Filters); Änderungen am Index rechnen leise nach, höchstens alle 2 s.
//

import Foundation

extension AppState {
    static let columnFilterLiveInterval: Duration = .seconds(2)

    /// Treffermenge für `key`, sonst `nil` (alle Ordner normal: kein Filter, noch nicht gerechnet, anderer Filter).
    func columnFilterFolderHits(for key: ColumnFilterKey?) -> Set<Int64>? {
        guard let key, let hits = columnFilterHits, hits.key == key else { return nil }
        return hits.folderIDs
    }

    /// Aus der Spaltenansicht (`task(id:)`): ein neuer Schlüssel bricht die vorige Rechnung ab.
    func updateColumnFilterHits(for key: ColumnFilterKey?) async {
        columnFilterLiveTask?.cancel()
        columnFilterLiveTask = nil
        columnFilterLiveDirty = false
        columnFilterRun &+= 1
        let run = columnFilterRun
        guard let key else {
            columnFilterHits = nil
            hideColumnFilterWait()
            return
        }
        if columnFilterHits?.key == key {
            hideColumnFilterWait()
            return
        }
        let timing = columnFilterTiming
        let waiter = Task { [weak self] in
            try? await Task.sleep(for: timing.delayBeforeHint)
            guard !Task.isCancelled, let self, self.columnFilterRun == run, !self.columnFilterWaitVisible else { return }
            self.columnFilterWaitVisible = true
            self.columnFilterWaitShownAt = .now
        }
        let ids = await loadColumnFilterHits(key)
        waiter.cancel()
        guard !Task.isCancelled, columnFilterRun == run else { return }
        guard let ids else {
            hideColumnFilterWait()
            return
        }
        if columnFilterWaitVisible, let shownAt = columnFilterWaitShownAt {
            let rest = timing.minimumHintVisible - shownAt.duration(to: .now)
            if rest > .zero { try? await Task.sleep(for: rest) }
            guard !Task.isCancelled, columnFilterRun == run else { return }
        }
        // In einem Schritt: leise Ordner erscheinen, der Wartescreen geht (kein Flackern).
        columnFilterHits = ColumnFilterHits(key: key, folderIDs: ids)
        hideColumnFilterWait()
    }

    /// „Filter zurücksetzen“ (Wartescreen, leiser Ordner): alle Objekt-Filter weg, Rechnung ab; der geöffnete Pfad bleibt.
    func resetColumnObjectFilters() {
        var filters = searchState.filters
        filters.fileTypes = []
        filters.customExtensions = []
        filters.age = nil
        filters.combineWithAnd = false
        searchState.filters = filters
        columnFilterRun &+= 1
        columnFilterLiveTask?.cancel()
        columnFilterLiveTask = nil
        columnFilterHits = nil
        hideColumnFilterWait()
    }

    /// Index des Mediums geändert (Live, Abgleich, Indizieren): bei aktivem Filter im Hintergrund neu rechnen, höchstens
    /// alle 2 s. Der alte Stand bleibt bis zum neuen Ergebnis, kein Wartescreen.
    func columnFilterIndexChanged(_ mediumID: UUID) {
        guard let hits = columnFilterHits, hits.key.mediumID == mediumID else { return }
        guard columnFilterLiveTask == nil else {
            columnFilterLiveDirty = true
            return
        }
        let key = hits.key
        let run = columnFilterRun
        let wait = columnFilterLastLiveRun.map { Self.columnFilterLiveInterval - $0.duration(to: .now) } ?? .zero
        columnFilterLiveTask = Task { [weak self] in
            if wait > .zero { try? await Task.sleep(for: wait) }
            guard let self, !Task.isCancelled else { return }
            self.columnFilterLastLiveRun = .now
            let ids = await self.loadColumnFilterHits(key)
            guard !Task.isCancelled, self.columnFilterRun == run else { return }
            self.columnFilterLiveTask = nil
            if let ids, self.columnFilterHits?.key == key {
                self.columnFilterHits = ColumnFilterHits(key: key, folderIDs: ids)
            }
            if self.columnFilterLiveDirty {
                self.columnFilterLiveDirty = false
                self.columnFilterIndexChanged(mediumID)
            }
        }
    }

    private func hideColumnFilterWait() {
        if columnFilterWaitVisible { columnFilterWaitVisible = false }
        columnFilterWaitShownAt = nil
    }

    private func loadColumnFilterHits(_ key: ColumnFilterKey) async -> Set<Int64>? {
        guard !Task.isCancelled, let store = indexStore else { return nil }
        do {
            let ids = try await store.folderIDsWithHits(
                mediumUUID: key.mediumID,
                filters: key.filters,
                maxDepth: appSettings.indexedMaxDepth,
                scope: indexScope
            )
            #if DEBUG
            await columnFilterComputeHookForTesting?(key)
            #endif
            return ids
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "columnFilterHits \(DiskIndexLog.errorSummary(error))")
            }
            return nil
        }
    }
}
