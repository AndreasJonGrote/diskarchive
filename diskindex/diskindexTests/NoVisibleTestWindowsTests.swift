//
//  NoVisibleTestWindowsTests.swift
//  diskindexTests
//
//  bug.0.4.116 — Wächter (Regel 19): Kein Testfenster im sichtbaren Bereich. Jedes `NSWindow(`/`NSPanel(` im
//  Testziel muss außerhalb des Bildschirms liegen (Ursprung −20 000 bzw. `PixelProbe`), kein `makeKeyAndOrderFront`.
//

import Foundation
import Testing

struct NoVisibleTestWindowsTests {
    @Test func everyTestWindowStartsOffscreen() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let files = try FileManager.default.contentsOfDirectory(at: testsDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "NoVisibleTestWindowsTests.swift" }
        try #require(files.count > 10)
        let constructors = ["NSWindow(", "NSPanel(", "ProbePanel(", "KeyablePanel("]
        var hits: [String] = []
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                if code.hasPrefix("//") || code.hasPrefix("///") { continue }
                if code.contains("makeKeyAndOrderFront") || code.contains(".makeKey()") {
                    hits.append("\(file.lastPathComponent):\(index + 1) makeKey")
                }
                guard constructors.contains(where: { code.contains($0) }) else { continue }
                // Aufruf samt `contentRect:` steht in dieser oder den nächsten zwei Zeilen.
                let upper = min(lines.count, index + 3)
                guard index < upper else { continue }
                let call = lines[index..<upper].joined(separator: " ")
                guard call.contains("contentRect:") else { continue }
                let offscreen = call.contains("-20_000") || call.contains("ffscreen")
                if !offscreen {
                    hits.append("\(file.lastPathComponent):\(index + 1)")
                }
            }
        }
        #expect(hits.isEmpty, "Testfenster im sichtbaren Bereich: \(hits.joined(separator: ", "))")
    }
}
