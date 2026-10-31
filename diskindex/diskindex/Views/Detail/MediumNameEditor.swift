//
//  MediumNameEditor.swift
//  diskindex
//
//  todo.0.4.2.005: „Benennen“ an Ort und Stelle (Dashboard-Kachel, Seitenleiste der Spaltenansicht). Der Titel wird zum
//  Eingabefeld (gleiche Schrift und Lage, Fläche und Rand wie das Feld im Details-Modal); Startwert ist der angezeigte
//  Name, ganz markiert. Ab dem ersten geänderten Zeichen steht der Originalname darunter. Enter, Klick daneben oder
//  Verschwinden übernimmt (`AppState.setCustomName`), Escape bricht ab.
//

import SwiftUI

struct MediumNameEditor: View {
    @Environment(AppState.self) private var appState
    let medium: Medium
    let naming: MediumNaming
    let font: Font
    let foreground: Color
    /// Zweite Zeile schon vor dem ersten Zeichen (Kachel mit eigenem Namen).
    let alwaysShowsOriginal: Bool
    let originalColor: Color

    private let start: String
    @State private var text: String
    @State private var finished = false
    @FocusState private var focused: Bool

    init(
        medium: Medium,
        naming: MediumNaming,
        font: Font,
        foreground: Color = DesignColor.text,
        alwaysShowsOriginal: Bool = false,
        originalColor: Color = DesignColor.text.opacity(0.5)
    ) {
        self.medium = medium
        self.naming = naming
        self.font = font
        self.foreground = foreground
        self.alwaysShowsOriginal = alwaysShowsOriginal
        self.originalColor = originalColor
        start = medium.shownName
        _text = State(initialValue: medium.shownName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Unsichtbarer Text gibt die Zeilenhöhe des Titels vor: kein Sprung beim Öffnen des Felds.
            Text(verbatim: "Ag")
                .font(font)
                .lineLimit(1)
                .hidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    TextField("", text: $text)
                        .textFieldStyle(.plain)
                        .font(font)
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                        // Fläche nach außen, damit der Text an der Stelle des Titels bleibt.
                        .background {
                            RoundedRectangle(cornerRadius: DesignRadius.sm)
                                .fill(DesignColor.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: DesignRadius.sm)
                                        .strokeBorder(DesignColor.divider, lineWidth: DesignBorder.width)
                                }
                                .padding(.horizontal, -4)
                                .padding(.vertical, -2)
                        }
                        .focused($focused)
                        .onSubmit(commit)
                        .onExitCommand(perform: cancel)
                        .onChange(of: focused) { wasFocused, isFocused in
                            if wasFocused, !isFocused { commit() }
                        }
                        .onChange(of: text) { _, value in
                            if value.count > Medium.customNameMaxLength {
                                text = String(value.prefix(Medium.customNameMaxLength))
                            }
                        }
                        .onClickOutside(perform: commit)
                        .task { focused = true }
                }

            if alwaysShowsOriginal || text != start {
                FadeMaskText(text: medium.name, applyFadeMask: true, font: .system(size: 11), foreground: originalColor)
            }
        }
        // Eine andere Bearbeitung beginnt oder die Ansicht geht weg: wie Verlassen.
        .onDisappear(perform: commit)
    }

    private func commit() {
        guard !finished else { return }
        finished = true
        if text != start {
            appState.setCustomName(mediumID: medium.id, input: text)
        }
        appState.endNaming(naming)
    }

    private func cancel() {
        guard !finished else { return }
        finished = true
        appState.endNaming(naming)
    }
}
