//
//  PointerCursor.swift
//  DiskArchive
//

import AppKit
import SwiftUI

extension View {
    /// Hand-Cursor für klickbare Custom-Controls (macOS setzt ihn nicht automatisch).
    func pointerCursor(_ active: Bool = true) -> some View {
        modifier(PointerCursorModifier(active: active))
    }

    /// Spaltenteiler-Cursor (`.pointerStyle(.columnResize)`).
    func columnResizePointerStyle() -> some View {
        modifier(ColumnResizePointerModifier())
    }
}

private struct PointerCursorModifier: ViewModifier {
    let active: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        content.pointerStyle(active ? .link : nil)
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
        content.pointerStyle(.columnResize)
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
