//
//  WarningBanner.swift
//  DiskArchive
//
//  Warnhinweis oben im Fenster (Versions-Sperre, Einstellungen nicht lesbar). Eine Quelle (Regel 12).
//

import SwiftUI

struct WarningBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image("IconWarning")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(DesignColor.text)
            Text(text)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignColor.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DesignColor.neutral100)
    }
}
