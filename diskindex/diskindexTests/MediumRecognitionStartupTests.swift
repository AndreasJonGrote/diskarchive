//
//  MediumRecognitionStartupTests.swift
//  diskindexTests
//

import Foundation
import Testing
@testable import diskindex

@MainActor
struct MediumRecognitionStartupTests {
    @Test func bootstrapStartsMonitorBeforeMediaLoad() async throws {
        MediumRecognitionStartup.resetStartupFlagsForTests()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskindex-startup-\(UUID().uuidString)", isDirectory: true)
        let database = try TestDatabase(fileURL: directory.appendingPathComponent("archive.sqlite"))
        let store = IndexStoreV3(database: database)
        let access = ScriptedAccess()
        let appState = AppState()
        let coordinator = MediumCoordinator(store: store, access: access, appState: appState)

        MediumRecognitionStartup.bootstrap(
            appState: appState,
            store: store,
            coordinator: coordinator,
            startChangeLoop: { appState.startChangeLoop() }
        )
        #expect(MediumRecognitionStartup.didStartCoordinatorBeforeLoad)
        coordinator.stop()
    }
}

private final class ScriptedAccess: MediumAccess, @unchecked Sendable {
    var result: MediumAccessResult = .granted
    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { result }
    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] { [] }
}
