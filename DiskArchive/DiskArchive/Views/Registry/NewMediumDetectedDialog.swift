//
//  NewMediumDetectedDialog.swift
//  DiskArchive
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
            // todo.0.4.026: auch ein erneut gefragtes (entschiedenes, nicht gemerktes) Medium in der Warteschlange.
            if let medium = appState.medium(with: mediumID),
               medium.decision == .undecided || appState.needsNewMediumDialog(mediumID) {
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

    /// „Für dieses Medium merken“: neues Medium angehakt; erneut gefragt (todo.0.4.026) wie zuletzt, also ohne Haken.
    @State private var rememberChoice: Bool

    init(medium: Medium) {
        self.medium = medium
        _rememberChoice = State(initialValue: !Self.isAskedAgain(medium))
    }

    /// Erneut gefragt (todo.0.4.026): schon entschieden, aber nicht gemerkt.
    static func isAskedAgain(_ medium: Medium) -> Bool {
        medium.decision == .index || medium.decision == .dontIndex
    }

    /// Vorbelegung = letzte Entscheidung (todo.0.4.026): Eingabetaste wählt bei „Nicht indizieren“ zuletzt Nein.
    static func defaultsToDontIndex(_ medium: Medium) -> Bool {
        medium.decision == .dontIndex
    }

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
                .keyboardShortcut(Self.defaultsToDontIndex(medium) ? .defaultAction : nil)
                .pointerCursor()

                Button(LayoutCopy.index) {
                    applyChoice(allowIndexing: true)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(Self.defaultsToDontIndex(medium) ? nil : .defaultAction)
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
        return LayoutCopy.newMediumBody(name: medium.name, size: size)
    }

    private func applyChoice(allowIndexing: Bool) {
        Self.applyChoice(mediumID: medium.id, allowIndexing: allowIndexing, remember: rememberChoice, appState: appState)
    }

    /// Antwort des Dialogs (Knöpfe „Indizieren“/„Nicht indizieren“): Entscheidung weitergeben, Panel schließen, Stapel
    /// neu ordnen. Eine Quelle für Knopf und Tests (bug.0.4.119, Regel 18: Tests nehmen denselben Einstieg wie der Knopf).
    static func applyChoice(mediumID: UUID, allowIndexing: Bool, remember: Bool, appState: AppState) {
        if let onNewMediumChoice = appState.onNewMediumChoice {
            onNewMediumChoice(mediumID, allowIndexing, remember)
        } else {
            appState.updateMedium(id: mediumID) {
                $0.decision = allowIndexing ? .index : .dontIndex
                $0.allowIndexing = allowIndexing
                if allowIndexing {
                    $0.indexStatus = .pending
                } else if !$0.hasIndex {
                    $0.indexStatus = .pending
                }
            }
        }
        appState.completeNewMediumDecision(mediumID)
        AppWindowPresenter.closeNewMediumPanel(mediumID: mediumID, appState: appState, userDismissed: false)
        AppWindowPresenter.syncNewMediumPanels(appState: appState)
    }
}
