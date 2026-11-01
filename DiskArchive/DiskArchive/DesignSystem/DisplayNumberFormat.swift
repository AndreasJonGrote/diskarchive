//
//  DisplayNumberFormat.swift
//  DiskArchive
//
//  README 10: Zahlen und Uhrzeiten nach App-Sprache (de: Tausendertrenner Punkt, en: Komma).
//

import Foundation

nonisolated enum DisplayNumberFormat {
    static func groupedInteger(_ value: Int) -> String {
        value.formatted(.number.locale(L10n.locale()))
    }
}

nonisolated enum DisplayTimeFormat {
    /// „14:30“ — 24-Stunden-Uhr in beiden Sprachen.
    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
