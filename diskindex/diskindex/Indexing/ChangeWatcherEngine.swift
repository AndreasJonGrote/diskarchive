//
//  ChangeWatcherEngine.swift
//  diskindex
//
//  Schwerer Live-Abgleich abseits des Main Actors.
//

import Foundation

actor ChangeWatcherEngine {
    private let store: IndexStoreV3
    private let access: any MediumAccess

    init(store: IndexStoreV3, access: any MediumAccess) {
        self.store = store
        self.access = access
    }

    struct RenameFollowUp: Sendable {
        var fromParent: String?
        var toParent: String?
    }

    struct FlushPrep: Sendable {
        var directories: Set<String>
        var renamePairs: [LiveRenamePair]
        var renameFollowUps: [RenameFollowUp]
    }

    func prepareFlush(
        rawPaths: Set<String>,
        itemEvents: [ItemPathEvent],
        mount: String,
        matcher: IgnoreMatcher,
        maxDepth: Int?,
        fileExists: @Sendable (String) -> Bool
    ) -> FlushPrep {
        var ctx = LiveWatchScopeContext(mount: mount, matcher: matcher, maxDepth: maxDepth)
        var directories = Set<String>()
        for path in rawPaths {
            if let dir = LiveWatchScope.directoryToReread(path, ctx: &ctx) {
                directories.insert(dir)
            }
        }
        let scoped = itemEvents.filter { LiveWatchScope.eventInScope($0.path, ctx: &ctx) }
        let pairs = LiveRenamePairs.pair(events: scoped, fileExists: fileExists)
        for item in scoped {
            if let dir = LiveWatchScope.directoryToReread(item.path, ctx: &ctx) {
                directories.insert(dir)
            }
        }
        var renameFollowUps: [RenameFollowUp] = []
        renameFollowUps.reserveCapacity(pairs.count)
        for pair in pairs {
            renameFollowUps.append(RenameFollowUp(
                fromParent: LiveWatchScope.scopedParentDirectory(pair.fromPath, ctx: &ctx),
                toParent: LiveWatchScope.scopedParentDirectory(pair.toPath, ctx: &ctx)
            ))
        }
        return FlushPrep(directories: directories, renamePairs: pairs, renameFollowUps: renameFollowUps)
    }

    enum Outcome: Sendable {
        case ok
        case needsFullReconcile
        case deferred
    }

    func processPending(
        mediumID: UUID,
        mount: String,
        directories: [String],
        matcher: IgnoreMatcher,
        maxDepth: Int?,
        writeAllowed: @Sendable () async -> Bool = { true }
    ) async -> Outcome {
        if await store.hasActiveIndexingToken(mediumUUID: mediumID) {
            return .deferred
        }
        guard await writeAllowed() else { return .deferred }
        let eventPaths = Set(directories.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
        var queue = Array(eventPaths)
        var seen = Set<String>()
        var attempts: [String: Int] = [:]
        var index = 0
        while index < queue.count {
            guard await writeAllowed() else { return .deferred }
            let directory = queue[index]
            index += 1
            if seen.contains(directory) { continue }
            let relative = Self.relativeComponents(directory, mount: mount)
            let parentID: Int64?
            if relative.isEmpty {
                parentID = nil
            } else {
                var folderID: Int64?
                do {
                    folderID = try await store.folderID(mediumUUID: mediumID, path: relative)
                } catch {
                    if DiskIndexLog.isOperationalFailure(error) {
                        DiskIndexLog.shared.record(.store, .error, "store error folderID \(error)")
                    }
                    folderID = nil
                }
                if let id = folderID {
                    parentID = id
                } else {
                    if relative.count == 1 {
                        let rootDir = URL(fileURLWithPath: mount, isDirectory: true).standardizedFileURL.path
                        if !seen.contains(rootDir) {
                            queue.append(rootDir)
                        }
                        continue
                    }
                    var parentExists = false
                    if relative.count > 1 {
                        do {
                            parentExists = try await store.folderID(mediumUUID: mediumID, path: Array(relative.dropLast())) != nil
                        } catch {
                            if DiskIndexLog.isOperationalFailure(error) {
                                DiskIndexLog.shared.record(.store, .error, "store error folderID parent \(error)")
                            }
                            parentExists = false
                        }
                    }
                    if parentExists {
                        let parentDir = Self.directoryURL(mount: mount, components: Array(relative.dropLast())).path
                        if !seen.contains(parentDir) {
                            queue.append(parentDir)
                        }
                        continue
                    }
                    let attempt = attempts[directory, default: 0] + 1
                    attempts[directory] = attempt
                    if attempt <= 2 {
                        queue.append(directory)
                    } else {
                        DiskIndexLog.shared.record(.watcher, .error, "ohne Elternzeile", privateDetail: directory)
                        return .needsFullReconcile
                    }
                    continue
                }
            }
            let listed: [ListedDirectoryEntry]
            do {
                listed = try await access.listDirectory(at: URL(fileURLWithPath: directory, isDirectory: true))
            } catch {
                DiskIndexLog.shared.record(.watcher, .error, "nicht lesbar \(DiskIndexLog.errorSummary(error))", privateDetail: directory)
                seen.insert(directory)
                continue
            }
            seen.insert(directory)
            let entries = listed.compactMap { entry -> ScannedEntry? in
                if matcher.shouldSkip(name: entry.name, isHidden: entry.isHidden) { return nil }
                return Self.scanned(entry)
            }
            var liveChildren: [StoredItem] = []
            do {
                liveChildren = try await store.children(mediumUUID: mediumID, parentID: parentID)
            } catch {
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.store, .error, "store error children \(error)")
                }
                liveChildren = []
            }
            let liveFolders = Set(
                liveChildren
                    .filter(\.isFolder)
                    .map(\.name)
            )
            do {
                if await store.hasActiveIndexingToken(mediumUUID: mediumID) {
                    return .deferred
                }
                guard await writeAllowed() else { return .deferred }
                try await store.applyDirectories(
                    mediumUUID: mediumID,
                    batches: [(parentID: parentID, path: nil, depth: nil, entries: entries, finalize: true)],
                    seenAt: Date(),
                    mountPath: mount
                )
                DiskIndexLog.shared.record(.watcher, .info, "reread entries=\(entries.count)", privateDetail: directory)
            } catch is CancellationError {
                return .deferred
            } catch {
                DiskIndexLog.shared.record(.watcher, .error, "reread \(DiskIndexLog.errorSummary(error))", privateDetail: directory)
                return .needsFullReconcile
            }
            let childDepth = relative.count + 1
            let withinDepth = maxDepth.map { childDepth < $0 } ?? true
            guard withinDepth else { continue }
            for entry in entries where entry.isFolder {
                let child = URL(fileURLWithPath: directory).appendingPathComponent(entry.name).standardizedFileURL.path
                let isNew = !liveFolders.contains(entry.name)
                if isNew || eventPaths.contains(child) {
                    queue.append(child)
                }
            }
        }
        return .ok
    }

    private static func directoryURL(mount: String, components: [String]) -> URL {
        var url = URL(fileURLWithPath: mount, isDirectory: true)
        for part in components { url.appendPathComponent(part) }
        return url.standardizedFileURL
    }

    private static func relativeComponents(_ path: String, mount: String) -> [String] {
        let mountPath = URL(fileURLWithPath: mount).standardizedFileURL.path
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard standardized != mountPath else { return [] }
        let prefix = mountPath.hasSuffix("/") ? mountPath : mountPath + "/"
        guard standardized.hasPrefix(prefix) else { return [] }
        return standardized.dropFirst(prefix.count).split(separator: "/").map(String.init)
    }

    private static func scanned(_ entry: ListedDirectoryEntry) -> ScannedEntry {
        let asFile = !entry.isDirectory || entry.isPackage || entry.isSymbolicLink
        return ScannedEntry(
            name: entry.name,
            isFolder: !asFile,
            isPackage: entry.isPackage && !entry.isSymbolicLink,
            sizeBytes: asFile && !entry.isPackage && !entry.isSymbolicLink ? entry.fileSize : nil,
            modifiedAt: entry.modifiedAt,
            fileID: FileIdentity.scannedFileID(entry.fileID)
        )
    }
}
