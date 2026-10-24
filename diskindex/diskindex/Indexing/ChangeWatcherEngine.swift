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

    /// bug.0.4.138: Ob ein Vorfahre von `relative` (ohne den Ordner selbst) noch ungelesen in der Schlange steht.
    nonisolated static func hasPendingAncestor(
        of relative: [String],
        mount: String,
        waiting: [String: Int],
        seen: Set<String>
    ) -> Bool {
        guard relative.count > 1 else { return false }
        for length in 1..<relative.count {
            let ancestor = directoryURL(mount: mount, components: Array(relative.prefix(length))).path
            if (waiting[ancestor] ?? 0) > 0, !seen.contains(ancestor) { return true }
        }
        return false
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
        // bug.0.4.138: wenige Komponenten zuerst, damit neue Elternordner vor ihren Kindern gelesen werden (Bündel sind
        // ungeordnet; sonst fehlen tiefen Ordnern die Elternzeilen und es kommt zum Vollabgleich des Mediums).
        // bug.0.4.154: die Tiefe einmal je Pfad bestimmen, nicht bei jedem Vergleich.
        let depths = Dictionary(uniqueKeysWithValues: eventPaths.map { ($0, Self.relativeComponents($0, mount: mount).count) })
        var queue = eventPaths.sorted { lhs, rhs in
            let left = depths[lhs] ?? 0
            let right = depths[rhs] ?? 0
            return left != right ? left < right : lhs < rhs
        }
        var seen = Set<String>()
        // bug.0.4.138: wartende Einträge je Pfad (statt je Aufruf ein Set aus der Restschlange).
        var waiting: [String: Int] = [:]
        for path in queue { waiting[path, default: 0] += 1 }
        func push(_ path: String) {
            queue.append(path)
            waiting[path, default: 0] += 1
        }
        var attempts: [String: Int] = [:]
        var index = 0
        while index < queue.count {
            guard await writeAllowed() else { return .deferred }
            let directory = queue[index]
            index += 1
            waiting[directory, default: 1] -= 1
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
                        DiskIndexLog.shared.record(.store, .error, "store error folderID \(DiskIndexLog.errorSummary(error))")
                    }
                    folderID = nil
                }
                if let id = folderID {
                    parentID = id
                } else {
                    if relative.count == 1 {
                        let rootDir = URL(fileURLWithPath: mount, isDirectory: true).standardizedFileURL.path
                        if !seen.contains(rootDir) {
                            push(rootDir)
                        }
                        continue
                    }
                    var parentExists = false
                    if relative.count > 1 {
                        do {
                            parentExists = try await store.folderID(mediumUUID: mediumID, path: Array(relative.dropLast())) != nil
                        } catch {
                            if DiskIndexLog.isOperationalFailure(error) {
                                DiskIndexLog.shared.record(.store, .error, "store error folderID parent \(DiskIndexLog.errorSummary(error))")
                            }
                            parentExists = false
                        }
                    }
                    if parentExists {
                        let parentDir = Self.directoryURL(mount: mount, components: Array(relative.dropLast())).path
                        if !seen.contains(parentDir) {
                            push(parentDir)
                        }
                        continue
                    }
                    // bug.0.4.138: Ein Vorfahre steht noch in der Schlange → er legt die Elternzeile an; kein Versuch.
                    if Self.hasPendingAncestor(of: relative, mount: mount, waiting: waiting, seen: seen) {
                        push(directory)
                        continue
                    }
                    let attempt = attempts[directory, default: 0] + 1
                    attempts[directory] = attempt
                    if attempt <= 2 {
                        push(directory)
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
            var liveReadFailed = false
            do {
                liveChildren = try await store.children(mediumUUID: mediumID, parentID: parentID)
            } catch {
                liveReadFailed = true
                if DiskIndexLog.isOperationalFailure(error) {
                    DiskIndexLog.shared.record(.store, .error, "store error children \(DiskIndexLog.errorSummary(error))")
                }
                liveChildren = []
            }
            let liveFolders = Set(
                liveChildren
                    .filter(\.isFolder)
                    .map(\.name)
            )
            // bug.0.4.181: gleiche Regel wie im Lauf (bug.0.4.177) – nach dem Auswerfen liest der stehengebliebene
            // Einhängeordner leer; dann nichts schreiben (der Inhalt bleibt, das Aushängen räumt auf).
            if await VanishedMediumGuard.vanished(
                folderEntries: entries, parentID: parentID,
                previousRootNames: previousRootNames(parentID: parentID, liveChildren: liveChildren, readFailed: liveReadFailed),
                store: store, access: access, mediumUUID: mediumID, stored: nil, mountPath: mount
            ) {
                DiskIndexLog.shared.record(.watcher, .error, "medium nicht mehr eingehängt medium=\(mediumID)")
                return .deferred
            }
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
                    push(child)
                }
            }
        }
        return .ok
    }

    /// Namen der bisherigen Wurzel für `VanishedMediumGuard` (nur dort gebraucht); `nil` = nicht lesbar.
    private func previousRootNames(parentID: Int64?, liveChildren: [StoredItem], readFailed: Bool) -> Set<String>? {
        guard parentID == nil else { return [] }
        return readFailed ? nil : Set(liveChildren.map(\.name))
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
