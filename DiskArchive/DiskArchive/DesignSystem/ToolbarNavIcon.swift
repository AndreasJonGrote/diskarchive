//
//  ToolbarNavIcon.swift
//  DiskArchive
//
//  Aufgabe 132/148/163 — Phosphor-Duotone Fill+Stroke, 17 pt, Fill 100 % / 50 %.
//

import SwiftUI

enum ToolbarNavIconRole {
    case home
    case settings
    case filter
    case favorites
    case search

    var fillOpacity: Double {
        switch self {
        case .home: 1.0
        case .settings, .filter, .favorites, .search: 0.50
        }
    }

    /// sRGB aus OKLCH: Hell `oklch(0.62 0.16 h)`, Dunkel `oklch(0.72 0.14 h)`.
    func activeColor(scheme: ColorScheme) -> Color {
        switch self {
        case .home:
            return DesignColor.control
        case .settings:
            return scheme == .dark
                ? Color(red: 0, green: 191 / 255, blue: 192 / 255)
                : Color(red: 0, green: 162 / 255, blue: 164 / 255)
        case .filter, .search:
            return DesignColor.filterSearch
        case .favorites:
            return DesignColor.favorite
        }
    }
}

struct ToolbarNavIcon: View {
    let fillAsset: String
    let strokeAsset: String
    let role: ToolbarNavIconRole
    let isActive: Bool

    @Environment(\.colorScheme) private var colorScheme

    /// Katalog / Layout: Toolbar-Icon 17 pt (Aufgabe 148).
    static let pointSize: CGFloat = 17

    var body: some View {
        let color = isActive ? role.activeColor(scheme: colorScheme) : DesignColor.text
        ZStack {
            if isActive {
                Image(fillAsset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .opacity(role.fillOpacity)
            }
            Image(strokeAsset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        }
        .foregroundStyle(color)
        .frame(width: Self.pointSize, height: Self.pointSize)
        .accessibilityHidden(true)
    }
}
