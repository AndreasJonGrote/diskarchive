//
//  AppearanceSegmentedControl.swift
//  DiskArchive
//
//  Erscheinungsbild — Hell | Dunkel | Automatisch (Layout 05).
//

import SwiftUI

/// Hell/Dunkel/Automatisch + Day/Night — Layout 05: **3 px** Abstand, jeweils eigener 1-pt-Rahmen.
struct AppearancePickerBlock: View {
    @Binding var selection: AppAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            AppearanceSegmentedControl(selection: $selection)
            DayNightScene(appearance: selection)
        }
    }
}

struct AppearanceSegmentedControl: View {
    @Binding var selection: AppAppearance
    var showsOuterBorder = true

    private static let outerShape = UnevenRoundedRectangle(
        topLeadingRadius: DesignRadius.sm,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: DesignRadius.sm
    )

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(AppAppearance.allCases.enumerated()), id: \.element) { index, mode in
                segment(mode: mode, showsDivider: index > 0)
            }
        }
        .clipShape(Self.outerShape)
        .overlay {
            if showsOuterBorder {
                Self.outerShape
                    .strokeBorder(DesignColor.sidebarActiveBackground, lineWidth: DesignBorder.width)
            }
        }
    }

    private func segment(mode: AppAppearance, showsDivider: Bool) -> some View {
        let isSelected = selection == mode
        return Button {
            selection = mode
            mode.apply()
        } label: {
            Text(mode.title)
                .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? Color.white : DesignColor.text.opacity(0.55))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .frame(minHeight: 28)
                .background {
                    if isSelected {
                        DesignColor.sidebarActiveBackground
                    } else {
                        Color.clear
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .overlay(alignment: .leading) {
            if showsDivider {
                Rectangle()
                    .fill(DesignColor.sidebarActiveBackground)
                    .frame(width: DesignBorder.width)
            }
        }
    }
}
