//
//  Medium+Dashboard.swift
//  DiskArchive
//

import Foundation

extension Medium {
    /// todo.0.4.3.008: „{Kapazität} · {n} Dateien“ in jedem Zustand (ohne Typ; bug.0.4.3.002: „Kein Zugriff …“ entfällt).
    var dashboardSpecLine: String {
        specLine
    }

    /// Dashboard-Karte, unterste Zeile (Layout 04): bei Fehler ohne Lücke an einem angeschlossenen Medium
    /// „Fehler · erneut versuchen“ (Link); sonst „Zuletzt gesehen“ und bei angeschlossenen Medien die Belegung.
    /// bug.0.4.200 (a): bei Lücke wie Online. „Fehler, offline“ hat keinen Link.
    var dashboardMetaLine: DashboardMetaLine {
        if indexStatus == .error, !hasIndexGaps, connectionStatus == .connected {
            return .retry
        }
        return .lastSeen(occupancy: occupancyLabel(showAbsolute: showAbsoluteCapacity))
    }

    /// bug.0.4.200 (a): Belegung und „Zuletzt indiziert“ wie bei Online – indiziert, im Lauf oder Fehler wegen Lücke.
    private var showsIndexDetails: Bool {
        indexStatus == .indexing || hasCompleteIndexExceptGaps
    }

    /// todo.0.4.3.013 (Layout 00, 03, 04): „Wird geprüft“ – angeschlossen, „Indizieren“ entschieden, und entweder ein
    /// neues Medium wartet auf den Start (`paused` = es startet keiner) oder der Lauf zählt noch ohne Prozentangabe.
    /// Ein gespeichertes „wird indiziert“ ohne laufenden Lauf setzt der Coordinator auf `.awaitingRun` – so zeigt das
    /// Wiedererkennen nie einen alten Prozentwert (kein Sprung auf 99 %).
    func isChecking(paused: Bool) -> Bool {
        // In der Pause startet bzw. zählt keiner: dort Pause-Icon und Prozent wie bisher.
        guard connectionStatus == .connected, decision == .index, !paused, !autoIndexPaused else { return false }
        if indexStatus == .indexing {
            return indexRunPhase == .awaitingRun || (indexRunPhase == .counting && indexingProgress == 0)
        }
        return indexStatus == .pending && !hasIndex
    }

    /// Menüleiste, zweite Zeile einer Medium-Zeile (Layout 03). `hasProgress` = ein Lauf zeigt Fortschritt.
    func popoverStatusLine(paused: Bool, hasProgress: Bool) -> PopoverStatusLine {
        if isChecking(paused: paused) { return .checking }
        if hasProgress { return .progress }
        switch indexStatus {
        case .indexed:
            return .lastIndexed(lastIndexedValue)
        case .error:
            // bug.0.4.3.002: statt „Kein Zugriff …“ der rote Punkt mit „Speichermedium fehlerhaft“.
            return hasIndexGaps ? .lastIndexed(lastIndexedValue) : .hasErrors
        case .pending:
            return decision == .undecided ? .decisionPending : .text(LayoutCopy.indexingInProgress)
        case .indexing:
            return .progress
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
        // todo.0.4.3.023 (Datumsregel, Layout 03/04): ab zwei vollen Monaten „vor {1} Monaten“ („vor 34 Tagen“ bleibt
        // Tage; „vor 1 Monat“ gibt es in 20 nicht), sonst ab 2 Tagen „vor {1} Tagen“.
        let months = calendar.dateComponents(
            [.month],
            from: calendar.startOfDay(for: lastSeenAt),
            to: calendar.startOfDay(for: now)
        ).month ?? 0
        if months >= 2 {
            return L10n.format("copy.dashboard.last_seen.months_ago", months, language: language)
        }
        if days >= 2 {
            return L10n.format("copy.dashboard.last_seen.days_ago", days, language: language)
        }
        return lastSeenAt.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        )
    }
}

/// todo.0.4.3.008: unterste Zeile der Kachel.
enum DashboardMetaLine: Equatable {
    case retry
    case lastSeen(occupancy: String?)
}

/// todo.0.4.3.013/014 (Layout 03): zweite Zeile einer Medium-Zeile im Popover.
enum PopoverStatusLine: Equatable {
    /// Balken; rechts Spinner (Pause-Icon) und Prozent.
    case progress
    /// Pulsierender Punkt: grün „Speichermedium wird geprüft“.
    case checking
    /// Pulsierender Punkt: gelb „Entscheidung ausstehend“; Klick öffnet den Erkennungs-Dialog dieses Mediums.
    case decisionPending
    /// Pulsierender Punkt: rot „Speichermedium fehlerhaft“.
    case hasErrors
    /// Uhr-Icon und Datum („heute, 09:14“).
    case lastIndexed(String)
    case text(String)
}
