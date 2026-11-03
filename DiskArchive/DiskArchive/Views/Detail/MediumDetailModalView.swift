//
//  MediumDetailModalView.swift
//  DiskArchive
//
//  todo.0.4.3.010 (Layout 06.01, 06.03) — Medium-Details: Kopf mit Icon auf Höhe des Namens und Chip rechts, bei eigenem
//  Namen klein der Originalname; Kennzahl-Flächen (Gesamt, Belegt, Frei / Dateien, Ordner), graue Index-Box mit dem
//  Balken „Indiziert“, dem Fehlergrund und „Soll indiziert werden“; unten „Zuletzt gesehen“ und „Zuletzt indiziert“.
//  Metadaten und Vorschaubilder kommen mit 0.5/0.6. todo.0.4.3.009 (06.02): Name mit Stift, Benennungsmodus im Kopf.
//

import SwiftUI

struct MediumDetailModalView: View {
    @Environment(AppState.self) private var appState
    let mediumID: UUID

    private var medium: Medium? {
        appState.medium(with: mediumID)
    }

    var body: some View {
        Group {
            if let medium {
                modalContent(medium: medium)
            } else {
                Color.clear
                    .onAppear { appState.detailMediumID = nil }
            }
        }
        // Fenster zu: ein offener Benennungsmodus endet ohne Übernahme.
        .onDisappear { appState.endNaming(mediumID: mediumID) }
    }

    /// Layout `.dialog`: Innenabstand 16, Abstand 12; Inhalt mit 16 Außenabstand, Knöpfe 12 darunter.
    private func modalContent(medium: Medium) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(medium: medium)
            figures(medium: medium)
                .padding(.top, 28)
            actionButtonRow(medium: medium)
                .padding(.top, 40)
        }
        .padding(16)
        .frame(width: 540)
        .background(DesignColor.bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.lg)
                .strokeBorder(DesignColor.divider, lineWidth: DesignBorder.width)
        }
        // Schatten nur für die Gesamtform, nicht für jede Unteransicht.
        .compositingGroup()
        .shadow(color: DesignColor.shadow.opacity(0.22), radius: 16, y: 12)
    }

    private func header(medium: Medium) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                MediumTypeIcon(medium: medium, size: 34)

                Group {
                    if appState.namingMediumID == medium.id {
                        // Ein anderes Medium bekommt ein neues Feld (Startwert, Fokus), nie den Text des vorigen.
                        MediumDetailNameEditor(medium: medium)
                            .id(medium.id)
                    } else {
                        MediumDetailName(medium: medium)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    StatusChip(medium: medium)
                        .fixedSize()
                    Button {
                        appState.detailMediumID = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DesignColor.neutral700)
                            .frame(width: 24, height: 24)
                            .designControlBorder(DesignColor.divider)
                    }
                    .buttonStyle(.plainFullHit)
                    .pointerCursor()
                    .accessibilityLabel(LayoutCopy.a11yClose)
                }
                .frame(height: 24)
            }
            .frame(minHeight: 34)

            if medium.customName != nil {
                FadeMaskText(
                    text: medium.name,
                    applyFadeMask: true,
                    font: .system(size: 12),
                    foreground: DesignColor.text.opacity(0.55)
                )
                .padding(.leading, 34 + 12)
            }
        }
    }

    private func figures(medium: Medium) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                statTile(LayoutCopy.total, medium.totalCapacityLabel)
                statTile(LayoutCopy.detailUsed, medium.usedLabel)
                statTile(LayoutCopy.detailFree, medium.freeLabel)
            }
            HStack(spacing: 8) {
                statTile(LayoutCopy.files, medium.filesLabel)
                statTile(LayoutCopy.folders, medium.foldersLabel)
            }
            indexBox(medium: medium)
            HStack(spacing: 8) {
                timeTile(LayoutCopy.lastSeen, medium.lastSeenDescription(now: .now))
                timeTile(LayoutCopy.detailLastIndexed, medium.lastIndexedValue)
            }
        }
    }

    /// Kennzahl-Fläche: 5 % Textfarbe, Radius 8, Innenabstand 8/12; Beschriftung 11 leise, Wert 15 fett.
    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DesignColor.text.opacity(0.55))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
                .frame(minHeight: 20)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignColor.text.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
    }

    private func timeTile(_ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(DesignColor.text.opacity(0.55))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .lineLimit(1)
        }
        .font(.system(size: 13))
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(DesignColor.text.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
    }

    /// Graue Index-Box: Balken „Indiziert“ (110 | Balken | 44), bei Fehler der Grund (06.03), „Soll indiziert werden“.
    private func indexBox(medium: Medium) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(LayoutCopy.detailIndexed)
                    .foregroundStyle(DesignColor.text.opacity(0.55))
                    .frame(width: 110, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DesignColor.text.opacity(0.12))
                        Capsule().fill(DesignColor.text)
                            .frame(width: geo.size.width * CGFloat(min(100, max(0, medium.indexProgressPercent))) / 100)
                    }
                }
                .frame(height: 4)
                // bug.0.4.199: Fortschritt immer sichtbar, auch offline.
                Text(medium.indexedLabel)
                    .frame(width: 44, alignment: .trailing)
            }
            .font(.system(size: 13))

            if let line = medium.detailFailureLine {
                Text(line)
                    .font(.system(size: 12))
                    .lineSpacing(2)
                    .foregroundStyle(DesignColor.stateError)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 110 + 12)
                    .padding(.top, -2)
            }

            HStack(spacing: 12) {
                Text(LayoutCopy.shouldIndex)
                    .foregroundStyle(DesignColor.text.opacity(0.55))
                Spacer(minLength: 8)
                EquatableView(content: AllowIndexingBinaryGroup(
                    mediumID: medium.id,
                    allowIndexing: medium.allowIndexing,
                    isPending: medium.indexStatus == .pending,
                    isEnabled: appState.featureAccess.canWriteIndex
                ) { allow in
                    appState.updateMedium(id: medium.id, persist: true) {
                        $0.decision = allow ? .index : .dontIndex
                        $0.allowIndexing = allow
                    }
                })
            }
            .font(.system(size: 13))
            .padding(.top, 8)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DesignColor.divider)
                    .frame(height: DesignBorder.width)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(DesignColor.text.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
    }

    private func actionButtonRow(medium: Medium) -> some View {
        HStack {
            ConfirmButton(title: LayoutCopy.forget, tone: .destructive) {
                appState.forgetMedium(id: medium.id)
            }
            .disabled(!appState.featureAccess.canWriteIndex)
            .opacity(appState.featureAccess.canWriteIndex ? 1 : 0.45)

            Spacer(minLength: 12)

            let allowed = appState.canReindex(medium.id) && appState.reindexGateTick >= .distantPast
            Button(LayoutCopy.reindex) {
                appState.reindexMedium(id: medium.id)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(!allowed)
            .opacity(allowed ? 1 : 0.45)
            .pointerCursor(allowed)

            Button(LayoutCopy.showContent) {
                MediumNavigation.openColumnBrowser(for: medium.id, appState: appState)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!medium.hasIndex)
            .opacity(medium.hasIndex ? 1 : 0.45)
            .pointerCursor()
        }
    }
}

/// todo.0.4.3.009 (Layout 06.02): Name ohne Rahmen, Stift direkt dahinter; Klick auf den Stift startet den
/// Benennungsmodus. Zu lange Namen laufen rechts aus, der Stift bleibt sichtbar.
struct MediumDetailName: View {
    @Environment(AppState.self) private var appState
    let medium: Medium

    private static let font = Font.system(size: 17, weight: .bold)

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 2) {
                Text(medium.shownName)
                    .font(Self.font)
                    .lineLimit(1)
                    .fixedSize()
                pencil
            }
            HStack(spacing: 2) {
                FadeMaskText(text: medium.shownName, applyFadeMask: true, font: Self.font)
                pencil
            }
        }
        .frame(height: 24)
    }

    private var pencil: some View {
        let enabled = appState.featureAccess.canWriteIndex
        return Button {
            appState.beginNaming(mediumID: medium.id)
        } label: {
            Image("IconPencilSimple")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundStyle(DesignColor.text.opacity(0.55))
                .frame(width: 20, height: 24)
        }
        .buttonStyle(.plainFullHit)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .pointerCursor(enabled)
        .help(LayoutCopy.contextSetName)
        .accessibilityLabel(LayoutCopy.contextSetName)
    }
}

/// todo.0.4.3.009 (Layout 06.02): Benennungsmodus – Feld an der Stelle des Namens (blauer Rand mit Fokusring), Fokus
/// und Text ganz markiert. Enter oder Häkchen übernimmt, Esc oder X bricht ab; ein leeres Feld stellt den Originalnamen
/// wieder her (`Medium.normalizedCustomName`).
struct MediumDetailNameEditor: View {
    @Environment(AppState.self) private var appState
    let medium: Medium

    @State private var text: String
    @FocusState private var focused: Bool

    init(medium: Medium) {
        self.medium = medium
        _text = State(initialValue: medium.shownName)
    }

    var body: some View {
        HStack(spacing: 6) {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .bold))
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(height: 28)
                .background {
                    RoundedRectangle(cornerRadius: DesignRadius.sm)
                        .strokeBorder(DesignColor.filterSearch, lineWidth: DesignBorder.width)
                        .background {
                            RoundedRectangle(cornerRadius: DesignRadius.sm + 3)
                                .stroke(DesignColor.filterSearch.opacity(0.18), lineWidth: 3)
                                .padding(-1.5)
                        }
                }
                // Text bleibt an der Stelle des Namens (Layout: −7 links, −2 oben und unten).
                .padding(.leading, -7)
                .padding(.vertical, -2)
                .focused($focused)
                .onSubmit(commit)
                .onExitCommand(perform: cancel)
                .onChange(of: text) { _, value in
                    if value.count > Medium.customNameMaxLength {
                        text = String(value.prefix(Medium.customNameMaxLength))
                    }
                }
                .task { focused = true }

            iconButton(asset: "IconCheck", label: LayoutCopy.namingApply, action: commit)
            iconButton(asset: "IconX", label: LayoutCopy.cancel, action: cancel)
        }
        .frame(height: 24)
    }

    private func iconButton(asset: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(DesignColor.text)
                .frame(width: 26, height: 26)
                .designControlBorder(DesignBorder.secondaryControlBorderColor)
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .help(label)
        .accessibilityLabel(label)
    }

    private func commit() {
        appState.setCustomName(mediumID: medium.id, input: text)
        appState.endNaming(mediumID: medium.id)
    }

    private func cancel() {
        appState.endNaming(mediumID: medium.id)
    }
}
