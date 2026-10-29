//
//  MediumTypeTests.swift
//  diskindexTests
//
//  bug.0.4.230 (Konzept `medien.md` 2c): Externe SSDs erschienen als „HDD“, weil der Typ nur „wechselbar = USB, sonst
//  HDD“ kannte. Wechselbar bleibt USB; sonst entscheidet die IOKit-Angabe „Medium Type“ (Solid State = SSD).
//

import Foundation
import Testing
@testable import diskindex

@Suite
struct MediumTypeTests {
    /// Test 1: reine Regel, ohne Platte.
    @Test func ruleUsesRemovableFirstThenTheDeviceMedium() {
        #expect(VolumeInfo.mediumType(isRemovable: true, deviceMedium: .solidState) == .usb, "Karte/Stick mit Solid State nicht USB")
        #expect(VolumeInfo.mediumType(isRemovable: true, deviceMedium: nil) == .usb, "Karte ohne Angabe nicht USB")
        #expect(VolumeInfo.mediumType(isRemovable: false, deviceMedium: .solidState) == .ssd, "feste SSD nicht SSD")
        #expect(VolumeInfo.mediumType(isRemovable: false, deviceMedium: .rotational) == .hdd, "Festplatte nicht HDD")
        #expect(VolumeInfo.mediumType(isRemovable: false, deviceMedium: nil) == .hdd, "ohne Angabe nicht HDD")
    }

    /// Test 2: echte Abfrage für das Startvolume (APFS, Angabe liegt über Container und Partition). Übersprungen, wenn
    /// `diskutil` für `/` nicht „Solid State“ meldet – nie grün ohne Beleg.
    @Test(.enabled(if: Self.diskutilReportsSolidState(path: "/"), "diskutil meldet für / kein Solid State"))
    func bootVolumeIsSolidStateViaIOKit() {
        let disk = DiskArbitrationLookup.attributes(path: "/")
        #expect(disk.deviceMedium == .solidState, "IOKit-Abfrage für / ergab \(String(describing: disk.deviceMedium))")
    }

    /// Unabhängige Gegenquelle für die Voraussetzung von Test 2 (nicht die geprüfte IOKit-Suche).
    static func diskutilReportsSolidState(path: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "-plist", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return false }
        return plist["SolidState"] as? Bool ?? false
    }
}
