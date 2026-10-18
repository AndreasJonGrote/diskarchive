//
//  IgnoreMatcherEquivalenceTests.swift
//  diskindexTests
//
//  bug.0.4.056 (REPORT 97): Muster einmal zerlegt, Name einmal kleingeschrieben, Artefakte über Set/Präfix/Suffix.
//  Das Ergebnis muss dem alten Weg (jedes Muster je Eintrag neu zerlegen und vergleichen) gleichen.
//

import Foundation
import Testing
@testable import diskindex

/// Der alte Weg, Schritt für Schritt nachgebaut (Stand vor bug.0.4.056).
private func referenceSkip(_ matcher: IgnoreMatcher, name: String, isHidden: Bool) -> Bool {
    if name.hasPrefix("._") { return true }
    if IgnoreMatcher.alwaysSkipped.contains(name) { return true }
    if matcher.ignoreHiddenFiles, isHidden || name.hasPrefix(".") { return true }
    if matcher.artifactsIgnored, ArtifactRules.patterns.contains(where: { $0.matches(name) }) { return true }
    for pattern in matcher.excludedPatterns {
        guard let rule = NamePattern.parse(pattern) else { continue }
        if rule.matches(name) { return true }
    }
    return false
}

@Suite struct IgnoreMatcherEquivalenceTests {
    private static let userPatterns = ["*.MOV", "Entwurf*", "genau.TXT", "fra?e", "*a*b", "[x]", "", "*", "ÄRGER*", "*.ß"]

    private static var names: [String] {
        var result = [
            "a.part", "a.part1.rar", ".gitignore", ".github", ".env", "Node_Modules", "THUMBS.DB", "Icon\u{000D}", "notes~",
            "readme.txt", "x.TMP", "~$Brief.docx", "Pods", "pods.txt", ".DS_Store", "._resource", ".Trashes", ".trash-501",
            "DerivedData", "deriveddata2", "film.mov", "FILM.Mov", "Entwurf 3", "entwurf", "genau.txt", "genau.txt.bak",
            "frage", "fra?e", "ab", "Ärgernis", "ärger", "STRASSE.ß", "straße", "ǅungla", "İstanbul.log", ".hidden", "normal",
            "System Volume Information", ".Spotlight-V100", "$RECYCLE.BIN", "desktop.INI", "x.crdownload", "y.Partial", "",
        ]
        for rule in ArtifactRules.patterns {
            switch rule {
            case .exact(let value): result += [value, value.uppercased(), value + "x"]
            case .prefix(let value): result += [value + "Rest", value.uppercased() + "z", "z" + value]
            case .suffix(let value): result += ["Datei" + value, "Datei" + value.uppercased(), value + "z"]
            }
        }
        return result
    }

    @Test func newMatcherEqualsTheOldPathForAllSettings() {
        var checked = 0
        for hidden in [false, true] {
            for artifacts in [false, true] {
                for patterns in [[], Self.userPatterns] {
                    let matcher = IgnoreMatcher(ignoreHiddenFiles: hidden, excludedPatterns: patterns, artifactsIgnored: artifacts)
                    for name in Self.names {
                        for isHidden in [false, true] {
                            let expected = referenceSkip(matcher, name: name, isHidden: isHidden)
                            let actual = matcher.shouldSkip(name: name, isHidden: isHidden, parentPath: ["a", "b"])
                            #expect(actual == expected, "\(name) hidden=\(hidden) artefakte=\(artifacts) muster=\(patterns.count)")
                            checked += 1
                        }
                    }
                }
            }
        }
        #expect(checked > 1_000)
    }

    @Test func artifactRulesEqualTheOldPatternList() {
        for name in Self.names {
            #expect(ArtifactRules.matches(name) == ArtifactRules.patterns.contains { $0.matches(name) }, "\(name)")
        }
    }

    @Test func changedPatternsAreParsedAgain() {
        var matcher = IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: ["*.mov"], artifactsIgnored: false)
        #expect(matcher.shouldSkip(name: "a.MOV", isHidden: false))
        matcher.excludedPatterns = ["*.jpg"]
        #expect(!matcher.shouldSkip(name: "a.MOV", isHidden: false))
        #expect(matcher.shouldSkip(name: "b.JPG", isHidden: false))
        #expect(matcher == IgnoreMatcher(ignoreHiddenFiles: false, excludedPatterns: ["*.jpg"], artifactsIgnored: false))
    }
}
