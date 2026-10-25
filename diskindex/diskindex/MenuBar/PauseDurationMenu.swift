//
//  PauseDurationMenu.swift
//  diskindex
//
//  Popover „PAUSIEREN FÜR“ im Dropdown. Eigene Fläche, keine Systemakzentfarbe.
//

import SwiftUI

nonisolated enum PauseSpan: String, Equatable, Codable, Sendable {
    case halfHour
    case hour
    case tomorrow
    case forever

    var title: String {
        switch self {
        case .halfHour: LayoutCopy.minutes30
        case .hour: LayoutCopy.oneHour
        case .tomorrow: LayoutCopy.untilTomorrow
        case .forever: LayoutCopy.forever
        }
    }

    /// bug.0.4.059: die gespeicherte gewählte Dauer; nur alte Pausen ohne Spanne werden aus der Restzeit abgeleitet.
    static func matching(_ pause: GlobalPause, now: Date) -> PauseSpan? {
        guard pause.active else { return nil }
        if let span = pause.span { return span }
        if pause.forever || pause.until == nil { return .forever }
        guard let until = pause.until else { return .forever }
        if abs(until.timeIntervalSince(GlobalPause.untilTomorrow(from: now))) < 90 { return .tomorrow }
        if until.timeIntervalSince(now) > 2_400 { return .hour }
        return .halfHour
    }

    func endDate(from now: Date) -> Date? {
        switch self {
        case .halfHour: now.addingTimeInterval(1_800)
        case .hour: now.addingTimeInterval(3_600)
        case .tomorrow: GlobalPause.untilTomorrow(from: now)
        case .forever: nil
        }
    }
}

/// Inhalt des separaten Pause-Child-Panels (Menüleiste); ändert Größe/Position des Haupt-Popovers nicht.
struct MenuBarPauseDropdownRoot: View {
    @Bindable var appState: AppState

    var body: some View {
        MenuBarPauseMenuChrome(
            opensAbove: appState.popoverPauseMenuOpensAbove,
            active: appState.globalAutoIndexPaused ? PauseSpan.matching(appState.pauseSnapshot, now: Date()) : nil,
            until: appState.globalAutoIndexPaused ? appState.pauseSnapshot.until : nil
        ) { span in
            appState.pauseIndexing(span: span)
            appState.popoverPauseMenuOpen = false
        }
    }
}

extension AppState {
    /// bug.0.4.059: Pause aus dem Menü mit gewählter Dauer; die Spanne wird mit der Pause gespeichert.
    func pauseIndexing(span: PauseSpan, defaults: UserDefaults = AppDefaults.current, now: Date = Date()) {
        pauseIndexing(until: span.endDate(from: now), defaults: defaults, now: now)
        storedPause.pause(span: span, now: now)
        savePause(defaults)
    }
}

/// Fenster-Inhalt: Kopfzeile für die Nase + Menü (Aufgabe 88).
struct MenuBarPauseMenuChrome: View {
    var opensAbove: Bool
    var active: PauseSpan?
    var until: Date?
    var onChoose: (PauseSpan) -> Void

    private var arrowTrailingInset: CGFloat {
        MenuBarPopoverLayout.pauseMenuArrowInsetFromTrailing - 5.5
    }

    var body: some View {
        VStack(spacing: 0) {
            if opensAbove {
                pauseMenuCard
                Color.clear.frame(height: MenuBarPopoverLayout.pauseMenuArrowHeadroom)
            } else {
                Color.clear.frame(height: MenuBarPopoverLayout.pauseMenuArrowHeadroom)
                pauseMenuCard
            }
        }
        .frame(width: MenuBarPopoverLayout.pauseMenuWidth)
        .shadow(color: DesignColor.shadow.opacity(0.22), radius: 12, y: 6)
    }

    private var pauseMenuCard: some View {
        PauseDurationMenuContent(active: active, until: until, onChoose: onChoose)
            .padding(MenuBarPopoverLayout.pauseMenuContainerPadding)
            .frame(width: MenuBarPopoverLayout.pauseMenuWidth)
            .background(DesignColor.bg)
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.md)
                    .strokeBorder(DesignColor.divider, lineWidth: DesignBorder.width)
            }
            .overlay(alignment: opensAbove ? .bottomTrailing : .topTrailing) {
                PauseMenuArrow(pointsUp: !opensAbove)
                    .padding(.trailing, arrowTrailingInset)
                    .offset(y: opensAbove ? MenuBarPopoverLayout.pauseMenuArrowRise : -MenuBarPopoverLayout.pauseMenuArrowRise)
            }
    }
}

struct PauseDurationMenuContent: View {
    var active: PauseSpan?
    var until: Date?
    var onChoose: (PauseSpan) -> Void

    private let spans: [PauseSpan] = [.halfHour, .hour, .tomorrow, .forever]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let active {
                Text(LayoutCopy.pausedFor(active.title))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(DesignColor.text)
                    .padding(.leading, 10)
                    .padding(.top, 6)
                if let until, active != .forever {
                    Text(untilLabel(until))
                        .font(.system(size: 11.5))
                        .foregroundStyle(DesignColor.text.opacity(0.6))
                        .padding(.leading, 10)
                        .padding(.top, 2)
                }
                Rectangle()
                    .fill(DesignColor.divider)
                    .frame(height: DesignBorder.width)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                Text(LayoutCopy.changeTo)
                    .font(.system(size: 10.5, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(DesignColor.text.opacity(0.45))
                    .padding(.leading, 10)
                    .padding(.bottom, 4)
            } else {
                Text(LayoutCopy.pauseFor)
                    .font(.system(size: 10.5, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(DesignColor.text.opacity(0.45))
                    .padding(.leading, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
            }

            ForEach(spans, id: \.title) { span in
                PauseDurationMenuRow(
                    title: span.title,
                    chosen: active == span,
                    onChoose: { onChoose(span) }
                )
            }
        }
        .padding(.bottom, 1)
    }

    private func untilLabel(_ date: Date) -> String {
        LayoutCopy.menuPauseUntil(DisplayTimeFormat.clock(date))
    }
}

private struct PauseDurationMenuRow: View {
    let title: String
    let chosen: Bool
    let onChoose: () -> Void

    @State private var isHovered = false

    private var isInteractive: Bool { !chosen }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if chosen {
                    Image("IconCheck")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                } else {
                    Color.clear
                }
            }
            .frame(width: 14, height: 12)
            Text(title)
                .font(.system(size: 13))
            Spacer(minLength: 0)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            if isHovered, isInteractive {
                RoundedRectangle(cornerRadius: DesignRadius.sm)
                    .fill(DesignColor.selection)
            }
        }
        .opacity(isInteractive ? 1 : 0.45)
        .pointerCursor(isInteractive)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 && isInteractive }
        .onTapGesture {
            guard isInteractive else { return }
            onChoose()
        }
    }

    private var foregroundColor: Color {
        if isHovered, isInteractive {
            return DesignColor.onSelection
        }
        return DesignColor.text
    }
}

/// Mockup Screen 03: 11×11 pt, 45°, nur zwei Kanten (wie CSS border ohne bottom/right).
struct PauseMenuArrow: View {
    var pointsUp: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(DesignColor.bg)
            PauseMenuArrowBorder(pointsUp: pointsUp)
                .stroke(DesignColor.divider, lineWidth: DesignBorder.width)
        }
        .frame(width: 11, height: 11)
        .rotationEffect(.degrees(45))
    }
}

private struct PauseMenuArrowBorder: Shape {
    var pointsUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointsUp {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        return path
    }
}
