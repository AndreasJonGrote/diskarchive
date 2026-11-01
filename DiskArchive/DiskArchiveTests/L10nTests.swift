//
//  L10nTests.swift
//  DiskArchiveTests
//

import Foundation
import Testing
@testable import DiskArchive

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

    /// bug.0.4.198: Der Hinweis auf eine neue Version ist der Dialog im Hauptfenster, nicht die Menüleiste.
    @Test func updatesSettingTextDoesNotMentionTheMenuBar() {
        #expect(L10n.string("copy.settings.updates.text", language: .german)
            == "Disk Archive weist dich darauf hin, sobald eine neue Version verfügbar ist.")
        #expect(L10n.string("copy.settings.updates.text", language: .english)
            == "Disk Archive lets you know as soon as a new version is available.")
    }
}
