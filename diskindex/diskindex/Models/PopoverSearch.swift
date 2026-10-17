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
    /// Gesamtzahl wie in der Suchansicht (Medien + Objekte). Solange die Zählung läuft (`isCountPending`), steht hier
    /// die zuletzt bekannte Zahl der vorigen Eingabe (bug.0.4.039: die Zahl kommt getrennt und abbrechbar nach); ohne
    /// bekannte Zahl wird die Seite erst mit der Zahl gezeigt. Nie die Zahl der gezeigten Zeilen.
    var totalCount = 0
    var isCountPending = false
}

/// Eine Popover-Suche ohne Zählung: Medien nach Name, Dateien und Ordner je mit eigener kleiner Abfrage.
struct PopoverSearchPage {
    var results = PopoverSearchResults()
    /// Anfrage für die nachgereichte Zahl; `nil` = Zahl steht schon fest (jede Gruppe unter ihrer Grenze).
    var pendingCount: SearchCountRequest?
    var mediumCount = 0
}

enum PopoverSearch {
    static let maxHitsPerGroup = 3

    /// Filter der Hauptsuche nur, wenn die Suchansicht offen ist.
    static func filters(appState: AppState) -> SearchFilters {
        appState.mainWindowDestination == .search ? appState.searchState.filters : SearchFilters()
    }

    static func page(query: String, appState: AppState) async -> PopoverSearchPage {
        let media = appState.indexedMedia
        let filters = filters(appState: appState)
        let found = await SearchIndex.popoverPage(
            store: appState.indexStore,
            query: query,
            filters: filters,
            media: media,
            maxDepth: appState.appSettings.indexedMaxDepth,
            scope: appState.indexScope,
            perGroup: maxHitsPerGroup
        )
        let shown = found.files.count + found.folders.count
        let complete = found.files.count < maxHitsPerGroup && found.folders.count < maxHitsPerGroup
        var results = grouped(media: found.media, files: found.files, folders: found.folders, totalCount: found.media.count + shown, allMedia: media)
        results.isCountPending = !complete
        return PopoverSearchPage(
            results: results,
            pendingCount: complete ? nil : SearchCountRequest(query: query, filters: filters),
            mediumCount: found.media.count
        )
    }

    static func grouped(match: SearchMatch, media: [Medium]) -> PopoverSearchResults {
        guard !match.isEmpty else { return PopoverSearchResults() }
        return grouped(
            media: match.media,
            files: match.items.filter { !$0.isFolder },
            folders: match.items.filter(\.isFolder),
            totalCount: match.totalCount,
            allMedia: media
        )
    }

    static func grouped(
        media matchedMedia: [Medium],
        files: [SearchResultItem],
        folders: [SearchResultItem],
        totalCount: Int,
        allMedia media: [Medium]
    ) -> PopoverSearchResults {
        let mediumNames = Dictionary(media.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let mediumHits = matchedMedia.prefix(maxHitsPerGroup).map { medium in
            PopoverSearchHit(kind: .medium, title: medium.name, location: "", target: .fromMedium(medium), result: nil)
        }
        func objectHits(_ items: [SearchResultItem], folders: Bool) -> [PopoverSearchHit] {
            items
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
            PopoverSearchGroup(title: "DATEIEN", hits: objectHits(files, folders: false)),
            PopoverSearchGroup(title: "ORDNER", hits: objectHits(folders, folders: true)),
        ].filter { !$0.hits.isEmpty }
        return PopoverSearchResults(groups: groups, totalCount: totalCount)
    }
}
