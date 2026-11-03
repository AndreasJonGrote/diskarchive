//
//  DashboardLastSeenTests.swift
//  DiskArchiveTests
//
//  Aufgabe 190 d / 192 b
//

import AppKit
import SwiftUI
import Testing
@testable import DiskArchive

@Suite @MainActor
struct DashboardLastSeenTests {
    @Test func lastSeenDescriptionCasesGermanAndEnglish() throws {
        guard let first = PreviewData.media.first else {
            Issue.record("PreviewData.media empty")
            return
        }
        var medium = first
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

    /// todo.0.4.3.008 (Layout 04): unten links „Zuletzt gesehen“ · Belegung, rechts nichts mehr (früher „Zuletzt
    /// indiziert“ rechts). Absolute Belegung macht die linke Zeile breiter.
    @Test func dashboardMetaLineStartsLeftWithClockAndOccupancy() async throws {
        let percent = try metaInk(absolute: false)
        let absolute = try metaInk(absolute: true)
        #expect(percent.right == nil, "rechts steht noch etwas: \(String(describing: percent.right))")
        #expect(absolute.right == nil)
        let reference = referenceLastSeenInk(for: "jetzt")
        #expect(percent.left.width > reference.width + 20, "Belegung fehlt neben „jetzt“")
        #expect(absolute.left.width > percent.left.width + 20, "absolute Belegung nicht breiter")
    }

    private func metaInk(absolute: Bool) throws -> (left: CGRect, right: CGRect?) {
        var medium = try #require(PreviewData.media.first)
        medium.connectionStatus = .connected
        medium.indexStatus = .indexed
        medium.completedDepth = 2
        medium.fileCount = 10
        medium.lastIndexedAt = Date()
        medium.capacityUsedBytes = 3_770_000_000_000
        medium.capacityTotalBytes = 4_100_000_000_000
        medium.showAbsoluteCapacity = absolute
        let app = AppState()
        app.media = [medium]
        let width: CGFloat = 960
        let height: CGFloat = 160
        let session = PixelProbe.open(
            MediumDashboardCard(medium: medium)
                .environment(app)
                .environment(\.colorScheme, .light)
                .frame(width: width, height: height, alignment: .topLeading)
                .background(Color.white),
            size: CGSize(width: width, height: height),
            appearance: .aqua
        )
        defer { session.close() }
        let bitmap = session.bitmap()
        // Unterste Zeile der Kachel (11 pt, 12 pt Innenabstand unten).
        let row = CGRect(x: 8, y: height - 32, width: width * 0.45, height: 18)
        let left = try #require(PixelProbe.inkBounds(in: bitmap, rect: row, background: CGPoint(x: width - 40, y: 60)))
        let right = PixelProbe.inkBounds(
            in: bitmap,
            rect: CGRect(x: width * 0.55, y: row.minY, width: width * 0.42, height: row.height),
            background: CGPoint(x: width - 40, y: 60)
        )
        return (left, right)
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
