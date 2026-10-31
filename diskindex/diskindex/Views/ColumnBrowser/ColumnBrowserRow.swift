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
    /// Tooltip statt des Titels (todo.0.4.2.002: Originalname bei eigenem Namen).
    var helpText: String?
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
    /// todo.0.4.2.003: Fläche der Auswahl (mit Filter blau, leiser Ordner in Textfarbe).
    var selectionFill: Color = DesignColor.sidebarActiveBackground
    /// todo.0.4.2.005: Medium der Seitenleiste – „Benennen“ bearbeitet hier; läuft es, ist der Titel ein Eingabefeld.
    var namingMedium: Medium?
    var onSelect: () -> Void

    var body: some View {
        let naming = namingMedium.map { MediumNaming(mediumID: $0.id, place: .columnSidebar) }
        if let medium = namingMedium, let naming, appState.mediumNaming == naming {
            // Kein Knopf: ein Klick ins Feld wechselt die Auswahl nicht.
            content {
                MediumNameEditor(
                    medium: medium,
                    naming: naming,
                    font: titleFont,
                    originalColor: (isSelected ? DesignColor.onSelection : DesignColor.text).opacity(0.5)
                )
            }
            .objectContextMenu(contextTarget, resolveTargets: resolveTargets, namingPlace: .columnSidebar)
        } else {
            Button {
                appState.contextMenuHighlightObjectID = nil
                onSelect()
            } label: {
                content {
                    FadeMaskText(
                        text: title,
                        isLightOnDark: isSelected,
                        applyFadeMask: fadeTitleOnOverflow || (fadeTitleWhenSelected && isSelected),
                        font: titleFont
                    )
                }
            }
            .buttonStyle(.plainFullHit)
            .pointerCursor()
            .help(helpText ?? title)
            .objectContextMenu(contextTarget, resolveTargets: resolveTargets, namingPlace: naming?.place)
        }
    }

    private var titleFont: Font {
        .system(size: 13, weight: isSelected ? .semibold : .regular)
    }

    private func content<Title: View>(@ViewBuilder title: () -> Title) -> some View {
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

            title()
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
                    .fill(selectionFill)
            }
        }
        .foregroundStyle(isSelected ? DesignColor.onSelection : DesignColor.text)
        .contentShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }

    private var iconColorOnSelection: Color {
        iconColor == DesignColor.text ? DesignColor.onSelection : iconColor
    }
}
