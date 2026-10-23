//
//  ColumnFolderContents.swift
//  diskindex
//
//  Ladehinweis mit 1-s-Verzögerung (T1 / Layout 07).
//  Normalfall LazyVStack; NSTableView ab 5.000 Einträgen (Aufgabe 122).
//

import SwiftUI

enum ColumnFolderListThreshold {
    /// Ab dieser Anzahl Zeilen: NSTableView, darunter LazyVStack.
    /// Aufgabe 137: 50.000, damit 14.300 wieder über LazyVStack laufen, bis die Tabelle sicher ist.
    static let tableViewMinimum = 50_000
}

private struct ColumnTableViewMinimumKey: EnvironmentKey {
    static let defaultValue = ColumnFolderListThreshold.tableViewMinimum
}

extension EnvironmentValues {
    /// Schwelle Liste/Tabelle der Spaltenansicht (nur Tests senken sie, bug.0.4.132).
    var columnTableViewMinimum: Int {
        get { self[ColumnTableViewMinimumKey.self] }
        set { self[ColumnTableViewMinimumKey.self] = newValue }
    }
}

/// bug.0.4.132: Senkrecht zu `id` scrollen, wenn `token` neu ist (Nutzeraktion, nicht bei Live-Änderungen).
struct ColumnScrollTarget: Equatable {
    var id: UUID?
    var token: Int = 0
}

struct ColumnFolderContents<Row: View>: View {
    let mediumID: UUID
    let path: [String]
    let filteredItems: [IndexedItem]
    let selectedIDs: Set<UUID>
    let isLoading: Bool
    let loaded: Int
    let total: Int
    /// Demo „Beispiel 3“: Hinweis sofort bei jedem Öffnen (ohne 1-s-Verzögerung).
    var loadingTiming: DelayedLoadingTiming = .standard
    /// Tests können die Schwelle senken, ohne den globalen Wert zu ändern.
    var tableViewMinimum: Int = ColumnFolderListThreshold.tableViewMinimum
    /// Sichtbarkeit des Ladehinweises nach oben (Spaltenbreite, Aufgabe 156).
    var onLoadingHintVisible: (Bool) -> Void = { _ in }
    /// Abstand nur um den Ladehinweis (vorher eigenes Exemplar mit Innenabstand in der Spalte, bug.0.4.061).
    var hintInsets = EdgeInsets()
    /// bug.0.4.132: Auswahl dieser Spalte, zu der nach einer Nutzeraktion gescrollt wird.
    var scrollTarget = ColumnScrollTarget()
    @ViewBuilder var row: (IndexedItem) -> Row

    @State private var delayed = DelayedLoadingState()
    /// Zeitvorgabe von `delayed`; eine neue Vorgabe gilt erst, wenn kein Ladevorgang und keine Mindestanzeige läuft.
    @State private var stateTiming: DelayedLoadingTiming = .standard
    /// Beginn des laufenden Ladevorgangs, für das Nachziehen der Verzögerung ohne Schreiben beim Zeichnen.
    @State private var loadStartedAt: ContinuousClock.Instant?
    /// Zuletzt ausgeführter Scroll-Auftrag (je Auftrag einmal, sobald die Zeile da ist).
    @State private var scrolledToken: Int?
    /// Erledigter Auftrag der Tabelle; lebt hier, nicht in der (ersetzbaren) Tabellenansicht (bug.0.4.148 b).
    @State private var scrollDone = ScrollTokenBox()

    private var pathKey: String {
        ([mediumID.uuidString] + path).joined(separator: "\u{0}")
    }

    private var usesTableView: Bool {
        filteredItems.count >= tableViewMinimum
    }

    /// bug.0.4.132: Ein Scroll-Auftrag steht aus und die Zeile ist geladen.
    private var pendingScroll: Bool {
        guard scrollTarget.token > 0, let id = scrollTarget.id, scrollTarget.token != scrolledToken, !isLoading else { return false }
        return filteredItems.contains { $0.id == id }
    }

    /// Rein lesend (bug.0.4.061): Der Zustand wird in `.task`/`onChange` nachgeführt, nicht beim Zeichnen.
    /// Nach dem Ladeende bleibt der Hinweis bis zum Ablauf der Mindestanzeige stehen.
    private var hintVisible: Bool {
        delayed.showsHint || (isLoading && loadingTiming.delayBeforeHint == .zero)
    }

    /// Rein lesend: Die Verzögerung ist abgelaufen, der Hinweis aber noch nicht gesetzt (Takt lief nicht,
    /// z. B. weil der Hauptthread eine verschachtelte RunLoop dreht). Nachgezogen wird in `onChange`.
    private var catchUpDue: Bool {
        guard isLoading, !delayed.showsHint, let loadStartedAt else { return false }
        return loadStartedAt.duration(to: .now) >= stateTiming.delayBeforeHint
    }

    var body: some View {
        Group {
            if hintVisible {
                FolderContentsLoadingHint(loaded: loaded, total: total)
                    .padding(hintInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if isLoading {
                Color.clear
            } else if usesTableView {
                ColumnFolderTableView(items: filteredItems, selectedIDs: selectedIDs, scrollTarget: scrollTarget, scrollDone: scrollDone, row: row)
                    .padding(.horizontal, 8)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredItems) { item in
                                row(item)
                                    // bug.0.4.088: ausgeblendete Einträge gleiten kurz weg, wieder freigegebene erscheinen.
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .scrollIndicators(.automatic)
                    .onChange(of: pendingScroll, initial: true) { _, pending in
                        guard pending, let id = scrollTarget.id else { return }
                        scrolledToken = scrollTarget.token
                        proxy.scrollTo(id)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // `onChange(initial:)` statt `.task`: läuft im selben Durchgang wie das Erscheinen, auch wenn der
        // Hauptthread gerade eine verschachtelte RunLoop dreht (Fenstertests).
        .onChange(of: isLoading, initial: true) { _, _ in
            syncDelayedState()
            onLoadingHintVisible(hintVisible)
        }
        .onChange(of: catchUpDue) { _, due in
            if due { delayed.catchUpToClock() }
        }
        .onChange(of: pathKey) { _, _ in
            delayed.reset()
            syncDelayedState()
        }
        .onChange(of: hintVisible) { _, visible in
            onLoadingHintVisible(visible)
        }
        // bug.0.4.090: Wechselt die Spalte auf einen anderen Zweig (Fehler, „wird indiziert“) oder verschwindet sie,
        // während der Ladehinweis steht, bliebe der gemeldete Hinweis sonst für immer stehen (Spalte füllt die
        // Restbreite, keine Trennlinie, keine Details), bis ein neues Laden ihn zurücknimmt.
        .onDisappear {
            onLoadingHintVisible(false)
        }
        .onChange(of: loaded) { _, _ in delayed.updateProgress(loaded: loaded, total: total) }
        .onChange(of: total) { _, _ in delayed.updateProgress(loaded: loaded, total: total) }
        .onChange(of: loadingTiming) { _, _ in
            if !delayed.isActive { syncDelayedState() }
        }
        // Ende der Mindestanzeige: neue Zeitvorgabe übernehmen bzw. einen inzwischen neu begonnenen Ladevorgang starten.
        .onChange(of: delayed.isActive) { _, active in
            if !active { syncDelayedState() }
        }
    }

    private func syncDelayedState() {
        if !delayed.isActive, stateTiming != loadingTiming {
            delayed = DelayedLoadingState(timing: loadingTiming)
            stateTiming = loadingTiming
        }
        delayed.updateProgress(loaded: loaded, total: total)
        if isLoading {
            if !delayed.isActive {
                delayed.beginLoading(total: total)
                loadStartedAt = .now
            } else if delayed.isFinishPending {
                // Neues Laden während der Mindestanzeige: Hinweis ohne Lücke weiter zeigen.
                delayed.resumeLoading()
            }
        } else if delayed.isActive, !delayed.isFinishPending {
            loadStartedAt = nil
            delayed.finishLoading()
        }
    }
}
