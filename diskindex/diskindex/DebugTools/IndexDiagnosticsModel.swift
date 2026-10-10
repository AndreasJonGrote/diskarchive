#if DEBUG
//
//  IndexDiagnosticsModel.swift
//  diskindex
//
//  Aufgabe 35: Zustand des Diagnosefensters. Kein AppState.
//

import AppKit
import Foundation
import os

@MainActor
@Observable
final class IndexDiagnosticsModel {
    var volumes: [VolumeRow] = []
    var selectedID: String?
    var logA = ""
    var logB = ""
    var logC = ""
    var logD = ""
    var logE = ""
    var systemDialogNote = ""
    var scanDepth = 3
    var sqliteRowCount = 100_000
    var probing = false
    var scanning = false
    var watching = false
    var measuring = false

    private var diskSnapshots: [DiskSnapshot] = []
    private var hiddenEntries = 0
    private var hiddenFlushScheduled = false
    private var monitor: VolumeEventMonitor?
    private var fsEvents: FSEventsSpike?
    private var scanFlag: IndexDiagnosticsCancelFlag?
    private var started = false
    private static let defaultsKey = "IndexDiagnostics.logs.v1"

    func start() {
        guard !started else { return }
        started = true
        restore()
        let sandbox = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        append(.a, "Lauf gestartet | sandboxed: \(sandbox ? "ja" : "nein")")
        refreshMounted(logNotes: true)
        let monitor = VolumeEventMonitor()
        monitor.onLog = { [weak self] line in self?.append(.a, line) }
        monitor.onDisk = { [weak self] snapshot in self?.receiveDisk(snapshot) }
        monitor.onWillUnmount = { [weak self] path in self?.fsEvents?.volumeWillUnmount(path) }
        monitor.start()
        self.monitor = monitor
        let fs = FSEventsSpike()
        fs.onLog = { [weak self] line in self?.append(.d, line) }
        fsEvents = fs
    }

    func stop() {
        scanFlag?.cancel()
        fsEvents?.stop(save: true)
        monitor?.stop()
        monitor = nil
        started = false
    }

    func refreshMounted(logNotes: Bool) {
        let rows = VolumeListing.mountedRows()
        volumes = rows
        if selectedID == nil || !rows.contains(where: { $0.id == selectedID }) {
            selectedID = rows.first { $0.isCandidate }?.id ?? rows.first?.id
        }
        let candidates = rows.filter(\.isCandidate)
        for row in candidates {
            append(.a, row.line)
        }
        let hidden = rows.count - candidates.count
        if hidden > 0 {
            append(.a, "\(hidden) interne Einträge ausgeblendet")
        }
        guard logNotes else { return }
        for note in VolumeListing.uuidNotes(mounted: candidates, disks: diskSnapshots.filter(\.isCandidate)) {
            append(.a, note)
        }
    }

    private func receiveDisk(_ snapshot: DiskSnapshot) {
        if snapshot.event == "verschwunden" {
            append(.a, snapshot.line)
            return
        }
        guard snapshot.isCandidate else {
            noteHiddenEntry()
            return
        }
        diskSnapshots.append(snapshot)
        append(.a, snapshot.line)
    }

    private func noteHiddenEntry() {
        hiddenEntries += 1
        guard !hiddenFlushScheduled else { return }
        hiddenFlushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.hiddenFlushScheduled = false
                let count = self.hiddenEntries
                self.hiddenEntries = 0
                if count > 0 {
                    self.append(.a, "\(count) interne Einträge ausgeblendet")
                }
            }
        }
    }

    func probeAccess() {
        guard let path = selectedPath else {
            append(.b, "Kein Volume gewählt.")
            return
        }
        probing = true
        Task.detached(priority: .utility) {
            let line = AccessProbeSpike.probe(path: path)
            await MainActor.run { [weak self] in
                self?.append(.b, line)
                self?.probing = false
            }
        }
    }

    func startScan() {
        guard let path = selectedPath else {
            append(.c, "Kein Volume gewählt.")
            return
        }
        let flag = IndexDiagnosticsCancelFlag()
        scanFlag = flag
        scanning = true
        let depth = scanDepth
        append(.c, "Start | Tiefe=\(depth) | \(path)")
        Task.detached(priority: .utility) { [weak self] in
            guard let model = self else { return }
            await BreadthScanSpike.run(path: path, maxDepth: depth, isCancelled: { flag.isCancelled }) { line in
                await model.appendFromBackground(.c, line)
            }
            await MainActor.run {
                model.scanning = false
            }
        }
    }

    func cancelScan() {
        scanFlag?.cancel()
        append(.c, "Abbruch angefordert")
    }

    func toggleFSEvents() {
        guard let fsEvents else { return }
        if watching {
            fsEvents.stop(save: true)
            watching = false
            return
        }
        guard let path = selectedPath else {
            append(.d, "Kein Volume gewählt.")
            return
        }
        let key = selectedVolumeKey ?? path
        fsEvents.start(path: path, volumeKey: key)
        watching = fsEvents.isRunning
    }

    func measureSQLite() {
        let count = sqliteRowCount
        measuring = true
        append(.e, "Start | Zeilen=\(count)")
        Task.detached(priority: .utility) { [weak self] in
            guard let model = self else { return }
            await SQLiteSpike.run(rowCount: count) { line in
                await model.appendFromBackground(.e, line)
            }
            await MainActor.run {
                model.measuring = false
            }
        }
    }

    func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        append(.a, "Bericht in die Zwischenablage kopiert")
    }

    var selectedPath: String? {
        volumes.first { $0.id == selectedID }?.path
    }

    private var selectedName: String? {
        volumes.first { $0.id == selectedID }?.name
    }

    private func prefixed(_ section: Section, _ message: String) -> String {
        guard section != .a, !message.hasPrefix("Ziel:") else { return message }
        return "Ziel: \(selectedName ?? "—") | \(selectedPath ?? "—") | \(message)"
    }

    private var selectedVolumeKey: String? {
        guard let row = volumes.first(where: { $0.id == selectedID }) else { return nil }
        if !VolumeListing.lacksUUID(row.uuid) { return row.uuid }
        return row.path
    }

    fileprivate func appendFromBackground(_ section: Section, _ message: String) async {
        await MainActor.run {
            append(section, message)
        }
    }

    private func append(_ section: Section, _ message: String) {
        let text = prefixed(section, message)
        let line = "\(Self.timestamp()) \(text)\n"
        switch section {
        case .a: logA += line
        case .b: logB += line
        case .c: logC += line
        case .d: logD += line
        case .e: logE += line
        }
        indexDiagnosticsLogger.info("[\(section.rawValue, privacy: .public)] \(text, privacy: .public)")
        persist()
    }

    private var markdown: String {
        """
        # Diagnose: Indexierung

        Systemdialog erschienen: \(systemDialogNote.isEmpty ? "(nicht eingetragen)" : systemDialogNote)

        Sandbox aus: Xcode → Target diskindex → Signing & Capabilities → App Sandbox entfernen → App neu starten → Abschnitt B erneut ausführen. Danach App Sandbox wieder aktivieren.
        Dialog zurücksetzen: tccutil reset SystemPolicyRemovableVolumes xjonx.diskindex

        ## A. Volumes
        \(logA)
        ## B. Zugriff
        \(logB)
        ## C. Scan
        \(logC)
        ## D. FSEvents
        \(logD)
        ## E. SQLite
        \(logE)
        """
    }

    private func persist() {
        let saved = SavedLogs(a: logA, b: logB, c: logC, d: logD, e: logE, dialog: systemDialogNote)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let saved = try? JSONDecoder().decode(SavedLogs.self, from: data) else { return }
        logA = saved.a
        logB = saved.b
        logC = saved.c
        logD = saved.d
        logE = saved.e
        systemDialogNote = saved.dialog
    }

    func storeDialogNote() {
        persist()
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    fileprivate enum Section: String {
        case a = "A"
        case b = "B"
        case c = "C"
        case d = "D"
        case e = "E"
    }
}

private struct SavedLogs: Codable {
    var a: String
    var b: String
    var c: String
    var d: String
    var e: String
    var dialog: String
}
#endif
