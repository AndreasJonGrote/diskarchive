//
//  ScanDepthColumnLoadTests.swift
//  diskindexTests
//
//  bug.0.4.178: Nach dem Verkleinern der Scan-Tiefe liefert ein neu geladener Ordner jenseits der Tiefe sofort keinen
//  Inhalt – auch bevor der Regelabgleich die Zeilen umgestellt hat (Tiefe gilt immer, nicht erst über `status`).
//

import Foundation
import Testing
@testable import diskindex

@Suite(.serialized) @MainActor
struct ScanDepthColumnLoadTests {
    private func depthTwo() -> IndexScope {
        var settings = AppSettings()
        settings.scanDepth = 2
        return IndexScope.from(settings)
    }

    /// Store: eine Seite der Spalte „Alpha/Inner“ (Tiefe 3) mit Tiefe 2, ohne Regelabgleich → leer.
    @Test func childrenBeyondTheScanDepthAreHiddenWithoutReconcile() async throws {
        let rig = try await seededTree()
        let alpha = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["Alpha"]))
        let inner = try #require(try await rig.store.folderID(mediumUUID: rig.medium.uuid, path: ["Alpha", "Inner"]))
        let scope = depthTwo()
        let page = try await rig.store.childrenPage(mediumUUID: rig.medium.uuid, parentID: inner, limit: 100, scope: scope)
        #expect(page.items.isEmpty, "Inhalt jenseits der Scan-Tiefe: \(page.items.map(\.name))")
        // Gegenprobe: innerhalb der Tiefe bleibt der Inhalt.
        let inside = try await rig.store.childrenPage(mediumUUID: rig.medium.uuid, parentID: alpha, limit: 100, scope: scope)
        #expect(Set(inside.items.map(\.name)) == ["a.txt", "Inner"])
    }

    /// Spalten-Cache: neue Tiefe gesetzt, der Ordner lädt neu, bevor ein Regelabgleich läuft → leer.
    @Test func columnLoadBeyondTheScanDepthIsEmptyBeforeReconcile() async throws {
        let rig = try await seededTree()
        rig.app.indexRepository.scope = depthTwo()
        let deep = await rig.app.indexRepository.loadChildren(mediumID: rig.medium.uuid, path: ["Alpha", "Inner"]).map(\.name)
        #expect(deep.isEmpty, "Spalte jenseits der Tiefe zeigt Inhalt: \(deep)")
    }
}
