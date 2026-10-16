//
//  CrashReportDialog.swift
//  diskindex
//
//  Dialog nach einem abnormalen Ende, im Stil des Erkennungs-Dialogs (Aufgabe 55).
//

import AppKit
import SwiftUI

struct CrashReportDialog: View {
    @State private var autoSend = false
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("IconWarning")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(DesignColor.text)

            Text(LayoutCopy.crashTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignColor.text)

            Text(LayoutCopy.crashBody)
                .font(.system(size: 13))
                .foregroundStyle(DesignColor.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Toggle(LayoutCopy.autoSend, isOn: $autoSend)
                .toggleStyle(DesignCheckbox())
                .font(.system(size: 14))
                .padding(.top, 4)

            HStack(spacing: 8) {
                Button(LayoutCopy.crashDiscard) {
                    onClose()
                }
                .buttonStyle(SecondaryButtonStyle(size: .dialog))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
                .pointerCursor()
                Spacer(minLength: 8)
                Button(LayoutCopy.crashSend) {
                    IssueConsent.setAutoSendEnabled(autoSend)
                    IssueReporter.shared.enqueue(kind: "crash")
                    onClose()
                }
                .buttonStyle(PrimaryButtonStyle(size: .dialog))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
                .pointerCursor()
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 560, alignment: .leading)
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
