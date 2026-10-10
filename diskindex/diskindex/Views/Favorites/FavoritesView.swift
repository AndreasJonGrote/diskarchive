//
//  FavoritesView.swift
//  diskindex
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
        let allFavoriteObjects = appState.favoriteObjects.filter {
            appState.favoritesConnectionFilter.includes(isOnline: $0.isOnline)
        }
        let favoriteObjects = allFavoriteObjects.filter { SearchItemFilter.matches($0.item, filters: filters) }
        let selectionEmpty = favoriteMedia.isEmpty && favoriteObjects.isEmpty

        VStack(spacing: 0) {
            FavoritesConnectionFilterBar()

            if selectionEmpty {
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

                ObjectResultsTable(results: favoriteObjects) {
                    Text(proposal: filters.hasActiveObjectFilters
                        ? ProposalCopy.noFavoritesForFilters
                        : ProposalCopy.noFavoritedObjects)
                        .font(.system(size: 13))
                        .proposedCopy(baseColor: DesignColor.text.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                }
            }

            ObjectCountFooter(filtered: favoriteObjects.count, total: allFavoriteObjects.count)
        }
        .task(id: favoriteRequest) {
            guard !appState.screenshotFrozenLists else { return }
            await appState.reloadFavorites()
        }
    }

    private var favoriteRequest: String {
        let media = appState.indexedMedia.map(\.id.uuidString).joined(separator: ",")
        return "\(appState.appSettings.indexedMaxDepth ?? -1)|\(media)|\(appState.indexRepository.generation)"
    }
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

private struct FavoritesConnectionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .frame(minHeight: 23.5)
                .foregroundStyle(isSelected ? DesignColor.filterSearch : DesignColor.text.opacity(0.55))
                .background(isSelected ? DesignColor.chipFill(DesignColor.filterSearch) : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignRadius.sm)
                        .strokeBorder(
                            isSelected ? DesignColor.chipBorder(DesignColor.filterSearch) : DesignColor.neutral500,
                            lineWidth: DesignBorder.width
                        )
                }
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
    }
}

#Preview {
    FavoritesView()
        .environment(AppState())
        .frame(width: 900, height: 600)
}
