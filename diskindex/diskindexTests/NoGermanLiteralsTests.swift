//
//  NoGermanLiteralsTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

struct NoGermanLiteralsTests {
    @Test func noGermanLiteralsOutsideCopySources() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let targets = [
            root.appendingPathComponent("diskindex/diskindex/Views"),
            root.appendingPathComponent("diskindex/diskindex/MenuBar"),
            root.appendingPathComponent("diskindex/diskindex/DesignSystem"),
        ]
        let pattern = #/(Text|Label|Button|Toggle|TextField)\(\s*"([^"]*[A-Za-zÄÖÜäöüß][^"]*)"/#
        let helpPattern = #/\.help\(\s*"([^"]*[A-Za-zÄÖÜäöüß][^"]*)"/#
        var hits: [String] = []
        let skipFiles = Set([
            "LayoutCopy.swift",
            "EmptyStateView.swift",
        ])
        for base in targets {
            let enumerator = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)!
            for case let file as URL in enumerator where file.pathExtension == "swift" {
                if skipFiles.contains(file.lastPathComponent) { continue }
                if file.path.contains("/Diagnostics/") { continue }
                let source = try String(contentsOf: file, encoding: .utf8)
                if source.contains("#if DEBUG") && file.lastPathComponent.contains("Diagnostic") { continue }
                for match in source.matches(of: pattern) {
                    let literal = String(match.output.2)
                    if auditExceptions.contains(literal) { continue }
                    if literal.allSatisfy({ $0.isNumber || $0.isWhitespace || $0 == "." || $0 == "%" }) { continue }
                    hits.append("\(file.lastPathComponent): \(literal)")
                }
                for match in source.matches(of: helpPattern) {
                    let literal = String(match.output.1)
                    if auditExceptions.contains(literal) { continue }
                    hits.append("\(file.lastPathComponent): \(literal)")
                }
            }
        }
        #expect(hits.isEmpty, "deutsche Literale außerhalb LayoutCopy: \(hits.joined(separator: " | "))")
    }

    private let auditExceptions: Set<String> = [
        " – ",
        "→",
        "!",
        "Disk Index",
    ]
}
