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
    init(type: MediumType, size: CGFloat = 20) {
        self.type = type
        self.size = size
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

extension Medium {
    /// Icon-Farbe: Fehler rot hat Vorrang vor Favorit violett (Aufgabe 23.7).
    var iconColor: Color {
        if indexStatus == .error { return DesignColor.stateError }
        if isFavorite { return DesignColor.favorite }
        return DesignColor.text
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
