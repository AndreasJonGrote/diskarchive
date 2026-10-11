//
//  StoreLoadingView.swift
//  diskindex
//
//  Ladezustand, bis die Datenbank offen ist (Aufgabe 219): Spinner und „Inhalte werden geladen“ wie in der Spalte.
//

import SwiftUI

struct StoreLoadingView: View {
    var body: some View {
        VStack(spacing: 8) {
            IndexingSpinnerRing(color: DesignColor.text, lineWidth: 2.5)
                .padding(1.25)
                .frame(width: 20, height: 20)
            Text(LayoutCopy.columnContentsLoading)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignColor.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
