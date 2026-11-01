//
//  MediumCompactSearchField.swift
//  DiskArchive
//
//  Popover-Header / kompakte Medium-Suche (150px).
//

import SwiftUI

struct MediumCompactSearchField: View {
    @Binding var text: String
    var placeholder: String = LayoutCopy.searchPlaceholderCompact
    var width: CGFloat = DesignSearchField.mediumCompactWidth
    var focus: FocusState<Bool>.Binding?

    init(
        text: Binding<String>,
        placeholder: String = LayoutCopy.searchPlaceholderCompact,
        width: CGFloat = DesignSearchField.mediumCompactWidth,
        focus: FocusState<Bool>.Binding? = nil
    ) {
        _text = text
        self.placeholder = placeholder
        self.width = width
        self.focus = focus
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(DesignColor.text.opacity(0.5))
                .frame(width: 26)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .optionalFocused(focus)

            if !text.isEmpty {
                SearchFieldClearButton { text = "" }
                    .padding(.trailing, 4)
            }
        }
        .frame(width: width, height: 26)
        .background(DesignColor.bg)
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.sm)
                .strokeBorder(DesignColor.neutral300, lineWidth: DesignBorder.width)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }
}

private extension View {
    @ViewBuilder
    func optionalFocused(_ binding: FocusState<Bool>.Binding?) -> some View {
        if let binding {
            focused(binding)
        } else {
            self
        }
    }
}
