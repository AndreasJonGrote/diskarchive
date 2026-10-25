//
//  SearchView.swift
//  diskindex
//
//  README Screen 07 / Layout Sektion 10. Treffer nur für den abgeschickten Begriff (Enter), nicht live.
//

import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState

    private var submittedQuery: String {
        appState.searchState.submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let hasSearchCriteria = !submittedQuery.isEmpty || appState.searchState.hasActiveFilters

        if hasSearchCriteria {
            let match = appState.searchMatch

            VStack(spacing: 0) {
                if appState.searchLoading.isShowing || appState.searchAwaitsFirstResults {
                    // todo.0.4.042: Start aus dem Leerzustand – Fläche von Layout 10.1, blauer Spinner, Umfang der Suche.
                    let scope = appState.searchLoadingScope
                    ScopeLoadingView(
                        tint: DesignColor.filterSearch,
                        title: LayoutCopy.loadingSearchTitle(media: scope.media, files: scope.files),
                        emptyStateMessage: LayoutCopy.searchIdleSubtitle
                    )
                    .background(DesignColor.text.opacity(0.05))
                } else {
                    results(match: match)
                }
            }
            .task(id: searchRequest) {
                guard !appState.screenshotFrozenLists else { return }
                await appState.runSearch()
            }
        } else {
            SearchIdlePlaceholder()
        }
    }

    @ViewBuilder
    private func results(match: SearchMatch) -> some View {
        if !match.media.isEmpty {
            CompactMediumCardFlow(media: match.media)
        }

        // bug.0.4.038: Name, Datum, Medium sortiert die Abfrage; Pfad und Status nur, wenn alle Treffer da sind.
        ObjectResultsTable(
            results: match.items,
            sort: appState.searchStateBinding(\.sort),
            serverSortedColumns: SearchSort.pageOrderedColumns,
            clientSortAvailable: match.allItemsOnPage
        ) {
            placeholder(match: match)
        }

        ObjectCountFooter(
            filtered: match.itemCount,
            total: appState.searchState.hasActiveFilters ? match.unfilteredItemCount : match.itemCount
        )
    }

    private var searchRequest: String {
        let filters = appState.searchState.filters
        let types = filters.fileTypes.map(\.rawValue).sorted().joined(separator: ",")
        let mediaIDs = filters.mediumIDs.map(\.uuidString).sorted().joined(separator: ",")
        let media = appState.indexedMedia.map(\.id.uuidString).joined(separator: ",")
        let sort = appState.searchState.sort.serverOrder
        return [
            submittedQuery,
            filters.selectAllMedia ? "all" : mediaIDs,
            types,
            filters.customExtensions.joined(separator: ","),
            filters.age?.rawValue ?? "",
            filters.combineWithAnd ? "and" : "or",
            String(appState.appSettings.indexedMaxDepth ?? -1),
            media,
            // Klick auf Name/Datum/Medium fragt neu ab; Pfad/Status sortiert der Client (gleiche Abfrage).
            "\(sort.column.rawValue)-\(sort.direction.rawValue)",
        ].joined(separator: "|")
    }

    @ViewBuilder
    private func placeholder(match: SearchMatch) -> some View {
        // todo.0.4.042: die kleine Zeile „Suche läuft…“ entfällt (Wartescreen nur aus dem Leerzustand); beim Verfeinern
        // bleibt die leere Tabelle stehen, bis die neuen Treffer da sind.
        if !appState.searchState.isSearchInProgress, match.media.isEmpty {
            Group {
                if submittedQuery.isEmpty {
                    Text(LayoutCopy.noResultsForFilters)
                } else {
                    Text(LayoutCopy.noResults(submittedQuery))
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(DesignColor.text.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .padding(.horizontal, 24)
        }
        // Nur Medien-Treffer: Kacheln oben, Tabelle bleibt leer.
    }
}

/// Leere Suche (Layout Sektion 10): zwei blaue Icons 40×40, Abstand 12 (Aufgabe 147).
private struct SearchIdlePlaceholder: View {
    var body: some View {
        EmptyStateView(
            title: LayoutCopy.searchIdleTitle,
            message: LayoutCopy.searchIdleSubtitle,
            iconStyle: .searchAndFilter
        )
        .background(DesignColor.text.opacity(0.05))
    }
}

#Preview {
    let state = AppState()
    state.openSearch(withQuery: "rechnung")
    return SearchView()
        .environment(state)
        .frame(width: 960, height: 600)
}
