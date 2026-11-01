//
//  ObjectRowOnlineStatusChip.swift
//  DiskArchive
//
//  Online/Offline in Such- und Favoriten-Tabellen (19.11 / 19.12).
//

import SwiftUI

struct ObjectRowOnlineStatusChip: View {
    let isOnline: Bool

    var body: some View {
        Text(isOnline ? LayoutCopy.chipOnline : LayoutCopy.chipOffline)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(isOnline ? DesignColor.stateOnline : DesignColor.stateOff)
            .background(isOnline ? DesignColor.chipFill(DesignColor.stateOnline) : Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.sm)
                    .strokeBorder(
                        DesignColor.chipBorder(isOnline ? DesignColor.stateOnline : DesignColor.stateOff),
                        style: isOnline
                            ? StrokeStyle(lineWidth: DesignBorder.width)
                            : StrokeStyle(lineWidth: DesignBorder.width, dash: [3, 2])
                    )
            }
    }
}
