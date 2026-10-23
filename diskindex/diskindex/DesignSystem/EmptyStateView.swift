//
//  EmptyStateView.swift
//  diskindex
//
//  Aufgabe 126/146/147 — Leerzustände Layout 04/05/10/11.
//

import SwiftUI

enum EmptyStateIconStyle {
    /// Drei Medien-Icons (HDD, SSD, USB), volle Textfarbe.
    case mediaTypes
    /// Favoriten: bookmarks-simple Duotone, 40 pt, violett, ohne Kachel.
    case favorites
    /// Suche idle: Lupe + Trichter, blau, 40 pt.
    case searchAndFilter
    /// todo.0.4.043/042: Laden – Spinner (wie „Inhalte werden geladen“, 20 pt, Textfarbe) an der Stelle der Icons, im
    /// 40-pt-Platz der Icons, damit der Titel an seiner Stelle bleibt.
    case loading
    case none
}

struct EmptyStateView: View {
    var title: String
    var message: String
    var iconStyle: EmptyStateIconStyle = .mediaTypes

    init(title: String, message: String, showsIcon: Bool = true, usesMediaTypeIcons: Bool = true) {
        self.title = title
        self.message = message
        if !showsIcon {
            self.iconStyle = .none
        } else if usesMediaTypeIcons {
            self.iconStyle = .mediaTypes
        } else {
            self.iconStyle = .none
        }
    }

    init(title: String, message: String, iconStyle: EmptyStateIconStyle) {
        self.title = title
        self.message = message
        self.iconStyle = iconStyle
    }

    var body: some View {
        VStack(spacing: 12) {
            switch iconStyle {
            case .mediaTypes:
                HStack(spacing: 12) {
                    mediaIcon("MediumTypeHDD")
                    mediaIcon("MediumTypeSSD")
                    mediaIcon("MediumTypeUSB")
                }
            case .favorites:
                Image("NavBookmarksDuotone")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(DesignColor.favorite)
            case .searchAndFilter:
                HStack(spacing: 12) {
                    filterSearchIcon("IconMagnifyingGlass")
                    filterSearchIcon("IconFunnel")
                }
            case .loading:
                IndexingSpinnerRing(color: DesignColor.text, lineWidth: 2.5)
                    .padding(1.25)
                    .frame(width: 20, height: 20)
                    .frame(width: 40, height: 40)
            case .none:
                EmptyView()
            }
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignColor.text.opacity(0.7))
                .multilineTextAlignment(.center)
            // Ladefläche ohne Untertitel (todo.0.4.043).
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DesignColor.text.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
    }

    private func mediaIcon(_ asset: String) -> some View {
        Image(asset)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .foregroundStyle(DesignColor.text)
    }

    private func filterSearchIcon(_ asset: String) -> some View {
        Image(asset)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .foregroundStyle(DesignColor.filterSearch)
    }
}

enum EmptyStateCopy {
    static var noMediumTitle: String { LayoutCopy.emptyNoMediaTitle }
    static var noMediumMessage: String { LayoutCopy.emptyNoMediaMessage }
    static var popoverNoneConnected: String { LayoutCopy.popoverNoneConnected }
    static var noFavoritesTitle: String { LayoutCopy.emptyNoFavoritesTitle }
    static var noFavoritesMessage: String { LayoutCopy.emptyNoFavoritesMessage }
    static var favoritesLoadingTitle: String { LayoutCopy.emptyFavoritesLoadingTitle }
}
