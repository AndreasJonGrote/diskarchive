//
//  RegistryTableRow.swift
//  DiskArchive
//

import SwiftUI

struct RegistryTableRow: View {
    @Environment(AppState.self) private var appState
    let medium: Medium
    let isLast: Bool

    private var rowOpacity: Double {
        !medium.allowIndexing ? 0.65 : 1
    }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                MediumNavigation.openDetails(for: medium.id, appState: appState)
            } label: {
                HStack(spacing: 8) {
                    MediumTypeIcon(medium: medium, size: 15)
                    Text(medium.shownName)
                        .fontWeight(.semibold)
                        // todo.0.4.2.002: Originalname als Tooltip, wenn ein eigener Name gesetzt ist.
                        .help(medium.customName != nil ? medium.name : "")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plainFullHit)
            .pointerCursor()

            Text(medium.type.displayName)
                .frame(width: RegistryTableLayout.typeWidth, alignment: .leading)

            StatusChip(medium: medium)
                .frame(width: RegistryTableLayout.statusWidth, alignment: .trailing)
                .padding(.trailing, 6)

            allowIndexingGroup
                .frame(width: RegistryTableLayout.indexingWidth, alignment: .trailing)

            Button {
                MediumNavigation.openDetails(for: medium.id, appState: appState)
            } label: {
                Image("IconFadersHorizontal")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(DesignColor.text)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plainFullHit)
            .pointerCursor()
            .frame(width: RegistryTableLayout.detailActionWidth, alignment: .trailing)
            .help(LayoutCopy.showDetailsHelp)
        }
        .font(.system(size: 13))
        .padding(.horizontal, RegistryTableLayout.horizontalPadding)
        .padding(.vertical, RegistryTableLayout.rowVerticalPadding)
        .opacity(rowOpacity)
        .contentShape(Rectangle())
        .objectContextMenu(.fromMedium(medium), highlightCornerRadius: 0)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(DesignColor.neutral200)
                    .frame(height: DesignBorder.width)
            }
        }
    }

    private var allowIndexingGroup: some View {
        EquatableView(content: AllowIndexingBinaryGroup(
            mediumID: medium.id,
            allowIndexing: medium.allowIndexing,
            isPending: medium.indexStatus == .pending,
            isEnabled: appState.featureAccess.canWriteIndex
        ) { allow in
            appState.updateMedium(id: medium.id, persist: true) {
                $0.decision = allow ? .index : .dontIndex
                $0.allowIndexing = allow
            }
        })
    }
}
