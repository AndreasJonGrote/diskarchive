//
//  ColumnBrowserRow.swift
//  diskindex
//

import SwiftUI

struct ColumnBrowserRow: View {
    @Environment(AppState.self) private var appState

    static let horizontalPadding: CGFloat = 10
    static let iconBox: CGFloat = 16
    static let iconSize: CGFloat = 15
    /// bug.0.4.220: linke Kante des Icons in der Zeile (Fußzeilenpfad bündig).
    static var iconLeading: CGFloat { horizontalPadding + (iconBox - iconSize) / 2 }

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
                        // bug.0.4.217: Layout 12 × 12 mit 2 pt Strich (Rand innen), mittig in der Icon-Box.
                        IndexingSpinnerRing(
                            color: isSelected ? iconColorOnSelection : iconColor,
                            lineWidth: 2
                        )
                        .padding(1)
                        .frame(width: 12, height: 12)
                    } else {
                        Image(iconAsset)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: Self.iconSize, height: Self.iconSize)
                            .foregroundStyle(isSelected ? iconColorOnSelection : iconColor)
                    }
                }
                .frame(width: Self.iconBox, height: Self.iconBox)

                FadeMaskText(
                    text: title,
                    isLightOnDark: isSelected,
                    applyFadeMask: fadeTitleOnOverflow || (fadeTitleWhenSelected && isSelected),
                    font: .system(size: 13, weight: isSelected ? .semibold : .regular)
                )
                .layoutPriority(0)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Self.horizontalPadding)
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
