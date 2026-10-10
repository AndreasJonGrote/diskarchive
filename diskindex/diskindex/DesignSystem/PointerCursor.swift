//
//  PointerCursor.swift
//  diskindex
//

import AppKit
import SwiftUI

extension View {
    /// Hand-Cursor für klickbare Custom-Controls (macOS setzt ihn nicht automatisch).
    func pointerCursor(_ active: Bool = true) -> some View {
        modifier(PointerCursorModifier(active: active))
    }

    /// Spaltenteiler-Cursor (macOS 15: `.pointerStyle(.columnResize)`, sonst `resizeLeftRight`).
    func columnResizePointerStyle() -> some View {
        modifier(ColumnResizePointerModifier())
    }
}

private struct PointerCursorModifier: ViewModifier {
    let active: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 15, *) {
                content.pointerStyle(active ? .link : nil)
            } else {
                content
            }
        }
        .onHover { inside in
            guard active else { return }
            hovering = inside
            if inside {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .onDisappear {
            if hovering {
                NSCursor.arrow.set()
                hovering = false
            }
        }
    }
}

private struct ColumnResizePointerModifier: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 15, *) {
                content.pointerStyle(.columnResize)
            } else {
                content
            }
        }
        .onHover { inside in
            hovering = inside
            if inside {
                NSCursor.resizeLeftRight.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .onDisappear {
            if hovering {
                NSCursor.arrow.set()
                hovering = false
            }
        }
    }
}
