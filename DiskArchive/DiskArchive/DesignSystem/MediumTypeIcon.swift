//
//  MediumTypeIcon.swift
//  DiskArchive
//

import SwiftUI

struct MediumTypeIcon: View {
    let type: MediumType
    var size: CGFloat = 20
    var color: Color = DesignColor.text

    /// Icon eines konkreten Mediums in seiner Zustandsfarbe (Fehler rot, Favorit violett).
    init(medium: Medium, size: CGFloat = 20) {
        self.type = medium.type
        self.size = size
        self.color = medium.iconColor
    }

    /// Neutrales Typ-Icon (z. B. „Neues Medium“-Dialog).
    init(type: MediumType, size: CGFloat = 20, color: Color = DesignColor.text) {
        self.type = type
        self.size = size
        self.color = color
    }

    var body: some View {
        Image(type.iconAssetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}

/// todo.0.4.3.007: Rolle der Icon-Farbe eines Mediums. Fehler rot vor Favorit violett (Aufgabe 23.7) vor benannt
/// türkis (Layout 19: Violett geht vor).
nonisolated enum MediumIconRole: Equatable {
    case plain
    case named
    case favorite
    case error
}

/// todo.0.4.3.007: Darstellung eines Mediums in Listen (Popover, Seitenleisten, Tabellen, Suche, Favoriten):
/// Name und – bei eigenem Namen – leise der Originalname in derselben Zeile (Layout 00/19).
nonisolated struct MediumListLabel: Equatable {
    var name: String
    var original: String?
    var iconRole: MediumIconRole
}

extension Medium {
    var iconRole: MediumIconRole {
        if indexStatus == .error { return .error }
        if isFavorite { return .favorite }
        if customName != nil { return .named }
        return .plain
    }

    var listLabel: MediumListLabel {
        MediumListLabel(name: shownName, original: customName != nil ? name : nil, iconRole: iconRole)
    }

    var iconColor: Color { iconRole.color }

    /// Auf ausgewählten Zeilen: Weiß statt Textfarbe, Türkis und Violett im Wert des anderen Modus (Layout 19).
    var iconColorOnSelection: Color { iconRole.colorOnSelection }
}

extension MediumIconRole {
    var color: Color {
        switch self {
        case .plain: DesignColor.text
        case .named: DesignColor.named
        case .favorite: DesignColor.favorite
        case .error: DesignColor.stateError
        }
    }

    var colorOnSelection: Color {
        switch self {
        case .plain: DesignColor.onSelection
        case .named: DesignColor.namedOnSelection
        case .favorite: DesignColor.favoriteOnSelection
        case .error: DesignColor.stateError
        }
    }
}

extension MediumType {
    var iconAssetName: String {
        switch self {
        case .usb: "MediumTypeUSB"
        case .ssd: "MediumTypeSSD"
        case .hdd: "MediumTypeHDD"
        }
    }
}
