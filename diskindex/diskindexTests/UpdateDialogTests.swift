//
//  UpdateDialogTests.swift
//  diskindexTests
//
//  todo.0.4.047: Updatedialog nach Layout 13 – Haken „Auf Updates hinweisen“ ist die Einstellung (gespeichert beim
//  Schließen), aus = kein Dialog mehr, Beta-Countdown und Sperre erscheinen trotzdem; „Zur neuen Version“ öffnet die
//  Download-Seite (Testhaken je Instanz, kein Browser). Dieselbe Einstellung im Tab Erweitert. Echtes Fenster außerhalb
//  des Bildschirms, Klicks per `sendEvent`, Pixel hell und dunkel.
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct UpdateDialogTests {
    private static let routineOffer = UpdateOffer(
        currentDisplay: "0.4.0", targetDisplay: "0.5", targetMajorMinor: AppVersion(major: 0, minor: 5, patch: 0),
        showBetaCountdown: false
    )
    private static let betaOffer = UpdateOffer(
        currentDisplay: "0.4.0", targetDisplay: "1.0", targetMajorMinor: AppVersion(major: 1, minor: 0, patch: 0),
        showBetaCountdown: true
    )

    private static func evaluation(_ offer: UpdateOffer?, lock: VersionLockState = .unlocked) -> VersionLockEvaluation {
        VersionLockEvaluation(
            lockState: lock, updateOffer: offer, showLockBanner: lock.isLocked, mutations: VersionLockSettingsMutations()
        )
    }

    /// Haken im Dialog abwählen, „Schließen“ → Einstellung aus; der nächste Check zeigt keinen Dialog, Beta-Countdown und
    /// Sperre aber doch.
    @Test(arguments: [false, true])
    func uncheckingAndClosingTurnsTheSettingOff(dark: Bool) async throws {
        let app = AppState()
        #expect(app.appSettings.notifyAboutUpdates, "Standard: an")
        app.applyVersionLockEvaluation(Self.evaluation(Self.routineOffer))
        let notice = try #require(app.updateNotice, "Dialog fehlt bei eingeschalteter Einstellung")
        #expect(notice.notifyAboutUpdates)
        let session = Self.openDialog(app, notice: notice, dark: dark)
        defer { session.close() }

        // Layout: Icon oben links (Textfarbe), primärer Knopf gefüllt.
        let bitmap = session.bitmap()
        let ink = ScopeLoadingPixels.ink(dark: dark)
        #expect(ScopeLoadingPixels.count(bitmap, region: CGRect(x: 48, y: 48, width: 30, height: 30), ink) > 40, "Icon fehlt")

        let toggle = try #require(Self.controls(in: session.window, height: 14...22).first, "Haken fehlt")
        session.click(at: CGPoint(x: toggle.minX + 8, y: toggle.midY))
        #expect(app.updateNotice?.notifyAboutUpdates == false, "Klick auf den Haken wirkt nicht")
        #expect(app.appSettings.notifyAboutUpdates, "Einstellung schon vor dem Schließen geändert")

        let buttons = Self.controls(in: session.window, height: 24...40).sorted { $0.minX < $1.minX }
        try #require(buttons.count == 2, "Knöpfe: \(buttons)")
        #expect(abs(buttons[0].width - buttons[1].width) <= 1, "Knöpfe nicht gleich breit")
        session.click(at: CGPoint(x: buttons[0].midX, y: buttons[0].midY))
        #expect(app.updateNotice == nil, "„Schließen“ schließt nicht")
        #expect(!app.appSettings.notifyAboutUpdates, "Einstellung nach dem Schließen nicht aus")

        app.applyVersionLockEvaluation(Self.evaluation(Self.routineOffer))
        #expect(app.updateNotice == nil, "Dialog trotz ausgeschalteter Einstellung")
        app.applyVersionLockEvaluation(Self.evaluation(Self.betaOffer))
        #expect(app.updateNotice?.offer.showBetaCountdown == true, "Beta-Countdown fehlt bei ausgeschalteter Einstellung")
        app.applyVersionLockEvaluation(Self.evaluation(Self.routineOffer, lock: .locked(.apiUnreachable)))
        #expect(app.updateNotice != nil, "Sperre ohne Dialog bei ausgeschalteter Einstellung")
    }

    /// „Zur neuen Version“ öffnet die Download-Seite (Testhaken) und speichert den Haken.
    @Test func getTheNewVersionOpensTheDownloadPage() async throws {
        let app = AppState()
        var opened: [URL] = []
        app.openExternalURL = { opened.append($0) }
        app.applyVersionLockEvaluation(Self.evaluation(Self.routineOffer))
        let notice = try #require(app.updateNotice)
        let session = Self.openDialog(app, notice: notice, dark: false)
        defer { session.close() }
        let buttons = Self.controls(in: session.window, height: 24...40).sorted { $0.minX < $1.minX }
        try #require(buttons.count == 2, "Knöpfe: \(buttons)")
        session.click(at: CGPoint(x: buttons[1].midX, y: buttons[1].midY))
        #expect(opened.map(\.absoluteString) == ["https://www.diskarchive.app/download/"], "geöffnet: \(opened)")
        #expect(app.updateNotice == nil)
        #expect(app.appSettings.notifyAboutUpdates, "Haken blieb an, Einstellung muss an bleiben")
    }

    /// Tab Erweitert: die Zeile „Updates“ unter Autostart schaltet dieselbe Einstellung (Pixel: Haken hell und dunkel).
    @Test(arguments: [false, true])
    func advancedTabTogglesTheSameSetting(dark: Bool) async throws {
        let app = AppState()
        app.launchAtLoginRegister = { _ in }
        app.launchAtLoginStateProvider = { .off }
        let size = CGSize(width: 860, height: 700)
        let session = PixelProbe.open(
            SettingsGeneralTab(section: .advanced)
                .environment(app)
                .environment(\.colorScheme, dark ? .dark : .light)
                .frame(width: size.width, height: size.height, alignment: .top)
                .background(DesignColor.bg),
            size: size,
            appearance: dark ? .darkAqua : .aqua
        )
        defer { session.close() }
        let rows = Self.controls(in: session.window, height: 14...22).sorted { $0.minY < $1.minY }
        try #require(rows.count >= 2, "Zeilen: \(rows)")
        // Zweite Zeile: direkt unter Autostart.
        let row = rows[1]
        let box = CGRect(x: row.minX, y: row.minY, width: 16, height: 16)
        let on = session.bitmap()
        session.click(at: CGPoint(x: row.minX + 8, y: row.midY))
        #expect(!app.appSettings.notifyAboutUpdates, "Klick schaltet die Einstellung nicht aus")
        let drawn = await waitUntil { Self.differs(on, session.bitmap(), in: box) }
        #expect(drawn, "Haken ändert sich im Bild nicht")
        session.click(at: CGPoint(x: row.minX + 8, y: row.midY))
        #expect(app.appSettings.notifyAboutUpdates, "zweiter Klick schaltet nicht wieder ein")
    }

    // MARK: - Hilfen

    private static func openDialog(_ app: AppState, notice: UpdateNotice, dark: Bool) -> PixelProbe.Session {
        let size = CGSize(width: 424, height: 360)
        return PixelProbe.open(
            UpdateAvailableDialog(notice: notice)
                .environment(app)
                .environment(\.colorScheme, dark ? .dark : .light)
                .frame(width: size.width, height: size.height, alignment: .top),
            size: size,
            appearance: dark ? .darkAqua : .aqua
        )
    }

    /// Bedienelemente (Fokus-Stellvertreter der SwiftUI-Steuerelemente) mit Höhe in `height`, Koordinaten von oben.
    private static func controls(in window: NSWindow, height: ClosedRange<CGFloat>) -> [CGRect] {
        guard let root = window.contentView else { return [] }
        let total = root.bounds.height
        return proxies(in: root).compactMap { view in
            let frame = view.convert(view.bounds, to: nil)
            guard height.contains(frame.height), frame.width > 40, frame.width < 400 else { return nil }
            return CGRect(x: frame.minX, y: total - frame.maxY, width: frame.width, height: frame.height)
        }
    }

    private static func proxies(in view: NSView) -> [NSView] {
        let name = String(describing: type(of: view))
        var found: [NSView] = name.contains("KeyViewProxy") ? [view] : []
        for subview in view.subviews {
            found.append(contentsOf: proxies(in: subview))
        }
        return found
    }

    private static func differs(_ lhs: NSBitmapImageRep, _ rhs: NSBitmapImageRep, in rect: CGRect) -> Bool {
        var y = rect.minY + 3
        while y < rect.maxY - 3 {
            var x = rect.minX + 3
            while x < rect.maxX - 3 {
                let a = PixelProbe.color(in: lhs, at: CGPoint(x: x, y: y)).usingColorSpace(.sRGB)
                let b = PixelProbe.color(in: rhs, at: CGPoint(x: x, y: y)).usingColorSpace(.sRGB)
                if let a, let b, abs(a.redComponent - b.redComponent) + abs(a.greenComponent - b.greenComponent)
                    + abs(a.blueComponent - b.blueComponent) > 0.3 { return true }
                x += 1
            }
            y += 1
        }
        return false
    }
}
}
