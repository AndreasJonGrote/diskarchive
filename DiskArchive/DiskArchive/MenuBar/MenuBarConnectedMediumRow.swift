//
//  MenuBarConnectedMediumRow.swift
//  DiskArchive
//

import SwiftUI

struct MenuBarConnectedMediumRow: View {
    @Environment(AppState.self) private var appState
    let medium: Medium
    var forceHover = false

    @State private var isHovered = false

    private let trailingSlotWidth: CGFloat = 108

    private var rowHovered: Bool { isHovered || forceHover }

    private var reindexAllowed: Bool {
        _ = appState.reindexGateTick
        return appState.canReindex(medium.id)
    }

    private var showsLiveProgress: Bool {
        medium.indexStatus == .indexing || appState.hasLiveProgress(medium.id)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !showsLiveProgress)) { context in
            row(at: context.date)
        }
    }

    private func row(at date: Date) -> some View {
        // todo.0.4.3.013: „Wird geprüft“ zeigt keinen Prozentwert, auch keinen gespeicherten.
        let checking = medium.isChecking(paused: appState.globalAutoIndexPaused)
        let fraction = checking ? nil : appState.displayedProgress(medium.id, now: date)
        let canShowReindex = medium.decision == .index && reindexAllowed
        let reservesTrailingSlot = fraction != nil || (rowHovered && fraction == nil && canShowReindex)
        return HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    MediumTypeIcon(medium: medium)
                    rowBody(fraction: fraction)
                }
                .contentShape(Rectangle())
                .pointerCursor()
                .onTapGesture { rowPrimaryTap() }

                if reservesTrailingSlot {
                    ZStack(alignment: .center) {
                        trailingSlot(fraction: fraction)
                    }
                    .frame(width: trailingSlotWidth, height: 24.4, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: MenuBarPopoverLayout.rowHeight(for: medium), maxHeight: MenuBarPopoverLayout.rowHeight(for: medium), alignment: .leading)
        .background {
            if isHovered || forceHover {
                RoundedRectangle(cornerRadius: DesignRadius.sm)
                    .fill(DesignColor.text.opacity(0.06))
                    .padding(.horizontal, -6)
            }
        }
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private func rowBody(fraction: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // todo.0.4.3.007: eigener Name, leise der Originalname (Layout 03).
            FadeMaskText(
                text: medium.listLabel.name,
                applyFadeMask: true,
                font: .system(size: 13, weight: .semibold),
                suffix: medium.listLabel.original
            )

            // Die versteckte Zeile gibt die Höhe vor; jeder Zustand liegt darüber (die Zeile springt nie).
            Text(verbatim: "Ag")
                .font(.system(size: 11))
                .hidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                switch medium.popoverStatusLine(paused: appState.globalAutoIndexPaused, hasProgress: fraction != nil) {
                case .progress:
                    IndexingProgressBar(progress: fraction ?? 0)
                case .checking:
                    statusDot(DesignColor.stateOnline, LayoutCopy.mediumChecking)
                case .decisionPending:
                    statusDot(DesignColor.stateIgnored, LayoutCopy.mediumDecisionPending)
                case .hasErrors:
                    statusDot(DesignColor.stateError, LayoutCopy.mediumHasErrors)
                case .lastIndexed(let date):
                    // todo.0.4.3.014 (Layout 03): Uhr-Icon und Datum statt „Zuletzt indiziert: …“.
                    HStack(spacing: 4) {
                        Image("IconClock")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text(date)
                            .lineLimit(1)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(DesignColor.text.opacity(0.55))
                case .text(let text):
                    Text(text)
                        .font(.system(size: 11))
                        .foregroundStyle(DesignColor.text.opacity(0.55))
                        .lineLimit(1)
                }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// todo.0.4.3.013 (Layout 03): pulsierender Punkt 8 pt, Abstand 6, Text 11 pt leise.
    private func statusDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            PulsingDot(color: color, size: 8)
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 11))
        .foregroundStyle(DesignColor.text.opacity(0.55))
    }

    @ViewBuilder
    private func trailingSlot(fraction: Double?) -> some View {
        if let fraction {
            indexingChip(fraction: fraction)
        } else if rowHovered, medium.decision == .index {
            MenuBarGhostButton(title: LayoutCopy.reindex, isEnabled: reindexAllowed) {
                appState.reindexMedium(id: medium.id)
            }
        }
    }

    /// todo.0.4.3.014 (Layout 03): nur während eines Laufs – Spinner (in der Pause das Pause-Icon) und Prozent; der
    /// Umschalter zwischen Bytes und Prozent entfällt.
    private func indexingChip(fraction: Double) -> some View {
        HStack(spacing: 6) {
            if appState.globalAutoIndexPaused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 11, height: 11)
            } else {
                IndexingSpinnerRing(color: DesignColor.control, lineWidth: 2)
                    .frame(width: 11, height: 11)
            }
            Text(indexingProgressLabel(fraction: fraction))
                .font(.system(size: 11))
        }
        .foregroundStyle(DesignColor.control)
    }

    func indexingProgressLabel(fraction: Double) -> String {
        "\(IndexProgress.percent(fraction)) %"
    }

    private func rowPrimaryTap() {
        // bug.0.4.215: offene Rückfrage „Ersetzt dieses Medium?“ zuerst – nicht der Erkennungs-Dialog daneben.
        if appState.replaceMediumPrompt?.newID == medium.id {
            AppWindowPresenter.revealReplaceMediumPrompt(appState: appState)
            return
        }
        // todo.0.4.026: auch ein erneut gefragtes Medium öffnet zuerst den Erkennungs-Dialog.
        // todo.0.4.3.013: „Entscheidung ausstehend“ öffnet den Dialog genau dieses Mediums (vorne).
        if medium.decision == .undecided || appState.needsNewMediumDialog(medium.id) {
            appState.enqueueNewMediumDecision(medium.id)
            AppWindowPresenter.openNewMedium(appState: appState, front: medium.id)
            return
        }
        openColumnBrowserFromPopover()
    }

    private func openColumnBrowserFromPopover() {
        MediumNavigation.openColumnBrowser(for: medium.id, appState: appState)
        MenuBarPopoverDismiss.openMainWindow(appState: appState)
    }
}
