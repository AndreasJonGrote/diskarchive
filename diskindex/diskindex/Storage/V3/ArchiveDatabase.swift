//
//  ArchiveDatabase.swift
//  diskindex
//
//  bug.0.4.086: genau ein Pool je Prozess für `archive.sqlite`. Index, Warteschlange (`api_queue`) und Fehlerbericht
//  holen ihn hier. Wer zuerst fragt, öffnet und migriert (unter der Sperre, nie auf dem Hauptfaden); alle anderen warten
//  und bekommen denselben Pool. Vorher öffneten Index und Fehlerbericht je einen eigenen Pool: beide liefen die
//  Schreib-PRAGMAs und den Migrator, und eine lange Migration (Index über eine große Datenbank) ließ den anderen nach
//  10 s mit „database is locked“ scheitern. Ein Fehler wird nicht gemerkt, der nächste Aufruf öffnet neu.
//

import Foundation
import GRDB

nonisolated final class ArchiveDatabase: @unchecked Sendable {
    /// Die Datenbank der App (`Application Support/Disk Archive/archive.sqlite`).
    static let shared = ArchiveDatabase(fileURL: nil)

    private let explicitURL: URL?
    /// Gehalten, solange geöffnet und migriert wird: ein zweiter Aufruf wartet, statt selbst zu öffnen.
    private let openLock = NSLock()
    private let stateLock = NSLock()
    private var opened: DatabasePool?
    /// bug.0.4.094: Fehler des letzten Öffnens (z. B. `schemaSuperseded`, kaputte Datei). Weitere Aufrufe melden ihn
    /// weiter, statt die Datei erneut zu öffnen (Schreib-PRAGMAs auf eine neuere Datei), bis `retryOpen()` ihn löscht.
    private var openError: Error?

    /// `fileURL`: nur Tests geben eine eigene Datei an; `nil` = `IndexStoreV3.storeFileURL()`.
    init(fileURL: URL?) {
        explicitURL = fileURL
    }

    func fileURL() throws -> URL {
        if let explicitURL { return explicitURL }
        return try IndexStoreV3.storeFileURL()
    }

    /// Der Pool; öffnet und migriert beim ersten Aufruf. Nicht auf dem Hauptfaden aufrufen (Migration kann dauern).
    func pool() throws -> DatabasePool {
        if let openedPool { return openedPool }
        #if DEBUG
        // bug.0.4.093: Ein Aufruf auf dem Hauptfaden, solange noch nicht geöffnet ist, wartet dort auf die Migration.
        if Thread.isMainThread, let url = try? fileURL() {
            SchemaV3.OpenCounter.shared.noteMainThreadPoolWait(url)
        }
        #endif
        openLock.lock()
        defer { openLock.unlock() }
        if let openedPool { return openedPool }
        if let remembered = stateLock.withLock({ openError }) { throw remembered }
        do {
            let pool = try SchemaV3.openPool(at: fileURL())
            stateLock.withLock { opened = pool }
            return pool
        } catch {
            stateLock.withLock { openError = error }
            throw error
        }
    }

    /// Ausdrücklicher neuer Versuch (Knopf „Erneut versuchen“): vergisst den gemerkten Fehler.
    func retryOpen() {
        stateLock.withLock { openError = nil }
    }

    /// Geschlossener Pool (Datei nach kaputter Integritätsprüfung weggesperrt): nicht mehr ausgeben, neu öffnen.
    func discard(_ pool: DatabasePool) {
        stateLock.withLock {
            if opened === pool { opened = nil }
            openError = nil
        }
    }

    /// Schon geöffneter Pool, ohne zu öffnen oder zu warten.
    var openedPool: DatabasePool? {
        stateLock.withLock { opened }
    }
}
