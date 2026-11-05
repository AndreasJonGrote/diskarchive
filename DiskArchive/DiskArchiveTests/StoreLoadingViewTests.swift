//
//  StoreLoadingViewTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.015 (Layout 03.11, 04.01a, 07.02.08): Startzustand „Inhalte werden geladen“ – schwarzer Spinner 20, 10 pt
//  darunter der Text; im Popover statt der Medienliste auf einer Fläche von mindestens 180 pt. Hell und dunkel, Beweis
//  über Pixel (Tintenbänder).
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

@MainActor
struct StoreLoadingViewTests {
    /// Senkrechte Bänder (pt) mit Pixeln, die sich vom Hintergrund unterscheiden, im Streifen `x`.
    private static func bands(_ bitmap: NSBitmapImageRep, x: ClosedRange<CGFloat>, height: CGFloat) -> [ClosedRange<CGFloat>] {
        let background = PixelProbe.color(in: bitmap, at: CGPoint(x: 2, y: 2))
        var result: [ClosedRange<CGFloat>] = []
        var start: CGFloat?
        var y: CGFloat = 0
        while y < height {
            var ink = false
            var column = x.lowerBound
            while column <= x.upperBound, !ink {
                let c = PixelProbe.color(in: bitmap, at: CGPoint(x: column, y: y))
                ink = abs(c.redComponent - background.redComponent) + abs(c.greenComponent - background.greenComponent)
                    + abs(c.blueComponent - background.blueComponent) > 0.4
                column += 1
            }
            if ink, start == nil { start = y }
            if !ink, let begin = start { result.append(begin...(y - 0.5)); start = nil }
            y += 0.5
        }
        return result
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func spinnerTextGapAndPopoverHeight(appearance: NSAppearance.Name) async throws {
        let size = CGSize(width: 340, height: 240)
        let bitmap = await PixelProbe.render(
            StoreLoadingView(inPopover: true)
                .environment(\.colorScheme, appearance == .darkAqua ? .dark : .light)
                .frame(width: size.width)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: size.width, height: size.height, alignment: .top)
                .background(DesignColor.bg),
            size: size,
            appearance: appearance
        )
        let found = Self.bands(bitmap, x: 100...240, height: size.height)
        // Der Spinner dreht sich (seine Tinte wechselt); fest ist der Text. Inhalt mittig in 180: Oberkante der
        // Textzeile = (180 − (20 + Abstand + Zeile)) / 2 + 20 + Abstand. Gemessen 100,0–100,5 bei 10 pt; bei 8 pt eine
        // Stufe höher (99,0–99,5).
        let text = try #require(found.last, "kein Text: \(found)")
        #expect(text.lowerBound >= 99.75 && text.lowerBound <= 101, "Textzeile bei \(text.lowerBound) (\(found))")

        let height = NSHostingView(rootView: StoreLoadingView(inPopover: true).frame(width: 340)).fittingSize.height
        #expect(height >= 180 - 0.5, "Popover-Fläche \(height) statt mindestens 180")
        #expect(StoreLoadingView.spacing == 10)
    }

    @Test func popoverKeepsHeaderAndFooterWhileLoading() {
        let app = AppState()
        app.storeOpening = true
        #expect(app.isStoreLoading)
        #expect(MenuBarPopoverLayout.idleFullHeight(media: app.popoverConnectedMedia)
            == MenuBarPopoverLayout.headerHeight + MenuBarPopoverLayout.searchStateHeight
                + MenuBarPopoverLayout.footerAutoIndexHeight + MenuBarPopoverLayout.footerOpenAppHeight)
    }
}
