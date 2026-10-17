//
//  BundleVersionTests.swift
//  diskindexTests
//
//  Aufgabe 220: Versionsnummer 0.2.0, Build-Nummer wird beim Bauen gesetzt.
//

import Foundation
import Testing

struct BundleVersionTests {
    @Test func marketingVersionIsZeroThreeTwo() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == "0.3.8")
    }

    @Test func buildNumberIsSetByTheBuild() throws {
        let text = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        let number = try #require(Int(text))
        #expect(number > 1)
    }
}
