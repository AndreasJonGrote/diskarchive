//
//  FilterValueChip.swift
//  DiskArchive
//
//  Blauer Filter-Chip (Aufgabe 19.11 / 19.14).
//

import SwiftUI

struct FilterValueChip: View {
    let label: String
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            if onRemove != nil {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .frame(minHeight: 23.5)
        .foregroundStyle(DesignColor.filterSearch)
        .background(DesignColor.chipFill(DesignColor.filterSearch))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.sm)
                .strokeBorder(DesignColor.chipBorder(DesignColor.filterSearch), lineWidth: DesignBorder.width)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
        .overlay {
            if let onRemove {
                ChipRemoveSquareHitOverlay(action: onRemove)
            }
        }
    }
}
