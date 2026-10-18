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
        "FileHandle(forWritingTo", "FileHandle(forUpdating", "FileHandle(forWritingAtPath:",
        ".write(to", ".write(toFile", "forWriting",
        "OutputStream(", "fopen(", "fwrite(", "recycle(", "performFileOperation",
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
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            violations.append(contentsOf: scan(relativePath: relative, contents: text))
        }
        return violations
    }

    static func scan(relativePath: String, contents: String) -> [(file: String, pattern: String)] {
        if isAllowed(relative: relativePath) { return [] }
        var violations: [(String, String)] = []
        for pattern in forbidden where contents.contains(pattern) {
            violations.append((relativePath, pattern))
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

    @Test func sabotageScannerFindsInjectedFileOutsideAllowlist() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-guard-sabotage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let bad = dir.appendingPathComponent("Foo.swift")
        try "try FileManager.default.removeItem(at: u)".write(to: bad, atomically: true, encoding: .utf8)
        let text = try String(contentsOf: bad, encoding: .utf8)
        let hits = Self.scan(relativePath: "Foo.swift", contents: text)
        #expect(!hits.isEmpty)
    }

    @Test func sabotageScannerIgnoresSamePatternOnAllowlistPath() {
        let text = "try FileManager.default.removeItem(at: u)"
        #expect(Self.scan(relativePath: "App/DiskIndexLog.swift", contents: text).isEmpty)
    }

    @Test func permitsBlocksVolumeAndDocuments() throws {
        #expect(!WriteGuard.permits(URL(fileURLWithPath: "/Volumes/X/foo.txt")))
        let docs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/x.txt")
        #expect(!WriteGuard.permits(docs))
        let appDir = try IndexStoreV3.storeFileURL().deletingLastPathComponent()
        #expect(WriteGuard.permits(appDir))
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("wg-ok.txt")
        #expect(WriteGuard.permits(tmp))
    }

    @Test func permitsAllowsDataFolderWhenHomeOnExternalVolume() async {
        // Simuliertes Home auf einem externen Volume: außerhalb aller erlaubten Wurzeln (nicht im Temp-Ordner,
        // sonst wäre der Pfad ohnehin erlaubt). Nur Pfadprüfung, es wird nichts angelegt.
        let externalHome = URL(fileURLWithPath: "/Volumes/ExtHome-\(UUID().uuidString)/Users/test", isDirectory: true)
        let dataRoot = externalHome.appendingPathComponent("Library/Application Support/Disk Archive", isDirectory: true)
        let file = dataRoot.appendingPathComponent("archive.sqlite")
        // bug.0.3.9.013: Override nur in diesem Task (@TaskLocal), außerhalb wirkungslos.
        await WriteGuard.$extraAllowedRootsForTesting.withValue([dataRoot.path]) {
            #expect(WriteGuard.permits(file))
            // Ein gleichzeitig laufender fremder Task (wie ein paralleler Test) sieht den Override nicht.
            let elsewhere = await Task.detached { WriteGuard.permits(file) }.value
            #expect(!elsewhere, "Override wirkt prozessweit")
        }
        #expect(!WriteGuard.permits(file), "Override wirkt über den Task hinaus")
    }

    @Test func diskIndexLogSkipsWriteWhenDirectoryBlocked() {
        // bug.0.3.9.013: eindeutiger Pfad, Zähler je Pfad statt globalem Zurücksetzen (Regel 20).
        let blocked = URL(fileURLWithPath: "/Volumes/BLOCKEDLOG-\(UUID().uuidString)/diskindex.log")
        let log = DiskIndexLog(directory: blocked.deletingLastPathComponent())
        log.record(.app, .info, "blocked test line")
        log.flushPendingWritesForTesting()
        #expect(!FileManager.default.fileExists(atPath: blocked.path))
        #expect(WriteGuard.blockedWriteCount(under: blocked.deletingLastPathComponent()) >= 1)
    }

    @Test func partialChecksumReadsWriteProtectedFile() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-ro-partial-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("ro.bin")
        try Data(repeating: 0xCD, count: 128).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path)
        let digest = try await PartialChecksum.computeOffActor(at: file)
        #expect(digest != nil)
    }
}
