//
//  IndexingProgressBar.swift
//  diskindex
//
//  Screen 03 — flacher Accent-Balken (% indiziert, kein Storage-Gradient).
//

import SwiftUI

struct IndexingProgressBar: View {
    var progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignColor.neutral300)
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignColor.control)
                    .frame(width: max(0, geometry.size.width * min(1, progress)))
            }
        }
        .frame(height: 4)
    }
}
