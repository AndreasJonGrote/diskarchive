//
//  Medium+Detail.swift
//  DiskArchive
//

import Foundation

extension Medium {
    var freeBytes: Int64 {
        max(0, capacityTotalBytes - capacityUsedBytes)
    }

    var connectionDescription: String {
        let connection = connectionStatus == .connected ? "extern angeschlossen" : "offline"
        return "\(type.displayName) · \(connection)"
    }

    var totalCapacityLabel: String {
        ByteCountFormatter.storage.string(fromByteCount: capacityTotalBytes)
    }

    var usedFreeLabel: String {
        let used = ByteCountFormatter.storage.string(fromByteCount: capacityUsedBytes)
        let free = ByteCountFormatter.storage.string(fromByteCount: freeBytes)
        return "\(used) / \(free) · \(Int(capacityUsedPercent.rounded()))%"
    }

    /// Spaltenansicht-Fußzeile: „1,3 TB frei von 2 TB“.
    var freeOfTotalLabel: String {
        LayoutCopy.mediumFreeOfTotal(ByteCountFormatter.storage.string(fromByteCount: freeBytes), totalCapacityLabel)
    }

    /// bug.0.4.199: Fortschritt wie im Chip (`indexProgressPercent`): vollständig 100 %, mit Lücke z. B. 99 %.
    var indexedLabel: String {
        LayoutCopy.detailIndexedValue(indexProgressPercent)
    }

    var filesLabel: String {
        DisplayNumberFormat.groupedInteger(fileCount)
    }

    var foldersLabel: String {
        DisplayNumberFormat.groupedInteger(folderCount)
    }
}
