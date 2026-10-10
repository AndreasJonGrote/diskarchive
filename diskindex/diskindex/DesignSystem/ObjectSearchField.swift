//
//  ObjectSearchField.swift
//  diskindex
//
//  Objekte-Suche (Screens 04, 06, 07).
//

import SwiftUI

struct ObjectSearchField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var placeholder: String = LayoutCopy.searchPlaceholderObjects
    var width: CGFloat = DesignSearchField.objectWidth
    var onSubmit: (() -> Void)?

    @State private var frameInWindow: ObjectSearchFieldWindowFrame = .init()

    private var showsClearButton: Bool {
        !text.isEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(DesignColor.text.opacity(0.5))
                .frame(width: DesignSearchField.objectIconLeadingPadding)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: DesignSearchField.objectFontSize))
                .focused($isFocused)
                .onSubmit { onSubmit?() }

            if showsClearButton {
                SearchFieldClearButton {
                    text = ""
                }
                .padding(.trailing, 6)
            }
        }
        .frame(width: width, height: 28)
        .background(DesignColor.bg)
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.sm)
                .strokeBorder(DesignColor.neutral300, lineWidth: DesignBorder.width)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
        .background(ObjectSearchFieldFrameInWindowReporter(frameInWindow: $frameInWindow))
        .preference(key: ObjectSearchFieldFrameInWindowKey.self, value: frameInWindow)
    }
}
