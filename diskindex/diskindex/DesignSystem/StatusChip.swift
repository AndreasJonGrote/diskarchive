//
//  StatusChip.swift
//  diskindex
//
//  Aufgabe 19.2 — ein Chip-Rezept für alle Status-Chips.
//

import SwiftUI

struct StatusChip: View {
    let medium: Medium
    @Environment(AppState.self) private var appState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !tracksProgress)) { context in
            chipBody(at: context.date)
        }
    }

    private var tracksProgress: Bool {
        medium.indexStatus == .indexing || appState.hasLiveProgress(medium.id)
    }

    private func chipBody(at date: Date) -> some View {
        let kind = MediumChip.presentation(
            medium,
            globalAutoIndexPaused: appState.globalAutoIndexPaused,
            displayedFraction: appState.displayedProgress(medium.id, now: date)
        )
        let color = roleColor(kind)
        return HStack(spacing: 4) {
            if appState.globalAutoIndexPaused, medium.indexStatus == .indexing || appState.hasLiveProgress(medium.id) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 7, weight: .bold))
            } else if kind.spinner {
                IndexingSpinnerRing()
                    .scaleEffect(0.65)
                    .frame(width: 7, height: 7)
            }
            chipLabel(kind, color: color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .frame(minHeight: 23.5)
        .background(kind.dashed ? Color.clear : DesignColor.chipFill(color))
        .overlay {
            if kind.dashed {
                RoundedRectangle(cornerRadius: DesignRadius.sm)
                    .strokeBorder(
                        DesignColor.chipBorder(color),
                        style: StrokeStyle(lineWidth: DesignBorder.width, dash: [3, 2])
                    )
            } else {
                RoundedRectangle(cornerRadius: DesignRadius.sm)
                    .strokeBorder(DesignColor.chipBorder(color), lineWidth: DesignBorder.width)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }

    @ViewBuilder
    private func chipLabel(_ kind: MediumChip.Presentation, color: Color) -> some View {
        let font = Font.system(size: 10, weight: medium.indexStatus == .error ? .bold : .regular)
        Text(kind.text)
            .font(font)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(color)
    }

    private func roleColor(_ kind: MediumChip.Presentation) -> Color {
        if kind.offlineGray { return DesignColor.stateOff }
        if kind.error { return DesignColor.stateError }
        return DesignColor.stateOnline
    }
}

enum MediumChip {
    struct Presentation: Equatable {
        var text: String
        var dashed: Bool
        var offlineGray: Bool
        var error: Bool
        var spinner: Bool
    }

    static func presentation(
        _ medium: Medium,
        globalAutoIndexPaused: Bool = false,
        displayedFraction: Double? = nil
    ) -> Presentation {
        let connected = medium.connectionStatus == .connected
        let percent = IndexProgress.percent(displayedFraction ?? medium.indexProgressFraction)
        let stillShowing = displayedFraction != nil
        if !medium.hasIndex {
            if medium.decision.refusesIndexing {
                return Presentation(text: LayoutCopy.chipNotAllowed, dashed: false, offlineGray: true, error: false, spinner: false)
            }
            return Presentation(text: LayoutCopy.chipPending, dashed: true, offlineGray: false, error: false, spinner: false)
        }
        if medium.indexStatus == .error {
            return Presentation(
                text: connected ? LayoutCopy.chipError : LayoutCopy.chipErrorOffline,
                dashed: !connected,
                offlineGray: !connected,
                error: connected,
                spinner: false
            )
        }
        let complete = medium.indexStatus == .indexed && !stillShowing
        if !connected {
            if complete {
                return Presentation(text: LayoutCopy.chipOffline, dashed: true, offlineGray: true, error: false, spinner: false)
            }
            return Presentation(
                text: LayoutCopy.chipPercentIndexedOffline(percent),
                dashed: true,
                offlineGray: true,
                error: false,
                spinner: false
            )
        }
        if complete {
            return Presentation(text: LayoutCopy.chipOnline, dashed: false, offlineGray: false, error: false, spinner: false)
        }
        let spinner = (medium.indexStatus == .indexing || stillShowing) && !globalAutoIndexPaused
        return Presentation(
            text: LayoutCopy.chipPercentIndexed(percent),
            dashed: true,
            offlineGray: false,
            error: false,
            spinner: spinner
        )
    }
}
