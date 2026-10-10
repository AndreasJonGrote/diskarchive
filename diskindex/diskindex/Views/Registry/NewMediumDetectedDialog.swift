//
//  NewMediumDetectedDialog.swift
//  diskindex
//
//  README Screen 01A — Modal.
//

import SwiftUI

/// Inhalt des systemweiten Panels (`AppWindowPresenter.openNewMedium`); schließt es, sobald entschieden ist.
struct NewMediumDialogWindowHost: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let id = appState.newMediumDialogMediumID,
               let medium = appState.medium(with: id) {
                NewMediumDetectedDialog(medium: medium)
                    .padding(Self.shadowInset)
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .fixedSize()
        .onExitCommand {
            appState.newMediumDialogMediumID = nil
        }
        .onChange(of: appState.newMediumDialogMediumID) { _, newValue in
            if newValue == nil {
                AppWindowPresenter.closeNewMedium()
            }
        }
    }

    /// Raum für den SwiftUI-Schatten, analog zum Kontextmenü. Kein Inhaltspolster.
    static let shadowInset: CGFloat = 32
}

struct NewMediumDetectedDialog: View {
    @Environment(AppState.self) private var appState
    let medium: Medium

    /// Wirkt erst mit dem Backend (Entscheidung pro Medium speichern).
    @State private var rememberChoice = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MediumTypeIcon(type: medium.type, size: 30)

            Text(LayoutCopy.newMediumTitle)
                .font(.system(size: 16, weight: .bold))

            Text(bodyText)
                .font(.system(size: 13))
                .foregroundStyle(DesignColor.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Toggle(LayoutCopy.rememberMedium, isOn: $rememberChoice)
                .toggleStyle(DesignCheckbox())
                .font(.system(size: 14))
                .padding(.top, 4)

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(LayoutCopy.dontIndex) {
                    applyChoice(allowIndexing: false)
                }
                .buttonStyle(SecondaryButtonStyle())
                .pointerCursor()

                Button(LayoutCopy.index) {
                    applyChoice(allowIndexing: true)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .pointerCursor()
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
        .background(DesignColor.bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.lg)
                .strokeBorder(DesignColor.neutral300, lineWidth: DesignBorder.width)
        }
        .compositingGroup()
        .shadow(color: DesignColor.shadow.opacity(0.22), radius: 16, y: 12)
    }

    private var bodyText: String {
        let size = ByteCountFormatter.storage.string(fromByteCount: medium.capacityTotalBytes)
        return LayoutCopy.newMediumBody(name: medium.name, type: medium.type.displayName, size: size)
    }

    private func applyChoice(allowIndexing: Bool) {
        if let onNewMediumChoice = appState.onNewMediumChoice {
            onNewMediumChoice(medium.id, allowIndexing, rememberChoice)
        } else {
            appState.updateMedium(id: medium.id) {
                $0.allowIndexing = allowIndexing
                $0.indexStatus = allowIndexing ? .indexing : .indexed
            }
        }
        appState.newMediumDialogMediumID = nil
    }
}
