//
//  SearchIndex.swift
//  diskindex
//
//  Suche über den (Mock-)Index — gemeinsam für Suchansicht, Popover und Favoriten.
//

import Foundation

/// Objekt aus dem Index samt Medium (Such- und Favoriten-Tabellen).
struct SearchResultItem: Identifiable, Hashable {
    let item: IndexedItem
    let mediumID: UUID
    let isOnline: Bool

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
}

struct SearchMatch {
    var media: [Medium] = []
    var items: [SearchResultItem] = []
    /// Trefferzahl aus der Zählabfrage, nicht die Länge der angezeigten Seite. `nil` = wird noch gezählt (Anzeige „–“).
    var itemCount: Int? = 0
    var unfilteredItemCount: Int? = 0

    var totalCount: Int { media.count + (itemCount ?? items.count) }
    var isEmpty: Bool { totalCount == 0 }
}

enum SearchIndex {
    static let pageLimit = 500

    static func matching(
        store: IndexStore?,
        query: String,
        filters: SearchFilters,
        media: [Medium],
        maxDepth: Int?,
        scope: IndexScope? = nil,
        withCount: Bool = true
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
                let rows = try await store.search(query: query, filters: scoped, limit: pageLimit, maxDepth: maxDepth, scope: scope)
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

        let online = Dictionary(media.map { ($0.id, $0.connectionStatus == .connected) }, uniquingKeysWith: { first, _ in first })
        let items = stored.map { row in
            SearchResultItem(
                item: IndexedItem(stored: row),
                mediumID: row.mediumUUID,
                isOnline: online[row.mediumUUID] ?? false
            )
        }

        let matchedMedia: [Medium]
        if query.isEmpty {
            let mediumIDsWithItems = Set(items.map(\.mediumID))
            matchedMedia = media.filter { mediumIDsWithItems.contains($0.id) && SearchItemFilter.matchesMedium($0, filters: filters) }
        } else {
            matchedMedia = media.filter {
                SearchItemFilter.matchesMedium($0, filters: filters) && $0.name.localizedCaseInsensitiveContains(query)
            }
        }
        return SearchMatch(media: matchedMedia, items: items, itemCount: itemCount)
    }

    /// Trefferzahl allein — wird nach der Ergebnisliste nachgereicht.
    static func count(
        store: IndexStore?,
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

    static func unfilteredItemCount(store: IndexStore?, query: String, media: [Medium], maxDepth: Int?, scope: IndexScope? = nil) async -> Int {
        guard let store else { return 0 }
        var filters = SearchFilters()
        filters.selectAllMedia = false
        filters.mediumIDs = Set(media.map(\.id))
        return (try? await store.searchCount(query: query, filters: filters, maxDepth: maxDepth, scope: scope)) ?? 0
    }

    static func favoriteObjects(store: IndexStore?, media: [Medium], maxDepth: Int?, scope: IndexScope? = nil) async -> [SearchResultItem] {
        guard let store else { return [] }
        let started = ContinuousClock.now
        let rows: [StoredItem]
        do {
            rows = try await store.favorites(maxDepth: maxDepth, scope: scope)
        } catch {
            if DiskIndexLog.isOperationalFailure(error) {
                DiskIndexLog.shared.record(.index, .error, "favorites \(error)")
            }
            rows = []
        }
        DiskIndexLog.shared.perfIfSlow("favorites", since: started)
        let known = Dictionary(media.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<UUID>()
        return rows.compactMap { row in
            guard let medium = known[row.mediumUUID] else { return nil }
            let item = IndexedItem(stored: row)
            guard seen.insert(item.id).inserted else { return nil }
            return SearchResultItem(
                item: item,
                mediumID: row.mediumUUID,
                isOnline: medium.connectionStatus == .connected
            )
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
