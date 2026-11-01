//
//  NoVisibleTestWindowsTests.swift
//  DiskArchiveTests
//
//  bug.0.4.116/142 — Wächter (Regel 19/21): Kein Testfenster im sichtbaren Bereich, keine App-Aktivierung, kein
//  Key-/Main-Fenster. Jede Fensterkonstruktion im Testziel muss außerhalb des Bildschirms liegen (echter Ursprung
//  −20 000 bzw. `PixelProbe`-Ursprung), auch mehrzeilig, ohne `contentRect` (`NSWindow()`, `contentViewController:`).
//

import Foundation
import Testing

struct NoVisibleTestWindowsTests {
    private static let forbidden = ["NSApp.activate", "makeKeyAndOrderFront", ".makeKey()", "orderFront(", "makeMain", "makeKeyWindow"]
    private static let constructors = ["NSWindow(", "NSPanel(", "ProbePanel(", "KeyablePanel(", "MainAppWindow("]
    private static let offscreenTokens = ["-20_000", "-20000", "offscreenOrigin", "nextOffscreenOrigin(", "offscreenWindow("]

    /// Liefert die Fundstellen (`Datei:Zeile Grund`) in einem Quelltext.
    static func violations(in source: String, file: String) -> [String] {
        let lines = source.components(separatedBy: "\n")
        func isComment(_ line: String) -> Bool { line.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        var hits: [String] = []
        for (index, line) in lines.enumerated() where !isComment(line) {
            for token in forbidden where line.contains(token) {
                hits.append("\(file):\(index + 1) \(token)")
            }
            for constructor in constructors {
                guard let range = line.range(of: constructor) else { continue }
                // Aufruf bis zur schließenden Klammer sammeln (mehrzeilig).
                var call = String(line[range.lowerBound...])
                var depth = 0
                var closed = false
                var cursor = index
                var text = call
                scan: while true {
                    for character in text {
                        if character == "(" { depth += 1 }
                        if character == ")" { depth -= 1; if depth == 0 { closed = true; break scan } }
                    }
                    cursor += 1
                    guard cursor < lines.count, cursor - index < 12 else { break }
                    text = lines[cursor]
                    call += " " + text
                }
                _ = closed
                let ahead = lines[index..<min(lines.count, index + 10)].joined(separator: " ")
                let needsFrame = !call.contains("contentRect:")
                if needsFrame {
                    // `NSWindow()` / `contentViewController:` – die Lage muss danach gesetzt werden.
                    if !offscreenTokens.contains(where: { ahead.contains($0) }) {
                        hits.append("\(file):\(index + 1) Fenster ohne Lage")
                    }
                } else if !offscreenTokens.contains(where: { call.contains($0) }) {
                    hits.append("\(file):\(index + 1) sichtbarer Ursprung")
                }
            }
        }
        return hits
    }

    @Test func everyTestWindowStartsOffscreen() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let files = try FileManager.default.contentsOfDirectory(at: testsDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "NoVisibleTestWindowsTests.swift" }
        try #require(files.count > 10)
        var hits: [String] = []
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            hits += Self.violations(in: source, file: file.lastPathComponent)
        }
        #expect(hits.isEmpty, "Testfenster im sichtbaren Bereich oder App-Aktivierung: \(hits.joined(separator: ", "))")
    }

    /// Sabotage: der Wächter erkennt ein Fenster bei (0, 0), mehrzeilige Aufrufe, `NSWindow()` und `NSApp.activate`.
    @Test func guardDetectsVisibleWindowsAndActivation() {
        let visible = """
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered, defer: false
        )
        """
        #expect(!Self.violations(in: visible, file: "x").isEmpty)
        #expect(!Self.violations(in: "let w = NSWindow()", file: "x").isEmpty)
        #expect(!Self.violations(in: "let p = NSPanel(contentViewController: vc)", file: "x").isEmpty)
        #expect(!Self.violations(in: "NSApp.activate(ignoringOtherApps: true)", file: "x").isEmpty)
        #expect(!Self.violations(in: "window.makeMain()", file: "x").isEmpty)
        let offscreen = """
        let window = NSWindow(
            contentRect: NSRect(origin: CGPoint(x: -20_000, y: -20_000), size: size),
            styleMask: [.borderless], backing: .buffered, defer: false)
        """
        #expect(Self.violations(in: offscreen, file: "x").isEmpty)
        // Teilstring „ffscreen“ irgendwo in der Zeile genügt nicht mehr.
        #expect(!Self.violations(in: "let w = NSWindow(contentRect: NSRect(origin: .zero, size: s), styleMask: [], backing: .buffered, defer: false) // offscreen", file: "x").isEmpty)
    }
}
