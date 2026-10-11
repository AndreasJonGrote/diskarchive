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

    /// Breiten der sechs Zellen (Icon, Name, Datum, Medium, Pfad, Status) bei gegebener Breite **innerhalb** des
    /// seitlichen Innenabstands.
    static func cellWidths(contentWidth: CGFloat) -> [CGFloat] {
        let columns = ObjectTableColumns(totalWidth: contentWidth + 2 * horizontalPadding)
        return [icon, columns.name, date, medium, columns.path, status]
    }
}

/// Verteilt die Breite der Tabellenzeile auf die Spalten: Name und Pfad teilen den freien Platz, die übrigen sind
/// fest. Die Breite kommt vom Layout-System (nicht aus einer Messung), daher gilt sie auch in einer `ScrollView`
/// und im Legacy-Stil (Leistenbreite ist schon abgezogen).
struct ObjectTableRowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let fixedMinimum = ObjectTableColumns.cellWidths(contentWidth: 0).reduce(0, +)
        let width = proposal.width ?? fixedMinimum
        let widths = ObjectTableColumns.cellWidths(contentWidth: width)
        var height: CGFloat = 0
        for (index, subview) in subviews.enumerated() where index < widths.count {
            height = max(height, subview.sizeThatFits(ProposedViewSize(width: widths[index], height: nil)).height)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = ObjectTableColumns.cellWidths(contentWidth: bounds.width)
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() where index < widths.count {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: widths[index], height: bounds.height)
            )
            x += widths[index]
        }
    }
}

struct ObjectResultsTable<Placeholder: View>: View {
    let results: [SearchResultItem]
    /// Mit `sort` sind alle Spaltenköpfe klickbar und die Zeilen werden sortiert.
    var sort: Binding<SearchSort>?
    @ViewBuilder var placeholder: () -> Placeholder

    @Environment(AppState.self) private var appState

    var body: some View {
        let rows = sortedResults

        // Kein `GeometryReader` um die ScrollView (212: im Legacy-Stil läge die Leiste hinter dem Fensterrand) und keine
        // Breitenmessung (218: kam als 0 an). Die Spaltenbreiten bestimmt `ObjectTableRowLayout` aus der Zeilenbreite.
        ScrollView {
            VStack(spacing: 0) {
                ObjectResultsTableHeader(sort: sort)
                if rows.isEmpty {
                    placeholder()
                } else {
                    ForEach(rows) { result in
                        ObjectResultRow(result: result, isLast: result.id == rows.last?.id)
                    }
                }
            }
            .frame(maxWidth: .infinity)
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
    var sort: Binding<SearchSort>?

    var body: some View {
        ObjectTableRowLayout {
            Color.clear.frame(width: ObjectTableColumns.icon)
            header(LayoutCopy.tableName, column: .name).frame(maxWidth: .infinity, alignment: .leading)
            header(LayoutCopy.tableDate, column: .date).frame(width: ObjectTableColumns.date, alignment: .leading)
            header(LayoutCopy.tableMedium, column: .medium).frame(width: ObjectTableColumns.medium, alignment: .leading)
            header(LayoutCopy.tablePath, column: .path).frame(maxWidth: .infinity, alignment: .leading)
            header(LayoutCopy.tableStatus, column: .status).frame(width: ObjectTableColumns.status, alignment: .trailing)
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
    let isLast: Bool

    @State private var isHovered = false

    var body: some View {
        Button {
            appState.contextMenuHighlightObjectID = nil
            MediumNavigation.openObject(result, appState: appState)
        } label: {
            ObjectTableRowLayout {
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
                .frame(maxWidth: .infinity, alignment: .leading)

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
                    .frame(maxWidth: .infinity, alignment: .leading)

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
