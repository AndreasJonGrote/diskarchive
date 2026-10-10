//
//  DesignTokens.swift
//  diskindex
//
//  Zentrale Design-Werte — Aufgabe 19.1 / layout/ds-disk-index.css.
//

import AppKit
import SwiftUI

// MARK: - Colors

nonisolated enum DesignColor {
    // Rollenfarben. Hell bleibt der bisherige Wert, Dunkel folgt der Tabelle in Aufgabe 48.
    static let control = pair(light: 0x1F1F1F, dark: 0xEAE9E9)
    static let stateOnline = pair(light: 0x20A04E, dark: 0x5BBD74)
    static let stateError = pair(light: 0xE04830, dark: 0xF57050)
    static let stateIgnored = pair(light: 0xEDA12D, dark: 0xEDA12D)
    static let filterSearch = pair(light: 0x3986E4, dark: 0x65A7FA)
    static let favorite = pair(light: 0x9D69D2, dark: 0xB98CEA)
    static let settingsActive = pair(light: 0x00B5B5, dark: 0x00BFC0)
    static let stateOff = pair(light: 0x868686, dark: 0x929292)

    static let bg = pair(light: 0xF3F2F2, dark: 0x1F1F1F)
    static let surface = pair(light: 0xEAE9E9, dark: 0x2A2A2A)
    static let text = pair(light: 0x201E1D, dark: 0xEAE9E9)
    static let divider = pair(light: 0x201E1D, lightOpacity: 0.4, dark: 0xEAE9E9, darkOpacity: 0.18)
    /// `text` 6 % über `bg`. Dunkel ergibt das neutrale #2B2B2B.
    static let toolbar = blend(inkOnto: bgHex, fraction: 0.06)
    /// Auswahlfläche. Alias der bestehenden Seitenleisten-Auswahl.
    static let selection = sidebarActiveBackground

    static let neutral100 = pair(light: 0xF8F4F4, dark: 0x2D2B2B)
    static let neutral200 = pair(light: 0xEAE7E7, dark: 0x444141)
    static let neutral300 = pair(light: 0xD7D3D3, dark: 0x605D5D)
    static let neutral500 = pair(light: 0x9B9797, dark: 0x9B9797)
    static let neutral700 = pair(light: 0x605D5D, dark: 0xD7D3D3)
    static let neutral800 = pair(light: 0x444141, dark: 0xEAE7E7)

    /// Auswahl in Seitenleiste, Zeilen und am Filter-Reset. In Dunkel #4A4949, nicht `control`.
    static let sidebarActiveBackground = pair(light: 0x1F1F1F, dark: 0x4A4949)
    /// Zweites Segment in An/Pausiert und Ja/Nein (Layout neutral-800 / di-sel).
    static let binaryGroupSecondSelected = pair(light: 0x444141, dark: 0x4A4949)

    /// Fensterfläche hinter der transparenten Titelleiste: dieselbe Mischung wie die Toolbar.
    static var windowChrome: NSColor { blendNS(fraction: 0.06) }
    /// Fenstertitel: `text` bei 60 %.
    static var windowTitle: NSColor { inkNS(opacity: 0.6) }

    private static let bgHex = (light: UInt32(0xF3F2F2), dark: UInt32(0x1F1F1F))
    private static let inkHex = (light: UInt32(0x201E1D), dark: UInt32(0xEAE9E9))
    /// Schatten bleiben in beiden Modi #2D2B2B. Die Neutral-Stufen kippen im Dunkelmodus auf Hell.
    static let shadow = Color(hex: 0x2D2B2B)
    /// Schrift und Icons auf der Auswahl. In beiden Modi weiß.
    static let onSelection = Color.white
    /// X und „!“ auf dem weißen Menüleisten-Badge (Layout 02): immer dunkle Tinte, unabhängig vom Erscheinungsbild.
    static let menuBarBadgeInk = Color(hex: 0x201E1D)
    /// Schrift auf `control`: in Hell weiß, in Dunkel #1F1F1F, weil die Fläche dort hell ist.
    static let onControl = pair(light: 0xFFFFFF, dark: 0x1F1F1F)

    /// Chip-Fläche: 5 % in Hell, 12 % in Dunkel. Die Deckkraft liegt im dynamischen Anbieter.
    static func chipFill(_ role: Color) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let opacity: CGFloat = isDark(appearance) ? 0.12 : 0.05
            let base = resolved(role, appearance: appearance)
            return base.withAlphaComponent(opacity)
        }))
    }

    /// Chip-Rand = exakt die Basisfarbe (Mockup; Aufgabe 20.5).
    static func chipBorder(_ role: Color) -> Color {
        role
    }

    private static func pair(
        light: UInt32,
        lightOpacity: CGFloat = 1,
        dark: UInt32,
        darkOpacity: CGFloat = 1
    ) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if isDark(appearance) {
                return nsColor(hex: dark, opacity: darkOpacity)
            }
            return nsColor(hex: light, opacity: lightOpacity)
        }))
    }

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static func resolved(_ color: Color, appearance: NSAppearance) -> NSColor {
        var resolved = NSColor.black
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(color).usingColorSpace(.sRGB) ?? .black
        }
        return resolved
    }

    private static func blend(
        inkOnto: (light: UInt32, dark: UInt32),
        fraction: CGFloat
    ) -> Color {
        Color(nsColor: blendNS(base: inkOnto, fraction: fraction))
    }

    private static func blendNS(fraction: CGFloat) -> NSColor {
        blendNS(base: bgHex, fraction: fraction)
    }

    private static func blendNS(base: (light: UInt32, dark: UInt32), fraction: CGFloat) -> NSColor {
        NSColor(name: nil, dynamicProvider: { appearance in
            let dark = isDark(appearance)
            let ground = nsColor(hex: dark ? base.dark : base.light, opacity: 1)
            let ink = nsColor(hex: dark ? inkHex.dark : inkHex.light, opacity: 1)
            return mix(ink, onto: ground, fraction: fraction)
        })
    }

    private static func inkNS(opacity: CGFloat) -> NSColor {
        NSColor(name: nil, dynamicProvider: { appearance in
            let hex = isDark(appearance) ? inkHex.dark : inkHex.light
            return nsColor(hex: hex, opacity: opacity)
        })
    }

    private static func mix(_ ink: NSColor, onto ground: NSColor, fraction: CGFloat) -> NSColor {
        let ink = ink.usingColorSpace(.sRGB) ?? ink
        let ground = ground.usingColorSpace(.sRGB) ?? ground
        let keep = 1 - fraction
        return NSColor(
            srgbRed: ink.redComponent * fraction + ground.redComponent * keep,
            green: ink.greenComponent * fraction + ground.greenComponent * keep,
            blue: ink.blueComponent * fraction + ground.blueComponent * keep,
            alpha: 1
        )
    }

    private static func nsColor(hex: UInt32, opacity: CGFloat) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: opacity
        )
    }
}

// MARK: - Radius & borders

enum DesignRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 14
}

enum DesignBorder {
    static let width: CGFloat = 1

    /// Sekundär-Buttons, „Hinzufügen“, Textfelder neben Buttons — Mockup `neutral-500`, 1 px.
    static let secondaryControlBorderColor: Color = DesignColor.neutral500
}

extension View {
    /// Einheitlicher 1-pt-Rand (strokeBorder innen, volle sichtbare Breite).
    func designControlBorder(
        _ color: Color,
        cornerRadius: CGFloat = DesignRadius.sm
    ) -> some View {
        clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(color, lineWidth: DesignBorder.width)
            }
    }
}

struct DesignDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignColor.divider)
            .frame(height: DesignBorder.width)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Spacing & layout

enum DesignSpacing {
    static let columnBrowserSidebarWidth: CGFloat = 200
    static let columnBrowserColumnWidth: CGFloat = 230
    static let columnBrowserDetailWidth: CGFloat = 200
}

// MARK: - Search fields

enum DesignSearchField {
    /// Objekte-Suche (Screens 04, 06, 07)
    static let objectWidth: CGFloat = 280
    static let objectFontSize: CGFloat = 14
    static let objectIconLeadingPadding: CGFloat = 34

    /// Medium-Suche kompakt (Popover-Header Screen 03)
    static let mediumCompactWidth: CGFloat = 150

    /// Medium-Suche klein (Sidebars, Filter 07B)
    static let mediumSmallFontSize: CGFloat = 12
    static let mediumSmallMinHeight: CGFloat = 26
    static let mediumSmallIconLeadingPadding: CGFloat = 26
}

// MARK: - Color hex helper

extension Color {
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
