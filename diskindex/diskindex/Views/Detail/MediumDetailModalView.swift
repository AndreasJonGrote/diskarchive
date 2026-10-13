//
//  MediumDetailModalView.swift
//  diskindex
//
//  README Screen 05 — Detail-Overlay.
//

import SwiftUI

struct MediumDetailModalView: View {
    @Environment(AppState.self) private var appState
    let mediumID: UUID

    private var medium: Medium? {
        appState.medium(with: mediumID)
    }

    var body: some View {
        Group {
            if let medium {
                modalContent(medium: medium)
            } else {
                Color.clear
                    .onAppear { appState.detailMediumID = nil }
            }
        }
    }

    private func modalContent(medium: Medium) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(medium: medium)

            statsTable(medium: medium)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            actionButtonRow(medium: medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
        }
        .frame(width: 540)
        .background(DesignColor.bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.lg)
                .strokeBorder(DesignColor.neutral300, lineWidth: DesignBorder.width)
        }
        // Schatten nur für die Gesamtform, nicht für jede Unteransicht.
        .compositingGroup()
        .shadow(color: DesignColor.shadow.opacity(0.22), radius: 16, y: 12)
    }

    private func header(medium: Medium) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MediumTypeIcon(medium: medium, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(medium.name)
                    .font(.system(size: 18, weight: .bold))
                Text(medium.connectionDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignColor.text.opacity(0.55))
            }

            Spacer(minLength: 8)

            StatusChip(medium: medium)

            Button {
                appState.detailMediumID = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignColor.neutral700)
                    .frame(width: 24, height: 24)
                    .designControlBorder(DesignBorder.secondaryControlBorderColor)
            }
            .buttonStyle(.plainFullHit)
            .pointerCursor()
            .accessibilityLabel(LayoutCopy.a11yClose)
        }
        .padding(16)
    }

    private func statsTable(medium: Medium) -> some View {
        VStack(spacing: 0) {
            detailRow(label: LayoutCopy.total, value: medium.totalCapacityLabel)
            detailRow(label: LayoutCopy.usedFree, value: medium.usedFreeLabel)
            detailRow(label: LayoutCopy.files, value: medium.filesLabel)
            detailRow(label: LayoutCopy.folders, value: medium.foldersLabel)
            detailRow(label: LayoutCopy.lastSeen, value: medium.lastSeenDescription(now: .now))

            settingsRow(label: LayoutCopy.shouldIndex, isLast: true) {
                EquatableView(content: AllowIndexingBinaryGroup(
                    mediumID: medium.id,
                    allowIndexing: medium.allowIndexing,
                    isPending: medium.indexStatus == .pending,
                    isEnabled: appState.featureAccess.canWriteIndex
                ) { allow in
                    appState.updateMedium(id: medium.id, persist: true) {
                        $0.decision = allow ? .index : .dontIndex
                        $0.allowIndexing = allow
                    }
                })
            }
        }
        .background(DesignColor.text.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.md)
                .strokeBorder(DesignColor.neutral200, lineWidth: DesignBorder.width)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(DesignColor.text.opacity(0.55))
                .frame(width: 180, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { rowDivider }
    }

    private func settingsRow<Control: View>(
        label: String,
        isLast: Bool = false,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(DesignColor.text.opacity(0.55))
                .frame(width: 180, alignment: .leading)
            Spacer(minLength: 8)
            control()
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            if !isLast { rowDivider }
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(DesignColor.neutral200)
            .frame(height: DesignBorder.width)
    }

    private func actionButtonRow(medium: Medium) -> some View {
        HStack {
            ConfirmButton(title: LayoutCopy.forget, tone: .destructive) {
                appState.forgetMedium(id: medium.id)
            }
            .disabled(!appState.featureAccess.canWriteIndex)
            .opacity(appState.featureAccess.canWriteIndex ? 1 : 0.45)

            Spacer(minLength: 12)

            let allowed = appState.canReindex(medium.id) && appState.reindexGateTick >= .distantPast
            Button(LayoutCopy.reindex) {
                appState.reindexMedium(id: medium.id)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(!allowed)
            .opacity(allowed ? 1 : 0.45)
            .pointerCursor(allowed)

            Button(LayoutCopy.showContent) {
                MediumNavigation.openColumnBrowser(for: medium.id, appState: appState)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!medium.hasIndex)
            .opacity(medium.hasIndex ? 1 : 0.45)
            .pointerCursor()
        }
    }

}
