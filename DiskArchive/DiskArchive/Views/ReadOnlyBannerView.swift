//
//  ReadOnlyBannerView.swift
//  DiskArchive
//
//  todo.0.4.3.020 (Layout 04.03a–04.06): Banner im Nur-Lesen-Modus. Gelb `#EDA12D` = Hinweis, Rot `#E04830` = Sperre;
//  Schrift und Icon weiß, Icon 20 pt, 14 pt Abstand, Innenabstand 12/16 pt, Rand unten dunkler. Überschrift 13 pt fett,
//  Info 12 pt (Zeilenhöhe 1,45, 2 pt Abstand); Knopf 12 pt halbfett mit weißem Rand, beim Hover weiß gefüllt.
//

import SwiftUI

struct ReadOnlyBannerView: View {
    @Environment(AppState.self) private var appState
    let banner: ReadOnlyBanner

    static let yellow = Color(red: 237 / 255, green: 161 / 255, blue: 45 / 255)
    static let yellowEdge = Color(red: 209 / 255, green: 138 / 255, blue: 28 / 255)
    static let red = Color(red: 224 / 255, green: 72 / 255, blue: 48 / 255)
    static let redEdge = Color(red: 194 / 255, green: 58 / 255, blue: 37 / 255)

    private var fill: Color { banner.isLock ? Self.red : Self.yellow }

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let asset = banner.iconAsset {
                    Image(asset)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                } else {
                    // 04.05 „Versionsprüfung …“: Spinner 16 pt in der 20-pt-Fläche.
                    IndexingSpinnerRing(color: .white, lineWidth: 2)
                        .padding(1)
                        .frame(width: 16, height: 16)
                }
            }
            .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title)
                    .font(.system(size: 13, weight: .bold))
                if let info = banner.info {
                    Text(info)
                        .font(.system(size: 12))
                        .lineSpacing(12 * 1.45 - 14.3)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let action = banner.action {
                ReadOnlyBannerButton(title: action.title, fill: fill) {
                    switch action.kind {
                    case .website: appState.openExternalURL(AppLinks.websiteURL)
                    case .checkNow: appState.checkLicenseServerNow()
                    }
                }
            }
        }
        .foregroundStyle(Color.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        // 04.05: der Prüfzustand behält die Höhe des Banners (62 pt).
        .frame(minHeight: banner == .checking ? 62 : nil)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(banner.isLock ? Self.redEdge : Self.yellowEdge)
                .frame(height: DesignBorder.width)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ReadOnlyBannerButton: View {
    let title: String
    let fill: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isHovered ? fill : Color.white)
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .background(isHovered ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: DesignRadius.sm))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignRadius.sm)
                        .strokeBorder(Color.white, lineWidth: DesignBorder.width)
                }
                .contentShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .onHover { isHovered = $0 }
    }
}
