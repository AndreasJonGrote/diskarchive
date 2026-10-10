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
                if !match.media.isEmpty {
                    CompactMediumCardFlow(media: match.media)
                }

                ObjectResultsTable(results: match.items, sort: appState.searchStateBinding(\.sort)) {
                    placeholder(match: match)
                }

                ObjectCountFooter(
                    filtered: match.itemCount,
                    total: appState.searchState.hasActiveFilters ? match.unfilteredItemCount : match.itemCount
                )
            }
            .task(id: searchRequest) {
                guard !appState.screenshotFrozenLists else { return }
                await appState.runSearch()
            }
        } else {
            SearchIdlePlaceholder()
        }
    }

    private var searchRequest: String {
        let filters = appState.searchState.filters
        let types = filters.fileTypes.map(\.rawValue).sorted().joined(separator: ",")
        let mediaIDs = filters.mediumIDs.map(\.uuidString).sorted().joined(separator: ",")
        let media = appState.indexedMedia.map(\.id.uuidString).joined(separator: ",")
        return [
            submittedQuery,
            filters.selectAllMedia ? "all" : mediaIDs,
            types,
            filters.customExtensions.joined(separator: ","),
            filters.age?.rawValue ?? "",
            filters.combineWithAnd ? "and" : "or",
            String(appState.appSettings.indexedMaxDepth ?? -1),
            media,
        ].joined(separator: "|")
    }

    @ViewBuilder
    private func placeholder(match: SearchMatch) -> some View {
        if appState.searchState.isSearchInProgress {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(proposal: ProposalCopy.searchInProgress)
                    .proposedCopy(baseColor: DesignColor.text.opacity(0.55))
            }
            .font(.system(size: 13))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        } else if match.media.isEmpty {
            Group {
                if submittedQuery.isEmpty {
                    Text(proposal: ProposalCopy.noResultsForFilters)
                } else {
                    Text(proposal: ProposalCopy.noResults(for: submittedQuery))
                }
            }
            .font(.system(size: 13))
            .proposedCopy(baseColor: DesignColor.text.opacity(0.55))
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
