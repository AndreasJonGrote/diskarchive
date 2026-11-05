//
//  MenuBarPopoverSearchContent.swift
//  DiskArchive
//

import SwiftUI

struct MenuBarPopoverSearchContent: View {
    @Environment(AppState.self) private var appState

    let query: String

    var body: some View {
        let results = appState.popoverResults
        let phase = appState.popoverSearchPhase

        // todo.0.4.3.014: ohne Treffer erst warten (vorige Treffer bleiben), dann Hinweis bzw. „Keine Suchergebnisse“.
        if results.groups.isEmpty || phase == .hint {
            PopoverSearchStateView(phase: results.groups.isEmpty && phase == .settled ? .settled : phase)
        } else if let scrollHeight = MenuBarPopoverLayout.searchScrollAreaHeight(
            groups: results.groups,
            totalCount: results.totalCount
        ) {
            ScrollView {
                searchBody(results)
            }
            .frame(height: scrollHeight)
        } else {
            searchBody(results)
        }
    }

    private func searchBody(_ results: PopoverSearchResults) -> some View {
        VStack(alignment: .leading, spacing: MenuBarPopoverLayout.searchSectionGap) {
            ForEach(results.groups) { group in
                VStack(alignment: .leading, spacing: MenuBarPopoverLayout.searchInnerGroupSpacing) {
                    Text(group.title)
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(1)
                        .foregroundStyle(DesignColor.text.opacity(0.55))
                        .padding(.bottom, MenuBarPopoverLayout.searchSectionLabelBottomMargin)
                    ForEach(group.hits) { hit in
                        PopoverSearchResultRow(hit: hit)
                    }
                }
            }

        }
        .padding(.horizontal, MenuBarPopoverLayout.searchHorizontalPadding)
        .padding(.vertical, MenuBarPopoverLayout.searchVerticalPadding)
    }
}

/// todo.0.4.3.014 (Layout 03.03/03.04): Fläche statt Treffern – Suche dauert länger (blauer Spinner, Umfang) oder kein
/// Ergebnis (Lupe, „Keine Suchergebnisse“, „Suchbegriff ändern.“). Mindesthöhe 180, Fläche 5 % Textfarbe.
struct PopoverSearchStateView: View {
    @Environment(AppState.self) private var appState
    let phase: PopoverSearchPhase

    var body: some View {
        VStack(spacing: 10) {
            switch phase {
            case .hint:
                IndexingSpinnerRing(color: DesignColor.filterSearch, lineWidth: 3)
                    .padding(1.5)
                    .frame(width: 32, height: 32)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignColor.text.opacity(0.7))
                    .multilineTextAlignment(.center)
            case .settled:
                Image("IconMagnifyingGlass")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(DesignColor.filterSearch)
                Text(LayoutCopy.searchNoResultsTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignColor.text.opacity(0.7))
                Text(LayoutCopy.popoverNoResultsMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignColor.text.opacity(0.55))
                    .multilineTextAlignment(.center)
            case .idle, .pending:
                EmptyView()
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: MenuBarPopoverLayout.searchStateHeight)
        .background(DesignColor.text.opacity(0.05))
    }

    /// Umfang wie im Fenster: alle indizierten Medien und ihre Dateien (Einzahl laut 20).
    private var title: String {
        let media = appState.indexedMedia
        return LayoutCopy.loadingSearchTitle(media: media.count, files: media.reduce(0) { $0 + $1.fileCount })
    }
}

private struct PopoverSearchResultRow: View {
    @Environment(AppState.self) private var appState
    let hit: PopoverSearchHit
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            icon
                .foregroundStyle(DesignColor.text.opacity(0.6))
                .frame(width: 15)

            HStack(spacing: 0) {
                Text(hit.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 150, alignment: .leading)

                if !hit.location.isEmpty {
                    HStack(spacing: 0) {
                        Text(verbatim: " – ")
                        Text(hit.location)
                    }
                    .foregroundStyle(DesignColor.text.opacity(0.45))
                    .lineLimit(1)
                }
            }
            .font(.system(size: 12.5))
            .foregroundStyle(DesignColor.text.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: MenuBarPopoverLayout.searchRowMinHeight, alignment: .leading)
        .padding(.vertical, MenuBarPopoverLayout.searchRowVerticalPadding)
        .padding(.horizontal, MenuBarPopoverLayout.searchRowHoverHorizontalOutset)
        .background(isHovered ? DesignColor.text.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
        .padding(.horizontal, -MenuBarPopoverLayout.searchRowHoverHorizontalOutset)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .pointerCursor()
        .onTapGesture(perform: open)
        .objectContextMenu(hit.target)
    }

    @ViewBuilder
    private var icon: some View {
        let assetName = switch hit.kind {
        case .medium: appState.medium(with: hit.target.mediumID)?.type.iconAssetName ?? FileKind.other.assetName
        case .file: FileKind(fileName: hit.title, isFolder: false).assetName
        case .folder: FileKind.folder.assetName
        }
        Image(assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 14, height: 14)
    }

    /// Treffer in der Spaltenansicht zeigen.
    private func open() {
        if let result = hit.result {
            MediumNavigation.openObject(result, appState: appState)
        } else {
            MediumNavigation.openColumnBrowser(for: hit.target.mediumID, appState: appState)
        }
        MenuBarPopoverDismiss.openMainWindow(appState: appState)
    }
}
