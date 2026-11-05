//
//  SettingsFilesAndRegistryTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.018 (Layout 05.01, 05.02, 05.08a, 19): Hinweisfläche oben auf „Dateien & Ordner“, gekürzte Texte aus 20,
//  Spalte „Zuletzt gesehen“ in „Speichermedien“ mit Sortierung, Freigabe-Link nur bei `requiresApproval`, Hinweis bei
//  unlesbaren Einstellungen aus 20.
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

@MainActor
struct SettingsFilesAndRegistryTests {
    @Test func textsComeFromSectionTwenty() {
        L10n.$languageOverride.withValue(.german) {
            #expect(LayoutCopy.settingsFilesNotice.hasPrefix("Was durch eine Änderung auf dieser Seite wegfällt"))
            #expect(LayoutCopy.scanDepthText == "Wie viele Ordnerebenen unterhalb des Wurzelverzeichnisses eines Speichermediums durchsucht werden. „5+“ durchsucht uneingeschränkt alles.")
            #expect(LayoutCopy.hiddenText == "Schließt versteckte Systemdateien und -ordner vom Index aus.")
            #expect(!LayoutCopy.excludeText.contains("1 Stunde") && !LayoutCopy.artifactsText.contains("1 Stunde"), "Einzelsätze zum Ausschalten")
            #expect(LayoutCopy.registryLastSeen == "Zuletzt gesehen")
            #expect(LayoutCopy.settingsUnreadableNotice == "Einstellungen konnten nicht gelesen werden – Änderungen werden nicht gespeichert.")
        }
        L10n.$languageOverride.withValue(.english) {
            #expect(LayoutCopy.settingsUnreadableNotice == "Settings couldn’t be read – changes won’t be saved.")
        }
    }

    @Test func approvalLinkOnlyWhenApprovalIsRequired() {
        #expect(AutostartApprovalLink.isShown(for: .requiresApproval))
        #expect(!AutostartApprovalLink.isShown(for: .on))
        #expect(!AutostartApprovalLink.isShown(for: .off))
    }

    @Test func lastSeenColumnSortsConnectedFirstThenNewest() throws {
        func medium(_ name: String, online: Bool, daysAgo: Int?) -> Medium {
            Medium(
                id: UUID(), name: name, type: .usb, connectionStatus: online ? .connected : .offline, indexStatus: .indexed,
                allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1, capacityUsedBytes: 0, fileCount: 0,
                folderCount: 0, lastSeenAt: daysAgo.map { Date(timeIntervalSinceNow: -Double($0) * 86_400) },
                firstIndexedAt: nil, lastIndexedAt: nil, isForgotten: false, indexingProgress: 1
            )
        }
        let media = [
            medium("Alt", online: false, daysAgo: 90), medium("Nie", online: false, daysAgo: nil),
            medium("Jetzt", online: true, daysAgo: 400), medium("Neu", online: false, daysAgo: 3),
        ]
        let descending = RegistrySortState(column: .lastSeen, ascending: true).sorted(media)
        #expect(descending.map(\.name) == ["Jetzt", "Neu", "Alt", "Nie"])
        let ascending = RegistrySortState(column: .lastSeen, ascending: false).sorted(media)
        #expect(ascending.map(\.name) == ["Nie", "Alt", "Neu", "Jetzt"])
    }

    /// Hinweisfläche (5 % Textfarbe) über volle Breite oben auf „Dateien & Ordner“, nicht auf „Allgemein“.
    @Test func filesTabStartsWithTheNoticeArea() async {
        let app = AppState()
        let size = CGSize(width: 640, height: 220)
        func probe(_ section: SettingsGeneralTab.Section) async -> NSColor {
            let bitmap = await PixelProbe.render(
                SettingsGeneralTab(section: section).environment(app).environment(\.colorScheme, .light)
                    .background(Color.white),
                size: size
            )
            // Innenabstand 24 pt, Fläche beginnt dort; Probe rechts neben dem Text, wo die Fläche frei ist.
            return PixelProbe.color(in: bitmap, at: CGPoint(x: size.width - 40, y: 30))
        }
        let files = await probe(.files)
        let general = await probe(.general)
        #expect(files.redComponent < 0.985 && files.redComponent > 0.9, "keine Hinweisfläche: \(files)")
        #expect(general.redComponent > 0.985, "Fläche auch auf „Allgemein“: \(general)")
    }
}
