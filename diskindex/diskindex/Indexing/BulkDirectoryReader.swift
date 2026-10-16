//
//  BulkDirectoryReader.swift
//  diskindex
//
//  Verzeichnislesen mit getattrlistbulk (Aufgabe 103), Fallback FileManager.
//

import Darwin
import Foundation

nonisolated enum BulkDirectoryReadMode: Sendable {
    /// Name, Typ, Größe, Änderungsdatum (Indizierung).
    case fullMetadata
    /// Nur Name und Objekttyp (Zählphase).
    case nameAndTypeOnly
}

nonisolated struct BulkDirectoryReadStats: Sendable, Equatable {
    var usedBulk = false
    var usedFallback = false
    var fallbackReason: String?
}

nonisolated struct BulkDirectoryReadResult: Sendable, Equatable {
    var entries: [ListedDirectoryEntry]
    var stats: BulkDirectoryReadStats
}

nonisolated enum BulkDirectoryReader {
    private static let bufferSize = 256 * 1024
    private static let returnedSetByteCount = 20
    private static let readLogLock = NSLock()
    private static var readLogBulk = 0
    private static var readLogFallback = 0
    private static var readLogLastFallbackReason: String?
    private static let readLogBatchSize = 200

    #if DEBUG
    static var readLogEmitCountForTesting = 0

    static func resetReadLogEmitCountForTesting() {
        readLogEmitCountForTesting = 0
    }
    #endif

    static func flushReadLogSummary(force: Bool = false) {
        readLogLock.lock()
        let bulk = readLogBulk
        let fallback = readLogFallback
        let reason = readLogLastFallbackReason
        let total = bulk + fallback
        guard force || total >= readLogBatchSize else {
            readLogLock.unlock()
            return
        }
        readLogBulk = 0
        readLogFallback = 0
        readLogLastFallbackReason = nil
        readLogLock.unlock()
        guard total > 0 else { return }
        #if DEBUG
        readLogEmitCountForTesting += 1
        #endif
        DiskIndexLog.shared.record(.index, .info, "lesen bulk=\(bulk) fallback=\(fallback)\(reason.map { " grund=\($0)" } ?? "")")
    }

    private static func noteReadStats(_ stats: BulkDirectoryReadStats) {
        readLogLock.lock()
        if stats.usedBulk { readLogBulk += 1 }
        if stats.usedFallback {
            readLogFallback += 1
            readLogLastFallbackReason = stats.fallbackReason
        }
        readLogLock.unlock()
        flushReadLogSummary()
    }
    static func shouldIgnoreName(_ name: String) -> Bool {
        name.hasPrefix("._")
    }

    static func readEntries(
        at directoryURL: URL,
        mode: BulkDirectoryReadMode = .fullMetadata,
        chunkSize: Int = IndexingRunLimits.standard.directoryChunkSize
    ) throws -> [ListedDirectoryEntry] {
        try readResult(at: directoryURL, mode: mode, chunkSize: chunkSize).entries
    }

    static func readResult(
        at directoryURL: URL,
        mode: BulkDirectoryReadMode = .fullMetadata,
        chunkSize: Int = IndexingRunLimits.standard.directoryChunkSize
    ) throws -> BulkDirectoryReadResult {
        var collected: [ListedDirectoryEntry] = []
        var stats = BulkDirectoryReadStats()
        try readStreaming(at: directoryURL, mode: mode, chunkSize: chunkSize, stats: &stats) { chunk in
            collected.append(contentsOf: chunk)
        }
        flushReadLogSummary(force: true)
        return BulkDirectoryReadResult(entries: collected, stats: stats)
    }

    static func chunkedStream(
        at directoryURL: URL,
        mode: BulkDirectoryReadMode = .fullMetadata,
        chunkSize: Int = IndexingRunLimits.standard.directoryChunkSize,
        isCancelled: @escaping @Sendable () -> Bool = { false }
    ) -> AsyncStream<Result<[ListedDirectoryEntry], Error>> {
        AsyncStream { continuation in
            final class CancelFlag: @unchecked Sendable {
                var value = false
            }
            let cancelled = CancelFlag()
            continuation.onTermination = { @Sendable _ in
                cancelled.value = true
            }
            let checkCancelled = {
                cancelled.value || isCancelled()
            }
            DispatchQueue.global(qos: .utility).async {
                do {
                    var stats = BulkDirectoryReadStats()
                    try readStreaming(
                        at: directoryURL,
                        mode: mode,
                        chunkSize: chunkSize,
                        stats: &stats,
                        isCancelled: checkCancelled
                    ) { chunk in
                        if chunk.isEmpty { return }
                        continuation.yield(.success(chunk))
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(.failure(error))
                    continuation.finish()
                }
            }
        }
    }

    private static func readStreaming(
        at directoryURL: URL,
        mode: BulkDirectoryReadMode,
        chunkSize: Int,
        stats: inout BulkDirectoryReadStats,
        isCancelled: @escaping () -> Bool = { false },
        onChunk: ([ListedDirectoryEntry]) -> Void
    ) throws {
        #if DEBUG
        dispatchPrecondition(condition: .notOnQueue(.main))
        #endif
        defer {
            noteReadStats(stats)
        }

        let path = directoryURL.path
        let fd = open(path, O_RDONLY)
        if fd >= 0 {
            defer { close(fd) }
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            var pending: [ListedDirectoryEntry] = []
            pending.reserveCapacity(chunkSize)
            do {
                try readBulk(fd: fd, directoryURL: directoryURL, mode: mode, buffer: &buffer, isCancelled: isCancelled) { entry in
                    pending.append(entry)
                    if pending.count >= chunkSize {
                        onChunk(pending)
                        pending.removeAll(keepingCapacity: true)
                    }
                }
                stats.usedBulk = true
                if !pending.isEmpty {
                    onChunk(pending)
                }
                return
            } catch BulkReadError.unsupported(let reason) {
                stats.fallbackReason = reason
            }
        } else {
            stats.fallbackReason = "open errno=\(errno)"
        }

        stats.usedFallback = true
        let fallback = try readUsingFileManager(at: directoryURL)
        var start = 0
        while start < fallback.count {
            let end = min(start + chunkSize, fallback.count)
            onChunk(Array(fallback[start..<end]))
            start = end
        }
    }

    private enum BulkReadError: Error {
        case unsupported(String)
    }

    private static func readBulk(
        fd: Int32,
        directoryURL: URL,
        mode: BulkDirectoryReadMode,
        buffer: inout [UInt8],
        isCancelled: @escaping () -> Bool = { false },
        onEntry: (ListedDirectoryEntry) -> Void
    ) throws {
        var attrList = attrlist()
        attrList.bitmapcount = UInt16(ATTR_BIT_MAP_COUNT)
        switch mode {
        case .fullMetadata:
            attrList.commonattr = attrBit(ATTR_CMN_RETURNED_ATTRS) | attrBit(ATTR_CMN_NAME)
                | attrBit(ATTR_CMN_OBJTYPE) | attrBit(ATTR_CMN_FILEID) | attrBit(ATTR_CMN_MODTIME)
            attrList.fileattr = attrBit(ATTR_FILE_DATALENGTH) | attrBit(ATTR_FILE_LINKCOUNT)
        case .nameAndTypeOnly:
            attrList.commonattr = attrBit(ATTR_CMN_RETURNED_ATTRS) | attrBit(ATTR_CMN_NAME) | attrBit(ATTR_CMN_OBJTYPE)
            attrList.fileattr = 0
        }

        while true {
            if isCancelled() {
                throw CancellationError()
            }
            let readCount: Int = buffer.withUnsafeMutableBytes { raw in
                guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
                return Int(getattrlistbulk(
                    fd,
                    &attrList,
                    base,
                    raw.count,
                    UInt64(FSOPT_PACK_INVAL_ATTRS)
                ))
            }
            if readCount < 0 {
                let err = errno
                if err == ENOTSUP || err == ENOSYS {
                    throw BulkReadError.unsupported("errno=\(err)")
                }
                throw POSIXError(POSIXErrorCode(rawValue: err) ?? .EIO)
            }
            if readCount == 0 { break }

            buffer.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                var offset = 0
                for _ in 0..<readCount {
                    guard offset + 4 <= raw.count else { break }
                    guard let recordLengthU32 = loadUnaligned(UInt32.self, from: base, at: offset) else { break }
                    let recordLength = Int(recordLengthU32)
                    guard recordLength >= 4, offset + recordLength <= raw.count else { break }
                    if let entry = parseBulkRecord(
                        base: base.advanced(by: offset),
                        length: recordLength,
                        directoryURL: directoryURL,
                        mode: mode
                    ) {
                        onEntry(entry)
                    }
                    offset += recordLength
                }
            }
        }
    }

    private static func parseBulkRecord(
        base: UnsafeRawPointer,
        length: Int,
        directoryURL: URL,
        mode: BulkDirectoryReadMode
    ) -> ListedDirectoryEntry? {
        guard length >= 4 + returnedSetByteCount else { return nil }
        var offset = 4

        guard
            let commonReturned = loadUnaligned(UInt32.self, from: base, at: offset),
            let volReturned = loadUnaligned(UInt32.self, from: base, at: offset + 4),
            let dirReturned = loadUnaligned(UInt32.self, from: base, at: offset + 8),
            let fileReturned = loadUnaligned(UInt32.self, from: base, at: offset + 12)
        else { return nil }
        _ = loadUnaligned(UInt32.self, from: base, at: offset + 16) // forkattr
        offset += returnedSetByteCount
        _ = volReturned
        _ = dirReturned

        var name: String?
        if commonReturned & attrgroupBit(ATTR_CMN_NAME) != 0 {
            let nameRefOffset = offset
            guard
                let nameRef = loadUnaligned(attrreference.self, from: base, at: nameRefOffset)
            else { return nil }
            offset += MemoryLayout<attrreference>.size
            name = readNameInRecord(
                recordBase: base,
                recordLength: length,
                nameRefFieldOffset: nameRefOffset,
                nameRef: nameRef
            )
        }

        var objType: UInt32 = 0
        if commonReturned & attrgroupBit(ATTR_CMN_OBJTYPE) != 0 {
            guard let raw = loadUnaligned(UInt32.self, from: base, at: offset) else { return nil }
            objType = raw
            offset += MemoryLayout<UInt32>.size
        }

        var modifiedAt: Date?
        if mode == .fullMetadata {
            if commonReturned & attrgroupBit(ATTR_CMN_MODTIME) != 0 {
                guard
                    let sec = loadUnaligned(Int64.self, from: base, at: offset),
                    let nsec = loadUnaligned(Int64.self, from: base, at: offset + 8)
                else { return nil }
                modifiedAt = Date(timeIntervalSince1970: TimeInterval(sec) + TimeInterval(nsec) / 1_000_000_000)
            }
            offset += 16
        }

        var fileID: Int64?
        if mode == .fullMetadata {
            if commonReturned & attrgroupBit(ATTR_CMN_FILEID) != 0 {
                guard let raw = loadUnaligned(UInt64.self, from: base, at: offset) else { return nil }
                fileID = Int64(bitPattern: raw)
            }
            offset += MemoryLayout<UInt64>.size
        }

        var dataLength: UInt64 = 0
        var linkCount: Int?
        if mode == .fullMetadata {
            if fileReturned & attrgroupBit(ATTR_FILE_DATALENGTH) != 0 {
                guard let raw = loadUnaligned(UInt64.self, from: base, at: offset) else { return nil }
                dataLength = raw
            }
            offset += MemoryLayout<UInt64>.size
            if fileReturned & attrgroupBit(ATTR_FILE_LINKCOUNT) != 0 {
                guard let raw = loadUnaligned(UInt32.self, from: base, at: offset) else { return nil }
                linkCount = Int(raw)
            }
            offset += MemoryLayout<UInt32>.size
        }

        guard let name else { return nil }
        if shouldIgnoreName(name) { return nil }

        let isSymlink = objType == 3 // VLNK
        let isDir = objType == 2 // VDIR
        let isHidden = name.hasPrefix(".")
        var isPackage = false
        if isDir && !isSymlink {
            let child = directoryURL.appendingPathComponent(name)
            if let values = try? child.resourceValues(forKeys: [.isPackageKey]) {
                isPackage = values.isPackage == true
            }
        }

        let fileSize: Int64? = isDir || isSymlink ? nil : Int64(dataLength)

        return ListedDirectoryEntry(
            name: name,
            isDirectory: isDir && !isSymlink,
            isPackage: isPackage,
            isSymbolicLink: isSymlink,
            isHidden: isHidden,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            fileID: isSymlink ? nil : fileID,
            linkCount: isSymlink ? nil : linkCount
        )
    }

    private static func readNameInRecord(
        recordBase: UnsafeRawPointer,
        recordLength: Int,
        nameRefFieldOffset: Int,
        nameRef: attrreference
    ) -> String? {
        let nameStart = nameRefFieldOffset + Int(nameRef.attr_dataoffset)
        let nameLen = Int(nameRef.attr_length)
        guard nameLen > 0, nameStart >= 0, nameStart + nameLen <= recordLength else { return nil }
        let bytes = recordBase.advanced(by: nameStart).assumingMemoryBound(to: CChar.self)
        let name = String(cString: bytes)
        if name.isEmpty || name.contains("/") { return nil }
        return name
    }

    private static func attrBit(_ flag: Int32) -> attrgroup_t {
        UInt32(bitPattern: flag)
    }

    private static func attrBit(_ flag: UInt32) -> attrgroup_t {
        flag
    }

    private static func attrgroupBit(_ flag: Int32) -> UInt32 {
        UInt32(bitPattern: flag)
    }

    private static func attrgroupBit(_ flag: UInt32) -> UInt32 {
        flag
    }

    private static func loadUnaligned<T>(_ type: T.Type, from base: UnsafeRawPointer, at offset: Int) -> T? {
        guard offset >= 0, offset + MemoryLayout<T>.size <= Int.max else { return nil }
        return base.advanced(by: offset).loadUnaligned(as: T.self)
    }

    private static func readUsingFileManager(at directoryURL: URL) throws -> [ListedDirectoryEntry] {
        let names = try FileManager.default.contentsOfDirectory(atPath: directoryURL.path)
        var entries: [ListedDirectoryEntry] = []
        entries.reserveCapacity(names.count)
        for name in names {
            if shouldIgnoreName(name) { continue }
            let child = directoryURL.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: child.path, isDirectory: &isDirectory) else { continue }
            var isHidden = name.hasPrefix(".")
            var fileSize: Int64?
            var modifiedAt: Date?
            var isPackage = false
            var isSymlink = false
            var fileID: Int64?
            if isDirectory.boolValue {
                if let values = try? child.resourceValues(forKeys: [.isPackageKey, .isHiddenKey, .contentModificationDateKey, .isSymbolicLinkKey]) {
                    isPackage = values.isPackage == true
                    isSymlink = values.isSymbolicLink == true
                    if values.isHidden == true { isHidden = true }
                    modifiedAt = values.contentModificationDate
                }
            } else if let values = try? child.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isHiddenKey]) {
                fileSize = values.fileSize.map(Int64.init)
                modifiedAt = values.contentModificationDate
                if values.isHidden == true { isHidden = true }
            }
            if !isSymlink {
                var statInfo = stat()
                if stat(child.path, &statInfo) == 0 {
                    fileID = Int64(statInfo.st_ino)
                }
            }
            entries.append(
                ListedDirectoryEntry(
                    name: name,
                    isDirectory: isDirectory.boolValue && !isSymlink,
                    isPackage: isPackage,
                    isSymbolicLink: isSymlink,
                    isHidden: isHidden,
                    fileSize: fileSize,
                    modifiedAt: modifiedAt,
                    fileID: fileID
                )
            )
        }
        return entries
    }
}
