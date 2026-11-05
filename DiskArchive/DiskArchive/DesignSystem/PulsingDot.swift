//
//  PulsingDot.swift
//  DiskArchive
//
//  todo.0.4.3.013 (Layout 03, 04): pulsierender Punkt – „Wird geprüft“ grün, „Entscheidung ausstehend“ gelb,
//  „Speichermedium fehlerhaft“ rot (Puls 1,6 s wie das Menüleisten-Badge).
//

import SwiftUI

struct PulsingDot: View {
    var color: Color
    var size: CGFloat = 8
    @State private var isDimmed = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(isDimmed ? 0.45 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
    }
}
