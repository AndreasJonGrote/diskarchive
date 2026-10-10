//
//  MediumMonitor.swift
//  diskindex
//

import AppKit

@MainActor
final class MediumMonitor {
    private var debouncer = MountEventDebouncer()

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
                center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                    MainActor.assumeIsolated {
                        self.emitMounted(continuation: continuation)
                    }
                },
            ]
            emitMounted(continuation: continuation)
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    for token in tokens {
                        center.removeObserver(token)
                    }
                }
            }
        }
    }

    private func emitMounted(continuation: AsyncStream<MediumEvent>.Continuation) {
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: []) ?? []
        for url in urls {
            guard let info = VolumeLookup.info(at: url), VolumeCandidateRule.isCandidate(info.candidateInput) else { continue }
            guard debouncer.shouldEmit(path: info.mountPath, kind: "appeared") else { continue }
            continuation.yield(.appeared(info))
        }
    }

    private func emitMount(_ note: Notification, continuation: AsyncStream<MediumEvent>.Continuation) {
        guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL,
              let info = VolumeLookup.info(at: url),
              VolumeCandidateRule.isCandidate(info.candidateInput),
              debouncer.shouldEmit(path: info.mountPath, kind: "appeared") else { return }
        continuation.yield(.appeared(info))
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
