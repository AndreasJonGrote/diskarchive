//
//  MediumNamingTests.swift
//  DiskArchiveTests
//
//  todo.0.4.2.005 (Konzept `medien.md` 2d): „Benennen“ im Kontextmenü der Medien. Kachel und Seitenleiste bearbeiten
//  den Namen an Ort und Stelle, alle anderen Stellen öffnen das Details-Modal mit Fokus im Feld „Eigener Name“. Alles im
//  echten Fenster außerhalb des Bildschirms: Klick auf den Menüeintrag und Tasten per `window.sendEvent`, Beweis über
//  Pixel (Lage der Spezifikationszeile bzw. Höhe der Zeile) und den Schlüssel `customName` in `storage_meta`.
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

    /// Kachel, die dem Medium im Zustand folgt (wie im Dashboard).
    private struct CardHost: View {
        @Environment(AppState.self) private var app
        let mediumID: UUID

        var body: some View {
            if let medium = app.medium(with: mediumID) {
                MediumDashboardCard(medium: medium)
            }
        }
    }

    private static let cardSize = CGSize(width: 240, height: 220)

    private static func openCard(_ app: AppState, _ mediumID: UUID) async -> PixelProbe.Session {
        let session = PixelProbe.open(
            CardHost(mediumID: mediumID)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: cardSize.width)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: cardSize.width, height: cardSize.height, alignment: .top),
            size: cardSize
        )
        await PixelProbe.settleOpenWindow(session)
        return session
    }

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

    /// Oberkante der Spezifikationszeile. Von unten: Fläche unter der Kachel, Zeile mit Belegung und Zeit,
    /// Spezifikation (darüber Titel und evtl. Originalname, Icon und Chip).
    private static func specTop(_ session: PixelProbe.Session) throws -> CGFloat {
        let bands = inkBands(session.bitmap(), x: 16...224, y: 2...(cardSize.height - 2), limit: 0.75)
        print("todo.0.4.2.005 Kachel-Bänder \(bands)")
        let spec = try #require(bands.count >= 5 ? bands[bands.count - 3] : nil, "Bänder \(bands)")
        return spec.lowerBound
    }

    /// Kontextmenü für `target` öffnen (eigenes Fenster, wie das Panel) und auf „Benennen“ klicken.
    /// Liefert die dunkelste Farbe im Icon von „Details“ und „Benennen“ (Ausgrauen).
    @discardableResult
    private static func chooseSetName(
        _ app: AppState, mediumID: UUID, place: MediumNamingPlace?
    ) async throws -> (details: CGFloat, setName: CGFloat) {
        let medium = try #require(app.medium(with: mediumID))
        let menu = PixelProbe.open(
            objectContextMenuForTesting([.fromMedium(medium)], namingPlace: place)
                .environment(app)
                .environment(\.colorScheme, .light),
            size: CGSize(width: 304, height: 420)
        )
        defer { menu.close() }
        await PixelProbe.settleOpenWindow(menu)
        let bitmap = menu.bitmap()
        // Erste Gruppe: „Inhalt anzeigen“, „Details“, „Benennen“ (auch ausgegraut sichtbar), dann die Trennlinie.
        let bands = inkBands(bitmap, x: 44...60, y: 34...300, limit: 0.85)
        print("todo.0.4.2.005 Menü-Bänder \(bands)")
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

    private static func arrow(_ window: NSWindow, _ function: Int, code: UInt16) {
        let characters = String(UnicodeScalar(UInt16(function)).map(Character.init) ?? " ")
        key(window, characters, code: code, modifiers: [.numericPad, .function])
    }

    // MARK: Tests

    // 1. Kachel ohne eigenen Namen: Feld mit Originalname, markiert, keine zweite Zeile; ab dem ersten Zeichen die zweite
    // Zeile; „Laura“ + Enter speichert.
    @Test func cardNamesInPlaceAndShowsTheOriginalAfterTheFirstCharacter() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = await Self.app(rig.store)
        defer { app.prepareForTermination() }
        let card = await Self.openCard(app, rig.mediumID)
        defer { card.close() }
        let plain = try Self.specTop(card)

        try await Self.chooseSetName(app, mediumID: rig.mediumID, place: .dashboardCard)
        #expect(app.detailMediumID == nil, "Details-Modal statt Bearbeitung an Ort und Stelle")
        try #require(await waitUntil { Self.editing(card.window) != nil }, "kein Feld mit Fokus in der Kachel")
        let opened = try #require(Self.editing(card.window))
        #expect(opened.field.stringValue == "Studio Backup", "Startwert \(opened.field.stringValue)")
        #expect(opened.editor.selectedRange() == NSRange(location: 0, length: 13), "nicht ganz markiert: \(opened.editor.selectedRange())")
        await PixelProbe.settleOpenWindow(card)
        let editingTop = try Self.specTop(card)
        #expect(abs(editingTop - plain) <= 0.5, "Kachel springt beim Öffnen des Felds: \(plain) → \(editingTop)")

        Self.type("L", card.window)
        await PixelProbe.settleOpenWindow(card)
        let typed = try Self.specTop(card)
        #expect(typed >= plain + 10, "zweite Zeile fehlt nach dem ersten Zeichen: \(plain) → \(typed)")

        Self.type("aura", card.window)
        Self.enter(card.window)
        try #require(await waitUntil { app.mediumNaming == nil && Self.editableFields(card.window).isEmpty }, "Enter beendet nicht")
        #expect(app.medium(with: rig.mediumID)?.shownName == "Laura")
        #expect(app.medium(with: rig.mediumID)?.name == "Studio Backup")
        #expect(await waitUntil { (try? await Self.storedCustomName(rig.store, rig.mediumID)) == "Laura" }, "nicht gespeichert")
        await PixelProbe.settleOpenWindow(card)
        let saved = try Self.specTop(card)
        #expect(saved >= plain + 10, "Originalname unter „Laura“ fehlt: \(plain) → \(saved)")
    }

    // 2. Escape nach dem Tippen: alter Name, kein Schlüssel. Während der Bearbeitung öffnet ein Klick die Kachel nicht.
    // Der Klick geht auf die Kachelfläche (Tap-Geste, per Hit-Test): Ein Klick ins Textfeld startet die Maus-Schleife
    // von AppKit, die auf die echte Ereigniswarteschlange wartet und im Test nie endet; den Monitor für „Klick daneben“
    // erreicht der Testklick nicht.
    @Test func escapeCancelsAndAClickOnTheCardDoesNotOpenIt() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = await Self.app(rig.store)
        defer { app.prepareForTermination() }
        let card = await Self.openCard(app, rig.mediumID)
        defer { card.close() }
        let plain = try Self.specTop(card)
        // Positivprobe: ohne Bearbeitung öffnet derselbe Klick die Kachel.
        card.clickThroughHitTest(at: CGPoint(x: 40, y: plain + 4), settle: 0.15)
        try #require(app.mainWindowDestination == .columnBrowser, "Klick erreicht die Kachel nicht")
        app.mainWindowDestination = .dashboard

        try await Self.chooseSetName(app, mediumID: rig.mediumID, place: .dashboardCard)
        try #require(await waitUntil { Self.editing(card.window) != nil }, "kein Feld mit Fokus in der Kachel")
        card.clickThroughHitTest(at: CGPoint(x: 40, y: plain + 4), settle: 0.15)
        #expect(app.mainWindowDestination == .dashboard, "Klick während der Bearbeitung öffnet die Kachel")
        #expect(app.mediumNaming != nil && Self.editing(card.window) != nil, "Bearbeitung durch den Klick beendet")

        Self.type("x", card.window)
        Self.escape(card.window)
        try #require(await waitUntil { app.mediumNaming == nil && Self.editableFields(card.window).isEmpty }, "Escape beendet nicht")
        #expect(app.medium(with: rig.mediumID)?.customName == nil, "Escape hat gespeichert")
        #expect(try await Self.storedCustomName(rig.store, rig.mediumID) == nil, "Schlüssel geschrieben")
        await PixelProbe.settleOpenWindow(card)
        #expect(abs(try Self.specTop(card) - plain) <= 0.5, "Kachel nach Escape nicht wie vorher")
    }

    // 3. Mit eigenem Namen: zweite Zeile steht schon; Feld leeren + Enter → Originalname, Schlüssel weg, einzeilig.
    @Test func emptyingTheFieldRestoresTheOriginalName() async throws {
        let rig = try await Self.makeRig(customName: "Laura")
        defer { rig.close() }
        let app = await Self.app(rig.store)
        defer { app.prepareForTermination() }
        let card = await Self.openCard(app, rig.mediumID)
        defer { card.close() }
        let named = try Self.specTop(card)

        try await Self.chooseSetName(app, mediumID: rig.mediumID, place: .dashboardCard)
        try #require(await waitUntil { Self.editing(card.window) != nil }, "kein Feld mit Fokus in der Kachel")
        let opened = try #require(Self.editing(card.window))
        #expect(opened.field.stringValue == "Laura")
        #expect(opened.editor.selectedRange() == NSRange(location: 0, length: 5), "nicht ganz markiert")
        await PixelProbe.settleOpenWindow(card)
        #expect(abs(try Self.specTop(card) - named) <= 0.5, "zweite Zeile beim Öffnen weg oder Sprung")

        Self.backspace(card.window)
        Self.enter(card.window)
        try #require(await waitUntil { app.mediumNaming == nil && Self.editableFields(card.window).isEmpty }, "Enter beendet nicht")
        #expect(app.medium(with: rig.mediumID)?.customName == nil)
        #expect(app.medium(with: rig.mediumID)?.shownName == "Studio Backup")
        #expect(await waitUntil { (try? await Self.storedCustomName(rig.store, rig.mediumID)) == .some(nil) }, "Schlüssel nicht entfernt")
        await PixelProbe.settleOpenWindow(card)
        let single = try Self.specTop(card)
        #expect(single <= named - 10, "Kachel nicht wieder einzeilig: \(named) → \(single)")
    }

    // 4. Seitenleiste: Feld in der Zeile, nach dem ersten Zeichen höher; Pfeiltasten bewegen den Cursor, nicht die
    // Auswahl; Enter → einzeilig mit neuem Namen.
    @Test func sidebarRowNamesInPlaceAndArrowsStayInTheField() async throws {
        var rig = try await ColumnFilterTreeRig.make([.folder("A", [.file("a.txt")])], name: "Baum")
        let otherID = try await rig.addMedium([.folder("B", [])], name: "Zweit")
        defer { rig.close() }
        let app = AppState(store: rig.store)
        await app.loadStoredMedia()
        defer { app.prepareForTermination() }
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = rig.mediumID
        let size = CGSize(width: 900, height: 420)
        let session = PixelProbe.open(
            MainWindowScreenScaffold { ColumnBrowserView() }
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height),
            size: size
        )
        defer { session.close() }
        try #require(await waitUntil { app.indexRepository.hasLoadedChildren(mediumID: rig.mediumID, path: []) }, "Wurzel nicht geladen")
        await PixelProbe.settleOpenWindow(session)
        let selectionBefore = app.columnBrowserState.selection

        // Höhe der gewählten Zeile: dunkle Auswahlfläche links neben dem Icon.
        func rowHeight() throws -> CGFloat {
            let bands = Self.inkBands(session.bitmap(), x: 8...9, y: 60...(size.height - 40), limit: 0.5)
            print("todo.0.4.2.005 Seitenleiste-Bänder \(bands)")
            let band = try #require(bands.first, "keine gewählte Zeile")
            return band.upperBound - band.lowerBound + 1
        }
        let single = try rowHeight()

        try await Self.chooseSetName(app, mediumID: rig.mediumID, place: .columnSidebar)
        try #require(await waitUntil { Self.editing(session.window) != nil }, "kein Feld mit Fokus in der Seitenleiste")
        let opened = try #require(Self.editing(session.window))
        #expect(opened.field.stringValue == "Baum")
        #expect(opened.editor.selectedRange() == NSRange(location: 0, length: 4), "nicht ganz markiert")
        #expect(opened.field.convert(opened.field.bounds, to: nil).minX < app.columnBrowserState.sidebarWidth, "Feld nicht in der Seitenleiste")
        await PixelProbe.settleOpenWindow(session)
        #expect(try rowHeight() <= single + 1, "Zeile vor dem ersten Zeichen schon höher")

        Self.type("Laura", session.window)
        await PixelProbe.settleOpenWindow(session)
        let tall = try rowHeight()
        #expect(tall >= single + 10, "Zeile mit Originalname nicht höher: \(single) → \(tall)")

        Self.arrow(session.window, NSLeftArrowFunctionKey, code: 123)
        Self.arrow(session.window, NSUpArrowFunctionKey, code: 126)
        Self.arrow(session.window, NSDownArrowFunctionKey, code: 125)
        Self.arrow(session.window, NSLeftArrowFunctionKey, code: 123)
        await PixelProbe.settleOpenWindow(session)
        #expect(app.columnBrowserState.selectedMediumID == rig.mediumID, "Pfeiltaste wechselt das Medium (zu \(String(describing: app.columnBrowserState.selectedMediumID)), anderes: \(otherID))")
        #expect(app.columnBrowserState.selection == selectionBefore, "Pfeiltaste ändert die Auswahl")
        let moved = try #require(Self.editing(session.window), "Feld verliert durch Pfeiltasten den Fokus")
        #expect(moved.field.stringValue == "Laura")
        #expect(moved.editor.selectedRange().location == 4, "Cursor nicht bewegt: \(moved.editor.selectedRange())")

        Self.enter(session.window)
        try #require(await waitUntil { app.mediumNaming == nil }, "Enter beendet nicht")
        #expect(app.medium(with: rig.mediumID)?.shownName == "Laura")
        #expect(await waitUntil { (try? await Self.storedCustomName(rig.store, rig.mediumID)) == "Laura" }, "nicht gespeichert")
        await PixelProbe.settleOpenWindow(session)
        let after = try rowHeight()
        #expect(abs(after - single) <= 0.5, "Zeile nach Enter nicht wieder einzeilig: \(single) → \(after)")
    }

    // 5. Andere Stellen (Suche, Einstellungen, Menüleiste – kein Ort): Details-Modal im Hauptfenster, Fokus im Feld
    // „Eigener Name“, Inhalt ganz markiert.
    @Test func otherPlacesOpenTheDetailsModalWithTheNameFieldFocused() async throws {
        let rig = try await Self.makeRig(customName: "Laura")
        defer { rig.close() }
        let app = await Self.app(rig.store)
        defer { app.prepareForTermination() }

        try await Self.chooseSetName(app, mediumID: rig.mediumID, place: nil)
        #expect(app.detailMediumID == rig.mediumID, "Details-Modal nicht geöffnet")
        let main = try #require(NSApp.windows.first { $0.title == LayoutCopy.diskArchive && $0.styleMask.contains(.titled) && $0.isVisible }, "Hauptfenster nicht geöffnet")
        defer { main.close() }
        #expect(main.frame.minX < -1000, "Hauptfenster nicht außerhalb des Bildschirms")
        try #require(await waitUntil { Self.editing(main) != nil && app.mediumNaming == nil }, "Feld „Eigener Name“ ohne Fokus")
        let opened = try #require(Self.editing(main))
        #expect(opened.field.stringValue == "Laura")
        #expect(opened.editor.selectedRange() == NSRange(location: 0, length: 5), "nicht ganz markiert: \(opened.editor.selectedRange())")
    }

    // 6. Schreibsperre: „Benennen“ ausgegraut, ein Klick tut nichts.
    @Test func writeLockGraysTheEntry() async throws {
        let rig = try await Self.makeRig()
        defer { rig.close() }
        let app = await Self.app(rig.store)
        defer { app.prepareForTermination() }
        app.versionLockState = .locked(.betaExpired)
        #expect(!app.featureAccess.canWriteIndex)

        let shades = try await Self.chooseSetName(app, mediumID: rig.mediumID, place: .dashboardCard)
        #expect(shades.setName > shades.details + 0.2, "nicht ausgegraut: Details \(shades.details), Benennen \(shades.setName)")
        #expect(app.mediumNaming == nil && app.detailMediumID == nil, "gesperrter Eintrag hat etwas ausgelöst")
    }
}
}
