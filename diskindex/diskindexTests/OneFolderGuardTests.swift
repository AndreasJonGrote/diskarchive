//
//  OneFolderGuardTests.swift
//  diskindexTests
//
//  bug.0.4.208: Alles von Disk Archive liegt in einem Ordner; Tests schreiben nichts nach `~/Library/Preferences`.
//  Quelltext-Wächter (wie todo.0.4.014), Schreibschranke, Ort des Protokolls und Rundlauf von `app-state.plist`.
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct OneFolderGuardTests {
    private static let forbiddenName = "User" + "Defaults"
    /// Die eine Ausnahmedatei der App (`AppleLanguages`, `NSQuitAlwaysKeepsWindows`).
    private static let exceptionFile = "App/SystemDefaults.swift"

    private static var repoRoot: URL {
        var repo = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { repo.deleteLastPathComponent() }
        return repo
    }

    /// Dateien unter `folder`, die `UserDefaults` außerhalb von Kommentaren nennen (relativ zu `folder`).
    private static func filesNamingTheSettingsAPI(in folder: String) throws -> [String] {
        let root = repoRoot.appendingPathComponent(folder, isDirectory: true)
        let files = try swiftFiles(in: root)
        #expect(files.count > 50, "Gegenprobe: Quelltext unter \(folder) nicht gefunden")
        return try files.compactMap { url -> String? in
            let text = try String(contentsOf: url, encoding: .utf8)
            let code = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> Substring in
                guard let comment = line.range(of: "//") else { return line }
                return line[..<comment.lowerBound]
            }
            guard code.contains(where: { $0.contains(forbiddenName) }) else { return nil }
            return url.path.replacingOccurrences(of: root.path + "/", with: "")
        }.sorted()
    }

    @Test func testsStayOutOfPreferences() throws {
        let files = try Self.filesNamingTheSettingsAPI(in: "diskindex/diskindexTests")
        #expect(files.isEmpty, "\(Self.forbiddenName) in Tests: \(files.joined(separator: ", "))")
    }

    @Test func appTouchesPreferencesOnlyInTheExceptionFile() throws {
        let files = try Self.filesNamingTheSettingsAPI(in: "diskindex/diskindex")
        #expect(files.contains(Self.exceptionFile), "Gegenprobe: Der Wächter findet die Ausnahmedatei nicht")
        #expect(files == [Self.exceptionFile], "\(Self.forbiddenName) außerhalb der Ausnahme: \(files.joined(separator: ", "))")
    }

    @Test func writeGuardPermitsOnlyTheDataFolderAndTemporaryItems() {
        let library = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        #expect(WriteGuard.permits(AppDataFolder.url.appendingPathComponent("app-state.plist")), "Gegenprobe: Datenordner gesperrt")
        #expect(WriteGuard.permits(AppDataFolder.url.appendingPathComponent("Logs/diskindex.log")))
        #expect(WriteGuard.permits(URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("x")))
        #expect(!WriteGuard.permits(library.appendingPathComponent("Preferences/x.plist")))
        #expect(!WriteGuard.permits(library.appendingPathComponent("Caches/x")))
        #expect(!WriteGuard.permits(library.appendingPathComponent("Logs/x")))
    }

    @Test func logLivesInTheDataFolder() {
        let expected = AppDataFolder.url.appendingPathComponent("Logs", isDirectory: true).standardizedFileURL.path
        #expect(DiskIndexLog.defaultDirectory.standardizedFileURL.path == expected)
        #expect(DiskIndexLog.shared.fileURL.deletingLastPathComponent().standardizedFileURL.path == expected)
    }

    // MARK: - Rundlauf der Datei

    private static func temporaryStateFile() throws -> (folder: URL, file: URL) {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("diskindex-app-state-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return (folder, folder.appendingPathComponent(AppStateStore.fileName))
    }

    /// Pause setzen, neuer Speicher auf dieselbe Datei, die Pause ist da. Gegenprobe zuerst: ein gesetzter Wert wird
    /// über die Datei gelesen.
    @Test func pauseSurvivesReopeningTheFile() throws {
        let (folder, file) = try Self.temporaryStateFile()
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = AppStateStore(fileURL: file)
        first.set("probe", forKey: "probe")
        #expect(AppStateStore(fileURL: file).string(forKey: "probe") == "probe", "Gegenprobe: Wert nicht in der Datei")

        let app = AppState(defaults: first)
        app.pauseIndexing(until: nil, defaults: first)
        let reopened = AppStateStore(fileURL: file)
        let pause = try #require(reopened.data(forKey: AppState.pauseKey), "Pause nicht in der Datei")
        #expect(try JSONDecoder().decode(GlobalPause.self, from: pause).isPaused)
        #expect(AppState(defaults: reopened).globalAutoIndexPaused, "Pause nach dem Öffnen der Datei nicht da")
        let mode = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
    }

    @Test func brokenFileGivesAnEmptyState() throws {
        let (folder, file) = try Self.temporaryStateFile()
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = AppStateStore(fileURL: file)
        first.set(true, forKey: "probe")
        #expect(AppStateStore(fileURL: file).bool(forKey: "probe"), "Gegenprobe: Wert nicht in der Datei")
        try Data("kaputt".utf8).write(to: file)
        let broken = AppStateStore(fileURL: file)
        #expect(broken.readFailure != nil, "Lesefehler nicht vorgemerkt (Protokollzeile)")
        #expect(!broken.bool(forKey: "probe"))
        #expect(broken.data(forKey: AppState.pauseKey) == nil)
    }
}
