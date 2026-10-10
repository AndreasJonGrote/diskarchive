//
//  AppDisplayLanguageTests.swift
//  diskindexTests
//

import Testing
@testable import diskindex

struct AppDisplayLanguageTests {
    @Test func germanPreferredLanguage() {
        #expect(AppDisplayLanguage.resolveFromOperatingSystem(preferredLanguages: ["de-DE"]) == .german)
        #expect(AppDisplayLanguage.resolveFromOperatingSystem(preferredLanguages: ["de-AT", "en-US"]) == .german)
    }

    @Test func englishPreferredLanguage() {
        #expect(AppDisplayLanguage.resolveFromOperatingSystem(preferredLanguages: ["en-US"]) == .english)
        #expect(AppDisplayLanguage.resolveFromOperatingSystem(preferredLanguages: ["en-GB", "de-DE"]) == .english)
    }

    @Test func otherLanguagesDefaultToEnglish() {
        #expect(AppDisplayLanguage.resolveFromOperatingSystem(preferredLanguages: ["fr-FR"]) == .english)
        #expect(AppDisplayLanguage.resolveFromOperatingSystem(preferredLanguages: []) == .english)
    }

    @Test func appleLanguageCodes() {
        #expect(AppDisplayLanguage.german.appleLanguageCode == "de")
        #expect(AppDisplayLanguage.english.appleLanguageCode == "en")
    }
}
