//
//  ColumnFolderTableView.swift
//  diskindex
//
//  Aufgabe 107/122/137 — NSTableView ab Schwelle. Breite an Scroll-Viewport binden.
//

import AppKit
import SwiftUI

struct ColumnFolderTableView<Row: View>: NSViewRepresentable {
    @Environment(AppState.self) private var appState

    let items: [IndexedItem]
    let selectedIDs: Set<UUID>
    /// bug.0.4.132: nach einer Nutzeraktion die gewählte Zeile in die Sicht holen.
    var scrollTarget = ColumnScrollTarget()
    @ViewBuilder var row: (IndexedItem) -> Row

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        // Systemleiste wie in allen langen Listen (README „Spaltenansicht: Scrollen“): Overlay oder dauerhaft nach
        // Systemeinstellung, nur bei Überlänge.
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.hasHorizontalScroller = false
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.postsBoundsChangedNotifications = true
        scroll.contentView.postsBoundsChangedNotifications = true
        scroll.contentView.postsFrameChangedNotifications = true

        let table = NSTableView()
        table.headerView = nil
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .none
        table.rowHeight = 32
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.style = .plain
        table.usesAlternatingRowBackgroundColors = false
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        let column = NSTableColumn(identifier: .init("row"))
        column.minWidth = 40
        column.resizingMask = [.autoresizingMask, .userResizingMask]
        table.addTableColumn(column)

        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        context.coordinator.tableView = table
        context.coordinator.scrollView = scroll
        context.coordinator.items = items
        context.coordinator.selectedIDs = selectedIDs
        context.coordinator.rowBuilder = makeRowBuilder()
        context.coordinator.itemIDs = items.map(\.id)
        context.coordinator.observeScrollSizing(scroll)

        scroll.documentView = table
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.rowBuilder = makeRowBuilder()
        coordinator.scrollView = scroll
        let table = coordinator.tableView
        let newIDs = items.map(\.id)
        let idsChanged = coordinator.itemIDs != newIDs
        let selectionChanged = coordinator.selectedIDs != selectedIDs
        // bug.0.4.037 (REPORT 103): gleiche Kennungen, aber geänderte Werte (z. B. Favorit umgeschaltet) → sichtbare
        // Zeilen neu bauen, sonst zeigt die Tabelle den alten Stand.
        let valuesChanged = !idsChanged && coordinator.items != items
        let wasEmpty = coordinator.items.isEmpty
        coordinator.items = items
        coordinator.selectedIDs = selectedIDs
        coordinator.itemIDs = newIDs
        // Immer Breite zuerst — sonst bleiben Zeilen bei Spaltenbreite 0 unsichtbar.
        coordinator.syncColumnWidth()
        if idsChanged || (wasEmpty && !items.isEmpty) || (table?.numberOfRows ?? 0) != items.count {
            table?.noteNumberOfRowsChanged()
            table?.reloadData()
        } else if selectionChanged || valuesChanged {
            table?.enumerateAvailableRowViews { rowView, rowIndex in
                guard items.indices.contains(rowIndex),
                      let host = rowView.view(atColumn: 0) as? NSHostingView<AnyView>,
                      let builder = coordinator.rowBuilder else { return }
                host.rootView = builder(items[rowIndex])
            }
        }
        coordinator.syncColumnWidth()
        coordinator.syncSelection()
        if let id = scrollTarget.id, coordinator.scrolledToken != scrollTarget.token,
           let row = items.firstIndex(where: { $0.id == id }) {
            coordinator.scrolledToken = scrollTarget.token
            table?.scrollRowToVisible(row)
        }
    }

    private func makeRowBuilder() -> (IndexedItem) -> AnyView {
        let appState = appState
        return { item in
            AnyView(
                row(item)
                    .environment(appState)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var items: [IndexedItem] = []
        var itemIDs: [UUID] = []
        var selectedIDs: Set<UUID> = []
        var scrolledToken: Int?
        var rowBuilder: ((IndexedItem) -> AnyView)?
        weak var tableView: NSTableView?
        weak var scrollView: NSScrollView?
        private var sizingObservers: [NSObjectProtocol] = []

        deinit {
            for token in sizingObservers {
                NotificationCenter.default.removeObserver(token)
            }
        }

        func observeScrollSizing(_ scroll: NSScrollView) {
            for token in sizingObservers {
                NotificationCenter.default.removeObserver(token)
            }
            sizingObservers.removeAll()
            let handler: (Notification) -> Void = { [weak self] _ in
                self?.syncColumnWidth()
            }
            sizingObservers.append(
                NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: scroll.contentView,
                    queue: nil,
                    using: handler
                )
            )
            sizingObservers.append(
                NotificationCenter.default.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: scroll,
                    queue: nil,
                    using: handler
                )
            )
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            items.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard items.indices.contains(row), let rowBuilder else { return nil }
            let item = items[row]
            let identifier = NSUserInterfaceItemIdentifier("ColumnFolderRow")
            let hosting: NSHostingView<AnyView>
            if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSHostingView<AnyView> {
                hosting = reused
                hosting.rootView = rowBuilder(item)
            } else {
                hosting = NSHostingView(rootView: rowBuilder(item))
                hosting.identifier = identifier
            }
            let width = max(tableView.bounds.width, tableColumn?.width ?? 0, 1)
            hosting.setFrameSize(NSSize(width: width, height: 32))
            hosting.autoresizingMask = [.width]
            return hosting
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            32
        }

        func syncColumnWidth() {
            guard let tableView, let scrollView else { return }
            let width = max(
                1,
                scrollView.contentView.bounds.width,
                scrollView.bounds.width,
                scrollView.contentSize.width
            )
            if let column = tableView.tableColumns.first, abs(column.width - width) > 0.5 {
                column.width = width
            }
            if abs(tableView.frame.width - width) > 0.5 {
                var frame = tableView.frame
                frame.size.width = width
                tableView.frame = frame
            }
            tableView.sizeLastColumnToFit()
            tableView.tile()
        }

        func syncSelection() {
            guard let tableView else { return }
            let indexes = IndexSet(items.indices.filter { selectedIDs.contains(items[$0].id) })
            if tableView.selectedRowIndexes != indexes {
                tableView.selectRowIndexes(indexes, byExtendingSelection: false)
            }
        }
    }
}
