//
//  ReadOnlyMediaGuardTests.swift
//  diskindexTests
//
//  todo.0.4.014: Quelltext-Wächter + WriteGuard + schreibgeschützte Teil-Prüfsumme.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct ReadOnlyMediaGuardTests {
    private static let sourceRoot = "diskindex/diskindex"

    private static let allowlist: [(suffix: String, reason: String)] = [
        ("App/DiskIndexLog.swift", "Protokoll und Absturzdatei"),
        ("App/IssueTracker.swift", "Fehlerbericht-Ausgang"),
        ("App/DatabaseCare.swift", "Datenbank-Wartung und Quarantäne"),
        ("App/AppDefaults.swift", "Voreinstellungen"),
        ("Storage/FilePrivacy.swift", "Rechte am Datenordner"),
        ("Storage/V3/SchemaV3.swift", "Datenbank anlegen"),
        ("DebugTools/", "Debug-Ausgaben"),
    ]

    private static let forbidden: [String] = [
        "removeItem", "trashItem", "moveItem", "copyItem", "replaceItem",
        "createFile", "createDirectory", "createSymbolicLink", "linkItem",
        "FileHandle(forWritingTo", "FileHandle(forUpdating", ".write(to",
        "setAttributes", "setxattr", "removexattr",
        "O_WRONLY", "O_RDWR", "O_CREAT", "O_APPEND", "O_TRUNC",
        "unlink(", "rename(", "mkdir(", "truncate(", "ftruncate(", "symlink(", "link(",
        "DADiskUnmount", "DADiskEject", "unmountAndEjectDevice",
    ]

    static func scanSources(repoRoot: URL) -> [(file: String, pattern: String)] {
        let root = repoRoot.appendingPathComponent(sourceRoot, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var violations: [(String, String)] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            if isAllowed(relative: relative) { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for pattern in forbidden where text.contains(pattern) {
                violations.append((relative, pattern))
            }
        }
        return violations
    }

    private static func isAllowed(relative: String) -> Bool {
        for entry in allowlist {
            if entry.suffix.hasSuffix("/") {
                if relative.hasPrefix(entry.suffix) { return true }
            } else if relative == entry.suffix {
                return true
            }
        }
        return false
    }

    @Test func productionSourcesHaveNoForbiddenWriteAPIsOutsideAllowlist() {
        var repo = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { repo.deleteLastPathComponent() }
        let violations = Self.scanSources(repoRoot: repo)
        #expect(violations.isEmpty, "ReadOnlyMediaGuard: \(violations.map { "\($0.file): \($0.pattern)" }.joined(separator: "; "))")
    }

    @Test func sabotageDetectorFindsInjectedPattern() {
        let sample = """
        func oops() { try FileManager.default.removeItem(at: url) }
        """
        let hit = Self.forbidden.contains { sample.contains($0) }
        #expect(hit)
    }

    @Test func writeGuardBlocksRegisteredMediumMount() throws {
        let mount = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-writeguard-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer {
            WriteGuard.clearMediumMountPathsForTesting()
            try? FileManager.default.removeItem(at: mount)
        }
        WriteGuard.registerMediumMountPath(mount.path)
        let target = mount.appendingPathComponent("blocked.txt")
        #expect(WriteGuard.wouldBlock(target))
        let appDir = try IndexStoreV3.storeFileURL().deletingLastPathComponent()
        #expect(!WriteGuard.wouldBlock(appDir))
    }

    @Test func partialChecksumReadsWriteProtectedFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-ro-partial-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("ro.bin")
        try Data(repeating: 0xCD, count: 128).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path)
        let digest = try PartialChecksum.compute(at: file)
        #expect(digest != nil)
    }
}
