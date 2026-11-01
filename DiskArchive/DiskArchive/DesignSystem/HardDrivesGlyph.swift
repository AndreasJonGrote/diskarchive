//
//  HardDrivesGlyph.swift
//  DiskArchive
//
//  Phosphor „hard-drives“ — Geometrie aus Asset (1:1 SVG).
//

import SwiftUI

struct HardDrivesGlyph: View {
    var size: CGFloat = 18
    var color: Color = DesignColor.text

    var body: some View {
        Image("MenuBarHardDrives")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}

#Preview {
    HardDrivesGlyph()
        .padding()
        .background(Color.gray.opacity(0.3))
}
