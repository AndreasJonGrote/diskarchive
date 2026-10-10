//
//  DisplayNumberFormat.swift
//  diskindex
//
//  README 10: Tausendertrenner Punkt (de-DE).
//

import Foundation

nonisolated enum DisplayNumberFormat {
    private static let locale = Locale(identifier: "de_DE")

    static func groupedInteger(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }
}
