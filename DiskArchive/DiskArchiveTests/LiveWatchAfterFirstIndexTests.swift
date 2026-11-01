//
//  LiveWatchAfterFirstIndexTests.swift
//  DiskArchiveTests
//
//  Aufgabe 174 c — echte FSEvents nach dem ersten Indexlauf.
//

import Foundation
import Testing
@testable import DiskArchive

extension WindowTestGroup {
@Suite @MainActor
struct LiveWatchAfterFirstIndexTests {
    @Test func changesAppearAfterFirstIndexRun() async throws {
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
        #expect(try await rig.store.storedNames().contains("seed.txt"))
        // bug.0.3.8.007: erst auf das Beobachten warten; die 2 s danach bleiben als Anlaufzeit des echten
        // FSEvents-Stroms (öffnet erst im Watch-Task, ein Umbenennen davor ginge verloren).
        let watching = await waitUntil { rig.watcher.isWatching(mediumID: mediumID) }
        #expect(watching)
        try await Task.sleep(for: .seconds(2))
        let seedURL = rootURL.appendingPathComponent("seed.txt")
        let renamedURL = rootURL.appendingPathComponent("renamed.txt")
        try FileManager.default.moveItem(at: seedURL, to: renamedURL)

        let renamedInStore = await waitUntil(timeout: 30) {
            guard (try? await rig.store.item(mediumUUID: mediumID, path: [], name: "renamed.txt")) != nil else {
                return false
            }
            return (try? await rig.store.item(mediumUUID: mediumID, path: [], name: "seed.txt")) == nil
        }
        #expect(renamedInStore)

        // Regel 18: offene Spaltenansicht lädt selbst; der Test liest nur den Zwischenspeicher.
        let session = openColumnWindow(app: rig.app, mediumID: mediumID)
        defer { session.close() }
        let columnShowsRename = await waitUntil(timeout: 30) {
            let names = rig.app.indexRepository.children(mediumID: mediumID, path: []).map(\.name)
            return names.contains("renamed.txt") && !names.contains("seed.txt")
        }
        #expect(columnShowsRename)

        try FileManager.default.createDirectory(at: rootURL.appendingPathComponent("Neu"), withIntermediateDirectories: true)
        let neuVisible = await waitUntil {
            (try? await rig.store.item(mediumUUID: mediumID, path: [], name: "Neu"))?.isFolder == true
        }
        #expect(neuVisible)

        let bulkURL = rootURL.appendingPathComponent("Bulk", isDirectory: true)
        try FileManager.default.createDirectory(at: bulkURL, withIntermediateDirectories: true)
        for index in 0..<2_000 {
            let file = bulkURL.appendingPathComponent("f-\(index).txt")
            try Data("x".utf8).write(to: file)
        }

        let bulkOK = await waitUntil(timeout: 30) {
            guard let folder = try? await rig.store.item(mediumUUID: mediumID, path: [], name: "Bulk"),
                  folder.isFolder else { return false }
            guard let stored = try? await rig.store.medium(uuid: mediumID) else { return false }
            return stored.fileCount >= 2_001
        }
        #expect(bulkOK)
    }
}
}

@MainActor
struct LiveWatchRig {
    let store: IndexStoreV3
    let app: AppState
    let coordinator: MediumCoordinator
    let service: IndexingService
    let watcher: ChangeWatcher
    let volume: VolumeInfo

    static func make(mountPath: String, volumeName: String) async throws -> LiveWatchRig {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-live-db-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let access = DirectMediumAccess(mountCheck: { _, _ in true })
        let app = AppState(store: store)
        let service = IndexingService(store: store, access: access, appState: app)
        let coordinator = MediumCoordinator(store: store, access: access, appState: app)
        let watcher = ChangeWatcher(store: store, access: access, appState: app)
        LiveWiring.connect(
            coordinator: coordinator,
            service: service,
            watcher: watcher,
            appState: app,
            startWatching: { id, volume in
                await LiveWiring.startWatching(
                    id: id,
                    volume: volume,
                    store: store,
                    watcher: watcher,
                    appState: app
                )
            }
        )
        let volume = VolumeInfo(
            mountPath: mountPath,
            name: volumeName,
            fsType: "hfs",
            volumeTotalBytes: 80_000_000,
            volumeFreeBytes: 40_000_000,
            diskSizeBytes: 80_000_000,
            volumeUUID: nil,
            createdAt: Date(),
            isRemovable: true,
            isEjectable: true,
            isInternal: false,
            isLocal: true,
            deviceProtocol: "USB",
            model: "Test",
            isTimeMachineSnapshot: false
        )
        return LiveWatchRig(
            store: store,
            app: app,
            coordinator: coordinator,
            service: service,
            watcher: watcher,
            volume: volume
        )
    }
}

struct MountedTestVolume {
    let mountPath: String
    let volumeName: String
    let scratchURL: URL
    let imageURL: URL

    static func make() throws -> MountedTestVolume {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-vol-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let name = "DIL\(UUID().uuidString.prefix(6))"
        let image = scratch.appendingPathComponent("live.dmg")
        _ = try runShell("hdiutil create -size 120m -fs HFS+ -volname '\(name)' '\(image.path)' -quiet")
        let attachOut = try runShell("hdiutil attach '\(image.path)' -nobrowse -noverify -noautoopen")
        guard let mount = attachOut.split(separator: "\n").compactMap({ (line: Substring) -> String? in
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard let last = parts.last.map(String.init), last.hasPrefix("/Volumes/") else { return nil }
            return last
        }).first else {
            throw NSError(domain: "LiveWatch", code: 1, userInfo: [NSLocalizedDescriptionKey: "attach failed"])
        }
        return MountedTestVolume(
            mountPath: mount,
            volumeName: name,
            scratchURL: scratch,
            imageURL: image
        )
    }

    func detach() {
        _ = try? runShell("hdiutil detach '\(mountPath)' -quiet")
        try? FileManager.default.removeItem(at: scratchURL)
    }
}

func runShell(_ command: String) throws -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", command]
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let text = String(data: data, encoding: .utf8) ?? ""
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "LiveWatch", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: text])
    }
    return text
}

extension IndexStoreV3 {
    func item(mediumUUID: UUID, path: [String], name: String) async throws -> StoredItem? {
        let parentID: Int64?
        if path.isEmpty {
            parentID = nil
        } else {
            parentID = try await folderID(mediumUUID: mediumUUID, path: path)
        }
        return try await children(mediumUUID: mediumUUID, parentID: parentID).first { $0.name == name }
    }
}
