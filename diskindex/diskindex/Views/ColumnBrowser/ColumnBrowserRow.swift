//
//  ColumnBrowserRow.swift
//  diskindex
//

import SwiftUI

struct ColumnBrowserRow: View {
    @Environment(AppState.self) private var appState

    let title: String
    let isSelected: Bool
    /// Template-Asset (Phosphor) aus dem Asset-Katalog.
    let iconAsset: String
    var iconColor: Color = DesignColor.text
    /// Ersetzt das Typ-Icon (Seitenleiste während Indizierung).
    var showsIndexingSpinner: Bool = false
    /// Seitenleiste: kein Verlauf; Ordnerspalten: Verlauf bei Überlauf (statt „…“).
    var fadeTitleWhenSelected: Bool = true
    var fadeTitleOnOverflow: Bool = false
    var contextTarget: ObjectContextTarget?
    var resolveTargets: ((ObjectContextTarget) -> [ObjectContextTarget])?
    var onSelect: () -> Void

    var body: some View {
        Button {
            appState.contextMenuHighlightObjectID = nil
            onSelect()
        } label: {
            HStack(spacing: 8) {
                Group {
                    if showsIndexingSpinner {
                        IndexingSpinnerRing(
                            color: isSelected ? iconColorOnSelection : iconColor,
                            lineWidth: 1.5
                        )
                        .frame(width: 14, height: 14)
                    } else {
                        Image(iconAsset)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .foregroundStyle(isSelected ? iconColorOnSelection : iconColor)
                    }
                }
                .frame(width: 16, height: 16)

                FadeMaskText(
                    text: title,
                    isLightOnDark: isSelected,
                    applyFadeMask: fadeTitleOnOverflow || (fadeTitleWhenSelected && isSelected),
                    font: .system(size: 13, weight: isSelected ? .semibold : .regular)
                )
                .layoutPriority(0)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: DesignRadius.sm)
                        .fill(DesignColor.sidebarActiveBackground)
                }
            }
            .foregroundStyle(isSelected ? DesignColor.onSelection : DesignColor.text)
            .contentShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .help(title)
        .objectContextMenu(contextTarget, resolveTargets: resolveTargets)
    }

    private var iconColorOnSelection: Color {
        iconColor == DesignColor.text ? DesignColor.onSelection : iconColor
    }
}
