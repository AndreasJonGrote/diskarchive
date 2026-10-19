//
//  ScrollbarGutter.swift
//  diskindex
//
//  bug.0.4.091 (README „Spaltenansicht: Scrollen“, Nutzer 18.10.): Wo ein senkrechter Rollbalken erscheinen kann, ist
//  rechts immer Platz für ihn reserviert (wie `scrollbar-gutter: stable` in CSS). Breite = Leistenbreite des aktuellen
//  Systemstils (dauerhaft: `NSScroller.scrollerWidth`, Overlay: 0); ein Wechsel des Systemstils zur Laufzeit gilt
//  sofort. Ein zentraler Baustein (Regel 12): `.stableScrollbarGutter()` am Inhalt einer senkrechten `ScrollView`.
//  Umsetzung: Im dauerhaften Stil steht der Rollbalken immer (nicht erst, wenn der Inhalt überläuft) – der Inhalt
//  springt nicht beim Wechsel zwischen Ansichten mit und ohne Überlauf. (`scrollIndicators(.visible)` lässt den
//  dauerhaften Rollbalken ohne Überlauf nicht stehen, im Fenstertest belegt.) Im Overlay-Stil bleibt alles wie bisher.
//

import AppKit
import SwiftUI

/// Systemstil der Rollbalken, mit Wechsel zur Laufzeit (Maus an/ab, Systemeinstellung).
@MainActor
@Observable
final class ScrollerStyleMonitor {
    static let shared = ScrollerStyleMonitor()

    private(set) var style: NSScroller.Style = NSScroller.preferredScrollerStyle
    @ObservationIgnored private var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.style = NSScroller.preferredScrollerStyle }
        }
    }
}

enum ScrollbarGutter {
    /// Reservierte Breite rechts für einen Stil (Overlay: 0).
    static func width(for style: NSScroller.Style) -> CGFloat {
        style == .legacy ? NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy) : 0
    }
}

private struct ScrollerStyleOverrideKey: EnvironmentKey {
    static let defaultValue: NSScroller.Style? = nil
}

extension EnvironmentValues {
    /// Fester Rollbalken-Stil statt des Systemstils (nur Tests; `nil` = System).
    var scrollerStyleOverride: NSScroller.Style? {
        get { self[ScrollerStyleOverrideKey.self] }
        set { self[ScrollerStyleOverrideKey.self] = newValue }
    }
}

/// Gültiger Stil: fester Wert aus der Umgebung oder der Systemstil.
struct EffectiveScrollerStyle: DynamicProperty {
    @Environment(\.scrollerStyleOverride) private var override

    @MainActor var style: NSScroller.Style {
        override ?? ScrollerStyleMonitor.shared.style
    }
}

extension View {
    /// Am Inhalt einer senkrechten `ScrollView`: Platz für den Rollbalken immer reservieren (bug.0.4.091).
    func stableScrollbarGutter() -> some View {
        modifier(StableScrollbarGutterModifier())
    }
}

private struct StableScrollbarGutterModifier: ViewModifier {
    @Environment(\.scrollerStyleOverride) private var override

    func body(content: Content) -> some View {
        // Systemstil gelesen, damit ein Wechsel zur Laufzeit neu anwendet; die Scrollansicht übernimmt ihn selbst.
        content.background(ScrollbarGutterKeeper(override: override, systemStyle: ScrollerStyleMonitor.shared.style))
    }
}

/// Unsichtbarer Helfer im Inhalt: lässt im dauerhaften Stil der umgebenden `NSScrollView` den senkrechten Rollbalken
/// stehen (`autohidesScrollers = false`). Der Stil ist der der Scrollansicht (AppKit folgt dem System); nur `override`
/// (Tests) setzt ihn fest. Greift schon beim Einhängen, damit das erste Layout die endgültige Breite hat.
private struct ScrollbarGutterKeeper: NSViewRepresentable {
    let override: NSScroller.Style?
    let systemStyle: NSScroller.Style

    func makeNSView(context: Context) -> KeeperView {
        let view = KeeperView()
        view.override = override
        return view
    }

    func updateNSView(_ view: KeeperView, context: Context) {
        view.override = override
        view.apply()
    }

    final class KeeperView: NSView {
        var override: NSScroller.Style?

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            apply()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        override func layout() {
            super.layout()
            apply()
        }

        func apply() {
            guard let scroll = enclosingScrollView else { return }
            var changed = false
            if let override, scroll.scrollerStyle != override {
                scroll.scrollerStyle = override
                changed = true
            }
            let keep = scroll.scrollerStyle == .legacy
            if !scroll.hasVerticalScroller {
                scroll.hasVerticalScroller = true
                changed = true
            }
            if scroll.autohidesScrollers == keep {
                scroll.autohidesScrollers = !keep
                changed = true
            }
            // Sofort neu einteilen: die Inhaltsbreite steht vor der ersten Darstellung fest.
            if changed { scroll.tile() }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
