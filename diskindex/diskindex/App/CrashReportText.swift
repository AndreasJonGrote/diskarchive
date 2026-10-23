//
//  CrashReportText.swift
//  diskindex
//
//  Protokollauszug (letzte Zeilen) für den Absturzbericht. bug.0.4.115: `make` entfernt (toter Code).
//

import Foundation

nonisolated enum CrashReportText {
    static func tail(_ text: String, limit: Int) -> [String] {
        var rows = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // Der Zeilenumbruch nach der letzten Zeile ist keine eigene leere Zeile (todo.0.4.023).
        if rows.last == "" { rows.removeLast() }
        guard rows.count > limit else { return rows }
        return Array(rows.suffix(limit))
    }
}
