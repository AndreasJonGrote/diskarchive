//
//  MediumDashboardCard.swift
//  diskindex
//
//  README Screen 04 — Medium-Karte.
//

import SwiftUI

struct MediumDashboardCard: View {
    @Environment(AppState.self) private var appState
    let medium: Medium

    var body: some View {
        let isOffline = medium.connectionStatus == .offline
        let isError = medium.indexStatus == .error

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                MediumTypeIcon(medium: medium, size: 26)
                Spacer(minLength: 8)
                // bug.0.4.211: der Chip bleibt ganz; die Zeitzeilen kürzen mit „…“, die Kachel wird nie breiter als ihre Zelle.
                StatusChip(medium: medium)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text(medium.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DesignColor.text)
                .lineLimit(2)

            Text(medium.dashboardSpecLine)
                .font(.system(size: 12))
                .foregroundStyle(DesignColor.text.opacity(0.65))
                .lineLimit(2)

            metaLine(medium: medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(14)
        .background(DesignColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.md)
                .strokeBorder(isError ? DesignColor.stateError : DesignColor.neutral300, lineWidth: DesignBorder.width)
        }
        .opacity(isOffline ? 0.55 : 1)
        .contentShape(RoundedRectangle(cornerRadius: DesignRadius.md))
        .pointerCursor()
        .onTapGesture {
            MediumNavigation.openColumnBrowser(for: medium.id, appState: appState)
        }
        .objectContextMenu(.fromMedium(medium), highlightCornerRadius: DesignRadius.md)
    }

    @ViewBuilder
    private func metaLine(medium: Medium) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if medium.dashboardShowsRetryLine {
                Text(LayoutCopy.dashboardErrorRetry)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let occupancy = medium.occupancyLabel(showAbsolute: medium.showAbsoluteCapacity) {
                occupancyToggle(medium: medium, occupancy: occupancy)
                    .lineLimit(1)
            } else {
                Color.clear.frame(height: 1)
            }
            Spacer(minLength: 4)
            metaTimeBadge(medium: medium)
        }
        .font(.system(size: 11))
        .foregroundStyle(DesignColor.text.opacity(0.55))
    }

    private func occupancyToggle(medium: Medium, occupancy: String) -> some View {
        Button {
            appState.updateMedium(id: medium.id, persist: true) { $0.showAbsoluteCapacity.toggle() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(occupancy).dashedUnderline()
                Text(LayoutCopy.dashboardOccupiedSuffix)
            }
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
    }

    @ViewBuilder
    private func metaTimeBadge(medium: Medium) -> some View {
        if medium.showsLastIndexedLine {
            HStack(spacing: 4) {
                Image("IconClock")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                Text(
                    IndexedDateFormatting.lastIndexedLine(
                        date: medium.lastIndexActivityAt ?? medium.lastIndexedAt
                    )
                )
                .lineLimit(1)
            }
        } else {
            lastSeenBadge(medium: medium)
        }
    }

    private func lastSeenBadge(medium: Medium) -> some View {
        HStack(spacing: 4) {
            Image("IconClock")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
            Text(medium.lastSeenDescription())
                .lineLimit(1)
        }
    }
}

#if DEBUG
#Preview {
    MediumDashboardCard(medium: PreviewData.media[0])
        .environment(AppState())
        .frame(width: 240)
        .padding()
}
#endif
