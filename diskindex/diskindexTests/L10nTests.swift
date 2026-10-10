//
//  L10nTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@Suite struct L10nTests {
    @Test func germanAndEnglishDifferForRepresentativeKeys() {
        let titleDE = L10n.string("copy.new_medium.title", language: .german)
        let titleEN = L10n.string("copy.new_medium.title", language: .english)
        #expect(titleDE == "Neues Speichermedium erkannt")
        #expect(titleEN == "New storage medium detected")
        #expect(titleDE != titleEN)
    }

    @Test func formattedNewMediumBodyUsesPlaceholders() {
        let body = L10n.format("copy.new_medium.body", "Stick", "USB", "2 TB", language: .german)
        #expect(body.contains("Stick"))
        #expect(body.contains("USB"))
        #expect(body.contains("2 TB"))
    }

    @Test func languageLabelsStayNative() {
        #expect(L10n.string("copy.settings.language.german", language: .german) == "Deutsch")
        #expect(L10n.string("copy.settings.language.english", language: .english) == "English")
    }
}
