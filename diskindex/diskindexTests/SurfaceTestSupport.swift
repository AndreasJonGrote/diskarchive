//
//  SurfaceTestSupport.swift
//  diskindexTests
//
//  Gemeinsame Fixtures aus dem früheren SurfaceTests.swift (Aufgabe 111).
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import diskindex

@MainActor
struct SurfaceRig {
    let database: IndexDatabase
    let store: IndexStore
    let app: AppState
    let coordinator: MediumCoordinator

    static func make() async throws -> SurfaceRig {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("diskindex-surface-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try IndexDatabase(fileURL: directory.appendingPathComponent("index.sqlite"))
        let store = IndexStore(database: database)
        let app = AppState()
        let coordinator = MediumCoordinator(store: store, access: GrantedAccess(), appState: app)
        return SurfaceRig(database: database, store: store, app: app, coordinator: coordinator)
    }

    func volume(name: String, path: String = "/Volumes/DISK", uuid: String?) -> VolumeInfo {
        VolumeInfo(
            mountPath: path,
            name: name,
            fsType: "apfs",
            volumeTotalBytes: 10,
            volumeFreeBytes: 4,
            diskSizeBytes: nil,
            volumeUUID: uuid,
            createdAt: nil,
            isRemovable: true,
            isEjectable: true,
            isInternal: false,
            isLocal: true,
            deviceProtocol: nil,
            model: nil,
            isTimeMachineSnapshot: false
        )
    }
}

@MainActor
struct TreeRig {
    let database: IndexDatabase
    let store: IndexStore
    let app: AppState
    let medium: StoredMedium
}

@MainActor
func seededTree() async throws -> TreeRig {
    let rig = try await SurfaceRig.make()
    var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Baum", decision: .index, indexStatus: .indexed, completedDepth: 3)
    try await rig.store.upsertMedium(medium)
    medium = try #require(try await rig.store.medium(uuid: medium.uuid))
    try await rig.store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: nil,
        entries: [
            ScannedEntry(name: "Beta", isFolder: true),
            ScannedEntry(name: "Alpha", isFolder: true),
            ScannedEntry(name: "readme.txt", isFolder: false, sizeBytes: 4, modifiedAt: Date()),
        ],
        seenAt: Date()
    )
    let root = try await rig.store.children(mediumUUID: medium.uuid, parentID: nil)
    let alpha = try #require(root.first { $0.name == "Alpha" })
    try await rig.store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: alpha.id,
        entries: [
            ScannedEntry(name: "a.txt", isFolder: false, sizeBytes: 1, modifiedAt: Date()),
            ScannedEntry(name: "Inner", isFolder: true),
        ],
        seenAt: Date()
    )
    let alphaChildren = try await rig.store.children(mediumUUID: medium.uuid, parentID: alpha.id)
    let inner = try #require(alphaChildren.first { $0.name == "Inner" })
    try await rig.store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: inner.id,
        entries: [ScannedEntry(name: "deep.txt", isFolder: false, sizeBytes: 1, modifiedAt: Date())],
        seenAt: Date()
    )
    rig.app.attach(store: rig.store)
    await rig.app.loadStoredMedia()
    return TreeRig(database: rig.database, store: rig.store, app: rig.app, medium: medium)
}

@MainActor
func searchFixture() async throws -> TreeRig {
    let rig = try await SurfaceRig.make()
    var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "Suche", type: .ssd, decision: .index, indexStatus: .indexed, completedDepth: 3)
    try await rig.store.upsertMedium(medium)
    medium = try #require(try await rig.store.medium(uuid: medium.uuid))
    let recent = Date()
    let old = Date(timeIntervalSince1970: 1_000_000_000)
    try await rig.store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: nil,
        entries: [
            ScannedEntry(name: "Rechnung.pdf", isFolder: false, sizeBytes: 10, modifiedAt: recent),
            ScannedEntry(name: "weg.pdf", isFolder: false, sizeBytes: 10, modifiedAt: recent),
            ScannedEntry(name: "alt.pdf", isFolder: false, sizeBytes: 10, modifiedAt: old),
            ScannedEntry(name: "foto.jpg", isFolder: false, sizeBytes: 10, modifiedAt: recent),
            ScannedEntry(name: "Ordner", isFolder: true),
        ],
        seenAt: Date()
    )
    try await rig.store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: nil,
        entries: [
            ScannedEntry(name: "Rechnung.pdf", isFolder: false, sizeBytes: 10, modifiedAt: recent),
            ScannedEntry(name: "alt.pdf", isFolder: false, sizeBytes: 10, modifiedAt: old),
            ScannedEntry(name: "foto.jpg", isFolder: false, sizeBytes: 10, modifiedAt: recent),
            ScannedEntry(name: "Ordner", isFolder: true),
        ],
        seenAt: Date()
    )
    let root = try await rig.store.children(mediumUUID: medium.uuid, parentID: nil)
    let folder = try #require(root.first { $0.name == "Ordner" })
    try await rig.store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: folder.id,
        entries: [ScannedEntry(name: "B", isFolder: true)],
        seenAt: Date()
    )
    let level2 = try await rig.store.children(mediumUUID: medium.uuid, parentID: folder.id)
    let nested = try #require(level2.first)
    try await rig.store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: nested.id,
        entries: [ScannedEntry(name: "deep.txt", isFolder: false, sizeBytes: 1, modifiedAt: recent)],
        seenAt: Date()
    )
    rig.app.attach(store: rig.store)
    await rig.app.loadStoredMedia()
    return TreeRig(database: rig.database, store: rig.store, app: rig.app, medium: medium)
}

@MainActor
func ids(store: IndexStore, query: String, filters: SearchFilters, maxDepth: Int?) async throws -> Set<Int64> {
    let rows = try await store.search(query: query, filters: filters, limit: 500, maxDepth: maxDepth)
    return Set(rows.map(\.id))
}

@MainActor
func swiftIDs(store: IndexStore, medium: UUID, query: String, filters: SearchFilters, maxDepth: Int?) async throws -> Set<Int64> {
    var rows: [StoredItem] = []
    func walk(_ parent: Int64?) async throws {
        for child in try await store.children(mediumUUID: medium, parentID: parent) {
            rows.append(child)
            if child.isFolder { try await walk(child.id) }
        }
    }
    try await walk(nil)
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return Set(rows.compactMap { row in
        if let maxDepth, row.depth > maxDepth { return nil }
        let item = IndexedItem(stored: row)
        let nameOK = trimmed.isEmpty || item.name.localizedCaseInsensitiveContains(trimmed)
        guard nameOK, SearchItemFilter.matches(item, filters: filters, hasSearchTerm: !trimmed.isEmpty) else { return nil }
        return row.id
    })
}

@MainActor
struct WatchRig {
    let database: IndexDatabase
    let store: IndexStore
    let app: AppState
    let medium: StoredMedium
    let access: MapAccess
    let source: ScriptedChangeSource
    let watcher: ChangeWatcher
    let volume: VolumeInfo
}

@MainActor
func watchRig() async throws -> WatchRig {
    let rig = try await SurfaceRig.make()
    var medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 10, name: "DISK", decision: .index, indexStatus: .indexed, completedDepth: 3)
    try await rig.store.upsertMedium(medium)
    medium = try #require(try await rig.store.medium(uuid: medium.uuid))
    try await rig.store.applyDirectory(
        mediumUUID: medium.uuid,
        parentID: nil,
        entries: [
            ScannedEntry(name: "A", isFolder: true),
            ScannedEntry(name: "B", isFolder: true),
        ],
        seenAt: Date()
    )
    let access = MapAccess()
    let source = ScriptedChangeSource()
    let watcher = ChangeWatcher(store: rig.store, access: access, appState: rig.app)
    let volume = VolumeInfo(
        mountPath: "/Volumes/DISK",
        name: "DISK",
        fsType: "apfs",
        volumeTotalBytes: 10,
        volumeFreeBytes: 1,
        diskSizeBytes: nil,
        volumeUUID: nil,
        createdAt: nil,
        isRemovable: true,
        isEjectable: true,
        isInternal: false,
        isLocal: true,
        deviceProtocol: nil,
        model: nil,
        isTimeMachineSnapshot: false
    )
    return WatchRig(database: rig.database, store: rig.store, app: rig.app, medium: medium, access: access, source: source, watcher: watcher, volume: volume)
}

final class MapAccess: MediumAccess, @unchecked Sendable {
    var listings: [String: [ListedDirectoryEntry]] = [:]
    var listCount: [String: Int] = [:]
    var failing: Set<String> = []
    private let lock = NSLock()

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        let path = url.standardizedFileURL.path
        if failing.contains(path) || failing.contains(url.path) {
            _ = record(path)
            throw CocoaError(.fileReadNoPermission)
        }
        return record(path)
    }

    func record(_ path: String) -> [ListedDirectoryEntry] {
        lock.lock()
        defer { lock.unlock() }
        listCount[path, default: 0] += 1
        return listings[path] ?? []
    }
}

final class ReconcileLog: @unchecked Sendable {
    var ids: [UUID] = []
}

final class BlockingListAccess: MediumAccess, @unchecked Sendable {
    let entered = SurfaceAsyncSignal()
    let release = SurfaceAsyncSignal()
    private let lock = NSLock()
    private var lists = 0

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        if consumeFirst() {
            await entered.signal()
            await release.wait()
        }
        return []
    }

    func consumeFirst() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        lists += 1
        return lists == 1
    }
}

actor SurfaceAsyncSignal {
    private var open = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func signal() {
        open = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }

    func wait() async {
        if open { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

final class GrantedAccess: MediumAccess, @unchecked Sendable {
    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }
    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] { [] }
}

func swiftFiles(in root: URL) throws -> [URL] {
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
    return files.filter { $0.pathExtension == "swift" }
}

/// Wartet, bis `condition` wahr ist (statt fester Schlafzeit); `false` nach Ablauf von `timeout`.
@MainActor
func waitUntil(timeout: TimeInterval = 10, _ condition: () async throws -> Bool) async rethrows -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if try await condition() { return true }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return try await condition()
}
