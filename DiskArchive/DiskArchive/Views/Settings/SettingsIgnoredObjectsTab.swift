//
//  SettingsIgnoredObjectsTab.swift
//  DiskArchive
//

import SwiftUI

struct SettingsIgnoredObjectsTab: View {
    @Environment(AppState.self) private var appState
    @State private var newPattern = ""

    var body: some View {
        let settings = appState.appSettingsBinding

        VStack(alignment: .leading, spacing: 24) {
            excludeSection(settings: settings)
            DesignDivider()
            hiddenFilesSection(settings: settings)
            DesignDivider()
            artifactsSection(settings: settings)
        }
    }

    private func excludeSection(settings: Binding<AppSettings>) -> some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionTitle(title: LayoutCopy.excludeTitle)
                Text(LayoutCopy.excludeText)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignColor.text.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField(LayoutCopy.excludePatternPlaceholder, text: $newPattern)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(DesignColor.bg)
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignRadius.sm)
                                .strokeBorder(DesignBorder.secondaryControlBorderColor, lineWidth: DesignBorder.width)
                        }
                        .onSubmit { addPattern(to: settings) }

                    Button(LayoutCopy.add) {
                        addPattern(to: settings)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .pointerCursor()
                }

                FlowLayout(spacing: 8) {
                    ForEach(settings.wrappedValue.excludedPatterns, id: \.self) { pattern in
                        IgnoredPatternChip(pattern: pattern) {
                            var copy = settings.wrappedValue
                            copy.excludedPatterns.removeAll { $0 == pattern }
                            settings.wrappedValue = copy
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func hiddenFilesSection(settings: Binding<AppSettings>) -> some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionTitle(title: LayoutCopy.hiddenTitle)
                Text(LayoutCopy.hiddenText)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignColor.text.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(LayoutCopy.ignore, isOn: settings.appSettingsField(\.ignoreHiddenFiles))
                .toggleStyle(DesignCheckbox())
                .font(.system(size: 12.5, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func artifactsSection(settings: Binding<AppSettings>) -> some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionTitle(title: LayoutCopy.artifactsTitle)
                Text(LayoutCopy.artifactsText)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignColor.text.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(LayoutCopy.ignore, isOn: settings.appSettingsField(\.artifactsIgnored))
                .toggleStyle(DesignCheckbox())
                .font(.system(size: 12.5, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func addPattern(to settings: Binding<AppSettings>) {
        let trimmed = newPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var copy = settings.wrappedValue
        guard !copy.excludedPatterns.contains(trimmed) else { return }
        copy.excludedPatterns.append(trimmed)
        settings.wrappedValue = copy
        newPattern = ""
    }
}
