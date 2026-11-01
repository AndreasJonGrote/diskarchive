//
//  ColumnFilterLiveTests.swift
//  DiskArchiveTests
//
//  todo.0.4.2.003 (Gegenprobe 7): Kettentest – echter Ordner auf einem Testvolume, FSEvents, Store, Treffermenge,
//  Spaltenansicht. Eine neue `bild.jpg` in `F/leer/` macht `F` und `leer` bei aktivem Filter normal, ohne Wartescreen.
//  Der Test löst nur das Schreiben der Datei aus.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite(.serialized) @MainActor
struct ColumnFilterLiveTests {
    @Test func newImageMakesItsFoldersNormalWithoutWaitScreen() async throws {
        let volume = try MountedTestVolume.make()
        defer { volume.detach() }
        let root = URL(fileURLWithPath: volume.mountPath, isDirectory: true)
        let leer = root.appendingPathComponent("F/leer", isDirectory: true)
        try FileManager.default.createDirectory(at: leer, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("A"), withIntermediateDirectories: true)
        try Data("bild".utf8).write(to: root.appendingPathComponent("A/bild.jpg"))

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
        try #require(await waitUntil { (try? await rig.store.medium(uuid: mediumID))?.indexStatus == .indexed }, "nicht indiziert")
        try #require(await waitUntil { rig.watcher.isWatching(mediumID: mediumID) }, "keine Überwachung")
        // Anlaufzeit des echten FSEvents-Stroms (wie LiveWatchSubfolderTests).
        try await Task.sleep(for: .seconds(2))

        let app = rig.app
        app.mainWindowDestination = .columnBrowser
        app.columnBrowserState.selectedMediumID = mediumID
        app.columnBrowserState.pathStack = ["F"]
        let size = CGSize(width: 1100, height: 600)
        let session = PixelProbe.open(
            ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
            size: size
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        app.searchState.filters.fileTypes = [.image]
        let key = try #require(ColumnFilterKey(mediumID: mediumID, filters: app.searchState.filters))
        try #require(await waitUntil { app.columnFilterFolderHits(for: key) != nil }, "Treffermenge fehlt")
        _ = await app.indexRepository.loadChildren(mediumID: mediumID, path: ["F"])
        let folderF = try #require(app.indexRepository.children(mediumID: mediumID, path: []).first { $0.name == "F" })
        let folderLeer = try #require(app.indexRepository.children(mediumID: mediumID, path: ["F"]).first { $0.name == "leer" })
        let hits = app.columnFilterFolderHits(for: key)
        #expect(ColumnBrowserFiltering.isQuiet(folderF, hits: hits) && ColumnBrowserFiltering.isQuiet(folderLeer, hits: hits), "Voraussetzung: F und leer leise")

        try Data("neu".utf8).write(to: leer.appendingPathComponent("bild.jpg"))
        var sawWait = false
        let normal = await waitUntil(timeout: 20) {
            sawWait = sawWait || app.columnFilterWaitVisible
            let now = app.columnFilterFolderHits(for: key)
            return !ColumnBrowserFiltering.isQuiet(folderF, hits: now) && !ColumnBrowserFiltering.isQuiet(folderLeer, hits: now)
                && now != nil
        }
        #expect(normal, "F und leer nach neuer Datei noch leise")
        #expect(!sawWait, "Wartescreen bei Live-Änderung")
        app.prepareForTermination()
    }
}
}
