//
//  DashboardGridLayout.swift
//  diskindex
//

import CoreGraphics

enum DashboardGridLayout {
    static let minCardWidth: CGFloat = 200
    static let maxCardWidth: CGFloat = 255
    static let spacing: CGFloat = 16

    static func columnCount(containerWidth: CGFloat) -> Int {
        guard containerWidth > 0 else { return 1 }
        return max(1, Int(floor((containerWidth + spacing) / (minCardWidth + spacing))))
    }

    /// Zellenbreite im Raster — Karten werden nicht breiter als `maxCardWidth`.
    static func cellWidth(containerWidth: CGFloat, columns: Int) -> CGFloat {
        let columns = max(1, columns)
        let raw = (containerWidth - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        return min(maxCardWidth, max(minCardWidth, raw))
    }
}
