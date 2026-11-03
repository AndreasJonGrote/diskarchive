//
//  Medium+Detail.swift
//  DiskArchive
//

import Foundation

extension Medium {
    var freeBytes: Int64 {
        max(0, capacityTotalBytes - capacityUsedBytes)
    }

    var totalCapacityLabel: String {
        ByteCountFormatter.storage.string(fromByteCount: capacityTotalBytes)
    }

    /// todo.0.4.3.010: Kennzahl-Flächen „Belegt“ und „Frei“ (Layout 06.01).
    var usedLabel: String {
        ByteCountFormatter.storage.string(fromByteCount: capacityUsedBytes)
    }

    var freeLabel: String {
        ByteCountFormatter.storage.string(fromByteCount: freeBytes)
    }

    /// todo.0.4.3.010: Fläche „Zuletzt indiziert“ – „heute, 18:42“, „gestern, 18:42“, sonst das Datum; nie indiziert „—“.
    var lastIndexedValue: String {
        guard let date = lastIndexActivityAt ?? lastIndexedAt else { return "—" }
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.locale()))
        if Calendar.current.isDateInToday(date) {
            return L10n.format("copy.dashboard.last_seen.today", time)
        }
        if Calendar.current.isDateInYesterday(date) {
            return L10n.format("copy.dashboard.last_seen.yesterday", time)
        }
        return IndexedDateFormatting.abbreviatedDay(date)
    }

    /// todo.0.4.3.010 (Layout 06.03): Fehlergrund unter dem Balken „Indiziert“, solange der Status „Fehler“ ist; bei
    /// unbekanntem Grund keiner.
    var detailFailureLine: String? {
        guard indexStatus == .error else { return nil }
        return failureReason?.line
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
