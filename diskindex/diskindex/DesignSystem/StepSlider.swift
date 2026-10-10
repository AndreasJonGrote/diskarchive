//
//  StepSlider.swift
//  diskindex
//
//  Stufen-Slider mit Beschriftung exakt unter den Stopps (Aufgabe 22.11).
//  Selbst gezeichnet, damit der Knopfradius bekannt ist: Stopp i liegt bei r + (Breite − 2r) · i/(n−1),
//  wie im Layout (`calc(8px + (100% − 16px) · i/4)`).
//

import SwiftUI

struct StepSlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    /// Eine Beschriftung pro Stufe.
    let labels: [String]

    private let knobDiameter: CGFloat = 16
    private let trackHeight: CGFloat = 4
    private let labelHeight: CGFloat = 14
    private let labelSpacing: CGFloat = 2

    private var knobRadius: CGFloat { knobDiameter / 2 }
    private var stepCount: Int { range.count }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let knobX = x(forStep: value - range.lowerBound, width: width)

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(DesignColor.neutral300)
                    .frame(width: max(0, width - knobDiameter), height: trackHeight)
                    .offset(x: knobRadius, y: knobRadius - trackHeight / 2)

                Capsule()
                    .fill(DesignColor.control)
                    .frame(width: max(0, knobX - knobRadius), height: trackHeight)
                    .offset(x: knobRadius, y: knobRadius - trackHeight / 2)

                Circle()
                    .fill(DesignColor.control)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .offset(x: knobX - knobRadius)

                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundStyle(DesignColor.text.opacity(0.5))
                        .fixedSize()
                        .position(x: x(forStep: index, width: width), y: knobDiameter + labelSpacing + labelHeight / 2)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    value = step(at: drag.location.x, width: width) + range.lowerBound
                }
            )
        }
        .frame(height: knobDiameter + labelSpacing + labelHeight)
        .accessibilityElement()
        .accessibilityValue(labels[safe: value - range.lowerBound] ?? "\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + 1)
            case .decrement: value = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }

    private func x(forStep step: Int, width: CGFloat) -> CGFloat {
        guard stepCount > 1 else { return knobRadius }
        return knobRadius + (width - knobDiameter) * CGFloat(step) / CGFloat(stepCount - 1)
    }

    private func step(at x: CGFloat, width: CGFloat) -> Int {
        guard stepCount > 1, width > knobDiameter else { return 0 }
        let fraction = (x - knobRadius) / (width - knobDiameter)
        return min(stepCount - 1, max(0, Int((fraction * CGFloat(stepCount - 1)).rounded())))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
