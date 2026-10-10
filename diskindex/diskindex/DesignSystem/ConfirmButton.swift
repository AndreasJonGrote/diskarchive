//
//  ConfirmButton.swift
//  diskindex
//
//  Drei Stufen: Beschriftung → Bestätigen → Bestätigt (2 s).
//  Aufgabe 145 — Sekundär-Rahmen einheitlich; Beschriftung mittig.
//

import SwiftUI

enum ConfirmStage: Equatable {
    case idle
    case armed
    case confirmed
}

struct ConfirmGate: Equatable {
    var title: String
    var stage = ConfirmStage.idle
    var armedAt: Date?

    mutating func click(now: Date) -> Bool {
        switch stage {
        case .idle:
            stage = .armed
            armedAt = now
            return false
        case .armed:
            stage = .confirmed
            armedAt = nil
            return true
        case .confirmed:
            return false
        }
    }

    mutating func leave() {
        guard stage == .armed else { return }
        stage = .idle
        armedAt = nil
    }

    mutating func resetArmedTimeout(now: Date) {
        guard stage == .armed, let armedAt, now.timeIntervalSince(armedAt) >= 3 else { return }
        stage = .idle
        self.armedAt = nil
    }

    mutating func finishConfirmedDisplay() {
        guard stage == .confirmed else { return }
        stage = .idle
    }

    func label() -> String {
        switch stage {
        case .idle: return title
        case .armed: return LayoutCopy.confirm
        case .confirmed: return LayoutCopy.confirmed
        }
    }

    func isConfirmed() -> Bool {
        stage == .confirmed
    }
}

struct ConfirmButton: View {
    enum Tone {
        case destructive
        case neutral
        case muted
    }

    static let layoutHeight: CGFloat = DesignButtonSize.standard.height
    private static let horizontalPadding: CGFloat = DesignButtonSize.standard.horizontalPadding

    var title: String
    var tone: Tone = .destructive
    var now: () -> Date = { Date() }
    var action: () -> Void

    @State private var gate: ConfirmGate

    init(title: String, tone: Tone = .destructive, now: @escaping () -> Date = { Date() }, action: @escaping () -> Void) {
        self.title = title
        self.tone = tone
        self.now = now
        self.action = action
        _gate = State(initialValue: ConfirmGate(title: title))
    }

    #if DEBUG
    /// Feste Stufe für Bildschirmfotos (`05-bestaetigung-*`).
    init(title: String, tone: Tone = .destructive, screenshotStage: ConfirmStage, action: @escaping () -> Void = {}) {
        self.title = title
        self.tone = tone
        self.now = { Date() }
        self.action = action
        var gate = ConfirmGate(title: title)
        gate.stage = screenshotStage
        if screenshotStage == .armed {
            gate.armedAt = Date()
        }
        _gate = State(initialValue: gate)
    }
    #endif

    var body: some View {
        Button {
            if gate.click(now: now()) {
                action()
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    gate.finishConfirmedDisplay()
                }
            }
        } label: {
            // Breite aus Textmaßen ohne Symbol; sichtbares Label zentriert (Aufgabe 145).
            ZStack {
                Text(title)
                    .font(.system(size: DesignButtonSize.standard.fontSize, weight: .semibold))
                    .lineLimit(1)
                    .hidden()
                Text(LayoutCopy.confirm)
                    .font(.system(size: DesignButtonSize.standard.fontSize, weight: .semibold))
                    .lineLimit(1)
                    .hidden()
                Text(LayoutCopy.confirmed)
                    .font(.system(size: DesignButtonSize.standard.fontSize, weight: .semibold))
                    .lineLimit(1)
                    .hidden()
                    .padding(.leading, 20) // Platz für Häkchen nur in der Breitenmessung
                stageLabel
            }
            .padding(.horizontal, Self.horizontalPadding)
            .frame(height: Self.layoutHeight)
            .fullHitArea()
        }
        .buttonStyle(ConfirmButtonStyle(
            stage: gate.stage,
            tone: tone
        ))
        .fullHitArea()
        .task(id: gate.armedAt) {
            guard gate.stage == .armed, gate.armedAt != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            gate.resetArmedTimeout(now: now())
        }
        .pointerCursor()
    }

    @ViewBuilder
    private var stageLabel: some View {
        if gate.isConfirmed() {
            HStack(spacing: 6) {
                Image("IconCheck")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Text(gate.label())
                    .font(.system(size: DesignButtonSize.standard.fontSize, weight: .semibold))
                    .lineLimit(1)
            }
        } else {
            Text(gate.label())
                .font(.system(size: DesignButtonSize.standard.fontSize, weight: .semibold))
                .lineLimit(1)
        }
    }
}

private struct ConfirmButtonStyle: ButtonStyle {
    var stage: ConfirmStage
    var tone: ConfirmButton.Tone

    private static let confirmFill = Color(red: 0xE0 / 255, green: 0x48 / 255, blue: 0x30 / 255)
    private static let confirmBorder = Color(red: 0xB5 / 255, green: 0x38 / 255, blue: 0x1F / 255)
    private static let successFill = Color(red: 0x2E / 255, green: 0x9E / 255, blue: 0x5B / 255)
    private static let successBorder = Color(red: 0x23 / 255, green: 0x7A / 255, blue: 0x46 / 255)

    func makeBody(configuration: Configuration) -> some View {
        let foreground: Color = {
            switch stage {
            case .confirmed, .armed: return .white
            case .idle:
                switch tone {
                case .destructive: return DesignColor.stateError
                case .neutral, .muted: return DesignColor.text
                }
            }
        }()
        let background: Color = {
            switch stage {
            case .confirmed: return Self.successFill
            case .armed: return Self.confirmFill
            case .idle: return .clear
            }
        }()
        let border: Color = {
            switch stage {
            case .confirmed: return Self.successBorder
            case .armed: return Self.confirmBorder
            case .idle:
                switch tone {
                case .destructive: return DesignColor.stateError
                // Neutral und muted: gleiche Sekundär-Optik (Katalog #9b9797).
                case .neutral, .muted: return DesignBorder.secondaryControlBorderColor
                }
            }
        }()

        return configuration.label
            .foregroundStyle(foreground)
            .background(background)
            .designControlBorder(border)
    }
}
