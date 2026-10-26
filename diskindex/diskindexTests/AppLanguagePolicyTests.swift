//
//  AppLanguagePolicyTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) struct AppLanguagePolicyTests {
    @Test func bootstrapPersistsDetectedLanguageOnFirstRun() {
        let defaults = TestDefaults.make()

        let settings = AppLanguagePolicy.bootstrap(defaults: defaults)
        #expect(defaults.string(forKey: AppLanguagePolicy.displayLanguageKey) == settings.displayLanguage.rawValue)
        #expect(AppLanguagePolicy.loadDisplayLanguage(from: defaults) == settings.displayLanguage)
    }

    /// bug.0.4.208: `AppleLanguages` schreibt nur `SystemDefaults` (unter Tests nie); geprüft wird der Wert.
    @Test func appleLanguagesHavePrimaryAndFallback() {
        #expect(AppLanguagePolicy.appleLanguages(for: .german) == ["de", "en", "en"])
        #expect(AppLanguagePolicy.appleLanguages(for: .english) == ["en", "de", "en"])
    }

    @Test func syncFromSettingsUpdatesActiveLanguageForL10n() {
        let defaults = TestDefaults.make()
        let previous = AppLanguagePolicy.resolvedDisplayLanguage()
        defer { AppLanguagePolicy.noteActiveDisplayLanguage(previous) }

        var settings = AppSettings()
        settings.displayLanguage = .english
        AppLanguagePolicy.withActiveLanguageLock {
            AppLanguagePolicy.syncFromSettings(settings, defaults: defaults)
            #expect(AppLanguagePolicy.resolvedDisplayLanguage(fallbackDefaults: defaults) == .english)
            #expect(L10n.string("copy.settings.tab.general") == "General")
            #expect(AppLanguagePolicy.loadDisplayLanguage(from: defaults) == .english)
        }
    }
}
