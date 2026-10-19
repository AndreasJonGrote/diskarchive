//
//  SearchIndex.swift
//  diskindex
//
//  Suche über den (Mock-)Index — gemeinsam für Suchansicht, Popover und Favoriten.
//

import Foundation

/// Objekt aus dem Index samt Medium (Such- und Favoriten-Tabellen). Der Verbindungsstatus wird nicht gespeichert,
/// sondern beim Zeichnen und Filtern aus `AppState.mediumConnectivity` abgeleitet (bug.0.4.037, REPORT 82).
struct SearchResultItem: Identifiable, Hashable {
    var item: IndexedItem
    let mediumID: UUID

    var id: UUID { item.id }
    var name: String { item.name }
    var isFolder: Bool { item.isFolder }
    var date: Date? { item.modifiedAt }
    var pathFolderComponents: [String] { item.parentPath }

    /// Anzeige „/Ordner/Unterordner/“.
    var path: String {
        item.parentPath.isEmpty ? "/" : "/" + item.parentPath.joined(separator: "/") + "/"
    }
}

/// Anfrage, für die zuletzt gezählt wurde (gleiche Anfrage: Zahl bleibt beim Neustart stehen).
struct SearchCountRequest: Equatable {
    var query: String
    var filters: SearchFilters
    /// Reihenfolge der Seite; ändert die Trefferzahl nicht (bug.0.4.038: reiner Sortierklick zählt nicht neu).
    var sort = SearchSort()

    /// Gleiche Treffermenge (Begriff und Filter), Reihenfolge egal.
    func hasSameHits(as other: SearchCountRequest?) -> Bool {
        guard let other else { return false }
        return query == other.query && filters == other.filters
    }
}

struct SearchMatch {
    var media: [Medium] = []
    var items: [SearchResultItem] = []
    /// Trefferzahl aus der Zählabfrage, nicht die Länge der angezeigten Seite. `nil` = wird noch gezählt (Anzeige „–“).
    var itemCount: Int? = 0
    var unfilteredItemCount: Int? = 0

    var totalCount: Int { media.count + (itemCount ?? items.count) }
    var isEmpty: Bool { totalCount == 0 }

    /// Alle Treffer stehen auf der geladenen Seite: Pfad und Status lassen sich dann im Client sortieren (bug.0.4.038).
    var allItemsOnPage: Bool {
        if let itemCount { return itemCount <= SearchIndex.pageLimit }
        return items.count < SearchIndex.pageLimit
    }
}

enum SearchIndex {
    static let pageLimit = 500

    static func matching(
        store: IndexStoreV3?,
        query: String,
        filters: SearchFilters,
        media: [Medium],
        maxDepth: Int?,
        scope: IndexScope? = nil,
        withCount: Bool = true,
        sort: SearchSort = SearchSort()
    ) async -> SearchMatch {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty, !filters.hasActiveFilters {
            return SearchMatch()
        }

        let scoped = scopedFilters(filters, media: media)
        let started = ContinuousClock.now
        let stored: [StoredItem]
        var itemCount: Int?
        if let store {
            do {
                let rows = try await store.search(
                    query: query, filters: scoped, limit: pageLimit, maxDepth: maxDepth, scope: scope, sort: sort
                )
                let counted: Int?
                if withCount {
                    counted = try await store.searchCount(query: query, filters: scoped, maxDepth: maxDepth, scope: scope)
                } else {
                    // Zahl kommt später (`SearchIndex.count`); eine leere Seite heißt 0 Treffer.
                    counted = rows.isEmpty ? 0 : nil
                }
                stored = rows
                itemCount = counted
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.index, .error, "search \(error)")
                }
                stored = []
                itemCount = 0
            }
        } else {
            stored = []
            itemCount = 0
        }
        DiskIndexLog.shared.perfIfSlow("search", since: started)

        let items = stored.map { row in
            SearchResultItem(item: IndexedItem(stored: row), mediumID: row.mediumUUID)
        }

        // bug.0.4.092 (Nutzer 18.10.): Medien erscheinen nur als Namenstreffer eines Suchbegriffs. Eine reine
        // Filtersuche zeigt keine Kacheln („hier liegt etwas“ zeigt schon die Tabelle), gleich welcher Filter.
        let matchedMedia: [Medium] = query.isEmpty ? [] : media.filter {
            SearchItemFilter.matchesMedium($0, filters: filters) && $0.name.localizedCaseInsensitiveContains(query)
        }
        return SearchMatch(media: matchedMedia, items: items, itemCount: itemCount)
    }

    /// Popover (bug.0.4.038, REPORT 130): Dateien und Ordner je mit eigener kleiner Abfrage (`LIMIT perGroup`), damit
    /// eine Gruppe nicht fehlt, nur weil die andere die erste Seite füllt. Ohne Zählung (bug.0.4.039).
    static func popoverPage(
        store: IndexStoreV3?,
        query: String,
        filters: SearchFilters,
        media: [Medium],
        maxDepth: Int?,
        scope: IndexScope? = nil,
        perGroup: Int
    ) async -> (media: [Medium], files: [SearchResultItem], folders: [SearchResultItem]) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return ([], [], []) }
        let matchedMedia = media.filter {
            SearchItemFilter.matchesMedium($0, filters: filters) && $0.name.localizedCaseInsensitiveContains(query)
        }
        guard let store else { return (matchedMedia, [], []) }
        let scoped = scopedFilters(filters, media: media)
        let started = ContinuousClock.now
        let files: [StoredItem]
        let folders: [StoredItem]
        do {
            files = try await store.search(query: query, filters: scoped, limit: perGroup, maxDepth: maxDepth, scope: scope, isFolder: false)
            try Task.checkCancellation()
            folders = try await store.search(query: query, filters: scoped, limit: perGroup, maxDepth: maxDepth, scope: scope, isFolder: true)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "popover search \(error)")
            }
            return (matchedMedia, [], [])
        }
        DiskIndexLog.shared.perfIfSlow("popover search", since: started)
        func results(_ rows: [StoredItem]) -> [SearchResultItem] {
            rows.map { row in
                SearchResultItem(item: IndexedItem(stored: row), mediumID: row.mediumUUID)
            }
        }
        return (matchedMedia, results(files), results(folders))
    }

    /// Trefferzahl allein — wird nach der Ergebnisliste nachgereicht.
    static func count(
        store: IndexStoreV3?,
        query: String,
        filters: SearchFilters,
        media: [Medium],
        maxDepth: Int?,
        scope: IndexScope? = nil
    ) async -> Int {
        guard let store else { return 0 }
        let scoped = scopedFilters(filters, media: media)
        return (try? await store.searchCount(query: query, filters: scoped, maxDepth: maxDepth, scope: scope)) ?? 0
    }

    static func unfilteredItemCount(store: IndexStoreV3?, query: String, media: [Medium], maxDepth: Int?, scope: IndexScope? = nil) async -> Int {
        guard let store else { return 0 }
        var filters = SearchFilters()
        filters.selectAllMedia = false
        filters.mediumIDs = Set(media.map(\.id))
        return (try? await store.searchCount(query: query, filters: filters, maxDepth: maxDepth, scope: scope)) ?? 0
    }

    /// Erste Seite aller Favoriten ohne Filter (Verbindung „Alle“).
    static func favoriteObjects(store: IndexStoreV3?, media: [Medium], maxDepth: Int?, scope: IndexScope? = nil) async -> [SearchResultItem] {
        await favoritePage(
            store: store,
            request: FavoritesRequest(media: media, connection: .all, filters: SearchFilters(), maxDepth: maxDepth),
            scope: scope
        )
    }

    /// bug.0.4.040 (REPORT 86): eine Seite (`pageLimit`) Favoriten; Verbindungs-, Dateityp- und Altersfilter wirken in
    /// der Abfrage, damit die Seite nicht nur die ersten 500 gefiltert zeigt.
    static func favoritePage(store: IndexStoreV3?, request: FavoritesRequest, scope: IndexScope? = nil, limit: Int? = nil) async -> [SearchResultItem] {
        guard let store else { return [] }
        let started = ContinuousClock.now
        let rows: [StoredItem]
        do {
            rows = try await store.favoritePage(filters: request.storeFilters, limit: limit ?? pageLimit, maxDepth: request.maxDepth, scope: scope)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "favorites \(error)")
            }
            rows = []
        }
        DiskIndexLog.shared.perfIfSlow("favorites", since: started)
        var seen = Set<UUID>()
        return rows.compactMap { row in
            guard request.mediumIDs.contains(row.mediumUUID) else { return nil }
            let item = IndexedItem(stored: row)
            guard seen.insert(item.id).inserted else { return nil }
            return SearchResultItem(item: item, mediumID: row.mediumUUID)
        }
    }

    /// bug.0.4.040: Zahl der Favoriten zur Anfrage; `objectFilters: false` zählt ohne Dateityp und Alter (Gesamtzahl
    /// im Zähler „x von y“).
    static func favoriteCount(store: IndexStoreV3?, request: FavoritesRequest, objectFilters: Bool = true, scope: IndexScope? = nil) async -> Int {
        guard let store else { return 0 }
        let filters = objectFilters ? request.storeFilters : request.withoutObjectFilters.storeFilters
        do {
            return try await store.favoriteCount(filters: filters, maxDepth: request.maxDepth, scope: scope)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "favorite count \(error)")
            }
            return 0
        }
    }

    private static func scopedFilters(_ filters: SearchFilters, media: [Medium]) -> SearchFilters {
        var copy = filters
        let allowed = Set(media.map(\.id))
        if copy.selectAllMedia {
            copy.selectAllMedia = false
            copy.mediumIDs = allowed
        } else {
            copy.mediumIDs = copy.mediumIDs.intersection(allowed)
        }
        return copy
    }
}

enum SearchItemFilter {
    /// Dateityp-Gruppe (Kategorien + eigene Endungen, intern Oder) und Alter; untereinander Oder bzw. Und
    /// je nach Verknüpfungs-Button (Aufgabe 33). Suchbegriff und Medium werden von den Aufrufern immer per Und ergänzt.
    /// - Parameters:
    ///   - hasSearchTerm: In der Suche mit abgeschicktem Begriff ist „Und“ nicht wirksam (33.1).
    ///   - foldersIgnoreTypeFilter: Spaltenansicht mit „Ordner weiterhin anzeigen“ (33.5) — Ordner prüfen nur das Alter.
    static func matches(
        _ item: IndexedItem,
        filters: SearchFilters,
        hasSearchTerm: Bool = false,
        foldersIgnoreTypeFilter: Bool = false
    ) -> Bool {
        let hasType = filters.hasFileTypeFilter
        let hasAge = filters.age != nil

        // Unbekanntes Datum oder kein Alter-Filter schließt nicht aus.
        let ageOK: Bool = {
            guard let age = filters.age, let date = item.modifiedAt else { return true }
            return age.matches(date)
        }()

        if foldersIgnoreTypeFilter, item.isFolder {
            return ageOK
        }

        let typeOK: Bool = {
            guard hasType else { return true }
            let categoryOK = filters.fileTypes.contains {
                $0.matches(fileName: item.name, isFolder: item.isFolder, isPackage: item.isPackage)
            }
            let lowercasedName = item.name.lowercased()
            let extensionOK = !item.isFolder && filters.customExtensions.contains { lowercasedName.hasSuffix($0) }
            return categoryOK || extensionOK
        }()

        guard hasType || hasAge else { return true }
        if hasType, hasAge {
            return filters.effectiveCombineWithAnd(hasSearchTerm: hasSearchTerm) ? (typeOK && ageOK) : (typeOK || ageOK)
        }
        return hasType ? typeOK : ageOK
    }

    static func matchesMedium(_ medium: Medium, filters: SearchFilters) -> Bool {
        filters.selectAllMedia || filters.mediumIDs.contains(medium.id)
    }
}

/// Anfrage der Favoriten-Tabelle (bug.0.4.040): welche Medien (nach Verbindungsfilter), welche Objekt-Filter, Tiefe.
/// Gleiche Anfrage = gleiche Treffermenge; der Verbindungsstatus geht über `mediumIDs` ein, nicht über die Zeilen.
struct FavoritesRequest: Equatable {
    /// Durchsuchbare Medien, die zum Verbindungsfilter passen.
    var mediumIDs: Set<UUID>
    var filters: SearchFilters
    var maxDepth: Int?

    init(media: [Medium], connection: FavoritesConnectionFilter, filters: SearchFilters, maxDepth: Int?) {
        mediumIDs = Set(media.filter { connection.includes(isOnline: $0.connectionStatus == .connected) }.map(\.id))
        var objectFilters = SearchFilters()
        objectFilters.fileTypes = filters.fileTypes
        objectFilters.customExtensions = filters.customExtensions
        objectFilters.age = filters.age
        objectFilters.combineWithAnd = filters.combineWithAnd
        self.filters = objectFilters
        self.maxDepth = maxDepth
    }

    /// Medienauswahl der Favoriten kommt aus dem Verbindungsfilter, nicht aus der Filterleiste der Suche.
    var storeFilters: SearchFilters {
        var copy = filters
        copy.selectAllMedia = false
        copy.mediumIDs = mediumIDs
        return copy
    }

    var withoutObjectFilters: FavoritesRequest {
        var copy = self
        copy.filters = SearchFilters()
        return copy
    }
}

enum FavoritesConnectionFilter: String, CaseIterable, Identifiable {
    case all
    case online
    case offline

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: LayoutCopy.scopeAll
        case .online: LayoutCopy.chipOnline
        case .offline: LayoutCopy.chipOffline
        }
    }

    func includes(isOnline: Bool) -> Bool {
        switch self {
        case .all: true
        case .online: isOnline
        case .offline: !isOnline
        }
    }
}
