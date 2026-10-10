//
//  SettingsView.swift
//  diskindex
//
//  Aufgabe 19.8 — Einstellungen mit Tabs links.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar(selected: appState.settingsTabBinding)
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func settingsSidebar(selected: Binding<SettingsTab>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selected.wrappedValue = tab
                } label: {
                    Text(tab.title)
                        .font(.system(size: 13, weight: selected.wrappedValue == tab ? .semibold : .regular))
                        .foregroundStyle(
                            selected.wrappedValue == tab
                                ? DesignColor.control
                                : DesignColor.text.opacity(0.65)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            selected.wrappedValue == tab
                                ? DesignColor.bg
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
                        // Schatten nur für die Gesamtform, nicht für jede Unteransicht.
                        .compositingGroup()
                        .shadow(
                            color: selected.wrappedValue == tab
                                ? DesignColor.shadow.opacity(0.14)
                                : .clear,
                            radius: 4,
                            y: 1
                        )
                }
                .buttonStyle(PlainFullHitButtonStyle(shape: RoundedRectangle(cornerRadius: DesignRadius.sm)))
                .pointerCursor()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(width: 170, alignment: .topLeading)
        .background(DesignColor.text.opacity(0.05))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DesignColor.neutral300)
                .frame(width: DesignBorder.width)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch appState.settingsTab {
        case .general:
            SettingsGeneralTab(section: .general)
        case .files:
            SettingsGeneralTab(section: .files)
        case .storageMedia:
            SettingsMediaRegistryPanel()
        case .advanced:
            SettingsGeneralTab(section: .advanced)
        }
    }
}
