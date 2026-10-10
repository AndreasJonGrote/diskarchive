//
//  DashedUnderline.swift
//  diskindex
//
//  Gestrichelte Unterstreichung für umschaltbare Werte (% ⇄ absolut), Aufgabe 23.6:
//  1 pt, 3 an / 2 aus, 2 pt unter der Grundlinie, nur unter dem Wert.
//

import SwiftUI

extension View {
    func dashedUnderline(color: Color = DesignColor.text.opacity(0.55)) -> some View {
        // Unterkante der Linie an der Grundlinie ausrichten, dann um 3 pt senken → Linie liegt 2–3 pt darunter.
        overlay(alignment: Alignment(horizontal: .leading, vertical: .firstTextBaseline)) {
            GeometryReader { proxy in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0.5))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: 0.5))
                }
                .stroke(color, style: StrokeStyle(lineWidth: DesignBorder.width, dash: [3, 2]))
            }
            .frame(height: 1)
            .offset(y: 3)
        }
    }
}
