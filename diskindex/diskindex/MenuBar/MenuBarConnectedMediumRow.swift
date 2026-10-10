//
//  MenuBarConnectedMediumRow.swift
//  diskindex
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
        let fraction = appState.displayedProgress(medium.id, now: date)
        let reservesTrailingSlot = fraction != nil || (rowHovered && fraction == nil)
        return HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    MediumTypeIcon(medium: medium)
                    rowBody(fraction: fraction)
                }
                .contentShape(Rectangle())
                .pointerCursor()
                .onTapGesture { openColumnBrowserFromPopover() }

                if reservesTrailingSlot {
                    ZStack(alignment: .trailing) {
                        trailingSlot(fraction: fraction)
                    }
                    .frame(width: trailingSlotWidth, height: 24.4, alignment: .center)
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
            Text(medium.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            ZStack(alignment: .leading) {
                Text(verbatim: "Ag")
                    .font(.system(size: 11))
                    .hidden()
                if let fraction {
                    IndexingProgressBar(progress: fraction)
                } else {
                    Text(secondaryLine)
                        .font(.system(size: 11))
                        .foregroundStyle(DesignColor.text.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func trailingSlot(fraction: Double?) -> some View {
        if let fraction {
            indexingToggle(fraction: fraction)
        } else if rowHovered {
            MenuBarGhostButton(title: "Neu indizieren", isEnabled: reindexAllowed) {
                appState.reindexMedium(id: medium.id)
            }
        }
    }

    private var secondaryLine: String {
        switch medium.indexStatus {
        case .indexed:
            IndexedDateFormatting.lastIndexedLine(date: medium.lastIndexActivityAt ?? medium.lastIndexedAt)
        case .error:
            "Kein Zugriff, in den Systemeinstellungen freigeben"
        case .pending:
            if medium.decision == .undecided {
                "Entscheidung ausstehend"
            } else if medium.hasIndex {
                LayoutCopy.indexingInProgress
            } else {
                "Wird indiziert"
            }
        case .indexing:
            ""
        }
    }

    private func indexingToggle(fraction: Double) -> some View {
        Button {
            appState.updateMedium(id: medium.id, persist: true) { $0.showAbsoluteCapacity.toggle() }
        } label: {
            HStack(spacing: 5) {
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
                    .dashedUnderline()
            }
            .foregroundStyle(DesignColor.control)
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
    }

    func indexingProgressLabel(fraction: Double) -> String {
        if medium.showAbsoluteCapacity {
            let total = medium.capacityTotalBytes
            let done = Int64((fraction * Double(total)).rounded())
            return "\(Self.byteLabel(done)) / \(Self.byteLabel(total))"
        }
        return "\(Int(floor(fraction * 100))) %"
    }

    private static func byteLabel(_ count: Int64) -> String {
        ByteCountFormatter.storage.string(fromByteCount: count)
    }

    private func openColumnBrowserFromPopover() {
        MediumNavigation.openColumnBrowser(for: medium.id, appState: appState)
        MenuBarPopoverDismiss.openMainWindow(appState: appState)
    }
}
