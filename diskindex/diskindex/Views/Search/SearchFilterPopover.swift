//
//  SearchFilterPopover.swift
//  diskindex
//
//  README Screen 07B / 19.11 — Filter-Popover.
//

import SwiftUI

struct SearchFilterPopover: View {
    @Environment(AppState.self) private var appState
    @State private var mediumFilterQuery = ""
    @State private var extensionInput = ""

    private var showsMediumFilter: Bool {
        appState.mainWindowDestination == .search
    }

    var body: some View {
        let filters = appState.searchStateBinding(\.filters)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 32) {
                fileTypeGroup(filters: filters)
                if showsMediumFilter {
                    mediumGroup(filters: filters)
                }
                ageGroup(filters: filters)
            }
            .padding(24)
        }
    }

    private func fileTypeGroup(filters: Binding<SearchFilters>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            groupHeader(LayoutCopy.searchFilterGroupFileType)

            FlowLayout(spacing: 6) {
                ForEach(SearchFileTypeFilter.allCases) { option in
                    let selected = filters.wrappedValue.fileTypes.contains(option)
                    FilterTypeChipButton(
                        label: option.label,
                        isSelected: selected,
                        isEnabled: option != .folder || !isFolderChipDisabled(filters.wrappedValue)
                    ) {
                        if selected {
                            filters.wrappedValue.fileTypes.remove(option)
                        } else {
                            filters.wrappedValue.fileTypes.insert(option)
                            // „Ordner“ und echte Typen schließen sich aus (Aufgabe 33.4).
                            if option != .folder {
                                filters.wrappedValue.fileTypes.remove(.folder)
                            }
                        }
                    }
                }
            }

            extensionBlock(filters: filters)
                .padding(.top, 8)
        }
        .frame(width: 195, alignment: .leading)
    }

    /// Eigene Dateiendungen (Layout Sektion 09, Aufgabe 32): Enter übernimmt, Chip per ✕ entfernbar.
    private func extensionBlock(filters: Binding<SearchFilters>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            groupHeader(LayoutCopy.searchFilterGroupExtension)

            MediumSidebarSearchField(text: $extensionInput, placeholder: LayoutCopy.searchPlaceholderExtension, icon: "FileTypeGeneric") {
                if filters.wrappedValue.addCustomExtension(extensionInput) {
                    extensionInput = ""
                }
            }

            if !filters.wrappedValue.customExtensions.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(filters.wrappedValue.customExtensions, id: \.self) { ext in
                        FilterValueChip(label: ext) {
                            filters.wrappedValue.customExtensions.removeAll { $0 == ext }
                        }
                    }
                }
            }
        }
    }

    /// „Ordner“ ist nicht wählbar, sobald ein anderer Dateityp oder eine Endung gesetzt ist oder „Und“ aktiv ist.
    private func isFolderChipDisabled(_ filters: SearchFilters) -> Bool {
        !filters.fileTypes.subtracting([.folder]).isEmpty || !filters.customExtensions.isEmpty || filters.combineWithAnd
    }

    /// Gruppenüberschrift wie im Layout: Versalien, 10 pt, Laufweite 0,8, 50 %.
    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10))
            .kerning(0.8)
            .foregroundStyle(DesignColor.text.opacity(0.5))
    }

    private func mediumGroup(filters: Binding<SearchFilters>) -> some View {
        let allMedia = appState.indexedMedia
        let filtered = mediumFilterQuery.isEmpty
            ? allMedia
            : allMedia.filter { $0.name.localizedCaseInsensitiveContains(mediumFilterQuery) }

        return VStack(alignment: .leading, spacing: 8) {
            groupHeader(LayoutCopy.searchFilterGroupMedium)

            MediumSidebarSearchField(text: $mediumFilterQuery, placeholder: LayoutCopy.searchPlaceholderMedium)

            Toggle(isOn: Binding(
                get: { filters.wrappedValue.selectAllMedia },
                set: { isOn in
                    filters.wrappedValue.selectAllMedia = isOn
                    if isOn {
                        filters.wrappedValue.mediumIDs.removeAll()
                    } else {
                        filters.wrappedValue.mediumIDs = Set(allMedia.map(\.id))
                    }
                }
            )) {
                Text(LayoutCopy.searchFilterAllMedia)
                    .foregroundStyle(filters.wrappedValue.selectAllMedia ? DesignColor.filterSearch : DesignColor.text)
            }
            .toggleStyle(DesignCheckbox(tint: DesignColor.filterSearch))
            .font(.system(size: 11, weight: filters.wrappedValue.selectAllMedia ? .bold : .regular))

            Rectangle()
                .fill(DesignColor.divider)
                .frame(height: DesignBorder.width)

            Group {
                if allMedia.count >= 15 {
                    ScrollView {
                        mediumToggleList(filtered: filtered, allMedia: allMedia, filters: filters)
                    }
                    .frame(maxHeight: 220)
                } else {
                    mediumToggleList(filtered: filtered, allMedia: allMedia, filters: filters)
                }
            }

            Text(LayoutCopy.mediumFilterCount(filtered.count, allMedia.count))
                .font(.system(size: 10))
                .foregroundStyle(DesignColor.text.opacity(0.45))
        }
        .frame(width: 200, alignment: .leading)
    }

    private func mediumToggleList(
        filtered: [Medium],
        allMedia: [Medium],
        filters: Binding<SearchFilters>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(filtered) { medium in
                Toggle(medium.name, isOn: Binding(
                    get: {
                        if filters.wrappedValue.selectAllMedia { return true }
                        return filters.wrappedValue.mediumIDs.contains(medium.id)
                    },
                    set: { isOn in
                        var ids = filters.wrappedValue.mediumIDs
                        if filters.wrappedValue.selectAllMedia {
                            filters.wrappedValue.selectAllMedia = false
                            ids = Set(allMedia.map(\.id))
                        }
                        if isOn {
                            ids.insert(medium.id)
                        } else {
                            ids.remove(medium.id)
                        }
                        if ids.count >= allMedia.count {
                            filters.wrappedValue.selectAllMedia = true
                            filters.wrappedValue.mediumIDs.removeAll()
                        } else {
                            filters.wrappedValue.mediumIDs = ids
                        }
                    }
                ))
                .toggleStyle(DesignCheckbox())
                .font(.system(size: 11))
            }
        }
    }

    private func ageGroup(filters: Binding<SearchFilters>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            groupHeader(LayoutCopy.searchFilterGroupAge)

            ForEach(SearchAgeFilter.allCases) { option in
                Button(option.label) {
                    if filters.wrappedValue.age == option {
                        filters.wrappedValue.age = nil
                    } else {
                        filters.wrappedValue.age = option
                    }
                }
                .buttonStyle(.plainFullHit)
                .pointerCursor()
                .font(.system(size: 12, weight: filters.wrappedValue.age == option ? .bold : .regular))
                .foregroundStyle(filters.wrappedValue.age == option ? DesignColor.filterSearch : DesignColor.text)
            }
        }
        .frame(width: 160, alignment: .leading)
    }
}

private struct FilterTypeChipButton: View {
    let label: String
    let isSelected: Bool
    var isEnabled = true
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plainFullHit)
        .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(isSelected ? DesignColor.filterSearch : DesignColor.text.opacity(0.7))
            .background(chipBackground)
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.sm)
                    .strokeBorder(
                        isSelected ? DesignColor.chipBorder(DesignColor.filterSearch) : DesignColor.neutral300,
                        lineWidth: DesignBorder.width
                    )
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.35)
            .pointerCursor(isEnabled)
            .onHover { isHovered = $0 && isEnabled }
    }

    private var chipBackground: Color {
        if isSelected { return DesignColor.chipFill(DesignColor.filterSearch) }
        if isHovered { return DesignColor.text.opacity(0.06) }
        return DesignColor.neutral100
    }
}

/// Zeilen-Wrap für Filter-Chips; Chipbreite höchstens Behälterbreite (Aufgabe 116).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        return layout(subviews: subviews, maxWidth: maxWidth, origin: .zero).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let laidOut = layout(subviews: subviews, maxWidth: bounds.width, origin: bounds.origin)
        for index in subviews.indices {
            let subview = subviews[index]
            let frame = laidOut.frames[index]
            let wrap = laidOut.wrapInContainer[index]
            let widthProposal: CGFloat? = wrap ? frame.width : nil
            let fitted = subview.sizeThatFits(ProposedViewSize(width: widthProposal, height: nil))
            subview.place(
                at: CGPoint(x: frame.minX, y: frame.minY),
                proposal: ProposedViewSize(width: widthProposal, height: fitted.height)
            )
        }
    }

    private struct PlacedChip {
        var frame: CGRect
        var naturalWidth: CGFloat
        var usesContainerWidth: Bool
    }

    private func layout(subviews: Subviews, maxWidth: CGFloat, origin: CGPoint) -> (frames: [CGRect], naturals: [CGFloat], wrapInContainer: [Bool], size: CGSize) {
        var placed: [PlacedChip] = []
        var x = origin.x
        var y = origin.y
        var rowHeight: CGFloat = 0
        let lineLimit = maxWidth.isFinite ? maxWidth : CGFloat.greatestFiniteMagnitude

        for subview in subviews {
            let natural = subview.sizeThatFits(.unspecified)
            let needsWrap = natural.width > lineLimit
            let chipWidth = needsWrap ? lineLimit : natural.width
            let fitted = needsWrap
                ? subview.sizeThatFits(ProposedViewSize(width: lineLimit, height: nil))
                : natural
            if chipWidth > lineLimit - (x - origin.x), x > origin.x {
                x = origin.x
                y += rowHeight + spacing
                rowHeight = 0
            }
            let width = min(fitted.width, lineLimit)
            placed.append(PlacedChip(
                frame: CGRect(x: x, y: y, width: width, height: fitted.height),
                naturalWidth: natural.width,
                usesContainerWidth: needsWrap
            ))
            rowHeight = max(rowHeight, fitted.height)
            x += width + spacing
        }
        let height = placed.isEmpty ? 0 : (placed.last!.frame.maxY - origin.y)
        let width = maxWidth.isFinite ? maxWidth : (placed.map(\.frame.maxX).max() ?? origin.x) - origin.x
        return (
            placed.map(\.frame),
            placed.map(\.naturalWidth),
            placed.map(\.usesContainerWidth),
            CGSize(width: width, height: height)
        )
    }
}
