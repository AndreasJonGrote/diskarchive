//
//  FavoritesView.swift
//  DiskArchive
//
//  Aufgabe 19.12 — Kacheln + Objekt-Tabelle, Chip-Leiste Alle/Online/Offline.
//  Aufgabe 126 — Leerzustand mit Favoriten-Icon.
//

import SwiftUI

struct FavoritesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let media = appState.indexedMedia
        let favoriteMedia = media.filter(\.isFavorite)
        let filters = appState.searchState.filters
        // bug.0.4.037: Verbindung aus dem aktuellen Medienstand (einmal je Body), nicht aus der geladenen Zeile. Die
        // Abfrage filtert schon nach Verbindung, Dateityp und Alter (bug.0.4.040); hier nur bis zum Nachladen.
        let online = appState.mediumConnectivity
        let connection = appState.favoritesConnectionFilter
        let favoriteObjects = appState.favoriteObjects.filter { connection.includes(isOnline: online[$0.mediumID] ?? false) }
        let selectionEmpty = favoriteMedia.isEmpty && favoriteObjects.isEmpty
        let loading = appState.favoritesLoading.isShowing
        let itemCount = loading ? nil : appState.favoriteItemCount

        VStack(spacing: 0) {
            FavoritesConnectionFilterBar()

            if loading {
                // todo.0.4.046: Fläche von „Keine Favoriten“, violetter Spinner, Umfang des Verbindungsfilters.
                let scope = appState.favoritesLoadingScope
                ScopeLoadingView(
                    tint: DesignColor.favorite,
                    title: LayoutCopy.loadingFavoritesTitle(media: scope.media, files: scope.files),
                    emptyStateMessage: EmptyStateCopy.noFavoritesMessage
                )
            } else if selectionEmpty {
                // Aufgabe 147 — Duotone bookmarks-simple, 40 pt violett, ohne Kachel.
                EmptyStateView(
                    title: EmptyStateCopy.noFavoritesTitle,
                    message: EmptyStateCopy.noFavoritesMessage,
                    iconStyle: .favorites
                )
            } else {
                if !favoriteMedia.isEmpty {
                    CompactMediumCardFlow(media: favoriteMedia)
                }

                // todo.0.4.3.005: ein Leerzustand für Auswahl und Filter (Layout 11), ersetzt die beiden alten Zeilen.
                ObjectResultsTable(results: favoriteObjects) {
                    EmptyStateView(
                        title: EmptyStateCopy.noFavoritesTitle,
                        message: EmptyStateCopy.noFavoritesMessage,
                        iconStyle: .favorites
                    )
                    .frame(minHeight: 300)
                }
            }

            ObjectCountFooter(
                filtered: itemCount,
                total: loading ? nil : (filters.hasActiveObjectFilters ? appState.favoriteUnfilteredCount : itemCount)
            )
        }
        .task(id: favoriteRequest) {
            guard !appState.screenshotFrozenLists else { return }
            await appState.reloadFavorites()
        }
    }

    /// Neu laden bei anderer Anfrage (Medien und deren Verbindung, Verbindungsfilter, Dateityp/Alter, Tiefe) oder
    /// geändertem Index.
    private var favoriteRequest: FavoritesTaskKey {
        FavoritesTaskKey(request: appState.currentFavoritesRequest, generation: appState.indexRepository.generation)
    }
}

private struct FavoritesTaskKey: Equatable {
    var request: FavoritesRequest
    var generation: Int
}

private struct FavoritesConnectionFilterBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 6) {
            ForEach(FavoritesConnectionFilter.allCases) { option in
                FavoritesConnectionChip(
                    title: option.label,
                    isSelected: appState.favoritesConnectionFilter == option
                ) {
                    appState.favoritesConnectionFilter = option
                }
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DesignColor.neutral300).frame(height: DesignBorder.width)
        }
    }
}

/// bug.0.4.163 (c): `internal`, damit `ChipButtonTests` das Rezept messen kann.
struct FavoritesConnectionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        ChipButton(
            title: title,
            foreground: isSelected ? DesignColor.filterSearch : DesignColor.text.opacity(0.55),
            background: isSelected ? DesignColor.chipFill(DesignColor.filterSearch) : Color.clear,
            border: isSelected ? DesignColor.chipBorder(DesignColor.filterSearch) : DesignColor.neutral500,
            action: action
        )
        .pointerCursor()
    }
}

#Preview {
    FavoritesView()
        .environment(AppState())
        .frame(width: 900, height: 600)
}
