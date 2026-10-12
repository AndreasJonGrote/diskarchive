//
//  AppLanguagePolicyTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) struct AppLanguagePolicyTests {
    @Test func bootstrapPersistsDetectedLanguageOnFirstRun() {
        let suite = "diskindex-lang-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let settings = AppLanguagePolicy.bootstrap(defaults: defaults)
        #expect(defaults.string(forKey: AppLanguagePolicy.displayLanguageKey) == settings.displayLanguage.rawValue)
        #expect(AppLanguagePolicy.loadDisplayLanguage(from: defaults) == settings.displayLanguage)
    }

    @Test func applyAppleLanguagesSetsPrimaryAndFallback() {
        let suite = "diskindex-lang-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let defaults = UserDefaults(suiteName: suite)!

        AppLanguagePolicy.applyAppleLanguages(.german, defaults: defaults)
        #expect(defaults.stringArray(forKey: AppLanguagePolicy.appleLanguagesKey)?.first == "de")

        AppLanguagePolicy.applyAppleLanguages(.english, defaults: defaults)
        #expect(defaults.stringArray(forKey: AppLanguagePolicy.appleLanguagesKey)?.first == "en")
    }

    @Test func syncFromSettingsUpdatesActiveLanguageForL10n() {
        let suite = "diskindex-lang-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let defaults = UserDefaults(suiteName: suite)!
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
