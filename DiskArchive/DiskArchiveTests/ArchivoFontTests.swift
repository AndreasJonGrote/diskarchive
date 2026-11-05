//
//  ArchivoFontTests.swift
//  DiskArchiveTests
//
//  todo.0.4.3.019 (Nutzer 03.11., Layout 19): Archivo liegt im Bundle, ist registriert (Gewicht 800) und wird an den Titeln
//  von Kacheln, Details-Fenster und Dialogen verwendet; die Lizenz liegt bei.
//

import AppKit
import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct ArchivoFontTests {
    @Test func archivoIsBundledAndRegisteredWithWeight800() throws {
        #expect(Bundle.main.url(forResource: "OFL", withExtension: "txt") != nil, "Lizenz fehlt im Bundle")
        #expect(Bundle.main.url(forResource: DesignFont.fileName, withExtension: "ttf") != nil, "Schrift fehlt im Bundle")
        #expect(DesignFont.registerBundledFonts(), "Archivo nicht registriert")
        let font = try #require(DesignFont.headingNSFont(size: 17))
        #expect(font.familyName == "Archivo")
        let traits = font.fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any]
        let weight = try #require(traits?[.weight] as? Double)
        // NSFont-Gewicht für 800 (ExtraBold) liegt über „bold“ (0,4).
        #expect(weight > 0.45, "Gewicht \(weight)")
    }

    /// Titel von Kacheln (17 pt), Details-Fenster (17 pt) und Dialogen (16 pt) nutzen `DesignFont.heading`.
    @Test func titlesUseTheHeadingFont() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("DiskArchive")
        let files = [
            "Views/Dashboard/MediumDashboardCard.swift", "Views/Detail/MediumDetailModalView.swift",
            "Views/CrashReportDialog.swift", "Views/Registry/UpdateAvailableDialog.swift",
            "Views/Registry/ReplaceMediumDialog.swift",
            "Views/Registry/UnexpectedErrorDialog.swift", "Views/Registry/IndexingFailureDialog.swift",
            "Views/Registry/NewMediumDetectedDialog.swift",
        ]
        for file in files {
            let source = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            #expect(source.contains("DesignFont.heading(size:"), "\(file): Titel ohne Archivo")
            #expect(!source.contains("size: 16, weight: .bold") && !source.contains("size: 17, weight: .bold"), "\(file): System-Fett")
        }
    }
}
