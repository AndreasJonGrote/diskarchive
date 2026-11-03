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
        // todo.0.4.3.005: ohne Medientyp.
        let body = L10n.format("copy.new_medium.body", "Stick", "2 TB", language: .german)
        #expect(body == "„Stick“ (2 TB) wurde angeschlossen. Soll sie indiziert werden?")
    }

    @Test func languageLabelsStayNative() {
        #expect(L10n.string("copy.settings.language.german", language: .german) == "Deutsch")
        #expect(L10n.string("copy.settings.language.english", language: .english) == "English")
    }

    /// bug.0.4.198: Der Hinweis auf eine neue Version ist der Dialog im Hauptfenster, nicht die Menüleiste.
    @Test func updatesSettingTextDoesNotMentionTheMenuBar() {
        #expect(L10n.string("copy.settings.updates.text", language: .german)
            == "Ist eine neue Version von Disk Archive verfügbar, erscheint ein Dialog mit allen Details zum Update.")
        #expect(L10n.string("copy.settings.updates.text", language: .english)
            == "When a new version of Disk Archive is available, a dialog shows all update details.")
    }
}
