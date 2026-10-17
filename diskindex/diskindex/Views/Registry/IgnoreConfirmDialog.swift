//
//  IgnoreConfirmDialog.swift
//  diskindex
//
//  bug.0.4.035 (todo.0.4.031): Rückfrage vor dem Ignorieren von 500 oder mehr Zielen auf einmal.
//  Maße: Komponentenkatalog „Dialog“ (340 breit inkl. Rahmen, Innenabstand 16, Radius 14, Abstand 12, Knöpfe groß 149 × 38,8).
//

import SwiftUI

/// Inhalt des Rückfrage-Panels (`AppWindowPresenter.openIgnoreConfirmation`).
struct IgnoreConfirmDialogWindowHost: View {
    @Environment(AppState.self) private var appState
    let onDone: () -> Void

    var body: some View {
        Group {
            if let prompt = appState.ignoreConfirmationPrompt {
                IgnoreConfirmDialog(prompt: prompt, onDone: onDone)
                    .padding(NewMediumDialogWindowHost.shadowInset)
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .fixedSize()
        .onExitCommand {
            appState.resolveIgnoreConfirmation(confirm: false)
            onDone()
        }
    }
}

struct IgnoreConfirmDialog: View {
    @Environment(AppState.self) private var appState
    let prompt: IgnoreConfirmationPrompt
    var onDone: () -> Void = {}

    static let width: CGFloat = 340

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LayoutCopy.ignoreConfirmTitle(count: prompt.count))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignColor.text)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    appState.resolveIgnoreConfirmation(confirm: true)
                    onDone()
                } label: {
                    Text(LayoutCopy.ignore).frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(size: .dialog))
                .pointerCursor()

                // Standard und Esc: Abbrechen ändert nichts.
                Button {
                    appState.resolveIgnoreConfirmation(confirm: false)
                    onDone()
                } label: {
                    Text(LayoutCopy.cancel).frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(size: .dialog))
                .keyboardShortcut(.defaultAction)
                .pointerCursor()
            }
            .padding(.top, 8)
        }
        // Katalog: 340 einschließlich 1-pt-Rahmen, Innenabstand 16 innerhalb des Rahmens.
        .padding(16 + DesignBorder.width)
        .frame(width: Self.width, alignment: .leading)
        .background(DesignColor.bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.lg)
                .strokeBorder(DesignColor.neutral300, lineWidth: DesignBorder.width)
        }
        .compositingGroup()
        .shadow(color: DesignColor.shadow.opacity(0.22), radius: 16, y: 12)
    }
}
