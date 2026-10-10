//
//  MenuBarPopoverSearchContent.swift
//  diskindex
//

import SwiftUI

struct MenuBarPopoverSearchContent: View {
    @Environment(AppState.self) private var appState

    let query: String

    var body: some View {
        let results = appState.popoverResults

        if let scrollHeight = MenuBarPopoverLayout.searchScrollAreaHeight(
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

            if results.totalCount == 0 {
                Text(proposal: ProposalCopy.popoverNoHits(
                    for: query.trimmingCharacters(in: .whitespacesAndNewlines)
                ))
                .font(.system(size: 12.5))
                .proposedCopy(baseColor: DesignColor.text.opacity(0.55))
            }
        }
        .padding(.horizontal, MenuBarPopoverLayout.searchHorizontalPadding)
        .padding(.vertical, MenuBarPopoverLayout.searchVerticalPadding)
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
