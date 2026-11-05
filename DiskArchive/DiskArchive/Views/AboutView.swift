//
//  AboutView.swift
//  DiskArchive
//
//  todo.0.4.3.001 (Layout 17): Inhalt des Fensters „Über Disk Archive“ – 420 pt breit. Oben 280 pt `#1f1f1f` mit
//  hellem Verlauf und fünf Ringen, App-Icon 112 pt, darunter „Disk Archive“ (Archivo 24 pt). Unten Balken `#0A0A0A`
//  (14/18 pt) mit Version (halbfett), Datum (60 %) und Link „diskarchive.app“. Hell und dunkel gleich.
//

import AppKit
import SwiftUI

struct AboutView: View {
    let content: AboutPanel.Content

    static let size = CGSize(width: 420, height: 280 + 59)
    private static let text = Color(red: 234 / 255, green: 233 / 255, blue: 233 / 255)

    /// Ringe aus dem Layout (Mittelpunkt 210/128): Durchmesser und Deckkraft des Randes (oben heller).
    private static let rings: [(diameter: CGFloat, side: Double, top: Double)] = [
        (160, 0.09, 0.26), (210, 0.08, 0.22), (265, 0.06, 0.18), (325, 0.06, 0.16), (400, 0.05, 0.14),
    ]

    var body: some View {
        VStack(spacing: 0) {
            hero
            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .foregroundStyle(Self.text)
        .environment(\.colorScheme, .dark)
    }

    private var hero: some View {
        ZStack {
            Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255)
            RadialGradient(
                stops: [
                    .init(color: Self.text.opacity(0.20), location: 0),
                    .init(color: Self.text.opacity(0.07), location: 0.4),
                    .init(color: .clear, location: 0.7),
                ],
                center: UnitPoint(x: 0.5, y: 130 / 280),
                startRadius: 0,
                endRadius: 300
            )
            ForEach(Self.rings, id: \.diameter) { ring in
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Self.text.opacity(ring.top), Self.text.opacity(ring.side)],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .frame(width: ring.diameter, height: ring.diameter)
                    .position(x: 210, y: 128)
            }
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.45), radius: 15, y: 18)
                .position(x: 210, y: 128)
            Text(verbatim: content.name)
                .font(DesignFont.heading(size: 24))
                .kerning(-0.48)
                .position(x: 210, y: 212 + 14)
        }
        .frame(width: Self.size.width, height: 280)
        .clipped()
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AboutPanel.versionLine(content.version))
                    .fontWeight(.semibold)
                if let date = AboutPanel.dateLine(content.buildDate) {
                    Text(date)
                        .foregroundStyle(Self.text.opacity(0.6))
                }
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            if let url = URL(string: content.link) {
                Link(destination: url) {
                    Text(AboutPanel.linkTitle(content.link))
                        .fontWeight(.semibold)
                        .underline()
                        .foregroundStyle(Self.text)
                }
                .pointerCursor()
            }
        }
        .font(.system(size: 12))
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: DesignBorder.width)
        }
    }
}
