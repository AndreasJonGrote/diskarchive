//
//  ReplaceMediumDialog.swift
//  diskindex
//
//  bug.0.4.031 c (todo.0.4.032): Rückfrage nach dem Erkennungs-Dialog, wenn ein Offline-Medium gleichen Namens bekannt ist.
//  Maße: Komponentenkatalog „Dialog“ (340 breit inkl. Rahmen, Innenabstand 16, Radius 14, Abstand 12, Knöpfe groß 149 × 38,8).
//

import SwiftUI

/// Inhalt des Rückfrage-Panels (`AppWindowPresenter.openReplaceMediumPrompt`).
struct ReplaceMediumDialogWindowHost: View {
    @Environment(AppState.self) private var appState
    let onDone: () -> Void

    var body: some View {
        Group {
            if let prompt = appState.replaceMediumPrompt {
                ReplaceMediumDialog(prompt: prompt, onDone: onDone)
                    .padding(NewMediumDialogWindowHost.shadowInset)
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .fixedSize()
        .onExitCommand {
            appState.resolveReplaceMediumPrompt(forgetOld: false)
            onDone()
        }
    }
}

struct ReplaceMediumDialog: View {
    @Environment(AppState.self) private var appState
    let prompt: ReplaceMediumPrompt
    var onDone: () -> Void = {}

    static let width: CGFloat = 340

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LayoutCopy.replaceMediumTitle(name: prompt.name))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignColor.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(LayoutCopy.replaceMediumBody)
                .font(.system(size: 13))
                .foregroundStyle(DesignColor.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                // Katalog: zwei Antworten gleich breit — der Inhalt füllt die Breite, Rahmen und Fläche folgen.
                Button {
                    appState.resolveReplaceMediumPrompt(forgetOld: true)
                    onDone()
                } label: {
                    Text(LayoutCopy.replaceMediumForgetOld).frame(maxWidth: .infinity)
                }
                .buttonStyle(DestructiveButtonStyle(size: .dialog))
                .pointerCursor()

                Button {
                    appState.resolveReplaceMediumPrompt(forgetOld: false)
                    onDone()
                } label: {
                    Text(LayoutCopy.replaceMediumKeep).frame(maxWidth: .infinity)
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
