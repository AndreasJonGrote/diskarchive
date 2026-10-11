//
//  PopoverSearch.swift
//  diskindex
//
//  Menüleisten-Popover (Screen 03): Top-Treffer aus demselben Matching wie die Suchansicht.
//

import Foundation

struct PopoverSearchHit: Identifiable, Hashable {
    enum Kind {
        case medium
        case file
        case folder
    }

    let kind: Kind
    let title: String
    /// Medium-Name bei Dateien/Ordnern, sonst leer.
    let location: String
    let target: ObjectContextTarget
    /// Für „In Spaltenansicht öffnen“ bei Dateien/Ordnern.
    let result: SearchResultItem?

    var id: UUID { target.id }
}

struct PopoverSearchGroup: Identifiable {
    let title: String
    let hits: [PopoverSearchHit]

    var id: String { title }
}

struct PopoverSearchResults {
    var groups: [PopoverSearchGroup] = []
    /// Gesamtzahl wie in der Suchansicht (Medien + Objekte).
    var totalCount = 0
}

enum PopoverSearch {
    static let maxHitsPerGroup = 3

    static func results(query: String, appState: AppState) async -> PopoverSearchResults {
        let media = appState.indexedMedia
        let filters = appState.mainWindowDestination == .search ? appState.searchState.filters : SearchFilters()
        let match = await SearchIndex.matching(
            store: appState.indexStore,
            query: query,
            filters: filters,
            media: media,
            maxDepth: appState.appSettings.indexedMaxDepth,
            scope: appState.indexScope
        )
        return grouped(match: match, media: media)
    }

    static func grouped(match: SearchMatch, media: [Medium]) -> PopoverSearchResults {
        guard !match.isEmpty else { return PopoverSearchResults() }
        let mediumNames = Dictionary(media.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let mediumHits = match.media.prefix(maxHitsPerGroup).map { medium in
            PopoverSearchHit(kind: .medium, title: medium.name, location: "", target: .fromMedium(medium), result: nil)
        }
        func objectHits(folders: Bool) -> [PopoverSearchHit] {
            match.items
                .filter { $0.isFolder == folders }
                .prefix(maxHitsPerGroup)
                .map { result in
                    PopoverSearchHit(
                        kind: folders ? .folder : .file,
                        title: result.name,
                        location: mediumNames[result.mediumID] ?? "",
                        target: .fromSearchResult(result),
                        result: result
                    )
                }
        }
        let groups = [
            PopoverSearchGroup(title: "SPEICHERMEDIEN", hits: Array(mediumHits)),
            PopoverSearchGroup(title: "DATEIEN", hits: objectHits(folders: false)),
            PopoverSearchGroup(title: "ORDNER", hits: objectHits(folders: true)),
        ].filter { !$0.hits.isEmpty }
        return PopoverSearchResults(groups: groups, totalCount: match.totalCount)
    }
}
