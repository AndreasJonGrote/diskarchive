//
//  DayNightScene.swift
//  diskindex
//

import SwiftUI

struct DayNightScene: View {
    var appearance: AppAppearance
    var showsOuterBorder = true

    private static let outerShape = UnevenRoundedRectangle(
        topLeadingRadius: 0,
        bottomLeadingRadius: DesignRadius.sm,
        bottomTrailingRadius: DesignRadius.sm,
        topTrailingRadius: 0
    )

    private var night: CGFloat {
        switch appearance {
        case .light: 0
        case .system: 0.5
        case .dark: 1
        }
    }

    private var sunOrigin: (CGFloat, CGFloat) {
        switch appearance {
        case .dark: (0.18, 70)
        case .light, .system: (0.22, 14)
        }
    }

    private var moonOrigin: (CGFloat, CGFloat) {
        switch appearance {
        case .light: (0.76, 70)
        case .dark: (0.46, 14)
        case .system: (0.76, 14)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                Color(red: 0.953, green: 0.937, blue: 0.902)
                Color(red: 0.110, green: 0.133, blue: 0.200)
                    .frame(width: width * night)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                Rectangle()
                    .fill(Color(red: 0.541, green: 0.522, blue: 0.467).opacity(0.35))
                    .frame(height: 12)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                Circle()
                    .fill(Color(red: 0.929, green: 0.631, blue: 0.176))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(Color(red: 0.929, green: 0.631, blue: 0.176).opacity(0.18), lineWidth: 5)
                            .padding(-2.5)
                    )
                    .offset(x: width * sunOrigin.0, y: sunOrigin.1)
                Circle()
                    .fill(Color(red: 0.918, green: 0.914, blue: 0.914))
                    .frame(width: 20, height: 20)
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .fill(Color(red: 0.110, green: 0.133, blue: 0.200))
                            .frame(width: 16, height: 16)
                            .offset(x: -6, y: -3)
                    }
                    .rotationEffect(.degrees(-20))
                    .offset(x: width * moonOrigin.0, y: moonOrigin.1)
                star(2, x: width * 0.58, y: 14, delay: 0.2)
                star(2, x: width * 0.72, y: 30, delay: 0.3)
                star(3, x: width * 0.88, y: 12, delay: 0.25)
                star(2, x: width * 0.64, y: 44, delay: 0.35)
            }
        }
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .clipShape(Self.outerShape)
        .overlay {
            if showsOuterBorder {
                Self.outerShape
                    .strokeBorder(DesignColor.sidebarActiveBackground, lineWidth: DesignBorder.width)
            }
        }
        .animation(.timingCurve(0.6, 0, 0.3, 1, duration: 0.6), value: night)
    }

    private func star(_ size: CGFloat, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .offset(x: x, y: y)
            .opacity(night == 0 ? 0 : 1)
            .animation(.easeInOut(duration: 0.5).delay(delay), value: night)
    }
}
