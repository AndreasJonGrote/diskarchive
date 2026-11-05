//
//  ColumnFolderStatusPanels.swift
//  DiskArchive
//
//  Layout Screen 07 — Sonderzustände in der Ordnerspalte (Aufgabe 139).
//  todo.0.4.3.016 (Layout 07.02.03–08): alle Zustände mit einem Aufbau – Icon 20 pt (10 pt Abstand), Titel 12 pt halbfett
//  (6 pt), Text 11 pt, Zeilenhöhe 1,45, 55 %, höchstens 260 pt (10 pt), darunter Link (11 pt halbfett, unterstrichen) oder
//  Fortschritt (11 pt, 55 %); Innenabstand 4/10 pt.
//

import SwiftUI

/// Gemeinsamer Aufbau der Statusflächen (eine Quelle, Regel 7).
struct ColumnStatusPanel<Icon: View>: View {
    struct Link {
        let title: String
        let action: () -> Void
    }

    let title: String
    let message: String?
    var link: Link?
    var progress: String?
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            icon()
                .frame(width: 20, height: 20)
                .padding(.bottom, 10)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignColor.text)
                .padding(.bottom, 6)
            if let message {
                Text(message)
                    .font(.system(size: 11))
                    // Zeilenhöhe 1,45 bei 11 pt (≈ 13 pt Schriftzeile).
                    .lineSpacing(11 * 1.45 - 13)
                    .foregroundStyle(DesignColor.text.opacity(0.55))
                    .frame(maxWidth: 260, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)
            }
            if let link {
                Button(link.title, action: link.action)
                    .buttonStyle(.plainFullHit)
                    .font(.system(size: 11, weight: .semibold))
                    .underline()
                    .foregroundStyle(DesignColor.text)
                    .pointerCursor()
            }
            if let progress {
                Text(progress)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(DesignColor.text.opacity(0.55))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// todo.0.4.3.016: Inhalt je Zustand (Layout 07.02.03–08) – Titel, Text, Icon, Link; testbar ohne Fenster.
enum ColumnFolderStatus: Equatable {
    case indexing
    case loading
    case scanDepth
    case excluded
    case unreadable

    enum Icon: Equatable {
        /// Spinner (grün beim Indizieren, Textfarbe beim Laden).
        case spinner(online: Bool)
        /// Phosphor-Glyphe aus dem Asset-Katalog in Gelb bzw. Rot.
        case glyph(asset: String, red: Bool)
    }

    enum LinkTarget: Equatable {
        case scanDepth
        case filesSettings
    }

    init(_ reason: ColumnFolderUncapturedReason) {
        switch reason {
        case .scanDepth: self = .scanDepth
        case .excluded: self = .excluded
        case .unreadable: self = .unreadable
        }
    }

    var title: String {
        switch self {
        case .indexing: LayoutCopy.indexingInProgress
        case .loading: LayoutCopy.columnContentsLoading
        case .scanDepth: LayoutCopy.folderNotIndexedTitle
        case .excluded: LayoutCopy.folderExcluded
        case .unreadable: LayoutCopy.folderUnreadable
        }
    }

    var message: String {
        switch self {
        case .indexing: LayoutCopy.folderPendingIndexingBody
        case .loading: LayoutCopy.folderLoadingManyObjects
        case .scanDepth: LayoutCopy.uncapturedScanDepthHint
        case .excluded: LayoutCopy.folderExcludedBody
        case .unreadable: LayoutCopy.folderUnreadableBody
        }
    }

    var icon: Icon {
        switch self {
        case .indexing: .spinner(online: true)
        case .loading: .spinner(online: false)
        case .scanDepth: .glyph(asset: "IconFolderDuotone", red: false)
        case .excluded: .glyph(asset: "IconEyeSlash", red: false)
        case .unreadable: .glyph(asset: "IconWarningBold", red: true)
        }
    }

    /// Link unter dem Text: Scan-Tiefe bzw. Einstellungen › Dateien & Ordner; nicht lesbar ohne Link.
    var link: (title: String, target: LinkTarget)? {
        switch self {
        case .scanDepth: (LayoutCopy.changeScanDepth, .scanDepth)
        case .excluded: (LayoutCopy.folderChangeExclusions, .filesSettings)
        case .indexing, .loading, .unreadable: nil
        }
    }
}

/// Icon einer Statusfläche (20 pt wie `font-size:20px` im Layout).
struct ColumnStatusIcon: View {
    let icon: ColumnFolderStatus.Icon

    var body: some View {
        switch icon {
        case .spinner(let online):
            IndexingSpinnerRing(color: online ? DesignColor.stateOnline : DesignColor.text, lineWidth: 2.5)
                .padding(1.25)
        case .glyph(let asset, let red):
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(red ? ColumnStatusColor.red : ColumnStatusColor.yellow)
        }
    }
}

enum ColumnStatusColor {
    /// Layout `#EDA12D` (Scan-Tiefe, ausgeschlossen).
    static let yellow = Color(red: 237 / 255, green: 161 / 255, blue: 45 / 255)
    /// Layout `#E04830` (nicht lesbar).
    static let red = Color(red: 224 / 255, green: 72 / 255, blue: 48 / 255)
}

/// Statusfläche eines Ordnerzustands; der Link führt in die Einstellungen.
struct ColumnFolderStatusView: View {
    let status: ColumnFolderStatus
    var progress: String?
    @Environment(AppState.self) private var appState

    var body: some View {
        ColumnStatusPanel(
            title: status.title,
            message: status.message,
            link: status.link.map { link in
                .init(title: link.title) {
                    switch link.target {
                    case .scanDepth:
                        MediumNavigation.openSettings(appState: appState, tab: .files, scrollTarget: .scanDepth)
                    case .filesSettings:
                        MediumNavigation.openSettings(appState: appState, tab: .files)
                    }
                }
            },
            progress: progress
        ) {
            ColumnStatusIcon(icon: status.icon)
        }
    }
}

/// 07.02.03: Ordner wird gerade indiziert (grüner Spinner).
struct FolderPendingIndexingHint: View {
    var body: some View {
        ColumnStatusPanel(title: ColumnFolderStatus.indexing.title, message: ColumnFolderStatus.indexing.message) {
            ColumnStatusIcon(icon: ColumnFolderStatus.indexing.icon)
        }
    }
}

/// 07.02.08: Inhalt wird geladen (Spinner in Textfarbe, „{1} von {2} Objekten geladen“).
struct FolderContentsLoadingHint: View {
    let loaded: Int
    let total: Int

    var body: some View {
        ColumnStatusPanel(
            title: ColumnFolderStatus.loading.title,
            message: ColumnFolderStatus.loading.message,
            progress: total > 0 ? LayoutCopy.folderLoadingProgress(loaded: loaded, total: total) : nil
        ) {
            ColumnStatusIcon(icon: ColumnFolderStatus.loading.icon)
        }
    }
}

/// Lesefehler der Datenbank beim Öffnen eines Ordners (Aufgabe 109): Icon und Titel wie 07.02.07, ohne Erklärung.
struct FolderContentsLoadErrorHint: View {
    let message: String

    var body: some View {
        ColumnStatusPanel(title: message, message: nil) {
            ColumnStatusIcon(icon: ColumnFolderStatus.unreadable.icon)
        }
    }
}

/// 07.02.05–07: Ordner, dessen Inhalt nicht erfasst ist (Scan-Tiefe, ausgeschlossen, nicht lesbar).
struct FolderUncapturedColumnHint: View {
    let reason: ColumnFolderUncapturedReason

    var body: some View {
        ColumnFolderStatusView(status: ColumnFolderStatus(reason))
    }
}

/// todo.0.4.2.003 (Layout 07.02.04, 08): Status in der Ordnerspalte bei aktivem Filter – „Keine passenden Objekte“ mit
/// Link „Alle Filter zurücksetzen“ bzw. „Filter wird angewendet“.
struct ColumnFilterStatusPanel: View {
    enum Kind {
        case noMatches
        case applying
    }

    let kind: Kind
    let onReset: () -> Void

    var body: some View {
        ColumnStatusPanel(
            title: kind == .noMatches ? LayoutCopy.columnFilterNoMatchesTitle : LayoutCopy.columnFilterApplyingTitle,
            message: kind == .noMatches ? LayoutCopy.columnFilterNoMatchesBody : LayoutCopy.columnFilterApplyingBody,
            link: .init(title: LayoutCopy.columnFilterReset, action: onReset)
        ) {
            icon
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .noMatches:
            // Phosphor `funnel`, duotone (wie das Filter-Icon der Werkzeugleiste).
            ZStack {
                Image("IconFunnelFill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .opacity(ToolbarNavIconRole.filter.fillOpacity)
                Image("IconFunnelStroke")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            }
            .foregroundStyle(DesignColor.filterSearch)
        case .applying:
            IndexingSpinnerRing(color: DesignColor.filterSearch, lineWidth: 2.5)
                .padding(1.25)
        }
    }
}
