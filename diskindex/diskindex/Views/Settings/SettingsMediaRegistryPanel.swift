//
//  SettingsMediaRegistryPanel.swift
//  diskindex
//
//  Registry-Tabelle im Tab „Speichermedien“ (19.8).
//  Aufgabe 146 — ohne Medien: gleicher Leerzustand wie Dashboard (keine Chips/Kopf).
//

import SwiftUI

struct SettingsMediaRegistryPanel: View {
    @Environment(AppState.self) private var appState
    @State private var filter: RegistryFilter = .all
    @State private var sort = RegistrySortState()
    private let scrollerStyle = EffectiveScrollerStyle()

    var body: some View {
        if appState.registryMedia.isEmpty {
            EmptyStateView(
                title: EmptyStateCopy.noMediumTitle,
                message: EmptyStateCopy.noMediumMessage,
                iconStyle: .mediaTypes
            )
        } else {
            registryTable
        }
    }

    private var registryTable: some View {
        let rows = sorted(appState.registryMedia.filter { filter.matches($0) })

        return VStack(spacing: 0) {
            filterChipRow
                .padding(.horizontal, RegistryTableLayout.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(DesignColor.bg)

            registryHeader
                // bug.0.4.091: Kopf so breit wie die Zeilen neben dem reservierten Rollbalken.
                .padding(.trailing, ScrollbarGutter.width(for: scrollerStyle.style))

            ScrollView {
                Group {
                    if rows.isEmpty {
                        Text(LayoutCopy.emptyNoMediaTitle)
                            .font(.system(size: 13))
                            .foregroundStyle(DesignColor.text.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(rows) { medium in
                                RegistryTableRow(medium: medium, isLast: medium.id == rows.last?.id)
                            }
                        }
                    }
                }
                .stableScrollbarGutter()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var filterChipRow: some View {
        HStack(spacing: 6) {
            ForEach(RegistryFilter.allCases) { option in
                NeutralFilterChip(title: option.label, isSelected: filter == option) {
                    filter = option
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var registryHeader: some View {
        HStack(spacing: 0) {
            sortHeader(LayoutCopy.tableName, column: .name)
                .frame(maxWidth: .infinity, alignment: .leading)

            sortHeader(LayoutCopy.tableType, column: .type)
                .frame(width: RegistryTableLayout.typeWidth, alignment: .leading)

            TableSortHeader.label(LayoutCopy.tableStatus, isActive: false)
                .frame(width: RegistryTableLayout.statusWidth, alignment: .trailing)
                .padding(.trailing, 6)

            sortHeader(LayoutCopy.index, column: .indexing, alignment: .trailing)
                .frame(width: RegistryTableLayout.indexingWidth, alignment: .trailing)

            Color.clear
                .frame(width: RegistryTableLayout.detailActionWidth, height: 1)
        }
        .padding(.horizontal, RegistryTableLayout.horizontalPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignColor.text.opacity(0.05))
    }

    private func sortHeader(_ title: String, column: RegistrySortColumn, alignment: Alignment = .leading) -> some View {
        TableSortHeader(title: title, isActive: sort.column == column, alignment: alignment) {
            if sort.column == column {
                sort.ascending.toggle()
            } else {
                sort.column = column
                sort.ascending = true
            }
        }
    }

    private func sorted(_ media: [Medium]) -> [Medium] {
        media.sorted { lhs, rhs in
            let ordered: Bool
            switch sort.column {
            case .name:
                ordered = lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .type:
                ordered = lhs.type.rawValue < rhs.type.rawValue
            case .indexing:
                ordered = lhs.allowIndexing && !rhs.allowIndexing
            }
            return sort.ascending ? ordered : !ordered
        }
    }
}
