//
//  MediumCustomNameField.swift
//  diskindex
//
//  todo.0.4.2.002 (Layout ab 0.4.2, Details-Modal, Zeile „Eigener Name“): Textfeld rechts, 200 pt breit, 12 pt,
//  mindestens 24 pt hoch, Innenabstand 2/8 pt; Platzhalter = Originalname. Enter oder Verlassen übernimmt, Escape stellt
//  den gespeicherten Wert wieder her.
//

import SwiftUI

struct MediumCustomNameField: View {
    @Environment(AppState.self) private var appState
    let medium: Medium

    @State private var text: String
    @FocusState private var focused: Bool

    init(medium: Medium) {
        self.medium = medium
        _text = State(initialValue: medium.customName ?? "")
    }

    var body: some View {
        TextField(medium.name, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .lineLimit(1)
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .frame(width: 200)
            .frame(minHeight: 24)
            .background(DesignColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.md)
                    .strokeBorder(DesignColor.divider, lineWidth: DesignBorder.width)
            }
            .focused($focused)
            .onSubmit(commit)
            .onExitCommand {
                text = medium.customName ?? ""
                focused = false
            }
            .onChange(of: focused) { wasFocused, isFocused in
                if wasFocused, !isFocused { commit() }
            }
            // Modal geschlossen, während das Feld noch den Fokus hatte: wie Verlassen.
            .onDisappear {
                if focused { commit() }
            }
            .onChange(of: text) { _, value in
                if value.count > Medium.customNameMaxLength {
                    text = String(value.prefix(Medium.customNameMaxLength))
                }
            }
            .onChange(of: medium.customName) { _, stored in
                if !focused { text = stored ?? "" }
            }
            // todo.0.4.2.005: „Benennen“ von Suche, Einstellungen oder Menüleiste – Fokus hier, Inhalt ganz markiert.
            .task {
                let naming = MediumNaming(mediumID: medium.id, place: .detailsModal)
                guard appState.mediumNaming == naming else { return }
                focused = true
                appState.endNaming(naming)
            }
            .disabled(!appState.featureAccess.canWriteIndex)
    }

    private func commit() {
        appState.setCustomName(mediumID: medium.id, input: text)
        text = Medium.normalizedCustomName(text, original: medium.name) ?? ""
    }
}
