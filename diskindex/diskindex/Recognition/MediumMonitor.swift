//
//  MediumMonitor.swift
//  diskindex
//

import AppKit

@MainActor
final class MediumMonitor {
    private var debouncer = MountEventDebouncer()
    /// bug.0.4.028: beim Aufwachen kein `.appeared`, wenn Pfad schon verbunden ist.
    var skipWakeAppearedIfKnown: ((VolumeInfo) -> Bool)?
    /// Eingehängte Kandidaten-Volumes (Tests: feste Liste statt Dateisystem).
    private let mountedVolumes: @MainActor () async -> [VolumeInfo]
    /// Aufwach-Auslöser (Tests: eigener Strom statt `NSWorkspace.didWakeNotification`).
    private let wakeEvents: @MainActor () -> AsyncStream<Void>

    init(
        mountedVolumes: @escaping @MainActor () async -> [VolumeInfo] = MediumMonitor.liveMountedVolumes,
        wakeEvents: @escaping @MainActor () -> AsyncStream<Void> = MediumMonitor.liveWakeEvents
    ) {
        self.mountedVolumes = mountedVolumes
        self.wakeEvents = wakeEvents
    }

    static func liveMountedVolumes() async -> [VolumeInfo] {
        var found: [VolumeInfo] = []
        for path in LocalVolumeMounts.candidateMountPaths() {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            guard let info = await VolumeLookup.info(at: url) else { continue }
            found.append(info)
        }
        return found
    }

    static func liveWakeEvents() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let center = NSWorkspace.shared.notificationCenter
            let token = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                continuation.yield()
            }
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in center.removeObserver(token) }
            }
        }
    }

    func events() -> AsyncStream<MediumEvent> {
        AsyncStream { continuation in
            let center = NSWorkspace.shared.notificationCenter
            let tokens = [
                center.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { note in
                    MainActor.assumeIsolated {
                        self.emitMount(note, continuation: continuation)
                    }
                },
                center.addObserver(forName: NSWorkspace.willUnmountNotification, object: nil, queue: .main) { note in
                    MainActor.assumeIsolated {
                        self.emitPath(note, kind: "will", event: { .willDisappear(path: $0) }, continuation: continuation)
                    }
                },
                center.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { note in
                    MainActor.assumeIsolated {
                        self.emitPath(note, kind: "did", event: { .disappeared(path: $0) }, continuation: continuation)
                    }
                },
                center.addObserver(forName: NSWorkspace.didRenameVolumeNotification, object: nil, queue: .main) { note in
                    MainActor.assumeIsolated {
                        self.emitRename(note, continuation: continuation)
                    }
                },
            ]
            let wakes = self.wakeEvents()
            let wakeTask = Task { @MainActor in
                for await _ in wakes {
                    self.emitMounted(continuation: continuation, wakeRescan: true)
                }
            }
            self.emitMounted(continuation: continuation, wakeRescan: false)
            continuation.onTermination = { @Sendable _ in
                wakeTask.cancel()
                Task { @MainActor in
                    for token in tokens {
                        center.removeObserver(token)
                    }
                }
            }
        }
    }

    private func emitMounted(continuation: AsyncStream<MediumEvent>.Continuation, wakeRescan: Bool) {
        let mountedVolumes = mountedVolumes
        Task {
            for info in await mountedVolumes() where VolumeCandidateRule.isCandidate(info.candidateInput) {
                await MainActor.run {
                    if wakeRescan, self.skipWakeAppearedIfKnown?(info) == true { return }
                    guard self.debouncer.shouldEmit(path: info.mountPath, kind: "appeared") else { return }
                    continuation.yield(.appeared(info))
                }
            }
        }
    }

    private func emitMount(_ note: Notification, continuation: AsyncStream<MediumEvent>.Continuation) {
        guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
        let path = url.standardizedFileURL.path
        guard path.hasPrefix("/Volumes/") else { return }
        Task {
            guard let info = await VolumeLookup.info(at: url),
                  VolumeCandidateRule.isCandidate(info.candidateInput) else { return }
            await MainActor.run {
                guard self.debouncer.shouldEmit(path: info.mountPath, kind: "appeared") else { return }
                continuation.yield(.appeared(info))
            }
        }
    }

    private func emitRename(_ note: Notification, continuation: AsyncStream<MediumEvent>.Continuation) {
        guard let newURL = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL,
              let oldURL = note.userInfo?[NSWorkspace.oldVolumeURLUserInfoKey] as? URL else { return }
        let oldPath = oldURL.standardizedFileURL.path
        Task {
            guard let info = await VolumeLookup.info(at: newURL) else { return }
            await MainActor.run {
                guard self.debouncer.shouldEmit(path: info.mountPath, kind: "renamed") else { return }
                continuation.yield(.renamed(oldPath: oldPath, volume: info))
            }
        }
    }

    private func emitPath(
        _ note: Notification,
        kind: String,
        event: (String) -> MediumEvent,
        continuation: AsyncStream<MediumEvent>.Continuation
    ) {
        guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
        let path = url.path
        guard debouncer.shouldEmit(path: path, kind: kind) else { return }
        continuation.yield(event(path))
    }
}
