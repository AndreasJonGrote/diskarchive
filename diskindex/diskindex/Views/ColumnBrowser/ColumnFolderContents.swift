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
    @ViewBuilder var row: (IndexedItem) -> Row

    @State private var delayed = DelayedLoadingState()

    private var pathKey: String {
        ([mediumID.uuidString] + path).joined(separator: "\u{0}")
    }

    private var usesTableView: Bool {
        filteredItems.count >= tableViewMinimum
    }

    private var hintVisible: Bool {
        if isLoading, !delayed.isActive {
            syncDelayedState()
        }
        delayed.catchUpToClock()
        return isLoading && (delayed.showsHint || loadingTiming.delayBeforeHint == .zero)
    }

    var body: some View {
        Group {
            if isLoading {
                if hintVisible {
                    FolderContentsLoadingHint(loaded: loaded, total: total)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else if usesTableView {
                ColumnFolderTableView(items: filteredItems, selectedIDs: selectedIDs, row: row)
                    .padding(.horizontal, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredItems) { item in
                            row(item)
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollIndicators(.automatic)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            syncDelayedState()
            onLoadingHintVisible(hintVisible)
        }
        .onChange(of: pathKey) { _, _ in
            delayed.reset()
            syncDelayedState()
        }
        .onChange(of: isLoading) { _, _ in syncDelayedState() }
        .onChange(of: hintVisible) { _, visible in
            onLoadingHintVisible(visible)
        }
        .onChange(of: loaded) { _, _ in delayed.updateProgress(loaded: loaded, total: total) }
        .onChange(of: total) { _, _ in delayed.updateProgress(loaded: loaded, total: total) }
        .onChange(of: loadingTiming) { _, timing in
            delayed = DelayedLoadingState(timing: timing)
            syncDelayedState()
        }
    }

    private func syncDelayedState() {
        delayed.updateProgress(loaded: loaded, total: total)
        if isLoading {
            if !delayed.isActive {
                delayed.beginLoading(total: total)
            }
        } else {
            delayed.finishLoading()
        }
    }
}
