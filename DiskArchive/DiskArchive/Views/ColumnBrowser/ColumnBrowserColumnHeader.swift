//
//  ColumnBrowserColumnHeader.swift
//  DiskArchive
//

import SwiftUI

struct ColumnBrowserColumnHeader: View {
    let title: String
    var showsLoadingContents = false

    var body: some View {
        HStack(spacing: 8) {
            FadeMaskText(
                text: title,
                applyFadeMask: true,
                font: .system(size: 10, weight: .semibold),
                foreground: DesignColor.text.opacity(0.45)
            )
            .kerning(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsLoadingContents {
                HStack(spacing: 6) {
                    IndexingSpinnerRing()
                        .scaleEffect(0.75)
                        .frame(width: 9, height: 9)
                    Text(LayoutCopy.columnContentsLoading)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
