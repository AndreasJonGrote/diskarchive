//
//  RawImageExtensionTests.swift
//  DiskArchiveTests
//
//  bug.0.4.2.001: RAW-Endungen wie `.cr3` zählen als Bild – im Filter (Suche, Favoriten, Spalten) und beim Icon, aus
//  einer gemeinsamen Liste.
//

import Foundation
import Testing
@testable import DiskArchive

struct RawImageExtensionTests {
    @Test func rawFilesAreFilteredAsImagesAndShowTheImageIcon() {
        for name in ["IMG_0001.CR3", "DSCF0001.raf", "DSC00001.arw"] {
            #expect(SearchFileTypeFilter.image.matches(fileName: name, isFolder: false), "\(name) nicht im Bild-Filter")
            #expect(FileKind(fileName: name, isFolder: false) == .image, "\(name) ohne Bild-Icon")
        }
    }

    @Test func filterAndIconUseTheSameLists() {
        for (filter, kind) in [(SearchFileTypeFilter.image, FileKind.image), (.video, .video), (.audio, .audio)] {
            for ext in filter.databaseExtensions {
                #expect(FileKind(fileName: "a.\(ext)", isFolder: false) == kind, ".\(ext) im Filter \(filter), Icon anders")
            }
        }
    }
}
