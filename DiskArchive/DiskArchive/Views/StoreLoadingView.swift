//
//  StoreLoadingView.swift
//  DiskArchive
//
//  Ladezustand, bis die Datenbank offen ist (Aufgabe 219): Spinner und „Inhalte werden geladen“ wie in der Spalte.
//

import SwiftUI

struct StoreLoadingView: View {
    /// todo.0.4.3.015 (Layout 03.11): im Popover statt der Medienliste – Fläche 5 % Textfarbe, mindestens 180 hoch.
    var inPopover = false

    /// Layout 07.02.08: Spinner 20 (Strich 2,5), 10 darunter der Text 12 halbfett.
    static let spacing: CGFloat = 10

    var body: some View {
        VStack(spacing: Self.spacing) {
            IndexingSpinnerRing(color: DesignColor.text, lineWidth: 2.5)
                .padding(1.25)
                .frame(width: 20, height: 20)
            Text(LayoutCopy.columnContentsLoading)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignColor.text)
        }
        .padding(.vertical, inPopover ? 24 : 0)
        .padding(.horizontal, inPopover ? 16 : 0)
        .frame(maxWidth: .infinity, minHeight: inPopover ? MenuBarPopoverLayout.searchStateHeight : nil, maxHeight: inPopover ? nil : .infinity)
        .background(inPopover ? DesignColor.text.opacity(0.05) : Color.clear)
        .accessibilityElement(children: .combine)
    }
}
