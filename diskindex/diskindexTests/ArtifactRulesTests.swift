//
//  ArtifactRulesTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@Suite struct ArtifactRulesTests {
    @Test func categoriesHitAndMiss() {
        #expect(ArtifactRules.matches("a.part"))
        #expect(!ArtifactRules.matches("a.part1.rar"))
        #expect(ArtifactRules.matches(".gitignore"))
        #expect(ArtifactRules.matches(".github"))
        #expect(!ArtifactRules.matches(".env"))
        #expect(ArtifactRules.matches("Node_Modules"))
        #expect(ArtifactRules.matches("THUMBS.DB"))
        #expect(ArtifactRules.matches("Icon\u{000D}"))
        #expect(ArtifactRules.matches("notes~"))
        #expect(!ArtifactRules.matches("readme.txt"))
    }

    @Test func hiddenAndArtifactsCombine() {
        let bothOff = IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [], artifactsIgnored: false)
        #expect(!bothOff.shouldSkip(name: ".env", isHidden: true))
        #expect(!bothOff.shouldSkip(name: "node_modules", isHidden: false))
        #expect(bothOff.shouldSkip(name: ".Spotlight-V100", isHidden: true))
        #expect(bothOff.shouldSkip(name: "System Volume Information", isHidden: false))

        let hiddenOffArtifactsOn = IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [], artifactsIgnored: true)
        #expect(!hiddenOffArtifactsOn.shouldSkip(name: ".env", isHidden: true))
        #expect(hiddenOffArtifactsOn.shouldSkip(name: ".git", isHidden: true))
        #expect(hiddenOffArtifactsOn.shouldSkip(name: "node_modules", isHidden: false))

        let hiddenOn = IgnoreMatcher(ignoreHiddenFiles: true, excludedPatterns: [], artifactsIgnored: false)
        #expect(hiddenOn.shouldSkip(name: ".env", isHidden: true))
        #expect(!hiddenOn.shouldSkip(name: "node_modules", isHidden: false))

        let bothOn = IgnoreMatcher(ignoreHiddenFiles: true, excludedPatterns: [], artifactsIgnored: true)
        #expect(bothOn.shouldSkip(name: ".env", isHidden: true))
        #expect(bothOn.shouldSkip(name: "thumbs.db", isHidden: false))
    }

    @Test func ownPatternsUseTheSameWildcards() {
        let matcher = IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: [".git*", "*.part*"], artifactsIgnored: false)
        #expect(matcher.shouldSkip(name: ".gitignore", isHidden: true))
        #expect(!matcher.shouldSkip(name: "a.part1.rar", isHidden: false))
    }

    @Test func savedSettingsKeepOldListsWhenTheArtifactFlagIsNew() throws {
        let old = #"{"scanDepth":4,"favoriteOnlineNotificationsEnabled":false,"ignoreHiddenFiles":false,"excludedPatterns":["Cache"],"showFoldersRegardlessOfFilter":false}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(old.utf8))
        #expect(settings.scanDepth == 4)
        #expect(settings.excludedPatterns == ["Cache"])
        #expect(settings.artifactsIgnored)
        #expect(!settings.ignoreHiddenFiles)
    }

    @Test func legacyArtifactKeysDecodeWithoutCrashing() throws {
        let json = #"{"scanDepth":3,"artifactDisabledCategories":["temporary"],"artifactIncludePatterns":["foo/bar"]}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(settings.scanDepth == 3)
    }
}
