//
//  ArchiveDatabaseStartupTests.swift
//  diskindexTests
//
//  bug.0.4.086: Erster Start nach einer Migration. Eine große Datenbank ohne die letzte Migration
//  (`items_search_natural`) wird über die Startkette der App geöffnet (`StartupSequence.run` wie in
//  `AppDelegate.startMediumRecognition`, danach `IssueReporter.start` wie in `applicationDidFinishLaunching`).
//  Erwartet: genau ein Pool und eine Migration für die Datei, kein Fehler, Medien geladen, die Warteschlange schreibt,
//  der Hauptfaden bleibt während der Migration ansprechbar.
//

import Foundation
import GRDB
import Testing
@testable import diskindex

/// Größte Lücke zwischen zwei Ticks des Hauptfadens (wie in `MainThreadMediumIOTests`).
@MainActor
private final class MainTicker {
    private(set) var ticks = 0
    private(set) var longestGap: TimeInterval = 0
    private var last = Date()
    private var task: Task<Void, Never>?

    func start() {
        last = Date()
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(10))
                guard let self else { return }
                let now = Date()
                self.longestGap = max(self.longestGap, now.timeIntervalSince(self.last))
                self.last = now
                self.ticks += 1
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

/// Faden des `open`-Schritts der Startkette (Öffnen und Warten auf die Migration).
private final class OpenThreadProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var onMain: [Bool] = []
    func note(_ value: Bool) { lock.withLock { onMain.append(value) } }
    var all: [Bool] { lock.withLock { onMain } }
}

@Suite(.serialized) @MainActor
struct ArchiveDatabaseStartupTests {
    private let itemCount = 300_000

    /// Datei im Stand vor bug.0.4.077: alle Migrationen bis `items_gone`, ein Medium, viele Einträge.
    private func makeDatabaseWithoutLastMigration(at url: URL) async throws -> StoredMedium {
        let pool = try DatabasePool(path: url.path, configuration: SchemaV3.makeConfiguration())
        try SchemaV3.migrator.migrate(pool, upTo: SchemaV3.itemsGoneMigration)
        let medium = StoredMedium(fsType: "apfs", volumeTotalBytes: 1_000, name: "Großarchiv", type: .usb, decision: .index)
        try await IndexStoreV3(pool: pool).upsertMedium(medium)
        try await pool.write { db in
            try db.execute(
                sql: """
                    WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < ?)
                    INSERT INTO items (storageID, name, slug, isFolder)
                    SELECT (SELECT id FROM storages LIMIT 1), 'Datei ' || i || '.txt', 'datei ' || i || '.txt', 0 FROM n
                    """,
                arguments: [itemCount]
            )
        }
        let applied = try await pool.read { try SchemaV3.migrator.appliedIdentifiers($0) }
        try #require(!applied.contains(SchemaV3.itemsSearchNaturalMigration))
        try pool.close()
        return medium
    }

    /// bug.0.4.094 (a): Scheitert das Öffnen (neuere Datei), öffnet ein zweiter Aufruf nicht erneut – der Fehler bleibt
    /// bis zum ausdrücklichen Wiederholen.
    @Test func failedOpenIsRememberedUntilRetry() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-archive-fail-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("archive.sqlite")
        let seed = try SchemaV3.openPool(at: url)
        try seed.write { db in
            try db.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)", arguments: ["9.9-future"])
        }
        try seed.close()
        let before = SchemaV3.OpenCounter.shared.count(url)
        let archive = ArchiveDatabase(fileURL: url)
        #expect(throws: IndexStoreError.self) { try archive.pool() }
        #expect(throws: IndexStoreError.self) { try archive.pool() }
        #expect(SchemaV3.OpenCounter.shared.count(url) == before + 1, "zweiter Aufruf öffnete die Datei erneut")
        archive.retryOpen()
        #expect(throws: IndexStoreError.self) { try archive.pool() }
        #expect(SchemaV3.OpenCounter.shared.count(url) == before + 2)
    }

    @Test func firstLaunchAfterMigrationOpensOnePoolAndStaysResponsive() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-archive-start-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("archive.sqlite")
        let medium = try await makeDatabaseWithoutLastMigration(at: url)
        try #require(SchemaV3.OpenCounter.shared.count(url) == 0)

        let archive = ArchiveDatabase(fileURL: url)
        let defaults = TestDefaults.make()
        let logDirectory = directory.appendingPathComponent("Logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        let diskLog = DiskIndexLog(directory: logDirectory)
        diskLog.start(installHandlers: false)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RealLogReportStubURL.self]
        let host = "a\(UUID().uuidString.prefix(8).lowercased()).real-log.test"
        let reporter = IssueReporter(
            endpoint: try #require(URL(string: "https://\(host)/api/issues/")),
            directory: directory.appendingPathComponent("outbox", isDirectory: true),
            queuePool: nil,
            session: URLSession(configuration: configuration),
            releaseBuild: false,
            log: { _ in },
            diskLog: diskLog,
            archive: archive
        )
        reporter.sendsImmediately = false
        let app = AppState()
        defer { app.prepareForTermination() }
        let scheduler = VersionCheckScheduler(wakeEvents: { AsyncStream { _ in } }, flush: {}, databaseWasNewThisLaunch: false)
        defer { scheduler.stop() }
        var coordinator: MediumCoordinator?
        defer { coordinator?.stop() }
        let ticker = MainTicker()
        ticker.start()
        defer { ticker.stop() }

        // bug.0.4.093: Während die Migration läuft, muss der Main Actor springen können (Tor wie `MainHopGate`): die
        // Migration wartet am Tor, bis der Test auf main die Meldung gelesen hat; Notgrenze nur für den roten Fall.
        let gate = MainHopGate()
        SchemaV3.OpenCounter.shared.setBeforeMigrateHook(url) { gate.arrive(onMain: Thread.isMainThread) }
        defer { SchemaV3.OpenCounter.shared.setBeforeMigrateHook(url, nil) }

        // Reihenfolge wie in der App: Öffnen im Hintergrund anstoßen, dann den Fehlerbericht starten.
        var failure: Error?
        let openThread = OpenThreadProbe()
        let started = Date()
        let startup = StartupSequence.run(
            previousRunUnclean: false,
            defaults: defaults,
            open: { [openThread] in
                openThread.note(Thread.isMainThread)
                // bug.0.4.093: derselbe Weg wie die App (`openDefault`), ein Rückfall auf einen eigenen Pool fällt auf.
                return try IndexStoreV3.openDefault(archive: archive)
            },
            wire: { store in
                // Öffnen und Migration sind fertig: Ticker anhalten (gemessen wird der Hauptfaden während der Migration;
                // das Verdrahten danach liest bewusst einmal synchron, `StoreLaunchSequence.startServices`).
                ticker.stop()
                // Wie `AppDelegate.wireStore`: Fehlerbericht auf denselben Pool, dann die Startdienste.
                reporter.queuePool = store.pool
                let wired = MediumCoordinator(store: store, access: MemoryVolume(mountPath: "/Volumes/KEINS"), appState: app)
                coordinator = wired
                StoreLaunchSequence.startServices(
                    appState: app,
                    store: store,
                    coordinator: wired,
                    versionCheck: scheduler,
                    startChangeLoop: { app.startChangeLoop() },
                    makeMonitor: {
                        MediumMonitor(mountedVolumes: { [] }, wakeEvents: { AsyncStream { _ in } }, notificationCenter: NotificationCenter())
                    }
                )
            },
            onFailure: { failure = $0 }
        )
        reporter.start()
        // Ende ohne Tor (z. B. Fehler vor der Migration) → Warten endet (rot statt Hängen).
        Task { _ = await startup.value; gate.finish() }
        let migrationReport = await gate.arrived()
        gate.open()
        await startup.value
        let openSeconds = Date().timeIntervalSince(started)

        #expect(failure == nil, "Start meldet Fehler: \(String(describing: failure))")
        let store = try #require(app.indexStore)
        #expect(await waitUntil(timeout: 10) { app.media.map(\.id) == [medium.uuid] }, "Medien: \(app.media.map(\.name))")
        let applied = try await store.pool.read { try SchemaV3.migrator.appliedIdentifiers($0) }
        #expect(applied.contains(SchemaV3.itemsSearchNaturalMigration))

        // Fehlerbericht: kennt die Mediennamen und schreibt in dieselbe Warteschlange.
        #expect(await waitUntil(timeout: 10) { reporter.knownNames().contains(medium.name) })
        reporter.enqueue(kind: "crash")
        reporter.waitForPendingEnqueuesForTesting()
        // Regel 20: ein Rest aus dem Start darf mitzählen.
        #expect(try reporter.queuedReportCount() >= 1)

        // Genau ein Öffnen (und damit eine Migration) für diese Datei.
        #expect(SchemaV3.OpenCounter.shared.count(url) == 1, "openPool-Aufrufe: \(SchemaV3.OpenCounter.shared.count(url))")
        // Hauptfaden während Öffnen und Migration frei: beides läuft nicht auf ihm (wie bug.0.3.9.004 deterministisch über
        // den Faden statt über eine Zeitgrenze – im Parallellauf teilen sich viele Tests den Hauptfaden, die Lücke
        // des Tickers maß dort fremde Arbeit: 0,77–0,83 s, seriell 11 ms). Der Ticker lief weiter (Diagnose).
        #expect(SchemaV3.OpenCounter.shared.mainThreadCount(url) == 0, "Öffnen/Migration auf dem Hauptfaden")
        // Auch das Warten der Startkette auf eine laufende Migration (Sperre in `ArchiveDatabase`) nicht auf ihm.
        #expect(openThread.all == [false], "open-Schritt auf dem Hauptfaden: \(openThread.all)")
        // bug.0.4.093: kein Aufrufer wartet auf dem Hauptfaden an der Sperre, und während der Migration kam ein Sprung
        // auf den Main Actor (die Migration lief nicht auf main und blockierte ihn nicht).
        #expect(SchemaV3.OpenCounter.shared.mainThreadPoolWaitCount(url) == 0, "pool() auf dem Hauptfaden vor dem Öffnen")
        #expect(migrationReport == false, "Migration erreichte das Tor nicht oder lief auf main")
        #expect(gate.timedOut == false, "Main Actor während der Migration blockiert")
        #expect(ticker.ticks > 0)
        print("bug.0.4.086 öffnen+migrieren \(itemCount) Einträge: \(openSeconds) s, längste Lücke \(ticker.longestGap) s")
    }
}
