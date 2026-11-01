//
//  DesignCheckbox.swift
//  DiskArchive
//
//  Layout-Checkbox (16 pt, Häkchen links, Label rechts). Erweitert → Mitteilungen, Filter, Dialoge.
//

import SwiftUI

struct DesignCheckbox: ToggleStyle {
    var tint: Color = DesignColor.control

    func makeBody(configuration: Configuration) -> some View {
        DesignCheckboxRow(configuration: configuration, tint: tint)
    }
}

private struct DesignCheckboxRow: View {
    let configuration: ToggleStyleConfiguration
    var tint: Color = DesignColor.control
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                box
                configuration.label
            }
        }
        .buttonStyle(.plainFullHit)
        .focused($focused)
        .onHover { hovering = $0 }
        .pointerCursor()
    }

    private var box: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.primary.opacity(0.001))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: DesignBorder.width)
            }
            .overlay {
                if configuration.isOn {
                    CheckmarkShape()
                        .stroke(tint, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                        .frame(width: 8, height: 6)
                }
            }
            .overlay {
                if focused {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(DesignColor.control, lineWidth: DesignBorder.width)
                        .padding(-4)
                }
            }
            .frame(width: 16, height: 16)
    }

    private var borderColor: Color {
        if configuration.isOn || hovering || focused {
            return tint
        }
        return DesignColor.divider
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
