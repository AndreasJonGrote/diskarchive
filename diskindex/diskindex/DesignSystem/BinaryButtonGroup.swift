//
//  BinaryButtonGroup.swift
//  diskindex
//
//  README → Button-Group-Regel (Ja/Nein, An/Pausiert).
//

import SwiftUI

enum BinaryButtonGroupSelection: Equatable {
    case first
    case second
    case none
}

struct BinaryButtonGroup: View {
    let firstTitle: String
    let secondTitle: String
    @Binding var selection: BinaryButtonGroupSelection
    /// „Pausiert“ / „Nein“: Hell `neutral-800`, Dunkel `di-sel` (#4A4949).
    var secondSelectedFill: Color = DesignColor.binaryGroupSecondSelected
    /// Erneuter Klick auf ein **bereits gewähltes** Segment (z. B. Pausentimer toggeln).
    var onReselectLeading: (() -> Void)?
    var onReselectTrailing: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            segment(title: firstTitle, isSelected: selection == .first, position: .leading, fill: firstSelectedFill)
            segment(title: secondTitle, isSelected: selection == .second, position: .trailing, fill: secondSelectedFill)
        }
        .designControlBorder(groupBorderColor)
    }

    private var groupBorderColor: Color {
        switch selection {
        case .first:
            DesignColor.control
        case .second:
            DesignColor.stateOff
        case .none:
            DesignColor.neutral300
        }
    }

    private enum SegmentPosition {
        case leading
        case trailing
    }

    private var firstSelectedFill: Color {
        DesignColor.control
    }

    private func segment(title: String, isSelected: Bool, position: SegmentPosition, fill: Color) -> some View {
        Button {
            if isSelected {
                switch position {
                case .leading: onReselectLeading?()
                case .trailing: onReselectTrailing?()
                }
            } else {
                selection = position == .leading ? .first : .second
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(segmentForeground(isSelected: isSelected, position: position))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .frame(height: 24.4)
                .background {
                    if isSelected {
                        fill
                    } else {
                        Color.clear
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .overlay(alignment: .leading) {
            if position == .trailing {
                Rectangle()
                    .fill(dividerColor)
                    .frame(width: DesignBorder.width)
            }
        }
    }

    private func segmentForeground(isSelected: Bool, position: SegmentPosition) -> Color {
        guard isSelected else { return DesignColor.text.opacity(0.55) }
        if position == .trailing {
            return DesignColor.onSelection
        }
        return DesignColor.onControl
    }

    private var dividerColor: Color {
        switch selection {
        case .first:
            DesignColor.control
        case .second:
            DesignColor.stateOff
        case .none:
            DesignColor.neutral300
        }
    }
}
