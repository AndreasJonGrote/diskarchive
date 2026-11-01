//
//  FadeMaskText.swift
//  DiskArchive
//
//  Aufgabe 138 — Text bestimmt nie die Layoutbreite; Überlauf mit Fade.
//

import SwiftUI

private struct FadeMaskTextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct FadeMaskText: View {
    let text: String
    var isLightOnDark: Bool = false
    /// Bei Auswahl: Verlauf nur, wenn der Text wirklich abgeschnitten wird.
    var applyFadeMask: Bool = false
    var font: Font = .system(size: 13, weight: .semibold)
    var foreground: Color = DesignColor.text

    @State private var intrinsicWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    /// Für Tests (Aufgabe 138): Fade aktiv, wenn Text breiter als Behälter.
    var shouldFade: Bool {
        applyFadeMask && intrinsicWidth > containerWidth + 0.5
    }

    var body: some View {
        // Unsichtbarer Text bestimmt nur die Zeilenhöhe; Breite bleibt flexibel (Aufgabe 150).
        Text(verbatim: "Ag")
            .font(font)
            .lineLimit(1)
            .hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(isLightOnDark ? DesignColor.onSelection : foreground)
            }
            .clipped()
            .mask {
                if shouldFade {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.82),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    Rectangle().fill(Color.black)
                }
            }
            .background {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .hidden()
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(key: FadeMaskTextWidthKey.self, value: geo.size.width)
                        }
                    }
            }
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { containerWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, width in
                            containerWidth = width
                        }
                }
            }
            .onPreferenceChange(FadeMaskTextWidthKey.self) { width in
                intrinsicWidth = width
            }
            .accessibilityLabel(text)
    }
}
