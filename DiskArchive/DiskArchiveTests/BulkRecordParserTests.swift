//
//  BulkRecordParserTests.swift
//  DiskArchiveTests
//
//  bug.0.4.055 (REPORT 96): `getattrlistbulk` mit `FSOPT_PACK_INVAL_ATTRS` packt jedes angeforderte Attribut,
//  auch ungültige. Der Parser rückt den Offset immer um die Attributgröße vor und übernimmt den Wert nur bei
//  gesetztem Bit. Prüfung mit synthetischen Puffern und gegen `stat` auf einer echten Platte.
//

import Darwin
import Foundation
import Testing
@testable import DiskArchive

/// Baut einen Datensatz wie `getattrlistbulk` (Reihenfolge der Attribute = Reihenfolge der Bits, man getattrlist).
private struct BulkRecordBuilder {
    var name = "datei.bin"
    var objType: UInt32 = 1 // VREG
    var modSeconds: Int64 = 1_700_000_000
    var modNanoseconds: Int64 = 500_000_000
    var fileID: UInt64 = 4_242
    var linkCount: UInt32 = 1
    var dataLength: UInt64 = 123_456
    /// Gesetzte Bits in `ATTR_CMN_RETURNED_ATTRS` (gepackt werden immer alle angeforderten Attribute).
    var commonValid: UInt32 = UInt32(bitPattern: ATTR_CMN_NAME) | UInt32(bitPattern: ATTR_CMN_OBJTYPE)
        | UInt32(bitPattern: ATTR_CMN_MODTIME) | UInt32(bitPattern: ATTR_CMN_FILEID)
    var fileValid: UInt32 = UInt32(bitPattern: ATTR_FILE_LINKCOUNT) | UInt32(bitPattern: ATTR_FILE_DATALENGTH)
    var fullMetadata = true
    /// Ordner kommen ohne Dateiattribute: `fileReturned` 0, kein LINKCOUNT/DATALENGTH im Datensatz.
    var includeFileAttributes = true

    func bytes() -> [UInt8] {
        var out: [UInt8] = []
        func put<T>(_ value: T) {
            withUnsafeBytes(of: value) { out.append(contentsOf: $0) }
        }
        put(UInt32(0)) // Länge, unten gesetzt
        put(commonValid | UInt32(ATTR_CMN_RETURNED_ATTRS))
        put(UInt32(0)) // vol
        put(UInt32(0)) // dir
        put(fullMetadata && includeFileAttributes ? fileValid : UInt32(0))
        put(UInt32(0)) // fork
        let nameRefOffset = out.count
        put(Int32(0)) // attr_dataoffset, unten gesetzt
        put(UInt32(name.utf8.count + 1))
        put(objType)
        if fullMetadata {
            put(modSeconds)
            put(modNanoseconds)
            put(fileID)
            if includeFileAttributes {
                put(linkCount)
                put(dataLength)
            }
        }
        let nameStart = out.count
        out.append(contentsOf: Array(name.utf8))
        out.append(0)
        while out.count % 4 != 0 { out.append(0) }
        let dataOffset = Int32(nameStart - nameRefOffset)
        withUnsafeBytes(of: dataOffset) { raw in
            for (index, byte) in raw.enumerated() { out[nameRefOffset + index] = byte }
        }
        let length = UInt32(out.count)
        withUnsafeBytes(of: length) { raw in
            for (index, byte) in raw.enumerated() { out[index] = byte }
        }
        return out
    }
}

@Suite struct BulkRecordParserTests {
    private let directory = URL(fileURLWithPath: "/nonexistent-diskarchive-bulk", isDirectory: true)

    private func parse(_ builder: BulkRecordBuilder) -> ListedDirectoryEntry? {
        let bytes = builder.bytes()
        return bytes.withUnsafeBytes { raw in
            BulkDirectoryReader.parseBulkRecord(raw, directoryURL: directory, mode: builder.fullMetadata ? .fullMetadata : .nameAndTypeOnly)
        }
    }

    @Test func allAttributesValid() throws {
        let entry = try #require(parse(BulkRecordBuilder()))
        #expect(entry.name == "datei.bin")
        #expect(entry.isDirectory == false)
        #expect(entry.fileSize == 123_456)
        #expect(entry.fileID == 4_242)
        #expect(entry.linkCount == 1)
        let modified = try #require(entry.modifiedAt)
        #expect(abs(modified.timeIntervalSince1970 - 1_700_000_000.5) < 0.001)
    }

    /// Kein MODTIME (z. B. FUSE/Netz): Platzhalter steht trotzdem im Puffer → fileID und Größe aus ihren eigenen Feldern.
    @Test func invalidModTimeKeepsFollowingFieldsInPlace() throws {
        var builder = BulkRecordBuilder()
        builder.commonValid &= ~UInt32(bitPattern: ATTR_CMN_MODTIME)
        builder.modSeconds = 0
        builder.modNanoseconds = 0
        let entry = try #require(parse(builder))
        #expect(entry.modifiedAt == nil)
        #expect(entry.fileID == 4_242)
        #expect(entry.fileSize == 123_456)
        #expect(entry.linkCount == 1)
    }

    @Test func invalidFileIDAndLinkCountKeepSizeInPlace() throws {
        var builder = BulkRecordBuilder()
        builder.commonValid &= ~UInt32(bitPattern: ATTR_CMN_FILEID)
        builder.fileValid &= ~UInt32(bitPattern: ATTR_FILE_LINKCOUNT)
        builder.linkCount = 0
        builder.fileID = 0
        let entry = try #require(parse(builder))
        #expect(entry.fileID == nil)
        #expect(entry.linkCount == nil)
        #expect(entry.fileSize == 123_456)
        #expect(entry.modifiedAt != nil)
    }

    @Test func linkCountAndSizeAreDistinctFields() throws {
        var builder = BulkRecordBuilder()
        builder.linkCount = 3
        builder.dataLength = 7
        let entry = try #require(parse(builder))
        #expect(entry.linkCount == 3)
        #expect(entry.fileSize == 7)
    }

    @Test func nameAndTypeOnlyRecord() throws {
        var builder = BulkRecordBuilder()
        builder.fullMetadata = false
        builder.objType = 2 // VDIR
        builder.name = "ordner"
        let entry = try #require(parse(builder))
        #expect(entry.name == "ordner")
        #expect(entry.isDirectory)
        #expect(entry.fileSize == nil)
    }

    @Test func folderRecordWithoutFileAttributes() throws {
        var builder = BulkRecordBuilder()
        builder.objType = VDIR.rawValue
        builder.name = "ordner"
        builder.includeFileAttributes = false
        let short = builder.bytes().count
        #expect(short < BulkRecordBuilder().bytes().count)
        let entry = try #require(parse(builder))
        #expect(entry.name == "ordner")
        #expect(entry.isDirectory)
        #expect(entry.fileSize == nil)
        #expect(entry.linkCount == nil)
        #expect(entry.fileID == 4_242)
        #expect(entry.modifiedAt != nil)
    }

    @Test func symlinkRecordIsASymbolicLink() throws {
        var builder = BulkRecordBuilder()
        builder.objType = VLNK.rawValue
        builder.name = "verweis"
        let entry = try #require(parse(builder))
        #expect(entry.isSymbolicLink)
        #expect(entry.isDirectory == false)
        #expect(entry.fileID == nil)
        #expect(entry.fileSize == nil)
    }

    @Test func truncatedRecordIsRejected() {
        let bytes = Array(BulkRecordBuilder().bytes().prefix(30))
        let entry = bytes.withUnsafeBytes { raw in
            BulkDirectoryReader.parseBulkRecord(raw, directoryURL: directory, mode: .fullMetadata)
        }
        #expect(entry == nil)
    }

    /// Echte Platte: Größe, Linkzahl, fileID und Änderungszeit wie `stat`.
    @Test func realDirectoryMatchesStat() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskarchive-bulkparse-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("a.bin")
        try Data(repeating: 7, count: 12_345).write(to: file)
        try FileManager.default.linkItem(at: file, to: root.appendingPathComponent("b.bin"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("sub"), withIntermediateDirectories: false)
        let linkToFile = root.appendingPathComponent("link-a")
        let linkToFolder = root.appendingPathComponent("link-sub")
        try FileManager.default.createSymbolicLink(atPath: linkToFile.path, withDestinationPath: "a.bin")
        try FileManager.default.createSymbolicLink(atPath: linkToFolder.path, withDestinationPath: "sub")

        let entries = try await Task.detached { try BulkDirectoryReader.readEntries(at: root) }.value
        let a = try #require(entries.first { $0.name == "a.bin" })
        var info = stat()
        #expect(stat(file.path, &info) == 0)
        #expect(a.fileSize == 12_345)
        #expect(a.linkCount == 2)
        #expect(a.fileID == Int64(info.st_ino))
        let modified = try #require(a.modifiedAt)
        #expect(abs(modified.timeIntervalSince1970 - TimeInterval(info.st_mtimespec.tv_sec)) < 1)
        let sub = try #require(entries.first { $0.name == "sub" })
        #expect(sub.isDirectory)
        #expect(sub.fileSize == nil)
        for link in [linkToFile, linkToFolder] {
            let entry = try #require(entries.first { $0.name == link.lastPathComponent })
            // Wie der FileManager-Weg (Dateityp des Eintrags selbst, ohne dem Verweis zu folgen).
            let type = try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType
            #expect(type == .typeSymbolicLink)
            #expect(entry.isSymbolicLink, "\(link.lastPathComponent)")
            #expect(entry.isDirectory == false)
            #expect(entry.fileID == nil)
            #expect(entry.fileSize == nil)
        }
    }

    /// bug.0.4.068 d): `loadUnaligned` liest nur innerhalb des Puffers. Der Puffer ist der Anfang eines größeren
    /// Arrays, damit ein Lesen über das Ende (Sabotage) gültigen Speicher trifft und nur der Rückgabewert zählt.
    @Test func loadUnalignedRejectsReadsPastTheBufferEnd() {
        let backing: [UInt8] = Array(1...16)
        backing.withUnsafeBytes { whole in
            let raw = UnsafeRawBufferPointer(rebasing: whole[0..<6])
            #expect(BulkDirectoryReader.loadUnaligned(UInt32.self, from: raw, at: 0) == UInt32(littleEndian: 0x0403_0201))
            #expect(BulkDirectoryReader.loadUnaligned(UInt32.self, from: raw, at: 2) == UInt32(littleEndian: 0x0605_0403))
            #expect(BulkDirectoryReader.loadUnaligned(UInt32.self, from: raw, at: 3) == nil)
            #expect(BulkDirectoryReader.loadUnaligned(UInt32.self, from: raw, at: 6) == nil)
            #expect(BulkDirectoryReader.loadUnaligned(UInt32.self, from: raw, at: -1) == nil)
            #expect(BulkDirectoryReader.loadUnaligned(UInt64.self, from: raw, at: 0) == nil)
        }
        let empty = UnsafeRawBufferPointer(start: nil, count: 0)
        #expect(BulkDirectoryReader.loadUnaligned(UInt32.self, from: empty, at: 0) == nil)
    }
}
