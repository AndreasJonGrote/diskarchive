//
//  CrashReportText.swift
//  diskindex
//
//  Text, den der Nutzer nach einem Fehler kopiert (Aufgabe 55).
//

import Foundation

nonisolated enum CrashReportText {
    static func make(
        version: String,
        build: String,
        config: String,
        macOS: String,
        model: String,
        started: String,
        runtime: String,
        crashSection: String?,
        actions: [String],
        logLines: [String],
        databaseBytes: Int64?,
        media: String,
        objects: String,
        diagnosticHead: String?
    ) -> String {
        var lines = [
            "Disk Archive Bericht",
            "version=\(version) build=\(build) config=\(config)",
            "macOS=\(macOS) model=\(model)",
            "started=\(started) runtime=\(runtime)",
            "databaseBytes=\(databaseBytes.map(String.init) ?? "unbekannt") media=\(media) objects=\(objects)",
            "",
        ]
        if let crashSection, !crashSection.isEmpty {
            lines.append("CRASH")
            lines.append(crashSection)
            lines.append("")
        }
        lines.append("AKTIONEN")
        lines.append(contentsOf: actions)
        lines.append("")
        lines.append("PROTOKOLL")
        lines.append(contentsOf: logLines)
        if let diagnosticHead, !diagnosticHead.isEmpty {
            lines.append("")
            lines.append("DIAGNOSTICREPORT")
            lines.append(diagnosticHead)
        }
        return lines.joined(separator: "\n")
    }

    static func tail(_ text: String, limit: Int) -> [String] {
        let rows = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard rows.count > limit else { return rows }
        return Array(rows.suffix(limit))
    }
}
