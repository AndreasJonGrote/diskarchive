//
//  MediumSidebarSearchField.swift
//  diskindex
//

import SwiftUI

struct MediumSidebarSearchField: View {
    @Binding var text: String
    var placeholder: String = "Medium suchen…"
    /// Template-Asset links im Feld; Dateiendungs-Feld nutzt `FileTypeGeneric` (Review K1 zu 32.2).
    var icon: String = "IconMagnifyingGlass"
    /// Enter (z. B. Endung übernehmen). Ohne Handler filtert das Feld nur live.
    var onSubmit: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 11, height: 11)
                .foregroundStyle(DesignColor.text.opacity(0.5))
                .frame(width: DesignSearchField.mediumSmallIconLeadingPadding)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: DesignSearchField.mediumSmallFontSize))
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                SearchFieldClearButton { text = "" }
                    .padding(.trailing, 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: DesignSearchField.mediumSmallMinHeight)
        .background(DesignColor.bg)
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.sm)
                .strokeBorder(DesignColor.neutral300, lineWidth: DesignBorder.width)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }
}
