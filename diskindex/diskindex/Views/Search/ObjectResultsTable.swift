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
    /// bug.0.4.038: Spalten, nach denen `results` schon sortiert ankommen (Datenbank); sie werden nicht nachsortiert.
    var serverSortedColumns: Set<SearchSortColumn> = []
    /// `false`: Pfad und Status (Spalten außerhalb von `serverSortedColumns`, außer Name) sind nicht sortierbar (Kopf
    /// deaktiviert), weil nicht alle Treffer auf der Seite stehen. Name bleibt klickbar: die Abfrage wählt die Seite nach
    /// Name, der Client sortiert sie natürlich nach.
    var clientSortAvailable = true
    @ViewBuilder var placeholder: () -> Placeholder

    @Environment(AppState.self) private var appState

    var body: some View {
        // bug.0.4.040 (REPORT 86): Mediennamen, Verbindung und Favoriten einmal je Body; die Zeilen bekommen nur Werte und
        // beobachten `media` nicht (ein Fortschritts-Tick baut sie nicht neu).
        let media = appState.media
        let mediumNames = Dictionary(media.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let online = Dictionary(media.map { ($0.id, $0.connectionStatus == .connected) }, uniquingKeysWith: { first, _ in first })
        let favorites = appState.favoriteLookup
        let rows = sortedResults(mediumNames: mediumNames, online: online)
        let lastID = rows.last?.id

        // Kein `GeometryReader` um die ScrollView (212: im Legacy-Stil läge die Leiste hinter dem Fensterrand) und keine
        // Breitenmessung (218: kam als 0 an). Die Spaltenbreiten bestimmt `ObjectTableRowLayout` aus der Zeilenbreite.
        ScrollView {
            LazyVStack(spacing: 0) {
                ObjectResultsTableHeader(sort: sort, isSortable: isSortable)
                if rows.isEmpty {
                    placeholder()
                } else {
                    ForEach(rows) { result in
                        ObjectResultRow(
                            result: result,
                            mediumName: mediumNames[result.mediumID] ?? "—",
                            isOnline: online[result.mediumID] ?? false,
                            isFavorite: favorites.isFavorite(rowID: result.item.rowID, fallback: result.item.isFavorite),
                            isLast: result.id == lastID
                        )
                        .equatable()
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func isSortable(_ column: SearchSortColumn) -> Bool {
        ObjectResultsOrdering.isSortable(column, serverSortedColumns: serverSortedColumns, clientSortAvailable: clientSortAvailable)
    }

    private func sortedResults(mediumNames: [UUID: String], online: [UUID: Bool]) -> [SearchResultItem] {
        guard let sort = sort?.wrappedValue else { return results }
        return ObjectResultsOrdering.rows(
            results,
            sort: sort,
            serverSortedColumns: serverSortedColumns,
            clientSortAvailable: clientSortAvailable,
            mediumNames: mediumNames,
            online: online
        )
    }
}

/// Reihenfolge der angezeigten Zeilen (eine Quelle für Tabelle und Test, bug.0.4.038).
enum ObjectResultsOrdering {
    static func isSortable(_ column: SearchSortColumn, serverSortedColumns: Set<SearchSortColumn>, clientSortAvailable: Bool) -> Bool {
        serverSortedColumns.contains(column) || column == .name || clientSortAvailable
    }

    /// Spalten in `serverSortedColumns` kommen fertig sortiert; Name wird immer (natürlich) nachsortiert, Pfad und
    /// Status nur, wenn alle Treffer auf der Seite stehen.
    static func rows(
        _ results: [SearchResultItem],
        sort: SearchSort,
        serverSortedColumns: Set<SearchSortColumn>,
        clientSortAvailable: Bool,
        mediumNames: [UUID: String],
        online: [UUID: Bool] = [:]
    ) -> [SearchResultItem] {
        if serverSortedColumns.contains(sort.column) { return results }
        guard sort.column == .name || clientSortAvailable else { return results }
        return sort.sorted(results, mediumNames: mediumNames, online: online)
    }
}

extension SearchSort {
    /// - Parameter online: `mediumID → angeschlossen` (bug.0.4.037: abgeleitet, nicht in der Zeile gespeichert).
    func sorted(_ items: [SearchResultItem], mediumNames: [UUID: String], online: [UUID: Bool] = [:]) -> [SearchResultItem] {
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
                let left = online[lhs.mediumID] ?? false
                let right = online[rhs.mediumID] ?? false
                ordered = left == right ? ascending(lhs.name, rhs.name) : left
            }
            return direction == .ascending ? ordered : !ordered
        }
    }
}

private struct ObjectResultsTableHeader: View {
    var sort: Binding<SearchSort>?
    var isSortable: (SearchSortColumn) -> Bool = { _ in true }

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
            let enabled = isSortable(column)
            TableSortHeader(title: title, isActive: enabled && sort.wrappedValue.column == column, isEnabled: enabled) {
                sort.wrappedValue.toggle(column)
            }
        } else {
            TableSortHeader.label(title, isActive: false)
        }
    }
}

/// Eine Zeile der Objekt-Tabelle. Bekommt Mediumname, Verbindung und Favorit als Werte (bug.0.4.040) und vergleicht
/// sich über sie: ändert ein Fortschritts-Tick nur Zähler eines Mediums, bleibt der Body der Zeile unberührt.
private struct ObjectResultRow: View, Equatable {
    @Environment(AppState.self) private var appState
    #if DEBUG
    @Environment(\.objectRowRenderProbe) private var renderProbe
    #endif
    let result: SearchResultItem
    let mediumName: String
    let isOnline: Bool
    let isFavorite: Bool
    let isLast: Bool

    @State private var isHovered = false

    static func == (lhs: ObjectResultRow, rhs: ObjectResultRow) -> Bool {
        lhs.result == rhs.result && lhs.mediumName == rhs.mediumName && lhs.isOnline == rhs.isOnline
            && lhs.isFavorite == rhs.isFavorite && lhs.isLast == rhs.isLast
    }

    var body: some View {
        #if DEBUG
        renderProbe?.noteRowBody()
        #endif
        return Button {
            appState.contextMenuHighlightObjectID = nil
            MediumNavigation.openObject(result, appState: appState)
        } label: {
            ObjectTableRowLayout {
                FileTypeIcon(
                    kind: result.item.fileKind,
                    size: 16,
                    color: isFavorite ? DesignColor.favorite : DesignColor.text
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

                Text(mediumName)
                    .lineLimit(1)
                    .frame(width: ObjectTableColumns.medium, alignment: .leading)

                Text(result.path)
                    .foregroundStyle(DesignColor.text.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ObjectRowOnlineStatusChip(isOnline: isOnline)
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
        .objectContextMenu(contextTarget)
    }

    /// Ziel mit dem aktuellen Favoriten-Stand der Zeile.
    private var contextTarget: ObjectContextTarget {
        var target = ObjectContextTarget.fromSearchResult(result)
        target.isFavorite = isFavorite
        return target
    }
}

#if DEBUG
/// Tests (bug.0.4.040): zählt Body-Auswertungen der Tabellenzeilen. Je Test eine eigene Instanz über die Umgebung,
/// kein prozessweiter Zähler (Regel 20). Ohne Probe (App) passiert nichts.
final class ObjectRowRenderProbe {
    private(set) var rowBodies = 0

    func noteRowBody() {
        rowBodies += 1
    }
}

private struct ObjectRowRenderProbeKey: EnvironmentKey {
    static let defaultValue: ObjectRowRenderProbe? = nil
}

extension EnvironmentValues {
    var objectRowRenderProbe: ObjectRowRenderProbe? {
        get { self[ObjectRowRenderProbeKey.self] }
        set { self[ObjectRowRenderProbeKey.self] = newValue }
    }
}
#endif

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
