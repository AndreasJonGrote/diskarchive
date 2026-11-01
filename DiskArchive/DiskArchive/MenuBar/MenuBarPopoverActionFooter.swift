//
//  MenuBarPopoverActionFooter.swift
//  DiskArchive
//
//  Popover-Fuß mit Sekundär-Button klein (Mockup Screen 03).
//

import SwiftUI

/// Fußzeile unter Inhalt bzw. „Automatisch indizieren“ — 7 % Text-Tönung, Trennlinie oben, Button rechts.
struct MenuBarPopoverActionFooter<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content()
        }
        .padding(.horizontal, MenuBarPopoverLayout.panelHorizontalInset)
        .padding(.vertical, MenuBarPopoverLayout.footerOpenAppVerticalPadding)
        .frame(height: MenuBarPopoverLayout.footerOpenAppHeight)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(MenuBarPopoverLayout.footerBandBackground)
        .overlay(alignment: .top) {
            MenuBarPopoverSeparator.horizontal
        }
    }
}
