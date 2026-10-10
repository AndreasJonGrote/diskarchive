//
//  DashboardEqualHeightRowLayout.swift
//  diskindex
//
//  Aufgabe 125 — gleiche Kartenhöhe ohne PreferenceKey-Rückkopplung.
//

import SwiftUI

struct DashboardEqualHeightRowLayout: Layout {
    var spacing: CGFloat
    var cardWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else {
            return CGSize(width: proposal.width ?? 0, height: 0)
        }
        let heights = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: cardWidth, height: nil)).height
        }
        let height = heights.max() ?? 0
        let width = CGFloat(subviews.count) * cardWidth
            + CGFloat(max(0, subviews.count - 1)) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let heights = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: cardWidth, height: nil)).height
        }
        let rowHeight = heights.max() ?? bounds.height
        var x = bounds.minX
        for subview in subviews {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: cardWidth, height: rowHeight)
            )
            x += cardWidth + spacing
        }
    }
}
