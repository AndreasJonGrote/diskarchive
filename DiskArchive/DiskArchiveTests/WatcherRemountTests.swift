//
//  WatcherRemountTests.swift
//  DiskArchiveTests
//
//  Aufgabe 178 d — Überwachung nach Einhängen ohne disappeared.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite @MainActor
struct WatcherRemountTests {
    @Test func renameAfterRemountWithoutDisappeared() async throws {
        let volume = try MountedTestVolume.make()
        defer { volume.detach() }
        let rootURL = URL(fileURLWithPath: volume.mountPath, isDirectory: true)
        try Data("seed".utf8).write(to: rootURL.appendingPathComponent("seed.txt"))

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
        let watchingBefore = await waitUntil(timeout: 60) { rig.watcher.isWatching(mediumID: mediumID) }
        #expect(watchingBefore)
        let generationBefore = rig.watcher.watchGenerationForTesting(mediumID)

        _ = try runShell("hdiutil detach '\(volume.mountPath)' -quiet")
        _ = try runShell(
            "hdiutil attach '\(volume.imageURL.path)' -nobrowse -noverify -noautoopen -mountpoint '\(volume.mountPath)'"
        )

        await rig.coordinator.handle(.appeared(rig.volume))
        // bug.0.4.188: `connectKnown` stoppt die alte Überwachung erst in einem eigenen Task und startet die neue nach dem
        // Abgleich. Ein „überwacht“ vor dem Neustart ist das alte Abbild; erst nach Stopp (+1) und Start (+1) zählt es.
        let watchingAgain = await waitUntil(timeout: 60) {
            rig.watcher.isWatching(mediumID: mediumID)
                && rig.watcher.watchGenerationForTesting(mediumID) >= generationBefore + 2
        }
        // bug.0.4.194 (b): Der Lauf nach dem Wiedereinhängen endete nicht „nicht bestätigt“.
        #expect(rig.app.indexingFailure == nil, "Hinweis nach dem Wiedereinhängen: \(String(describing: rig.app.indexingFailure))")
        let stored = try await rig.store.medium(uuid: mediumID)
        #expect(
            watchingAgain,
            "Hinweis=\(String(describing: rig.app.indexingFailure?.reason)) Status=\(String(describing: stored?.indexStatus))"
        )

        rig.app.mainWindowDestination = .columnBrowser
        rig.app.columnBrowserState.selectedMediumID = mediumID
        let size = CGSize(width: 1280, height: 800)
        let session = PixelProbe.open(
            ColumnBrowserView()
                .environment(rig.app)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height),
            size: size,
            appearance: .aqua
        )
        defer { session.close() }
        await PixelProbe.settleOpenWindow(session)
        _ = await rig.app.indexRepository.loadChildren(mediumID: mediumID, path: [])

        let seedURL = rootURL.appendingPathComponent("seed.txt")
        let renamedURL = rootURL.appendingPathComponent("remounted.txt")
        try FileManager.default.moveItem(at: seedURL, to: renamedURL)

        let columnShowsRemount = await waitUntil(timeout: 60) {
            rig.app.indexRepository.children(mediumID: mediumID, path: []).map(\.name).contains("remounted.txt")
        }
        #expect(columnShowsRemount)
    }

    @Test func wakeRestartLogsCount() async throws {
        let volume = try MountedTestVolume.make()
        defer { volume.detach() }
        let rootURL = URL(fileURLWithPath: volume.mountPath, isDirectory: true)
        try Data("a".utf8).write(to: rootURL.appendingPathComponent("a.txt"))

        let rig = try await LiveWatchRig.make(mountPath: volume.mountPath, volumeName: volume.volumeName)
        rig.app.startChangeLoop()
        await rig.coordinator.handle(.appeared(rig.volume))
        await rig.app.loadStoredMedia()
        let mediumID = try #require(rig.app.newMediumDialogMediumID)
        rig.app.onNewMediumChoice?(mediumID, true, true)
        await rig.coordinator.waitForChoice()
        await rig.service.waitUntilIdle(mediumID)
        // bug.0.3.8.007: auf das Beobachten warten statt fester 2 s (hier folgt keine Dateiänderung).
        let watching = await waitUntil { rig.watcher.isWatching(mediumID: mediumID) }
        #expect(watching)
        #expect(rig.coordinator.connectedVolumes().contains { $0.id == mediumID })

        await LiveWiring.restartWatchersAfterWake(
            coordinator: rig.coordinator,
            watcher: rig.watcher,
            store: rig.store,
            appState: rig.app
        )
        #expect(rig.watcher.isWatching(mediumID: mediumID))

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification,
            object: NSWorkspace.shared
        )
    }
}
}
