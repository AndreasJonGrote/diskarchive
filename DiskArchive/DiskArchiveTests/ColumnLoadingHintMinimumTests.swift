//
//  ColumnLoadingHintMinimumTests.swift
//  DiskArchiveTests
//
//  bug.0.4.061 (REPORT 107): Mindestanzeige (400 ms) des Ladehinweises in der Spalte wirkt,
//  der Zustand wird nicht beim Zeichnen verändert.
//

import AppKit
import Observation
import SwiftUI
import Testing
@testable import DiskArchive

@MainActor
@Observable
private final class LoadSwitch {
    var isLoading = true
}

@MainActor
private final class HintRecorder {
    private(set) var events: [(visible: Bool, at: ContinuousClock.Instant)] = []

    func record(_ visible: Bool) {
        events.append((visible, ContinuousClock.now))
    }

    /// bug.0.4.068 b): wie oft die Ansicht `isLoading == false` wirklich bekommen hat.
    private(set) var loadingEndsSeen = 0

    func noteLoadingEnded() {
        loadingEndsSeen += 1
    }

    /// bug.0.4.192: wie oft die Ansicht `isLoading == true` (Neustart) bekommen hat.
    private(set) var loadingStartsSeen = 0

    func noteLoadingStarted() {
        loadingStartsSeen += 1
    }

    var last: Bool? { events.last?.visible }
    var firstShown: ContinuousClock.Instant? { events.first { $0.visible }?.at }

    func firstHidden(after instant: ContinuousClock.Instant) -> ContinuousClock.Instant? {
        events.first { !$0.visible && $0.at >= instant }?.at
    }
}

private struct LoadingHarness: View {
    let model: LoadSwitch
    let recorder: HintRecorder
    let timing: DelayedLoadingTiming

    var body: some View {
        ColumnFolderContents(
            mediumID: UUID(uuidString: "00000000-0000-0000-0000-000000000061") ?? UUID(),
            path: ["Ordner"],
            filteredItems: [],
            selectedIDs: [],
            isLoading: model.isLoading,
            loaded: 0,
            total: 0,
            loadingTiming: timing,
            onLoadingHintVisible: { recorder.record($0) }
        ) { _ in EmptyView() }
        .frame(width: 270, height: 200)
        .onChange(of: model.isLoading) { _, loading in
            if loading { recorder.noteLoadingStarted() } else { recorder.noteLoadingEnded() }
        }
    }
}

/// In der seriellen Fenstergruppe, wie die übrigen Tests mit echtem Fenster.
extension WindowTestGroup {
    @Suite(.serialized) @MainActor
    struct ColumnLoadingHintMinimumTests {
        /// Echtes Fenster außerhalb des Bildschirms (Regel 19), bleibt offen, bis `close` gerufen wird.
        private func open(_ view: some View) -> NSWindow {
            let size = CGSize(width: 270, height: 200)
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(origin: .zero, size: size)
            let window = NSWindow(
                contentRect: NSRect(origin: CGPoint(x: -20_000, y: -20_000), size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFrontRegardless()
            host.layoutSubtreeIfNeeded()
            return window
        }

        private func close(_ window: NSWindow) {
            window.contentView = nil
            window.orderOut(nil)
            window.close()
        }

        @Test func hintStaysForMinimumAfterLoadingEnds() async throws {
            let minimum = Duration.milliseconds(400)
            let model = LoadSwitch()
            let recorder = HintRecorder()
            let window = open(LoadingHarness(
                model: model,
                recorder: recorder,
                timing: DelayedLoadingTiming(delayBeforeHint: .zero, minimumHintVisible: minimum)
            ))
            defer { close(window) }

            let shownSeen = await waitUntil { recorder.firstShown != nil }
            try #require(shownSeen, "Ladehinweis erscheint nicht: \(recorder.events.map(\.visible))")
            let shown = try #require(recorder.firstShown)

            let finishedAt = ContinuousClock.now
            model.isLoading = false
            let hiddenSeen = await waitUntil { recorder.firstHidden(after: finishedAt) != nil }
            try #require(hiddenSeen, "Ladehinweis verschwindet nicht")
            let hidden = try #require(recorder.firstHidden(after: finishedAt))

            // Untergrenze statt Zeitfenster: Last kann das Ausblenden nur verzögern, nie verfrühen.
            #expect(shown.duration(to: hidden) >= minimum - .milliseconds(5),
                    "sichtbar nur \(shown.duration(to: hidden)) statt mindestens \(minimum)")
        }

        @Test func reloadDuringMinimumKeepsHintWithoutGap() async throws {
            // Verzögerung (300 ms) größer als die kurze Lücke bis zum Neustart: Ohne Fortsetzen würde der
            // Hinweis am Ende der Mindestanzeige ausgeblendet und erst nach 300 ms wieder gezeigt.
            let model = LoadSwitch()
            let recorder = HintRecorder()
            // bug.0.4.192: Das Tor hält das Ende der Mindestanzeige fest, bis der Neustart in der Ansicht ist (unter Last lief
            // die Mindestanzeige sonst vorher ab – „Test prüft nichts“).
            let gate = SurfaceAsyncSignal()
            var timing = DelayedLoadingTiming(delayBeforeHint: .milliseconds(300), minimumHintVisible: .milliseconds(1_500))
            timing.minimumEndGate = { await gate.wait() }
            let window = open(LoadingHarness(model: model, recorder: recorder, timing: timing))
            defer { close(window) }
            defer { Task { await gate.signal() } }

            let shownSeen = await waitUntil { recorder.last == true }
            try #require(shownSeen, "Ladehinweis erscheint nicht")

            // bug.0.4.068 b): erst weiter, wenn das Ladeende wirklich in der Ansicht ankam; sonst würden beide
            // Änderungen zusammengefasst und `resumeLoading` nie gebraucht (Test grün ohne Beleg).
            let endsBefore = recorder.loadingEndsSeen
            let startsBefore = recorder.loadingStartsSeen
            model.isLoading = false
            let endSeen = await waitUntil { recorder.loadingEndsSeen > endsBefore }
            try #require(endSeen, "isLoading == false kam in der Ansicht nicht an")
            try #require(recorder.last == true, "Hinweis schon vor dem Neustart ausgeblendet: \(recorder.events.map(\.visible))")
            model.isLoading = true
            let restartedAt = ContinuousClock.now
            let restartSeen = await waitUntil { recorder.loadingStartsSeen > startsBefore }
            try #require(restartSeen, "isLoading == true kam in der Ansicht nicht an")
            await gate.signal()

            // Über das Ende der Mindestanzeige (1,5 s ab Erscheinen) hinaus laden lassen. Die lange Mindestanzeige
            // lässt Reserve, damit der Hinweis unter Last vor dem Neustart noch steht (bug.0.4.068 b, Regel 20).
            try? await Task.sleep(for: .milliseconds(1_900))
            let gap = recorder.firstHidden(after: restartedAt)
            #expect(gap == nil, "Hinweis während erneuten Ladens ausgeblendet: \(recorder.events.map(\.visible))")
            #expect(recorder.last == true)
            model.isLoading = false
        }

        /// `ColumnBrowserView` nutzt für Laden und Liste ein Exemplar: Der Hinweis der Ordnerspalte bleibt nach
        /// dem Ladeende stehen (Mindestanzeige), statt mit dem Lade-Exemplar sofort zu verschwinden.
        @Test func folderColumnKeepsHintAfterLoadingEnds() async throws {
            let app = AppState()
            let mediumID = UUID()
            var medium = Medium(
                id: mediumID,
                name: "Langsam",
                type: .ssd,
                connectionStatus: .connected,
                indexStatus: .indexed,
                allowIndexing: true,
                autoIndexPaused: false,
                capacityTotalBytes: 1_000,
                capacityUsedBytes: 10,
                fileCount: 20_000,
                folderCount: 0,
                lastSeenAt: Date(),
                firstIndexedAt: Date(),
                lastIndexedAt: Date(),
                isForgotten: false,
                indexingProgress: 1
            )
            medium.completedDepth = 2
            app.media = [medium]
            app.columnBrowserState.selectedMediumID = mediumID
            app.indexRepository.setLoadingForUITest(mediumID: mediumID, path: [], loading: true, total: 20_000)
            let size = CGSize(width: 1040, height: 600)
            let session = PixelProbe.open(
                ColumnBrowserView().environment(app).environment(\.colorScheme, .light).frame(width: size.width, height: size.height),
                size: size,
                appearance: .aqua
            )
            defer { session.close() }

            func hint() -> Bool {
                session.window.contentView?.layoutSubtreeIfNeeded()
                return app.columnBrowserState.loadingHintVisible(mediumID: mediumID, path: [])
            }
            let shown = await waitUntil { hint() }
            try #require(shown, "Ladehinweis der Spalte erscheint nicht")

            app.indexRepository.setLoadingForUITest(mediumID: mediumID, path: [], loading: false)
            let finishedAt = ContinuousClock.now
            var hiddenAt: ContinuousClock.Instant?
            let hidden = await waitUntil {
                if !hint() { hiddenAt = .now }
                return hiddenAt != nil
            }
            try #require(hidden, "Ladehinweis verschwindet nicht")
            let end = try #require(hiddenAt)
            // Zwei Exemplare: sofort weg (< 50 ms). Ein Exemplar: Rest der 400 ms; Untergrenze mit Reserve
            // für die Erkennungsverzögerung.
            #expect(finishedAt.duration(to: end) >= .milliseconds(100), "ausgeblendet nach \(finishedAt.duration(to: end))")
        }
    }
}
