//
//  IndexingFailureDialog.swift
//  DiskArchive
//

import SwiftUI

struct IndexingFailureDialog: View {
    @Environment(AppState.self) private var appState
    let notice: IndexingFailureNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("IconWarning")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(DesignColor.text)

            Text(LayoutCopy.indexFailedTitle(name: notice.name))
                .font(DesignFont.heading(size: 16))
                .foregroundStyle(DesignColor.text)

            Text(LayoutCopy.indexFailedBody)
                .font(.system(size: 13))
                .foregroundStyle(DesignColor.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            if let line = notice.reason.line {
                Text(line)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignColor.text.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button(LayoutCopy.close) {
                    appState.indexingFailure = nil
                }
                .buttonStyle(SecondaryButtonStyle(size: .dialog))
                .frame(maxWidth: .infinity)
                .pointerCursor()

                Button(LayoutCopy.retry) {
                    appState.indexingFailure = nil
                    appState.onReindexMedium?(notice.id)
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
