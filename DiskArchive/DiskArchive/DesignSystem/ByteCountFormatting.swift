//
//  ByteCountFormatting.swift
//  DiskArchive
//

import Foundation

extension ByteCountFormatter {
    /// Dateigrößen nach App-Sprache (bug.0.4.058): `ByteCountFormatter` kennt keine `locale`,
    /// deshalb ein Format-Stil mit `L10n.locale()`; der Aufruf `storage.string(fromByteCount:)` bleibt.
    nonisolated static var storage: StorageByteCountFormat { StorageByteCountFormat(locale: L10n.locale()) }
}

nonisolated struct StorageByteCountFormat {
    let locale: Locale

    /// bug.0.4.067: wie im Finder – unter 1.000 Byte die Bytes („999 Byte“ / „999 bytes“),
    /// Null als Ziffer („0 Byte“ / „0 bytes“), darüber das Datei-Format („1,5 GB“, „kB“ klein).
    func string(fromByteCount count: Int64) -> String {
        if count.magnitude < 1_000 {
            return count.formatted(.byteCount(style: .file, allowedUnits: .bytes, spellsOutZero: false).locale(locale))
        }
        return count.formatted(.byteCount(style: .file, spellsOutZero: false).locale(locale))
    }
}
