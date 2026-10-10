//
//  ProposedCopy.swift
//  diskindex
//
//  Darstellung und Einstellungen für Vorschlagstexte (Aufgabe 119).
//

import AppKit
import SwiftUI

nonisolated enum ProposalCopySettings {
    static let highlightKey = "highlightProposalCopy"

    static var highlightProposalCopy: Bool {
        get {
            if AppDefaults.current.object(forKey: highlightKey) == nil { return true }
            return AppDefaults.current.bool(forKey: highlightKey)
        }
        set { AppDefaults.current.set(newValue, forKey: highlightKey) }
    }
}

extension Notification.Name {
    static let proposalCopyHighlightDidChange = Notification.Name("ProposalCopySettings.highlightDidChange")
}

private struct HighlightProposalCopyKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var forcesProposalCopyHighlight: Bool {
        get { self[HighlightProposalCopyKey.self] }
        set { self[HighlightProposalCopyKey.self] = newValue }
    }
}

nonisolated enum ProposalCopyPresentation {
    static let proposalRed = Color(red: 1, green: 0, blue: 0)

    /// `nil` = Standardtext (keine Vorschlagsfarbe). Rot nur bei aktivem Highlight.
    static func foregroundColor(base: Color?) -> Color? {
        #if DEBUG
        if ProposalCopySettings.highlightProposalCopy {
            return proposalRed
        }
        #endif
        return base
    }

    static func prefixIfNeeded(_ text: String) -> String {
        #if DEBUG
        if ProposalCopySettings.highlightProposalCopy {
            return "[V] \(text)"
        }
        #endif
        return text
    }
}

struct ProposedCopyModifier: ViewModifier {
    @Environment(\.forcesProposalCopyHighlight) private var forcesHighlight
    @AppStorage(ProposalCopySettings.highlightKey, store: AppDefaults.current) private var highlightFromDefaults = true
    var baseColor: Color?

    private var highlightsProposalCopy: Bool {
        #if DEBUG
        forcesHighlight || ProposalCopySettings.highlightProposalCopy || highlightFromDefaults
        #else
        false
        #endif
    }

    func body(content: Content) -> some View {
        #if DEBUG
        if highlightsProposalCopy {
            content.foregroundStyle(Color(red: 1, green: 0, blue: 0))
        } else if let baseColor {
            content.foregroundStyle(baseColor)
        } else {
            content
        }
        #else
        if let baseColor {
            content.foregroundStyle(baseColor)
        } else {
            content
        }
        #endif
    }
}

extension View {
    func proposedCopy(baseColor: Color? = nil) -> some View {
        modifier(ProposedCopyModifier(baseColor: baseColor))
    }
}

extension Text {
    init(proposal string: String) {
        #if DEBUG
        if ProposalCopySettings.highlightProposalCopy {
            var attributed = AttributedString(string)
            attributed.foregroundColor = Color(red: 1, green: 0, blue: 0)
            self.init(attributed)
            return
        }
        #endif
        self.init(string)
    }
}

enum ProposalCopyExporter {
    @MainActor
    static func exportAndReveal() {
        let root = projectRootURL()
        let folder = root.appendingPathComponent("Werkzeuge", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("vorschlagstexte.txt")
        var lines: [String] = []
        for entry in ProposalCopy.catalog {
            lines.append("\(entry.name)\t\(entry.text)\t\(entry.location)")
        }
        let body = lines.joined(separator: "\n") + "\n"
        try? body.write(to: file, atomically: true, encoding: .utf8)
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }

    private static func projectRootURL() -> URL {
        if let env = ProcessInfo.processInfo.environment["DISKINDEX_PROJECT_ROOT"] {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        let bundleRoot = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: bundleRoot.appendingPathComponent("prompt.md").path) {
            return bundleRoot
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
