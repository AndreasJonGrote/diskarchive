//
//  ByteCountFormatting.swift
//  diskindex
//

import Foundation

extension ByteCountFormatter {
    /// Dateigrößen nach App-Sprache (bug.0.4.058): `ByteCountFormatter` kennt keine `locale`,
    /// deshalb ein Format-Stil mit `L10n.locale()`; der Aufruf `storage.string(fromByteCount:)` bleibt.
    nonisolated static var storage: StorageByteCountFormat { StorageByteCountFormat(locale: L10n.locale()) }
}

nonisolated struct StorageByteCountFormat {
    let locale: Locale

    func string(fromByteCount count: Int64) -> String {
        count.formatted(.byteCount(style: .file).locale(locale))
    }
}
