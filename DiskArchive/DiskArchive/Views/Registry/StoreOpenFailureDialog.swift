//
//  StoreOpenFailureDialog.swift
//  DiskArchive
//

import SwiftUI

struct StoreOpenFailureDialog: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("IconWarning")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(DesignColor.text)

            Text(LayoutCopy.storeOpenFailedTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignColor.text)

            Text(LayoutCopy.storeOpenFailedBody)
                .font(.system(size: 13))
                .foregroundStyle(DesignColor.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(LayoutCopy.close) {
                    appState.indexStoreOpenFailureAlert = false
                }
                .buttonStyle(SecondaryButtonStyle(size: .dialog))
                .frame(maxWidth: .infinity)
                .pointerCursor()

                Button(LayoutCopy.retry) {
                    appState.indexStoreOpenFailureAlert = false
                    appState.onRetryIndexStoreOpen?()
                }
                .buttonStyle(PrimaryButtonStyle(size: .dialog))
                .frame(maxWidth: .infinity)
                .pointerCursor()
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 360, alignment: .leading)
        .background(DesignColor.bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.lg)
                .strokeBorder(DesignColor.neutral300, lineWidth: DesignBorder.width)
        }
        .compositingGroup()
        .shadow(color: DesignColor.shadow.opacity(0.22), radius: 16, y: 12)
        .padding(32)
    }
}
