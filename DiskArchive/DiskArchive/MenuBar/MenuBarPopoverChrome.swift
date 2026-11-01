//
//  MenuBarPopoverChrome.swift
//  DiskArchive
//
//  Äußere Form Screen 03: Radius, 1-pt-Rand, Schatten (--shadow-lg).
//

import SwiftUI

private struct MenuBarPopoverChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(DesignColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.lg)
                    .strokeBorder(DesignColor.divider, lineWidth: DesignBorder.width)
            }
            .compositingGroup()
            .shadow(color: DesignColor.shadow.opacity(0.22), radius: 16, y: 12)
    }
}

extension View {
    /// Ruhe- und Such-Popover (Layout 03): abgerundet, Rand, Schatten — nach `.frame(width:height:)`.
    func menuBarPopoverChrome() -> some View {
        modifier(MenuBarPopoverChromeModifier())
    }
}

enum MenuBarPopoverSeparator {
    static var horizontal: some View {
        Rectangle()
            .fill(DesignColor.divider)
            .frame(height: DesignBorder.width)
    }
}
