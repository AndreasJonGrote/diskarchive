//
//  NewMediumDetectedDialog.swift
//  diskindex
//
//  README Screen 01A — Modal.
//

import SwiftUI

/// Inhalt eines Erkennungs-Panels je Medium-ID (`AppWindowPresenter.syncNewMediumPanels`).
struct NewMediumDialogWindowHost: View {
    @Environment(AppState.self) private var appState
    let mediumID: UUID

    var body: some View {
        Group {
            if let medium = appState.medium(with: mediumID), medium.decision == .undecided {
                NewMediumDetectedDialog(medium: medium)
                    .padding(Self.shadowInset)
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .fixedSize()
        // bug.0.3.9.014 a: `onExitCommand` löst im Panel ohne fokussiertes Element nicht aus; Esc wie bei den
        // Rückfragen über die Tastenkürzel dieses Fensters (`onPanelEscape`).
        .onPanelEscape {
            AppWindowPresenter.closeNewMediumPanel(mediumID: mediumID, appState: appState, userDismissed: true)
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
                $0.decision = allowIndexing ? .index : .dontIndex
                $0.allowIndexing = allowIndexing
                if allowIndexing {
                    $0.indexStatus = .pending
                } else if !$0.hasIndex {
                    $0.indexStatus = .pending
                }
            }
        }
        appState.completeNewMediumDecision(medium.id)
        AppWindowPresenter.closeNewMediumPanel(mediumID: medium.id, appState: appState, userDismissed: false)
        AppWindowPresenter.syncNewMediumPanels(appState: appState)
    }
}
