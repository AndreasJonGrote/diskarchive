//
//  SearchCompactMediumCard.swift
//  diskindex
//
//  Kompakte Medium-Kachel (Suche, Favoriten; Layout Sektion 10): Icon links, Status-Chip rechts, Name darunter.
//

import SwiftUI

struct SearchCompactMediumCard: View {
    @Environment(AppState.self) private var appState
    let medium: Medium

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                MediumTypeIcon(medium: medium, size: 20)
                Spacer(minLength: 8)
                StatusChip(medium: medium)
            }
            Text(medium.shownName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
        }
        .padding(12)
        .frame(width: 190, alignment: .leading)
        .background(DesignColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.md)
                .strokeBorder(DesignColor.neutral300, lineWidth: DesignBorder.width)
        }
        .contentShape(RoundedRectangle(cornerRadius: DesignRadius.md))
        .pointerCursor()
        .onTapGesture {
            MediumNavigation.openColumnBrowser(for: medium.id, appState: appState)
        }
        .objectContextMenu(.fromMedium(medium), highlightCornerRadius: DesignRadius.md)
    }
}
