//
//  FolderContentsLoadErrorHint.swift
//  DiskArchive
//
//  Aufgabe 139 — Restbreite wie andere Statusflächen.
//

import SwiftUI

struct FolderContentsLoadErrorHint: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignColor.text)
                .frame(maxWidth: 230, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}