//
//  AppStateStore.swift
//  DiskArchive
//
//  bug.0.4.208: kleiner App-Zustand (Konzept „Speicherung“): globale Pause, Zähler der Fehler-Modals, „Mitteilungen
//  erfragt“, letzte Integritätsprüfung, Termin des Aufräumens, Anzeigesprache. Statt `UserDefaults`.
//

import Foundation

/// `~/Library/Application Support/Disk Archive/` – der eine Ordner der App (Datenbank, App-Zustand, Protokoll, Outbox).
nonisolated enum AppDataFolder {
    static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Disk Archive", isDirectory: true)
    }
}

/// App: die Datei `app-state.plist` im Datenordner, synchron gelesen (die Sprache wird vor der Datenbank gebraucht) und
/// bei jeder Änderung atomar geschrieben (Rechte 600, nur über `WriteGuard`). Tests: im Speicher, je Instanz.
nonisolated final class AppStateStore: @unchecked Sendable {
    static let fileName = "app-state.plist"

    /// Der Speicher des Prozesses; unter Tests im Speicher (nie die Datei des Nutzers).
    static let current: AppStateStore = RuntimeEnvironment.isRunningTests
        ? AppStateStore()
        : AppStateStore(fileURL: AppDataFolder.url.appendingPathComponent(fileName, isDirectory: false))

    private let lock = NSLock()
    private var values: [String: Any]
    /// `nil`: im Speicher (Tests).
    let fileURL: URL?
    /// Lesefehler der Datei, gemeldet erst nach dem Start des Protokolls (`reportReadFailure`): Eine Zeile davor sähe
    /// beim Start wie ein unsauberes Ende des letzten Laufs aus.
    private(set) var readFailure: String?

    /// Im Speicher.
    init() {
        values = [:]
        fileURL = nil
    }

    /// Datei; fehlt sie, ist der Zustand leer. Ist sie nicht lesbar: leerer Zustand und Protokollzeile, kein Absturz.
    init(fileURL: URL) {
        self.fileURL = fileURL
        (values, readFailure) = Self.read(fileURL)
    }

    func reportReadFailure(to log: DiskArchiveLog = .shared) {
        lock.lock()
        let failure = readFailure
        readFailure = nil
        lock.unlock()
        guard let failure else { return }
        log.record(.app, .error, "app-zustand nicht lesbar \(failure)")
    }

    func data(forKey key: String) -> Data? { value(key) as? Data }
    func bool(forKey key: String) -> Bool { value(key) as? Bool ?? false }
    func date(forKey key: String) -> Date? { value(key) as? Date }
    func string(forKey key: String) -> String? { value(key) as? String }

    func set(_ value: Data, forKey key: String) { store(value, key) }
    func set(_ value: Bool, forKey key: String) { store(value, key) }
    func set(_ value: Date, forKey key: String) { store(value, key) }
    func set(_ value: String, forKey key: String) { store(value, key) }

    func remove(forKey key: String) { store(nil, key) }

    private func value(_ key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    private func store(_ value: Any?, _ key: String) {
        lock.lock()
        defer { lock.unlock() }
        if let value {
            values[key] = value
        } else {
            guard values.removeValue(forKey: key) != nil else { return }
        }
        guard let fileURL else { return }
        Self.write(values, to: fileURL)
    }

    private static func read(_ url: URL) -> ([String: Any], failure: String?) {
        guard FileManager.default.fileExists(atPath: url.path) else { return ([:], nil) }
        do {
            let data = try Data(contentsOf: url)
            guard let dictionary = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                return ([:], "kein wörterbuch")
            }
            return (dictionary, nil)
        } catch {
            return ([:], DiskArchiveLog.errorSummary(error))
        }
    }

    private static func write(_ values: [String: Any], to url: URL) {
        let folder = url.deletingLastPathComponent()
        guard WriteGuard.permitsWrite(to: url), WriteGuard.permitsWrite(to: folder) else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            DiskArchiveLog.shared.record(.app, .error, "app-zustand speichern \(DiskArchiveLog.errorSummary(error))")
        }
    }
}
