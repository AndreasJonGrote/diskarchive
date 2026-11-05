//
//  UnexpectedErrorDialog.swift
//  DiskArchive
//
//  todo.0.4.3.011 (Layout 16): „Unerwarteter Fehler“ im Aufbau des Absturzberichts (15) – rotes Warn-Icon, Titel,
//  Beschreibung, „Schließen“ und optional eine Aktion rechts; beide Knöpfe gleich breit. Allgemeine Komponente für alle
//  Fehler ohne eigenen Dialog (Paket 62 nutzt sie weiter).
//

import SwiftUI

struct UnexpectedErrorDialog: View {
    @Environment(AppState.self) private var appState
    let notice: UnexpectedErrorNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("IconWarning")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(DesignColor.stateError)

            Text(LayoutCopy.unexpectedErrorTitle)
                .font(DesignFont.heading(size: 16))
                .foregroundStyle(DesignColor.text)

            Text(notice.message)
                .font(.system(size: 13))
                .foregroundStyle(DesignColor.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(LayoutCopy.close) {
                    appState.unexpectedError = nil
                }
                .buttonStyle(SecondaryButtonStyle(size: .dialog))
                .frame(maxWidth: .infinity)
                .pointerCursor()

                if let title = notice.actionTitle, let action = notice.action {
                    Button(title) {
                        appState.unexpectedError = nil
                        action()
                    }
                    .buttonStyle(PrimaryButtonStyle(size: .dialog))
                    .frame(maxWidth: .infinity)
                    .pointerCursor()
                }
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 460, alignment: .leading)
        .background(DesignColor.bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.lg)
                .strokeBorder(DesignColor.divider, lineWidth: DesignBorder.width)
        }
        .compositingGroup()
        .shadow(color: DesignColor.shadow.opacity(0.22), radius: 16, y: 12)
    }
}
