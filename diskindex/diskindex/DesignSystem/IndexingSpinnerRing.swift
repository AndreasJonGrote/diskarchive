//
//  IndexingSpinnerRing.swift
//  diskindex
//

import SwiftUI

/// Rotierender Ring, oberes Viertel offen, 0,9 s linear.
/// Grün im Status-Chip; schwarz (`control`, 2 pt) in der Popover-Zeile (Layout Sektion 03).
struct IndexingSpinnerRing: View {
    var color: Color = DesignColor.stateOnline
    var lineWidth: CGFloat = 1.4

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}
