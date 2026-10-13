//
//  UpdateAvailableDialog.swift
//  diskindex
//
//  Update-Hinweis (c.0.3.3.001), Vorlage IndexingFailureDialog.
//

import AppKit
import SwiftUI

struct UpdateAvailableDialog: View {
    @Environment(AppState.self) private var appState
    let notice: UpdateNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("IconWarning")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(DesignColor.text)

            Text(LayoutCopy.updateAvailableTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignColor.text)

            Text(LayoutCopy.updateAvailableBody(current: notice.offer.currentDisplay, target: notice.offer.targetDisplay))
                .font(.system(size: 13))
                .foregroundStyle(DesignColor.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            if notice.offer.showBetaCountdown {
                Text(LayoutCopy.updateAvailableBetaCountdown)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignColor.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let banner = appState.versionLockBannerText() {
                Text(banner)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DesignColor.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if notice.offer.showSkipCheckbox {
                Toggle(isOn: Binding(
                    get: { appState.updateNotice?.skipUpdate ?? notice.skipUpdate },
                    set: { newValue in
                        guard var current = appState.updateNotice else { return }
                        current.skipUpdate = newValue
                        appState.updateNotice = current
                    }
                )) {
                    Text(LayoutCopy.updateAvailableSkipCheckbox)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignColor.text.opacity(0.85))
                }
                .toggleStyle(DesignCheckbox())
            }

            HStack(spacing: 8) {
                Button(LayoutCopy.close) {
                    appState.dismissUpdateNotice(saveSkip: appState.updateNotice?.skipUpdate ?? notice.skipUpdate)
                }
                .buttonStyle(SecondaryButtonStyle(size: .dialog))
                .frame(maxWidth: .infinity)
                .pointerCursor()

                Button(LayoutCopy.updateAvailableDownload) {
                    appState.dismissUpdateNotice(saveSkip: appState.updateNotice?.skipUpdate ?? notice.skipUpdate)
                    if let url = URL(string: "https://diskarchive.app/") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(size: .dialog))
                .frame(maxWidth: .infinity)
                .pointerCursor()
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 360, alignment: .leading)
        .background(DesignColor.bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.lg)
                .strokeBorder(DesignColor.neutral300, lineWidth: DesignBorder.width)
        }
        .compositingGroup()
        .shadow(color: DesignColor.shadow.opacity(0.22), radius: 16, y: 12)
        .padding(32)
    }
}
