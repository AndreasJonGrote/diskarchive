//
//  ColumnBrowserPathFooter.swift
//  diskindex
//
//  Fußzeile Spaltenansicht (19.10).
//

import SwiftUI

struct ColumnBrowserPathFooter: View {
    let freeCapacityLabel: String
    let pathLabel: String
    let objectCountLabel: String

    var body: some View {
        StatusFooterBar {
            Text(freeCapacityLabel)
                .frame(width: DesignSpacing.columnBrowserSidebarWidth, alignment: .leading)
                .padding(.leading, 16)

            Text(pathLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .help(pathLabel)

            Text(objectCountLabel)
                .padding(.trailing, 16)
        }
    }
}
