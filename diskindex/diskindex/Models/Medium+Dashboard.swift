//
//  Medium+Dashboard.swift
//  diskindex
//

import Foundation

extension Medium {
    var dashboardSpecLine: String {
        // bug.0.4.200 (a): bei Lücke die normale Zeile wie Online.
        if indexStatus == .error, !hasIndexGaps {
            return LayoutCopy.mediumNoAccess
        }
        if indexStatus == .pending, fileCount == 0 {
            return "\(type.displayName) · \(totalCapacityLabel) · \(LayoutCopy.mediumNotIndexedYet)"
        }
        return specLine
    }

    /// Dashboard-Karte: „Fehler · erneut versuchen“ statt der Belegung; bug.0.4.200 (a): bei Lücke die Belegung wie Online
    /// (nur der Chip sagt „Fehler“).
    var dashboardShowsRetryLine: Bool {
        indexStatus == .error && !hasIndexGaps
    }

    /// Dashboard-Karte: Zeile „Zuletzt indiziert“ (aus `MediumDashboardCard`, bug.0.4.200 testbar).
    var showsLastIndexedLine: Bool {
        connectionStatus == .connected && showsIndexDetails && hasIndex
    }

    /// bug.0.4.200 (a): Belegung und „Zuletzt indiziert“ wie bei Online – indiziert, im Lauf oder Fehler wegen Lücke.
    private var showsIndexDetails: Bool {
        indexStatus == .indexing || hasCompleteIndexExceptGaps
    }

    /// Menüleiste, zweite Zeile einer Medium-Zeile (aus `MenuBarConnectedMediumRow`, bug.0.4.200 testbar).
    var menuBarSecondaryLine: String {
        switch indexStatus {
        case .indexed:
            IndexedDateFormatting.lastIndexedLine(date: lastIndexActivityAt ?? lastIndexedAt)
        case .error:
            hasIndexGaps
                ? IndexedDateFormatting.lastIndexedLine(date: lastIndexActivityAt ?? lastIndexedAt)
                : LayoutCopy.mediumNoAccess
        case .pending:
            if decision == .undecided {
                LayoutCopy.mediumDecisionPending
            } else {
                LayoutCopy.indexingInProgress
            }
        case .indexing:
            ""
        }
    }

    /// Belegung als „87 %“ oder „3,77 TB / 4,1 TB“ — nur bei angeschlossenen, indizierten Medien.
    func occupancyLabel(showAbsolute: Bool) -> String? {
        guard connectionStatus == .connected, showsIndexDetails else {
            return nil
        }
        if showAbsolute {
            return "\(ByteCountFormatter.storage.string(fromByteCount: capacityUsedBytes)) / \(totalCapacityLabel)"
        }
        return "\(Int(capacityUsedPercent.rounded())) %"
    }

    func lastSeenDescription(now: Date = .now, language: AppDisplayLanguage? = nil) -> String {
        if connectionStatus == .connected {
            return L10n.string("copy.dashboard.last_seen.now", language: language)
        }
        guard let lastSeenAt else {
            return L10n.string("copy.dashboard.last_seen.unknown", language: language)
        }

        let calendar = Calendar.current
        let locale = L10n.locale(for: language)
        let time = lastSeenAt.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)
        )

        if calendar.isDateInToday(lastSeenAt) {
            return L10n.format("copy.dashboard.last_seen.today", time, language: language)
        }
        if calendar.isDateInYesterday(lastSeenAt) {
            return L10n.format("copy.dashboard.last_seen.yesterday", time, language: language)
        }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastSeenAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        if days >= 2 {
            return L10n.format("copy.dashboard.last_seen.days_ago", days, language: language)
        }
        return lastSeenAt.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        )
    }
}
