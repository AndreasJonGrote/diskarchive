//
//  DashboardView.swift
//  diskindex
//
//  README Screen 04 — Übersicht.
//

import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.indexedMedia.isEmpty {
            EmptyStateView(title: EmptyStateCopy.noMediumTitle, message: EmptyStateCopy.noMediumMessage)
        } else {
            GeometryReader { geo in
                let contentWidth = geo.size.width - DashboardGridLayout.spacing * 2
                let columns = DashboardGridLayout.columnCount(containerWidth: contentWidth)
                let cardWidth = DashboardGridLayout.cellWidth(containerWidth: contentWidth, columns: columns)
                let rows = chunked(appState.indexedMedia, columns: columns)
                ScrollView {
                    VStack(alignment: .leading, spacing: DashboardGridLayout.spacing) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            DashboardEqualHeightRowLayout(
                                spacing: DashboardGridLayout.spacing,
                                cardWidth: cardWidth
                            ) {
                                ForEach(row) { medium in
                                    MediumDashboardCard(medium: medium)
                                        .transaction { $0.animation = nil }
                                }
                            }
                        }
                    }
                    .padding(DashboardGridLayout.spacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func chunked(_ media: [Medium], columns: Int) -> [[Medium]] {
        stride(from: 0, to: media.count, by: columns).map { start in
            Array(media[start..<min(start + columns, media.count)])
        }
    }
}

#if DEBUG
#Preview {
    let state = AppState()
    state.media = PreviewData.media
    return DashboardView()
        .environment(state)
        .frame(width: 900, height: 640)
}
#endif
