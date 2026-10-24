//
//  MemoryVolume.swift
//  diskindexTests
//

import Foundation
@testable import diskindex

final class MemoryVolume: MediumAccess, @unchecked Sendable {
    struct Node {
        var children: [String: Node] = [:]
        var isPackage = false
        var isSymbolicLink = false
        var isHidden = false
        var isDirectory = true
        var size: Int64?
        var unreadable = false
    }

    let mountPath: String
    private var root = Node()
    private let lock = NSLock()
    private(set) var listed: [String] = []
    private var rootError: Error?
    private var ejected = false
    private var foreign = false
    private var slowFromDepth: Int?

    init(mountPath: String) {
        self.mountPath = mountPath
    }

    @discardableResult
    func file(_ relative: String, size: Int64 = 4) -> MemoryVolume {
        var node = Node()
        node.isDirectory = false
        node.size = size
        node.isHidden = relative.split(separator: "/").last?.hasPrefix(".") == true
        insert(relative, node)
        return self
    }

    @discardableResult
    func package(_ relative: String, child: String) -> MemoryVolume {
        var node = Node()
        node.isPackage = true
        node.children[child] = {
            var file = Node()
            file.isDirectory = false
            file.size = 1
            return file
        }()
        insert(relative, node)
        return self
    }

    @discardableResult
    func symlink(_ relative: String) -> MemoryVolume {
        var node = Node()
        node.isDirectory = false
        node.isSymbolicLink = true
        insert(relative, node)
        return self
    }

    func markUnreadable(_ relative: String) {
        lock.lock()
        defer { lock.unlock() }
        if relative.isEmpty {
            root.unreadable = true
            return
        }
        mutate(relative) { $0.unreadable = true }
    }

    func markReadable(_ relative: String) {
        lock.lock()
        defer { lock.unlock() }
        if relative.isEmpty {
            root.unreadable = false
            return
        }
        mutate(relative) { $0.unreadable = false }
    }

    func remove(_ relative: String) {
        lock.lock()
        defer { lock.unlock() }
        let parts = relative.split(separator: "/").map(String.init)
        guard let name = parts.last else { return }
        if parts.count == 1 {
            root.children[name] = nil
            return
        }
        let parent = parts.dropLast().joined(separator: "/")
        mutate(parent) { $0.children[name] = nil }
    }

    func clearListed() {
        lock.lock()
        listed.removeAll()
        lock.unlock()
    }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    /// bug.0.4.177: Medium ausgeworfen, der Einhängepunkt bleibt als leerer Ordner stehen – die Wurzel liest leer,
    /// alles darunter fehlt, und die Prüfung „dieses Medium ist eingehängt“ sagt nein.
    func eject() {
        lock.lock()
        defer { lock.unlock() }
        ejected = true
    }

    private var isEjected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return ejected
    }

    /// bug.0.4.177: unter dem Pfad ist ein anderes Medium eingehängt (eigener Inhalt, die Prüfung sagt nein).
    func markForeign() {
        lock.lock()
        defer { lock.unlock() }
        foreign = true
    }

    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool {
        lock.withLock { !ejected && !foreign }
    }

    /// Das Lesen des Wurzelordners schlägt mit genau diesem Fehler fehl (Fehlergrund-Tests, 202).
    func failRoot(with error: Error) {
        lock.lock()
        defer { lock.unlock() }
        rootError = error
    }

    /// Das Lesen von Ordnern ab dieser Tiefe (Wurzel = 0) dauert künstlich länger (Vorlauf-Test, 206).
    func slowListing(fromDepth depth: Int) {
        lock.lock()
        defer { lock.unlock() }
        slowFromDepth = depth
    }

    private func listingDelay(for path: String) -> Duration? {
        lock.lock()
        defer { lock.unlock() }
        guard let slowFromDepth else { return nil }
        let rootPath = URL(fileURLWithPath: mountPath).standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return nil }
        let depth = path.dropFirst(rootPath.count).split(separator: "/").count
        return depth >= slowFromDepth ? .milliseconds(30) : nil
    }

    private func injectedRootError() -> Error? {
        lock.lock()
        defer { lock.unlock() }
        return rootError
    }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        let path = url.standardizedFileURL.path
        if let delay = listingDelay(for: path) { try await Task.sleep(for: delay) }
        let node = recordListing(path)
        if path == URL(fileURLWithPath: mountPath).standardizedFileURL.path, let injected = injectedRootError() {
            throw injected
        }
        if isEjected {
            if path == URL(fileURLWithPath: mountPath).standardizedFileURL.path { return [] }
            throw CocoaError(.fileReadNoSuchFile)
        }
        guard let node else { throw CocoaError(.fileReadNoSuchFile) }
        if node.unreadable { throw CocoaError(.fileReadNoPermission) }
        return node.children.map { name, child in
            ListedDirectoryEntry(
                name: name,
                isDirectory: child.isSymbolicLink ? false : child.isDirectory,
                isPackage: child.isPackage && !child.isSymbolicLink,
                isSymbolicLink: child.isSymbolicLink,
                isHidden: child.isHidden || name.hasPrefix("."),
                fileSize: child.size,
                modifiedAt: nil
            )
        }
    }

    private func recordListing(_ path: String) -> Node? {
        lock.lock()
        defer { lock.unlock() }
        listed.append(path)
        return node(at: path)
    }

    private func insert(_ relative: String, _ node: Node) {
        lock.lock()
        defer { lock.unlock() }
        let parts = relative.split(separator: "/").map(String.init)
        func put(_ parts: ArraySlice<String>, into parent: inout Node) {
            guard let head = parts.first else { return }
            if parts.count == 1 {
                parent.children[head] = node
                return
            }
            var child = parent.children[head] ?? Node()
            child.isDirectory = true
            put(parts.dropFirst(), into: &child)
            parent.children[head] = child
        }
        put(parts[...], into: &root)
    }

    private func node(at path: String) -> Node? {
        if path == mountPath || path == mountPath + "/" { return root }
        guard path.hasPrefix(mountPath + "/") else { return nil }
        return nodeAt(String(path.dropFirst(mountPath.count + 1)))
    }

    private func nodeAt(_ relative: String) -> Node? {
        var current = root
        if relative.isEmpty { return root }
        for part in relative.split(separator: "/") {
            guard let next = current.children[String(part)] else { return nil }
            current = next
        }
        return current
    }

    private func mutate(_ relative: String, _ change: (inout Node) -> Void) {
        let parts = relative.split(separator: "/").map(String.init)
        func edit(_ parts: ArraySlice<String>, node: inout Node) {
            guard let head = parts.first, var child = node.children[head] else { return }
            if parts.count == 1 {
                change(&child)
                node.children[head] = child
                return
            }
            edit(parts.dropFirst(), node: &child)
            node.children[head] = child
        }
        edit(parts[...], node: &root)
    }
}

