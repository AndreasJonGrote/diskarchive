//
//  LaunchAtLogin.swift
//  DiskArchive
//
//  „Automatisch bei Systemstart“ (Aufgabe 30.2) als Hintergrundobjekt.
//  `SMAppService.mainApp` landet nur unter „Bei der Anmeldung öffnen“.
//  Der Launch Agent in Contents/Library/LaunchAgents erscheint unter „Im Hintergrund erlauben“.
//  Quelle der Wahrheit ist das System, nicht `AppSettings` — deshalb bei jedem Anzeigen neu lesen.
//

import OSLog
import ServiceManagement

enum LaunchAtLogin {
    nonisolated enum State: Equatable, Sendable {
        case off
        case on
        /// Registriert, aber vom Nutzer in den Systemeinstellungen noch nicht freigegeben.
        case requiresApproval
    }

    /// Dateiname unter `Contents/Library/LaunchAgents/`.
    nonisolated private static let agentPlistName = "app.diskarchive.plist"
    nonisolated private static let logger = Logger(subsystem: "app.diskarchive", category: "LaunchAtLogin")

    nonisolated private static var agent: SMAppService {
        SMAppService.agent(plistName: agentPlistName)
    }

    /// Echte Systemabfrage. Aufrufer gehen über `AppState.launchAtLoginStateProvider`, damit Tests
    /// sie je Instanz ersetzen können (bug.0.3.9.001).
    nonisolated static var state: State {
        switch agent.status {
        case .enabled: .on
        case .requiresApproval: .requiresApproval
        case .notRegistered, .notFound: .off
        @unknown default: .off
        }
    }

    /// An = `.on` oder `.requiresApproval`.
    nonisolated static var isEnabled: Bool {
        state != .off
    }

    /// Echte Systemregistrierung. Aufrufer gehen über `AppState.launchAtLoginRegister`, damit Tests
    /// sie je Instanz ersetzen können (bug.0.3.9.001).
    nonisolated static func setEnabled(_ enabled: Bool) {
        if enabled {
            switch agent.status {
            case .notRegistered, .notFound:
                do {
                    try agent.register()
                } catch {
                    logger.error("Systemstart einschalten fehlgeschlagen: \(DiskArchiveLog.errorSummary(error), privacy: .public)")
                }
            case .enabled, .requiresApproval:
                break
            @unknown default:
                break
            }
        } else if agent.status == .enabled || agent.status == .requiresApproval {
            do {
                try agent.unregister()
            } catch {
                logger.error("Systemstart ausschalten fehlgeschlagen: \(DiskArchiveLog.errorSummary(error), privacy: .public)")
            }
        }
    }

    nonisolated static func logMismatch(requested: Bool, actual: State) {
        logger.error("Systemstart weicht ab: angefordert=\(requested, privacy: .public) system=\(String(describing: actual), privacy: .public)")
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
