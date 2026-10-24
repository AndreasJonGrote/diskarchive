//
//  RunGateAccess.swift
//  diskindexTests
//
//  Tor für laufende Läufe (bug.0.4.027, 028, 030 Nacharbeit 3): leitet an `MemoryVolume`s weiter
//  und hält gewählte Ordner an, bis `open()`. Kein `lock()` über `await` (Regel 20).
//

import Foundation
@testable import diskindex

final class RunGateAccess: MediumAccess, @unchecked Sendable {
    /// bug.0.4.177: Testzugriff steht für ein eingehängtes Medium.
    func mediumIsMounted(_ medium: StoredMedium, mountPath: String) async -> Bool { true }
    private let volumes: [MemoryVolume]
    private let holds: @Sendable (String) -> Bool
    private let state = RunGateState()
    /// Erstes Anhalten am Tor.
    let entered = SurfaceAsyncSignal()

    /// `holds(path)` = dieser Ordner wartet am Tor (Pfad standardisiert).
    init(_ volumes: [MemoryVolume], holds: @escaping @Sendable (String) -> Bool) {
        self.volumes = volumes
        self.holds = holds
    }

    func open() async {
        await state.open()
    }

    /// Wie oft ein Lauf am Tor angehalten hat (auch nach Abbruch und Neustart).
    func heldCount() async -> Int {
        await state.held
    }

    func probe(_ volume: VolumeInfo) async -> MediumAccessResult { .granted }

    func listDirectory(at url: URL) async throws -> [ListedDirectoryEntry] {
        let path = url.standardizedFileURL.path
        guard let volume = volumes.first(where: { path == $0.mountPath || path.hasPrefix($0.mountPath + "/") }) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        if holds(path), await !state.isOpen {
            if await state.noteHeld() == 1 { await entered.signal() }
            while await !state.isOpen {
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(5))
            }
        }
        return try await volume.listDirectory(at: url)
    }
}

private actor RunGateState {
    private(set) var isOpen = false
    private(set) var held = 0

    func open() {
        isOpen = true
    }

    func noteHeld() -> Int {
        held += 1
        return held
    }
}

/// Medium-Zeile für `AppState.media` aus der DB (Tests).
func connectedTestMedium(from stored: StoredMedium) -> Medium {
    let status: IndexStatus = switch stored.indexStatus {
    case .indexed: .indexed
    case .indexing: .indexing
    case .error: .error
    case .pending: .pending
    }
    return Medium(
        id: stored.uuid,
        name: stored.name,
        type: .usb,
        connectionStatus: .connected,
        indexStatus: status,
        allowIndexing: true,
        autoIndexPaused: false,
        decision: stored.decision,
        capacityTotalBytes: stored.volumeTotalBytes,
        capacityUsedBytes: 0,
        fileCount: stored.fileCount,
        folderCount: stored.folderCount,
        scanTotal: stored.scanTotal,
        lastSeenAt: Date(),
        firstIndexedAt: stored.firstIndexedAt,
        lastIndexedAt: stored.lastIndexedAt,
        completedDepth: stored.completedDepth,
        isForgotten: false,
        indexingProgress: status == .indexed ? 1 : 0
    )
}

/// Testvolume mit eigener Volume-UUID: der Coordinator erkennt es nach `recordIdentity` eindeutig wieder
/// (ohne UUID und Erstellungsdatum gibt es nur einen schwachen Treffer → Erkennungs-Dialog).
func testVolume(path: String, name: String, fsType: String = "apfs", uuid: String = UUID().uuidString) -> VolumeInfo {
    VolumeInfo(
        mountPath: path, name: name, fsType: fsType,
        volumeTotalBytes: 1_000, volumeFreeBytes: nil, diskSizeBytes: nil, volumeUUID: uuid,
        createdAt: nil, isRemovable: true, isEjectable: true, isInternal: false, isLocal: true,
        deviceProtocol: "USB", model: nil, isTimeMachineSnapshot: false
    )
}

/// Erkennung, Indizierung und Überwachung wie in der App verdrahtet (ohne FSEvents-Start).
@MainActor
struct WiredRig {
    let app: AppState
    let service: IndexingService
    let coordinator: MediumCoordinator
    let watcher: ChangeWatcher

    init(
        store: IndexStoreV3,
        access: any MediumAccess,
        app: AppState,
        startWatching: @escaping (UUID, VolumeInfo) async -> Void = { _, _ in }
    ) {
        self.app = app
        service = IndexingService(store: store, access: access, appState: app)
        coordinator = MediumCoordinator(store: store, access: access, appState: app)
        watcher = ChangeWatcher(store: store, access: access, appState: app)
        LiveWiring.connect(
            coordinator: coordinator,
            service: service,
            watcher: watcher,
            appState: app,
            startWatching: startWatching
        )
    }

    func starts(_ id: UUID) -> [Bool] {
        service.startedRunsForTesting[id] ?? []
    }
}
