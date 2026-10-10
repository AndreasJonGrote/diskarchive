//
//  FolderContentsLoadingHint.swift
//  diskindex
//
//  Layout Screen 07 — „Inhalte werden geladen“ (Aufgabe 139).
//

import SwiftUI

struct FolderContentsLoadingHint: View {
    let loaded: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IndexingSpinnerRing(color: DesignColor.text, lineWidth: 2.5)
                .padding(1.25)
                .frame(width: 20, height: 20)
                .padding(.bottom, 5)
            Text(LayoutCopy.columnContentsLoading)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignColor.text)
                .frame(minHeight: 18.6, alignment: .leading)
                .padding(.bottom, 6)
            Text(LayoutCopy.folderLoadingManyObjects)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(DesignColor.text.opacity(0.60))
                .frame(maxWidth: 230, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if total > 0 {
                Text(LayoutCopy.folderLoadingProgress(loaded: loaded, total: total))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(DesignColor.text.opacity(0.75))
                    .frame(minHeight: 17.05, alignment: .leading)
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
