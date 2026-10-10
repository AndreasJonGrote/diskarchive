//
//  UncapturedFolderScanDepthHint.swift
//  diskindex
//
//  Layout Screen 07 — Hinweis unter „Inhalt nicht erfasst“.
//

import SwiftUI

struct UncapturedFolderScanDepthHint: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LayoutCopy.uncapturedScanDepthHint)
                .font(.system(size: 11))
                .lineSpacing(2)
                .foregroundStyle(DesignColor.text.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
            Button(LayoutCopy.changeScanDepth) {
                MediumNavigation.openSettings(appState: appState, tab: .files, scrollTarget: .scanDepth)
            }
            .buttonStyle(.plainFullHit)
            .font(.system(size: 11))
            .underline()
            .foregroundStyle(DesignColor.text.opacity(0.55))
            .pointerCursor()
        }
    }
}
