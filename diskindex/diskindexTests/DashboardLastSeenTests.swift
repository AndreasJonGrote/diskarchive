//
//  DashboardLastSeenTests.swift
//  diskindexTests
//
//  Aufgabe 190 d / 192 b
//

import AppKit
import SwiftUI
import Testing
@testable import diskindex

@Suite @MainActor
struct DashboardLastSeenTests {
    @Test func lastSeenDescriptionCasesGermanAndEnglish() throws {
        var medium = try #require(PreviewData.media.first)
        medium.connectionStatus = .connected
        #expect(medium.lastSeenDescription(language: .german) == "jetzt")
        #expect(medium.lastSeenDescription(language: .english) == "now")

        medium.connectionStatus = .offline
        let calendar = Calendar.current
        let today = Date()
        medium.lastSeenAt = today
        let time = today.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.locale(for: .german)))
        #expect(medium.lastSeenDescription(now: today, language: .german) == "heute, \(time)")

        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        medium.lastSeenAt = yesterday
        let yTime = yesterday.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.locale(for: .english)))
        #expect(medium.lastSeenDescription(now: today, language: .english) == "yesterday, \(yTime)")

        medium.lastSeenAt = calendar.date(byAdding: .day, value: -3, to: today) ?? today
        #expect(medium.lastSeenDescription(now: today, language: .german) == "vor 3 Tagen")
        #expect(medium.lastSeenDescription(now: today, language: .english) == "3 days ago")
    }

    @Test func dashboardShowsClockAndLastIndexedWithoutPrefix() async throws {
        var medium = try #require(PreviewData.media.first)
        medium.connectionStatus = .connected
        medium.indexStatus = .indexed
        medium.completedDepth = 2
        medium.fileCount = 10
        medium.lastIndexedAt = Date()
        medium.capacityUsedBytes = 400
        let app = AppState()
        app.media = [medium]
        let width: CGFloat = 960
        let session = PixelProbe.open(
            MediumDashboardCard(medium: medium)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: width, height: 160, alignment: .topLeading)
                .background(Color.white),
            size: CGSize(width: width, height: 160),
            appearance: .aqua
        )
        defer { session.close() }
        let bitmap = session.bitmap()
        let label = IndexedDateFormatting.lastIndexedLine(date: medium.lastIndexedAt)
        let ref = referenceLastSeenInk(for: label)
        let rowY: CGFloat = 118
        let ink = try #require(PixelProbe.inkBounds(
            in: bitmap,
            rect: CGRect(x: width * 0.55, y: rowY - 6, width: width * 0.42, height: 20),
            background: CGPoint(x: 40, y: 40)
        ))
        #expect(abs(ink.width - ref.width) <= max(14, ref.width * 0.2))
        #expect(abs(ink.height - ref.height) <= 8)
        let prefixRef = referenceLastSeenInk(for: "zuletzt indiziert: \(label)")
        #expect(ink.width < prefixRef.width - 20)
    }

    private func referenceLastSeenInk(for text: String) -> CGSize {
        let session = PixelProbe.open(
            HStack(spacing: 4) {
                Image("IconClock")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                Text(text)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(.system(size: 11))
            .foregroundStyle(DesignColor.text.opacity(0.55))
            .padding(24)
            .frame(width: 400, height: 48, alignment: .leading)
            .background(Color.white),
            size: CGSize(width: 400, height: 48),
            appearance: .aqua
        )
        defer { session.close() }
        let refBitmap = session.bitmap()
        let ink = PixelProbe.inkBounds(
            in: refBitmap,
            rect: CGRect(x: 0, y: 0, width: 400, height: 48),
            background: CGPoint(x: 380, y: 40)
        )
        return CGSize(width: ink?.width ?? 0, height: ink?.height ?? 0)
    }
}
