//
//  StatusFooterBar.swift
//  diskindex
//
//  Fußleiste unter Spaltenansicht, Suche und Favoriten (Layout Sektionen 07/10/11, Aufgabe 23.10).
//

import SwiftUI

struct StatusFooterBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0, content: content)
            .font(.system(size: 11.5))
            .foregroundStyle(DesignColor.text.opacity(0.55))
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 27)
            .background(DesignColor.text.opacity(0.05))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DesignColor.neutral300)
                    .frame(height: DesignBorder.width)
            }
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Nur „N Objekte“ rechts (Suche, Favoriten).
struct ObjectCountFooter: View {
    let filtered: Int
    let total: Int

    var body: some View {
        StatusFooterBar {
            Spacer(minLength: 0)
            Text(ObjectCountFormatting.label(filtered: filtered, total: total))
                .padding(.horizontal, 16)
        }
    }
}

enum ObjectCountFormatting {
    /// „1 Objekt“ / „1.234 Objekte“; bei aktivem Filter „x von y Objekten“.
    static func label(filtered: Int, total: Int) -> String {
        if filtered != total {
            return LayoutCopy.objectFiltered(DisplayNumberFormat.groupedInteger(filtered), DisplayNumberFormat.groupedInteger(total))
        }
        return filtered == 1 ? LayoutCopy.objectOne : LayoutCopy.objectMany(DisplayNumberFormat.groupedInteger(filtered))
    }
}
