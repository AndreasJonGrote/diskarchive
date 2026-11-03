//
//  SettingsGeneralTab.swift
//  DiskArchive
//

import SwiftUI

struct SettingsGeneralTab: View {
    /// Ereignis-Checkboxen unter „Mitteilungen aktivieren“ (Layout 05, Hierarchie).
    static let noticeEventsLeadingInset: CGFloat = 25

    enum Section {
        case general, files, advanced
    }

    var section: Section = .general
    @Environment(AppState.self) private var appState
    private var launchAtLogin: LaunchAtLogin.State { appState.launchAtLoginState }
    @State private var noticePreview: DiskNotice?
    var body: some View {
        let settings = appState.appSettingsBinding

        ScrollViewReader { scroll in
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch section {
                case .general:
                    SettingsLanguageSection(selection: settings.appSettingsField(\.displayLanguage))
                    DesignDivider()
                    appearanceSection(settings: settings)
                    DesignDivider()
                    notificationsSection(settings: settings)
                case .files:
                    scanDepthSection(settings: settings)
                        .id(SettingsScrollTarget.scanDepth)
                    DesignDivider()
                    SettingsIgnoredObjectsTab()
                case .advanced:
                    launchAtLoginSection
                    DesignDivider()
                    updatesSection(settings: settings)
                    DesignDivider()
                    reportsSection
                    DesignDivider()
                    pruneSection
                    DesignDivider()
                    defaultsSection
                    DesignDivider()
                    forgetMediaSection
                }
            }
            .padding(24)
            // bug.0.4.091: alle Tabs gleich breit, kein Springen, wenn der Rollbalken (dauerhafter Stil) erscheint.
            .stableScrollbarGutter()
        }
        .onAppear {
            // bug.0.4.135 (Regel 15): nur scrollen; das Ziel räumt `AppState` beim Wechsel von Tab oder Ansicht ab.
            guard section == .files, appState.settingsScrollTarget == .scanDepth else { return }
            scroll.scrollTo(SettingsScrollTarget.scanDepth, anchor: .top)
        }
        }
    }

    /// Aufgabe 30.2 — „Auf Standard zurücksetzen“ ändert das bewusst nicht (Systemeinstellung, kein App-Wert).
    private func appearanceSection(settings: Binding<AppSettings>) -> some View {
        settingsSplit(title: LayoutCopy.appearanceTitle, text: LayoutCopy.appearanceText) {
            AppearancePickerBlock(selection: settings.appSettingsField(\.appearance))
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var launchAtLoginSection: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionTitle(title: LayoutCopy.autostartTitle)
                Text(LayoutCopy.autostartText)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignColor.text.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Toggle(LayoutCopy.autostartToggle, isOn: Binding(
                    get: { launchAtLogin != .off },
                    set: { enabled in
                        appState.launchAtLoginState = enabled ? .on : .off
                        let register = appState.launchAtLoginRegister
                        let readState = appState.launchAtLoginStateProvider
                        Task {
                            let state = await Task.detached {
                                register(enabled)
                                return readState()
                            }.value
                            if (state != .off) != enabled {
                                LaunchAtLogin.logMismatch(requested: enabled, actual: state)
                            }
                            appState.launchAtLoginState = state
                        }
                    }
                ))
                .toggleStyle(DesignCheckbox())
                .font(.system(size: 12.5, weight: .semibold))
                .tint(DesignColor.control)

                if launchAtLogin == .requiresApproval {
                    Button {
                        LaunchAtLogin.openSystemSettings()
                    } label: {
                        Text(LayoutCopy.openSystemSettingsForPermission)
                            .foregroundStyle(DesignColor.stateIgnored)
                    }
                    .buttonStyle(.plainFullHit)
                    .font(.system(size: 11.5))
                    .pointerCursor()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// todo.0.4.047: „Auf Updates hinweisen“ (Layout des Nutzers 24.10.: Muster wie Autostart, darunter).
    private func updatesSection(settings: Binding<AppSettings>) -> some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionTitle(title: LayoutCopy.updatesTitle)
                Text(LayoutCopy.updatesText)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignColor.text.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(LayoutCopy.updatesToggle, isOn: settings.appSettingsField(\.notifyAboutUpdates))
                .toggleStyle(DesignCheckbox())
                .font(.system(size: 12.5, weight: .semibold))
                .tint(DesignColor.control)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func scanDepthSection(settings: Binding<AppSettings>) -> some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionTitle(title: LayoutCopy.scanDepthTitle)
                Text(LayoutCopy.scanDepthText)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignColor.text.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(LayoutCopy.depthLabel)
                        .font(.system(size: 11, weight: .bold))
                        .kerning(0.6)
                    Spacer()
                    Text(settings.wrappedValue.scanDepthLabel)
                        .font(.system(size: 11, weight: .bold))
                        .kerning(0.6)
                }

                StepSlider(
                    value: settings.scanDepth,
                    range: 1...AppSettings.unlimitedScanDepth,
                    labels: (1...AppSettings.unlimitedScanDepth).map {
                        $0 == AppSettings.unlimitedScanDepth ? "\($0)+" : "\($0)"
                    }
                )
                .padding(.top, 4)

                scanDepthExample(depth: settings.wrappedValue.scanDepth)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func scanDepthExample(depth: Int) -> some View {
        let crumbs = ScanDepthExampleFormatting.crumbs(
            depth: depth,
            unlimited: depth >= AppSettings.unlimitedScanDepth
        )
        return VStack(alignment: .leading, spacing: 5) {
            Text(LayoutCopy.exampleHeading)
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(DesignColor.text.opacity(0.45))

            HStack(spacing: 7) {
                ForEach(crumbs) { crumb in
                    Text(crumb.text)
                        .font(.system(size: 11))
                        .italic()
                        .fontWeight(crumb.isCaptured ? .semibold : .regular)
                        .foregroundStyle(
                            crumb.isCaptured ? DesignColor.control : DesignColor.text.opacity(0.55)
                        )
                    if !crumb.isLast {
                        Text("→")
                            .font(.system(size: 11))
                            .foregroundStyle(DesignColor.text.opacity(0.35))
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .settingsExampleBox()
    }

    private func notificationsSection(settings: Binding<AppSettings>) -> some View {
        settingsSplit(title: LayoutCopy.noticesTitle, text: nil, description: { notificationsDescriptionText }) {
            // Aufgabe 144 — Zeilenhöhe 19 + Abstand 8 → Mitte–Mitte 27; Einrückung 25; Kasten +15.
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    noticeRowChrome {
                        Toggle(LayoutCopy.noticesToggle, isOn: Binding(
                            get: { appState.notificationsToggleShown },
                            set: { appState.setNotificationsEnabled($0) }
                        ))
                            .toggleStyle(DesignCheckbox())
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        noticeRow(LayoutCopy.noticeSystem, event: .system, isOn: settings.notifySystem)
                        noticeRow(LayoutCopy.noticeIndexed, event: .indexed, isOn: settings.notifyIndexed)
                        noticeRow(LayoutCopy.noticeFavorites, event: .favorites, isOn: settings.notifyFavorites)
                    }
                    .padding(.leading, SettingsGeneralTab.noticeEventsLeadingInset)
                    .disabled(!appState.notificationsToggleShown)
                    .opacity(appState.notificationsToggleShown ? 1 : 0.45)
                }
                NoticePreviewCard(event: noticePreview ?? appState.noticePreviewPin ?? .system)
                    .padding(.top, 15)
                    .disabled(!appState.notificationsToggleShown)
                    .opacity(appState.notificationsToggleShown ? 1 : 0.45)
            }
        }
        .font(.system(size: 12.5, weight: .semibold))
        .onAppear {
            if let pin = appState.noticePreviewPin { noticePreview = pin }
        }
    }

    private var pruneSection: some View {
        settingsSplit(title: LayoutCopy.pruneTitle, text: LayoutCopy.pruneText) {
            ConfirmButton(title: LayoutCopy.pruneButton, tone: .neutral) {
                appState.requestIgnoredObjectsPurgeNow()
            }
        }
    }

    private var defaultsSection: some View {
        settingsSplit(title: LayoutCopy.defaultsTitle, text: LayoutCopy.defaultsText) {
            ConfirmButton(title: LayoutCopy.defaultsButton, tone: .muted) {
                appState.applyFactoryDefaults()
            }
        }
    }

    private var forgetMediaSection: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionTitle(title: LayoutCopy.mediaTitle)
                Text(LayoutCopy.mediaText)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignColor.text.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                Text(LayoutCopy.mediaWarning)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DesignColor.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ConfirmButton(title: LayoutCopy.forgetAll, tone: .destructive) {
                appState.forgetAllMedia()
            }
            .disabled(!appState.featureAccess.canWriteIndex)
            .opacity(appState.featureAccess.canWriteIndex ? 1 : 0.45)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var reportsSection: some View {
        let settings = appState.appSettingsBinding
        return settingsSplit(title: LayoutCopy.reportsTitle, text: LayoutCopy.reportsText) {
            Toggle(LayoutCopy.autoSend, isOn: settings.appSettingsField(\.autoSendCrashReports))
            .font(.system(size: 12.5, weight: .semibold))
            .toggleStyle(DesignCheckbox())
        }
    }

    private var notificationsDescriptionText: some View {
        Text(LayoutCopy.noticesText)
            .foregroundStyle(DesignColor.text.opacity(0.6))
        .font(.system(size: 12, weight: .regular))
        .fixedSize(horizontal: false, vertical: true)
    }

    private func settingsSplit<Control: View>(
        title: String,
        text: String? = nil,
        @ViewBuilder description: () -> some View = { EmptyView() },
        @ViewBuilder control: () -> Control
    ) -> some View {
        SettingsSplitRow(title: title, text: text, description: description, control: control)
    }

    private func noticeRow(_ title: String, event: DiskNotice, isOn: Binding<Bool>) -> some View {
        noticeRowChrome {
            Toggle(title, isOn: isOn)
                .toggleStyle(DesignCheckbox())
                .onHover { inside in
                    guard appState.noticePreviewPin == nil else { return }
                    noticePreview = inside ? event : nil
                }
        }
    }

    /// Feste Zeilenhöhe 19, damit VStack-Spacing 8 → Mitte–Mitte 27 (Toggle sonst höher).
    private func noticeRowChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Color.clear
            .frame(height: 19)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) { content() }
            .clipped()
    }
}

struct NoticePreviewCard: View {
    let event: DiskNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LayoutCopy.exampleHeading)
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(DesignColor.text.opacity(0.45))
            HStack(alignment: .top, spacing: 8) {
                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LayoutCopy.diskArchive)
                        .font(.system(size: 11, weight: .bold))
                    Text(NoticeCopy.preview(event))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(DesignColor.text.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .background(DesignColor.text.opacity(0.03))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    DesignColor.text.opacity(0.4),
                    style: StrokeStyle(lineWidth: DesignBorder.width, dash: [3, 2])
                )
        }
    }

    private var iconName: String {
        switch event {
        case .system: "IconWarning"
        case .indexed: "IconCheckCircle"
        case .favorites: "NavBookmarks"
        }
    }

    private var iconColor: Color {
        switch event {
        case .system: DesignColor.text
        case .indexed: DesignColor.stateOnline
        case .favorites: DesignColor.favorite
        }
    }
}

struct SettingsSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .kerning(0.6)
            .accessibilityLabel(title)
            .accessibilityIdentifier(title)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// Gestrichelte „BEISPIEL“-Box in den Einstellungen.
    func settingsExampleBox() -> some View {
        padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignColor.text.opacity(0.03))
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.sm)
                    .strokeBorder(DesignColor.divider.opacity(0.35), style: StrokeStyle(lineWidth: DesignBorder.width, dash: [4, 3]))
            }
    }
}

/// Titel und Text links, Bedienelement rechts — eine Quelle für alle Abschnitte.
struct SettingsSplitRow<Description: View, Control: View>: View {
    let title: String
    var text: String?
    let description: Description
    let control: Control

    init(title: String, text: String?, @ViewBuilder description: () -> Description, @ViewBuilder control: () -> Control) {
        self.title = title
        self.text = text
        self.description = description()
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionTitle(title: title)
                if let text {
                    Text(text)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(DesignColor.text.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    description
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Eigene Ansicht: Öffnen des Feldes berechnet nur diesen Abschnitt neu, nicht die ganze Seite.
/// `zIndex` wirkt als Merkmal im `VStack` der Seite und legt den Abschnitt über die folgenden.
struct SettingsLanguageSection: View {
    @Binding var selection: AppDisplayLanguage
    @State private var isOpen = false

    var body: some View {
        SettingsSplitRow(title: LayoutCopy.languageTitle, text: nil, description: {
            Text(LayoutCopy.languageText)
                .foregroundStyle(DesignColor.text.opacity(0.6))
                .font(.system(size: 12, weight: .regular))
                .fixedSize(horizontal: false, vertical: true)
        }) {
            SettingsLanguagePicker(selection: $selection, isOpen: $isOpen)
        }
        .zIndex(isOpen ? 10 : 0)
    }
}
