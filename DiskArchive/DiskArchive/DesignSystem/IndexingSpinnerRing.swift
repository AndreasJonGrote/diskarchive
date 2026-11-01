//
//  IndexingSpinnerRing.swift
//  DiskArchive
//

import SwiftUI

/// Rotierender Ring, oberes Viertel offen, 0,9 s linear.
/// Grün im Status-Chip; schwarz (`control`, 2 pt) in der Popover-Zeile (Layout Sektion 03).
/// Der Winkel wird aus der Uhrzeit berechnet (nicht aus einer Animation in `onAppear`), damit der Ring
/// sich auch in einer übergeordneten `TimelineView` (Dashboard-Chip) dreht.
struct IndexingSpinnerRing: View {
    static let period: Double = 0.9

    var color: Color = DesignColor.stateOnline
    var lineWidth: CGFloat = 1.4

    /// Drehwinkel in Grad zu einem Zeitpunkt: eine Umdrehung je `period`.
    static func angle(at date: Date) -> Double {
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return phase / period * 360
    }

    @Environment(\.spinnerFrozenAngle) private var frozenAngle

    var body: some View {
        if let frozenAngle {
            ring.rotationEffect(.degrees(frozenAngle))
        } else {
            TimelineView(.animation) { context in
                ring.rotationEffect(.degrees(Self.angle(at: context.date)))
            }
        }
    }

    private var ring: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
}

private struct SpinnerFrozenAngleKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    /// Feste Drehung statt Uhrzeit: Messungen am Pixelbild brauchen eine unveränderliche Form (Tests, Aufgabe 222).
    var spinnerFrozenAngle: Double? {
        get { self[SpinnerFrozenAngleKey.self] }
        set { self[SpinnerFrozenAngleKey.self] = newValue }
    }
}
