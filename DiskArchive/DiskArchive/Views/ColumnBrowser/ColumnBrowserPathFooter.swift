//
//  ColumnBrowserPathFooter.swift
//  DiskArchive
//
//  Fußzeile Spaltenansicht (19.10).
//  todo.0.4.3.017 (Layout 07.01.01): links „{1} frei von {2}“, Mitte der Pfad (Teile mit `caret-right` 10 pt, 60 %,
//  4 pt Abstand; bei Überlänge in der Mitte ausgeblendet), rechts die Objektzahl.
//

import SwiftUI

struct ColumnBrowserPathFooter: View {
    /// Aktuelle (gezogene) Breite der Seitenleiste.
    let sidebarWidth: CGFloat
    let freeCapacityLabel: String
    let pathParts: [String]
    let objectCountLabel: String

    var body: some View {
        StatusFooterBar {
            Text(freeCapacityLabel)
                .lineLimit(1)
                .padding(.leading, 16)
                .frame(width: pathLeading, alignment: .leading)

            ColumnFooterPath(parts: pathParts)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 8)
                .help(pathParts.joined(separator: " / "))

            Text(objectCountLabel)
                .lineLimit(1)
                .fixedSize()
                .padding(.trailing, 16)
        }
    }

    /// bug.0.4.220: Der Pfad beginnt bündig mit dem Icon der ersten Ordnerspalte (Seitenleiste + Zeileneinzug der Spalte
    /// + Icon-Kante in der Zeile) und folgt dem Ziehen der Seitenleiste.
    private var pathLeading: CGFloat {
        sidebarWidth + ColumnFolderContents<EmptyView>.rowInset + ColumnBrowserRow.iconLeading
    }
}

/// Pfad der Fußzeile: passt er, ganz; sonst vorne und hinten sichtbar, die Mitte über je 18 pt ausgeblendet (vorderer Teil
/// gibt zuerst nach, wie `flex-shrink: 1000` im Layout).
struct ColumnFooterPath: View {
    let parts: [String]
    static let fade: CGFloat = 18

    /// Aufteilung bei Überlänge: vordere Hälfte (aufgerundet) mit Pfeil am Ende, Rest hinten.
    static func split(_ parts: [String]) -> (head: [String], tail: [String]) {
        let headCount = (parts.count + 1) / 2
        return (Array(parts.prefix(headCount)), Array(parts.dropFirst(headCount)))
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            segments(parts, trailingCaret: false)
                .fixedSize()
            let split = Self.split(parts)
            HStack(spacing: 4) {
                segments(split.head, trailingCaret: !split.tail.isEmpty)
                    .fixedSize()
                    .frame(minWidth: 0, alignment: .leading)
                    .clipped()
                    .mask(fadeMask(trailing: true))
                    .layoutPriority(0)
                if !split.tail.isEmpty {
                    segments(split.tail, trailingCaret: false)
                        .fixedSize()
                        .frame(minWidth: 0, alignment: .trailing)
                        .clipped()
                        .mask(fadeMask(trailing: false))
                        .layoutPriority(1)
                }
            }
        }
    }

    private func segments(_ list: [String], trailingCaret: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(list.enumerated()), id: \.offset) { index, part in
                Text(part).lineLimit(1)
                if index < list.count - 1 || trailingCaret {
                    caret
                }
            }
        }
    }

    private var caret: some View {
        Image("NavCaretRight")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 10, height: 10)
            .opacity(0.6)
    }

    private func fadeMask(trailing: Bool) -> some View {
        HStack(spacing: 0) {
            if !trailing {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: Self.fade)
            }
            Rectangle()
            if trailing {
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: Self.fade)
            }
        }
    }
}

