//
//  SettingsLanguagePicker.swift
//  DiskArchive
//
//  Aufgabe 165 — eigener Auswahl-Knopf, kein Systemmenü.
//

import SwiftUI

struct SettingsLanguagePicker: View {
    @Binding var selection: AppDisplayLanguage
    /// Nach oben gereicht, damit der ganze Abschnitt über die folgenden gelegt werden kann.
    @Binding var isOpen: Bool

    private let buttonWidth: CGFloat = 160
    private let buttonHeight: CGFloat = 24.4

    var body: some View {
        Button {
            setOpen(!isOpen)
        } label: {
            HStack(spacing: 8) {
                Text(selection.label)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image("NavCaretDown")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 11, height: 11)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(width: buttonWidth, height: buttonHeight)
            .foregroundStyle(DesignColor.text)
            .background(DesignColor.bg)
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.md)
                    .strokeBorder(DesignBorder.secondaryControlBorderColor, lineWidth: DesignBorder.width)
            }
            .contentShape(RoundedRectangle(cornerRadius: DesignRadius.md))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .pointerCursor()
        .overlay(alignment: .topLeading) {
            // Immer aufgebaut, nur ausgeblendet: das erste Öffnen kostet sonst den Aufbau des Feldes.
            languagePanel
                .offset(y: buttonHeight + 4)
                .opacity(isOpen ? 1 : 0)
                .allowsHitTesting(isOpen)
                .accessibilityHidden(!isOpen)
                .zIndex(1)
        }
        .background {
            if isOpen {
                Color.clear.onEscapeKey { setOpen(false) }
            }
        }
        .background {
            Color.clear
                .frame(width: 2400, height: 2400)
                .contentShape(Rectangle())
                .onTapGesture { setOpen(false) }
                .offset(x: -400, y: -400)
                .allowsHitTesting(isOpen)
        }
    }

    private func setOpen(_ open: Bool) {
        withTransaction(Transaction(animation: nil)) { isOpen = open }
    }

    private var languagePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(AppDisplayLanguage.allCases) { language in
                languageRow(language)
            }
        }
        .padding(4)
        .frame(minWidth: buttonWidth, alignment: .leading)
        .background(DesignColor.bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.lg)
                .strokeBorder(DesignColor.text.opacity(0.4), lineWidth: DesignBorder.width)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 10, y: 3)
        .focusEffectDisabled()
    }

    private func languageRow(_ language: AppDisplayLanguage) -> some View {
        Button {
            selection = language
            setOpen(false)
        } label: {
            HStack(spacing: 8) {
                radio(selected: selection == language)
                Text(language.label)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(DesignColor.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .pointerCursor()
    }

    private func radio(selected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(DesignColor.text.opacity(0.4), lineWidth: 1.5)
            if selected {
                Circle()
                    .fill(DesignColor.text)
                    .padding(4)
            }
        }
        .frame(width: 16, height: 16)
    }
}
