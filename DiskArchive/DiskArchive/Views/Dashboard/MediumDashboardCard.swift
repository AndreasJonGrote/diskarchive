//
//  MediumDashboardCard.swift
//  DiskArchive
//
//  todo.0.4.3.008 (Layout 04, 04.07) — Medium-Kachel: oben links das Medien-Icon, oben rechts der Status-Chip; darunter
//  der Name (bei eigenem Namen klein der Originalname); unten „{Kapazität} · {n} Dateien“ und die Zeile „Zuletzt gesehen“
//  · Belegung. Offline blasser, Fehler mit rotem Rahmen, nichts bricht um (rechts auslaufend).
//

import SwiftUI

struct MediumDashboardCard: View {
    @Environment(AppState.self) private var appState
    let medium: Medium
    @State private var isHovered = false

    var body: some View {
        let isOffline = medium.connectionStatus == .offline
        let isError = medium.indexStatus == .error

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                MediumTypeIcon(medium: medium, size: 26)
                Spacer(minLength: 8)
                // bug.0.4.211: der Chip bleibt ganz; die Zeilen darunter laufen aus, die Kachel wird nie breiter als ihre Zelle.
                // todo.0.4.3.011 (Layout 04): beim Hover fährt rechts neben dem Chip der Auswerfen-Knopf heraus.
                HStack(spacing: 6) {
                    StatusChip(medium: medium)
                    if isHovered, !isOffline {
                        EjectButton(mediumID: medium.id)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .animation(.easeOut(duration: 0.18), value: isHovered)
            }

            VStack(alignment: .leading, spacing: 2) {
                FadeMaskText(
                    text: medium.shownName,
                    applyFadeMask: true,
                    font: DesignFont.heading(size: 17)
                )
                if medium.customName != nil {
                    FadeMaskText(
                        text: medium.name,
                        applyFadeMask: true,
                        font: .system(size: 11),
                        foreground: DesignColor.text.opacity(0.5)
                    )
                }
            }

            Spacer(minLength: 0)

            // Layout `card-body`: 13 pt, 80 %, 12 pt Luft darüber, 6 pt näher an der Zeile darunter.
            FadeMaskText(
                text: medium.dashboardSpecLine,
                applyFadeMask: true,
                font: .system(size: 13),
                foreground: DesignColor.text.opacity(0.8)
            )
            .padding(.top, 12)
            .padding(.bottom, -6)

            metaLine
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(DesignColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.md)
                .strokeBorder(isError ? DesignColor.stateError : DesignColor.divider, lineWidth: DesignBorder.width)
        }
        // Kein Schatten (Layout `elev-md`): er färbt Pixel außerhalb der Zelle, die Abstände wären nicht mehr 16 pt
        // (bug.0.4.211, Korrektur K1 Paket 59).
        .opacity(isOffline ? 0.55 : 1)
        .contentShape(RoundedRectangle(cornerRadius: DesignRadius.md))
        .pointerCursor()
        .onHover { isHovered = $0 }
        .onTapGesture {
            MediumNavigation.openColumnBrowser(for: medium.id, appState: appState)
        }
        .objectContextMenu(.fromMedium(medium), highlightCornerRadius: DesignRadius.md)
    }

    /// Layout `card-meta`: 11 pt, 50 %, Abstand 6, Zeilenhöhe 14.
    @ViewBuilder
    private var metaLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            switch medium.dashboardMetaLine {
            case .retry:
                // bug.0.4.3.002: „Fehler · erneut versuchen“, der zweite Teil ist ein Link (Neuindizierung wie in 14).
                Text(DashboardRetryLine.status)
                    .foregroundStyle(DesignColor.text)
                separator
                DashboardRetryLink(mediumID: medium.id)
            case .lastSeen(let occupancy):
                lastSeenBadge
                if let occupancy {
                    separator
                    occupancyToggle(occupancy: occupancy)
                }
            }
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .foregroundStyle(DesignColor.text.opacity(0.5))
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private var separator: some View {
        Text(verbatim: "·")
            .foregroundStyle(DesignColor.text.opacity(0.55))
    }

    private var lastSeenBadge: some View {
        HStack(spacing: 4) {
            Image("IconClock")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
            Text(medium.lastSeenDescription())
        }
        .foregroundStyle(DesignColor.text.opacity(0.55))
        .fixedSize()
    }

    private func occupancyToggle(occupancy: String) -> some View {
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
}

/// bug.0.4.3.002: Teile von „Fehler · erneut versuchen“ (Sektion 20, ein Text). Der Link ist der Teil nach dem Punkt.
enum DashboardRetryLine {
    private static var parts: [String] {
        LayoutCopy.dashboardErrorRetry.components(separatedBy: " · ")
    }

    static var status: String { parts.first ?? LayoutCopy.dashboardErrorRetry }
    static var link: String { parts.count > 1 ? parts[1] : LayoutCopy.dashboardErrorRetry }
}

/// „erneut versuchen“: Textfarbe, beim Hover unterstrichen, Hand-Cursor; startet die Indizierung sofort neu wie
/// „Erneut versuchen“ im Indizierungsfehler (14).
struct DashboardRetryLink: View {
    @Environment(AppState.self) private var appState
    let mediumID: UUID
    @State private var isHovered = false

    var body: some View {
        Button {
            appState.retryIndexing(mediumID: mediumID)
        } label: {
            Text(DashboardRetryLine.link)
                .underline(isHovered)
                .foregroundStyle(DesignColor.text)
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .onHover { isHovered = $0 }
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
