//
//  ObjectResultsTable.swift
//  diskindex
//
//  Gemeinsame Objekt-Tabelle für Suche (Screen 07) und Favoriten (19.12).
//  Spaltenbreiten werden einmal pro Tabelle berechnet und identisch an Kopf und Zeilen gegeben (Aufgabe 22.8).
//

import SwiftUI

/// Spaltenbreiten: feste Spalten + Name/Pfad teilen sich den Rest 1 : 1.
struct ObjectTableColumns {
    static let icon: CGFloat = 36
    static let date: CGFloat = 110
    static let medium: CGFloat = 140
    static let status: CGFloat = 100
    static let horizontalPadding: CGFloat = 16
    private static let nameMin: CGFloat = 160
    private static let pathMin: CGFloat = 140

    let name: CGFloat
    let path: CGFloat

    init(totalWidth: CGFloat) {
        let fixed = Self.icon + Self.date + Self.medium + Self.status + 2 * Self.horizontalPadding
        let half = max(0, totalWidth - fixed) / 2
        name = max(Self.nameMin, half)
        path = max(Self.pathMin, half)
    }
}

struct ObjectResultsTable<Placeholder: View>: View {
    let results: [SearchResultItem]
    /// Mit `sort` sind alle Spaltenköpfe klickbar und die Zeilen werden sortiert.
    var sort: Binding<SearchSort>?
    @ViewBuilder var placeholder: () -> Placeholder

    @Environment(AppState.self) private var appState

    var body: some View {
        GeometryReader { proxy in
            let columns = ObjectTableColumns(totalWidth: proxy.size.width)
            let rows = sortedResults

            ScrollView {
                VStack(spacing: 0) {
                    ObjectResultsTableHeader(columns: columns, sort: sort)
                    if rows.isEmpty {
                        placeholder()
                    } else {
                        ForEach(rows) { result in
                            ObjectResultRow(result: result, columns: columns, isLast: result.id == rows.last?.id)
                        }
                    }
                }
            }
        }
    }

    private var sortedResults: [SearchResultItem] {
        guard let sort = sort?.wrappedValue else { return results }
        let mediumNames = Dictionary(appState.media.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return sort.sorted(results, mediumNames: mediumNames)
    }
}

extension SearchSort {
    func sorted(_ items: [SearchResultItem], mediumNames: [UUID: String]) -> [SearchResultItem] {
        func ascending(_ lhs: String, _ rhs: String) -> Bool {
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        return items.sorted { lhs, rhs in
            let ordered: Bool
            switch column {
            case .name:
                ordered = ascending(lhs.name, rhs.name)
            case .date:
                ordered = (lhs.date ?? .distantPast) < (rhs.date ?? .distantPast)
            case .medium:
                ordered = ascending(mediumNames[lhs.mediumID] ?? "", mediumNames[rhs.mediumID] ?? "")
            case .path:
                ordered = ascending(lhs.path, rhs.path)
            case .status:
                ordered = lhs.isOnline == rhs.isOnline ? ascending(lhs.name, rhs.name) : lhs.isOnline
            }
            return direction == .ascending ? ordered : !ordered
        }
    }
}

private struct ObjectResultsTableHeader: View {
    let columns: ObjectTableColumns
    var sort: Binding<SearchSort>?

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: ObjectTableColumns.icon)
            header("Name", column: .name).frame(width: columns.name, alignment: .leading)
            header("Datum", column: .date).frame(width: ObjectTableColumns.date, alignment: .leading)
            header("Speichermedium", column: .medium).frame(width: ObjectTableColumns.medium, alignment: .leading)
            header("Pfad", column: .path).frame(width: columns.path, alignment: .leading)
            header("Status", column: .status).frame(width: ObjectTableColumns.status, alignment: .trailing)
        }
        .padding(.horizontal, ObjectTableColumns.horizontalPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignColor.neutral100)
    }

    @ViewBuilder
    private func header(_ title: String, column: SearchSortColumn) -> some View {
        if let sort {
            TableSortHeader(title: title, isActive: sort.wrappedValue.column == column) {
                sort.wrappedValue.toggle(column)
            }
        } else {
            TableSortHeader.label(title, isActive: false)
        }
    }
}

private struct ObjectResultRow: View {
    @Environment(AppState.self) private var appState
    let result: SearchResultItem
    let columns: ObjectTableColumns
    let isLast: Bool

    @State private var isHovered = false

    var body: some View {
        Button {
            appState.contextMenuHighlightObjectID = nil
            MediumNavigation.openObject(result, appState: appState)
        } label: {
            HStack(spacing: 0) {
                FileTypeIcon(
                    kind: result.item.fileKind,
                    size: 16,
                    color: result.item.isFavorite ? DesignColor.favorite : DesignColor.text
                )
                .frame(width: ObjectTableColumns.icon)

                HStack(spacing: 4) {
                    Text(result.name)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(width: columns.name, alignment: .leading)

                Text(result.date?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                    .foregroundStyle(DesignColor.text.opacity(0.55))
                    .lineLimit(1)
                    .frame(width: ObjectTableColumns.date, alignment: .leading)

                Text(appState.medium(with: result.mediumID)?.name ?? "—")
                    .lineLimit(1)
                    .frame(width: ObjectTableColumns.medium, alignment: .leading)

                Text(result.path)
                    .foregroundStyle(DesignColor.text.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(width: columns.path, alignment: .leading)

                ObjectRowOnlineStatusChip(isOnline: result.isOnline)
                    .frame(width: ObjectTableColumns.status, alignment: .trailing)
            }
            .font(.system(size: 13))
            .padding(.horizontal, ObjectTableColumns.horizontalPadding)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? DesignColor.neutral100 : Color.clear)
        }
        .buttonStyle(.plainFullHit)
        .pointerCursor()
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(DesignColor.neutral200).frame(height: DesignBorder.width)
            }
        }
        .onHover { isHovered = $0 }
        .objectContextMenu(.fromSearchResult(result))
    }
}

/// Umbrechende Medium-Kacheln über der Tabelle (Suche, Favoriten; Layout Sektion 10).
struct CompactMediumCardFlow: View {
    let media: [Medium]

    var body: some View {
        FlowLayout(spacing: 12) {
            ForEach(media) { medium in
                SearchCompactMediumCard(medium: medium)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DesignColor.neutral300).frame(height: DesignBorder.width)
        }
    }
}
