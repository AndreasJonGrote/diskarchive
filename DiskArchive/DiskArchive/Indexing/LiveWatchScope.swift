//
//  LiveWatchScope.swift
//  DiskArchive
//
//  bug.0.4.022 — Live-Scope und Paket-Innereien (off-main via Engine).
//

import Foundation

nonisolated struct LiveWatchScopeContext: Sendable {
    var mount: String
    var matcher: IgnoreMatcher
    var maxDepth: Int?
    var packageCache: [String: Bool] = [:]
}

nonisolated enum LiveWatchScope {
    static func eventInScope(_ path: String, ctx: inout LiveWatchScopeContext) -> Bool {
        guard let rel = MediaMountPath.relativeComponents(eventPath: path, mountPath: ctx.mount) else { return false }
        for part in rel where ctx.matcher.shouldSkip(name: part, isHidden: part.hasPrefix(".")) {
            return false
        }
        if rel.contains(".Trashes") { return false }
        if isInsidePackageInterior(path, ctx: &ctx) { return false }
        return true
    }

    static func directoryToReread(_ path: String, ctx: inout LiveWatchScopeContext) -> String? {
        if let packageDir = packageRereadDirectory(path, ctx: &ctx) {
            return packageDir
        }
        guard eventInScope(path, ctx: &ctx) else { return nil }
        let mountPath = MediaMountPath.normalizedMount(ctx.mount)
        guard MediaMountPath.relativeComponents(eventPath: path, mountPath: ctx.mount) != nil else { return nil }
        let fileName = (path as NSString).lastPathComponent
        if ctx.matcher.shouldSkip(name: fileName, isHidden: fileName.hasPrefix(".")) { return nil }
        var parent = MediaMountPath.parentDirectory(eventPath: path, mountPath: mountPath) ?? mountPath
        if parent.count < mountPath.count { parent = mountPath }
        var relative = relativeComponents(parent, mount: mountPath)
        if relative.contains(where: { ctx.matcher.shouldSkip(name: $0, isHidden: $0.hasPrefix(".")) }) { return nil }
        if let maxDepth = ctx.maxDepth {
            let limit = max(0, maxDepth - 1)
            if relative.count > limit {
                relative = Array(relative.prefix(limit))
                var url = URL(fileURLWithPath: mountPath, isDirectory: true)
                for part in relative { url.appendPathComponent(part) }
                return url.path
            }
        }
        return parent
    }

    static func scopedParentDirectory(_ path: String, ctx: inout LiveWatchScopeContext) -> String? {
        guard eventInScope(path, ctx: &ctx) else { return nil }
        let mountPath = MediaMountPath.normalizedMount(ctx.mount)
        var parent = MediaMountPath.parentDirectory(eventPath: path, mountPath: mountPath) ?? mountPath
        if parent.count < mountPath.count { parent = mountPath }
        return parent
    }

    private static func isInsidePackageInterior(_ path: String, ctx: inout LiveWatchScopeContext) -> Bool {
        guard let rel = MediaMountPath.relativeComponents(eventPath: path, mountPath: ctx.mount), rel.count > 1 else { return false }
        var url = URL(fileURLWithPath: ctx.mount, isDirectory: true)
        for (index, part) in rel.enumerated() {
            url.appendPathComponent(part)
            if urlIsPackage(url, ctx: &ctx), index < rel.count - 1 { return true }
        }
        return false
    }

    private static func packageRereadDirectory(_ path: String, ctx: inout LiveWatchScopeContext) -> String? {
        guard let rel = MediaMountPath.relativeComponents(eventPath: path, mountPath: ctx.mount) else { return nil }
        var url = URL(fileURLWithPath: ctx.mount, isDirectory: true)
        for (index, part) in rel.enumerated() {
            url.appendPathComponent(part)
            if urlIsPackage(url, ctx: &ctx), index + 1 < rel.count {
                if index == 0 { return MediaMountPath.normalizedMount(ctx.mount) }
                var parentURL = URL(fileURLWithPath: ctx.mount, isDirectory: true)
                for j in 0..<index { parentURL.appendPathComponent(rel[j]) }
                return parentURL.path
            }
        }
        return nil
    }

    private static func urlIsPackage(_ url: URL, ctx: inout LiveWatchScopeContext) -> Bool {
        let key = url.standardizedFileURL.path
        if let cached = ctx.packageCache[key] { return cached }
        let value = (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) == true
        ctx.packageCache[key] = value
        return value
    }

    private static func relativeComponents(_ path: String, mount: String) -> [String] {
        let mountPath = URL(fileURLWithPath: mount).standardizedFileURL.path
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard standardized != mountPath else { return [] }
        let prefix = mountPath.hasSuffix("/") ? mountPath : mountPath + "/"
        guard standardized.hasPrefix(prefix) else { return [] }
        return standardized.dropFirst(prefix.count).split(separator: "/").map(String.init)
    }
}
