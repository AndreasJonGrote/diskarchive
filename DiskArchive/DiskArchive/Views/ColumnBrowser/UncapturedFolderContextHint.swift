//
//  UncapturedFolderContextHint.swift
//  DiskArchive
//

import SwiftUI

struct UncapturedFolderContextHint: View {
    let reason: ColumnFolderUncapturedReason
    @Environment(AppState.self) private var appState

    var body: some View {
        switch reason {
        case .scanDepth:
            UncapturedFolderScanDepthHint()
        case .excluded:
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(LayoutCopy.folderExcluded)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignColor.text.opacity(0.55))
                Text(" ")
                Button(LayoutCopy.folderChangeExclusions) {
                    MediumNavigation.openSettings(appState: appState, tab: .files)
                }
                .buttonStyle(.plainFullHit)
                .font(.system(size: 11))
                .underline()
                .foregroundStyle(DesignColor.text.opacity(0.55))
                .pointerCursor()
            }
        case .unreadable:
            Text(LayoutCopy.folderUnreadable)
                .font(.system(size: 11))
                .foregroundStyle(DesignColor.text.opacity(0.55))
        }
    }
}
