//
//  FullHitArea.swift
//  diskindex
//
//  Aufgabe 133 / 189 — Klickfläche bei Plain-Knöpfen.
//

import SwiftUI

/// Plain-Knopf mit `contentShape` **im** ButtonStyle (nicht außen am Button).
struct PlainFullHitButtonStyle<S: Shape>: ButtonStyle {
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(shape)
    }
}

extension ButtonStyle where Self == PlainFullHitButtonStyle<Rectangle> {
    static var plainFullHit: PlainFullHitButtonStyle<Rectangle> {
        PlainFullHitButtonStyle(shape: Rectangle())
    }
}

extension View {
    /// Nur für Nicht-Knöpfe (`onTapGesture` o. ä.). Knöpfe: `.buttonStyle(.plainFullHit)`.
    func fullHitArea<S: Shape>(_ shape: S = Rectangle()) -> some View {
        contentShape(shape)
    }

    func fullHitArea() -> some View {
        contentShape(Rectangle())
    }
}
