//
//  MenuBarStatusBadgeView.swift
//  DiskArchive
//
//  README Screen 02 — Status-Badge unten rechts am Menüleisten-Glyph.
//

import SwiftUI

struct MenuBarStatusBadgeView: View {
    let state: MenuBarBadgePreview

    private let badgeSize: CGFloat = 12

    var body: some View {
        switch state {
        case .idle, .syncing:
            EmptyView()
        case .indexing:
            badgeContainer {
                IndexingSpinnerRing()
                    .padding(2)
            }
        case .newlyDetected:
            badgeContainer {
                MenuBarPulsingDot()
            }
        case .paused:
            badgeContainer {
                MenuBarPausedMark()
            }
        case .error:
            badgeContainer {
                MenuBarErrorMark()
            }
        }
    }

    @ViewBuilder
    private func badgeContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
            content()
        }
        .frame(width: badgeSize, height: badgeSize)
    }
}

// MARK: - Badge contents

private struct MenuBarPulsingDot: View {
    @State private var isDimmed = false

    var body: some View {
        Circle()
            .fill(DesignColor.stateOnline)
            .padding(3)
            .opacity(isDimmed ? 0.45 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
    }
}

private struct MenuBarPausedMark: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(DesignColor.menuBarBadgeInk)
                .frame(width: 5.5, height: 1)
                .rotationEffect(.degrees(45))
            Capsule()
                .fill(DesignColor.menuBarBadgeInk)
                .frame(width: 5.5, height: 1)
                .rotationEffect(.degrees(-45))
        }
    }
}

private struct MenuBarErrorMark: View {
    var body: some View {
        Text("!")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(DesignColor.stateError)
    }
}

#Preview("Badges") {
    HStack(spacing: 16) {
        ForEach(MenuBarBadgePreview.allCases) { state in
            VStack {
                MenuBarStatusBadgeView(state: state)
                    .padding(8)
                    .background(Color.gray.opacity(0.3))
                Text(state.rawValue).font(.caption2)
            }
        }
    }
    .padding()
}
