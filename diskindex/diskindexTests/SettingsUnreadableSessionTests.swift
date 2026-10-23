//
//  SettingsUnreadableSessionTests.swift
//  diskindexTests
//
//  bug.0.4.153: Sitzung mit unlesbaren Einstellungen – Hinweis im Einstellungsfenster, keine Läufe, Datei unverändert;
//  lesbare Datei beim Folgestart → alles normal.
//

import AppKit
import Foundation
import GRDB
import SwiftUI
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct SettingsUnreadableSessionTests {
    private func rawSettings(_ harness: StoreHarness) async throws -> String? {
        try await harness.store.pool.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM settings WHERE key = ?", arguments: [SettingsPersistence.appSettingsKey])
        }
    }

    private func writeRaw(_ raw: String, _ harness: StoreHarness) async throws {
        try await harness.store.pool.write { db in
            try db.execute(
                sql: "INSERT INTO settings (key, value, date) VALUES (?, ?, NULL) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                arguments: [SettingsPersistence.appSettingsKey, raw]
            )
        }
    }

    private func appWithSettings(_ raw: String, harness: StoreHarness) async throws -> AppState {
        try await writeRaw(raw, harness)
        let suite = "diskindex-settings-\(UUID().uuidString)"
        let defaults = TestDefaults.make()
        let app = AppState(defaults: defaults)
        app.attach(store: harness.store)
        await app.hydrateSettingsFromStore()
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return app
    }

    /// Verbindet ein bekanntes Medium wie beim Anschließen; liefert die Zahl der gestarteten Läufe nach kurzer Wartezeit.
    private func startsAfterAppearing(app: AppState, harness: StoreHarness, expectRun: Bool) async throws -> [Bool] {
        let scan = try await ScanHarness.make()
        var stored = try #require(try await scan.store.medium(uuid: scan.mediumID))
        stored.decision = .index
        try await scan.store.upsertMedium(stored)
        let volume = testVolume(path: "/Volumes/T", name: "TEST")
        try await scan.store.recordIdentity(mediumUUID: scan.mediumID, volume.identity)
        let inner = MemoryVolume(mountPath: "/Volumes/T")
        inner.file("only.txt")
        app.attach(store: scan.store)
        let rig = WiredRig(store: scan.store, access: inner, app: app)
        defer { rig.coordinator.stop() }
        await rig.coordinator.handle(.appeared(volume))
        if expectRun {
            let started = await waitUntil { !rig.starts(scan.mediumID).isEmpty }
            try #require(started)
            await rig.service.waitUntilIdle(scan.mediumID)
        } else {
            try await Task.sleep(for: .milliseconds(600))
        }
        return rig.starts(scan.mediumID)
    }

    @Test func unreadableSettingsStartNoRunAndLeaveFileUntouched() async throws {
        let harness = try StoreHarness.make()
        let raw = #"{"scanDepth":"#
        let app = try await appWithSettings(raw, harness: harness)
        #expect(app.settingsUnreadable)
        #expect(app.globalAutoIndexPaused, "unlesbare Einstellungen müssen wie Pause wirken")
        let starts = try await startsAfterAppearing(app: app, harness: harness, expectRun: false)
        #expect(starts.isEmpty, "Lauf gestartet trotz unlesbarer Einstellungen")
        #expect(try await rawSettings(harness) == raw)
        // „Fortsetzen“ hebt die Sitzungssperre nicht auf.
        app.resumeIndexing(defaults: TestDefaults.make())
        #expect(app.globalAutoIndexPaused)
        #expect(app.pauseSnapshot.isPaused == false, "gespeicherte Pause darf durch den Lesefehler nicht entstehen")
    }

    @Test func readableSettingsOnNextStartRunNormally() async throws {
        let harness = try StoreHarness.make()
        let app = try await appWithSettings(#"{"scanDepth":2}"#, harness: harness)
        #expect(!app.settingsUnreadable)
        #expect(!app.globalAutoIndexPaused)
        let starts = try await startsAfterAppearing(app: app, harness: harness, expectRun: true)
        #expect(starts == [false])
    }
}

extension WindowTestGroup {
@Suite @MainActor
struct SettingsUnreadableNoticeTests {
    private func render(_ view: some View, appearance: NSAppearance.Name) async -> NSBitmapImageRep {
        await PixelProbe.render(
            view.environment(\.colorScheme, appearance == .darkAqua ? .dark : .light),
            size: CGSize(width: 720, height: 480),
            appearance: appearance
        )
    }

    private func bannerPixel(_ app: AppState, appearance: NSAppearance.Name) async -> NSColor {
        let rep = await render(SettingsView().environment(app).frame(width: 720, height: 480), appearance: appearance)
        return PixelProbe.color(in: rep, at: CGPoint(x: 700, y: 3))
    }

    private func reference(appearance: NSAppearance.Name) async -> NSColor {
        let rep = await render(Rectangle().fill(DesignColor.neutral100).frame(width: 720, height: 480), appearance: appearance)
        return PixelProbe.color(in: rep, at: CGPoint(x: 700, y: 3))
    }

    private func same(_ a: NSColor, _ b: NSColor) -> Bool {
        guard let x = a.usingColorSpace(.sRGB), let y = b.usingColorSpace(.sRGB) else { return false }
        return abs(x.redComponent - y.redComponent) < 0.01 && abs(x.greenComponent - y.greenComponent) < 0.01
            && abs(x.blueComponent - y.blueComponent) < 0.01
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func noticeIsVisibleOnlyWhileUnreadable(_ appearance: NSAppearance.Name) async throws {
        let app = AppState()
        let expected = await reference(appearance: appearance)
        #expect(await !same(bannerPixel(app, appearance: appearance), expected), "Hinweis ohne Lesefehler sichtbar")
        app.settingsUnreadable = true
        #expect(await same(bannerPixel(app, appearance: appearance), expected), "Hinweis fehlt")
        #expect(
            LayoutCopy.settingsUnreadableNotice.contains("nicht gespeichert")
                || LayoutCopy.settingsUnreadableNotice.contains("not be saved")
        )
    }
}
}

extension WindowTestGroup {
/// bug.0.4.136: Der Spinner „Wird indiziert“ folgt dem Farbschema (dunkel ≈ #5BBD74, hell ≈ #20A04E).
@Suite @MainActor
struct IndexingSpinnerColorTests {
    private func dominantInk(appearance: NSAppearance.Name) async -> NSColor? {
        let size = CGSize(width: 260, height: 90)
        let rep = await PixelProbe.render(
            FolderPendingIndexingHint()
                .environment(\.colorScheme, appearance == .darkAqua ? .dark : .light)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .background(DesignColor.bg),
            size: size,
            appearance: appearance
        )
        // Der Ring liegt oben links (20 × 20 pt); die kräftigste grüne Farbe darin ist die Ringfarbe.
        var best: NSColor?
        var bestScore: CGFloat = 0
        for y in stride(from: 0, to: 24, by: 1) {
            for x in stride(from: 0, to: 26, by: 1) {
                guard let c = PixelProbe.color(in: rep, at: CGPoint(x: x + 4, y: y)).usingColorSpace(.sRGB) else { continue }
                let score = c.greenComponent - max(c.redComponent, c.blueComponent)
                if score > bestScore { bestScore = score; best = c }
            }
        }
        return best
    }

    /// Der Ring folgt dem Farbschema: dunkel heller als hell (stateOnline #5BBD74 gegenüber #20A04E). Die frühere feste
    /// Farbe ergäbe in beiden Erscheinungen denselben Ring.
    @Test func spinnerFollowsTheColorScheme() async throws {
        let light = try #require(await dominantInk(appearance: .aqua), "kein Ring (hell)")
        let dark = try #require(await dominantInk(appearance: .darkAqua), "kein Ring (dunkel)")
        #expect(dark.redComponent > light.redComponent + 0.1, "hell \(light), dunkel \(dark)")
        #expect(dark.greenComponent > 0.6 && light.greenComponent > 0.5)
    }
}
}
