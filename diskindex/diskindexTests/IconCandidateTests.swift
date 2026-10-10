//
//  IconCandidateTests.swift
//  diskindexTests
//

import Foundation
import Testing

@Suite(.serialized)
struct IconCandidateTests {
    private var workspace: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test func candidateKeepsTheApprovedShape() throws {
        let tool = workspace.appendingPathComponent("Werkzeuge/icon-pruefen")
        let process = Process()
        process.executableURL = tool
        process.currentDirectoryURL = workspace
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        #expect(process.terminationStatus == 0, "\(output)")
    }

    @Test func dockIconMatchesTheLargeAppIcon() throws {
        let folder = workspace.appendingPathComponent("Werkzeuge/icon-kandidat")
        let dock = try Data(contentsOf: folder.appendingPathComponent("DockIcon.png"))
        let icon = try Data(contentsOf: folder.appendingPathComponent("icon_512x512@2x.png"))
        #expect(dock == icon)
    }
}
