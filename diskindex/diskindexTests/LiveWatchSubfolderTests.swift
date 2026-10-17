//
//  LiveWatchSubfolderTests.swift
//  diskindexTests
//
//  Aufgabe 182 a — Live-Unterordner ohne Test-Nachhilfe.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

extension WindowTestGroup {
@Suite @MainActor
struct LiveWatchSubfolderTests {
    @Test func subfolderColumnUpdatesFromLiveWatch() async throws {
        let volume = try MountedTestVolume.make()
        defer { volume.detach() }
        let rootURL = URL(fileURLWithPath: volume.mountPath, isDirectory: true)
        let folderB = rootURL.appendingPathComponent("A/B", isDirectory: true)
        try FileManager.default.createDirectory(at: folderB, withIntermediateDirectories: true)
        try Data("seed".utf8).write(to: folderB.appendingPathComponent("datei.txt"))
        try Data("gone".utf8).write(to: folderB.appendingPathComponent("weg.txt"))

        let rig = try await LiveWatchRig.make(mountPath: volume.mountPath, volumeName: volume.volumeName)
        rig.watcher.quietInterval = .seconds(1)
        rig.watcher.maxQuietInterval = .seconds(8)
        rig.app.startChangeLoop()

        await rig.coordinator.handle(.appeared(rig.volume))
        await rig.app.loadStoredMedia()
        let mediumID = try #require(rig.app.newMediumDialogMediumID)
        rig.app.onNewMediumChoice?(mediumID, true, true)
        await rig.coordinator.waitForChoice()
        await rig.service.waitUntilIdle(mediumID)
        let indexed = await waitUntil {
            (try? await rig.store.medium(uuid: mediumID))?.indexStatus == .indexed
        }
        #expect(indexed)
        // bug.0.3.8.007: erst auf das Beobachten warten; die 2 s danach bleiben als Anlaufzeit des echten
        // FSEvents-Stroms (öffnet erst im Watch-Task, ein Umbenennen davor ginge verloren).
        let watching = await waitUntil { rig.watcher.isWatching(mediumID: mediumID) }
        #expect(watching)
        try await Task.sleep(for: .seconds(2))

        let session = openColumnSession(rig: rig, mediumID: mediumID)
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        _ = await rig.app.indexRepository.loadChildren(mediumID: mediumID, path: ["A", "B"])

        let renamedURL = folderB.appendingPathComponent("umbenannt.txt")
        try FileManager.default.moveItem(at: folderB.appendingPathComponent("datei.txt"), to: renamedURL)
        let renamedInColumn = await waitUntil(timeout: 15) {
            let names = rig.app.indexRepository.children(mediumID: mediumID, path: ["A", "B"]).map(\.name)
            return names.contains("umbenannt.txt") && !names.contains("datei.txt")
        }
        #expect(renamedInColumn)
        #expect(columnBHasInk(session))

        try FileManager.default.createDirectory(at: folderB.appendingPathComponent("Neu"), withIntermediateDirectories: true)
        let neuInColumn = await waitUntil(timeout: 15) {
            rig.app.indexRepository.children(mediumID: mediumID, path: ["A", "B"]).map(\.name).contains("Neu")
        }
        #expect(neuInColumn)
        #expect(columnBHasInk(session))

        try FileManager.default.removeItem(at: folderB.appendingPathComponent("weg.txt"))
        let deletedInColumn = await waitUntil(timeout: 15) {
            !rig.app.indexRepository.children(mediumID: mediumID, path: ["A", "B"]).map(\.name).contains("weg.txt")
        }
        #expect(deletedInColumn)
        #expect(columnBHasInk(session))
    }

    private func openColumnSession(rig: LiveWatchRig, mediumID: UUID) -> PixelProbe.Session {
        rig.app.mainWindowDestination = .columnBrowser
        rig.app.columnBrowserState.selectedMediumID = mediumID
        rig.app.columnBrowserState.pathStack = ["A", "B"]
        let size = CGSize(width: 1280, height: 800)
        return PixelProbe.open(
            ColumnBrowserView()
                .environment(rig.app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
    }

    private func columnBHasInk(_ session: PixelProbe.Session) -> Bool {
        session.window.contentView?.layoutSubtreeIfNeeded()
        session.window.display()
        let bitmap = session.bitmap()
        let sidebar = DesignSpacing.columnBrowserSidebarWidth
        let width = DesignSpacing.columnBrowserColumnWidth
        let columnIndex = 2
        let x = sidebar + CGFloat(columnIndex) * width + 8
        let background = CGPoint(x: 1260, y: 12)
        return PixelProbe.inkBounds(
            in: bitmap,
            rect: CGRect(x: x, y: 30, width: width - 24, height: 50),
            background: background
        ) != nil
    }
}
}
