//
//  MediumNamingTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.009 (Konzept `medien.md` 2d, Layout 06.02, 12): „Benennen“ im Kontextmenü der Medien öffnet überall das
//  Details-Fenster im Benennungsmodus – Fokus im Namensfeld, Text ganz markiert; Enter übernimmt, Esc bricht ab, ein
//  leeres Feld stellt den Originalnamen wieder her. Kachel und Seitenleiste bearbeiten nicht mehr an Ort und Stelle.
//  Echte Fenster außerhalb des Bildschirms: Klick auf den Menüeintrag und Tasten per `window.sendEvent`, Beweis über
//  den Schlüssel `customName` in `storage_meta`.
//

import AppKit
import Foundation
import GRDB
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@MainActor
@Suite(.serialized)
struct MediumNamingTests {
    private struct Rig {
        let directory: URL
        let store: IndexStoreV3
        let mediumID: UUID

        func close() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private static func makeRig(customName: String? = nil) async throws -> Rig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-naming-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = IndexStoreV3(database: try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite")))
        let studio = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Studio Backup", decision: .index, indexStatus: .indexed, completedDepth: 1)
        try await store.upsertMedium(studio)
        if let customName {
            try await store.setCustomName(mediumUUID: studio.uuid, input: customName)
        }
        return Rig(directory: directory, store: store, mediumID: studio.uuid)
    }

    private static func app(_ store: IndexStoreV3) async -> AppState {
        let app = AppState(store: store)
        await app.loadStoredMedia()
        app.mainWindowDestination = .dashboard
        return app
    }

    /// Wert des Schlüssels `customName` (`nil` = Zeile fehlt).
    private static func storedCustomName(_ store: IndexStoreV3, _ uuid: UUID) async throws -> String? {
        try await store.pool.read { db in
            let storageID = try #require(try MediumCodecV3.storageRowID(db, uuid: uuid))
            return try MediumCodecV3.metaValue(db, storageID, .customName)
        }
    }

    // MARK: Fenster, Menü, Tasten

    /// Zeilenbänder (pt von oben) mit Tinte (ein Kanal unter `limit`) im Ausschnitt; Lücken bis 4 pt (Teile eines
    /// Icons) gehören zum selben Band.
    private static func inkBands(
        _ bitmap: NSBitmapImageRep, x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>, limit: CGFloat
    ) -> [ClosedRange<CGFloat>] {
        var bands: [ClosedRange<CGFloat>] = []
        var start: CGFloat?
        var row = y.lowerBound
        while row <= y.upperBound {
            var ink = false
            var column = x.lowerBound
            while column <= x.upperBound, !ink {
                let sample = PixelProbe.color(in: bitmap, at: CGPoint(x: column, y: row))
                ink = min(sample.redComponent, sample.greenComponent, sample.blueComponent) < limit
                column += 1
            }
            if ink, start == nil { start = row }
            if !ink, let begin = start {
                if let last = bands.last, begin - last.upperBound <= 5 {
                    bands[bands.count - 1] = last.lowerBound...(row - 1)
                } else {
                    bands.append(begin...(row - 1))
                }
                start = nil
            }
            row += 1
        }
        if let begin = start { bands.append(begin...y.upperBound) }
        return bands
    }

    /// Details-Fenster des Mediums (wie im Hauptfenster).
    private static func openDetails(_ app: AppState, _ mediumID: UUID) async -> PixelProbe.Session {
        let size = CGSize(width: 600, height: 520)
        let session = PixelProbe.open(
            MediumDetailModalView(mediumID: mediumID)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height, alignment: .top),
            size: size
        )
        await PixelProbe.settleOpenWindow(session)
        return session
    }

    /// Kontextmenü für `target` öffnen (eigenes Fenster, wie das Panel) und auf „Benennen“ klicken.
    /// Liefert die dunkelste Farbe im Icon von „Details“ und „Benennen“ (Ausgrauen).
    @discardableResult
    private static func chooseSetName(_ app: AppState, mediumID: UUID) async throws -> (details: CGFloat, setName: CGFloat) {
        let medium = try #require(app.medium(with: mediumID))
        let menu = PixelProbe.open(
            objectContextMenuForTesting([.fromMedium(medium)])
                .environment(app)
                .environment(\.colorScheme, .light),
            size: CGSize(width: 304, height: 460)
        )
        defer { menu.close() }
        await PixelProbe.settleOpenWindow(menu)
        let bitmap = menu.bitmap()
        // Erste Gruppe: „Inhalt anzeigen“, „Details“, „Benennen“ (auch ausgegraut sichtbar), dann die Trennlinie.
        let bands = inkBands(bitmap, x: 44...60, y: 34...300, limit: 0.85)
        let details = try #require(bands.count > 2 ? bands[1] : nil, "Menü-Bänder \(bands)")
        let entry = try #require(bands.count > 2 ? bands[2] : nil, "Menü-Bänder \(bands)")
        func darkest(_ band: ClosedRange<CGFloat>) -> CGFloat {
            var value: CGFloat = 1
            var y = band.lowerBound
            while y <= band.upperBound {
                for x in stride(from: CGFloat(44), through: 60, by: 1) {
                    let sample = PixelProbe.color(in: bitmap, at: CGPoint(x: x, y: y))
                    value = min(value, sample.redComponent, sample.greenComponent, sample.blueComponent)
                }
                y += 1
            }
            return value
        }
        let shades = (darkest(details), darkest(entry))
        menu.clickThroughHitTest(at: CGPoint(x: 120, y: (entry.lowerBound + entry.upperBound) / 2), settle: 0.1)
        return shades
    }

    /// Textfeld mit Fokus (Feldeditor ist erster Antwortgeber) im Fenster.
    private static func editing(_ window: NSWindow) -> (field: NSTextField, editor: NSTextView)? {
        guard let editor = window.firstResponder as? NSTextView, let field = editor.delegate as? NSTextField else { return nil }
        return (field, editor)
    }

    private static func editableFields(_ window: NSWindow) -> [NSTextField] {
        ColumnAutoScrollTestSupport.allViews(of: NSTextField.self, in: window.contentView).filter(\.isEditable)
    }

    private static func key(_ window: NSWindow, _ characters: String, code: UInt16, modifiers: NSEvent.ModifierFlags = []) {
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            guard let event = NSEvent.keyEvent(
                with: type,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                characters: characters,
                charactersIgnoringModifiers: characters,
                isARepeat: false,
                keyCode: code
            ) else { continue }
            window.sendEvent(event)
        }
        let deadline = Date().addingTimeInterval(0.05)
        while Date() < deadline {
            CFRunLoopRunInMode(.defaultMode, 0.01, true)
        }
    }

    /// Echte Tastendrücke, je Zeichen ein `keyDown`.
    private static func type(_ text: String, _ window: NSWindow) {
        for character in text {
            key(window, String(character), code: 0)
        }
    }

    private static func enter(_ window: NSWindow) { key(window, "\r", code: 36) }
    private static func escape(_ window: NSWindow) { key(window, "\u{1b}", code: 53) }
    private static func backspace(_ window: NSWindow) { key(window, "\u{7f}", code: 51) }

    // MARK: Tests

    // 1. Menüeintrag (an Kachel, Seitenleiste, Tabelle und Suche dasselbe Menü am Medium): Details-Fenster offen, im
    // Benennungsmodus; das Hauptfenster kommt nach vorn (außerhalb des Bildschirms).
    @Test func menuEntryOpensTheDetailsInNamingMode() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = await Self.app(rig.store)
        defer { app.prepareForTermination() }

        try await Self.chooseSetName(app, mediumID: rig.mediumID)
        #expect(app.detailMediumID == rig.mediumID, "Details-Fenster nicht geöffnet")
        #expect(app.namingMediumID == rig.mediumID, "nicht im Benennungsmodus")
        if let main = NSApp.windows.first(where: { $0.title == LayoutCopy.diskArchive && $0.styleMask.contains(.titled) && $0.isVisible }) {
            #expect(main.frame.minX < -1000, "Hauptfenster nicht außerhalb des Bildschirms")
            main.close()
        }
    }

    // 2. Fokus im Namensfeld, Text ganz markiert; Tippen + Enter speichert, der Originalname bleibt.
    @Test func enterSavesTheName() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = await Self.app(rig.store)
        defer { app.prepareForTermination() }
        app.beginNaming(mediumID: rig.mediumID)
        let details = await Self.openDetails(app, rig.mediumID)
        defer { details.close() }
        try #require(await waitUntil { Self.editing(details.window) != nil }, "kein Feld mit Fokus")
        let opened = try #require(Self.editing(details.window))
        #expect(opened.field.stringValue == "Studio Backup", "Startwert \(opened.field.stringValue)")
        #expect(opened.editor.selectedRange() == NSRange(location: 0, length: 13), "nicht ganz markiert: \(opened.editor.selectedRange())")

        Self.type("Laura", details.window)
        Self.enter(details.window)
        try #require(await waitUntil { app.namingMediumID == nil && Self.editableFields(details.window).isEmpty }, "Enter beendet nicht")
        #expect(app.medium(with: rig.mediumID)?.shownName == "Laura")
        #expect(app.medium(with: rig.mediumID)?.name == "Studio Backup")
        #expect(await waitUntil { (try? await Self.storedCustomName(rig.store, rig.mediumID)) == "Laura" }, "nicht gespeichert")
    }

    // 3. Esc nach dem Tippen: alter Name, kein Schlüssel, Modus beendet, das Fenster bleibt offen.
    @Test func escapeCancels() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = await Self.app(rig.store)
        defer { app.prepareForTermination() }
        app.beginNaming(mediumID: rig.mediumID)
        let details = await Self.openDetails(app, rig.mediumID)
        defer { details.close() }
        try #require(await waitUntil { Self.editing(details.window) != nil }, "kein Feld mit Fokus")
        Self.type("x", details.window)
        Self.escape(details.window)
        try #require(await waitUntil { app.namingMediumID == nil && Self.editableFields(details.window).isEmpty }, "Esc beendet nicht")
        #expect(app.detailMediumID == rig.mediumID, "Esc schließt das Details-Fenster")
        #expect(app.medium(with: rig.mediumID)?.customName == nil, "Esc hat gespeichert")
        #expect(try await Self.storedCustomName(rig.store, rig.mediumID) == nil, "Schlüssel geschrieben")
    }

    // 4. Mit eigenem Namen: Feld leeren + Enter → Originalname, Schlüssel weg.
    @Test func emptyingTheFieldRestoresTheOriginalName() async throws {
        let rig = try await Self.makeRig(customName: "Laura")
        defer { rig.close() }
        let app = await Self.app(rig.store)
        defer { app.prepareForTermination() }
        app.beginNaming(mediumID: rig.mediumID)
        let details = await Self.openDetails(app, rig.mediumID)
        defer { details.close() }
        try #require(await waitUntil { Self.editing(details.window) != nil }, "kein Feld mit Fokus")
        let opened = try #require(Self.editing(details.window))
        #expect(opened.field.stringValue == "Laura")
        #expect(opened.editor.selectedRange() == NSRange(location: 0, length: 5), "nicht ganz markiert")
        Self.backspace(details.window)
        Self.enter(details.window)
        try #require(await waitUntil { app.namingMediumID == nil }, "Enter beendet nicht")
        #expect(app.medium(with: rig.mediumID)?.customName == nil)
        #expect(app.medium(with: rig.mediumID)?.shownName == "Studio Backup")
        #expect(await waitUntil { (try? await Self.storedCustomName(rig.store, rig.mediumID)) == .some(nil) }, "Schlüssel nicht entfernt")
    }

    // 5. Ohne Benennungsmodus kein Feld; die Kachel und die Seitenleiste haben keine Bearbeitung mehr.
    @Test func noFieldOutsideTheNamingMode() async throws {
        let rig = try await Self.makeRig(customName: "Laura")
        defer { rig.close() }
        let app = await Self.app(rig.store)
        defer { app.prepareForTermination() }
        let details = await Self.openDetails(app, rig.mediumID)
        defer { details.close() }
        #expect(Self.editableFields(details.window).isEmpty, "Feld ohne Benennungsmodus")
        let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("DiskArchive", isDirectory: true)
        for file in ["Views/Dashboard/MediumDashboardCard.swift", "Views/ColumnBrowser/ColumnBrowserRow.swift"] {
            let text = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
            #expect(!text.contains("TextField") && !text.contains("NameEditor"), "\(file) bearbeitet noch an Ort und Stelle")
        }
    }

    // 6. Schreibsperre: „Benennen“ ausgegraut, ein Klick tut nichts.
    @Test func writeLockGraysTheEntry() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = await Self.app(rig.store)
        defer { app.prepareForTermination() }
        app.versionLockState = .locked(.betaExpired)
        #expect(!app.featureAccess.canWriteIndex)

        let shades = try await Self.chooseSetName(app, mediumID: rig.mediumID)
        #expect(shades.setName > shades.details + 0.2, "nicht ausgegraut: Details \(shades.details), Benennen \(shades.setName)")
        #expect(app.namingMediumID == nil && app.detailMediumID == nil, "gesperrter Eintrag hat etwas ausgelöst")
    }
}
}
