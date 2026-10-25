//
//  EmptyStateView.swift
//  diskindex
//
//  Aufgabe 126/146/147 — Leerzustände Layout 04/05/10/11.
//

import SwiftUI

enum EmptyStateIconStyle: Equatable {
    /// Drei Medien-Icons (HDD, SSD, USB), volle Textfarbe.
    case mediaTypes
    /// Favoriten: bookmarks-simple Duotone, 40 pt, violett, ohne Kachel.
    case favorites
    /// Suche idle: Lupe + Trichter, blau, 40 pt.
    case searchAndFilter
    /// todo.0.4.042/046: Laden – drehender Spinner (offener Bogen, 32 pt, Strich 3 pt) in der Farbe der Ansicht (Suche
    /// blau, Favoriten violett) an der Stelle der Icons, im 40-pt-Platz, damit der Titel an seiner Stelle bleibt.
    case loadingSpinner(Color)
    case none
}

struct EmptyStateView: View {
    var title: String
    var message: String
    var iconStyle: EmptyStateIconStyle = .mediaTypes
    /// todo.0.4.042/046: Untertitel des Leerzustands, dessen Höhe die Ladeansicht freihält – so bleiben Icon-Platz und
    /// Titel an derselben Stelle wie im Leerzustand, auch wenn der eigene Untertitel kürzer ist.
    var reservedMessage: String?

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

    init(title: String, message: String, iconStyle: EmptyStateIconStyle, reservedMessage: String? = nil) {
        self.title = title
        self.message = message
        self.iconStyle = iconStyle
        self.reservedMessage = reservedMessage
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
            case .loadingSpinner(let tint):
                IndexingSpinnerRing(color: tint, lineWidth: 3)
                    .padding(1.5)
                    .frame(width: 32, height: 32)
                    .frame(width: 40, height: 40)
            case .none:
                EmptyView()
            }
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignColor.text.opacity(0.7))
                .multilineTextAlignment(.center)
            if !message.isEmpty {
                ZStack(alignment: .top) {
                    if let reservedMessage {
                        messageText(reservedMessage).hidden()
                    }
                    messageText(message)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
    }

    private func messageText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(DesignColor.text.opacity(0.55))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 340)
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
}

/// todo.0.4.042/046: eine Ladeansicht für Suche und Favoriten – Fläche des Leerzustands, Spinner in der Farbe der
/// Ansicht, Titel mit dem Umfang, Untertitel „Einen Moment bitte.“ (Farbe und Text als Parameter, Regel 7).
struct ScopeLoadingView: View {
    var tint: Color
    var title: String
    /// Untertitel des Leerzustands derselben Ansicht (Lage von Icon-Platz und Titel wie dort).
    var emptyStateMessage: String

    var body: some View {
        EmptyStateView(
            title: title,
            message: LayoutCopy.loadingOneMoment,
            iconStyle: .loadingSpinner(tint),
            reservedMessage: emptyStateMessage
        )
    }
}
