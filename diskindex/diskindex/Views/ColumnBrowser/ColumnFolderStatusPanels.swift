//
//  ColumnFolderStatusPanels.swift
//  diskindex
//
//  Layout Screen 07 — Sonderzustände in der Ordnerspalte (Aufgabe 139).
//

import SwiftUI

struct FolderPendingIndexingHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IndexingSpinnerRing(
                color: DesignColor.stateOnline,
                lineWidth: 2.5
            )
            .padding(1.25)
            .frame(width: 20, height: 20)
            .padding(.bottom, 5)
            Text(LayoutCopy.indexingInProgress)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignColor.text)
                .frame(minHeight: 18.6, alignment: .leading)
                .padding(.bottom, 6)
            Text(LayoutCopy.folderPendingIndexingBody)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(DesignColor.text.opacity(0.60))
                .frame(maxWidth: 230, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct FolderUncapturedColumnHint: View {
    let reason: ColumnFolderUncapturedReason
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("IconWarningCircle")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 25, height: 25)
                .frame(width: 20, height: 20)
                .padding(.bottom, 5)
                .foregroundStyle(Color(red: 237 / 255, green: 161 / 255, blue: 45 / 255))
            Text(LayoutCopy.folderNotIndexedTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignColor.text)
                .frame(minHeight: 18.6, alignment: .leading)
                .padding(.bottom, 6)
            hintBody
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(DesignColor.text.opacity(0.60))
                .frame(maxWidth: 230, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var hintBody: some View {
        switch reason {
        case .scanDepth:
            UncapturedFolderScanDepthInlineHint()
        case .excluded:
            UncapturedFolderContextHint(reason: .excluded)
        case .unreadable:
            UncapturedFolderContextHint(reason: .unreadable)
        }
    }
}

/// Scan-Tiefe: Erklärung, Link darunter (Layout 07).
struct UncapturedFolderScanDepthInlineHint: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LayoutCopy.uncapturedScanDepthHint)
                .font(.system(size: 11))
                .lineSpacing(2)
                .foregroundStyle(DesignColor.text.opacity(0.60))
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
