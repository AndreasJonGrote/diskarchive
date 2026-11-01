//
//  ColumnBrowserPathFooter.swift
//  DiskArchive
//
//  Fußzeile Spaltenansicht (19.10).
//

import SwiftUI

struct ColumnBrowserPathFooter: View {
    /// Aktuelle (gezogene) Breite der Seitenleiste.
    let sidebarWidth: CGFloat
    let freeCapacityLabel: String
    let pathLabel: String
    let objectCountLabel: String

    var body: some View {
        StatusFooterBar {
            Text(freeCapacityLabel)
                .lineLimit(1)
                .padding(.leading, 16)
                .frame(width: pathLeading, alignment: .leading)

            Text(pathLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 8)
                .help(pathLabel)

            Text(objectCountLabel)
                .padding(.trailing, 16)
        }
    }

    /// bug.0.4.220: Der Pfad beginnt bündig mit dem Icon der ersten Ordnerspalte (Seitenleiste + Zeileneinzug der Spalte
    /// + Icon-Kante in der Zeile) und folgt dem Ziehen der Seitenleiste.
    private var pathLeading: CGFloat {
        sidebarWidth + ColumnFolderContents<EmptyView>.rowInset + ColumnBrowserRow.iconLeading
    }
}
