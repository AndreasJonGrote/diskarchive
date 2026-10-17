//
//  ButtonStyles.swift
//  diskindex
//
//  Aufgabe 131 — Katalogmaße (docs/Komponenten-Masse.md).
//

import SwiftUI

enum DesignButtonSize {
    case standard
    case compact
    /// Dialog-Fuß: gleiche Höhe wie Standard (Katalog „groß“).
    case dialog

    var height: CGFloat {
        switch self {
        case .standard, .dialog: 38.8
        case .compact: 24.4
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .standard, .dialog: 18
        case .compact: 12
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .standard, .dialog: 10
        case .compact: 4
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .standard, .dialog: 14
        case .compact: 12
        }
    }

    /// Popover-Fuß „Disk Index öffnen“: 12 pt, 12×4 pt (Mockup Screen 03).
    var compactFooterHorizontalPadding: CGFloat { 12 }
}

struct PrimaryButtonStyle: ButtonStyle {
    var size: DesignButtonSize = .standard

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .semibold))
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(height: size.height)
            .foregroundStyle(DesignColor.onControl)
            .background(DesignColor.control.opacity(configuration.isPressed ? 0.85 : 1))
            .designControlBorder(DesignColor.control)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var size: DesignButtonSize = .standard
    /// Popover-Fuß: kompaktes Sekundär-Layout (12 pt, 12×4 pt).
    var compactFooter = false

    func makeBody(configuration: Configuration) -> some View {
        let horizontal = compactFooter ? size.compactFooterHorizontalPadding : size.horizontalPadding
        let vertical = compactFooter ? 4 : size.verticalPadding
        let fontSize = compactFooter ? 12 : size.fontSize

        return configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .frame(height: compactFooter ? MenuBarPopoverLayout.footerOpenAppButtonHeight : size.height)
            .foregroundStyle(DesignColor.text)
            .background(configuration.isPressed ? DesignColor.neutral100 : Color.clear)
            .designControlBorder(DesignBorder.secondaryControlBorderColor)
            .contentShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }
}

/// Katalog „Destruktiv“: Rand und Schrift Rot (`#e04830`), Fläche leer; Maße wie die übrigen großen Knöpfe.
struct DestructiveButtonStyle: ButtonStyle {
    var size: DesignButtonSize = .standard

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .semibold))
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(height: size.height)
            .foregroundStyle(DesignColor.stateError)
            .background(configuration.isPressed ? DesignColor.stateError.opacity(0.08) : Color.clear)
            .designControlBorder(DesignColor.stateError)
            .contentShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }
}
