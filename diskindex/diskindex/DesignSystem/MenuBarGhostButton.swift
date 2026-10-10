//
//  MenuBarGhostButton.swift
//  diskindex
//
//  Mockup `.btn-ghost` — Zeilenaktion „Neu indizieren“ im Popover.
//

import SwiftUI

struct MenuBarGhostButton: View {
    let title: String
    var isEnabled = true
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(MenuBarGhostButtonStyle(isHovered: isEnabled && isHovered))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .pointerCursor(isEnabled)
        .onHover { hovering in
            isHovered = isEnabled && hovering
        }
    }
}

struct MenuBarGhostButtonStyle: ButtonStyle {
    var isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(DesignColor.control)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                (isHovered || configuration.isPressed)
                    ? DesignColor.control.opacity(0.08)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
            .contentShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }
}
