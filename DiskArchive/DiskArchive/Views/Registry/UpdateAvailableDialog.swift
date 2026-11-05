//
//  UpdateAvailableDialog.swift
//  DiskArchive
//
//  Update-Hinweis (c.0.3.3.001), Vorlage IndexingFailureDialog; Layout 13 „Updatedialog“ (todo.0.4.047).
//

import AppKit
import SwiftUI

struct UpdateAvailableDialog: View {
    @Environment(AppState.self) private var appState
    let notice: UpdateNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // todo.0.4.047: Icon „Festplatten“ (Phosphor hard-drives), Textfarbe, 30 pt.
            Image("MenuBarHardDrives")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(DesignColor.text)

            Text(LayoutCopy.updateAvailableTitle)
                .font(DesignFont.heading(size: 16))
                .foregroundStyle(DesignColor.text)

            Text(LayoutCopy.updateAvailableText)
                .font(.system(size: 13))
                .foregroundStyle(DesignColor.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            // todo.0.4.047: der Haken ist die Einstellung „Auf Updates hinweisen“ (gespeichert beim Schließen).
            Toggle(isOn: Binding(
                get: { appState.updateNotice?.notifyAboutUpdates ?? notice.notifyAboutUpdates },
                set: { newValue in
                    guard var current = appState.updateNotice else { return }
                    current.notifyAboutUpdates = newValue
                    appState.updateNotice = current
                }
            )) {
                Text(LayoutCopy.updatesToggle)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignColor.text.opacity(0.85))
            }
            .toggleStyle(DesignCheckbox())

            HStack(spacing: 8) {
                // Beide Knöpfe gleich breit (Layout 13): die Fläche des Stils füllt die halbe Zeile.
                Button {
                    appState.dismissUpdateNotice()
                } label: {
                    Text(LayoutCopy.close).frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(size: .dialog))
                .frame(maxWidth: .infinity)
                .pointerCursor()

                Button {
                    appState.openUpdateWebsite()
                } label: {
                    Text(LayoutCopy.updateAvailableDownload).frame(maxWidth: .infinity)
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
