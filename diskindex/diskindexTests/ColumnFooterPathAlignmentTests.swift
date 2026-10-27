//
//  ColumnFooterPathAlignmentTests.swift
//  diskindexTests
//
//  bug.0.4.220 — Der Pfad in der Fußzeile beginnt bündig mit dem Ordner-Icon der ersten Ordnerspalte und folgt der Breite
//  der Seitenleiste (auch nach dem Ziehen). Echtes Fenster außerhalb des Bildschirms, Beweis über Pixel: linke Kante der
//  Tinte von Icon und erstem Pfadzeichen, jeweils um den Abstand Rahmen → Tinte bereinigt, der an einer Vergleichsdarstellung
//  desselben Icons und desselben Texts (in `StatusFooterBar`) gemessen wird. ±0,5 pt, hell und dunkel.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct ColumnFooterPathAlignmentTests {
    private static let size = CGSize(width: 1100, height: 400)
    private static let footerHeight: CGFloat = 27

    private static func app() -> (AppState, IndexedItem) {
        let app = AppState()
        let mediumID = UUID()
        var medium = Medium(
            id: mediumID, name: "Hallo", type: .ssd, connectionStatus: .connected, indexStatus: .indexed,
            allowIndexing: true, autoIndexPaused: false, capacityTotalBytes: 1_000, capacityUsedBytes: 100,
            fileCount: 0, folderCount: 1, lastSeenAt: Date(), firstIndexedAt: Date(), lastIndexedAt: Date(),
            isForgotten: false, indexingProgress: 1
        )
        medium.completedDepth = 5
        app.media = [medium]
        app.columnBrowserState.selectedMediumID = mediumID
        let folder = IndexedItem(
            id: IndexedItem.stableID(mediumID: mediumID, rowID: 1), rowID: 1, name: "Bilder",
            kind: .folder, parentPath: [], modifiedAt: Date(), sizeBytes: 0, listedAt: Date()
        )
        app.indexRepository.seedScreenshotCache(mediumID: mediumID, entries: [([], [folder])])
        return (app, folder)
    }

    private static func scheme(_ appearance: NSAppearance.Name) -> ColorScheme { appearance == .darkAqua ? .dark : .light }

    /// Abstand Rahmen → linke Tinte: Icon (15 × 15) und Text (Fußzeile) bei x = 20.
    private static func inkInsets(asset: String, text: String, appearance: NSAppearance.Name) async throws -> (icon: CGFloat, text: CGFloat) {
        let size = CGSize(width: 300, height: 80)
        let bitmap = await PixelProbe.render(
            VStack(alignment: .leading, spacing: 0) {
                Image(asset).renderingMode(.template).resizable().scaledToFit().frame(width: 15, height: 15)
                    .foregroundStyle(DesignColor.text)
                    .padding(.leading, 20).padding(.top, 10)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
                StatusFooterBar {
                    Text(text).padding(.leading, 20)
                    Spacer(minLength: 0)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .background(DesignColor.bg)
            .environment(\.colorScheme, scheme(appearance)),
            size: size, appearance: appearance
        )
        let icon = try #require(PixelProbe.inkBounds(in: bitmap, rect: CGRect(x: 2, y: 2, width: 60, height: 36), background: CGPoint(x: 1, y: 1)))
        let line = try #require(PixelProbe.inkBounds(in: bitmap, rect: CGRect(x: 2, y: 44, width: 200, height: 30), background: CGPoint(x: 280, y: 60)))
        return (icon.minX - 20, line.minX - 20)
    }

    /// Linke Kante (Rahmen) von Icon der ersten Ordnerspalte und Pfad in der Fußzeile.
    private static func edges(_ session: PixelProbe.Session, sidebar: CGFloat, insets: (icon: CGFloat, text: CGFloat)) throws -> (icon: CGFloat, path: CGFloat) {
        session.window.contentView?.layoutSubtreeIfNeeded()
        session.window.display()
        let bitmap = session.bitmap()
        let iconInk = try #require(
            PixelProbe.inkBounds(in: bitmap, rect: CGRect(x: sidebar + 2, y: 32, width: 36, height: 40), background: CGPoint(x: sidebar + 150, y: 200)),
            "Icon nicht gefunden"
        )
        try #require(iconInk.height >= 8 && iconInk.height <= 16, "kein Icon: \(iconInk)")
        let footerTop = size.height - footerHeight + 2
        let pathInk = try #require(
            PixelProbe.inkBounds(in: bitmap, rect: CGRect(x: sidebar - 50, y: footerTop, width: 110, height: footerHeight - 4), background: CGPoint(x: size.width / 2, y: footerTop + 1)),
            "Pfad nicht gefunden"
        )
        return (iconInk.minX - insets.icon, pathInk.minX - insets.text)
    }

    /// Ziehen am Griff der Seitenleiste (Ereignisse an die getroffene Ansicht, wie `ColumnWidthPerColumnTests`).
    private static func dragSidebar(_ session: PixelProbe.Session, from x: CGFloat, by distance: CGFloat) {
        let location = { (x: CGFloat) in NSPoint(x: x, y: size.height - 200) }
        func event(_ type: NSEvent.EventType, _ x: CGFloat) -> NSEvent? {
            NSEvent.mouseEvent(
                with: type, location: location(x), modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: session.window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1
            )
        }
        guard let content = session.window.contentView,
              let target = content.hitTest(content.superview?.convert(location(x), from: nil) ?? location(x)),
              let down = event(.leftMouseDown, x) else { return }
        target.mouseDown(with: down)
        for step in stride(from: 10, through: distance, by: 10) {
            if let drag = event(.leftMouseDragged, x + step) { target.mouseDragged(with: drag) }
        }
        if let up = event(.leftMouseUp, x + distance) { target.mouseUp(with: up) }
        let deadline = Date().addingTimeInterval(0.2)
        while Date() < deadline { CFRunLoopRunInMode(.defaultMode, 0.01, true) }
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func pathStartsAtTheFolderIcon(appearance: NSAppearance.Name) async throws {
        let (app, folder) = Self.app()
        let insets = try await Self.inkInsets(asset: folder.fileKind.assetName, text: "Hallo", appearance: appearance)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, Self.scheme(appearance))
                .frame(width: Self.size.width, height: Self.size.height).background(DesignColor.bg),
            size: Self.size, appearance: appearance
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)

        let sidebar = app.columnBrowserState.sidebarWidth
        let standard = try Self.edges(session, sidebar: sidebar, insets: insets)
        #expect(abs(standard.path - standard.icon) <= 0.5, "Standardbreite: Pfad bei \(standard.path), Icon bei \(standard.icon)")

        Self.dragSidebar(session, from: sidebar - 3, by: 60)
        let dragged = app.columnBrowserState.sidebarWidth
        try #require(abs(dragged - sidebar - 60) <= 0.5, "Seitenleiste nicht gezogen: \(dragged)")
        let after = try Self.edges(session, sidebar: dragged, insets: insets)
        #expect(abs(after.path - after.icon) <= 0.5, "nach dem Ziehen: Pfad bei \(after.path), Icon bei \(after.icon)")
    }
}
}
