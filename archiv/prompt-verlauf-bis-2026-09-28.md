# prompt.md — Aufgabenliste für Cursor

Diese Datei ist die Arbeitsliste für die Umsetzung von „Disk Index" (macOS Menu-Bar App). Regeln zur Zusammenarbeit stehen in [AGENTS.md](AGENTS.md). **Maßgebliches Design seit 28.09.: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html) + [layout/Farbschema.dc.html](layout/Farbschema.dc.html) — siehe Aufgabe 19.** Das alte Handoff liegt archiviert unter `layout/design_handoff_disk_index/`; Screen-Nummern in den Aufgaben 0–18 beziehen sich noch auf dessen alte Nummerierung (Umrechnungstabelle in Aufgabe 19). Laufende Korrekturen/Entscheidungen stehen in [README.md](README.md) (Projekt-Root).

**Für Cursor:** Arbeite die Aufgaben der Reihe nach ab. Trage nach jeder Aufgabe unter „**Status:**" ein, was du gebaut hast (Dateien, Entscheidungen, Abweichungen, offene Fragen). Ändere sonst nichts an dieser Datei — Claude liest und prüft sie danach.

---

## 0. Vorbereitung (blockiert alle weiteren Aufgaben)

**Status:** Erledigt durch Cursor (Build lokal nicht geprüft — nur Command Line Tools, kein `xcodebuild`).

- **LSUIElement:** `INFOPLIST_KEY_LSUIElement = YES` in `diskindex.xcodeproj/project.pbxproj` (Debug + Release).
- **App-Einstieg:** `diskindexApp.swift` — `MenuBarExtra` (`.window`) mit Template-Icon `MenuBarHardDrives`; `Window(id: "main-window")` mit `DashboardView`, `.defaultLaunchBehavior(.suppressed)`; SwiftData/`Item` entfernt.
- **Entfernt:** `Item.swift`, Template-`ContentView.swift`.
- **Ordnerstruktur** unter `diskindex/diskindex/`:
  - `App/AppState.swift` — `@Observable`, Debug-Hook für Badge-Vorschau (Aufgabe 2).
  - `DesignSystem/DesignTokens.swift` — Farben (Accent/Violet/Neutral/Red), Radius 6/8/14, Border 1px, Suchfeld-Maße, Storage-Gradient-Stops.
  - `MenuBar/MenuBarPopoverView.swift` — Platzhalter + „Disk Index öffnen“ (`openWindow`).
  - `Views/Dashboard/DashboardView.swift` — Platzhalter Screen 04.
  - `Views/Registry|ColumnBrowser|Search|Detail/*Placeholder.swift` — Marker für spätere Screens.
  - `Models/` — leer (`.gitkeep`), ab Aufgabe 1.
  - `Resources/Icons/` — `ICON_STRATEGY.md`, Quell-`hard-drives.svg`.
- **Icons:** Phosphor SVG → Asset Catalog (`MenuBarHardDrives.imageset`, Preserve Vector + Template). Badges später als SwiftUI-Shapes (siehe `ICON_STRATEGY.md`). Vollständiger Export in Aufgabe 10.
- **Abweichung:** SVG direkt im Asset Catalog statt PDF-Zwischenschritt (Xcode 15+); funktional gleichwertig zu Spec.

Projekt existiert bereits unter `diskindex/` (Xcode-Projekt `diskindex.xcodeproj`, Target `diskindex`). Ist-Zustand (Standard-Template, unverändert):
- SwiftUI, SwiftData, macOS-Deployment-Target 15.7, Bundle-ID `xjonx.diskindex`.
- `diskindexApp.swift`: `WindowGroup { ContentView() }` mit `ModelContainer` für `Item.self` — **Platzhalter-Boilerplate, muss ersetzt werden.**
- `ContentView.swift`, `Item.swift`: Xcode-Default-Template (Liste mit „+"-Button für `Item`s) — **komplett ersetzen**, nicht Teil des Produkts.
- Es existiert noch **kein** `Info.plist`-Override, kein `LSUIElement`, keine Menu-Bar-Integration.

Konkrete Schritte für diese Aufgabe:
1. **App-Typ auf Menu-Bar-App umstellen**: `LSUIElement = YES` setzen (Info-Settings im Target, „Application is agent (UIElement)"), damit die App ohne Dock-Icon/Standardfenster startet und primär über die Menüleiste läuft. Das Hauptfenster (Screen 04 etc.) wird bei Bedarf separat geöffnet (z. B. über `openWindow`/`NSWindow`, nicht als automatisch startendes `WindowGroup`).
2. `diskindexApp.swift` umbauen: `MenuBarExtra` (SwiftUI, macOS 13+) als primärer Einstiegspunkt für Icon + Popover (Screen 02/03), zusätzliches `Window`/`WindowGroup`-Scene für das Hauptfenster (Screen 04–07), das nicht automatisch beim App-Start aufgeht.
3. `Item.swift` und den Default-Content aus `ContentView.swift` entfernen; `ContentView.swift` wird zur Übersicht (Screen 04) oder aufgeteilt — deine Entscheidung, wie du die Views strukturierst, aber bitte grob an den Screens aus der README orientieren (ein View/eine Datei pro Screen ist ein guter Default).
4. Zielordnerstruktur innerhalb `diskindex/diskindex/` anlegen (Namen sind Vorschlag, du kannst sinnvoll anpassen — bitte kurz dokumentieren, falls abgewichen):
   - `Models/` — `Medium.swift`, `SearchState.swift`, etc. (siehe Aufgabe 1)
   - `DesignSystem/` — Tokens (Farben, Radius, Spacing, Typo) zentral, siehe unten
   - `MenuBar/` — Menu-Bar-Icon, Status-Badges, Popover (Screen 02/03)
   - `Views/Dashboard/`, `Views/Registry/`, `Views/ColumnBrowser/`, `Views/Search/`, `Views/Detail/` — je Screen-Gruppe
   - `Resources/Icons/` — Phosphor-Icon-Assets
5. Icon-Strategie: Phosphor Icons (regular weight, Status-Icons „dezent fetter") **nicht** als Web-Font. Exportiere die benötigten Icons (siehe README Screen 08 für die vollständige Liste) als SVG → PDF-Vektor-Assets im Asset-Catalog (`Resources/Icons/` bzw. `Assets.xcassets`) mit „Preserve Vector Data", oder als SwiftUI `Path`/`Shape`, falls das für die wenigen animierten/speziellen Icons (Spinner-Ring, X, „!") einfacher ist. Dokumentiere hier, wofür du dich entschieden hast.
6. Design-Tokens als zentrale Konstanten/Swift-`enum` bzw. `Color`-Extension in `DesignSystem/` anlegen, exakt nach README → „Design Tokens" (Farben inkl. Ramp-Stufen, Radius 6/8/14px, Border 1px). **Nicht** pro View hart codieren — jede Farbe/jeder Radius wird aus diesem zentralen Ort referenziert.

**Akzeptanzkriterium:** App startet ohne Dock-Icon, zeigt ein Menu-Bar-Icon, Default-Template-Code (`Item`, Listen-UI) ist vollständig entfernt, Ordnerstruktur steht, Design-Tokens sind zentral definiert und noch ungenutzt (werden in den folgenden Aufgaben verwendet).

---

## 1. Datenmodell & State

**Status:** Erledigt durch Cursor.

- **Dateien:** `Models/Medium.swift` (Typen + `Medium`), `SearchState.swift`, `ColumnBrowserState.swift`, `MockData.swift` (6 Medien, alle Status aus Screen 01).
- **AppState** erweitert: `media`, `searchState`, `columnBrowserState`, `showAbsoluteCapacity`, `globalAutoIndexPaused`, Hilfs-Collections `connectedMedia` / `registryMedia`.
- **Offene Frage:** `showAbsoluteCapacity` vorläufig **global** in `AppState` — Produktentscheidung global vs. pro Medium steht aus (README).

**Review-Fix (Cursor):** `ByteCountFormatter.storage` nach `DesignSystem/ByteCountFormatting.swift` (internal) verschoben; `xcodebuild -scheme diskindex build` ✅ (Xcode 26.3).

Aus README → „State Management":
- `Medium`-Model: `type` (usb/ssd/hdd), `connectionStatus` (connected/offline), `indexStatus` (indexing/indexed/error/pending), `allowIndexing: Bool`, `autoIndexPaused: Bool`, `capacityUsedPercent`, `lastSeenAt`, `firstIndexedAt`, plus Felder für Registry (`forgotten`-Flag).
- Globaler bzw. per-Medium `showAbs`-Toggle (Prozent ⇄ absolute Größe) — **Produktentscheidung nötig**: lieber global oder pro Medium? Cursor: bitte als offene Frage markieren, falls nicht klar, statt eigenmächtig zu entscheiden.
- Such-State: `query`, `filters { medium[], fileType[], age, folderOnly }`, `sort { column, direction }`.
- Column-Browser-State: `selectedMediumId`, `pathStack`, `selectedFileId`.

Kein Backend/echtes Disk-Scanning in dieser Phase nötig — Mock-/Dummy-Daten reichen, die alle Statuskombinationen abdecken (siehe README Screen 01: „Six example rows demonstrate every state").

---

## 2. Menüleisten-Icon & Status-Badges (README Screen 02)

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

- **SwiftUI `MenuBarExtra`-Label** (statt separatem `NSStatusItem` — gleiches Ergebnis: Template-Glyph + Badge-Overlay): `MenuBar/MenuBarStatusIconView.swift`, `MenuBar/MenuBarStatusBadgeView.swift`.
- Template-Image `MenuBarHardDrives` (Phosphor regular), Badge ~12px, weißer Kreis.
- Zustände: idle (kein Badge), indexing (Ring 0,9s linear), newlyDetected (Puls 1,6s ease-in-out), paused (dünnes X), error (fettes „!“).
- Debug: Popover-Picker `Badge (Debug)` schaltet `AppState.menuBarBadgePreview`; SwiftUI-Previews für alle Zustände + Dark-Hintergrund.

- `NSStatusItem` mit Template-Image „stacked disks" (Phosphor `hard-drives`, regular/thin) — automatisches Tinting für Light/Dark.
- Status-Badge unten rechts, ~12–13px, weißer Grund:
  - Indiziert (idle): kein Badge.
  - Wird indiziert: rotierender Ring, accent blue, `border-top-color: transparent`, Rotation 0.9s linear infinite.
  - Neu erkannt: pulsierender solider blauer Punkt, 1.6s ease-in-out infinite.
  - Pausiert: dünnes zweistrichiges X (kein fetter Icon-Pfad), dunkelgrau/schwarz.
  - Fehler: fettes „!"-Zeichen (Text, kein Icon-Pfad), dunkelgrau/schwarz.
- **Regel:** Hauptglyph immer regular/thin. Nur Badges dürfen „dicker" wirken.

**Akzeptanzkriterium:** Alle 5 Zustände sind durchschaltbar/testbar (z. B. via Debug-Menü oder Preview), Template-Rendering funktioniert in Light & Dark Menübar.

**Review-Fix (Cursor):** Menüleisten-Glyph als SwiftUI-`HardDrivesGlyphShape` ([DesignSystem/HardDrivesGlyph.swift](diskindex/diskindex/DesignSystem/HardDrivesGlyph.swift)) statt SVG-Asset — Template via `Color.primary`. SVG-Asset bleibt als Referenz. `xcodebuild` ✅.

**Review-Fix 2 (Cursor):** Menüleiste nutzt `HardDrivesTemplateIcon` — `ImageRenderer` → `NSImage` mit `isTemplate = true` in [HardDrivesTemplateIcon.swift](diskindex/diskindex/DesignSystem/HardDrivesTemplateIcon.swift); Popover behält vektorales `HardDrivesGlyph`. Bitte visuell in der Menüleiste prüfen (zwei gestapelte Laufwerke). `xcodebuild` ✅.

**Review (Claude, 20.09., per Screenshot) — Rendering-Pipeline jetzt ok, Geometrie noch falsch:** ✅ `NSImage` + `isTemplate = true` funktioniert jetzt zuverlässig — Icon ist sichtbar und wird getintet (bitte diesen Ansatz beibehalten, **nicht** wieder auf rohe SVG-Assets oder `Color.primary`-Shapes zurückwechseln). ❌ Die **Form** ist aber falsch: [HardDrivesGlyphShape](diskindex/diskindex/DesignSystem/HardDrivesGlyph.swift:11) zeichnet zwei **massiv gefüllte** abgerundete Balken — sieht in 18px aus wie ein Hamburger-Menü-Icon, nicht wie gestapelte Festplatten. Das echte Phosphor-`hard-drives`-Icon besteht aus zwei **umrandeten** (nicht gefüllten) abgerundeten Rechtecken mit je einem kleinen LED-Punkt rechts — der exakte Original-Pfad liegt bereits vor in [hard-drives.svg](diskindex/diskindex/Assets.xcassets/MenuBarHardDrives.imageset/hard-drives.svg) (`M208,136H48a16,16,0,0,0-16,16v48...`, even-odd-Füllregel für die Rahmen-Löcher).

Bitte: `HardDrivesGlyphShape.path(in:)` durch eine `Path`-Konstruktion ersetzen, die diesen echten SVG-Pfad nachbildet (per `Path.addPath` mit even-odd-Fill für die Rahmen-Löcher, oder die SVG-Pfaddaten direkt in Bezier-/Rect-Befehle übersetzen), **und weiterhin über die bereits funktionierende `HardDrivesTemplateIcon`-Pipeline** (`ImageRenderer` → `NSImage`, `isTemplate = true`) rendern. Nicht die Rendering-Pipeline nochmal anfassen, nur die Geometrie in der Shape korrigieren. Danach wieder Screenshot zur Bestätigung.

**Review-Fix (Cursor):** Menü-Glyph 1:1 aus Asset `MenuBarHardDrives` (`HardDrivesTemplateIcon` + `HardDrivesGlyph`); Rechtsklick-Kontextmenü „Öffnen“ / „Beenden“ am Label (`MenuBarExtraLabel`). `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 3):**
1. ❌ **Icon immer noch falsch** (per neuestem Screenshot: sieht wie ein Trichter/Filter-Icon aus, nicht wie zwei gestapelte Festplatten). Bitte diesmal die Geometrie wirklich 1:1 aus dem SVG-Pfad ableiten statt erneut freihändig zu approximieren — im Zweifel den SVG-Pfad-String direkt in eine `Path`-Erweiterung parsen (es gibt dafür einfache Parser-Snippets für SVG-Path-Data in Swift), damit hier nicht ein viertes Mal geraten wird.
2. ~~Rechtsklick~~ → siehe Review-Fix oben. Erwartet (Standard-macOS-Verhalten für Menu-Bar-Apps, nicht explizit im README, aber Nutzer-Anforderung): Rechtsklick (oder generell ein zusätzlicher Eintrag) soll ein Kontextmenü mit mindestens „Öffnen" (Hauptfenster) und „Beenden" (App-Quit) zeigen. Mit `MenuBarExtra(.window)` ist Rechtsklick-Kontextmenü nicht trivial nativ verfügbar — ggf. auf `NSStatusItem` mit eigenem `NSMenu` für Rechtsklick umsteigen (linksklick weiterhin Popover), oder recherchieren, wie sich das mit `MenuBarExtra` sauber kombinieren lässt.

**Review-Fix (Cursor, Runde 6):** Error-/Status-Badge als `.overlay(alignment: .bottomTrailing)` auf dem 18px-Glyph (kein fester 22×18-`ZStack`, der das Badge neben das Icon drückte). `xcodebuild` ✅.

**Review-Fix (Cursor, Runde 7):** `MenuBarExtraLabel` liest `menuBarBadgePreview` aus `@Environment(AppState.self)`; Label erhält `.environment(appState)` in `diskindexApp`. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 6) — Root Cause für „Debug-Select tut nichts" gefunden:** ❌ Der eigentliche Bug liegt nicht in `MenuBarStatusBadgeView` (der Code dort — [MenuBarStatusBadgeView.swift](diskindex/diskindex/MenuBar/MenuBarStatusBadgeView.swift) — sieht korrekt aus), sondern in [diskindexApp.swift:17](diskindex/diskindex/diskindexApp.swift:17): `MenuBarExtraLabel(badge: appState.menuBarBadgePreview)` liest den Wert **einmalig beim Aufbau der Scene**, nicht reaktiv. `Scene.body` wird von SwiftUI nicht zuverlässig neu ausgewertet, wenn sich `appState.menuBarBadgePreview` ändert (bekannte Einschränkung von `MenuBarExtra`+`@Observable` in diesem Kontext) — deshalb bleibt das Menüleisten-Icon bei der zuletzt gerenderten Badge-Variante hängen, egal was im Debug-Picker gewählt wird. Das erklärt vermutlich auch, warum der „error"-Zustand zuvor falsch aussah: es war wahrscheinlich gar nicht der Error-Zustand, der gerendert wurde, sondern ein alter/anderer Stand.

**Fix:** `MenuBarExtraLabel` darf den Badge-Wert nicht als Parameter von außen bekommen, sondern muss ihn **selbst** aus dem Environment lesen, damit die eigene `View.body` (die reaktiv ist) sich aktualisiert:
```swift
// diskindexApp.swift
} label: {
    MenuBarExtraLabel()
        .environment(appState)   // falls nicht schon global gesetzt
}
```
```swift
// MenuBarExtraLabel.swift
struct MenuBarExtraLabel: View {
    @Environment(AppState.self) private var appState
    var body: some View {
        MenuBarStatusIconView(badge: appState.menuBarBadgePreview)
    }
}
```
Nach dem Fix bitte im Debug-Picker jeden Zustand durchschalten und per Screenshot bestätigen, dass das Menüleisten-Icon live mitgeht — inklusive „error", das war ja der ursprüngliche Auslöser dieser ganzen Runde.

**Review (Claude, 20.09., Runde 4):** ✅ Icon-Geometrie ist jetzt korrekt (zwei gestapelte Laufwerke erkennbar, per Screenshot bestätigt). ❌ **Error-Badge weicht vom Layout ab** — im aktuellen Screenshot sitzt das „!" wie ein zweites Icon direkt neben dem Glyph in einer Art Auswahl-Kapsel, nicht als kleiner runder Badge (~12px, weißer Kreis) unten rechts am Glyph überlagert, wie im README/Mockup beschrieben (Screen 02: „Status-Badge unten rechts, ≈12–13px, weißer Grund"). Bitte `MenuBarErrorMark`/`badgeContainer`-Platzierung prüfen — vermutlich fehlt der `.offset`/`.alignment: .bottomTrailing` bzw. es wird fälschlich als eigenständiges Element neben statt als Overlay auf dem Glyph gerendert.

**Review (Claude, 20.09., Runde 7) — Fix aus Runde 6 hat nicht geholfen, tieferes Problem vermutet:** ❌ Trotz `MenuBarExtraLabel` mit `@Environment(AppState.self)` ([MenuBarExtraLabel.swift](diskindex/diskindex/MenuBar/MenuBarExtraLabel.swift) — Code sieht strukturell korrekt aus, exakt wie in Runde 6 vorgeschlagen) bleibt das Menüleisten-Icon beim Debug-Picker weiterhin funktionslos/eingefroren. Das deutet auf eine **bekannte, tieferliegende Einschränkung von `MenuBarExtra`** hin: Das `label`-View eines `MenuBarExtra` wird von AppKit teils nur einmalig in ein statisches `NSImage` für den `NSStatusItem`-Button „eingefroren" und aktualisiert sich NICHT zuverlässig allein durch SwiftUI-State-Änderungen, selbst wenn der State korrekt `@Observable`/`@Environment` gebunden ist (bekanntes Verhalten auf mehreren macOS-Versionen, kein reiner Programmierfehler mehr).

**Empfohlener Fix (Runde 7):** Weg von reiner SwiftUI-Reaktivität, stattdessen das Icon **imperativ** über einen eigenen `NSStatusItem`-Controller aktualisieren:
1. Eigene Klasse (z. B. `MenuBarIconController`, `NSObject`), hält eine Referenz auf den `NSStatusItem` (entweder den von `MenuBarExtra` intern verwalteten holen ist nicht offiziell möglich — daher ggf. ganz auf eigenen `NSStatusItem` statt `MenuBarExtra` fürs Icon-Label umsteigen, mit `NSPopover`/eigenem Fenster für den Klick-Inhalt, falls das nötig ist).
2. Bei jeder Änderung von `appState.menuBarBadgePreview` **aktiv** `statusItem.button?.image = HardDrivesTemplateIcon.make(badge:)` neu setzen — z. B. via `withObservationTracking(_:onChange:)` rekursiv, oder indem `AppState` das Badge als `didSet`-artigen Hook nach außen meldet (z. B. Callback/Combine), den der Controller abonniert.
3. Das ist ein größerer struktureller Umbau als der Versuch aus Runde 6 — bitte kurz recherchieren, ob es 2024/2025 einen saubereren offiziellen Weg gibt (z. B. neuere SwiftUI-APIs für `MenuBarExtra`-Label-Updates), bevor der komplette Umbau auf reinen `NSStatusItem` gemacht wird. Falls kein sauberer Weg gefunden wird, ist der `NSStatusItem`-Umbau der Fallback.

**Review-Fix (Cursor, Runde 8):** `MenuBarExtra` entfernt; `MenuBar/MenuBarController.swift` (eigenes `NSStatusItem`, `NSPopover` mit `MenuBarRootView`), `MenuBarIconRenderer.swift` (Badge → `NSImage`), `App/AppDelegate.swift` + `AppDelegateBridge.swift` (ein `AppState`, Install in `applicationDidFinishLaunching`); Badge-Updates rekursiv via `withObservationTracking`. Popover/Fenster: `App/AppWindowPresenter.swift` (Haupt- und Neues-Medium-Fenster ohne `OpenWindowAction` im Popover). Rechtsklick-Kontextmenü am Status-Button. Bitte Debug-Picker erneut visuell prüfen. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 9) — Regression im neuen Code, Ursache eindeutig:** ❌ Jetzt ist **gar kein Icon** mehr sichtbar. In [MenuBarController.swift:58](diskindex/diskindex/MenuBar/MenuBarController.swift:58) (Methode `updateStatusImage()`) steht:
```swift
button.image?.isTemplate = false
```
Das deaktiviert das Template-Rendering für den Status-Item-Button explizit. Ohne `isTemplate = true` tintet macOS das Bild **nicht** automatisch passend zur (hellen/dunklen) Menüleiste — es wird als normales Vollfarb-Icon behandelt. Da [MenuBarIconRenderer.swift](diskindex/diskindex/MenuBar/MenuBarIconRenderer.swift) über `MenuBarStatusIconView`/`HardDrivesGlyph` mit schwarzer Füllfarbe (`Color.primary`/`Color.black`) rendert, ist das Ergebnis ein **schwarzes Icon auf dunkler Menüleiste** — quasi unsichtbar. Das erklärt exakt den gemeldeten Zustand „kein Icon mehr".

**Fix:** Zeile `button.image?.isTemplate = false` entfernen bzw. auf `true` setzen — genau umgekehrt zur aktuellen Zeile:
```swift
button.image?.isTemplate = true
```
Das ist vermutlich als (falscher) Fix für ein anderes vermutetes Problem eingefügt worden (evtl. um zu verhindern, dass macOS Farben aus dem gerenderten Bild wegfiltert) — bitte NICHT wieder entfernen ohne zu verstehen warum, sondern einfach auf `true` setzen und danach in Light- **und** Dark-Menüleiste per Screenshot bestätigen, dass das Icon sichtbar UND korrekt getintet ist (weiß auf dunkel, schwarz auf hell) — das war ja der ursprüngliche Zweck von `isTemplate`.

**Review (Claude, 20.09., Runde 10) — zwei neue Bugs nach dem `isTemplate`-Fix:**

1. ❌ **Badge wird durch `isTemplate` mit zerstört, sobald ein Badge aktiv ist.** Root Cause: [MenuBarIconRenderer.swift](diskindex/diskindex/MenuBar/MenuBarIconRenderer.swift) rendert `MenuBarStatusIconView` (Glyph **+** Badge zusammen, siehe [MenuBarStatusIconView.swift](diskindex/diskindex/MenuBar/MenuBarStatusIconView.swift)) in **ein einziges** `NSImage`. Wird auf dieses kombinierte Bild `isTemplate = true` gesetzt (der gerade gemachte Fix), wirft macOS **alle Farbinformationen des gesamten Bildes weg** — inklusive der absichtlich farbigen Badges (blauer Spinner-Ring, rotes "!", blauer Puls-Punkt laut Design-Tokens). Das erklärt "Badge hat keinen Inhalt" bzw. wirkt kaputt.

   **Fix — Glyph und Badge müssen getrennt gerendert werden:**
   - Der **Haupt-Glyph** (`HardDrivesTemplateIcon`) bleibt als eigenes `NSImage` mit `isTemplate = true` — das ist korrekt und soll so bleiben (adaptiert an Light/Dark-Menüleiste).
   - Der **Badge** (Ring/Punkt/„!"/X) darf NICHT Teil dieses Template-Bildes sein. Zwei Optionen: (a) Badge als eigene kleine `NSView`/`NSHostingView` als Subview über dem `NSStatusItem`-Button positionieren (unten rechts, `bottomTrailing`, feste Pixel-Offsets), unabhängig vom Template-Image und mit voller Farbe; oder (b) zwei separate `NSImage`s zeichnen und beide auf den Button-Bereich compositen, aber nur das Glyph-Bild als `button.image` mit `isTemplate=true`, den Badge separat wie in (a). Option (a) ist robuster. Bitte diesen Weg umsetzen, nicht wieder alles in ein Bild flatten.

2. ❌ **Pfeil/Dreieck am Popover, nicht im Mockup.** `NSPopover` zeichnet standardmäßig einen Pointer-Pfeil zum Status-Item — Screen 03 im Mockup zeigt ein einfaches abgerundetes Rechteck ohne Pfeil. Zwei Optionen: (a) `popover.setValue(0, forKeyPath: "arrowSize")` — funktioniert, ist aber eine undokumentierte private KVC-API (Risiko: kann bei macOS-Updates brechen, für App-Store-Submission ggf. problematisch); (b) sauberer: komplett von `NSPopover` weg auf ein eigenes **borderless `NSWindow`/`NSPanel`** umsteigen, das unterhalb des Status-Items positioniert wird (viele Menu-Bar-Apps machen das so für volle Kontrolle über Form/Schatten/kein Pfeil). Bitte (b) bevorzugen, falls der Umbau überschaubar ist — sonst (a) als Zwischenlösung mit Kommentar, warum es eine private API ist.

**Review (Claude, 20.09., Runde 11):** ✅ Badges sind jetzt farbig korrekt sichtbar (Glyph/Badge-Trennung hat funktioniert, per Screenshot bestätigt). ❌ **Neue Regression durch den Umstieg auf `NSPanel` (Option b oben):** Das Panel wird jetzt komplett falsch positioniert — erscheint nicht unter dem Status-Item, sondern in einer Ecke/außerhalb des sichtbaren Bereichs. Code in [MenuBarController.swift:174-180](diskindex/diskindex/MenuBar/MenuBarController.swift:174) (`position(panel:below:)`) sieht auf den ersten Blick plausibel aus (Button-Bounds → Screen-Koordinaten → Panel mittig darunter), enthält aber `guard let window = button.window else { return }` — falls `button.window` beim ersten Klick noch `nil` ist (bekannter Timing-Fallstrick bei `NSStatusItem`-Buttons, deren Fenster teils erst nach dem ersten Rendern/Klick verfügbar ist), wird diese Methode **komplett übersprungen** und das Panel bleibt bei seinem Default-Origin (0,0) bzw. wo auch immer `NSPanel` es beim Erzeugen hinlegt — das würde exakt das beobachtete „außerhalb des Screens"-Verhalten erklären.

**Bitte prüfen:**
1. Mit `print`/Breakpoint verifizieren, ob `button.window` beim Aufruf tatsächlich `nil` ist bzw. ob `screenRect`/`originX`/`originY` plausible Werte enthalten (grob: `originY` sollte nahe der Bildschirmhöhe minus Menüleisten-Höhe minus Panel-Höhe liegen, nicht 0 oder negativ groß).
2. Falls `button.window` wirklich `nil` sein kann: Fallback einbauen, der stattdessen `NSStatusBar.system` bzw. `button.screen`/`NSScreen.main` nutzt, oder die Positionierung erst im nächsten Runloop-Tick (`DispatchQueue.main.async`) nach dem Anzeigen berechnet, wenn das Fenster garantiert existiert.
3. Zusätzlich defensiv gegen Screen-Ränder clampen (`NSScreen.visibleFrame`), damit das Panel nie über den sichtbaren Bereich hinausragt, unabhängig vom Multi-Monitor-Setup.

**Review (Claude, 20.09., Runde 12) — Padding-Bug im Hover-Highlight gefunden:** ❌ Das Hover-Highlight-Rechteck einer Medium-Zeile wirkt eingerückt/schmaler als der Rest der Zeile. Ursache: [MenuBarConnectedMediumRow.swift:27-33](diskindex/diskindex/MenuBar/MenuBarConnectedMediumRow.swift:27) zeichnet den Hover-`background` INNERHALB der Zeile, aber `MenuBarPopoverView.idleContent` packt jede Zeile von außen zusätzlich in `.padding(.horizontal, 14)`, bevor das gerendert wird — das Highlight-Rechteck liegt also innerhalb dieses äußeren Paddings und wirkt dadurch schmaler/eingerückt im Vergleich zu unhovered Zeilen (die einfach den durchgehenden Panel-Hintergrund zeigen, keinen eigenen Rahmen). Fix: horizontales Padding umdrehen — die **Zeile selbst** (inkl. Hover-Background) soll bis an die Panel-Kante (minus einheitlichem Panel-Innenabstand) reichen; das Padding für Icon/Text/Button gehört **innerhalb** von `MenuBarConnectedMediumRow`, nicht außerhalb um die ganze Zeile herum. Am saubersten: `.padding(.horizontal, 14)` aus `idleContent` entfernen und stattdessen als `.padding(.horizontal, 14)` auf den `HStack`-Inhalt in `MenuBarConnectedMediumRow` selbst legen (Hover-`background` bleibt außerhalb dieses inneren Paddings, deckt die volle Zeilenbreite ab).

**Review (Claude, 20.09., Runde 13) — Überkorrektur, jetzt zu weit in die andere Richtung:** ❌ Der Fix aus Runde 12 wurde umgesetzt, aber das äußere Padding wurde komplett entfernt statt nur an die richtige Stelle verschoben — jetzt reicht das Hover-Rechteck bis auf 0px an die Panel-Kante (siehe Screenshot: berührt den Rand direkt). Laut Mockup ([Catalog App Design.dc.html:295](layout/Catalog%20App%20Design.dc.html:295), Container-Padding `var(--space-3) var(--space-3) var(--space-2)` = **12px** links/rechts) soll der gesamte "ANGESCHLOSSEN"-Block **12px Innenabstand vom Panel-Rand** haben — das Hover-Highlight darf bis an diesen 12px-Rand reichen (nicht bis 0px, aber auch nicht mit einem zusätzlichen inneren Extra-Inset wie vorher).

**Fix:** Genau **ein** Padding-Level mit 12px, nicht zwei (vorher) und nicht keins (jetzt):
- `MenuBarPopoverView.idleContent`: `.padding(.horizontal, 12)` auf den **äußeren Container** (die `VStack`, die `sectionHeader` + alle Zeilen enthält) — nicht auf jede einzelne Zeile.
- `MenuBarConnectedMediumRow`: **kein** horizontales Padding mehr auf den `HStack`-Inhalt, das Hover-`background` deckt die volle Zeilenbreite innerhalb des schon vom Container vorgegebenen 12px-Randes ab.

Bitte kurz nachvollziehen, dass „Fortschritt der Indizierung"-Zeile (Spinner-Ring + „67 %", dotted-underline) dabei nicht durcheinandergerät — die Unterstreichung selbst ist laut Mockup korrekt (`text-decoration:underline dotted` mit `accent 50%`), das war beim letzten Screenshot schwer zu beurteilen, da nur ein enger Ausschnitt zu sehen war. Bitte einen vollständigen, nicht zugeschnittenen Screenshot des Popovers zur nächsten Runde mitschicken, damit ich das ganze Layout auf einmal beurteilen kann statt einzelne Ausschnitte zu raten.

**Review-Fix (Cursor, Runde 13):** `idleContent`-`VStack` mit einmalig `.padding(.horizontal, 12)` (Mockup `--space-3`); kein Extra-Padding pro Zeile; `MenuBarConnectedMediumRow` ohne horizontales Innen-Padding — Hover bis zum 12px-Rand. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 16) — Popover erscheint ohne Übergang:** ❌ Seit dem Umstieg von `NSPopover` auf ein eigenes `NSPanel` ([MenuBarController.swift:166](diskindex/diskindex/MenuBar/MenuBarController.swift:166), `panel.orderFrontRegardless()`) gibt es **keinerlei Erscheinungs-Animation** mehr — das Panel poppt hart an seine Position, wirkt wie ein Sprung/Glitch ("aus dem Nichts"). `NSPopover` hatte das eingebaut, das eigene `NSPanel` nicht. Fix: kurzer Fade-In beim Anzeigen, z. B.:
```swift
panel.alphaValue = 0
position(panel: panel, below: button)
panel.orderFrontRegardless()
NSAnimationContext.runAnimationGroup { context in
    context.duration = 0.12
    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
    panel.animator().alphaValue = 1
}
```
Reicht als einfacher, unaufdringlicher Effekt — kein aufwendiges Slide/Scale nötig, nur damit es nicht mehr wie ein Rendering-Fehler aussieht. Beim Schließen (`performClose`/Klick außerhalb) darf gerne ein ähnlich kurzer Fade-Out ergänzt werden, ist aber zweitrangig gegenüber dem Erscheinen.

**Review-Fix (Cursor, Runde 16):** `showDropdown` — `alphaValue = 0`, dann `fadeIn` (0,12s, easeOut); `closePanel` — Fade-Out 0,1s vor `orderOut`, `alphaValue` danach zurück auf 1. `xcodebuild` ✅.

**Review-Fix (Cursor, Runde 12):** `.padding(.horizontal, 14)` aus `MenuBarPopoverView.idleContent` entfernt; in `MenuBarConnectedMediumRow` innerer `HStack` mit Padding, äußerer Wrapper `frame(maxWidth: .infinity)` + Hover-`background` über volle Panelbreite. `xcodebuild` ✅.

**Review-Fix (Cursor, Runde 11):** `statusItemScreenRect(for:)` — zuerst `button.window`, sonst Status-Bar-Fenster via `NSApp.windows` + `isDescendant`, sonst Mausposition; `position(panel:below:)` clamped auf `NSScreen.visibleFrame`; Reposition im nächsten Runloop nach `orderFrontRegardless`. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 17) — Feinjustierung Badge-Position:** ❌ Badge sitzt laut Nutzer 2-3px zu weit unten. In [MenuBarController.swift:104](diskindex/diskindex/MenuBar/MenuBarController.swift:104) steht `container.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: 1)`. Bitte den Constant-Wert um **2px nach oben** korrigieren, also von `1` auf `-1` ändern:
```swift
container.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -1),
```
Nur dieser eine Wert, sonst nichts an der Badge-Positionierung ändern (x-Achse/trailing bleibt wie es ist, dazu kam kein Feedback).

**Review-Fix (Cursor, Runde 17):** Badge-Container `bottomAnchor` constant `1` → `-1`. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 18) - Kontextmenue "Oeffnen" tut nichts, Root Cause gefunden:** Fehler: `NSMenuItem(title: "Oeffnen", ...)` postet `.openMainWindowRequest` ([MenuBarController.swift:134-135](diskindex/diskindex/MenuBar/MenuBarController.swift:134)), aber die einzige Stelle, die diese Notification empfaengt, ist `.onReceive(...)` in [MenuBarRootView.swift:14](diskindex/diskindex/MenuBar/MenuBarRootView.swift:14) - und `MenuBarRootView` existiert nur, WAEHREND das Dropdown-Panel gerade sichtbar ist (wird als `NSHostingController`-Inhalt nur beim Oeffnen des Panels erzeugt). Klickt man "Oeffnen" per Rechtsklick, OHNE dass das Panel gerade offen ist (der uebliche Fall), gibt es niemanden, der die Notification empfaengt - sie verpufft. "Beenden" funktioniert, weil es direkt `NSApp.terminate` aufruft, ganz ohne Notification-Umweg.

Fix: `openMainWindow()` in `MenuBarController.swift` soll DIREKT `AppWindowPresenter.openMain(appState:destination:)` aufrufen (der Controller hat bereits eine `appState`-Referenz), statt eine Notification zu posten, auf die nur eine ephemere View hoert.

**Review-Fix (Cursor, Runde 18):** `openMainWindow()` ruft `MenuBarPopoverDismiss.openMainWindowFromMenuBar(destination: .dashboard, …)` mit gespeicherter `appState`-Referenz auf; `closePanel()` falls Panel offen. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 19) - Hover-Stil der Medium-Zeile prazisiert (Nutzer hat Mockup-DOM direkt zitiert):** Der Unterschied normal/hover ist im Mockup exakt definiert:
- **Normal:** `padding: var(--space-3) 0` (12px vertikal, **0px horizontal** - Inhalt liegt direkt am 12px-Container-Rand).
- **Hover:** `padding: var(--space-3) 6px` PLUS `margin: 0 -6px` - die Zeile wird beim Hover **6px breiter als ihr eigener Inhalt** (links und rechts), dazu `background: color-mix(text 6%)`, `border-radius: var(--radius-sm)`. Der Inhalt (Icon/Text) bleibt dabei optisch an derselben horizontalen Position wie im Normal-Zustand - nur die Hintergrund-Box woelbt sich sichtbar ueber die normale Zeilenbreite hinaus.

Aktuell in [MenuBarConnectedMediumRow.swift](diskindex/diskindex/MenuBar/MenuBarConnectedMediumRow.swift) wird beim Hover nur ein `background` in der EXAKT GLEICHEN Groesse wie der Zeileninhalt eingeblendet - kein "Hinauswachsen" ueber die Zeilengrenze. Das erklaert den "klebt"-Eindruck: der Hover-Effekt wirkt flach/eingeschlossen statt wie im Mockup leicht ueberstehend.

**Fix (SwiftUI hat kein CSS-`margin`, aber negatives Padding auf den Background erzeugt denselben Effekt):**
```swift
.background {
    if isHovered {
        RoundedRectangle(cornerRadius: DesignRadius.sm)
            .fill(DesignColor.text.opacity(0.06))
            .padding(.horizontal, -6)   // laesst den Hintergrund 6px ueber die Zeile hinausragen
    }
}
```
Der Zeileninhalt selbst (Icon/Text/Button) braucht dafuer KEIN zusaetzliches horizontales Padding - der bleibt wie er ist, nur der Hintergrund wird breiter gezogen. Bitte exakt so umsetzen (negatives Padding auf den Hintergrund, nicht auf den Content), sonst verschiebt sich wieder der Text.

**Review-Fix (Cursor, Runde 19):** Hover-`RoundedRectangle` mit `.padding(.horizontal, -6)` (6 % Text-Fill unverändert). `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 18) - Fenster-Position/-Groesse wird nicht gemerkt:** Fehler: [AppWindowPresenter.swift](diskindex/diskindex/App/AppWindowPresenter.swift) ruft bei jedem Neuerstellen `window.center()` auf ([Zeile 41](diskindex/diskindex/App/AppWindowPresenter.swift:41)) - keine Persistenz von Position/Groesse zwischen App-Starts. Standard-AppKit-Fix: `window.setFrameAutosaveName("MainWindow")` direkt nach dem Erzeugen aufrufen; das liest beim naechsten Start automatisch aus `UserDefaults` und positioniert das Fenster entsprechend. `window.center()` nur noch als Fallback, falls noch kein gespeicherter Frame existiert (z. B. `if !window.setFrameUsingName("MainWindow") { window.center() }`).

**Nachtrag (Nutzer, 21.09.):** Der Erst-Start-Fallback (bevor ein gespeicherter Frame existiert) soll konkret **1100x750**, **mittig auf dem Bildschirm** sein - nicht oben an der Menueleiste kleben. Aktuell erzeugt [AppWindowPresenter.swift:35](diskindex/diskindex/App/AppWindowPresenter.swift:35) das Fenster mit `contentRect: NSRect(x: 0, y: 0, width: 960, height: 640)` und ruft danach `window.center()` auf - die Groesse muss auf **1100x750** geaendert werden. Falls das "oben an der Menueleiste kleben" tatsaechlich beobachtet wurde (nicht nur befuerchtet): `window.center()` zentriert eigentlich korrekt auf dem Hauptbildschirm - falls es trotzdem oben klebt, koennte das mit dem `NSPanel`-Level (`.popUpMenu`) der Menueleisten-Panel-Logik zusammenhaengen faelschlich auf das Hauptfenster uebertragen worden sein, oder `window.center()` wird VOR dem tatsaechlichen Setzen der finalen `contentRect`-Groesse aufgerufen. Bitte pruefen und mit den neuen Massen (1100x750) nochmal frisch (ohne alten gespeicherten Frame, z. B. `defaults delete xjonx.diskindex` zum Testen) verifizieren.

**Review-Fix (Cursor, Nachtrag 21.09.):** Erst-Start `defaultMainWindowSize` 1100×750; ohne gespeicherten Frame `centerMainWindowOnVisibleScreen` (visibleFrame, nicht nur `center()`). `AppWindowPresenter.swift`. `xcodebuild` ✅.

**Review-Fix (Cursor, Runde 18):** Hauptfenster `setFrameAutosaveName("DiskIndexMainWindow")`; `setFrameUsingName` vor `center()` als Fallback. `xcodebuild` ✅.

**Review-Fix (Cursor, Runde 10):** Glyph nur noch `HardDrivesTemplateIcon` + `isTemplate = true`; farbiger Badge als `NSHostingView` (`MenuBarStatusBadgeView`) unten rechts auf dem Status-Button (nicht im Template-Bitmap). Dropdown: borderless `NSPanel` (`.popUpMenu`, Schatten, ohne Pfeil) statt `NSPopover`; Klick außerhalb schließt; `MenuBarController.closePanel()` auch aus `MenuBarPopoverDismiss.openMainWindow`. `xcodebuild` ✅.

**Review-Fix (Cursor, Runde 9):** `updateStatusImage()` setzt `button.image?.isTemplate = true`; Idle-Badge nutzt direkt `HardDrivesTemplateIcon.make()` ohne `ImageRenderer`. Bitte Light/Dark-Menüleiste + Badge-Zustände visuell prüfen (farbige Badges ggf. durch Template-Tint eingeschränkt). `xcodebuild` ✅.

---

## 3. Popover / Dropdown (README Screen 03)

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

- **Views:** `MenuBar/MenuBarPopoverView.swift` (Ruhe/Suche-Umschaltung), `MenuBarConnectedMediumRow.swift`, `MenuBarPopoverSearchContent.swift`; `Views/MainWindowHostView.swift` (Dashboard vs. Suche-Platzhalter für „Alle Ergebnisse").
- **DesignSystem:** `BinaryButtonGroup`, `StatusChip`, `MediumCompactSearchField` (150px), `IndexingProgressBar`, `MediumTypeIcon` + Phosphor-Assets `MediumTypeUSB/SSD/HDD`.
- **Ruhe:** Header Glyph + Titel + Suche; „ANGESCHLOSSEN“ aus `connectedMedia`; Index-Zeile mit blauem Fortschrittsbalken + klickbarem %/absolut (`showAbsoluteCapacity` global); sonst Status-Chip; Hover → Ghost „Neu indizieren“; Footer An/Pausiert + „Disk Index öffnen“.
- **Suche:** Bei Text im Suchfeld Top-Gruppen (Mock `PopoverSearchMock`); Button „Alle 9 Ergebnisse anzeigen“ setzt `searchState.query`, `mainWindowDestination = .search`, öffnet Fenster.
- **State:** `popoverSearchText`, `mainWindowDestination` in `AppState`.

**Ruhezustand:**
- Header: Glyph + „Disk Index" + kompaktes Suchfeld (150px, siehe Design Tokens → Medium-Suche-Größe).
- Abschnitt „ANGESCHLOSSEN": pro Medium Zeile mit Typ-Icon, Name, und entweder Indexier-Fortschrittsbalken (solid accent blue, **kein** Gradient — anderes Konzept als Storage-Fill) mit klickbarem %/absolut-Toggle, oder Status-Chip.
- Hover-State auf Medium-Zeile: Ghost-Button „Neu indizieren" erscheint rechts.
- Footer: „Automatisches Indizieren" Label + An/Pausiert-Button-Group (siehe Design Tokens → Button-Group-Regel).
- Unten: Ghost-Button „Disk Index öffnen" → öffnet Hauptfenster (Screen 04).

**Suchzustand:**
- Gleiches Panel, Inhalt ersetzt durch Top-3-Gruppen (Speichermedien / Dateien / Ordner).
- Datei/Ordner-Zeilen gedimmt-grau, Name mit Ellipsis, Ort nach Halbgeviertstrich angehängt (`name.pdf – Backup SSD`).
- Button „Alle 9 Ergebnisse anzeigen" → öffnet Screen 07.

**Akzeptanzkriterium:** Umschalten zwischen Ruhe- und Suchzustand bei Tippen im Suchfeld; Hover-Reveal funktioniert; Button-Group zeigt korrekte Border-Farbe je nach aktivem Zustand.

**Review-Fix (Cursor):** Popover schließt via `@Environment(\.dismiss)` + `MenuBarPopoverDismiss.openMainWindow` (auch Such-Button); `BinaryButtonGroup` — aktives `.second` mit `DesignColor.neutral300`. `xcodebuild` ✅.

**Review-Fix (Cursor):** Hover ohne Reflow (fester Trailing-Slot); Ghost-Button mit Rand; `NSApp.activate` + Fenster nach vorne; stabiler Popover-Header + `@FocusState`; Suchtext bei `onDisappear` leeren. `xcodebuild` ✅.

**Review-Fix (Cursor, Runde 14):** Suchfeld-Fokus: Header behält Glyph/Titel im Layout (nur `opacity`/`frame`, kein `if !isSearching`); stabile `TextField`-Identität via `optionalFocused` in `MediumCompactSearchField`; `.id("popoverHeaderSearch")` + `onChange` setzt Fokus beim Tippen. Hauptfenster: weiterhin `AppWindowPresenter` + `NSApp.activate`; Suchtext-Reset via `MenuBarController.closePanel()` / `onDisappear`. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 3) — mehrere Layout-/Interaktions-Bugs, bitte alle vor „erledigt" fixen:**
1. ~~Hover~~ → Review-Fix oben. (Layout verschiebt sich sichtbar beim Hover). Im Mockup bleibt die Zeile an Ort und Stelle, nur der „Neu indizieren"-Ghost-Button erscheint zusätzlich rechts — kein Reflow/Einrücken der bestehenden Inhalte. Vermutlich ein `HStack`, das durch das bedingte Einblenden des Buttons zusätzlichen Platz beansprucht, statt dass der Button über eine feste Reserve-Breite oder `.overlay` eingeblendet wird.
2. ❌ **„Disk Index öffnen"-Button sieht falsch aus** (aktuell wie ein normaler Zeilentext/Listeneintrag statt wie ein Ghost-Button). Laut README/Mockup: Ghost-Button-Optik (dezenter Rahmen oder Hover-Hintergrund, keine reine Fließtext-Zeile).
3. ❌ **Hauptfenster öffnet sich im Hintergrund** — Klick auf „Disk Index öffnen" öffnet das Fenster, aber es kommt nicht nach vorne / wird nicht aktiviert. Nach `openWindow(id:)` zusätzlich `NSApp.activate(ignoringOtherApps: true)` aufrufen (oder das Fenster gezielt `makeKeyAndOrderFront`), damit es tatsächlich in den Vordergrund kommt.
4. ❌ **Suchfeld verliert Fokus nach dem ersten Buchstaben.** Vermutlich wird die View, die das `TextField` enthält, bei jeder Textänderung neu aufgebaut (z. B. weil sich `popoverSearchText`/`mainWindowDestination`-Änderungen auf die View-Identität auswirken und SwiftUI das Feld für ein neues hält). Fokus-State prüfen — ggf. `@FocusState` explizit binden und sicherstellen, dass sich die Identität der TextField-View beim Tippen nicht ändert.
5. ❌ **Suchfeld-Inhalt bleibt nach Schließen des Popovers erhalten** — beim nächsten Öffnen sollte die Ruhezustand-Suche wieder leer sein (frischer State), nicht der alte Suchtext. Beim Schließen `popoverSearchText` zurücksetzen (z. B. im `dismiss`-Handler oder via `.onDisappear`).

**Review-Fix (Cursor, Runde 5):** `MenuBarGhostButton` — accent, kein Rand, Hover accent 10 % (`.btn-ghost`). `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 4) — Punkt 2 immer noch falsch:** ❌ Der „Ghost-Button mit Rand"-Fix trifft nicht das Original. Im Mockup ist `.btn-ghost` (siehe [ds-modernist.css:132-134](layout/ds-modernist.css:132)) definiert als: `color: var(--color-accent)` (blauer Text), **kein Rahmen, kein Hintergrund** im Ruhezustand, nur `background: color-mix(accent 10%)` beim Hover. Das gilt für **„Disk Index öffnen" UND „Neu indizieren"** — beide nutzen dieselbe `.btn-ghost`-Klasse im Mockup (Zeilen 322 + 334 im HTML). Der aktuelle `MenuBarGhostButtonStyle` ([MenuBarConnectedMediumRow.swift:124](diskindex/diskindex/MenuBar/MenuBarConnectedMediumRow.swift:124)) zeichnet stattdessen einen grauen Rahmen mit `DesignColor.text`-farbenem Text — das ist der falsche Button-Typ (sieht eher wie ein sekundärer/outline Button). Bitte `MenuBarGhostButtonStyle` korrigieren: `foregroundStyle(DesignColor.accent)`, kein `strokeBorder`/`overlay`-Rahmen, `background` nur bei Hover (`isHovered`, nicht nur `isPressed`) leicht accent-getönt.

**Neue Aufgabe (Nutzer, 21.09.) — Klick auf Medium-Zeile im Popover öffnet Column Browser:** Aktuell hat [MenuBarConnectedMediumRow.swift](diskindex/diskindex/MenuBar/MenuBarConnectedMediumRow.swift) keinerlei Tap-Handler auf der Zeile selbst — nur die Controls im `trailingSlot` (Reindex-Button, %/absolut-Toggle) sind klickbar. Gewünscht: Klick auf die Zeile (Icon+Name-Bereich) öffnet den Column Browser für **genau dieses Medium** — Ausnahme: der Reindex-Button-Klick beim Hover-Zustand soll weiterhin nur den Reindex auslösen, nicht zusätzlich navigieren.

**Fix:** Die Navigation gehört es es bereits fertig als `MediumNavigation.openColumnBrowser(for: mediumID, appState: appState)` — dieselbe Funktion, die auch Dashboard-Karten und Registry-Zeilen nutzen (siehe [MediumNavigation.swift:41](diskindex/diskindex/App/MediumNavigation.swift:41)). Popover muss dabei natürlich vorher geschlossen werden (`MenuBarController.shared.closePanel()` bzw. den bestehenden Dismiss-Mechanismus nutzen, wie schon bei „Disk Index öffnen"). Am saubersten: `.onTapGesture` NUR auf den Bereich `MediumTypeIcon + rowBody` legen (nicht auf den kompletten `HStack`, der auch `trailingSlot` enthält), damit der Reindex-Button/%-Toggle im `trailingSlot` ihre eigene, unabhängige Klick-Zone behalten und nicht doppelt/versehentlich beides auslösen.

**Review-Fix (Cursor, Runde 28):** Tap auf Icon+Name in `MenuBarConnectedMediumRow` → `MediumNavigation.openColumnBrowser`, `AppWindowPresenter.openMain(.columnBrowser)`, `MenuBarController.shared.closePanel()`; `trailingSlot` unverändert eigene Hit-Zone. Mock „Neu indizieren“ setzt `indexStatus = .indexing`. `xcodebuild` ✅.

## 3b. Popover — Runde 20: Suchfeld-Fokus & Schliess-Bug

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

1. Fehler: **Suchfeld im Popover nimmt keinen Tastatur-Fokus an, Klick tut nichts.** Root Cause: Das Panel wird als reines `NSPanel(styleMask: [.borderless, .nonactivatingPanel], ...)` erzeugt ([MenuBarController.swift:166](diskindex/diskindex/MenuBar/MenuBarController.swift:166)), ohne eigene Subklasse. Borderless Fenster geben in AppKit standardmaessig `canBecomeKey = false` zurueck - ohne das explizit zu ueberschreiben, kann KEIN `TextField` innerhalb jemals echten Tastatur-Fokus bekommen, unabhaengig davon, was SwiftUI-seitig (`@FocusState` etc.) versucht wird.

   **Fix:** Eine kleine `NSPanel`-Subklasse einfuehren, die `canBecomeKey` explizit auf `true` setzt (Standard-Loesung fuer genau dieses Muster - borderless Popup-Panel mit Texteingabe):
   ```swift
   final class KeyablePanel: NSPanel {
       override var canBecomeKey: Bool { true }
   }
   ```
   Diese Klasse statt `NSPanel(...)` instanziieren. Zusaetzlich beim Anzeigen nicht nur `orderFrontRegardless()`, sondern auch `panel.makeKey()` aufrufen, damit es tatsaechlich zum Key-Window wird (der `.nonactivatingPanel`-StyleMask bleibt bestehen, der verhindert nur, dass die App unnoetig in den Vordergrund aktiviert wird - er verhindert NICHT explizites `makeKey()`).

2. Fehler: **Popover laesst sich nicht mehr schliessen, wenn das Hauptfenster gerade offen/aktiv ist** - Klick auf das Menueleisten-Icon oeffnet das Popover, ein erneuter Klick (oder Klick ausserhalb) schliesst es dann aber nicht mehr. Ich habe mir `toggleDropdown`, `closePanel`, `installOutsideClickMonitors`/`handleOutsideClick` in [MenuBarController.swift](diskindex/diskindex/MenuBar/MenuBarController.swift) angeschaut - der Code sieht auf den ersten Blick korrekt aus (Status-Button-Klick prueft `dropdownPanel.isVisible` und ruft `closePanel()`, der Outside-Click-Monitor schliesst ebenfalls). Ich kann die App hier nicht selbst ausfuehren, um die genaue Ursache zu sehen. **Bitte reproduzieren und dabei kurz Debug-Prints/Breakpoints setzen** in `statusBarButtonClicked`, `toggleDropdown` und `handleOutsideClick`, um zu sehen: Wird `toggleDropdown` beim zweiten Klick ueberhaupt aufgerufen? Ist `dropdownPanel.isVisible` zu diesem Zeitpunkt `true`? Feuert der Outside-Click-Monitor gar nicht mehr, sobald das Hauptfenster (ein eigenes, normales `NSWindow`) key/aktiv ist? Ein moeglicher Verdacht: `NSApp.activate(ignoringOtherApps: true)` beim Oeffnen des Hauptfensters ([AppWindowPresenter.swift](diskindex/diskindex/App/AppWindowPresenter.swift)) koennte mit dem Panel-Fokus-Handling (Punkt 1 oben) interferieren, sobald beide - Hauptfenster UND `canBecomeKey`-faehiges Panel - gleichzeitig um den Key-Status konkurrieren. Bitte NACH dem Fix aus Punkt 1 nochmal gezielt testen, ob das Problem dann von selbst verschwindet (haengt evtl. zusammen), und nur falls nicht, weiter debuggen.

**Review-Fix (Cursor, Runde 20):** `KeyablePanel` (`canBecomeKey`); Panel via `makeKey()` nach `orderFrontRegardless()`; Toggle/Outside-Click über `isDropdownOpen` statt `dropdownPanel.isVisible`; Panel-Referenz erst nach Fade-Out freigeben; Local-Monitor synchron auf MainActor. Dateien: `MenuBar/KeyablePanel.swift`, `MenuBarController.swift`. Bitte Schließen mit offenem Hauptfenster manuell prüfen. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 21) - Layout der Popover-Suchergebnisse nicht korrekt:**

1. Fehler: **Grosse leere Flaeche zwischen Suchfeld und "SPEICHERMEDIEN"-Sektion** (Screenshot bestaetigt). Ich habe [MenuBarPopoverView.swift](diskindex/diskindex/MenuBar/MenuBarPopoverView.swift) und [MenuBarPopoverSearchContent.swift](diskindex/diskindex/MenuBar/MenuBarPopoverSearchContent.swift) durchgesehen - kein offensichtlicher Spacer/fixe Hoehe im SwiftUI-Code selbst. Verdacht: Das Panel wird beim OEFFNEN im Ruhezustand erzeugt (`hosting.sizeThatFits(...)` misst dabei die LAENGERE Ruhezustand-Liste, z. B. 6 Medien-Zeilen + Footer), die `NSPanel`-`contentRect`-Hoehe bleibt danach FEST, auch wenn der Nutzer tippt und der Inhalt auf die kuerzere Suchergebnis-Ansicht wechselt - der SwiftUI-Root (`VStack(spacing: 0)` in `MenuBarPopoverView.body`) hat aber `.frame(width: panelWidth)` OHNE zugehoeriges `maxHeight`/`alignment: .top`, wodurch der jetzt kuerzere Inhalt in der zu hoch gewordenen `NSHostingController`-Flaeche vermutlich nicht zuverlaessig oben pinnt.

   **Fix (robust, unabhaengig von der genauen Ursache):** Explizit `.frame(maxHeight: .infinity, alignment: .top)` auf den Root-`VStack` in `MenuBarPopoverView.body` (oder zumindest um den Header+Content-Block herum) setzen, damit der Inhalt IMMER am oberen Rand pinnt, egal wie viel Extra-Hoehe das Panel gerade hat. ZUSAETZLICH pruefen: wird die Panel-Hoehe (`hosting.sizeThatFits`) bei JEDEM Wechsel zwischen Ruhe-/Suchzustand neu berechnet und das Panel entsprechend verkleinert/vergroessert (nicht nur einmal beim ersten Oeffnen)? Falls nicht, das ebenfalls nachziehen, damit das Panel selbst mitschrumpft statt nur leeren Raum zu lassen.

2. Fehler: **"Alle X Ergebnisse anzeigen"-Button falscher Stil.** [MenuBarPopoverSearchContent.swift:37](diskindex/diskindex/MenuBar/MenuBarPopoverSearchContent.swift:37) nutzt `.buttonStyle(.bordered)` (natives macOS-Pill-Control) statt eines flachen, VOLLBREITEN sekundaeren Buttons wie im Mockup (`btn-secondary btn-block`, zentrierter Text, volle Breite). Im Projekt existiert bereits `SecondaryBorderButtonStyle` ([NewMediumDetectedDialog.swift](diskindex/diskindex/Views/Registry/NewMediumDetectedDialog.swift)) - bitte diesen wiederverwenden statt `.bordered`, und `.frame(maxWidth: .infinity)` beibehalten (steht schon da), damit der Button die volle Panel-Breite abzueglich Padding einnimmt.

**Review-Fix (Cursor, Runde 21):** Root-`VStack` `.frame(maxHeight: .infinity, alignment: .top)`; Panel-Höhe bei Ruhe↔Suche via `menuBarPopoverLayoutInvalidated` + `MenuBarController.updateDropdownPanelSize()` (Oberkante fix); „Alle Ergebnisse“ mit `SecondaryBorderButtonStyle`. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 22) - zwei Punkte:**

1. Aufgabe: **Debug-Badge-Picker aus dem Popover entfernen.** Der `#if DEBUG debugFooter(...) #endif`-Block ([MenuBarPopoverView.swift:39-41](diskindex/diskindex/MenuBar/MenuBarPopoverView.swift:39)) inkl. der `debugFooter(state:)`-Methode ([Zeile ~174](diskindex/diskindex/MenuBar/MenuBarPopoverView.swift:174)) soll komplett raus - wird nicht mehr gebraucht, Badge-Zustände sind verifiziert. Bitte den kompletten Block + die zugehörige Methode löschen (nicht nur auskommentieren).

2. Fehler: **Kopfbereich (Suchfeld-Header) ist immer noch zu hoch** - der Nutzer sagt explizit "oben ist immer noch zu hoch", nicht "Leerraum irgendwo in der Mitte". Das deutet darauf hin, dass der `.frame(maxHeight: .infinity, alignment: .top)`-Fix aus Runde 21 zu GROSSZUEGIG angewendet wurde und dabei den `header(...)`-Block SELBST streckt (inkl. seines grauen Hintergrunds `DesignColor.text.opacity(0.06)` und der Bottom-Divider-Linie), statt nur den Inhaltsbereich UNTER dem Header top-zu-pinnen. Bitte in [MenuBarPopoverView.swift](diskindex/diskindex/MenuBar/MenuBarPopoverView.swift) genau pruefen: sitzt `.frame(maxHeight: .infinity, alignment: .top)` auf dem AEUSSEREN `VStack` (der `header(...)` MIT umschliesst) oder gezielt nur auf dem Container UNTERHALB des Headers (Ruhe-/Suchinhalt + Footer)? Falls der Header mit eingeschlossen ist: `header(...)` aus diesem Geltungsbereich rausnehmen bzw. dem Header selbst eine `.fixedSize(horizontal: false, vertical: true)` geben, damit er unabhaengig von der restlichen verfuegbaren Panel-Hoehe immer seine intrinsische (kompakte) Hoehe behaelt und nicht mitgestreckt wird.

**Review-Fix (Cursor, Runde 22):** `#if DEBUG` Badge-Picker + `debugFooter` entfernt; Header `.fixedSize(vertical: true)`; `.frame(maxHeight: .infinity, alignment: .top)` nur auf Inhalt unterhalb des Headers. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 23) - VERBINDLICHE Hoehen-Spec, keine Messung mehr, feste Werte aus dem Mockup berechnet:**

Der bisherige Ansatz (Hoehe per `hosting.sizeThatFits(...)` zur Laufzeit MESSEN) ist seit mehreren Runden die Fehlerquelle - Messen von SwiftUI-Views aus AppKit heraus ist in diesem Fall unzuverlaessig. Ab jetzt: **feste, hartcodierte Konstanten**, aus dem Mockup exakt nachgerechnet. Bitte diese als `enum MenuBarPopoverLayout` (oder aehnlich, ein Single-Source-of-Truth fuer SwiftUI-Padding UND AppKit-Hoehenberechnung) anlegen:

```swift
enum MenuBarPopoverLayout {
    static let headerHeight: CGFloat = 50          // 26 (Suchfeld) + 12+12 (vertikales Padding)
    static let contentTopPadding: CGFloat = 12
    static let contentBottomPadding: CGFloat = 8
    static let sectionLabelHeight: CGFloat = 24     // "ANGESCHLOSSEN"-Label + margin-bottom
    static let rowHeightStandard: CGFloat = 56      // Name + Untertitel + Chip, kein Fortschrittsbalken
    static let rowHeightIndexing: CGFloat = 64      // Name + Untertitel + Fortschrittsbalken (hoeher)
    static let footerAutoIndexHeight: CGFloat = 48  // "Automatisches Indizieren"-Zeile
    static let footerOpenAppHeight: CGFloat = 44    // "Disk Index oeffnen"-Zeile
    static let panelMaxHeight: CGFloat = 480        // bewusst gewaehlter Maximalwert - siehe unten
    static let panelMinHeight: CGFloat = 130        // Header + minimaler Leerzustand
}
```

**Regeln, ohne Ausnahme:**
1. **Jede** SwiftUI-View, die diese Bloecke rendert (Header, Zeilen, Footer), verwendet exakt diese Konstanten als `.frame(height:)` bzw. Padding-Werte - kein `.fixedSize()`, kein `sizeThatFits`-Messen mehr fuer die Gesamthoehe.
2. Die **Panel-Hoehe wird in Swift-Code deterministisch AUSGERECHNET** (Summe der Konstanten je nach Anzahl/Art der Zeilen), NICHT von AppKit am gerenderten SwiftUI-View gemessen:
   ```swift
   var computedHeight = MenuBarPopoverLayout.headerHeight
   if isSearching {
       // Suchergebnis-Bloecke: eigene, ebenfalls feste Konstanten (siehe Suchergebnis-Bereich, Aufgabe 3b)
   } else {
       computedHeight += MenuBarPopoverLayout.contentTopPadding
       computedHeight += MenuBarPopoverLayout.sectionLabelHeight
       computedHeight += connectedMedia.reduce(0) { $0 + ($1.indexStatus == .indexing ? MenuBarPopoverLayout.rowHeightIndexing : MenuBarPopoverLayout.rowHeightStandard) }
       computedHeight += MenuBarPopoverLayout.contentBottomPadding
       computedHeight += MenuBarPopoverLayout.footerAutoIndexHeight
       computedHeight += MenuBarPopoverLayout.footerOpenAppHeight
   }
   let panelHeight = min(max(computedHeight, MenuBarPopoverLayout.panelMinHeight), MenuBarPopoverLayout.panelMaxHeight)
   ```
3. **Wachstumsverhalten (Nutzer-Vorgabe):** Das Panel WAECHST mit jedem zusaetzlichen Eintrag (mehr angeschlossene Medien), bis `panelMaxHeight` (480pt) erreicht ist. **Ab da waechst das Panel NICHT weiter** - stattdessen wird der Zeilen-Bereich (nicht Header/Footer) zu einer scrollbaren `ScrollView`, die den ueberschuessigen Inhalt aufnimmt. Header und Footer bleiben immer sichtbar/fest, nur die mittlere Zeilen-Liste scrollt.
4. Diese `panelMaxHeight = 480` ist mein Vorschlag (Platz fuer ca. 5-6 Standard-Zeilen) - falls der Nutzer einen anderen Maximalwert im Kopf hat, bitte kurz nachfragen/mit README.md abgleichen, bevor final committed wird.
5. Fuer den Suchergebnis-Zustand (Aufgabe 3b) gilt dasselbe Prinzip mit eigenen festen Konstanten fuer Sektions-Header, Zeilen und den "Ergebnisse anzeigen"-Button - nicht die Ruhezustand-Konstanten wiederverwenden, da die Inhalte unterschiedlich hoch sind.

**Zwei kleine Textkorrekturen (Nutzer, 21.09.):**
- Button-Label: nicht mehr "Alle X Ergebnisse anzeigen", sondern nur noch **"Ergebnisse anzeigen"** (ohne Zahl/„Alle") - [MenuBarPopoverSearchContent.swift:29](diskindex/diskindex/MenuBar/MenuBarPopoverSearchContent.swift:29), `Button("Alle \\(PopoverSearchMock.totalResultCount) Ergebnisse anzeigen")` → `Button("Ergebnisse anzeigen")`.
- Kontextmenü am Menueleisten-Icon ([MenuBarController.swift:124](diskindex/diskindex/MenuBar/MenuBarController.swift:124)): Eintraege umbenennen zu **"Disk Index anzeigen"** (statt "Oeffnen"), dann Trenner (bereits vorhanden), dann **"Disk Index beenden"** (statt "Beenden").

**Review-Fix (Cursor, Runde 23):** `MenuBarPopoverLayout` (feste Höhen + `panelHeight`/`scrollArea`-Berechnung); SwiftUI/AppKit ohne `sizeThatFits`; ScrollView ab `panelMaxHeight` 480; Zeilen/Footer/Header mit `.frame(height:)`; Button „Ergebnisse anzeigen“; Kontextmenü „Disk Index anzeigen/beenden“. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 24) — Formel unterschätzt die Suchergebnis-Höhe, Button wird abgeschnitten:** ❌ Header-Höhe ist jetzt korrekt (kein Streckungs-Bug mehr, gut), aber der "Ergebnisse anzeigen"-Button ist am unteren Rand fast komplett abgeschnitten. Root Cause: [MenuBarPopoverLayout.swift:51-67](diskindex/diskindex/MenuBar/MenuBarPopoverLayout.swift:51) (`searchContentHeight`) vergisst zwei Abstände, die in [MenuBarPopoverSearchContent.swift](diskindex/diskindex/MenuBar/MenuBarPopoverSearchContent.swift) tatsächlich gerendert werden:
1. Die äußere `VStack(alignment: .leading, spacing: MenuBarPopoverLayout.searchSectionGap)` ([Zeile 36](diskindex/diskindex/MenuBar/MenuBarPopoverSearchContent.swift:36)) legt **12pt Abstand zwischen JEDEM Kind** — also auch zwischen der letzten Gruppe und dem Button. Die Formel addiert vor dem Button aber nur `searchResultsButtonTopPadding` (4pt) statt der tatsächlichen 12pt — **8pt Fehlbetrag**.
2. Die innere `VStack(alignment: .leading, spacing: 6)` je Gruppe ([Zeile 38](diskindex/diskindex/MenuBar/MenuBarPopoverSearchContent.swift:38)) legt **6pt Abstand zwischen Sektions-Label und jeder Zeile sowie zwischen aufeinanderfolgenden Zeilen** — das fehlt in der Formel komplett (sie rechnet nur `sectionHeaderHeight + rowCount × rowHeight`, ohne die `rowCount`-vielen 6pt-Lücken dazwischen).

**Fix:** `searchContentHeight(query:)` korrigieren, sodass sie exakt dieselben Spacing-Werte verwendet wie die echte View:
```swift
static let searchInnerGroupSpacing: CGFloat = 6   // neue Konstante, muss mit VStack(spacing: 6) in MenuBarPopoverSearchContent übereinstimmen

static func searchContentHeight(query: String) -> CGFloat {
    let groups = PopoverSearchMock.grouped(PopoverSearchMock.topResults(matching: query))
    guard !groups.isEmpty else {
        return searchVerticalPadding * 2 + searchResultsButtonHeight
    }
    var height = searchVerticalPadding * 2
    for group in groups {
        height += searchSectionHeaderHeight
        height += CGFloat(group.hits.count) * searchRowHeight
        height += CGFloat(group.hits.count) * searchInnerGroupSpacing  // NEU: Lücken innerhalb der Gruppe
    }
    height += CGFloat(groups.count) * searchSectionGap  // NEU: 12pt VOR JEDER Gruppe inkl. vor dem Button, nicht nur G-1 mal
    height += searchResultsButtonHeight
    return height
}
```
**Wichtiger genereller Hinweis für diese Art von Bug:** Statt die Formel immer wieder einzeln nachzujustieren, wäre es robuster, in `MenuBarPopoverSearchContent.swift` die dort hart codierte `spacing: 6` durch `MenuBarPopoverLayout.searchInnerGroupSpacing` zu ersetzen (Single Source of Truth), damit SwiftUI-Layout und Höhen-Formel nie wieder auseinanderlaufen können — genau das war ja der Sinn der ganzen Umstellung weg von `sizeThatFits`. Bitte das konsequent für alle Spacing-/Padding-Werte in diesem Bereich so verdrahten, nicht nur für diesen einen Fall.

**Review (Claude, 20.09., Runde 25) — Kontextmenü liegt hinter dem Popover, nicht anklickbar:** ❌ Root Cause klar: [MenuBarController.swift:131-143](diskindex/diskindex/MenuBar/MenuBarController.swift:131) (`statusBarButtonClicked`) ruft bei Rechtsklick direkt `showContextMenu(for:event:)` auf, **ohne vorher das offene Dropdown-Panel zu schließen**. Da `dropdownPanel.level = .popUpMenu` bereits eine hohe Fensterebene hat und zuletzt angezeigt wurde, bleibt es vor dem `NSMenu` des Kontextmenüs liegen — das Kontextmenü ist zwar sichtbar, aber durch das Panel verdeckt/nicht klickbar.

**Fix:** In `statusBarButtonClicked`, bevor `showContextMenu(...)` aufgerufen wird, immer zuerst `closePanel()` aufrufen (unabhängig davon, ob das Panel gerade offen ist — `closePanel()` ist bereits idempotent via `guard let panel = dropdownPanel else { return }`):
```swift
if event.type == .rightMouseUp {
    closePanel()
    showContextMenu(for: sender, event: event)
    return
}
```
Bitte danach testen: Popover per Linksklick öffnen, dann ohne vorheriges Schließen direkt rechtsklicken → Popover muss verschwinden UND das Kontextmenü muss sofort klickbar erscheinen, nicht erst nach einem zusätzlichen Klick.

**Review-Fix (Cursor, Runde 25):** Rechtsklick ruft vor `showContextMenu` `closePanel(animated: false)` auf (Panel sofort `orderOut`, kein Fade vor dem Menü). `xcodebuild` ✅.

**Review-Fix (Cursor, Runde 24):** `searchContentHeight` inkl. `searchInnerGroupSpacing` und `groups.count × searchSectionGap` (Abstand vor Button); View nutzt Layout-Konstanten, kein extra Button-Top-Padding. `xcodebuild` ✅.

---

## 4. Hauptfenster · Übersicht (README Screen 04)

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

- **Views:** `DashboardView.swift` (Toolbar + responsives `LazyVGrid`, min 220px), `MediumDashboardCard.swift`.
- **DesignSystem:** `StorageFillGradientBar` (background-size-Trick via Gradient-Breite `width/fraction`), `StorageErrorBar` / `StorageEmptyTrack`, `ObjectSearchField` (280px).
- **Model:** `Medium+Dashboard.swift` — Spec-Zeile, Meta, `lastSeenDescription`, Belegungs-Label.
- **StatusChip:** „Offline“ bei `connectionStatus == .offline`.
- Karten: Offline `opacity 0.55`, Fehler roter Rand + roter Balken, Meta mit klickbarem Belegungs-Toggle (global `showAbsoluteCapacity`).

- Fenster mit Traffic-Lights, Titelleiste: App-Name + „Objekte suchen…"-Suchfeld (Standard-Größe, oben rechts).
- Responsive Card-Grid, eine Card pro Medium: Typ-Icon oben links, Status-Chip oben rechts, Name (bold), Spec-Zeile (`HDD · 4,1 TB · 238 421 Dateien`), Storage-Fill-Gradient-Bar (siehe Design Tokens → Füllstand-Skala — **eigene Gradient-Logik**, nicht verwechseln mit Screen-03-Balken), Meta-Zeile mit klickbarem %/absolut-Toggle.
- Offline-Cards: `opacity: .55`. Error-Card: roter Rand + rot getönter „! Fehler"-Chip.

**Akzeptanzkriterium:** Gradient-Bar zeigt bei jedem Füllstand korrekt nur den bis dahin sichtbaren Ausschnitt des Gradients (immer bei Grau startend, nie direkt bei der Zielfarbe) — siehe README-Formel (`background-size` Trick).

**Review-Fix (Cursor):** `MainWindowToolbar` (Phosphor `NavHouse`/`NavGear`, Haus accent auf Dashboard); `MediumNavigation` + `MediumContextMenuItems` / `.mediumContextMenu`; Karten-Tap → Column-Browser-Platzhalter; `MainWindowDestination` um `.registry` / `.columnBrowser` erweitert. `xcodebuild` ✅.

**Review-Fix (Cursor):** Doppeltes „Disk Index“ in der Dashboard-Toolbar entfernt (`EmptyView` im Center-Slot). `xcodebuild` ✅.

---

## 5. Detail-Overlay (README Screen 05, Modal)

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

- **`MediumDetailModalView`** — Overlay in `MainWindowHostView` (heller Scrim 8 %, weißer Modal-Grund), Close oben rechts; Header mit Icon, Name, Verbindung, Chip; Stats-Tabelle inkl. Ja/Nein, „Neu indizieren“, „Vergessen“; Primär „Index anzeigen“.
- **State:** `detailMediumID`, `updateMedium` / `forgetMedium`; Öffnen via `MediumNavigation.openDetails` (Kontextmenü Dashboard).
- **Model:** `Medium+Detail.swift` (Verbindungstext, Kapazitäts-/Datums-Labels).

- Modal: weißer Hintergrund (nicht transluzent), heller Scrim (nicht dunkel), „✕"-Close oben rechts.
- Header: Typ-Icon, Name, Verbindungsbeschreibung, Status-Chip.
- Stats-Tabelle (leicht getönter Hintergrund, abgerundet, Innenabstand zum Modalrand): Gesamt, Belegt/Frei, Dateien/Ordner, Zuletzt gesehen, Zuerst indiziert.
- **Einstellungen als Zeilen in derselben Tabelle**, nicht als separate Buttons: „Soll indiziert werden" (Ja/Nein-Group), „Index erneuern", „Medium entfernen" (destruktiv, rot, „Vergessen").
- Primäraktion unterhalb: „Index anzeigen" (Label bewusst so, nicht „Dateien anzeigen") → öffnet Column Browser am Root des Mediums.

**Review-Fix (Cursor):** Tabellenzeilen Mockup-Layout (40 % Label, Controls rechtsbündig in Zeile); Settings-Zeilen wie Screen 05 HTML. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 7) — zwei konkrete Bugs im Code bestätigt:**
1. ❌ **Wert-Spalte linksbündig statt rechtsbündig.** In [MediumDetailModalView.swift:117-118](diskindex/diskindex/Views/Detail/MediumDetailModalView.swift:117) steht `Text(value).frame(maxWidth: .infinity, alignment: .leading)` — das ist links, nicht rechts. Fix: `alignment: .trailing` (und ggf. `.multilineTextAlignment(.trailing)` falls der Wert mal zweizeilig wird).
2. ❌ **Divider zwischen "Index erneuern" und "Medium entfernen" fehlt.** Ursache: [MediumDetailModalView.swift:97](diskindex/diskindex/Views/Detail/MediumDetailModalView.swift:97) ruft `settingsRow(label: "Medium entfernen", isLast: true)` auf, und `settingsRow` unterdrueckt bei `isLast: true` den oberen Divider ([Zeile 141-143](diskindex/diskindex/Views/Detail/MediumDetailModalView.swift:141)). Das ist verkehrt herum: der Divider wird am OBEREN Rand jeder Zeile gezeichnet (trennt von der Zeile davor) - der Trenner zwischen "Index erneuern" und "Medium entfernen" darf nicht wegfallen, nur weil letztere Zeile die letzte im Block ist. Fix: entweder `isLast`-Parameter bei diesem Aufruf entfernen (Divider immer zeichnen), oder die Logik so aendern, dass `isLast` nur die untere Abschlusskante des gesamten Blocks betrifft, nicht den Trenner zur vorherigen Zeile.

**Review-Fix (Cursor, Runde 8):** `detailRow` Werte mit `alignment: .trailing`; `settingsRow` für „Medium entfernen“ ohne `isLast: true`. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 3):** ❌ Layout stimmt laut Screenshot nicht mit dem Mockup überein (genaue Abweichung vom Nutzer nicht bis ins Detail benannt, aber klar erkennbar falsch) und ❌ ein Hover-Effekt sitzt an der falschen Stelle. Bitte nochmal 1:1 gegen `layout/Catalog App Design.dc.html` Screen 05 abgleichen: Abstände/Innenabstände der Stats-Tabelle, Zeilenhöhen, Button-Platzierung (Ja/Nein-Group und „Neu indizieren" rechtsbündig in der jeweiligen Tabellenzeile, nicht darunter/versetzt), und wo genau der Hover-State (vermutlich auf den Tabellenzeilen oder dem Close-Button) sichtbar wird — aktuell scheint er auf einem falschen Element zu liegen.

---

## 6. Column Browser (README Screen 06)

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).
a
- **`ColumnBrowserView`** — Toolbar mit Breadcrumb + Objekte-Suche; Sidebar 200px (Medium-Suche, Medienliste, aktive Zeile `#1c1c1e`); horizontal scrollbare Spalten (180px) + Detail 200px; Offline-Banner.
- **Komponenten:** `ColumnBrowserRow` (Hover Finder-Icon online), `FadeMaskText`, `MediumSidebarSearchField`, `ColumnBrowserBreadcrumb`.
- **Mock:** `ColumnBrowserMockData` (Baum für „Archiv 2019–2021“).
- **State:** `columnBrowserState` (medium, pathStack, selectedFileID).

- Titelleiste: Traffic-Lights, App-Name, Breadcrumb, Standard-Suchfeld (280px) oben rechts.
- Sidebar (fix 200px, getönt, inset shadow): kompaktes „Medium suchen…"-Feld (kleine Größe), volle Medienliste. Aktive Zeile: `#1c1c1e` Hintergrund, weißer Text.
- Hauptbereich: horizontal scrollbare Ordner-Spalten (je 180px) + finale Detail-Spalte (200px: Name, geändert, Größe, zuletzt gesehen, Online/Offline-Tag). `min-width: 1020px`, `overflow-x: auto` am Elternelement.
- Hover auf aktiver/dunkler Zeile (Sidebar **und** Spalten): fettes weißes „open in Finder"-Icon rechts, **nur bei Online-Items**. Bei zu langem Text: Fade via Maske (kein harter Ellipsis-Schnitt).
- Offline-Banner über den Spalten, wenn Medium nicht verbunden: „Offline — Inhalt aus dem Index, zum Öffnen bitte anschließen".

**Review-Fix (Cursor):** Keine verschachtelten Vertikal-ScrollViews in Spalten; Detail leer bis Datei-Klick; Fade nur auf aktiven Zeilen; Sidebar-Dimm nur offline; Objekte-Suche `onSubmit` → Suche. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 3) — mehrere Bugs:**
1. ~~Scrollbar~~ → Review-Fix oben., wo laut Mockup keine hingehört (vermutlich Spalten-Container hat mehr Höhe reserviert/berechnet als Inhalt braucht, oder `ScrollView` statt `HStack`+`overflow-x` falsch dimensioniert). Bitte Layout-Höhen prüfen, damit nur horizontal (Spalten) gescrollt wird, wo nötig — keine zusätzliche vertikale Scrollbar in Spalten ohne Overflow.
2. ❌ **Detail-Spalte zeigt Inhalt, obwohl keine Datei ausgewählt ist.** Erwartet: Detail-Spalte bleibt leer/zeigt einen Platzhalter („Datei auswählen" o. ä.), bis tatsächlich eine Datei angeklickt wurde — aktuell scheint sie vorbelegte/erste Datei anzuzeigen.
3. ❌ **Alle Medien in der Sidebar sind gefadet/gedimmt**, obwohl das laut Spec nur für **offline** Medien gilt (vgl. README: Fade-Opacity nur bei Offline-Status, z. B. Dashboard-Karten `opacity: .55`). Hier scheint die Dimm-Logik fälschlich auf alle Zeilen statt nur auf `connectionStatus == .offline` angewendet zu werden.
4. ~~Spaltenbreite nicht justierbar~~ → siehe Runde-4-Notiz unten, jetzt priorisiert (nicht mehr nur „vormerken").
5. ❌ **Suche nicht absendbar** — das Suchfeld in der Titelleiste (280px) nimmt zwar Text an, aber es gibt keine Möglichkeit, die Eingabe „abzusenden"/anzuwenden (kein Enter-Handling, keine Live-Filterung sichtbar). Mindestens `onSubmit` sollte etwas auslösen (z. B. Filterung der aktuellen Spalte oder Sprung zu Suchergebnissen) — Feinschliff der vollständigen Suchlogik ist zwar erst Aufgabe 7, aber das Feld sollte jetzt schon nicht komplett wirkungslos sein.

**Review (Claude, 20.09., Runde 4):**
1. **Detail-Spalte ohne Auswahl** — im aktuellen Screenshot korrekt: zeigt „Datei auswählen"-Platzhalter, kein Inhalt ohne Klick. ✅ Sieht behoben aus. Der Nutzer berichtet aber weiterhin ein Problem hierzu — bitte trotzdem gegenchecken: verhält sich das auch nach Ordnerwechsel/Medienwechsel konsistent (Detail-Spalte muss beim Wechsel in eine neue Spalte wieder zurück auf Platzhalter, nicht die zuletzt gewählte Datei aus dem vorherigen Kontext behalten)?
2. ❌ **Hover-Reveal fälschlich an Auswahl gekoppelt** — siehe [ColumnBrowserRow.swift:31](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserRow.swift:31): `if isSelected, isOnline, isHovered`. Das bedeutet, man muss eine Zeile erst anklicken (auswählen), bevor Hover überhaupt das Finder-Icon zeigt. **Korrektur** (siehe [README.md](README.md) → „Hover-Reveal open in Finder gilt für jede Online-Zeile"): Bedingung muss `if isOnline, isHovered` sein — unabhängig von `isSelected`. Das Icon-Styling (weiß/fett) bleibt wie gehabt, es soll nur nicht mehr an die Auswahl gekoppelt sein. Gilt genauso für die Sidebar-Medienliste, falls dort dieselbe Bedingung existiert — bitte prüfen.
**Review-Fix (Cursor, Runde 5):** Finder-Hover bei `isOnline && isHovered` (ohne Auswahl); Spalten **230pt** + `ColumnResizeHandle` → `folderColumnWidth` (global, siehe README.md). Detail leert bei Medien-/Ordnerwechsel. `xcodebuild` ✅.

3. ~~Spaltenbreite~~ → Review-Fix oben. — Spalten sollen breiter **und** per Drag justierbar sein. Umsetzung: an der rechten Kante jeder Spalte ein schmaler Drag-Handle (z. B. 4-6pt breiter, unsichtbarer Hit-Bereich mit `.onHover`-Cursor-Wechsel zu `.resizeLeftRight`), der die Spaltenbreite in `columnBrowserState` speichert (pro Spalte oder global — deine Wahl, aber bitte dokumentieren). Startbreite darf gerne über die 180px aus dem Mockup hinausgehen (Standardbreite z. B. 220-240px), das ist eine bewusste Verbesserung gegenüber dem Mockup.

**Review-Fix (Cursor, Runde 6):** Resize: `liveWidth` nur während Drag, Commit in `onEnded`; Detail: `onChange` Pfad/Medium + Lookup nur in aktuellem Pfad; Doc-Icon `DesignColor.text`; Finder-Hover als Overlay mit Opacity-Animation. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 5) — Review-Fix aus Runde 4 nicht vollständig, 4 offene Punkte:**
1. ~~Spalten-Resize~~ → Review-Fix Runde 6. (Zitat Nutzer) — beim Ziehen des Resize-Handles reflowt offenbar mehr als nur die eine Spalte (vermutlich weil `folderColumnWidth` global ist und JEDE Spalte inkl. bereits gerenderter/gescrollter Positionen bei jedem Drag-Frame neu layoutet, was zu sichtbarem Sprung/Jitter führt statt smoothem Ziehen). Bitte lokal reproduzieren und prüfen, ob das Neuzeichnen pro Drag-Event gedrosselt/geglättet werden muss (z. B. nur `DragGesture().onChanged` mit lokalem `@GestureState`, Commit erst `onEnded` in `folderColumnWidth`, damit während des Ziehens nicht der komplette Spalten-Stack neu aufgebaut wird).
2. ❌ **„Tote" Detail-Ansicht weiterhin da** — trotz Review-Fix-Meldung „Detail leert bei Medien-/Ordnerwechsel" berichtet der Nutzer, das Problem bestehe weiterhin. Bitte nochmal exakt nachvollziehen (Datei anklicken → Ordner wechseln → Detail-Spalte muss wieder auf Platzhalter zurückspringen) und mit Screenshot bestätigen, nicht nur den Code-Pfad für plausibel halten.
3. ❌ **Beim Öffnen/Anzeigen einer Datei „phantasiert" die Anzeige eine blaue Farbe**, die nicht im Design-Tokens-Spec vorkommt (siehe README → „Colors": nur Accent-Blau `#0074e0` für aktive/Indiziert-Zustände, Violet nur für Filter, Rot nur für Fehler — kein weiteres Blau-Konzept für Datei-Vorschau/-Öffnen-Zustände). Bitte die entsprechende View (Detail-Spalte bei ausgewählter Datei) zeigen/beschreiben und die Farbe auf einen der definierten Design-Tokens zurückführen statt eine neue Ad-hoc-Farbe zu verwenden.
4. ❌ **Hover-Icons ohne Transition** — das „open in Finder"-Icon (und generell Hover-Reveals) erscheinen/verschwinden hart, ohne Fade. Bitte eine leichte Opacity-Transition ergänzen (z. B. `.animation(.easeOut(duration: 0.12), value: isHovered)`), konsistent für alle Hover-Reveal-Icons im Column Browser (Sidebar + Spalten).

**Review (Claude, 20.09., Runde 6) — zwei echte Root Causes gefunden für Punkt 2 ("tote Detail-Ansicht") + neuer Punkt zu Mock-Daten:**

1. ❌ **Detail-Spalte ist IMMER gerendert und reserviert dauerhaft Platz**, selbst direkt am Medium-Root ohne jede Navigation/Auswahl. Ursache: [ColumnBrowserView.swift:143](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift:143) ruft `detailColumn(medium: height:)` bedingungslos nach den Ordner-Spalten auf, in derselben `HStack` wie die `ForEach`-Ordnerspalten. Erwartetes Verhalten (Nutzer-Vorgabe, [README.md](README.md) bitte ergänzen): Die Detail-Spalte soll **nur** erscheinen, wenn entweder (a) eine Datei tatsächlich ausgewählt ist, oder (b) die vorhandenen Ordner-Spalten die verfügbare Fensterbreite bereits füllen. Solange keins von beidem zutrifft, bleibt der rechte Bereich komplett leer — kein reservierter „Datei auswählen"-Platzhalter-Block. Fix: `detailColumn(...)` nur `if appState.columnBrowserState.selectedFileID != nil` in die `HStack` aufnehmen (Breitenausgleich per `Spacer()` statt fixer Detail-Spalten-Reservierung, wenn nicht genug Spalten für volle Breite vorhanden sind).
**Review-Fix (Cursor, Runde 7):** Detail-Spalte nur bei Datei-Auswahl oder voller Spaltenbreite; `genericTree` mit Dateien für alle Medien; README ergänzt. `xcodebuild` ✅.

2. ~~Root Cause Beispieldateien~~ → Review-Fix Runde 7. [ColumnBrowserMockData.swift](diskindex/diskindex/Models/ColumnBrowserMockData.swift) hat nur für die eine hartcodierte Medium-ID `archivID` ("Archiv 2019–2021") einen Baum mit echten Dateien (`archivTree`, Zeile ~30). **Jedes andere Medium** (inkl. „Backup SSD", das der Nutzer die ganze Zeit getestet hat) landet in `defaultRoot(mediumID:)` (Zeile 89), die nur zwei leere Ordner „Dokumente"/„Backup" ohne jegliche Dateien liefert — und das bleibt beim Reinklicken auch leer, es gibt nirgends im Default-Baum eine Datei zum Anklicken. Deshalb konnte die Detail-Ansicht nie mit echtem Inhalt getestet werden. Fix: `defaultRoot`/die generische Mock-Baum-Logik um 2-3 Beispieldateien pro Ordner erweitern (unterschiedliche Dateitypen, mal online/offline je nach Medium-Status), damit **jedes** Medium im Column Browser tatsächlich Dateien zum Anklicken hat, nicht nur das eine Spezial-Medium.

**Review (Claude, 20.09., Runde 8) — neuer Bug: Ordner UND Datei gleichzeitig „ausgewählt" (dunkel markiert):** ❌ Per Screenshot bestätigt: in einer Spalte kann sowohl ein navigierter Ordner (z. B. „2024") als auch eine Datei im selben Ordner (z. B. „Übersicht.pdf") gleichzeitig dunkel/„selektiert" dargestellt sein. Ursache in [ColumnBrowserView.swift](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift): Ordner-`isSelected` (Zeile ~185) hängt ausschließlich an `pathStack`-Zugehörigkeit (Navigation), Datei-`isSelected` (Zeile ~216, `fileRow`) ausschließlich an `selectedFileID` — beides sind unabhängige State-Variablen, die nicht gegenseitig zurückgesetzt werden, wenn man z. B. erst in „2024" navigiert (pathStack enthält „2024") und danach in derselben Spalte auf die Nachbardatei „Übersicht.pdf" klickt (setzt nur `selectedFileID`, `pathStack` bleibt unverändert). Ergebnis: zwei „aktive" Zeilen in derselben Spalte gleichzeitig — pro Spalte darf aber immer nur **eine** Zeile aktiv sein, entweder ein navigierter Ordner ODER eine ausgewählte Datei. Fix: beim Klick auf eine Datei in `fileRow.onSelect` (Zeile ~225) zusätzlich `appState.columnBrowserState.pathStack` auf `columnIndex` kürzen (`Array(pathStack.prefix(columnIndex))`), damit ein eventuell in dieser Spalte navigierter Ordner deselektiert wird und alle tieferen Spalten verschwinden.

**Review-Fix (Cursor, Runde 8):** `fileRow.onSelect` setzt `pathStack = Array(pathStack.prefix(columnIndex))` vor `selectedFileID`. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 16) — Nebenwirkung des Runde-8-Fixes gefunden, zwei neue Bugs:**

1. ❌ **Datei-Auswahl braucht jetzt zwei Klicks.** Ursache: [ColumnBrowserView.swift:67-69](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift:67) hat einen generischen Watcher `.onChange(of: pathStack) { selectedFileID = nil }`, der **bei jeder** `pathStack`-Änderung `selectedFileID` zurücksetzt — auch dann, wenn die `pathStack`-Änderung selbst Teil der Datei-Auswahl aus Runde 8 war (`fileRow.onSelect` setzt `pathStack` UND `selectedFileID` im selben Klick). Der `onChange`-Watcher feuert reaktiv NACH der kombinierten Zustandsänderung und wirft die gerade gesetzte `selectedFileID` wieder um — der erste Klick "deselektiert nur den Ordner" (weil `selectedFileID` sofort wieder auf `nil` fällt), erst beim zweiten Klick ändert sich `pathStack` nicht mehr, der Watcher feuert nicht, und `selectedFileID` bleibt stehen.

   **Fix:** Den generischen `.onChange(of: pathStack) { selectedFileID = nil }`-Reset entfernen. Stattdessen `selectedFileID = nil` **explizit und gezielt** nur dort setzen, wo tatsächlich in einen Ordner navigiert wird — also direkt in `navigateToFolder(columnIndex:name:)` (Zeile ~291) neben der `pathStack`-Mutation, NICHT in `fileRow.onSelect` (dort ist `selectedFileID`ja das Ziel, nicht `nil`). Dasselbe Prinzip wie beim Runde-8-Fix: jede Mutation soll für ihren eigenen Fall explizit verantwortlich sein statt sich auf einen globalen reaktiven Reset zu verlassen, der nicht zwischen den Auslösern unterscheiden kann.

2. ❌ **Detail-Spalte hat fixe Breite (`DesignSpacing.columnBrowserDetailWidth`, [ColumnBrowserView.swift:281](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift:281)), lässt aber Platz rechts frei** (sichtbarer leerer grauer Streifen im Screenshot). Erwartet: Die Detail-Spalte soll den **gesamten verbleibenden Platz** einnehmen (`maxWidth: .infinity` bzw. Breite aus `geometry.size.width` minus Summe der Ordner-Spalten-Breiten berechnen), nicht auf eine feste Design-Token-Breite begrenzt sein.

**Review-Fix (Cursor, Runde 17):** Generisches `.onChange(of: pathStack)` entfernt; `selectedFileID = nil` bleibt in `navigateToFolder`, Breadcrumb-Root und Medium-Wechsel. Detail-Spalte: `detailColumnWidth(in:)` = `max(DesignSpacing.columnBrowserDetailWidth, geometry.width − Ordnerspalten)`. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 18) - drei neue Punkte:**

1. Fehler: **Detail-Spalten-Inhalt zentriert statt linksbuendig**, obwohl die aeussere `VStack(alignment: .leading, ...)` ([ColumnBrowserView.swift:245](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift:245)) korrekt `.leading` gesetzt hat. Root Cause: Die `.frame(width: width, height: height, alignment: .top)` am Ende dieses Blocks ([Zeile ~292](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift:292)) - `alignment: .top` ist `Alignment(horizontal: .center, vertical: .top)`, also horizontal ZENTRIERT. Seit die Detail-Spalte in Runde 17 auf die volle verbleibende Breite gezogen wurde, bleibt die VStack selbst bei ihrer schmalen "hugging"-Breite (Inhalt ist ja kurz) und wird dadurch horizontal MITTIG in der jetzt viel breiteren Spalte platziert, statt links zu kleben. Fix: `alignment: .top` zu `alignment: .topLeading` aendern - eine Wort-Aenderung.

2. Fehler: **Kein Pointer-Cursor auf dem "open in Finder"-Hover-Icon** in den Ordner-Spalten (und vermutlich auch Sidebar-Medienliste) - das war schon in [Aufgabe 11](Cursor-Feedback fuer interaktive Elemente) als generisches Problem addressiert, ist hier aber offenbar nicht konsequent umgesetzt worden. Bitte pruefen, ob der `pointerCursor()`-Modifier aus Aufgabe 11 tatsaechlich auf das Finder-Icon in `ColumnBrowserRow`/den Zeilen angewendet wurde - falls Aufgabe 11 nur teilweise umgesetzt wurde, hier gezielt nachziehen.

3. Fehler: **Spalten-Resize ruckelt weiterhin extrem** ("springt alles wild durch die Gegend", schon in Runde 5 gemeldet, offenbar nie wirklich behoben). Bitte diesmal konkret pruefen: Wird waehrend des Drags (`DragGesture().onChanged`) bei JEDEM Frame `folderColumnWidth` (globaler State) direkt geschrieben, wodurch die GESAMTE Spalten-Reihe bei jedem Pixel-Delta neu layoutet UND potenziell die `ScrollView`-Scrollposition zuruecksetzt? Falls ja: waehrend des Drags nur einen lokalen `@GestureState`/`@State`-Wert live aktualisieren (nur die eine gezogene Spalte reagiert visuell in Echtzeit), und `folderColumnWidth` im globalen State erst bei `onEnded` EINMAL committen. Das ist der Unterschied zwischen "bei jedem Frame den ganzen Baum neu aufbauen" und "nur eine View live skalieren, Rest erst am Ende aktualisieren" - bitte diesmal wirklich pruefen und nicht nur den Code fuer plausibel halten, das Thema haengt schon seit mehreren Runden.

**Review-Fix (Cursor, Runde 18):** Detail-Spalte `.frame(..., alignment: .topLeading)`; Finder-Overlay `pointerCursor()` in `ColumnBrowserRow`; Resize: `@GestureState` + Preview nur an gezogener Spalte (`columnResizePreview`), Commit in `onEnded`, `.animation(nil)` während Drag. `xcodebuild` ✅.

**Neue Anforderung (Nutzer, 21.09.) — Statusleiste unter den Spalten:** Über das ursprüngliche Mockup hinaus (siehe auch [README.md](README.md)) soll unterhalb der Ordner-/Detail-Spalten eine schmale Statusleiste eingefügt werden, mit zwei Informationen:

**Nutzer hat dazu ein eigenes Referenz-Mockup geliefert (21.09.) — das ist jetzt bindend, ersetzt meine vorherige grobe Beschreibung:**

1. **Links: Speicherstand des aktuellen Mediums, nur als Zahlen, KEIN Balken.** Exakter Wortlaut aus dem Referenz-Mockup: **„{frei} frei von {gesamt}"**, z. B. „2,4 GB frei von 500 GB" — NICHT „belegt"/Prozent wie ursprünglich von mir vorgeschlagen. Frei-Wert berechnen aus `capacityTotalBytes - capacityUsedBytes` des aktuell ausgewählten Mediums (`selectedMediumID`). Kein %/absolut-Toggle hier, nur dieser eine feste Wortlaut.
2. **Rechts: Anzahl der Objekte in der aktuell geöffneten Spalte**, z. B. „3 Objekte" — Ordner+Dateien zusammengezählt in der aktuell aktiven/rechtesten Spalte (identisch mit der Zahl, die schon oben im jeweiligen Spalten-Header steht, z. B. „KUNDE B · 3 ELEMENTE" im Referenz-Mockup — beide Zahlen müssen übereinstimmen, da dieselbe Datenquelle).

**Platzierung/Stil laut Referenz-Mockup:** eigene volle-Breite-Zeile ganz unten am Fenster (unterhalb der Spalten, als Fenster-Abschluss), mit dünner Trennlinie darüber, sehr dezent (kleine, gedämpfte Schrift, heller/neutraler Hintergrund passend zu den bestehenden Design-Tokens). Links- und rechtsbündige Texte in derselben Zeile, kein Icon/Deko nötig.

**Review-Fix (Cursor, Runde 30):** `columnBrowserStatusBar` in `ColumnBrowserView` (volle Fensterbreite unter Sidebar+Spalten): links „{frei} frei von {gesamt}“ aus `capacityTotalBytes`/`capacityUsedBytes`; rechts Objektanzahl der rechtesten Spalte (`ColumnBrowserMockData.children` am aktuellen `pathStack`). Rechteste Spalten-Header ergänzt um „ · N ELEMENTE“ (Mockup). `xcodebuild` ✅.

---

## 7. Suche (README Screen 07 + 07B)

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

- **`SearchView`** — Toolbar (Haus, Filter + violette Chips, Objekte-Suche, Zahnrad); kompakte Medium-Karten; Ergebnistabelle mit sortierbaren Spalten, Status rechts, Chevron → Column Browser; Online-Hover Finder-Icon.
- **`SearchFilterPopover`** (07B) — Dateityp-Chips, Medium-Liste mit Suche/Scroll, Alter; Hover am Filter-Button öffnet Popover.
- **Mock:** `SearchMockResults.swift`; Filter an `searchState.filters` gebunden.

- Eine einzige Suche, **kein** Modus-Umschalter Medien/Dateien.
- Top-Zeile: „Filter"-Button (Trichter-Icon, violett `#9c27b0`) + aktive Filter-Chips (violett, entfernbar via „✕") + Standard-Suchfeld rechts.
- Treffer, die Medien matchen: kompakte Preview-Cards oberhalb der Ergebnistabelle (gleiche Optik wie Screen-04-Cards, verdichtet).
- Ergebnistabelle: Icon, Name (sortierbar), Datum, Speichermedium, Pfad, Status (rechtsbündig), letzte Spalte „In Spalten anzeigen" (gleicher Chevron wie Screen 01) — **Tabellenregel:** letzte Spalte immer rechtsbündig, Inhalt flush zum Rand.
- Online-Items: Hover-Reveal „open in Finder" wie in Screen 06.

**Filter-Popover (07B, eigener Hover-Popover am Filter-Button):**
- Drei Gruppen nebeneinander: Dateityp (Multi-Select-Chips), Medium (mit eigenem Suchfeld, „Alle Medien"-Checkbox, scrollbare Liste `max-height ~110px`, Caption „x von y Medien · scrollt"), Alter (flache Liste, aktive Option fett + accent-farbig).
- Kleiner CSS-Dreieck-Pointer zwischen Button und Popover.

**Review-Fix (Cursor, Runde 6):** Mock-UUIDs `S1000001` → `B1000001` (gültiges Hex); übrige `UUID(uuidString:)!` in MockData/ColumnBrowserMockData bereits `A`-Präfix — ok. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 5) — Absturz gefunden, Ursache exakt lokalisiert:** ❌ **Crash bei jeder Suche.** In [SearchMockResults.swift:30,39,48](diskindex/diskindex/Models/SearchMockResults.swift:30) stehen Mock-IDs mit dem Präfix `"S1000001-..."` — **`S` ist kein gültiges Hex-Zeichen** (UUID-Segmente erlauben nur `0-9`/`A-F`). `UUID(uuidString:)` liefert deshalb `nil`, das nachfolgende `!` crasht hart — exakt der Absturz aus dem Log (`SearchMockResults.swift:30: Fatal error: Unexpectedly found nil`). Fix: alle drei `"S1000001-..."`-Strings auf ein gültiges Hex-Präfix ändern (z. B. `"B1000001-..."`), und **bitte einmal alle anderen hartcodierten `UUID(uuidString:)!`-Vorkommen im Projekt grep'en** (`MockData.swift`, `ColumnBrowserMockData.swift` etc.) und auf gültige Hex-Zeichen prüfen, damit nicht an anderer Stelle der gleiche Fehler schlummert.

## 7b. Suche & Filter-Popover — Runde 18 Nacharbeiten

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

1. Fehler: **Keine "Nichts gefunden"-Anzeige in der Ergebnistabelle**, wenn eine Suche keine Treffer liefert - Tabelle bleibt vermutlich einfach leer/wirkt kaputt. Bitte einen eindeutigen Empty-State in der Tabelle ergaenzen (kurzer Text + ggf. Icon, passend zum Design-System - z. B. "Keine Ergebnisse fuer „{query}“" zentriert im Tabellenbereich), analog zum "Datei auswählen"-Platzhalter im Column Browser.

**Review (Claude, 20.09., Runde 26) - Empty-State immer noch luckenhaft, jetzt mit Screenshot bestaetigt:** Fehler: Der bestehende `searchEmptyState` in [SearchView.swift:63](diskindex/diskindex/Views/Search/SearchView.swift:63) greift nur bei `results.isEmpty && !trimmedQuery.isEmpty` (also NUR wenn eine Suche eingegeben wurde und nichts gefunden wurde). Der Fall aus dem Screenshot - Suchfeld komplett LEER, noch gar keine Suche gestartet - faellt durch dieses `if` durch und landet im `else`-Zweig `searchResultsTable`, die dann nur den Tabellenkopf mit null Zeilen zeigt, komplett ohne Hinweistext.

**Gewuenscht (Nutzer-Vorgabe, zwei saubere Zustaende, beide zentriert im Tabellenbereich, Standard-Schriftgroesse):**
1. **Kein Suchbegriff eingegeben** (`trimmedQuery.isEmpty`): dezenter Hinweistext, z. B. "Suche nach Dateien, Ordnern oder Speichermedien" (Wortlaut nach eigenem Ermessen passend zum Rest der App).
2. **Suchbegriff eingegeben, keine Treffer** (`!trimmedQuery.isEmpty && results.isEmpty`): "Keine Ergebnisse fuer „{query}“" (bereits als Text-Idee vorhanden, jetzt aber die Bedingung fixen, s.o.).
3. **Optional/fuer spaeter (Nutzer: "alternativ"), niedrige Prioritaet:** Ein Lade-Spinner-Zustand "Suche laeuft…" - aktuell ist die Mock-Suche synchron/instant, es gibt also (noch) keinen echten Ladezustand zu zeigen. Trotzdem schon jetzt als dritte, saubere Variante der Empty-State-Komponente vorsehen (z. B. ein `enum SearchResultsState { case idle, loading, empty(query: String), results([SearchResultItem]) }`), damit das Grundgeruest steht, wenn spaeter eine echte (ggf. asynchrone) Suche drankommt - aber nicht mit Aufwand fuer eine kuenstliche Verzoegerung/Animation ueberkonstruieren, das eigentliche Sucherverhalten bleibt synchron.

Alle drei Text-/Spinner-Zustaende: mittig im Tabellenbereich (dort wo sonst die Zeilen waeren, unterhalb des Tabellenkopfs), Standard-Fliesstext-Groesse (nicht kleiner/grauer als sonst im UI ueblich), kein UEberladen mit Icon-Deko falls das nicht zum Rest des Screens passt - einfacher, klarer Text reicht.

**Review-Fix (Cursor, Runde 26):** `SearchResultsState` + `isSearchInProgress`; Tabellenkopf immer sichtbar; Platzhalter idle / empty / loading unter dem Kopf. `SearchView.swift`, `SearchState.swift`. `xcodebuild` ✅.

2. Fehler: **Filter-Popover oeffnet bei Hover statt Klick.** [SearchView.swift:89](diskindex/diskindex/Views/Search/SearchView.swift:89) hat `.onHover { hovering in showFilterPopover = hovering }` - laut Nutzer-Vorgabe soll das Popover per Klick auf den Filter-Button auf-/zugehen (nicht bei blossem Drueberfahren, das ist bei einem Popover mit Checkboxen/Eingaben ungeeignet - man wuerde beim Wegbewegen der Maus sofort wieder rausfliegen). Fix: `.onHover` entfernen, stattdessen `Button { showFilterPopover.toggle() }` auf dem Filter-Button selbst.

3. Fehler: **Filter-Popover ist mittig zum Button ausgerichtet, soll linksbuendig sein.** [SearchView.swift:86](diskindex/diskindex/Views/Search/SearchView.swift:86) nutzt SwiftUI's natives `.popover(isPresented:arrowEdge:)` - das zentriert sich IMMER relativ zum Anchor und zeichnet einen eigenen Pfeil, den man nicht auf "links" umstellen kann (genau dasselbe Problem wie beim Menueleisten-Popover in früheren Runden). Empfehlung: genau wie beim Menueleisten-Dropdown vom nativen `.popover(...)` weg auf eine selbstgebaute Loesung umsteigen - entweder ein eigenes `NSPanel` (falls dieser Screen ohnehin schon AppKit-nah gebaut ist) oder ein SwiftUI-Overlay mit manueller Positionierung (z. B. `.overlay(alignment: .topLeading)` relativ zum Filter-Button per `GeometryReader`/Anchor-Preference), das linksbuendig unter dem Button erscheint und den kleinen Dreieck-Pointer aus dem Mockup (07B) exakt nachbaut, statt sich auf SwiftUIs eingebautes zentriertes Pfeil-Popover zu verlassen.

4. Fehler: **Checkboxen im Filter-Popover verhalten sich unzuverlaessig.** [SearchFilterPopover.swift:69-92](diskindex/diskindex/Views/Search/SearchFilterPopover.swift:69) nutzt die Konvention "leeres `mediumIDs`-Set bedeutet implizit alle Medien ausgewaehlt" fuer sowohl den "Alle Medien"-Toggle als auch jede einzelne Medium-Checkbox (`get: { filters.wrappedValue.mediumIDs.contains(medium.id) || filters.wrappedValue.mediumIDs.isEmpty }`). Das ist fehleranfaellig: Toggle-Semantik "leer = alle" vs. "gefuellt = nur diese" wechselt implizit je nach Interaktion und ist schwer nachzuvollziehen (z. B. nach Abwaehlen EINES Mediums werden ploetzlich ALLE anderen individuell "gefuellt" ins Set uebernommen). Bitte auf ein explizites, vorhersehbares Modell umstellen: z. B. einen eigenen `selectAllMedia: Bool`-Flag statt der impliziten Leer-Set-Konvention, oder das Set immer explizit mit allen IDs vorbefuellen statt es leer zu lassen. Wichtig: nach dem Umbau tatsaechlich mehrfach an/abwaehlen testen (einzelne Medien, dann "Alle Medien", dann wieder einzelne), nicht nur den Code lesen.

5. Fehler: **Filter-Chips (Dateityp-Auswahl) haben keinen Hover-Zustand.** Bitte `FilterChipButtonStyle` ([SearchFilterPopover.swift:125](diskindex/diskindex/Views/Search/SearchFilterPopover.swift:125)) um einen dezenten Hover-Effekt ergaenzen (z. B. leichter Hintergrund-Tint bei `configuration.isPressed` bzw. per zusaetzlichem `@State isHovered` + `.onHover`), konsistent mit den anderen interaktiven Elementen aus Aufgabe 11.

**Review-Fix (Cursor, Runde 18):** Empty-State „Keine Ergebnisse für …“; Filter per Klick (Hover entfernt); linksbündiges `SearchFilterPopoverPanel` (Overlay + Dreieck); `SearchFilters.selectAllMedia` explizit; Dateityp-Chips mit Hover (`FilterTypeChipButton`). Dateien: `SearchView.swift`, `SearchFilterPopover.swift`, `SearchFilterPopoverPanel.swift`, `SearchState.swift`, `SearchMockResults.swift`. `xcodebuild` ✅.

---

## 8. Registry-Tabelle (README Screen 01B)

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

- **`RegistryView`** — Filter-Chips (`NeutralFilterChip`), sortierbare Header (Name/Typ/Indizieren), Zeilen via `RegistryTableRow`.
- **Klick:** Name → Detail-Modal; Kontextmenü (`MediumNavigation`); Chevron → Column Browser; Ja/Nein-Group an `allowIndexing`.
- **Model:** `RegistryFilter.swift` (`RegistryFilter`, `RegistrySortState`).

- Filter-Chip-Zeile: Alle / Indiziert / Pausiert / Nicht erlaubt (neutral grau).
- Spalten: Name (+Typ-Icon), Typ, Status (Chip), Indizieren (Ja/Nein-Group), unlabeled Chevron-Spalte → öffnet Column Browser.
- Name/Typ/Indizieren-Header sortierbar (Pfeil-Icon, accent bei aktiver Spalte, sonst muted grau).
- Status- und Indizieren-Spalte ohne Lücke, beide rechtsbündig (`width: 1%; white-space: nowrap`-Äquivalent in SwiftUI-Tabelle).
- Letzte Zeile ohne unteren Divider.
- **Klickverhalten** (siehe [README.md](README.md), gleiche Logik wie Aufgabe 4 → auf Dashboard-Karte bauen, nicht neu erfinden): Klick auf den **Namen** einer Zeile → Detail-Modal (Screen 05). Die Zeile trägt zusätzlich ein Kontextmenü mit „Index anzeigen“ (→ Column Browser) und „Details“ (→ Detail-Modal). Chevron-Button bleibt zusätzlich bestehen (→ Column Browser, wie oben beschrieben).

**Review-Fix (Cursor):** Registry-Spalten wie Mockup (`RegistryTableLayout`), Status/Indizieren/Chevron rechtsbündig, Phosphor-Chevron, Zeilen-Opacity bei „Nicht erlaubt“. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 3):** ❌ Layout laut Nutzer „total im Arsch" — komplett gegen `layout/Catalog App Design.dc.html` Screen 01 neu abgleichen: Spaltenbreiten/-ausrichtung, Zeilenhöhen, Chip-/Button-Group-Größen, Filter-Chip-Zeile-Abstände. Bitte hier nicht punktuell nachbessern, sondern einmal komplett Pixel für Pixel mit dem Mockup vergleichen (Kicker „01 — NEUES SPEICHERMEDIUM & REGISTRY" im HTML) und Screenshot zur nächsten Runde mitschicken.

**Review-Fix (Cursor, Runde 5):** **Ursache der ~250px-Lücke:** SwiftUI hat Filter-Zeile und/oder Tabellenkopf mit der **vollen verbleibenden Fensterhöhe** layoutiert (Hintergrund/`HStack` wirkte wie leerer Block zwischen Chips und Kopf). Fix: `fixedSize(vertical: true)` auf Filter + Kopf + Zeilen, Tabelle in einer Karte (Mockup), `ScrollView` nur für den Body; Toolbar-Center `ToolbarCenterPlaceholder` statt `EmptyView()`. `xcodebuild` ✅.

**Review-Fix (Cursor, Runde 6):** Dokumentations-`<section>`-Rahmen entfernt — Registry wieder flächenbündig wie 04/06/07; `fixedSize` auf Filter/Kopf/Zeilen bleibt gegen die Lücke. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 8) — neuer, kleinerer Layout-Fehler:** ❌ Zwischen Filter-Chip-Zeile und Tabellenkopf ist jetzt (statt der grossen Luecke) ein schmaler, farblich merkwuerdiger grauer/rosastichiger Balken sichtbar (siehe Screenshot) - vermutlich ein Rest-Hintergrund-Modifier (z. B. `background(DesignColor.text.opacity(...))` oder ein Divider mit falscher Hoehe/Farbe) an der Nahtstelle zwischen `filterChipRow` und `registryHeader`. Bitte den Bereich genau dort (kein Padding/Inset dazwischen, direkter Uebergang, ggf. `DesignColor.neutral100`-Hintergrund exakt nur auf `registryHeader` begrenzt, nicht ueberlappend mit `filterChipRow`s eigenem Hintergrund) pruefen. Diesmal reicht wahrscheinlich eine gezielte Korrektur, nicht noch ein struktureller Umbau - aber bitte trotzdem kurz die tatsaechliche Ursache (welcher Modifier/View) benennen, bevor "erledigt" gemeldet wird.

**Review-Fix (Cursor, Runde 9):** Ursache: zweiter Hintergrund `DesignColor.text.opacity(0.04)` auf `filterChipRow` (rosastich auf `DesignColor.bg`) direkt über `registryHeader` mit `neutral100` — sichtbarer Streifen an der Naht. Fix: Tint-Hintergrund auf der Chip-Zeile entfernt; Chip-Block mit `DesignColor.bg` hinterlegt, Abstand unten auf 10pt reduziert, Kopfzeile unverändert `neutral100`. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 5) — neuer Fehler durch den Fix selbst eingeführt:** ❌ Die Lücke ist weg, aber jetzt hat die Tabelle einen **Karten-Rahmen mit Schatten und großzügigem Außenabstand**, der so nicht ins App-Fenster gehört. Ursache vermutlich: `layout/Catalog App Design.dc.html` umschließt **jeden Screen-Abschnitt der Katalog-Dokumentationsseite** mit `<section style="border:1px solid var(--color-divider); padding:var(--space-6); border-radius:var(--radius-lg);">` — das ist der Rahmen, der auf der HTML-Seite die einzelnen Screens voneinander abgrenzt (Dokumentations-Layout), **nicht Teil der eigentlichen App-UI**. Wenn dieser äußere `<section>`-Rahmen mit übernommen wurde ("Tabelle in einer Karte (Mockup)"), ist das der Fehler — die Registry-Tabelle soll flächenbündig im App-Fenster sitzen (wie Screens 04/06/07 auch, die diesen Dokumentations-Rahmen ebenfalls nicht in die App übernommen haben), nicht als freistehende Karte mit Schatten/Rand/Padding darin. Bitte diesen äußeren Wrapper in `RegistryView.swift` wieder entfernen und nur das interne Tabellen-Layout (Header/Zeilen/Divider aus dem eigentlichen `<table>`-Markup) behalten.

**Review (Claude, 20.09., Runde 4) — konkreter Befund:** ❌ Immer noch falsch, diesmal genauer lokalisiert: Zwischen der Filter-Chip-Zeile („Alle / Indiziert / Pausiert / Nicht erlaubt") und dem Tabellenkopf („Name / Typ / Status / Indizieren") klafft eine **große leere Fläche** (~250px), bevor der Tabellenkopf und die Zeilen erscheinen. Im Code-Pfad (`RegistryView.swift`) folgt `registryHeader` direkt auf `filterChipRow` ohne sichtbaren Extra-Spacer — das Leerfeld kommt also vermutlich aus einer der beiden Views selbst oder aus der `ScrollView`, die eventuell fälschlich VOR statt NACH dem Header eine übergroße `Spacer`/`frame(maxHeight: .infinity)`-Fläche rendert, oder aus einem falsch platzierten `background`-Modifier mit eigener Mindesthöhe. Bitte lokal im Xcode-Preview/View-Debugger (⌘⇧⌥ „Debug View Hierarchy" bei laufender App) nachschauen, welche View exakt diese Fläche einnimmt, und meldet die Ursache kurz zurück, statt nur den Fix zu committen — bei diesem Screen ist schon zweimal “behoben” gemeldet worden, obwohl es sichtbar nicht stimmte.

---

## 9. „Neues Speichermedium erkannt"-Dialog (README Screen 01A, Modal)

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

- **`NewMediumDetectedDialog`** — Overlay via `AppState.newMediumDialogMediumID` in `MainWindowHostView`; Checkbox „merken“; Indizieren/Nicht indizieren (Primary/Secondary Styles).
- **Debug:** Registry → „Neues Medium (Demo)“ öffnet Dialog für Mock-Medium „Neues Medium“.

- Kleines Modal (~300px), HDD-Icon, Titel, Body-Text mit Platzhaltern für Medienname/Typ/Größe.
- Checkbox „Für dieses Medium merken".
- Buttons: „Nicht indizieren" (sekundär, grauer Rand) / „Indizieren" (primär, blau, Rand eine Stufe dunkler als Fill — siehe Button-Border-Regel in README).

**Review-Fix (Cursor):** Eigenes Fenster `AppWindowID.newMedium` + `NewMediumDialogPresenter` (unabhängig vom Hauptfenster). `xcodebuild` ✅.

**Review-Fix (Cursor, Runde 8):** Fenster aus Menüleiste zusätzlich über `AppWindowPresenter.openNewMedium` / `openMain` (NSHostingController), falls kein SwiftUI-`openWindow` im Popover-Kontext. `xcodebuild` ✅.

**Status zurückgesetzt auf offen (Claude, 21.09., Codebase-Audit):** ❌ Die Kern-Anforderung aus [README.md](README.md) („Neues Medium erkannt-Dialog muss systemweit sein, nicht app-intern") ist **nicht erfüllt**, obwohl diese Aufgabe als erledigt markiert war. Geprüft: [AppWindowPresenter.swift:66-80](diskindex/diskindex/App/AppWindowPresenter.swift:66) (`openNewMedium`) erzeugt ein ganz normales `NSWindow` (`styleMask: [.titled, .closable, .fullSizeContentView]`) — **kein** `NSPanel`, **kein** `.floating`/`.utility`-Level, kein `isFloatingPanel`. Das Fenster ist zwar unabhängig vom Hauptfenster (das war der vorherige Fix), kann aber ganz normal hinter anderen Fenstern verschwinden — es verhält sich nicht wie eine System-Benachrichtigung, die immer obenauf liegt.

**Fix:** `NSWindow` durch `NSPanel` ersetzen mit `styleMask: [.titled, .closable, .nonactivatingPanel]` (oder ähnlich, ohne `.fullSizeContentView` falls das mit Titelleiste kollidiert — bitte visuell gegenchecken), `panel.level = .floating` (oder `.utility`), `panel.isFloatingPanel = true`. Gleiches Prinzip wie beim Menüleisten-Dropdown-Panel (`MenuBarController.swift`), nur mit normalem Fenster-Chrome (Titelleiste/Close-Button bleiben, nur die Fensterebene ändert sich). Nach dem Fix testen: Dialog öffnen, dann auf ein anderes Fenster/eine andere App klicken — der Dialog muss sichtbar obenauf bleiben, nicht dahinter verschwinden.

**Review-Fix (Cursor, Runde 28):** `openNewMedium` erzeugt `NSPanel` (`.titled`, `.closable`, `.nonactivatingPanel`), `level = .floating`, `isFloatingPanel = true`; Referenz `newMediumWindow: NSPanel?`. `AppWindowPresenter.swift`. `xcodebuild` ✅.

**Review (Claude, 20.09., Runde 3) — Architektur-Korrektur, siehe [README.md](README.md) → „Neues Medium erkannt-Dialog muss systemweit sein":** ❌ Aktuell ist der Dialog ein Overlay **innerhalb** von `MainWindowHostView` — das bedeutet, er ist nur sichtbar, wenn zufällig gerade das Hauptfenster offen ist. Das ist konzeptionell falsch: Das Ereignis kommt vom OS (Disk angeschlossen) und muss unabhängig von offenen App-Fenstern erscheinen. Bitte umbauen auf ein eigenständiges Fenster/Panel (z. B. `NSPanel` mit `.floating` oder `.utility`-Level, per `NSWindowController` verwaltet, oder ein separates SwiftUI `Window(id:)`, das per `openWindow` unabhängig vom Hauptfenster erscheint und immer im Vordergrund liegt). Visuelles Design (Größe, Buttons, Checkbox) bleibt wie bereits gebaut — nur die Fenster-Architektur ändert sich.

---

## 10. Icon-Set & Design-System-Feinschliff (README Screen 08 + 09)

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

- **Assets:** Dateitypen (`FileType*`), `NavCaretRight`, `IconFunnel`, `IconCheckCircle`, `IconCircleDashed` (Phosphor regular, Template) — siehe `Resources/Icons/ICON_STRATEGY.md`.
- **Code:** `FileTypeIcon.swift`; Filter-Trichter in `SearchView`; `BinaryButtonGroup` „Nein“-Fill `neutral800`; Registry/Popover-Glyphs aus Asset-Catalog.

- Alle Icons aus Phosphor (regular, Status-Icons „dezent fetter") als Assets einbinden; Liste siehe README Screen 08.
- Finaler Abgleich aller Screens gegen README → „Design Tokens": Farben (inkl. Ramp-Stufen), Button-Group-Regel, Status-Chip-Farben (**Achtung**: „Wird indiziert" = Outline, „Indiziert" = Fill — nicht vertauschen), Suchfeld-Größen (Objekte- vs. Medium-Suche), Radius (6/8/14px), Border 1px, Tabellenregel.

---

## 11. Cursor-Feedback für interaktive Elemente (übergreifend, alle Screens)

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

- **`DesignSystem/PointerCursor.swift`** — `pointerCursor()`; angewendet u. a. auf Ghost-Buttons, Dashboard-Karten, Registry (Name/Chevron/Sort), Toolbar-Icons, Filter-Chips, BinaryButtonGroup, Column-Browser-Zeilen.

❌ Klickbare Elemente (Buttons, Hover-Reveal-Icons wie „open in Finder", Tabellen-Header-Sortierpfeile, Karten mit Klick-Handler etc.) zeigen aktuell den normalen Pfeil-Cursor statt eines Hand-/Pointer-Cursors beim Hover. In AppKit/SwiftUI passiert das nicht automatisch bei Custom-Buttons — braucht explizites Cursor-Handling. Bitte einen wiederverwendbaren Modifier bauen, z. B.:
```swift
extension View {
    func pointerCursor() -> some View {
        onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
```
und konsequent auf alle `Button`/klickbaren Custom-Views anwenden (Dashboard-Karten, Registry-Zeilen/Namen, Column-Browser-Zeilen, Sortier-Header, Chips, Ghost-Buttons, Kontextmenü-Trigger, Chevron-Buttons). Nicht auf reine Text-Labels ohne Aktion.

---

## 12. Kritischer Bug: App crasht beim Schließen/Minimieren des Hauptfensters über die Ampel-Buttons

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

**Root Cause identifiziert:** Es existieren zwei parallele, konkurrierende Fenster-Management-Systeme für dieselben Fenster-IDs:
1. [diskindexApp.swift:14-28](diskindex/diskindex/diskindexApp.swift:14) deklariert SwiftUI-`Window(id:)`-Scenes für `AppWindowID.main` und `AppWindowID.newMedium` — SwiftUI verwaltet deren Lebenszyklus (inkl. Schließen/Minimieren über die Traffic-Lights) selbst, intern über sein eigenes Scene-System.
2. [AppWindowPresenter.swift](diskindex/diskindex/App/AppWindowPresenter.swift) erzeugt zusätzlich **rohe `NSWindow`-Instanzen** mit **denselben Identifier-Strings** (`window.identifier = NSUserInterfaceItemIdentifier(AppWindowID.main)` in `openMain()`, analog `openNewMedium()`), komplett an SwiftUI vorbei — laut Kommentar in der Datei nötig, weil im `NSPanel`-Popover von `MenuBarController` kein `openWindow`-Environment-Action verfügbar ist (der Popover ist kein Teil des SwiftUI-Scene-Baums).

Wenn beide Systeme gleichzeitig existieren, gerät SwiftUIs Fenster-Buchhaltung durcheinander, sobald der Nutzer ein Fenster über die native macOS-Steuerung (Ampel: Schließen/Minimieren/Zoomen) manipuliert — SwiftUI versucht, ein Scene-Fenster zu verwalten, das eigentlich ein fremd erzeugtes `NSWindow` ist (oder umgekehrt), was zum Crash führt.

**Empfohlener Fix — auf EIN System festlegen, nicht beide parallel:**
- Da die App als reine Menu-Bar-App (`LSUIElement`) läuft und Fenster ausschließlich über `AppWindowPresenter` aus dem `NSPanel`-Popover heraus geöffnet werden, ist die konsistente Lösung: die SwiftUI-`Window(id:)`-Scene-Deklarationen in `diskindexApp.swift` komplett entfernen (sie werden nicht mehr für das eigentliche Öffnen gebraucht, da `AppWindowPresenter` das schon übernimmt) und **ausschließlich** über `AppWindowPresenter`s rohe `NSWindow`s arbeiten. Da `App` mindestens eine `Scene` braucht, ggf. eine leere `Settings {}`-Scene als Platzhalter einsetzen.
- Zusätzlich prüfen: Das in `AppWindowPresenter.openMain`/`openNewMedium` erzeugte `window` ist nur eine **lokale Variable ohne eigene starke Referenz** außerhalb der Funktion. Das funktioniert meist, weil sichtbare Fenster von AppKit intern gehalten werden, ist aber fragil — bitte zur Sicherheit eine statische Property (z. B. `static var mainWindow: NSWindow?` in `AppWindowPresenter`) einführen, die das Fenster explizit hält, damit es nicht durch ARC vorzeitig freigegeben wird, insbesondere beim Wiederverwenden über `existingWindow(id:)`.
- Nach dem Fix bitte explizit testen: Hauptfenster über rotes Ampel-Symbol schließen, über gelbes minimieren, über Dock-Icon-Klick (falls noch vorhanden) wiederherstellen, mehrfach hintereinander öffnen/schließen — kein Crash in keinem dieser Fälle.

**Review-Fix (Cursor, Runde 15):** SwiftUI-`Window(id:)`-Scenes aus `diskindexApp.swift` entfernt; Platzhalter-`Settings { EmptyView() }`. Einziges Fenster-Management in `AppWindowPresenter` mit starken Referenzen (`mainWindow` / `newMediumWindow`), `PresenterWindowDelegate` (`windowWillClose` → Referenz leeren), `isReleasedWhenClosed = false`. `AppWindowID.swift` ausgelagert; `NewMediumDialogWindowHost` schließt via `AppWindowPresenter.closeNewMedium()` (kein `dismissWindow`). Bitte Ampel Schließen/Minimieren/Reopen manuell testen.

---

## 13. „Objekte suchen"-Feld muss überall auf Enter reagieren (systemweite Prüfung)

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

**Audit (Claude, 21.09.):** `ObjectSearchField` ([DesignSystem/ObjectSearchField.swift](diskindex/diskindex/DesignSystem/ObjectSearchField.swift)) hat `.onSubmit { onSubmit?() }` korrekt eingebaut — das Problem liegt an den **Aufrufstellen**, die den `onSubmit`-Parameter größtenteils gar nicht mitgeben (dann ist er `nil`, Enter tut nichts):

| Datei | `onSubmit` gesetzt? |
|---|---|
| [DashboardView.swift:23](diskindex/diskindex/Views/Dashboard/DashboardView.swift:23) | ❌ Nein — Enter tut nichts (genau das gemeldete Problem) |
| [RegistryView.swift:27](diskindex/diskindex/Views/Registry/RegistryView.swift:27) | ❌ Nein — gleicher Bug, war bisher nicht gemeldet, aber genauso betroffen |
| [ColumnBrowserView.swift:49](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift:49) | ✅ Ja — `{ appState.mainWindowDestination = .search }`, springt korrekt zur Suche |
| [SearchView.swift:45](diskindex/diskindex/Views/Search/SearchView.swift:45) | ❌ Nein — aber die Ergebnisse filtern hier schon live bei jedem Tastendruck (reaktive Bindung an `searchState.query`), das ist vermutlich das vom Nutzer beschriebene „reagiert auf KeyUp/Down" statt auf Enter |

**Fix für Dashboard und Registry:** Exakt das gleiche Muster wie in `ColumnBrowserView` übernehmen:
```swift
ObjectSearchField(text: $state.searchState.query) {
    appState.mainWindowDestination = .search
}
```

**Klarstellung (Nutzer, 21.09.):** In der Suchansicht selbst soll die Tabelle **nicht mehr live bei jedem Tastendruck** filtern, sondern **nur auf Enter** aktualisiert werden — exakt umgekehrtes Verhalten zu jetzt.

**Root Cause:** [SearchView.swift:22-36](diskindex/diskindex/Views/Search/SearchView.swift:22) — `matchedMedia` und `results` sind beide direkt aus `appState.searchState.query` berechnet, das live ans `TextField` gebunden ist. Jeder Tastendruck löst sofort eine Neuberechnung aus, `onSubmit` wird gar nicht gebraucht/beachtet.

**Fix:** Eingabe- und Filter-Query entkoppeln — zwei getrennte States:
```swift
@State private var submittedQuery: String = appState.searchState.query  // oder eigenes @State in SearchView

private var matchedMedia: [Medium] {
    SearchMockResults.matching(query: submittedQuery, filters: appState.searchState.filters, media: appState.registryMedia).0
}
private var results: [SearchResultItem] {
    sorted(SearchMockResults.matching(query: submittedQuery, filters: appState.searchState.filters, media: appState.registryMedia).1)
}
```
Das `TextField` selbst bindet weiterhin live an `appState.searchState.query` (damit man beim Tippen sieht, was man tippt), aber `matchedMedia`/`results` lesen `submittedQuery`, das **nur** im `onSubmit`-Callback aktualisiert wird:
```swift
ObjectSearchField(text: $state.searchState.query) {
    submittedQuery = state.searchState.query
}
```
Zusätzlich: Wenn das Suchfeld komplett geleert und dann Enter gedrückt wird, muss `submittedQuery` auch auf leer aktualisiert werden (damit man die Suche wieder verlassen/zurücksetzen kann) — das deckt der obige Code schon ab, da `onSubmit` bei jedem Enter feuert, unabhängig vom Inhalt. Bitte NICHT zusätzlich `onChange(of: text)` verwenden, das würde wieder live filtern.

**Review-Fix (Cursor, Runde 27):** `ObjectSearchField` in `DashboardView` und `RegistryView` mit `onSubmit` → `mainWindowDestination = .search` (wie Column Browser). `SearchView`: `submittedQuery` nur bei Enter; Ergebnisse/Karten aus `submittedQuery`, Feld live an `searchState.query`; `onAppear` übernimmt vorbefüllte Query nach Navigation. `xcodebuild` ✅.

---

## 14. Codebase-Audit (Claude, 21.09.) — Performance & kleinere Lücken

**Status:** Erledigt durch Cursor (`xcodebuild` ✅, Runde 28).

Vollständiger Code-Durchlauf über alle Swift-Dateien, nicht nur Screenshot-Feedback. Ergebnisse:

### Performance (echte O(n²)-Muster, werden mit echten Daten spürbar)

1. **[RegistryView.swift:44-47](diskindex/diskindex/Views/Registry/RegistryView.swift:44):** `ForEach(Array(filteredMedia.enumerated())…) { index, medium in … index == filteredMedia.count - 1 }` — `filteredMedia` ist eine computed property (filtert + sortiert bei jedem Zugriff), wird aber **pro Zeile nochmal komplett neu berechnet**, nur um `.count` fürs `isLast`-Flag zu bekommen. Das ist ein voller Filter+Sort-Durchlauf pro sichtbarer Zeile. Fix: `let items = filteredMedia` einmal am Anfang von `body` capturen, `items.count` in der Closure verwenden statt `filteredMedia.count`.

2. **[SearchView.swift:22-36](diskindex/diskindex/Views/Search/SearchView.swift:22) + [173-175](diskindex/diskindex/Views/Search/SearchView.swift:173):** Gleiches Muster (`results.count` in der `ForEach`-Closure statt gecacht) — UND zusätzlich rufen `matchedMedia` und `results` **beide unabhängig voneinander** `SearchMockResults.matching(...)` auf (derselbe teure Scan+Filter zweimal pro Render), `results` sortiert danach nochmal extra. Bei Mock-Daten unsichtbar, wird aber merklich ruckeln, sobald echte Suchergebnisse mit hunderten/tausenden Einträgen reinkommen. Fix: `matching(...)` einmal pro Render aufrufen (z. B. in einem `@State`, aktualisiert in `onSubmit`), `matchedMedia` und `results` aus demselben gecachten Tupel ableiten statt zweimal neu zu berechnen.

### Kleinere Lücken/Bugs

3. **[MediumDetailModalView.swift:15](diskindex/diskindex/Views/Detail/MediumDetailModalView.swift:15):** Wenn `mediumID` nicht gefunden wird, fällt der Code still auf `MockData.media[0]` zurück (`appState.medium(with: mediumID) ?? MockData.media[0]`) — zeigt dann die Details eines **falschen** Mediums an, statt das Modal zu schließen. Fix: `medium` optional machen, bei `nil` das Modal automatisch schließen (`appState.detailMediumID = nil`).

4. **[MediumDetailModalView.swift:92-94](diskindex/diskindex/Views/Detail/MediumDetailModalView.swift:92):** Der "Neu indizieren"-Button im Detail-Modal hat eine **leere Action** (`Button("Neu indizieren") {}`) — tut buchstäblich nichts, kein Feedback. Bitte zumindest den Mock-Zustand ändern (`medium.indexStatus = .indexing`), damit er nicht kaputt wirkt.

5. **`showAbsoluteCapacity` ist weiterhin global** ([AppState.swift:14](diskindex/diskindex/App/AppState.swift:14)) — Klick auf die Prozent-Anzeige auf **einer** Dashboard-Karte kippt aktuell die Anzeige für **alle** Karten gleichzeitig ([MediumDashboardCard.swift:68](diskindex/diskindex/Views/Dashboard/MediumDashboardCard.swift:68)). **Entschieden (Nutzer, 21.09.): pro Medium, nicht global.** Fix: `showAbsoluteCapacity: Bool` von `AppState` in `Medium` verschieben (bzw. ein separates `[UUID: Bool]`-Dictionary in `AppState`, falls `Medium` selbst nicht veränderlich pro Instanz gehalten wird) — jede Karte/Zeile/jedes Popover-Element, das diesen Toggle nutzt, muss ab jetzt den Wert **des jeweiligen Mediums** lesen/schreiben, nicht mehr `appState.showAbsoluteCapacity`. Betrifft mindestens: `MediumDashboardCard.swift`, `MenuBarConnectedMediumRow.swift` (Popover-Fortschrittsanzeige), ggf. weitere Stellen — bitte projektweit nach `showAbsoluteCapacity` suchen und alle Fundstellen umstellen.

### Architektur-Hinweis, keine akute Aktion nötig
`ColumnBrowserMockData.stableID` (Zeile 103) hasht Dateinamen in Fake-UUIDs durch Byte-Summierung — Kollisionsanfällig, und `ColumnBrowserMockData.item(id:...)`/`selectedDetailFile` bauen bei jedem Zugriff die komplette Ordnerliste neu auf statt zu cachen. Für die aktuelle Mock-Daten-Größe unproblematisch, aber **bevor echtes Disk-Scanning/Indexing drankommt** (siehe „Offene Produktentscheidungen" unten), muss dieses Muster (kompletter Neuaufbau pro Zugriff, hash-basierte Fake-IDs) ersetzt werden durch echte stabile IDs + Caching/Indexierung. Nur als Merkposten, nicht jetzt umsetzen.

**Review-Fix (Cursor, Runde 28):** (1) `RegistryView`: `registryItems = filteredMedia` einmal in `body`. (2) `SearchView`: `searchMatch` einmal `matching` + Sort; `rows` in `ForEach`. (3–4) `MediumDetailModalView`: unbekannte ID → Modal schließen; „Neu indizieren“ Mock → `.indexing`. (5) `showAbsoluteCapacity` auf `Medium`, Toggle per `updateMedium` in `MediumDashboardCard` + `MenuBarConnectedMediumRow`; aus `AppState` entfernt. `xcodebuild` ✅.

**Review-Fix (Cursor, Runde 29):** `SearchView.body` hält ein `match`-Tupel pro Render (Karten + Tabelle + State); Dashboard/Popover-Zeilen lesen `liveMedium` aus `AppState` für pro-Medium-Toggles. `xcodebuild` ✅.

---

## 15. Suchfeld-Cursor bleibt dauerhaft aktiv/blinkend

**Status:** Erledigt durch Cursor (`xcodebuild` ✅, Runde 38).

**Symptom (Nutzer, 21.09.):** In der Suchansicht bleibt der blinkende Text-Cursor im „Objekte suchen…"-Feld permanent aktiv, egal was man danach in der App macht (andere Elemente anklicken etc.) — das Feld gibt den Tastatur-Fokus offenbar nie wieder ab.

**Verdacht:** [ObjectSearchField.swift](diskindex/diskindex/DesignSystem/ObjectSearchField.swift) hat kein `@FocusState`/`.focused(...)` — das `TextField` verwaltet seinen First-Responder-Status komplett selbst. Wenn andere UI-Elemente in der Suchansicht (Tabellenzeilen, Karten) über `.onTapGesture`/reine Tap-Handler statt über echte fokussierbare Controls (`Button` reicht meist schon) reagieren, „stiehlt" nichts dem Suchfeld den Fokus zurück, und der Cursor bleibt sichtbar blinkend stehen.

**Bitte reproduzieren und beheben, plausible Ansätze:**
1. `ObjectSearchField` um `@FocusState`/`.focused($isFocused)` erweitern, steuerbar von außen.
2. In `SearchView`: bei Klick auf Ergebniszeilen/Karten (oder generell irgendwo außerhalb des Suchfelds) den Fokus aktiv wegnehmen — entweder über das neue `@FocusState` (`isFocused = false`) oder notfalls per AppKit (`NSApp.keyWindow?.makeFirstResponder(nil)`), falls SwiftUI-seitig nicht zuverlässig genug.
3. Prüfen, ob dasselbe Muster (kein `@FocusState`) auch in anderen `ObjectSearchField`-Einsatzstellen (Dashboard, Registry, Column Browser) zu ähnlichen Symptomen führt, auch wenn dort bisher nichts gemeldet wurde — `ObjectSearchField` ist eine gemeinsame Komponente, ein Fix dort sollte konsistent für alle vier Einsatzstellen gelten.

**Review-Fix (Cursor, Runde 30):** `ObjectSearchField` mit `@FocusState.Binding` + `.focused`; alle vier Toolbar-Einsatzstellen binden `@FocusState`. `SearchView`: Fokus bei Tap auf Ergebnis-ScrollViews und vor Filter-Button explizit abgeben (`isObjectSearchFocused = false`). `ObjectSearchField.swift`, `SearchView`, `DashboardView`, `RegistryView`, `ColumnBrowserView`. `xcodebuild` ✅.

**Review (Claude, 21.09., Runde 34) — Fix war richtig, aber lückenhaft:** ❌ Nutzer bestätigt: Problem besteht weiterhin. Ich hab [SearchView.swift](diskindex/diskindex/Views/Search/SearchView.swift) geprüft — es gibt bereits `.simultaneousGesture(TapGesture().onEnded { isObjectSearchFocused = false })` auf der Medien-Karten-`ScrollView` (Zeile 56) und der Ergebnis-`ScrollView` (Zeile 65), plus expliziten Reset vor dem Filter-Popover (Zeile 113). Das deckt aber nicht alles ab — z. B. Klicks auf die native Fenster-Titelleiste/Traffic-Lights, auf Home-/Zahnrad-Icon in `MainWindowToolbar`, oder generell irgendeine Stelle außerhalb der beiden abgedeckten `ScrollView`-Bereiche.

**Vorschlag statt weiterer Einzelgesten-Nachrüstung:** Nicht noch mehr punktuelle `.simultaneousGesture`-Aufrufe verteilen (das Muster ist strukturell fehleranfällig, weil man jede neue Fläche einzeln nachziehen muss) — stattdessen einen **Catch-all auf Fenster-Ebene**: Wenn der Nutzer irgendwo in die App klickt, das aber NICHT das Suchfeld selbst ist, soll der First Responder generell wegwandern. Zwei Optionen:
1. **Einfacher SwiftUI-Weg:** `.focused($isObjectSearchFocused)` auf das `TextField` UND zusätzlich auf den kompletten `VStack`-Wurzel-Container in `SearchView.body` ein `.contentShape(Rectangle()).onTapGesture { isObjectSearchFocused = false }` legen (ganz unten in der View-Hierarchie, sodass alle Kindelemente, die selbst keine eigene Gesten-Behandlung haben, automatisch durchgereicht werden) — muss aber mit `.simultaneousGesture` bei klickbaren Kindelementen kombiniert bleiben, damit die eigentliche Aktion (Navigation etc.) nicht verloren geht.
2. **Robuster (AppKit-Ebene, wie schon beim Menüleisten-Panel gemacht):** Beim Öffnen der Suchansicht einen lokalen `NSEvent`-Monitor registrieren (`NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown])`), der bei jedem Klick irgendwo im Fenster prüft, ob der Klick außerhalb des Suchfeld-Bereichs war, und falls ja `isObjectSearchFocused = false` setzt bzw. `window.makeFirstResponder(nil)` aufruft — das deckt garantiert auch native Fensterbereiche (Titelleiste etc.) ab, die SwiftUI-Gesten gar nicht erreichen. Empfehlung: Option 2, da Option 1 vermutlich wieder nur Teilabdeckung bringt (gleiche Fehlerklasse wie der bisherige Versuch).

Bitte nach dem Fix testen: Suchfeld fokussieren, dann NACHEINANDER auf Titelleiste, Home-Icon, Zahnrad-Icon, eine Ergebniszeile UND eine leere Fläche ganz unten im Fenster klicken — in jedem Fall muss der blinkende Cursor verschwinden.

**Review-Fix (Cursor, Runde 36):** Option 2 — `NSEvent.addLocalMonitorForEvents` (`.leftMouseDown`) in `ObjectSearchFocusOutsideClickDismissModifier`; Klick außerhalb des Suchfeld-Frames (Fensterkoordinaten via `ObjectSearchFieldFrameInWindowReporter` in `ObjectSearchField`) → `isFocused = false` + `makeFirstResponder(nil)`. Modifier auf `SearchView`, `DashboardView`, `RegistryView`, `ColumnBrowserView`; punktuelle `simultaneousGesture` in `SearchView` entfernt. `ObjectSearchFocusMonitor.swift`, `ObjectSearchField.swift`. `xcodebuild` ✅.

**Zwischenzeitlich weiterentwickelt (Runde 37):** `ObjectSearchFocusClickMonitor` als zentraler Singleton mit Klienten-Registrierung + `ObjectIdentifier`-Fensterprüfung (behebt die in Aufgabe 18 Punkt G/H notierten Risiken) — Architektur ist jetzt sauber.

**Review (Claude, 21.09., Runde 38) — Nutzer meldet: Fokus in Dashboard bleibt weiterhin hängen, UND der Filter-Button in der Suche öffnet gar nichts mehr. Ich vermute EINE gemeinsame Ursache für beides:**

In [ObjectSearchFocusMonitor.swift:153-154](diskindex/diskindex/DesignSystem/ObjectSearchFocusMonitor.swift:153) (`handleMouseDown`) wird bei **jedem** `leftMouseDown`-Event im Fenster — nicht nur bei Klicks aufs Suchfeld — synchron `client.dismissFocus()` **und zusätzlich** `eventWindow.makeFirstResponder(nil)` aufgerufen, sobald irgendein registriertes Suchfeld gerade fokussiert ist. Das passiert als lokaler `NSEvent`-Monitor, der **während** der `mouseDown`-Verarbeitung feuert — also bevor SwiftUI die Klick-Geste des eigentlichen Ziel-Elements (z. B. der Filter-Button) fertig verarbeitet hat.

**Verdacht:** Das erzwungene `makeFirstResponder(nil)` mitten im Event-Zyklus stört die nachfolgende Klick-/`mouseUp`-Erkennung für das eigentliche Ziel-Element. Ein lokaler Monitor, der `return event` zurückgibt, soll das Event eigentlich unverändert durchreichen — aber das **Nebeneffekt-Verhalten** (First-Responder-Wechsel als Seiteneffekt der Callback-Ausführung) kann trotzdem den Rest der Event-Verarbeitung durcheinanderbringen, weil AppKit den First-Responder-Wechsel sofort synchron vollzieht, nicht erst nach Abschluss des aktuellen Klick-Zyklus.

**Fix-Vorschlag — `makeFirstResponder(nil)` ersatzlos entfernen, nur noch SwiftUI-seitig lösen:**
```swift
// in handleMouseDown, Zeile ~153:
client.dismissFocus()
// eventWindow.makeFirstResponder(nil)  <- entfernen
```
`dismissFocus` setzt bereits `isFocused = false` über die `@FocusState`-Bindung — SwiftUI kümmert sich danach **selbst** darum, dass das zugehörige `NSTextField` den First-Responder-Status abgibt (das ist ja genau der Sinn von `@FocusState`, es an den First-Responder zu koppeln). Der manuelle AppKit-Aufruf ist vermutlich redundant und richtet mehr Schaden an, als er nützt.

**Bitte nach dem Fix beides einzeln testen** (nicht nur eins, da beide Symptome zusammenhängen könnten, aber nicht müssen):
1. Dashboard: Suchfeld fokussieren, woanders hinklicken → Fokus muss weg sein.
2. Suchansicht: Suchfeld fokussieren (damit ein Klient „isFocused" ist), DANN auf „Filter" klicken → Panel muss aufgehen. Auch ohne vorherigen Suchfeld-Fokus nochmal testen, falls das Problem nur in Kombination auftritt.

Falls das Entfernen von `makeFirstResponder(nil)` den Fokus-Bug (Dashboard) wieder aufleben lässt (falls SwiftUIs `@FocusState`-Sync allein doch nicht zuverlässig genug ist, was der ursprüngliche Grund für den AppKit-Fallback war), bitte NICHT den Monitor komplett umbauen, sondern gezielt `makeFirstResponder(nil)` **verzögert** aufrufen (`DispatchQueue.main.async`), damit der aktuelle Klick-Zyklus des eigentlichen Ziel-Elements zuerst fertig verarbeitet wird, bevor der First-Responder-Wechsel erzwungen wird.

**Review-Fix (Cursor, Runde 38):** In `ObjectSearchFocusClickMonitor.handleMouseDown` synchrones `eventWindow.makeFirstResponder(nil)` entfernt — nur noch `client.dismissFocus()` (`@FocusState = false`), damit Klicks auf andere Controls (z. B. Filter-Button) den Event-Zyklus nicht stören. `ObjectSearchFocusMonitor.swift`. `xcodebuild` ✅.

---

## 16. Pointer-Cursor-Lücke im Detail-Modal + Byte-Formatierung zu grob

**Status:** Erledigt durch Cursor (`xcodebuild` ✅).

1. **[MediumDetailModalView.swift](diskindex/diskindex/Views/Detail/MediumDetailModalView.swift) fehlt komplett in der `pointerCursor()`-Abdeckung** (siehe Aufgabe 11) — geprüft per `grep -rl pointerCursor`, diese Datei taucht nicht auf. Betrifft mindestens: „Neu indizieren"-Button ([Zeile 104](diskindex/diskindex/Views/Detail/MediumDetailModalView.swift:104)), „Vergessen"-Button (destruktiv), Close-„✕"-Button. Bitte `.pointerCursor()` auf alle Buttons in dieser Datei ergänzen (das Ja/Nein für „Soll indiziert werden" läuft schon über `BinaryButtonGroup`, die es bereits hat — nur die eigenständigen `Button(...)`-Aufrufe in dieser Datei fehlen).

2. **Byte-Größen werden immer auf GB gerundet, nie feiner.** Root Cause: [ByteCountFormatting.swift](diskindex/diskindex/DesignSystem/ByteCountFormatting.swift) — `formatter.allowedUnits = [.useTB, .useGB]`, hart auf nur diese zwei Einheiten beschränkt. Eine 15KB-Datei oder ein 45MB-Ordner wird dadurch fälschlich als „0 GB" o. ä. angezeigt statt in einer sinnvollen Einheit. Fix: `allowedUnits` auf `.useAll` setzen (oder die Zeile ganz entfernen, Default ist bereits `.useAll`) — `ByteCountFormatter` wählt dann automatisch die passende Einheit je nach Größenordnung (Byte/KB/MB/GB/TB), sowohl für große Medium-Kapazitäten (Dashboard, weiterhin „4,1 TB") als auch für kleine Datei-Details (Column Browser, „5 Byte", „15 KB", „45 MB"). Bitte nach dem Fix an mehreren Stellen gegenchecken (Dashboard-Karten weiterhin TB/GB korrekt, Column-Browser-Detail-Spalte jetzt auch kleine Einheiten), da dieselbe zentrale Formatter-Instanz überall im Projekt verwendet wird.

**Review-Fix (Cursor, Runde 31):** `pointerCursor()` auf Schließen, „Index anzeigen“, „Neu indizieren“, „Vergessen“ in `MediumDetailModalView`. `ByteCountFormatting`: `allowedUnits`-Beschränkung entfernt (Default `.useAll`). `xcodebuild` ✅.

---

## 17. Dock-Icon nur, solange das Hauptfenster offen ist

**Status:** Erledigt durch Cursor (`xcodebuild` ✅, Runde 36 Nacharbeit Icon).

**Anforderung (Nutzer, 21.09.):** Die App bleibt grundsätzlich eine reine Menüleisten-App (kein dauerhaftes Dock-Icon, `LSUIElement = YES` bleibt bestehen). Aber: **sobald das Hauptfenster geöffnet wird, soll ein Dock-Icon erscheinen** — und wieder verschwinden, sobald das Hauptfenster geschlossen wird.

**Umsetzung:** `NSApplication.shared.setActivationPolicy(...)` dynamisch umschalten, gekoppelt an den Hauptfenster-Lebenszyklus in [AppWindowPresenter.swift](diskindex/diskindex/App/AppWindowPresenter.swift):
- Beim Öffnen des Hauptfensters (`openMain`): `NSApp.setActivationPolicy(.regular)` (macht Dock-Icon sichtbar), danach wie gehabt `NSApp.activate(ignoringOtherApps: true)`.
- Beim Schließen des Hauptfensters (im bereits vorhandenen `PresenterWindowDelegate.windowWillClose`, siehe `AppWindowPresenter.swift`): `NSApp.setActivationPolicy(.accessory)` (Dock-Icon verschwindet wieder), aber **nur wenn tatsächlich kein anderes reguläres Fenster mehr offen ist** — falls z. B. der „Neues Medium"-Dialog parallel offen ist, bitte kurz prüfen, ob der auch ein Dock-Icon rechtfertigen soll oder nicht (vermutlich nicht, da das eher ein System-Panel ist, siehe Aufgabe 9) — im Zweifel: Policy nur am Hauptfenster-Open/-Close umschalten, den New-Medium-Dialog davon unberührt lassen.

**Icon-Motiv — KORRIGIERT (Nutzer, 21.09.):** ~~schwarz auf transparentem Grund~~ war falsch spezifiziert. Richtig: **opakes schwarzes Quadrat/Squircle als Hintergrund, das gestapelte-Festplatten-Glyph in WEISS darüber** (invertiert — helles Symbol auf dunklem Grund, wie bei den meisten macOS-App-Icons üblich). Aktuell (per Pixel-Check bestätigt, `icon_512x512@2x.png`, Pixel `(5,5)` = `(0,0,0,0)`) ist der Hintergrund komplett **transparent**, das ist für ein Dock-Icon nicht valide/nicht ideal (Apple-HIG erwartet opake, den Canvas ausfüllende Icons). Bitte alle Icon-Größen neu rendern: schwarzer, voll deckender Hintergrund (gerne mit den macOS-typischen abgerundeten Ecken/Squircle-Proportionen, ca. 10% Rand-Padding laut HIG) + weißes Glyph mittig.

**Aktueller Stand:** [Assets.xcassets/AppIcon.appiconset](diskindex/diskindex/Assets.xcassets/AppIcon.appiconset) enthält aktuell **nur die `Contents.json`, keine tatsächlichen Bilddateien** — es gibt also noch gar kein echtes App-Icon, nur den leeren Asset-Slot. Bitte aus der vorhandenen `HardDrivesGlyphShape`-Geometrie (oder dem finalen korrekten SVG-Pfad, falls der aus Aufgabe 2 inzwischen 1:1 übernommen wurde) ein vollständiges Icon-Set rendern (alle von Xcode geforderten Größen — 16/32/64/128/256/512/1024pt in 1x/2x, je nach `Contents.json`-Vorgabe), schwarzes Icon auf transparentem oder passendem Grund, und ins `AppIcon.appiconset` einfügen.

**Konzept/Zweck (siehe [README.md](README.md)):** Der Sinn des Dock-Icons ist Fenster-Erreichbarkeit, nicht Branding — solange das Hauptfenster offen ist, muss es (a) per Klick auf das Dock-Icon in den Vordergrund geholt werden können (falls es hinter anderen Fenstern verschwunden ist) und (b) über ⌘-Tab im App-Umschalter erscheinen und anwählbar sein. Beides ist Standard-Verhalten von `NSApp.setActivationPolicy(.regular)` und braucht keine zusätzliche Implementierung — bitte nach dem Fix trotzdem beides kurz testen (Fenster hinter eine andere App schieben, Dock-Icon anklicken → muss nach vorne kommen; ⌘-Tab gedrückt halten → App muss im Umschalter auftauchen, solange das Hauptfenster offen ist).

**Review (Claude, 21.09., Runde 33) — zwei konkrete Nacharbeiten:**

1. ❌ **Dock-Name falsch/„Quatsch".** Root Cause: `PRODUCT_NAME = "$(TARGET_NAME)"` im Xcode-Projekt ist `diskindex` (Xcode-Target-Name in Kleinschreibung), nicht „Disk Index". Fix: `INFOPLIST_KEY_CFBundleDisplayName = "Disk Index"` explizit für beide Build-Configs (Debug + Release) in `project.pbxproj` setzen — analog wie `INFOPLIST_KEY_LSUIElement` schon gesetzt ist.

2. ❌ **Dock-Icon erscheint leer.** Ich habe [icon_512x512@2x.png](diskindex/diskindex/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png) direkt geöffnet — die Datei selbst zeigt korrekt das schwarze Festplatten-Icon auf weißem Grund, ist also nicht leer. Das deutet stark auf einen **macOS-Icon-Cache** hin (bekannter Effekt: geänderte App-Icons in `Assets.xcassets` werden von macOS teils nicht sofort im Dock aktualisiert, selbst nach Rebuild, weil `iconservicesagent`/`lsregister` das alte Icon für die Bundle-ID zwischenspeichert). Bitte:
   - Erst mit einem **komplett frischen Build** testen (Clean Build Folder in Xcode, `⇧⌘K`, dann neu bauen).
   - Falls das Icon immer noch leer bleibt: lokal den Icon-Cache leeren, z. B. `killall Dock` nach dem Neubau, oder `sudo rm -rf /Library/Caches/com.apple.iconservices.store; killall Dock` (destruktiv am System-Cache, nur als Diagnose-Schritt, kein Teil des eigentlichen Codes/Fixes).
   - Falls das Icon danach IMMER noch leer bleibt (also kein Cache-Problem war): dann tatsächlich prüfen, ob `AppIcon.appiconset` korrekt im Build-Target eingebunden ist und ob im fertig gebauten `.app`-Bundle (`Contents/Resources/AppIcon.icns` bzw. `Assets.car`) das Icon überhaupt vorhanden ist — aber das ist der unwahrscheinlichere Fall, da die Rohdatei nachweislich korrekt ist.

**Review-Fix (Cursor, Runde 33):** `INFOPLIST_KEY_CFBundleDisplayName = "Disk Index"` (Debug + Release in `project.pbxproj`). AppIcon-PNGs neu gerendert mit `NSBitmapImageRep` in exakten Pixelmaßen (Runde-32-Export war durch Retina-`lockFocus` doppelt groß → u. a. 2048 statt 1024 für `icon_512x512@2x`, vermutliche Ursache für leeres Dock-Icon). Clean Build empfohlen; ggf. `killall Dock` bei Cache. `xcodebuild` ✅.

**Review (Claude, 21.09., Runde 35) — beide Probleme laut Nutzer weiterhin da, trotz Fix in Runde 33:**

1. **Icon:** Pixelmaß-Fix war vermutlich richtig, aber unabhängig davon habe ich den Alpha-Kanal der aktuellen PNG direkt geprüft (`icon_512x512@2x.png`, Pixel `(5,5)`) — Ergebnis: `(0,0,0,0)`, also **komplett transparenter Hintergrund**. Das ist ein zweites, unabhängiges Problem von der Pixelmaß-Sache und erklärt weiterhin ein unbefriedigendes Dock-Icon (auch wenn "leer" jetzt evtl. behoben ist, sieht ein Icon ohne opaken Hintergrund auf hellem/dunklem Dock-Hintergrund inkonsistent aus). **Und die Farbgebung ist jetzt explizit umgedreht worden** (siehe korrigierte Spec oben: opak schwarz + weißes Glyph, nicht schwarzes Glyph auf transparent). Bitte das Icon-Rendering-Skript entsprechend anpassen: Canvas mit vollflächigem Schwarz (kein Alpha) füllen, Glyph in Weiß darüber zeichnen.

2. **Name:** Der Code-Fix (`INFOPLIST_KEY_CFBundleDisplayName`) ist im Projekt nachweislich vorhanden — trotzdem zeigt der Nutzer weiterhin den falschen Namen. Das deutet darauf hin, dass entweder (a) nicht wirklich clean neu gebaut wurde, oder (b) macOS den alten Namen für die Bundle-ID zwischenspeichert (LaunchServices-Datenbank, gleiche Fehlerklasse wie der Icon-Cache). Bitte zur Diagnose: Nach einem Clean Build direkt im gebauten `.app`-Bundle nachschauen (`Contents/Info.plist` im tatsächlichen Build-Output, nicht die Projektdatei) — steht dort wirklich „Disk Index"? Falls ja, ist es ein reines Cache-Problem, lösbar z. B. mit `sudo /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -kill -r -domain local -domain system -domain user` (danach Dock/Finder neu starten) — bitte kurz recherchieren, ob es einen saubereren Weg gibt, bevor der LaunchServices-Reset als Diagnoseschritt genutzt wird, da er systemweit wirkt.

**Review-Fix (Cursor, Runde 37):** `GenerateAppIcons.swift` — Glyph-Form per `.draw`, Weiß via `CGContext.setBlendMode(.sourceIn)` (statt wirkungslosem `isTemplate` + `NSColor.set()`). Pixel-Check `@2x`: Ecke `(0,0,0,255)`, Mitte `(255,255,255,255)`. PNGs neu geschrieben. `xcodebuild` ✅.

**Review (Claude, 21.09., Runde 36) — Icon jetzt komplett schwarz, kein Glyph mehr sichtbar (neuer Bug):** ❌ Per Pixel-Scan bestätigt: [icon_512x512@2x.png](diskindex/diskindex/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png) ist jetzt zwar korrekt opak (`(0,0,0,255)`), aber **jeder** gesampelte Pixel im ganzen Bild ist reines Schwarz — kein einziger weißer/heller Pixel, das Glyph ist komplett verschwunden.

**Root Cause gefunden** in [Scripts/GenerateAppIcons.swift:64-82](diskindex/Scripts/GenerateAppIcons.swift:64): Der Code füllt zuerst den Hintergrund schwarz, setzt dann `glyph.isTemplate = true` und `NSColor.white.set()`, und zeichnet den Glyph mit `.draw(in:from:operation: .sourceOver, ...)`. Das Problem: **`NSColor.white.set()` tintet ein `NSImage` beim manuellen `.draw()`-Aufruf nicht** — `.set()` setzt nur die aktuelle Fill-/Stroke-Farbe für nachfolgende Pfad-Operationen, hat aber keinen Effekt auf Bild-Kompositing. `isTemplate = true` allein tintet ebenfalls nicht automatisch bei manuellem Draw (das greift nur, wenn AppKit selbst das Bild in bestimmten UI-Kontexten rendert, z. B. `NSButton`/`NSImageView`). Ergebnis: Der Glyph wird mit seiner **eigenen Originalfarbe aus der SVG (schwarz)** gezeichnet — schwarz auf schwarzem Hintergrund, unsichtbar.

**Fix — Bild-Tinting per Blend-Mode statt `.set()`:** Erst den Glyph zeichnen (liefert die Form als Alpha-Maske), dann eine weiße Fläche mit `.sourceIn`- oder `.sourceAtop`-Compositing darüberlegen, das nur die bereits gezeichnete Form einfärbt:
```swift
// Nach dem schwarzen Hintergrund-Fill:
glyph.draw(
    in: glyphRect,
    from: NSRect(origin: .zero, size: glyphSource.size),
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: false,
    hints: [.interpolation: NSImageInterpolation.high]
)
// Glyph-Form jetzt vorhanden (schwarz) — mit Weiß eintönen via sourceIn:
NSColor.white.setFill()
NSBezierPath(rect: glyphRect).fill(using: .sourceIn)
```
`NSBezierPath.fill(using:)` mit `.sourceIn` ersetzt nur die Pixel, die im Zielbereich bereits undurchsichtig sind (also exakt die zuvor gezeichnete Glyph-Form), mit der neuen Fill-Farbe — der Rest bleibt unangetastet. Bitte nach dem Fix erneut per Pixel-Check verifizieren (nicht nur visuell im Xcode-Vorschaubild, das hatte schon zweimal einen echten Bug übersehen lassen), dass sowohl ein opaker schwarzer Hintergrund als auch tatsächlich weiße Pixel im Glyph-Bereich vorhanden sind.

**Review-Fix (Cursor, Runde 36):** AppIcon-PNGs neu gerendert (`Scripts/GenerateAppIcons.swift`): opaker schwarzer Canvas (Pixel `(5,5)` = `(0,0,0,255)`), weißes Glyph (10 % Padding). **Diagnose Name:** Nach Clean Build enthält `diskindex.app/Contents/Info.plist` `CFBundleDisplayName` = „Disk Index“ (Build-Output DerivedData, 21.09.) — wenn das Dock weiter „diskindex“ zeigt, ist es LaunchServices-/Dock-Cache (sauberer erster Schritt: App neu starten nach Clean Build + `killall Dock`; systemweiter `lsregister -kill` nur als letzte Diagnose). `Assets.xcassets/AppIcon.appiconset/*.png`. `xcodebuild` ✅.

**Review-Fix (Cursor, Runde 32):** `AppActivationPolicy` — `.regular` in `openMain`, `.accessory` in `AppDelegate` beim Start und nach Schließen des Hauptfensters (`windowWillClose`); Neues-Medium-Panel unverändert. `AppIcon.appiconset`: PNGs aus `hard-drives.svg` (schwarz, alle macOS-Größen). Dateien: `AppActivationPolicy.swift`, `AppWindowPresenter.swift`, `AppDelegate.swift`, `Assets.xcassets/AppIcon.appiconset/`. `xcodebuild` ✅.

---

## 18. Vollständiges Code-Review (Claude, 21.09., Runde 37)

**Status:** ✅ Geprüft und erledigt (Claude, 28.09., Runde 40) — alle Punkte A–I im Code verifiziert; J bleibt Merkposten. Details siehe Review Runde 40 in Aufgabe 19.

Kompletter Durchlauf durch alle ~5.000 Zeilen (App/, MenuBar/, Views/, DesignSystem/, Models/), nicht Screenshot-basiert. **Zuerst das Positive — folgendes ist verifiziert korrekt umgesetzt und braucht nichts mehr:** Aufgabe 9 (Neues-Medium-Panel ist jetzt `NSPanel` + `.floating` + `isFloatingPanel`), Aufgabe 14 (Registry cached `registryItems` einmal; Detail-Modal nutzt Optional + Auto-Dismiss statt `MockData.media[0]`-Fallback; „Neu indizieren" hat echte Action), Aufgabe 16 (`allowedUnits`-Beschränkung entfernt; `pointerCursor` 4× im Detail-Modal), Aufgabe 6 (Statusleiste mit korrektem Wortlaut inkl. Singular „1 Objekt"), Aufgabe 15 (`NSEvent`-Monitor wie empfohlen), Aufgabe 17 (1100×750, `setFrameAutosaveName`, Activation-Policy-Wechsel), `showAbsoluteCapacity` pro Medium.

### A. Funktionale Lücke: Menüleisten-Badge ist komplett inaktiv

`AppState.menuBarBadgePreview` wird **nirgends mehr geschrieben** — geprüft per projektweitem Grep: nur drei Lesestellen ([MenuBarController.swift:100](diskindex/diskindex/MenuBar/MenuBarController.swift:100), [:114](diskindex/diskindex/MenuBar/MenuBarController.swift:114), plus die tote `MenuBarExtraLabel.swift`), null Schreibstellen. Der Debug-Picker, der den Wert früher gesetzt hat, wurde in Runde 22 entfernt — seitdem steht der Wert permanent auf `.idle`, d. h. **es erscheint nie ein Badge**, obwohl README Screen 02 vier Zustände spezifiziert (Wird indiziert / Neu erkannt / Pausiert / Fehler). Die gesamte Badge-Maschinerie (`MenuBarStatusBadgeView`, Spinner, Puls-Animation, X, „!") ist zur Laufzeit unerreichbar.

**Fix:** Badge aus dem echten Medien-Zustand ableiten statt aus einem manuell gesetzten Feld. Z. B. als computed property in `AppState`:
```swift
var effectiveMenuBarBadge: MenuBarBadgePreview {
    if media.contains(where: { !$0.isForgotten && $0.indexStatus == .error }) { return .error }
    if media.contains(where: { !$0.isForgotten && $0.indexStatus == .indexing }) { return .indexing }
    if media.contains(where: { !$0.isForgotten && $0.indexStatus == .pending }) { return .newlyDetected }
    if globalAutoIndexPaused { return .paused }
    return .idle
}
```
(Prioritätsreihenfolge bitte kurz gegen README Screen 02 prüfen — meine Reihenfolge ist ein Vorschlag, kein Spec-Zitat.) `MenuBarController` liest dann diese computed property, und `withObservationTracking` muss entsprechend auf `media` + `globalAutoIndexPaused` tracken statt auf `menuBarBadgePreview`. Das alte `menuBarBadgePreview`-Feld danach ersatzlos löschen.

### B. Performance: O(n²)-Lookup mitten im Sortier-Comparator

[SearchView.swift:253-256](diskindex/diskindex/Views/Search/SearchView.swift:253) — beim Sortieren nach Spalte „Speichermedium" ruft der Comparator für **jeden einzelnen Vergleich** zweimal `appState.medium(with:)` auf, was jedes Mal ein lineares `first { $0.id == id }` über das Medien-Array ist. Bei n Ergebnissen sind das O(n log n) Vergleiche × O(m) Lookup. Fix: vor dem Sortieren einmal ein `[UUID: String]`-Dictionary der Medien-Namen bauen und im Comparator nur noch daraus lesen.

### C. Performance: Verzeichnis-Listing wird pro Render mehrfach neu aufgebaut

In [ColumnBrowserView.swift](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift) ruft `ColumnBrowserMockData.children(...)` — das die Liste jedes Mal neu zusammenbaut **und sortiert** — pro Render mehrfach für teils identische Pfade auf: einmal je Spalte in `folderColumn` ([:191](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift:191)), nochmal für dieselbe rechteste Spalte in `rightmostColumnObjectCount` ([:401](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift:401)), und ein drittes Mal indirekt über `selectedDetailFile` → `ColumnBrowserMockData.item(...)` → `children(...)`. Mit Mock-Daten unkritisch, mit echten Ordnern (hunderte/tausende Einträge) spürbar. Fix: die Listen einmal pro `body`-Durchlauf berechnen (z. B. `let columns = (0..<depth).map { children(path: ...) }`) und an alle Verbraucher durchreichen.

### D. Performance/Sauberkeit: `selectedMedium` wird pro Render vielfach neu aufgelöst

`selectedMedium` ([ColumnBrowserView.swift:17-22](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift:17)) ist eine computed property, die entweder `medium(with:)` (linearer Scan) oder `registryMedia.first` (filtert das komplette Array) ausführt — und wird im `body` an mindestens sechs Stellen aufgerufen (Breadcrumb, Offline-Check, Sidebar-Markierung, Spalten, Statusleiste, Objektzähler). Fix: einmal am Anfang von `body` als `let medium = selectedMedium` auflösen und weiterreichen.

### E. Toter Code — ~80 Zeilen, null Verwendungen (per Grep verifiziert)

Alle folgenden Dateien werden nirgends referenziert (außer im eigenen Datei-Header-Kommentar) und sollten gelöscht werden:
- `MenuBar/MenuBarExtraLabel.swift` (26 Zeilen) — Überbleibsel der `MenuBarExtra`-Architektur, die in Runde 8 durch `NSStatusItem` ersetzt wurde
- `MenuBar/MenuBarIconRenderer.swift` (16 Zeilen) — laut eigenem Kommentar „nur noch Fallback", inzwischen gar nicht mehr aufgerufen
- `Views/ColumnBrowser/ColumnBrowserPlaceholder.swift`, `Views/Detail/MediumDetailPlaceholder.swift`, `Views/Registry/RegistryPlaceholder.swift`, `Views/Search/SearchPlaceholder.swift` (je 10 Zeilen) — Gerüst aus Aufgabe 0, nie entfernt

### F. Robustheit: `ForEach` über dynamischen Integer-Range

[ColumnBrowserView.swift:160](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift:160): `ForEach(0..<depth, id: \.self)`, wobei `depth` sich bei jeder Navigation ändert. Das ist der bekannte SwiftUI-Fallstrick „ForEach über veränderlichen Range" — führt zu View-Identitäts-Churn (Spalten werden neu aufgebaut statt aktualisiert), was plausibel zum seit mehreren Runden gemeldeten Resize-/Sprung-Verhalten beigetragen hat. Fix: statt über den Index-Range über ein explizites Array von Spalten-Deskriptoren iterieren (z. B. `struct ColumnDescriptor: Identifiable { let id: String /* Pfad */ ... }`), sodass jede Spalte eine stabile Identität über Navigationswechsel hinweg behält.

### G. Fokus-Monitor prüft die Fenster-Zugehörigkeit nicht

[ObjectSearchFocusMonitor.swift:101-115](diskindex/diskindex/DesignSystem/ObjectSearchFocusMonitor.swift:101): `handleMouseDown` vergleicht `event.locationInWindow` direkt mit `fieldFrameInWindow`, **ohne zu prüfen, ob das Event überhaupt aus dem Fenster stammt, in dem das Suchfeld liegt**. Beide Werte sind fensterlokale Koordinaten — bei mehreren offenen Fenstern (Hauptfenster + Neues-Medium-Panel + Menüleisten-Panel) können Klicks in einem anderen Fenster zufällig innerhalb des gepolsterten Rechtecks liegen und die Fokus-Aufhebung fälschlich überspringen. Fix: im `ReportingView` zusätzlich das `NSWindow` merken und in `handleMouseDown` prüfen, dass `event.window === dieses Fenster` ist, bevor die Koordinaten verglichen werden.

### H. Risiko: Event-Monitor kann sich ansammeln

Derselbe Modifier installiert seinen `NSEvent`-Monitor in `onAppear` und entfernt ihn in `onDisappear`. Er wird an vier Views verwendet (Dashboard, Registry, Column Browser, Suche), die in `MainWindowHostView` gegeneinander ausgetauscht werden. Falls `onDisappear` bei einem Wechsel mal nicht feuert (in SwiftUI nicht garantiert), bleibt ein Monitor aktiv und ein zweiter kommt dazu. Fix: Monitor zentral verwalten (z. B. ein Singleton mit Referenzzählung) statt pro View-Instanz, oder defensiv in `installMonitorIfNeeded` einen eventuell vorhandenen alten Monitor immer erst entfernen.

### I. Datenmodell: `capacityUsedPercent` ist redundant gespeichert

[Medium.swift:44-46](diskindex/diskindex/Models/Medium.swift:44): `capacityUsedPercent` liegt als eigenes gespeichertes Feld neben `capacityUsedBytes` und `capacityTotalBytes` — derselbe Sachverhalt doppelt, kann auseinanderlaufen (z. B. wenn später beim echten Scan nur die Bytes aktualisiert werden). Fix: als computed property ableiten (`Double(capacityUsedBytes) / Double(capacityTotalBytes) * 100`, mit Division-durch-Null-Schutz), Feld entfernen und die Mock-Daten entsprechend anpassen.

### J. Merkposten (keine Aktion jetzt)

- `SearchState.isSearchInProgress` wird nur gelesen, nie gesetzt — der „Suche läuft…"-Zustand ist damit aktuell unerreichbar. Das ist **so gewollt** (bewusst als Gerüst für eine spätere echte/asynchrone Suche angelegt, siehe Aufgabe 7b Punkt 3), nur zur Erinnerung dokumentiert.
- 13 hart codierte `UUID(uuidString: "...")!` in den Mock-Daten. Hat in Runde 5 schon einmal zu einem harten Crash geführt (ungültiges Hex-Zeichen „S"). Beim Umstieg auf echte Daten ersatzlos entfernen; solange sie bleiben, bei jeder Änderung auf gültiges Hex achten.

**Review-Fix (Cursor, Runde 37):** **A** — `AppState.effectiveMenuBarBadge` (Priorität: Fehler → Indizierung → pending/Neu → global pausiert → idle); `MenuBarController` trackt `media` + `globalAutoIndexPaused`; `menuBarBadgePreview` entfernt. **B** — `SearchView`: Medien-Namen-Dictionary für Sort „Speichermedium“. **C–D, F** — `ColumnBrowserView`: `makeFolderColumns` einmal pro Render, `ColumnBrowserFolderColumn` + stabile `ForEach`-IDs, `resolvedSelectedMedium`/`columns` einmal in `body`. **E** — Gelöscht: `MenuBarExtraLabel`, `MenuBarIconRenderer`, vier `*Placeholder.swift`. **G–H** — `ObjectSearchFocusClickMonitor` (Singleton, Refcount); Fenster-Match via `ObjectIdentifier` + Frame in Fensterkoordinaten. **I** — `capacityUsedPercent` computed aus Bytes; Mock-Daten angepasst. **J** unverändert (Merkposten). Dateien: `AppState.swift`, `MenuBarController.swift`, `SearchView.swift`, `ColumnBrowserView.swift`, `Medium.swift`, `MockData.swift`, `ObjectSearchFocusMonitor.swift`, `ObjectSearchField.swift`, `Scripts/GenerateAppIcons.swift`. `xcodebuild` ✅.

---

## 19. Layout-Revision vom 28.09. — Abgleich & Umbau

**Status:** ⚠️ **Nacharbeiten offen — siehe Review Runde 40 am Ende dieses Abschnitts.** Ursprünglich: **Erledigt durch Cursor** (`xcodebuild` ✅, Runde 39 + Abschluss 19.12–19.14). Unterpunkte 19.1–19.14 jeweils mit eigenem Status unten. **Noch offen im Block (bewusst / Feinschliff):** 19.2 Punkt 9–10 (Phosphor-Favoriten-Duotone, erweiterte Dateityp-Icons); Finder-Aktion im Objekt-Kontextmenü (Stub); gelbes Prohibit-Icon + 1‑h-Ignore-Bereinigung (UI-Hook, Backend folgt); Aufgabe-18-Punkte B–I außer A (weiterhin separat).

**Neue Quellen der Wahrheit (ersetzen die alten Pfade in allen früheren Aufgaben):**
- Haupt-Mockup: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html) — 14 Sektionen (00–13)
- Farbkonzept: [layout/Farbschema.dc.html](layout/Farbschema.dc.html)
- Design-System-CSS: [layout/ds-disk-index.css](layout/ds-disk-index.css)
- Projektregel für Mockups: [layout/CLAUDE.md](layout/CLAUDE.md) — in App-Fenstern keine Design-Annotationen, auch nicht in Tooltips/Labels wie „(aktiv)"
- Das alte Handoff (`Catalog App Design.dc.html` + `README.md`) liegt archiviert unter `layout/design_handoff_disk_index/` und ist **nicht mehr maßgeblich**.

**Neue Sektions-Nummerierung** (frühere Aufgaben in dieser Datei verwenden noch die alte!):

| Neu | Inhalt | Alt |
|---|---|---|
| 01 | Menüleisten-Icon | 02 |
| 02 | Erkennungs-Dialog | 01A |
| 03 | Popover | 03 |
| 04 | Dashboard | 04 |
| 05 | **Einstellungen** (Tabs; enthält die bisherige Registry) | 01B |
| 06 | Detail-Overlay | 05 |
| 07 | Spaltenansicht | 06 |
| 08 | **Spaltenansicht mit Filter** (neu) | — |
| 09 | Filter-Auswahl-Popover | 07B |
| 10 | Suche | 07 |
| 11 | **Favoriten** (neu) | — |
| 12 | **Kontextmenü an Ordnern & Dateien** (neu) | — |
| 13 | Styleguide & Icon-Sets | 08 + 09 |

**Leitprinzip des neuen Farbkonzepts:** *Farbe bedeutet immer einen Zustand, nie eine Bedienung — bedient wird in Schwarz.* Blau ist nicht mehr Akzent, sondern ausschließlich „Filter/Suche aktiv".

---

### 19.1 Farb-Tokens (Grundlage für alles Weitere)

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅, Runde 39).

In [DesignTokens.swift](diskindex/diskindex/DesignSystem/DesignTokens.swift) umbauen. Das Mockup gibt die Rollenfarben in OKLCH an; umgerechnet in sRGB (bitte diese Hex-Werte verwenden):

| Rolle | Wert | Verwendung |
|---|---|---|
| **Schwarz · Bedienung** | `#1F1F1F` | Primär-Buttons, Auswahl (auch aktive Sidebar-/Spaltenzeile, bisher `#1C1C1E`), aktive Tabs, Selectgroup-„Ja/An", Slider, Checkbox, aktive Tabellenspalte, Rechtsklick-Rahmen, Home-Icon aktiv |
| **Grün · Online** | `#20A04E` | Online (voll), wird indiziert / ausstehend (gestrichelt + Spinner), Neu erkannt (pulsierender Punkt) |
| **Rot · Fehler** | `#E04830` | Fehler-Status, destruktive Aktion („Vergessen"), „Ignorieren aktiv" im Kontextmenü. **Ersetzt alle vier bisherigen Rot-Tokens** (`red`, `redTint`, `redText`, `redBorderDark`) |
| **Gelb · Ignoriert** | `#EDA12D` | Ignore-Liste (voll), Inhalt jenseits der Scan-Tiefe (gestrichelt) — **neu** |
| **Blau · Filter/Suche** | `#3986E4` | Ausschließlich: Filter-/Such-Icon aktiv, Filter-Button, Filter-Chips, aktiver Chip in Chip-Leisten |
| **Violett · Favorit** | `#9D69D2` | Favoriten-Icon aktiv, Icons favorisierter Objekte, aktiver Kontextmenü-Eintrag „Favorit" — **ersetzt die bisherige Filter-Violett-Palette komplett** |
| **Türkis · Einstellungen** | `#00B5B5` | Nur: Zahnrad-Icon aktiv (Mockup: `oklch(0.7 0.12 195)`, bewusst andere Helligkeit als die übrigen Rollen) |
| **Grau · Aus** | `#868686` | „Nein", aus, leer, pausiert, indiziert, nicht erlaubt; Offline = gestrichelt ohne Fläche |

Neutrale Töne (`bg #F3F2F2`, `surface #EAE9E9`, `text #201E1D`, `neutral100–900`) bleiben wie im neuen CSS unverändert. **Blau-Rampe (`accent`, `accent100–800`) und Violett-Filter-Tokens entfallen**; alle Stellen, die sie nutzen, bekommen die passende neue Rolle (siehe 19.2). Ebenso entfallen `storageFillGradientStops` (siehe 19.6). Betroffene Dateien laut Grep: `IndexingProgressBar`, `MenuBarGhostButton`, `BinaryButtonGroup`, `IndexingSpinnerRing`, `MenuBarStatusBadgeView`, `MenuBarConnectedMediumRow`, `MainWindowToolbar`, `SearchView`, `SearchFilterPopover`, `MediumDetailModalView`, `RegistryView`, `StatusChip`, `VioletFilterChip`, `StorageFillGradientBar`, `MediumDashboardCard`, `ColumnBrowserRow`.

**Review-Fix (Cursor, Runde 39):** Rollenfarben (`control`, `stateOnline`, `stateError`, `stateIgnored`, `filterSearch`, `favorite`, `settingsActive`, `stateOff`), `chipFill`/`chipBorder`, `sidebarActiveBackground` → `control`. Legacy-Füllstands-Gradient nur noch lokal in `StorageFillGradientBar` (bis 19.6). Alle ehemaligen `accent`/`violet`/`red*`-Referenzen im Target ersetzt.

### 19.2 Komponenten nach Styleguide (Sektion 13)

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅, Runde 39) — Punkte 9–10 (Favoriten-/Dateityp-Icon-Erweiterungen) bewusst für spätere 19.x offen.

1. **Ein Chip-Rezept für alle Status-Chips** ([StatusChip.swift](diskindex/diskindex/DesignSystem/StatusChip.swift)): Schrift, Rand und Icon in der Basisfarbe; Fläche = Basisfarbe mit **5 % Deckkraft**. Gestrichelt (`dash`) = gleiche Schrift/Rand, **keine** Fläche = „unvollständig". Neue Zuordnung:

   | Zustand | Label | Stil |
   |---|---|---|
   | indexing | **„N % indiziert"** (Prozent aus `indexingProgress`, statt „Wird indiziert …") | Grün gestrichelt + grüner Spinner (7 px) |
   | connected + indexed | **„Online"** (statt „Indiziert") | Grün voll |
   | offline | „Offline" | Grau **gestrichelt**, keine Fläche (bisher durchgezogen) |
   | pending | „Ausstehend" | Grün gestrichelt (bisher blau) |
   | error | „! Fehler" | Rot voll |
   | nicht erlaubt / pausiert | „Nicht erlaubt" / „Pausiert" | Grau voll |

2. **Buttons** (groß + klein, je Primär/Sekundär/Ghost/Destruktiv): Primär = Schwarz `#1F1F1F` mit weißer Schrift; Ghost = Schwarz statt Blau (betrifft `MenuBarGhostButton`, z. B. „Disk Index öffnen", „Neu indizieren"); Destruktiv = Rot `#E04830` für Schrift + Rand. Regel: jeder farbige Button/Chip trägt einen Rand im dunkleren Ton derselben Farbe. Der kleine Button übernimmt exakt die Höhe der Selectgroup daneben.
3. **Selectgroup** ([BinaryButtonGroup.swift](diskindex/diskindex/DesignSystem/BinaryButtonGroup.swift)): aktives „Ja"/„An" = Schwarz-Fläche (bisher Blau), aktives „Nein"/„Pausiert" = Grau. Gruppenrand entsprechend Schwarz bzw. Grau.
4. **Spinner** ([IndexingSpinnerRing.swift](diskindex/diskindex/DesignSystem/IndexingSpinnerRing.swift)): Grün statt Blau.
5. **Indizier-Fortschrittsbalken** ([IndexingProgressBar.swift](diskindex/diskindex/DesignSystem/IndexingProgressBar.swift)): Füllung Schwarz (Mockup: `var(--color-accent)`), nicht mehr Blau.
6. **Tabellen-Regel neu:** **Keine Sortierpfeile mehr** in Tabellenköpfen (`arrow.up.arrow.down` in `SearchView` und `RegistryView` entfernen). Spaltennamen sind klickbar (Hand-Cursor) und sortieren; die aktiv sortierte Spalte erkennt man allein an **schwarzem, fettem** Header-Text, die übrigen normal/gedämpft. Letzte Spalte bleibt rechtsbündig.
7. **Suchfeld-Reset (verbindlich für jedes Suchfeld** — `ObjectSearchField`, `MediumCompactSearchField`, `MediumSidebarSearchField`): Sobald Text im Feld steht, erscheint rechts ein kleines **X in einem grauen Kreis**; Klick leert das Feld und setzt die zugehörige Suche/Filterung zurück. Im Leerzustand kein X. (In der Suchansicht löscht das X nur den Suchbegriff, die Suche bleibt offen — siehe 19.11.)
8. **Cursor-Regel:** Hand-Cursor auf allen klickbaren Elementen — ausdrücklich auch klickbare Zeilen, klickbare Spaltenköpfe und entfernbare Chips.
9. **Favoriten-Icons** (Phosphor): „Favoriten" = `bookmarks-simple` (zwei Lesezeichen) für die Navigation, „Favorit" = einzelnes Lesezeichen am Objekt. Inaktiv als Kontur in Textfarbe, aktiv als **Duotone in Violett** (gefüllt mit transparenter Fläche wie die Chips) — nie Blau.
10. **Dateityp-Icons erweitert:** zusätzlich „Programme" und „Skripte" sowie die spezifischen `ph-file-*`-Varianten (zip, csv, doc, html, jpg, js, md, png, ppt, py, sql, svg, txt, xls …) neben den generischen — siehe Sektion 13 „Dateitypen — Erweiterungen". Alle regular, Status-Icons dezent fetter.

**Review-Fix (Cursor, Runde 39):** `StatusChip` neu (5 %-Fläche, gestrichelt ohne Fläche, Labels „Online"/„N % indiziert"/…). Primär/Ghost/Selectgroup/Spinner/Indizier-Balken/Filter-Chips auf Rollenfarben. Tabellen: Sortierpfeile entfernt, aktive Spalte schwarz/fett + Hand-Cursor (`SearchView`, `RegistryView`). `SearchFieldClearButton` + Clear in allen drei Suchfeld-Typen. `SearchFieldClearButton.swift`, u. a. `DesignTokens`, `StatusChip`, `BinaryButtonGroup`, `VioletFilterChip`, `ObjectSearchField`, `MediumCompactSearchField`, `MediumSidebarSearchField`, `MenuBarGhostButton`, `IndexingProgressBar`, `IndexingSpinnerRing`, `MenuBarStatusBadgeView`, `MediumDetailModalView`, `SearchFilterPopover`. `xcodebuild` ✅.

### 19.3 Menüleisten-Icon & App-Icon (Sektion 01)

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅, Runde 39).

1. Spinner-Ring und pulsierender „Neu erkannt"-Punkt: **Grün** statt Blau (`MenuBarStatusBadgeView`, `IndexingSpinnerRing`).
2. **Das Layout liefert jetzt die exakte Badge-Logik** — damit ist Aufgabe 18 Punkt A (Badge ist tot) konkret umsetzbar. Den Badge aus dem echten Zustand ableiten statt aus dem Debug-Feld `menuBarBadgePreview`:
   - **Wird indiziert:** solange für mindestens ein angeschlossenes Medium eine Erst- oder Neu-Indizierung läuft.
   - **Neu erkannt:** solange der Erkennungs-Dialog (02) auf eine Antwort wartet (`newMediumDialogMediumID != nil`) — verschwindet, sobald „Indizieren" oder „Nicht indizieren" gewählt wurde.
   - **Pausiert:** Überwachung für ein Medium oder global manuell angehalten.
   - **Fehler:** Indizierung eines Mediums fehlgeschlagen. **Neu:** Klick auf das Menüleisten-Icon führt dann direkt zum betroffenen Medium.
   - **Kein Badge:** alle angeschlossenen Medien online und vollständig indiziert.
   Prioritätsreihenfolge bei mehreren gleichzeitigen Zuständen ist im Layout nicht festgelegt — Vorschlag: Fehler > Neu erkannt > Wird indiziert > Pausiert; bitte als offene Frage im Status vermerken, falls anders sinnvoll.
3. **App-Icon (Dock) laut Mockup:** abgerundetes Quadrat (Radius wie `--radius-lg` im Verhältnis 14/72), Hintergrund **Verlauf 160° von `#2B2B2D` nach `#201E1D`**, Glyph in **`#F2F2F2`** (nicht reines Weiß), Glyph-Größe ≈ 53 % der Kantenlänge (38/72). Ersetzt die bisherige Spec in Aufgabe 17 (opak schwarz + weiß). `Scripts/GenerateAppIcons.swift` entsprechend anpassen (inkl. des dort noch offenen Tint-Bugs aus Runde 36).

**Review-Fix (Cursor, Runde 39):** Badge-Logik in `AppState.effectiveMenuBarBadge` (Fehler → `newMediumDialogMediumID` → indizierendes angeschlossenes Medium → global/`autoIndexPaused` pausiert → idle); `menuBarErrorMediumID`; Linksklick bei Fehler-Badge öffnet Spaltenansicht für betroffenes Medium statt Popover. Beobachtung inkl. `newMediumDialogMediumID`. Fehler-„!" in `DesignColor.stateError`. AppIcon: Gradient + Squircle-Radius 14/72, Glyph `#F2F2F2` per `sourceIn`, 38/72 — PNGs neu. Prioritätsreihenfolge wie Vorschlag im Spec; bei Bedarf Produktentscheidung. `AppState.swift`, `MenuBarController.swift`, `MenuBarStatusBadgeView.swift`, `Scripts/GenerateAppIcons.swift`, `AppIcon.appiconset`. `xcodebuild` ✅.

### 19.4 Erkennungs-Dialog (Sektion 02)
„Indizieren" = Primär-Button Schwarz (bisher Blau); Checkbox schwarz. Text im Dialog unverändert. Konzeptuell: die gemerkte Entscheidung ist später unter **Einstellungen → Speichermedien** (05) änderbar.

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅, Runde 39 Fortsetzung) — Primär „Indizieren“ via `PrimaryAccentButtonStyle`/`DesignColor.control` (19.1); Toggle „Für dieses Medium merken“ mit `.tint(DesignColor.control)`. `NewMediumDetectedDialog.swift`.

### 19.5 Popover (Sektion 03)
1. **Status-Chip nur noch während der Indizierung** (mit Spinner). Kein Chip = online und vollständig indiziert. Fehler/Ausstehend/Nicht erlaubt bekommen im Popover **keinen** Chip mehr ([MenuBarConnectedMediumRow.swift](diskindex/diskindex/MenuBar/MenuBarConnectedMediumRow.swift), `shouldShowChip`).
2. Untertitel eines fertigen Mediums: **„Zuletzt indiziert: heute, 09:14"** (Datum/Uhrzeit aus dem Modell) statt „Index aktuell".
3. Indizier-Fortschrittsbalken Schwarz, Spinner Grün, %/absolut-Wert mit **gestrichelter** Unterstreichung (bisher gepunktet).
4. An/Pausiert-Gruppe: „An" Schwarz.
5. Button unter den Suchergebnissen: **„Alle N Ergebnisse anzeigen"** mit tatsächlicher Trefferzahl (Entscheidung Nutzer 28.09., hebt „Ergebnisse anzeigen" vom 21.09. auf).
6. Suchergebnis-Zeilen im Popover: Hover = dezente graue Hinterlegung der ganzen Zeile; Rechtsklick öffnet das Kontextmenü (19.13).

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅, Runde 39 Fortsetzung) — Popover-Zeile ohne `StatusChip` außer Indizier-UI (Fortschrittsbalken + Spinner/% rechts, gestrichelte Unterstreichung); Untertitel indiziert via `IndexedDateFormatting` + `firstIndexedAt`/`lastSeenAt`. Button „Alle 9 Ergebnisse anzeigen“ (`PopoverSearchMock.totalResultCount`). Suche: Hover-Zeile + Kontextmenü (19.13). An/Pausiert unverändert schwarz über `BinaryButtonGroup` (19.2). Dateien: `MenuBarConnectedMediumRow.swift`, `MenuBarPopoverSearchContent.swift`, `IndexedDateFormatting.swift`.

### 19.6 Dashboard (Sektion 04)
1. **Füllstands-Farbverlauf entfällt komplett** — kein Balken mehr auf den Karten. `StorageFillGradientBar`, `StorageErrorBar`, `StorageEmptyTrack` aus `MediumDashboardCard` entfernen; da sie im neuen Layout nirgends mehr vorkommen, die Komponenten danach löschen.
2. **Meta-Zeile zweigeteilt:** links „{Wert} belegt" (Wert klickbar, %/absolut, **gestrichelt** unterstrichen), rechts „zuletzt gesehen: …" — per `space-between`, nicht mehr mit „ · " verbunden. **Wenn der absolute Wert angezeigt wird, entfällt „zuletzt gesehen"** (Mockup-Logik `showLastSeen = !showAbs`, weil der absolute Wert mehr Platz braucht).
3. Chips nach 19.2; Fehler-Karte Rand `#E04830`; Offline-Karten weiterhin Deckkraft 0,55.
4. **Favorisierte Medien zeigen ihr Typ-Icon in Violett.**

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅, Runde 39 Fortsetzung) — Füllbalken/`StorageFillGradientBar.swift` entfernt; Meta-Zeile `HStack` mit klickbarem „{Wert} belegt“ (gestrichelt) und „zuletzt gesehen“ (entfällt bei absoluter Anzeige). `Medium.isFavorite` + Mock „Archiv 2019–2021“; `MediumTypeIcon.useFavoriteTint`. Fehler-Rand/offline-Deckkraft unverändert; Chips via 19.2. `MediumDashboardCard.swift`, `Medium.swift`, `MockData.swift`, `MediumTypeIcon.swift`.

### 19.7 Toolbar aller Hauptfenster-Ansichten ([MainWindowToolbar.swift](diskindex/diskindex/Views/MainWindowToolbar.swift))
Neue Reihenfolge — **links:** Übersicht (Haus) · Favoriten · Einstellungen (Zahnrad); **rechts, direkt vor dem Objekt-Suchfeld:** Filter-Icon · Such-Icon; dann das Suchfeld. Kein Breadcrumb mehr in der Toolbar (der Pfad wandert in die Fußzeile der Spaltenansicht, 19.10).

| Icon | aktiv |
|---|---|
| Übersicht | Schwarz |
| Favoriten | Violett, Duotone |
| Einstellungen | Türkis `#00B5B5` |
| Filter | Blau, solange die Filterleiste offen ist |
| Suche | Blau, solange die Suche aktiv ist |

Inaktiv jeweils Textfarbe. Das Zahnrad öffnet ab jetzt **Einstellungen** (19.8), nicht mehr direkt die Registry. Accessibility-Labels ohne „(aktiv)" (Projektregel `layout/CLAUDE.md`), z. B. einfach „Übersicht".

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅, Runde 39 Fortsetzung) — Toolbar: links Übersicht/Favoriten/Einstellungen (Schwarz/Violett/`settingsActive`), rechts Filter- und Such-Icon (blau bei offener Filterleiste bzw. Suchansicht) + Objektsuchfeld. Zahnrad → `SettingsView`; Favoriten → `FavoritesView` (19.12). `MainWindowScreenScaffold` + `MainWindowFilterBar`; Filter schließen setzt Filter zurück. Spaltenansicht ohne Breadcrumb in der Toolbar (Pfad in Fußzeile 19.10). Such-Icon toggelt Suche inkl. Rücksprung. Legacy-Destination `.registry` → `RegistryView` (Redirect Einstellungen). Offen: Favoriten-Duotone-Asset (19.2/9).

### 19.8 Einstellungen — neue Ansicht (Sektion 05)
Eigene Ansicht im Hauptfenster (kein Modal), Aufruf übers Zahnrad. **Tabs links**, aktiver Tab Schwarz:
1. **Allgemein**
   - **Scan-Tiefe:** Slider 1–5 (Schwarz), „5+" = uneingeschränkt; darunter ein Beispiel-Pfad, der live zeigt, bis zu welcher Ordnerebene erfasst wird (Mockup-Logik: Ebenen „Festplatte → Unterordner 1…n", letzte erfasste Ebene hervorgehoben; bei 5+ „maximale Indextiefe").
   - **Hinweis zu Online-Favoriten:** Checkbox „Mitteilung aktivieren" — wenn ein Medium mit Favoriten angeschlossen wird, erscheint eine macOS-Mitteilung mit Name des Mediums und Anzahl der Favoriten (Beispieltext im Mockup).
   - „Auf Standard zurücksetzen".
2. **Ignorierte Objekte**
   - **Dateien & Ordner ausschließen:** Eingabe + „Hinzufügen"; Einträge als **gelbe Chips** (voll, mit ✕), z. B. `node_modules`, `*.tmp`, `Cache`. Gilt für alle Medien; auch per Rechtsklick hinzufügbar (19.13). Bereits erfasste Treffer bleiben nach dem Hinzufügen **1 Stunde** im Index sichtbar (mit gelbem Prohibit-Icon neben dem Namen), danach automatische Bereinigung; Entfernen des Chips vorher macht es rückgängig.
   - **Unsichtbare Dateien:** Schalter „Ignorieren" (z. B. `.DS_Store`, `.git`).
   - „Erfasste Objekte jetzt bereinigen", „Auf Standard zurücksetzen".
3. **Speichermedien** — die bisherige Registry-Tabelle zieht hierher um (Filter-Chips Alle/Indiziert/Pausiert/Nicht erlaubt; Spalten Name, Typ, Status, Indizieren). Sortierung nach 19.2 Punkt 6 (keine Pfeile). **Letzte Spalte: Detail-Icon statt Chevron** — Klick auf Namen **oder** Detail-Icon öffnet das Detail-Overlay (Entscheidung Nutzer 28.09.; der Chevron zur Spaltenansicht entfällt).

Hinweis Backend: Scan-Tiefe, Ignore-Liste, unsichtbare Dateien und Mitteilungen haben ohne Indexing-Backend noch keine echte Wirkung. Bitte als **UI + Zustand in `AppState`** umsetzen (Mock), so dass ein späteres Backend nur noch darauf zugreifen muss — keine Scheinlogik erfinden.

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅, Runde 39 Fortsetzung) — `SettingsView` mit Sidebar-Tabs (aktiv schwarz); `AppSettings` + `settingsTab` in `AppState`. Allgemein: Scan-Tiefe-Slider 1–5+ schwarz, Beispiel-Pfad, Mitteilungs-Checkbox + Beispiel; Ignorierte Objekte: Eingabe/Hinzufügen, gelbe `IgnoredPatternChip`, unsichtbare Dateien, Bereinigen/Reset (Purge-Hook leer). Speichermedien: `SettingsMediaRegistryPanel` (Registry inkl. Filter/Sort); `RegistryTableRow` Detail-Icon (`info.circle`) statt Chevron → Overlay; Name ebenfalls Details. Legacy `RegistryView` → Tab Speichermedien. Dateien: `AppSettings.swift`, `Settings*.swift`, `IgnoredPatternChip.swift`, `SettingsMediaRegistryPanel.swift`, `RegistryTableRow.swift`, `MediumNavigation.swift`.

### 19.9 Detail-Overlay (Sektion 06)
1. Kennzahlen-Tabelle nur noch: Gesamt, Belegt/Frei, Dateien/Ordner, Zuletzt gesehen — **„Zuerst indiziert" entfällt.**
2. Einstellungszeile „Soll indiziert werden" (Ja/Nein) bleibt als letzte Tabellenzeile.
3. **Aktionen als Button-Zeile unter der Tabelle** statt eigener Tabellenzeilen: links „Vergessen" (Destruktiv, Rot), rechts „Neu indizieren" (Sekundär) und **„Inhalt anzeigen"** (Primär Schwarz, bisher „Index anzeigen").
4. Status-Chip oben rechts = derselbe wie im Dashboard.

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅, Runde 39 Fortsetzung) — Kennzahlen ohne „Zuerst indiziert“; „Soll indiziert werden“ letzte Tabellenzeile; Aktionszeile unten (Vergessen links, Neu indizieren + Primär „Inhalt anzeigen“ rechts). Chip unverändert wie Dashboard. `MediumDetailModalView.swift`.

### 19.10 Spaltenansicht (Sektion 07)
1. **Hover-Finder-Icon entfällt komplett** (Sidebar und Spalten, `ColumnBrowserRow`). „Im Finder anzeigen" gibt es ausschließlich im Kontextmenü (Entscheidung Nutzer 28.09., hebt die README-Entscheidung vom 20.09. auf). Die Fade-Maske für lange Namen bleibt.
2. Aktive Zeile Schwarz `#1F1F1F`.
3. **Fußzeile dreigeteilt:** links „{frei} frei von {gesamt}" in einer Zelle **genau so breit wie die Sidebar (200 pt)**, damit die Mitte bündig mit der ersten Ordnerspalte beginnt; **Mitte: der Pfad** („Archiv 2019–2021 › Projekte › Kunde B › Datei") — bei Überlänge **in der Mitte ausgeblendet** (Anfang und Ende bleiben sichtbar, Übergang per Verlauf; vollständiger Pfad als Tooltip); rechts „N Objekte". Der Breadcrumb in der Toolbar entfällt dafür.
4. **Ordner jenseits der Scan-Tiefe:** Klick öffnet **keine** weitere Spalte; Ordner-Icon in Spalte und Detail **gelb**; Detail-Spalte zeigt Icon, Name und gelb **gestrichelten** Chip „Inhalt nicht erfasst". Die oberste Ebene eines Mediums ist immer erfasst. (Mock: ein Beispielordner in den Mock-Daten reicht.)
5. Favorisierte Ordner/Dateien/Medien mit violettem Icon.

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅, Runde 39 Fortsetzung) — Finder-Hover in `ColumnBrowserRow` entfernt; aktive Zeile `#1F1F1F`. Fußzeile `ColumnBrowserPathFooter`: links 200 pt „frei von gesamt“, Mitte Pfad mit `.truncationMode(.middle)` + Tooltip, rechts Objektzahl. Scan-Tiefe aus `AppSettings`: Ordner jenseits der Tiefe gelbes Icon, Klick ohne neue Spalte, Detail mit gestricheltem Chip „Inhalt nicht erfasst“; Mock „RAW-Export“ unter Archiv › Projekte › Kunde B › Assets. Favoriten: `favoriteIndexedItemIDs` + violette Icons (Medium/Datei-Demo). `ColumnBrowserView.swift`, `ColumnBrowserRow.swift`, `ColumnBrowserState.swift`, `ColumnBrowserMockData.swift`, `AppState.swift`.

### 19.11 Filter & Suche — neues Bedienkonzept (Sektionen 08, 09, 10)
Ersetzt die bisherige Filter-Umsetzung in der Suchansicht.

1. **Filter-Icon** (Toolbar): öffnet/schließt eine **Filterleiste unter der Toolbar — in jeder Ansicht**. Solange offen: Icon blau. **Schließen hebt alle gesetzten Filter auf.**
2. **Such-Icon** (Toolbar): öffnet eine **leere Suche mit geöffneter Filterleiste** (Filter auch ohne Suchbegriff nutzbar). Solange die Suche aktiv ist: Icon blau. **Erneuter Klick beendet die Suche und kehrt zur vorherigen Ansicht zurück.**
3. **Suchfeld:** Tippen wechselt sofort in die Suchansicht (aus jeder Ansicht); die Filterleiste bleibt, wie sie war. **Die Trefferliste aktualisiert sich weiterhin erst mit Enter** (Entscheidung Nutzer 28.09. — bestätigt Aufgabe 13). Das X im Feld löscht nur den Begriff, die Suche bleibt offen.
4. **Geltungsbereich:** In der Suche wirken Filter **global** über alle Medien (Medium-Auswahl verfügbar). Außerhalb der Suche nur im **aktuellen Ordner** — rechts in der Filterleiste steht „In „{Ordner}"", und die Medium-Auswahl im Popover entfällt.
5. **Übergang:** Wechsel aus einem gefilterten Ordner in die Suche übernimmt die gesetzten Filter und wendet sie global an.
6. **Filterleiste:** „Filter"-Button (öffnet das Popover **per Klick**, Entscheidung bestätigt; der Layout-Text ist inzwischen korrigiert) + **ein eigener blauer Chip je gesetztem Wert**, einzeln per ✕ entfernbar (z. B. „Archiv 2019–2021 ✕", „PDF ✕", „Text ✕") — nicht mehr gruppiert wie bisher „Typ: PDF, Text ✕" / „Ort: Alle Medien ✕". Ohne aktiven Filter ist der Button grau.
7. **Gefilterter Ordner (Spaltenansicht, 08):** nur die Spalte des aktuellen Ordners wird gefiltert, übergeordnete Spalten bleiben vollständig; Spaltenkopf „KUNDE B · 1 VON 3", Fußzeile „1 von 3 Objekten".
8. **Filter-Popover (09):**
   - Dateityp (Mehrfachauswahl): **PDF, Text, Dokumente, Bild, Video, Audio, Archiv, Programme, Skripte, Ordner** (bisher 7, neu „Dokumente", „Programme", „Skripte"). Zuordnung laut Sektion 13: Dokumente = Office-Formate (doc/docx, xls/xlsx, ppt/pptx, pages, numbers, key, odt …), Programme = .app/.dmg/.pkg/.exe, Skripte = .html/.css/.js/.php/.py/.sh/.rb/.command ….
   - Medium (nur in der Suche): durchsuchbare Liste, „Alle Medien"; **erst ab 15 Einträgen scrollbar, darunter in voller Höhe** (bisher feste Maximalhöhe 110 pt); Zähler „7 von 22 Medien" (ohne „· scrollt").
   - Alter: **Letzte 24 Stunden, Letzte 2 Tage, Letzte Woche, Letzter Monat, 3 Monate, 6 Monate, 9 Monate, Letztes Jahr, Älter** (bisher 5 Optionen).
   - Alles blau statt violett; jede Auswahl erscheint sofort als Chip in der Filterleiste.
9. **Suchansicht-Zustände (10):** (1) nach Klick aufs Such-Icon: leere Suche, Filterleiste offen, beide Icons blau, statt Liste ein Hinweis auf grauem Grund: „Suchbegriff eingeben oder Filter verwenden" / „Durchsucht alle erfassten Speichermedien – auch offline." — ersetzt den bisherigen Hinweistext aus Aufgabe 7b/Runde 26; (2) Begriff eingegeben (Enter) → Kacheln + Tabelle; (3) gefiltert; (4) keine Treffer. Treffer erscheinen, sobald ein Begriff **oder** ein Filter gesetzt ist.
10. **Klick auf eine Ergebniszeile** öffnet den Treffer in der Spaltenansicht an genau dieser Stelle; Rechtsklick → Kontextmenü. Hover-Finder-Icon in der Tabelle entfällt (wie 19.10).
11. Status-Spalte der Ergebnistabelle: „Online" grün voll / „Offline" grau gestrichelt.

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅, Runde 39 Fortsetzung) — Filterleiste: ein blauer Chip pro Wert (`FilterValueChip` / `MainWindowFilterBar`), Popover blau, 10 Dateitypen + 9 Alter-Optionen; Medium-Block nur in der Suche, Scroll ab 15 Medien. Spaltenansicht: Filter nur in der rechten Ordnerspalte, Kopf „X VON Y“, Fuß „X von Y Objekten“, Scope „In „{Ordner}““. Suche: Idle-Hinweis (10), Treffer bei Enter **oder** sofort bei Filter; Zeilenklick → Spaltenansicht (`MediumNavigation.openSearchResult`), kein Finder-Hover, Status-Chips, Kontextmenü (19.13). `SearchState`, `SearchItemFilter`, `SearchMockResults`, `SearchFilterPopover`, `SearchView`, `ColumnBrowserView`, `AppState`. Offen für Feinschliff: gefilterter Ordner mit Spaltenkopf-Mock „1 VON 3“ exakt wie Layout 08.

### 19.12 Favoriten — neue Ansicht (Sektion 11)
Aufruf übers Favoriten-Icon (dann violett). Aufbau wie die Suche: oben favorisierte **Speichermedien als Kacheln**, darunter favorisierte **Objekte** als Tabelle. Statt Filterleiste eine Chip-Leiste **„Alle / Online / Offline"**, aktiver Chip blau. Alle Icons favorisierter Objekte violett. Rechtsklick auf Einträge → Kontextmenü. Zustand: Favoriten-Markierung pro Objekt/Medium in `AppState` (Mock), sodass sie in Spaltenansicht, Suche, Dashboard und Favoriten konsistent erscheint.

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅) — `FavoritesView`: Kacheln (`SearchCompactMediumCard`) + Objekt-Tabelle wie Suche; Chip-Leiste Alle/Online/Offline (blau aktiv); keine Filterleiste in Favoriten (`MainWindowScreenScaffold`). `FavoritesCatalog`, `favoritesConnectionFilter` in `AppState`; Zeilenklick → Spaltenansicht (`MediumNavigation.openFavoriteObject`); Kontextmenü. Status-Spalte via `ObjectRowOnlineStatusChip`. Mock-Objekte an `favoriteIndexedItemIDs` angebunden.

### 19.13 Kontextmenü an Ordnern & Dateien — neu (Sektion 12)
Rechtsklick auf jedes Objekt in Spaltenansicht, Suche, Favoriten (und in den Popover-Suchergebnissen). **Einziger Weg zu „Im Finder anzeigen".** Vier Gruppen mit Trennern:
1. **Im Finder anzeigen** — öffnet ein Finder-Fenster und markiert das Objekt; nur wenn das Medium angeschlossen ist, sonst ausgegraut.
2. **Als Favorit markieren** — setzt/entfernt den Favoriten, aktiv mit **violettem Häkchen**.
3. **Nach Namen suchen** (öffnet die Suche mit exaktem Namen) · **Nach Dateiendung suchen** (öffnet die Suche mit z. B. „.pdf"; bei Ordnern ausgegraut).
4. **Dateinamen ignorieren** · **Dateitypen ignorieren** (setzt „*.log" o. ä. auf die Ignore-Liste; bei Ordnern ausgegraut). Aktiv mit **rotem Häkchen**, bleibt 1 Stunde rot markiert und per erneutem Klick aufhebbar, danach automatische Bereinigung; betroffene Objekte zeigen bis dahin ein gelbes Prohibit-Icon neben dem Namen.

Regeln: Nicht verfügbare Einträge **ausgegraut statt ausgeblendet** (Menüstruktur bleibt immer gleich). Das angeklickte Objekt erhält einen **schwarzen Rahmen**, solange das Menü offen ist. Menüfläche weiß.

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅) — `ObjectFileContextMenu` + `ObjectContextTarget`; Modifier `objectContextMenu` (Rechtsklick-Highlight schwarzer Rand, Finder/Favorit/Suche/Ignore). Angebunden: Spaltenansicht (`ColumnBrowserRow`), `SearchView`, `FavoritesView`, Popover-Suche. Dateiendung/Dateityp ignorieren nur bei `.file` aktiv (Ordner/Medium ausgegraut). Popover-Treffer: IDs über `SearchMockResults.knownItemID` wo möglich (Favorit konsistent). Ignore-Normalisierung vereinheitlicht in `AppState`. „Im Finder anzeigen“ ohne Finder-Aktion (Stub). Prohibit-Icon/1 h-Bereinigung UI offen.

### 19.14 Aufräumen im Zuge des Umbaus
- `StorageFillGradientBar.swift` (inkl. `StorageErrorBar`, `StorageEmptyTrack`) löschen, sobald 19.6 umgesetzt ist — im neuen Layout nirgends mehr verwendet.
- `VioletFilterChip` durch einen blauen Filter-Chip ersetzen bzw. umbenennen.
- Die offenen Punkte aus Aufgabe 18 (A Badge, B–D Performance, E toter Code, F `ForEach`-Range, I redundantes `capacityUsedPercent`) gelten weiter; A ist durch 19.3 jetzt präzise spezifiziert.
- Mock-Daten **nicht** löschen, nur erweitern (Favoriten, ein Ordner jenseits der Scan-Tiefe, ein ignorierter Eintrag, Datums-/Uhrzeitangaben für „Zuletzt indiziert").

**Status:** ✅ Erledigt durch Cursor (`xcodebuild` ✅) — `StorageFillGradientBar`/`VioletFilterChip`/`ObjectContextMenu`-Platzhalter entfernt; `FilterValueChip` (blau) in `MainWindowFilterBar`. Doppelte Online/Offline-Chips in Suche/Favoriten → `ObjectRowOnlineStatusChip`. Dashboard-Kontextmenü: „Inhalt anzeigen“ statt „Index anzeigen“. Favoriten-Mock in `FavoritesCatalog`. Legacy `RegistryView` bleibt als Redirect zu Einstellungen → Speichermedien (kein toter Pfad). Offen: Aufgabe-18 B–I; Prohibit-Icon.

---

### Review (Claude, 28.09., Runde 40) — Code-Prüfung von Aufgabe 19

**Status Aufgabe 19:** ⚠️ Größtenteils korrekt, **10 Nacharbeiten** (unten). Geprüft wurde der tatsächliche Code, nicht nur die Status-Einträge.

**Verifiziert korrekt ✅:** 19.1 alle acht Rollenfarben hex-genau, keine Alt-Tokens mehr · 19.2 Chip-Labels/-Logik, Selectgroup, Spinner grün, Balken schwarz, keine Sortierpfeile, X-Reset in allen drei Suchfeldern · 19.3 Badge aus echtem Zustand abgeleitet, altes Debug-Feld entfernt, Beobachtung vollständig, Fehler-Klick führt zum Medium; App-Icon mit abgerundeten Ecken, Glyph `#F2F2F2`, 53 % · 19.4 · 19.5 Chip nur bei Indizierung, gestrichelte Unterstreichung · 19.6 Balken entfernt, Meta-Zeile zweigeteilt inkl. Ausblenden von „zuletzt gesehen" bei absoluter Anzeige, Favoriten-Tint · 19.7 Reihenfolge und Aktivfarben der fünf Toolbar-Icons, Labels ohne „(aktiv)" · 19.8 Tabs, Slider, Mitteilung, Ignore-Chips, unsichtbare Dateien · 19.9 · 19.10 Finder-Hover entfernt, Fußzeile dreigeteilt mit 200-pt-Zelle und Tooltip, Scan-Tiefe-Ordner gelb mit Chip · 19.11 Filterleiste, Scope „In „…"", ein Chip je Wert, 10 Dateitypen und 9 Altersbereiche wirken echt (zentral in `SearchItemFilter`), Medium-Liste ab 15 scrollbar, Leerzustand-Text, Zeilenklick → Spaltenansicht · 19.12 · 19.14.

**Aufgabe 18 ist damit komplett erledigt** — entgegen dem Status-Eintrag „B–I offen" sind im Code umgesetzt: B (Namens-Dictionary statt Lookup im Comparator), C (weniger Mehrfachberechnung), D (`selectedMedium` wird als Parameter durchgereicht), E (alle sechs toten Dateien gelöscht), F (kein `ForEach` über Integer-Range mehr), G/H (zentraler Fokus-Monitor mit Fensterprüfung), I (`capacityUsedPercent` jetzt berechnet). A durch 19.3.

**Nacharbeiten (Reihenfolge = Priorität):**

1. **Suche übernimmt beim Wechsel per Tippen den ersten Buchstaben als Suchbegriff.** Tippt man z. B. im Dashboard „r", wechselt die App in die Suche ([DashboardView.swift:42-44](diskindex/diskindex/Views/Dashboard/DashboardView.swift:42)); dort übernimmt `syncSubmittedQueryIfNeeded()` in `onAppear`/`onChange(of: mainWindowDestination)` ([SearchView.swift:71-86](diskindex/diskindex/Views/Search/SearchView.swift:71)) diesen einen Buchstaben sofort als abgeschickten Begriff — es erscheinen Treffer für „r", alle weiteren Tastendrücke werden bis Enter ignoriert. Soll laut Entscheidung 28.09.: Tippen wechselt in die Suche, **Treffer erst bei Enter**. Die automatische Übernahme ist nur für Fälle gedacht, in denen ein vollständiger Begriff programmatisch gesetzt wird (`openSearch(withQuery:)` aus dem Kontextmenü „Nach Namen/Dateiendung suchen", Popover-Button). Fix: z. B. ein Feld `pendingSubmittedSearchQuery: String?` in `AppState`, das nur `openSearch(withQuery:)` setzt und `SearchView` beim Erscheinen einmalig übernimmt und leert; der Tipp-Wechsel setzt es nicht.
2. **Favoriten: Tippen wechselt nicht in die Suche.** In Dashboard, Spaltenansicht und Einstellungen gibt es `onChange(of: searchState.query)` → Suche, in [FavoritesView.swift](diskindex/diskindex/Views/Favorites/FavoritesView.swift) nur `onSubmit`. Bitte angleichen.
3. **„Alle 9 Ergebnisse anzeigen" ist fest verdrahtet.** [PopoverSearchMock.swift:22](diskindex/diskindex/Models/PopoverSearchMock.swift:22) `static let totalResultCount = 9` — die Zahl passt nie zur tatsächlichen Trefferzahl, und die Suchansicht zeigt nach dem Klick eine andere Anzahl. Fix: Zahl aus demselben Matching berechnen, das die Suchansicht für diesen Begriff verwendet (Medien + Objekte).
4. **„Zuletzt indiziert" zeigt das Datum der ersten Indizierung.** [MenuBarConnectedMediumRow.swift:89](diskindex/diskindex/MenuBar/MenuBarConnectedMediumRow.swift:89) nutzt `firstIndexedAt ?? lastSeenAt`; das Modell hat kein Feld für den letzten Indizierungslauf. Fix: `lastIndexedAt: Date?` in `Medium` ergänzen (wird auch vom späteren Backend gebraucht), in den Mock-Daten füllen, dort verwenden. `firstIndexedAt` nicht löschen.
5. **Alle Chip-Ränder zu blass.** `DesignColor.chipBorder(_:)` liefert `role.opacity(0.72)` — das ist heller, nicht dunkler (entgegen dem eigenen Kommentar), und das Mockup nutzt für Chip-Ränder exakt die Basisfarbe. Betrifft neun Stellen (`StatusChip`, `FilterValueChip`, `IgnoredPatternChip`, `ObjectRowOnlineStatusChip`, `UncapturedFolderDetailChip`, Favoriten-Chips, Filter-Popover, Detail-Overlay). Fix: `chipBorder` gibt die Basisfarbe unverändert zurück.
6. **Favoriten-Icon in der Toolbar hat das falsche Motiv.** [MainWindowToolbar.swift:61](diskindex/diskindex/Views/MainWindowToolbar.swift:61) nutzt SF Symbol `books.vertical` (Bücherregal). Laut Styleguide: Phosphor **`bookmarks-simple`** (zwei Lesezeichen), inaktiv als Kontur in Textfarbe, aktiv **Duotone in Violett**. Das ist das prominenteste Element aus dem zurückgestellten 19.2 Punkt 9 — bitte jetzt, zusammen mit dem Einzel-Lesezeichen „Favorit" für Objekte.
7. **Detail-Icon in Einstellungen → Speichermedien hat das falsche Motiv.** [RegistryTableRow.swift:45](diskindex/diskindex/Views/Registry/RegistryTableRow.swift:45) nutzt `info.circle`; das Mockup verwendet Phosphor **`sliders-horizontal`** (im Styleguide „Details/Regler").
8. **App-Icon-Verlauf steht auf dem Kopf.** Per Pixel geprüft: oben `#222020` (dunkler), unten `#29282A` (heller). Mockup: `linear-gradient(160deg, #2B2B2D, #201E1D)` = oben der **hellere** Ton. Ursache vermutlich die in AppKit von unten gezählte y-Achse. In `Scripts/GenerateAppIcons.swift` Start- und Endfarbe tauschen bzw. den Winkel spiegeln, Icons neu erzeugen.
9. **Inaktive Tabellenköpfe sind `.semibold`, aktive `.bold`** ([SearchView.swift:187](diskindex/diskindex/Views/Search/SearchView.swift:187), [SettingsMediaRegistryPanel.swift:100](diskindex/diskindex/Views/Settings/SettingsMediaRegistryPanel.swift:100)) — der Unterschied ist kaum sichtbar. Laut Tabellen-Regel erkennt man die aktive Spalte *allein* an schwarz + fett; inaktive bitte `.regular` und gedämpft.
10. **Kontextmenü bitte visuell prüfen** ([ObjectFileContextMenu.swift](diskindex/diskindex/DesignSystem/ObjectFileContextMenu.swift)): Das Menü läuft über SwiftUI `.contextMenu` = natives macOS-Menü. Dort werden eigene Farben und `HStack`/`Spacer`-Layouts in Einträgen üblicherweise ignoriert — die violetten/roten Häkchen erscheinen dann einfarbig und evtl. links statt rechts. Außerdem hängt der schwarze Rahmen am angeklickten Objekt an `onAppear`/`onDisappear` des Menüinhalts, das auf macOS nicht garantiert beim Öffnen/Schließen feuert. Falls eins davon nicht funktioniert: bitte melden statt nachzubauen — dann entscheidet der Nutzer, ob native Häkchen in Systemfarbe reichen oder ein eigenes Menü nötig ist.

**Bekannte, bewusst offene Punkte (keine Nacharbeit jetzt):** „Im Finder anzeigen" ohne Aktion (braucht echte Pfade vom Backend; mit Mock-Pfaden würde `NSWorkspace.activateFileViewerSelecting` ins Leere laufen) · gelbes Prohibit-Icon und 1-Stunden-Bereinigung (Backend) · erweiterte `ph-file-*`-Dateityp-Icons (19.2 Punkt 10) · Fußzeilen-Pfad kürzt mit „…" statt Verlauf und trennt mit „›" statt Caret-Icon (vertretbare Annäherung).

**Merkposten fürs spätere Backend:** `.app`-Programme sind auf macOS Ordner-Bundles; `SearchFileTypeFilter.matches` behandelt Ordner aber immer nur als „Ordner" — der Filter „Programme" würde echte Apps so nie finden.

**Offene Frage an den Nutzer:** Beim Verlassen der Suche über das Such-Icon bleibt die Filterleiste offen, samt global gesetzter Filter (inkl. Medium-Auswahl), die dann im Ordner-Kontext weiterwirken. Soll die Filterleiste beim Verlassen der Suche geschlossen/zurückgesetzt werden?

---

## Offene Produktentscheidungen (für Claude/Nutzer, nicht für Cursor zu entscheiden)
- ~~`showAbs` global vs. per Medium~~ → **Entschieden (Nutzer, 21.09.): pro Medium**, nicht mehr global. Siehe Aufgabe 14, Punkt 5 für den konkreten Fix.
- Reales Disk-Scanning/Indexing-Backend ist außerhalb dieses Design-Specs — wird separat spezifiziert, sobald UI steht.


---

# Nachtrag 29.09. — Aufgabe 20 (erledigt)

**Freigabe (Claude, 29.09.):** Alle zehn Punkte im Code verifiziert, Build mit Xcode 26.3 erfolgreich. 20.7: Das Mockup widerspricht sich (Styleguide `faders-horizontal`, Tabellen-Icon `sliders-horizontal`); Umsetzung folgt dem verbindlichen Styleguide. 20.10 → Nutzerentscheidung 29.09.: eigenes Menü nach Layout (Aufgabe 21.1).

## 20. Nacharbeiten zur Layout-Revision

**Status:** Erledigt durch Claude (28.09., im Auftrag des Nutzers statt Cursor). `xcodebuild` ✅, 0 Warnungen; App startet ohne Absturz. **Nicht per Klick/Screenshot getestet**, nur Code, Build, Start und Icon-Pixel.

- **20.1 + 20.2:** Umgesetzt anders als im Fix-Vorschlag. Die Toolbar mit Objekt-Suchfeld liegt jetzt **einmal** in `MainWindowHostView` (über `MainWindowScreenScaffold`) statt in jedem Screen. Das Feld wird beim Wechsel in die Suche nicht neu erzeugt, Fokus und Cursor bleiben erhalten. Neu: `SearchState.submittedQuery`. `AppState.beginSearchFromTyping()` (Tippen → Suche, Treffer leer bis Enter), `submitObjectSearch()` (Enter), `openSearch(withQuery:)` (Kontextmenü/Popover, sofort abgeschickt). Das `onChange(query)` gibt es nur noch zentral, gilt damit auch für Favoriten. `syncSubmittedQueryIfNeeded` ist entfernt.
- **20.3:** Zahl kommt aus `SearchIndex.matching` (identisch zur Suchansicht, gleiche Filter). Popover-Treffer sind jetzt echte Treffer (max. 3 je Gruppe), klickbar (→ Spaltenansicht). Bei 0 Treffern steht „Keine Treffer für …“.
- **20.4:** `Medium.lastIndexedAt` ergänzt, Mock-Daten gefüllt, im Popover verwendet. `firstIndexedAt` bleibt.
- **20.5:** `chipBorder` gibt die Basisfarbe zurück.
- **20.6:** Phosphor-Assets `NavBookmarks` / `NavBookmarksDuotone` (Toolbar, inaktiv Kontur, aktiv Duotone violett) und `IconBookmarkSimple(Duotone)`. Die Einstellungen-Mitteilungsvorschau nutzt Duotone violett. Im Kontextmenü habe ich das Lesezeichen **nicht** eingebaut, das hängt an der Entscheidung zu 20.10.
- **20.7:** Asset `IconFadersHorizontal`. Achtung: Das Mockup/der Styleguide nutzt `ph-faders-horizontal` („Details/Regler“), nicht `sliders-horizontal`. Übernommen wie im Mockup.
- **20.8:** Verlauf korrigiert (y-Achse gespiegelt, CSS-Gradientlänge). Gerendert wird jetzt im sRGB-`CGContext`. Pixel roh: oben `#29292A`, unten `#222020`. **Zusätzlicher Bug behoben:** Das `sourceIn` füllte bisher das **ganze Glyph-Rechteck** weiß (17956/17956 Pixel hell), es war also ein weißes Quadrat statt des Glyphs. Jetzt wird das Glyph auf einer eigenen Ebene eingefärbt.
- **20.9:** Neue gemeinsame `TableSortHeader`-Komponente: aktiv schwarz + fett, inaktiv regular + gedämpft. Genutzt in Suche und Speichermedien, der Favoriten-Kopf nutzt dieselbe Optik.
- **20.10 (nur Analyse, nichts nachgebaut):** Aus dem Code ist das Ergebnis vorhersagbar, visuell ist es noch nicht bestätigt. SwiftUI-`.contextMenu` wird auf macOS zu einem nativen `NSMenu`. Dabei wird aus `HStack { Text; Spacer; Image(checkmark) }` ein Menüeintrag mit Titel und **links** stehendem Bild; `Spacer` und `foregroundStyle` werden ignoriert. Die Häkchen erscheinen also links und einfarbig in Menü-Textfarbe, nicht violett/rot rechts. `onAppear` des Menüinhalts feuert beim Aufbau des Menüs, `onDisappear` beim Schließen nicht zuverlässig. Der schwarze Markierungsrahmen kann deshalb stehen bleiben, bis man ein anderes Objekt anklickt; das Zurücksetzen beim Klick ist vorhanden. **Entscheidung Nutzer:** Reichen native Häkchen in Systemfarbe, oder soll ein eigenes Menü (NSMenu mit eigenen Views bzw. ein eigenes Popover) gebaut werden?

**Zusätzlich — Code-Review Redundanz/Performance/Qualität:**
- Ein einziger Mock-Index `Models/MockIndex.swift` (Baum pro Medium, gecacht, SHA256-basierte stabile IDs statt Byte-Summen-Hash) für Spaltenansicht, Suche, Favoriten und Popover. Er ersetzt `ColumnBrowserMockData`, `SearchMockResults` (inkl. „rechnung“-Sonderfall), `FavoritesCatalog`, `PopoverSearchMock`, `SearchItemFilter` (doppelte Filterlogik) und die hart codierten `B1000001-…`-UUIDs. Neu dazu: `Models/SearchIndex.swift`, `Models/PopoverSearch.swift`. Online-Status in Suche/Favoriten kommt jetzt live aus dem Medium statt aus festen Mock-Werten.
- Eine gemeinsame Objekt-Tabelle `Views/Search/ObjectResultsTable.swift` für Suche und Favoriten (vorher zwei Kopien). `MediumNavigation.openObject` ersetzt die zwei doppelten `open…`-Funktionen. Ordner werden dabei geöffnet, Ordner jenseits der Scan-Tiefe als „nicht erfasst“ markiert.
- **Bug:** Die Spaltenansicht löschte in `onAppear`/`onChange(selectedMediumID)` die Datei-Vorauswahl. Dadurch war die Datei beim Öffnen aus Suche/Favoriten nie markiert. Behoben.
- **Bug:** Filterleisten-Chips zeigten zwei „X“ (Text „✕“ plus X-Button). Behoben.
- **Bug:** Das „Neues Medium“-Panel öffnete nur, wenn gerade das Menüleisten-Popover offen war. Jetzt beobachtet `MenuBarController` das zentral. Das Panel ist nicht-aktivierend und `hidesOnDeactivate = false`. Schließen per ✕ = später entscheiden (Badge verschwindet).
- **Bug:** Das „Ignorieren“-Häkchen im Kontextmenü lief über ein eigenes Set, das nicht mitbekam, wenn ein Chip in den Einstellungen entfernt wurde. Es leitet sich jetzt direkt aus `excludedPatterns` ab.
- Pointer-Cursor über `pointerStyle(.link)` / `.columnResize` (macOS 15) statt `NSCursor.push/pop`. Damit bleibt kein Cursor mehr hängen, wenn eine View unter der Maus verschwindet. Außerdem fehlende `pointerCursor()` an mehreren Buttons ergänzt.
- `AppWindowPresenter`: nur noch starke Referenzen statt der Suche über `NSApp.windows`-Identifier, die geschlossene Fenster wiederfinden konnte. Der `storage`-Parameter ist raus.
- `AppState.updateMedium(id:_:)` / `reindexMedium` ersetzen fünf Kopien von „holen, ändern, zurückschreiben“. Das `liveMedium` in Karte und Popover-Zeile war doppelt und ist entfernt.
- Kompakte Medium-Karten (Suche/Favoriten) sind jetzt klickbar und haben ein Kontextmenü. Objekt- und Spaltenzeilen nutzen die Phosphor-`FileType*`-Assets statt SF Symbols.
- Kleinkram: `AppSettings`-Defaults ohne Duplikat, `SettingsSectionTitle`/`settingsExampleBox()` geteilt, toter Code entfernt (`dashboardMetaLine`, `firstIndexedLabel`, `DesignTypography`, `MockData.registry`, unerreichbare Sortierspalten), Swift-6-Warnungen im `MenuBarController` behoben.

**Bitte manuell löschen** (tot, das Löschen wurde in meiner Sitzung blockiert): `Views/MainWindowIdentifierSetter.swift`, `Views/ColumnBrowser/ColumnBrowserBreadcrumb.swift`, `MenuBar/MenuBarStatusIconView.swift` (nur Previews). Nach einem Mini-Umbau ebenfalls entbehrlich: `App/AppWindowID.swift`, `MenuBar/NewMediumDialogPresenter.swift` (`NewMediumDialogWindowHost` vorher in `NewMediumDetectedDialog.swift` verschieben), `MenuBar/MenuBarRootView.swift` (Controller hostet dann direkt `MenuBarPopoverView`), `Views/Registry/RegistryView.swift` + `MainWindowDestination.registry`, `Notification.Name.openMainWindowRequest`.

Reihenfolge = Priorität.

### 20.1 Suche übernimmt beim Wechsel per Tippen den ersten Buchstaben
Tippt man z. B. im Dashboard „r", wechselt die App in die Suche ([DashboardView.swift:42-44](diskindex/diskindex/Views/Dashboard/DashboardView.swift:42)). Dort übernimmt `syncSubmittedQueryIfNeeded()` in `onAppear`/`onChange(of: mainWindowDestination)` ([SearchView.swift:71-86](diskindex/diskindex/Views/Search/SearchView.swift:71)) diesen einen Buchstaben sofort als abgeschickten Suchbegriff — es erscheinen Treffer für „r", alle weiteren Tastendrücke werden bis Enter ignoriert.

**Soll:** Tippen wechselt sofort in die Suche, **Treffer erst bei Enter**. Automatisch abgeschickt wird ein Begriff nur, wenn er vollständig programmatisch gesetzt wird: `openSearch(withQuery:)` aus dem Kontextmenü („Nach Namen suchen", „Nach Dateiendung suchen") und der Popover-Button „Alle N Ergebnisse anzeigen".

**Fix-Vorschlag:** Feld `pendingSubmittedSearchQuery: String?` in `AppState`, das nur `openSearch(withQuery:)` setzt; `SearchView` übernimmt es beim Erscheinen einmalig als `submittedQuery` und leert es. Der Tipp-Wechsel setzt es nicht.

### 20.2 Favoriten: Tippen ins Suchfeld wechselt nicht in die Suche
Dashboard, Spaltenansicht und Einstellungen haben `onChange(of: searchState.query)` → Wechsel in die Suche; [FavoritesView.swift](diskindex/diskindex/Views/Favorites/FavoritesView.swift) reagiert nur auf `onSubmit`. Bitte angleichen.

### 20.3 „Alle 9 Ergebnisse anzeigen" ist fest verdrahtet
[PopoverSearchMock.swift:22](diskindex/diskindex/Models/PopoverSearchMock.swift:22): `static let totalResultCount = 9`. Die Zahl passt nie zur tatsächlichen Trefferzahl, und die Suchansicht zeigt nach dem Klick eine andere Anzahl. **Fix:** Zahl aus demselben Matching berechnen, das die Suchansicht für diesen Begriff verwendet (Medien + Objekte).

### 20.4 „Zuletzt indiziert" zeigt das Datum der ersten Indizierung
[MenuBarConnectedMediumRow.swift:89](diskindex/diskindex/MenuBar/MenuBarConnectedMediumRow.swift:89) nutzt `firstIndexedAt ?? lastSeenAt` — das Modell hat kein Feld für den letzten Indizierungslauf. **Fix:** `lastIndexedAt: Date?` in `Medium` ergänzen (braucht später auch das Backend), in den Mock-Daten füllen, hier verwenden. `firstIndexedAt` **nicht** löschen.

### 20.5 Alle Chip-Ränder zu blass
`DesignColor.chipBorder(_:)` in [DesignTokens.swift](diskindex/diskindex/DesignSystem/DesignTokens.swift) liefert `role.opacity(0.72)` — das ist heller, nicht dunkler (entgegen dem eigenen Kommentar). Laut Mockup ist der Chip-Rand exakt die Basisfarbe. Betrifft neun Stellen (`StatusChip`, `FilterValueChip`, `IgnoredPatternChip`, `ObjectRowOnlineStatusChip`, `UncapturedFolderDetailChip`, Favoriten-Chips, Filter-Popover, Detail-Overlay). **Fix:** `chipBorder` gibt die Basisfarbe unverändert zurück.

### 20.6 Favoriten-Icons mit falschem Motiv
[MainWindowToolbar.swift:61](diskindex/diskindex/Views/MainWindowToolbar.swift:61) nutzt SF Symbol `books.vertical` (Bücherregal). Laut Styleguide (Sektion 13 „Favoriten"): Phosphor **`bookmarks-simple`** (zwei Lesezeichen) für die Navigation, **einzelnes Lesezeichen** für den Favoriten am Objekt. Inaktiv als Kontur in Textfarbe, aktiv als **Duotone in Violett** (`DesignColor.favorite`, Fläche transparent wie bei Chips) — nie Blau.

### 20.7 Detail-Icon in Einstellungen → Speichermedien mit falschem Motiv
[RegistryTableRow.swift:45](diskindex/diskindex/Views/Registry/RegistryTableRow.swift:45) nutzt `info.circle`. Das Mockup verwendet Phosphor **`sliders-horizontal`** (im Styleguide „Details/Regler").

### 20.8 App-Icon-Verlauf steht auf dem Kopf
Per Pixel geprüft: oben `#222020` (dunkler), unten `#29282A` (heller). Mockup: `linear-gradient(160deg, #2B2B2D, #201E1D)` = oben der **hellere** Ton. Ursache vermutlich die in AppKit von unten gezählte y-Achse. In [Scripts/GenerateAppIcons.swift](diskindex/Scripts/GenerateAppIcons.swift) Start- und Endfarbe tauschen bzw. Winkel spiegeln, Icons neu erzeugen und per Pixel prüfen.

### 20.9 Aktive und inaktive Tabellenköpfe kaum unterscheidbar
Inaktiv `.semibold`, aktiv `.bold` ([SearchView.swift:187](diskindex/diskindex/Views/Search/SearchView.swift:187), [SettingsMediaRegistryPanel.swift:100](diskindex/diskindex/Views/Settings/SettingsMediaRegistryPanel.swift:100)). Laut Tabellen-Regel erkennt man die sortierte Spalte allein an schwarz + fett — inaktive Köpfe bitte `.regular` und gedämpft.

### 20.10 Kontextmenü visuell prüfen
[ObjectFileContextMenu.swift](diskindex/diskindex/DesignSystem/ObjectFileContextMenu.swift) läuft über SwiftUI `.contextMenu` = natives macOS-Menü. Dort werden eigene Farben und `HStack`/`Spacer` in Einträgen meist ignoriert — die violetten (Favorit) und roten (Ignorieren) Häkchen erscheinen dann evtl. einfarbig und links statt rechts. Der schwarze Rahmen am angeklickten Objekt hängt an `onAppear`/`onDisappear` des Menüinhalts, das auf macOS nicht garantiert beim Öffnen/Schließen feuert. **Bitte nur testen und das Ergebnis im Status melden, nichts nachbauen** — ob native Häkchen in Systemfarbe reichen oder ein eigenes Menü nötig ist, entscheidet der Nutzer.


---

# Nachtrag 29.09. — Aufgaben 21, 22 und Review-Korrekturen K1–K4 (Code freigegeben)

Freigabe Claude 29.09.: Code gegen Aufgabe und Layout geprüft, Build ✅, Icon-Generator pixelgleich ✅, K1–K4 umgesetzt. Umsetzung erfolgte durch eine Claude-Sitzung statt Cursor. Klicktest durch den Nutzer steht zum Zeitpunkt der Archivierung noch aus (Checkliste in prompt.md).

## Review Claude 29.09. — Korrekturen zu 21/22

Code gegen Aufgabe und Layout geprüft, Build ✅, Icon-Generator pixelgleich ✅. 22.1–22.13, 21.1 und 21.3 sind im Kern korrekt. Offen bleiben nur diese Kleinigkeiten, danach Klicktest durch den Nutzer:

- **K1 (21.1) Ignorieren aktiv:** Im Layout (Sektion 12, Zustand „Ignorieren aktiv") ist auch das **Prohibit-Icon rot** (#E04830), nicht nur das Häkchen, analog zu Favorit (Icon violett). In `contextMenuGroups` bei `ignoreName`/`ignoreType` `iconColor: … ? DesignColor.stateError : nil` setzen.
- **K2 (21.1) Menüfläche:** Das Briefing sagte „weiß". Das war falsch: Das Layout nutzt `--color-bg`. Also `DesignColor.bg` statt `Color.white`. Schatten wie `--shadow-lg`: y 12, Blur 32 (SwiftUI `radius: 16`), 22 % von #2D2B2B.
- **K3 (22.4) Medium-Auswahl außerhalb der Suche:** `SearchFilters.hasActiveFilters` zählt `!selectAllMedia` mit. In Spaltenansicht und Favoriten wirkt die Medium-Auswahl aber nicht, trotzdem wird dort der Funnel im „Filter"-Button blau und die Favoriten zeigen „Keine Favoriten für die gesetzten Filter". Lösung: eine Variante ohne Medium (z. B. `hasActiveObjectFilters`: Dateityp, Alter, folderOnly) für Spaltenansicht, Favoriten und den Filter-Button außerhalb der Suche verwenden.
- **K4 Toolbar-Icons Filter/Suche:** Das Layout zeichnet sie mit **18 × 18**, wie die Nav-Icons. Der Code nutzt 16 × 16 in `toolIconButton`.

**Status:** Erledigt durch Claude (29.09.). `xcodebuild` ✅ ohne Warnungen, App startet. Nicht durchgeklickt.
- **K1:** `ignoreName`/`ignoreType` bekommen bei aktivem Zustand `iconColor: DesignColor.stateError`, das Prohibit-Icon ist also rot wie das Häkchen. Beim Hover bleibt es weiß auf Schwarz, wie alle Icons.
- **K2:** Menüfläche `DesignColor.bg`, Schatten `DesignColor.neutral900.opacity(0.22)`, `radius: 16`, `y: 12`. Den Außenabstand im Panel (`shadowInset`) habe ich von 16 auf 32 erhöht, damit der größere Schatten nicht abgeschnitten wird. Die Positionierung am Mauszeiger rechnet damit.
- **K3:** Neu `SearchFilters.hasActiveObjectFilters` (Dateityp, Alter, folderOnly). `hasActiveFilters` ist jetzt `!selectAllMedia || hasActiveObjectFilters`. Neu `AppState.hasEffectiveFilters` (Suche: mit Medium, sonst ohne) steuert den Funnel im „Filter“-Button. Spaltenansicht (Filterung, Spaltenkopf „x VON y“) und Favoriten (Leertext) nutzen `hasActiveObjectFilters`. In der Suche bleibt alles wie gehabt.
- **K4:** `toolIconButton` zeichnet 18 × 18.

---

## 22. Fehlerrunde 29.09. (Nutzer-Test) — vor Aufgabe 21 erledigen

**Status:** Erledigt durch Claude (29.09.). `xcodebuild` ✅ ohne Warnungen, App startet ohne Absturz. **Nicht durchgeklickt:** In dieser Sitzung habe ich keine Maus/Tastatur-Steuerung, der geforderte Klicktest inkl. „Scrollbalken immer sichtbar“ steht also noch aus.
- **22.1:** Fehler-Zweig im Linksklick entfernt, `menuBarErrorMediumID` gelöscht. Das Fehler-Badge bleibt.
- **22.2:** `Scripts/GenerateAppIcons.swift` rendert jetzt exakt wie die Referenz (Apple-Raster, Schatten, Endfarbe #1F1F1F, Kopfkommentar aktualisiert). Optionales Argument = Ausgabeordner. Geprüft: In einen Temp-Ordner gerendert und pixelweise mit den PNGs verglichen, **0 abweichende Pixel** (16, 64, 256, 1024 px). Die PNGs habe ich nicht überschrieben. Dock-Sichtprüfung/`killall Dock` steht noch aus.
- **22.3:** `isFilterBarVisible = true` aus `toggleSearchFromToolbar()` und `openSearch(withQuery:)` entfernt. Such- und Filter-Icon sind unabhängig blau. Filter-Icon schließen hebt die Filter wie bisher auf.
- **22.4:** `AppState.isFilterAvailable` / `showsFilterBar`. Das Filter-Icon ist in Übersicht/Einstellungen `.disabled`, `text.opacity(0.3)`, ohne Hand-Cursor, das Label bleibt schlicht „Filter“. Die Leiste wird dort nur ausgeblendet. Die Favoriten-Bedingung im Scaffold ist entfernt. Favoriten filtern ihre Liste nach Dateityp + Alter (`SearchItemFilter.matches`), rechts steht „In Favoriten“. Medium-Chips erscheinen in der Leiste nur in der Suche, weil sie nur dort wirken.
- **22.5:** Den `print`-Befund konnte ich nicht erheben, dafür müsste man klicken. Deshalb direkt robust gelöst: `anchorPreference(key: FilterButtonAnchorKey, value: .bounds)` am Button, `overlayPreferenceValue` im Scaffold. Der alte Frame-Key und der Koordinatenraum sind entfernt. Das Popover liegt mit `zIndex` über allem und schließt per Klick daneben, Escape (neuer Modifier `onEscapeKey`, `DesignSystem/EscapeKeyMonitor.swift`), erneutem Klick auf „Filter“, Ansichtswechsel und wenn die Leiste ausgeblendet wird.
- **22.6:** `onChange(query)` und `beginSearchFromTyping()` entfernt. Nur Enter (`submitObjectSearch`) öffnet die Suche. Das X leert nur den Text.
- **22.7:** `SearchIdlePlaceholder` füllt den ganzen Inhaltsbereich (ohne ScrollView/Kopf), Fläche `text.opacity(0.05)`, Icons `IconMagnifyingGlass` (neues Phosphor-Asset) + `IconFunnel` 40 × 40, Texte wie spezifiziert.
- **22.8:** `ObjectTableColumns` rechnet einmal pro Tabelle per `GeometryReader` (fest 36/110/140/100, Name : Pfad = 1 : 1, Mindestbreiten 160/140). Kopf und Zeilen nutzen dieselben Breiten. Name `.middle`, Pfad `.head`.
- **22.9:** Die Medium-Kacheln umbrechen (`CompactMediumCardFlow`, `FlowLayout` 12, Innenabstand 16, Trennlinie). Karte 190 breit: Icon 20, `StatusChip` rechts, Name 13 semibold. Alle fünf Spaltenköpfe sortieren (`SearchSortColumn.medium/.path` wieder da, Sortierung in `SearchSort.sorted`). Eigene Bäume für „Foto USB“ (Exporte, Fotos/2022–2023, RAW) und „Projekt NVMe“ (Assets, Projekte, Video). Änderungsdaten variieren jetzt (Jahr aus dem Namen, sonst die letzten 60 Tage), damit Alters-Filter unterscheidbare Treffer liefern. RAW-Endungen (nef, cr2, arw, dng) zählen als Bild.
- **22.10:** Zwei Offline-Favoriten auf „Foto USB“: Ordner `Fotos/2023/Hochzeit_Anna` und Datei `Exporte/Portfolio_2023.pdf`. Der Offline-Chip ist grau und gestrichelt (bestehende Tabellenregel).
- **22.11:** Neuer `StepSlider` (`DesignSystem/StepSlider.swift`), selbst gezeichnet: Spur grau, gefüllter Teil + Knopf #1F1F1F, Knopf 16 (r = 8). Labels bei `r + (Breite − 2r) · i/4`, identisch zum Layout-`calc(8px + (100% − 16px) · i/4)`. Knopf und Labels nutzen dieselbe Breite. Bedienung per Klick/Ziehen, VoiceOver per Adjustable-Action. Das alte `Slider` + `scanDepthTickLabels` ist entfernt.
- **22.12:** Assets `NavHouseLine` / `NavHouseLineDuotone`, inaktiv Kontur, aktiv Duotone in `DesignColor.control`. `NavHouse` war sonst unbenutzt und ist gelöscht. Das Such-Icon der Toolbar ist jetzt ebenfalls Phosphor.
- **22.13:** `columnBrowserMinWidth` entfernt. Der Inhalt ist `minWidth: geometry.size.width` breit, sonst so breit wie die tatsächliche Spaltensumme (inkl. Detail-Spalte). Spalten und Detail-Spalte bekommen keine feste Geometry-Höhe mehr (`maxHeight: .infinity`), dadurch liegt ein Legacy-Scroller über der Fußleiste statt über dem Spalteninhalt.

Ursachen hat Claude im Code geprüft; die Entscheidungen stehen im [README.md](README.md) unter „2026-09-29 (2)". Nach der Umsetzung bauen und **jeden Punkt selbst durchklicken**, auch mit angeschlossener Maus (Scrollbalken „immer sichtbar").

### 22.1 Menüleisten-Klick öffnet wieder das Popover
**Ursache:** [MenuBarController.swift:157](diskindex/diskindex/MenuBar/MenuBarController.swift:157): Bei `effectiveMenuBarBadge == .error` springt der Linksklick direkt in die Spaltenansicht. „Externe Platte 5" steht in den Mock-Daten dauerhaft auf `.error`, also öffnet sich das Popover nie.
**Soll:** Linksklick öffnet **immer** das Popover (`toggleDropdown`). Den `if … .error`-Zweig ersatzlos entfernen; `menuBarErrorMediumID` löschen, falls danach unbenutzt. Das Fehler-Badge in der Menüleiste bleibt.

### 22.2 App-Icon — erledigt durch Claude, nur Generator nachziehen
Die zehn PNGs in `Assets.xcassets/AppIcon.appiconset/` hat Claude am 29.09. neu erzeugt (Apple-Raster: 1024er Fläche, Kachel 824 mit 100 px transparentem Rand, Radius 185.4, Schatten y −10 / Blur 20 / 30 % Schwarz ab 64 px; Verlauf 160° #2B2B2D → **#1F1F1F**; Glyph #F2F2F2 bei 38/72 der Kachel). **Nicht überschreiben.**
**Aufgabe:** [Scripts/GenerateAppIcons.swift](diskindex/Scripts/GenerateAppIcons.swift) so anpassen, dass es genau dieses Ergebnis erzeugt. Referenz-Implementierung: [archiv/GenerateAppIcons-referenz-2026-09-29.swift](archiv/GenerateAppIcons-referenz-2026-09-29.swift) (Aufruf: `swift <skript> <pfad/hard-drives.svg> <ausgabeordner>`). Kopfkommentar aktualisieren (Endfarbe #1F1F1F statt #201E1D). Danach Build, App einmal starten und das Dock-Icon neben anderen Apps prüfen (ggf. `killall Dock` wegen Icon-Cache).

### 22.3 Such-Icon und Filter-Icon strikt getrennt
**Ursache:** [AppState.swift](diskindex/diskindex/App/AppState.swift): `toggleSearchFromToolbar()` und `openSearch(withQuery:)` setzen `isFilterBarVisible = true`.
**Soll:**
- Beide Zeilen entfernen. Such-Icon = nur Suchansicht an/aus; Filterleiste und Filter bleiben unverändert (auch beim Verlassen der Suche).
- Das Such-Icon ist blau, solange die Suche aktiv ist; das Filter-Icon ist blau, solange die Leiste offen ist. Beides unabhängig.
- Filter-Icon schließen = Filter aufheben (wie bisher).

### 22.4 Filter nur in Spaltenansicht, Suche, Favoriten
**Soll:**
- In **Übersicht** und **Einstellungen** ist das Filter-Icon deaktiviert: `.disabled(true)`, Farbe `DesignColor.text.opacity(0.3)`, kein Hand-Cursor, kein Tooltip-Text über Bedienung (Regel [layout/CLAUDE.md](layout/CLAUDE.md)).
- Eine offene Filterleiste wird in diesen Ansichten **ausgeblendet, nicht geschlossen**: `isFilterBarVisible` und `searchState.filters` bleiben unangetastet, die Leiste erscheint beim Wechsel in Spaltenansicht/Suche/Favoriten wieder. Eine berechnete Eigenschaft wie `AppState.isFilterAvailable` (Destination ∈ {columnBrowser, search, favorites}) und `showsFilterBar = isFilterBarVisible && isFilterAvailable` verwenden. Toolbar-Blau richtet sich nach `showsFilterBar`.
- In [MainWindowScreenScaffold.swift](diskindex/diskindex/Views/MainWindowScreenScaffold.swift) die Bedingung `mainWindowDestination != .favorites` entfernen; die Leiste erscheint auch in den Favoriten.
- Wirkung: Suche → global (inkl. Medium-Auswahl). Spaltenansicht → aktueller Ordner. **Favoriten → auf die Favoritenliste** (Dateityp + Alter; keine Medium-Auswahl im Popover, zusätzlich zum bestehenden Alle/Online/Offline-Umschalter). Rechts in der Leiste bei Favoriten: „In Favoriten".

### 22.5 Filter-Popover öffnet nicht
**Wahrscheinliche Ursache:** `MainWindowFilterBarFrameKey.reduce` in [MainWindowFilterBar.swift](diskindex/diskindex/Views/MainWindowFilterBar.swift) setzt blind `value = nextValue()`. Liefert ein weiterer Beitrag `.zero`, bleibt `filterButtonFrame == .zero`, und `guard filterButtonFrame != .zero` im Scaffold unterdrückt das Popover komplett. (Beim Suchfeld-Key steht genau dieser Schutz schon drin.)
**Soll:**
- Zuerst per `print` bestätigen, dass `showFilterPopover` umschaltet und der Frame `.zero` ist; den Befund im Status nennen.
- Dann robust lösen: `anchorPreference(key:value: .bounds)` am Filter-Button und `overlayPreferenceValue` im Scaffold (Standardweg, kein Koordinatenraum-Abgleich). Alternative: den Reduce-Schutz gegen `.zero` ergänzen.
- Das Popover liegt über allen Inhalten (zIndex), schließt per Klick daneben, Escape, erneutem Klick auf „Filter" und bei Ansichtswechsel.
- Test in Spaltenansicht, Suche und Favoriten.

### 22.6 Globales Suchfeld: nichts beim Tippen, Enter öffnet die Suche
**Ursache:** `onChange(of: searchState.query)` in [MainWindowScreenScaffold.swift](diskindex/diskindex/Views/MainWindowScreenScaffold.swift) ruft bei jedem Tastendruck `beginSearchFromTyping()` auf.
**Soll:**
- Den `onChange`-Block und `beginSearchFromTyping()` entfernen.
- Tippen ändert nur den Text im Feld.
- **Enter** (`submitObjectSearch`) wechselt in die Suche und zeigt Treffer.
- Das X im Feld leert nur den Text; in der Suche bleibt die Ansicht offen.
- Live-Filterung beim Tippen bleibt nur in Medium-Suchfeldern (`MediumSidebarSearchField`, z. B. „Medium suchen…" im Filter-Popover).

### 22.7 Leere Suche nach Layout (Sektion 10, Zustand 1)
**Ist:** Grauer Kasten mit `padding(16)` im ScrollView ([SearchView.swift:72](diskindex/diskindex/Views/Search/SearchView.swift:72)), ohne Icons.
**Soll:**
- Die graue Fläche füllt den **gesamten Inhaltsbereich unter Toolbar/Filterleiste** (100 % Breite und Höhe, kein Außenabstand, kein ScrollView, kein Tabellenkopf).
- Hintergrund `DesignColor.text.opacity(0.05)`.
- Inhalt vertikal und horizontal zentriert, `VStack(spacing: 14)`:
  1. `HStack(spacing: 14)` mit zwei Phosphor-Icons **regular** 40 × 40 in `DesignColor.text.opacity(0.35)`: **magnifying-glass** und **funnel** (vorhandenes Asset `IconFunnel`; für die Lupe ein Phosphor-SVG-Asset verwenden, kein SF Symbol).
  2. „Suchbegriff eingeben oder Filter verwenden": 15 pt semibold, `text.opacity(0.7)`.
  3. „Durchsucht alle erfassten Speichermedien – auch offline.": 13 pt, `text.opacity(0.55)`, max. Breite 340, zentriert.

### 22.8 Tabellen in Suche und Favoriten: Spalten fluchten nicht
**Ursache:** [ObjectResultsTable.swift](diskindex/diskindex/Views/Search/ObjectResultsTable.swift): Name und Pfad haben nur `frame(minWidth:)` ohne `maxWidth`. Jede Zeile bemisst sie nach eigenem Inhalt, lange Namen („Endabnahme_final_v2_signiert.pdf") verschieben alle folgenden Spalten. Kopf und Zeilen rechnen unabhängig.
**Soll:**
- Feste Spalten bleiben fest (Icon 36, Datum 110, Speichermedium 140, Status 100).
- Name und Pfad: `frame(minWidth: …, maxWidth: .infinity, alignment: .leading)`, im Verhältnis Name : Pfad = 1 : 1 (z. B. über `GeometryReader` einmal pro Tabelle die Breiten berechnen und identisch an Kopf und Zeilen geben).
- Texte `lineLimit(1)`: Name `truncationMode(.middle)`, Pfad `.head`.
- Prüfung: gleiche x-Position jeder Spalte in allen Zeilen und im Kopf, bei 1100 pt und bei maximaler Fensterbreite.

### 22.9 Suchergebnis-Layout (Sektion 10, Zustand 2)
- **Medium-Kacheln** über der Tabelle: kein horizontaler ScrollView, sondern **umbrechend** (FlowLayout, Abstand 12). Innenabstand des Bereichs 16, Kartenbreite **190**, Trennlinie unten. Karte: Icon 20 links, Chip rechts oben, Name 13 pt semibold 6 pt darunter.
- **Tabellenkopf:** Alle fünf Spaltennamen sind klickbar und sortieren (Hand-Cursor); also auch **Speichermedium** und **Pfad** (bisher `column: nil`). `SearchSortColumn` entsprechend ergänzen.
- **Mock-Daten:** Alle Medien außer „Archiv 2019–2021" teilen denselben `genericTree` ([MockIndex.swift](diskindex/diskindex/Models/MockIndex.swift)). Darum liefert „foto" auf jedem Medium dieselbe `Foto_export.jpg`. Mindestens „Foto USB" (Fotos/RAW/Exporte) und „Projekt NVMe" (Projekte/Assets) bekommen eigene Bäume, damit Suche und Filter unterscheidbare Treffer zeigen. Stabile IDs über `itemID(…)` bleiben.

### 22.10 Favoriten: Offline-Beispiel
Alle drei Demo-Favoriten liegen auf Online-Medien, deshalb lässt sich der Offline-Filter nicht testen. In `MockIndex.demoFavoriteItemIDs` **mindestens zwei Objekte auf „Foto USB" (offline)** ergänzen: eine Datei und einen Ordner aus dem neuen Foto-Baum (22.9). Die Offline-Zeilen zeigen den Offline-Status nach Tabellenregel (grau, gestrichelt).

### 22.11 Scan-Tiefe: Beschriftungen unter den Slider-Stopps
**Ursache:** [SettingsGeneralTab.swift:73](diskindex/diskindex/Views/Settings/SettingsGeneralTab.swift:73): Die Zahlen stehen in fünf gleich breiten Zellen (Mitte bei 10/30/50/70/90 %). Die Stopps liegen aber bei 0/25/50/75/100 % der Spur, eingerückt um den Knopfradius.
**Soll:** Wie im Layout: Label *i* (0…4) zentriert bei `x = r + (Breite − 2r) · i/4`, wobei r = halbe Knopfbreite. r nicht schätzen, sondern exakt vom Control nehmen:
- Entweder `NSSlider` per `NSViewRepresentable` mit `numberOfTickMarks = 5`, `allowsTickMarkValuesOnly = true` und die Label-x-Positionen aus `rectOfTickMark(at:)` übernehmen (Tick-Marks selbst dürfen unsichtbar bleiben).
- Oder den Slider komplett selbst zeichnen (Spur + Knopf schwarz #1F1F1F), dann ist r bekannt.

Prüfung: Knopf auf 1, 3 und 5+ steht exakt mittig über der jeweiligen Zahl.

### 22.12 Übersicht-Icon: Aktivstatus
**Ist:** Aktiv = `DesignColor.control` (#1F1F1F), inaktiv = `DesignColor.text` (#201E1D); optisch identisch.
**Soll (README 29.09. (2)):**
- Neue Assets `NavHouseLine` (Phosphor `house-line` regular) und `NavHouseLineDuotone` (Phosphor `house-line` duotone), wie bei `NavBookmarks`/`NavBookmarksDuotone`.
- Inaktiv: Kontur in Textfarbe. Aktiv: Duotone in `DesignColor.control`.
- Das alte `NavHouse` nur löschen, wenn es sonst nirgends verwendet wird.

### 22.13 Spaltenansicht: kein Dauer-Scrollbalken
**Ursache:** [ColumnBrowserView.swift:204](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift:204): `minWidth: max(geometry.size.width, DesignSpacing.columnBrowserMinWidth)` mit `columnBrowserMinWidth = 1020`. Diese Mindestbreite gilt nur für den Spaltenbereich (ohne die 200-pt-Sidebar). Bei 1100 pt Fenster sind rund 900 pt da, der Inhalt ist also immer breiter.
**Soll:**
- Mindestbreite des Inhalts = **tatsächliche Summe** der Spaltenbreiten (+ Trennlinien) bzw. `geometry.size.width`, je nachdem, was größer ist. `columnBrowserMinWidth` hier nicht mehr verwenden.
- Ohne Auswahl und bei passenden Spalten darf **kein** Scrollbalken erscheinen, auch nicht mit „Scrollbalken immer anzeigen" (Systemeinstellung, Maus angeschlossen).
- Wird gescrollt, liegt der horizontale Scrollbalken **direkt über der Fußleiste** (Freier Platz · Pfad · Anzahl), in voller Breite des Spaltenbereichs. Er überdeckt keinen Spalteninhalt: Die Spaltenhöhe ist `geometry.size.height` minus der Scrollerhöhe, falls Legacy-Scroller sichtbar sind. Einfachster Weg: Höhe nicht aus der Geometry vorgeben, sondern Spalten mit `maxHeight: .infinity` im ScrollView füllen lassen.
- Prüfung: Fenster schmal ziehen, tief navigieren → Balken erscheint über der Fußleiste; breit ziehen → verschwindet.

---

## 21. Kontextmenü nach Layout, Aufräumen

**Status:** Erledigt durch Claude (29.09.). `xcodebuild` ✅ ohne Warnungen. Nicht durchgeklickt (siehe Aufgabe 22).
- **21.1 — Weg: eigenes randloses Panel** (`KeyablePanel`, `.popUpMenu`, wie das Menüleisten-Dropdown) statt `NSMenu` mit `NSMenuItem.view`. **Begründung:** `NSMenu` zeichnet Fläche, Radius und Schatten selbst (Systemmaterial, nicht weiß), die Hervorhebung in Systemfarbe statt Schwarz und Views in Menüeinträgen müssen Hover/Klick/Tastatur ohnehin selbst nachbauen. Mit dem Panel gehört uns der ganze Lebenszyklus, also verschwindet der Rahmen garantiert.
  - Dateien: `DesignSystem/ObjectFileContextMenu.swift` (Menü-View, `ObjectContextMenuPresenter`, `RightClickCatcher`).
  - Rechtsklick und Ctrl-Klick fängt ein Overlay-`NSView` ab, dessen `hitTest` nur bei Rechtsklick greift. Linksklick, Hover und Scrollen fallen durch.
  - Das Menü öffnet mit der Ecke oben links am Mauszeiger und klappt am Bildschirmrand nach oben/links. Fläche weiß, Rand 1 px, Radius 8, Schatten, Breite 240, Zeilen 13 pt mit Phosphor-Icons 14 (`IconArrowSquareOut` bold wie im Layout, `IconBookmarkSimple(Duotone)`, `IconMagnifyingGlass`, `IconFileMagnifyingGlass`, `IconProhibit`), Häkchen `IconCheck` 12 rechts: Favorit violett (Icon dann Duotone violett), Ignorieren rot. Hover/Tastaturauswahl: schwarze Zeile, weiße Schrift.
  - Nicht verfügbare Einträge stehen ausgegraut da. „Dateinamen ignorieren“ ist bei Medien ausgegraut, weil ein Mediumname kein Dateimuster ist.
  - Schließen: Auswahl, Escape, Klick daneben (Linksklick wird wie beim Systemmenü verschluckt, Rechtsklick öffnet direkt das nächste Menü), App-Wechsel. Tastatur: ↑/↓/Enter/Escape.
  - Einsatzorte: Spaltenansicht (Objekte + Medien-Sidebar), Suche, Favoriten, kompakte Medium-Karten (vorher natives Medium-Menü), Popover-Suchtreffer. Klicks ins Menü schließen das Menüleisten-Dropdown nicht. Die Suchaktionen öffnen das Hauptfenster und schließen das Dropdown.
  - **Offen/Hinweis:** Dashboard-Karten und die Tabelle unter Einstellungen → Speichermedien behalten ihr natives Medium-Menü („Inhalt anzeigen“ / „Details“). Sie standen nicht auf der Liste, und es sind andere Aktionen. Soll das auch umgestellt werden?
- **21.3:** Gelöscht: `MainWindowIdentifierSetter.swift`, `ColumnBrowserBreadcrumb.swift`, `MenuBarStatusIconView.swift`, dazu optional `AppWindowID.swift`, `NewMediumDialogPresenter.swift` (`NewMediumDialogWindowHost` liegt jetzt in `NewMediumDetectedDialog.swift`), `MenuBarRootView.swift` (Controller hostet `MenuBarPopoverView` direkt, ohne `AnyView`), `RegistryView.swift` + `MainWindowDestination.registry`, `openMainWindowRequest` und `MenuBarPopoverDismiss.openMainWindowFromMenuBar`.

### 21.1 Eigenes Kontextmenü nach Layout (Entscheidung Nutzer 29.09.)
Das native macOS-Menü (SwiftUI `.contextMenu` → `NSMenu`) kann die Layout-Vorgaben nicht darstellen: Häkchen erscheinen nur links und in Menü-Textfarbe, und der schwarze Rahmen am angeklickten Objekt bleibt stehen, weil `onDisappear` des Menüinhalts nicht zuverlässig feuert. Der Nutzer will das Menü **layoutgetreu** (Sektion 12 in [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html)):
- Vier Gruppen mit Trennern: Finder · Favorit · Suchen · Ignorieren (Einträge wie bisher in [ObjectFileContextMenu.swift](diskindex/diskindex/DesignSystem/ObjectFileContextMenu.swift)).
- Aktive Zustände mit Häkchen **rechts**: Favorit in **Violett** (`DesignColor.favorite`), Ignorieren in **Rot** (`DesignColor.stateError`).
- Nicht verfügbare Einträge ausgegraut statt ausgeblendet.
- Menüfläche weiß, Schatten, Radius wie im Mockup.
- Das angeklickte Objekt trägt einen **schwarzen Rahmen, genau solange das Menü offen ist** — beim Schließen (Auswahl, Escape, Klick daneben) verschwindet er zuverlässig.
- Öffnen per Rechtsklick an der Mausposition; Schließen per Escape, Klick außerhalb oder nach Auswahl eines Eintrags; Tastaturbedienung (Pfeiltasten/Enter) wie bei einem Systemmenü wäre wünschenswert.

Umsetzungsweg freigestellt — z. B. ein eigenes `NSMenu` mit `NSMenuItem.view` (eigene Zeilen-Views; Menü-Lebenszyklus über `NSMenuDelegate.menuDidClose` → Rahmen zuverlässig entfernen) oder ein borderless `NSPanel` wie beim Menüleisten-Dropdown. Bitte kurz im Status begründen, welcher Weg gewählt wurde. Gilt für alle bisherigen Einsatzorte: Spaltenansicht, Suche, Favoriten, kompakte Medium-Karten, Popover-Suchtreffer.

### 21.2 *(entfällt — ersetzt durch 22.3/22.4, README 29.09. (2))*

### 21.3 Toten Code löschen
Per Grep geprüft, nirgends verwendet (nur Selbstreferenzen/Previews):
- `Views/MainWindowIdentifierSetter.swift`
- `Views/ColumnBrowser/ColumnBrowserBreadcrumb.swift`
- `MenuBar/MenuBarStatusIconView.swift`

Optional im selben Zug (kleiner Umbau, keine Verhaltensänderung): `App/AppWindowID.swift`; `MenuBar/NewMediumDialogPresenter.swift` (vorher `NewMediumDialogWindowHost` nach `NewMediumDetectedDialog.swift` verschieben); `MenuBar/MenuBarRootView.swift` (Controller hostet direkt `MenuBarPopoverView`); `Views/Registry/RegistryView.swift` samt `MainWindowDestination.registry`; `Notification.Name.openMainWindowRequest`. Danach bauen und kurz durchklicken.

---



---

# Nachtrag 29.09. — Aufgabe 23 (Code freigegeben)

Freigabe Claude 29.09.: Build ✅, App heißt „Disk Index.app“ (CFBundleName/Executable „Disk Index“). 23.1–23.11 gegen Vorgabe geprüft. Ausnahme: Tiefenregel in 23.9 war in der Vorgabe um eine Ebene falsch, Korrektur als Aufgabe 24. 23.1 Schritt 4 wartet auf die Sichtprüfung des Nutzers.

## 23. Fehlerrunde 29.09. (2) — Nutzertest nach 21/22

**Status:** Erledigt durch Claude (29.09.). `xcodebuild` ✅ ohne Warnungen, App startet ohne Absturz. Nicht durchgeklickt (keine Maus-/Tastatursteuerung in dieser Sitzung).
- **23.1 (Schritte 1–3, Schritt 4 wartet auf Rückmeldung):** `Assets.xcassets/DockIcon.imageset/DockIcon.png` ist eine Kopie von `icon_512x512@2x.png`, die App-Icon-PNGs sind unverändert. `AppActivationPolicy.showDockIconForMainWindow()` setzt nach `.regular` `NSApp.applicationIconImage = NSImage(named: "DockIcon")`. `project.pbxproj`: App-Target Debug + Release `PRODUCT_NAME = "Disk Index"`, `PRODUCT_MODULE_NAME = diskindex`. Test-Target `TEST_HOST` → `Disk Index.app/Contents/MacOS/Disk Index` (`BUNDLE_LOADER = $(TEST_HOST)` zieht mit), Produktreferenz → `Disk Index.app`. Bundle-ID und `CFBundleDisplayName` sind unverändert. Geprüft im Build: `Disk Index.app`, `CFBundleName` = `CFBundleExecutable` = „Disk Index“, ID `xjonx.diskindex`. **Hinweis:** Ein alter `diskindex.app`-Build in deinem DerivedData kann bei LaunchServices noch registriert sein; im Zweifel Clean Build Folder. Backup der alten Projektdatei: Scratchpad `project.pbxproj.bak`.
- **23.2:** `didSet` an `AppState.mainWindowDestination`, nur bei echtem Wechsel: `isFilterBarVisible = false`, `searchState.filters = SearchFilters()`. Das Popover schließt über das bestehende `onChange` im Scaffold. Innerhalb der Spaltenansicht und bei neuer Suche in der Suche gibt es keinen Reset. Der Zwischenspeicher-Kommentar ist entfernt, das ausgegraute Filter-Icon bleibt. Die Popover-Suche verwendet die Filter nur, wenn das Hauptfenster schon in der Suche ist; so stimmt „Alle N“ mit der Suchansicht überein.
- **23.3:** Innenabstand 6 × 14, Radius sm, 12 pt semibold, Funnel 13 × 13, Abstand 3. Ohne Filter: blauer Rand, blaue Schrift und Icon. Mit Filtern (`hasEffectiveFilters`): blaue Fläche und Rand, weiße Schrift und Icon.
- **23.4:** `SearchFilterPopoverPanel` neu. Kasten: Rand 1 pt blau, Radius 14, Fläche bg, Schatten y 12 / radius 16 / neutral900 22 %. Innenabstand 24, Gruppenabstand 32. Nase: 11 × 11 gedreht, Fläche bg, blauer Rand oben/links, als `overlay(.topLeading)` außerhalb des Clips mit `offset(x: 18, y: -6)`. Der Kasten sitzt 4 + 8 pt unter dem Button, dadurch endet die Nasenspitze etwa 4 pt darunter.
- **23.5:** `IndexingSpinnerRing` hat jetzt Parameter `color`/`lineWidth`, Bogen 0…0,75 (ein Viertel offen), 0,9 s linear. Die Popover-Zeile nutzt `control` mit 2 pt, 11 × 11, Label 11 pt in `control` mit Abstand 5. Der Chip-Spinner bleibt grün.
- **23.6:** Neuer Modifier `dashedUnderline()` (`DesignSystem/DashedUnderline.swift`): 1 pt, `text.opacity(0.55)`, 3/2, an der Grundlinie ausgerichtet und 2 pt tiefer. Er liegt nur unter dem Wert, in der Übersichtskarte also nicht unter „belegt“ (`HStack` statt Text-Verkettung). Genutzt in Übersichtskarte (nur bei angeschlossenen, indizierten Medien, wo der Umschalter existiert) und Popover-Fortschritt.
- **23.7:** `Medium.iconColor` (Fehler rot > Favorit violett > Text) und `MediumTypeIcon(medium:)`. Genutzt in Übersichtskarte, Popover-Zeile, Detail-Modal, Speichermedien-Tabelle, kompakten Karten und in der Sidebar der Spaltenansicht. Kartenrand und Chip waren schon rot.
- **23.8:** Neuer `RevealInFinderButton` (Rand neutral500, Radius sm, Hover `text.opacity(0.07)`, 12 pt semibold, Icon 13, Abstand 6). Er steht in der Detail-Spalte 16 pt unter den Angaben, nur bei angeschlossenem Medium. Der Status-Chip dort ist `ObjectRowOnlineStatusChip` (Online grün mit Fläche, Offline grau gestrichelt). Button und Kontextmenü rufen `AppState.revealInFinder(_:)` auf (bis zum Backend ohne Wirkung).
- **23.9:** Sechs Ordnerebenen mit Dateien auf jeder Ebene: Archiv `Projekte/Kunde B/Assets/RAW-Export/Shooting_2021/Auswahl`, Foto USB `Fotos/2022/Urlaub_Italien/Tag_01/Serie_A/Bearbeitet`, Projekt NVMe `Projekte/Disk Index/Scripts/Build/Logs/2026`. Zentrale Funktion `MockIndex.allItems(mediumID:maxDepth:)`: Ebene n = Ordneranzahl im Pfad, erfasst wenn n ≤ Tiefe, `nil` bei „5+“. Sie filtert nach dem Cache, der Slider wirkt also sofort. Die ungefilterte Variante ist jetzt privat. `AppSettings.indexedMaxDepth` fließt in Suche, Favoriten, Popover-Suche und die Filter-Zählung. Die Spaltenansicht folgt der bestehenden Regel: Bei Tiefe 3 ist die vierte Spalte die letzte, ihre Ordner sind gelb. Neuer Demo-Favorit `Projekte/Kunde B/Assets/RAW-Export/Shooting_Auswahl.pdf` (Archiv, Ebene 4) erscheint erst ab Tiefe 4.
- **23.10:** Neue gemeinsame `StatusFooterBar` (min. 27 hoch, Trennlinie oben, Fläche 5 %, 11,5 pt, 55 %). Die Spaltenansicht-Fußleiste nutzt sie jetzt auch. `ObjectCountFooter` steht rechts in Suche und Favoriten, außerhalb des ScrollViews, also fest unten. Gemeinsame Formatierung `ObjectCountFormatting.label` (auch Spaltenansicht). Bezugsgröße bei Filtern: Suche = Treffer des Begriffs ohne Filter (`SearchIndex.unfilteredItemCount`), Favoriten = Favoritenliste vor dem Dateityp-/Altersfilter. Die leere Suche hat keine Leiste.
- **23.11:** Linie 1 × 20 zwischen Favoriten- und Einstellungen-Icon, Farbe `divider.opacity(0.35)` wie die übrigen Toolbar-Linien.

Befunde aus dem Klicktest des Nutzers, von Claude gegen Layout und Code geprüft. Neue Entscheidungen: [README.md](README.md) „2026-09-29 (3)". Farben: Blau = `DesignColor.filterSearch` (#3986E4), Rot = `DesignColor.stateError` (#E04830), Schwarz = `DesignColor.control` (#1F1F1F). Nach der Umsetzung bauen und im Status je Punkt eintragen, was geändert wurde.

### 23.1 Dock: Titel „diskindex" und leeres weißes Icon
**Befund:** Die Icon-Datei im Build ist korrekt (Claude hat `AppIcon.icns` aus dem Xcode-Build entpackt). Ursache ist `INFOPLIST_KEY_LSUIElement = YES` + späteres `NSApp.setActivationPolicy(.regular)` in [AppActivationPolicy.swift](diskindex/diskindex/App/AppActivationPolicy.swift). Beim Umschalten zeigt das Dock kein Icon und als Namen `CFBundleName` = `$(PRODUCT_NAME)` = „diskindex".
Die Icon-PNGs in `AppIcon.appiconset` **nicht neu zeichnen und nicht überschreiben**.
**Soll:**
1. **Eigenes Bild für das Dock:** `Assets.xcassets/DockIcon.imageset/` anlegen, als normales Bild, nicht als App-Icon-Eintrag. Inhalt: eine Kopie von `AppIcon.appiconset/icon_512x512@2x.png`, gleiche Grafik. So kann `NSImage(named:)` es sicher laden; ein App-Icon-Eintrag ist über den Namen nicht zuverlässig ladbar.
2. **Icon setzen:** In `AppActivationPolicy.showDockIconForMainWindow()` direkt nach `setActivationPolicy(.regular)`: `NSApp.applicationIconImage = NSImage(named: "DockIcon")`.
3. **Name:**
   - Im App-Target (Debug und Release) `PRODUCT_NAME = "Disk Index"` und `PRODUCT_MODULE_NAME = diskindex`.
   - Die Bundle-ID `xjonx.diskindex` bleibt, `CFBundleDisplayName` bleibt „Disk Index".
   - In den Test-Targets `TEST_HOST` und `BUNDLE_LOADER` auf `Disk Index.app/Contents/MacOS/Disk Index` umstellen.
4. **Falls die Dock-Kachel danach immer noch leer ist:** `INFOPLIST_KEY_LSUIElement` entfernen und in `AppDelegate.applicationWillFinishLaunching` (nicht `didFinish`) `NSApp.setActivationPolicy(.accessory)` setzen.
5. **Status:** Den gewählten Weg eintragen.

Ob die Kachel leer bleibt, kann nur der Nutzer im Dock sehen. Deshalb zuerst Schritt 1–3 umsetzen und melden. Schritt 4 erst nach Rückmeldung des Nutzers umsetzen. Die Sichtprüfung ist bestanden, wenn der Tooltip „Disk Index" zeigt und das Icon dunkel ist.

### 23.2 Filter gehört zur Ansicht
- **Jeder Wechsel von `mainWindowDestination`** schließt die Filterleiste (`isFilterBarVisible = false`), leert `searchState.filters` und schließt das Filter-Popover. Zentral umsetzen, z. B. `didSet` von `mainWindowDestination` in [AppState.swift](diskindex/diskindex/App/AppState.swift), nur wenn sich der Wert wirklich ändert. Damit greift es bei Treffer-Klick, Kontextmenü, Popover und Toolbar.
- Beispiel: In der Suche ist „PDF" gesetzt, Klick auf einen Treffer → Spaltenansicht ohne Filterleiste und ohne Filter.
- **Kein Reset** innerhalb der Spaltenansicht (anderer Ordner/anderes Medium) und bei neuer Suche innerhalb der Suche.
- Die Filter-Zwischenspeicherung für Übersicht/Einstellungen (22.4) entfällt. Das ausgegraute Filter-Icon dort bleibt.

### 23.3 „Filter"-Button in der Filterleiste ([MainWindowFilterBar.swift](diskindex/diskindex/Views/MainWindowFilterBar.swift))
- Form: Innenabstand 6 vertikal × 14 horizontal, Radius `DesignRadius.sm`, Schrift 12 pt semibold, Funnel-Icon 13 × 13, 3 pt Abstand zum Text.
- **Ohne gesetzte Filter:** Rand 1 pt blau, Schrift und Icon blau, keine Fläche.
- **Mit gesetzten Filtern** (`appState.hasEffectiveFilters`): Fläche blau, Rand blau, Schrift und Icon weiß.

### 23.4 Filter-Popover: Nase und Rahmen ([SearchFilterPopoverPanel.swift](diskindex/diskindex/Views/Search/SearchFilterPopoverPanel.swift))
- **Ist:** Das Dreieck ist die erste Zeile **innerhalb** des Kastens und wird vom `clipShape` mit abgeschnitten; Rand grau, Radius `md`.
- **Kasten:** Rand 1 pt **blau**, Radius 14 (`DesignRadius.lg`), Fläche `DesignColor.bg`, Schatten y 12 / `radius: 16` / `neutral900.opacity(0.22)`. Innenabstand 24, Abstand zwischen den Gruppen 32.
- **Nase:** Quadrat 11 × 11, 45° gedreht, Fläche `bg`, Rand 1 pt blau nur oben und links. 18 pt vom linken Rand, sitzt **auf der oberen Kante**: Die Hälfte ragt hinaus, die andere Hälfte überdeckt den Kastenrand.
- Umsetzung: als `overlay(alignment: .topLeading)` **außerhalb** des `clipShape`, `offset(x: 18, y: -6)`. Die Nasenspitze endet etwa 4 pt unter dem Filter-Button.

### 23.5 Spinner im Menüleisten-Popover schwarz (Layout Sektion 03)
- Spinner in der Medium-Zeile 11 × 11, Ring 2 pt in `DesignColor.control`, oberes Viertel offen, 0,9 s linear.
- Prozentangabe daneben 11 pt in `control`, 5 pt Abstand zum Spinner.
- Der grüne Spinner **im Chip** der Übersichtskarte („92 % indiziert") bleibt grün.

### 23.6 Gestrichelte Unterstreichung der Füllstand-Anzeige (Popover Sektion 03, Übersichtskarten Sektion 04)
- Gestrichelte Linie 1 pt in `text.opacity(0.55)`, Muster 3 an / 2 aus, **2 pt unter der Grundlinie**, nur unter dem Wert, nicht unter „belegt".
- Umsetzung per `overlay(alignment: .bottom)` mit `Path` + `StrokeStyle(lineWidth: 1, dash: [3, 2])` + `offset(y: 2)`.
- Nur bei Medien, bei denen ein Klick wirklich zwischen % und absolut umschaltet.

### 23.7 Fehler-Medium rot (Layout Sektion 04, Karte „NAS Klon")
- Bei `indexStatus == .error`: **Medium-Icon rot**, Kartenrand 1 pt rot, Chip „! Fehler" rot (Chip-Rezept).
- Das Icon ist auch im Menüleisten-Popover, in der Sidebar der Spaltenansicht und auf den kompakten Medium-Karten rot. Rot hat Vorrang vor Violett (Favorit).

### 23.8 „Im Finder anzeigen" in der Detail-Spalte (Layout Sektion 07, „Datei auf einem Online-Medium")
- Bei ausgewählter Datei auf einem **angeschlossenen** Medium: Button „Im Finder anzeigen" unter den Angaben, 16 pt Abstand nach oben.
- Rand 1 pt `neutral500`, Radius `sm`, keine Fläche (Hover `text.opacity(0.07)`), Schrift 12 pt semibold, Icon `IconArrowSquareOut` 13 × 13, 6 pt Abstand.
- Bei Offline-Medien entfällt der Button.
- Der Status-Chip in der Detail-Spalte folgt dem Chip-Rezept: „Online" grün (Fläche 5 %), „Offline" grau gestrichelt.
- Button und Kontextmenü rufen **eine** gemeinsame Funktion in `AppState` auf (bleibt ohne Wirkung bis zum Backend, siehe „Später").

### 23.9 Scan-Tiefe simulieren: nur bis Ebene 3
- **Befund:** `defaultScanDepth = 3` und `isFolderBeyondScanDepth` existieren. Aber nur ein Mock-Pfad reicht so tief (Archiv › Projekte › Kunde B › Assets › RAW-Export), und die Suche findet alle Objekte unabhängig von der Tiefe.
- **Mock-Bäume:** Auf Archiv 2019–2021, Foto USB und Projekt NVMe je ein Pfad mit **6 Ordnerebenen** und Dateien auf jeder Ebene. Die IDs bleiben stabil über `itemID(…)`.
- **Spaltenansicht:** Ordner jenseits der Tiefe sind gelb; ein Klick öffnet die Detail-Spalte mit „Inhalt nicht erfasst" (bestehendes Verhalten). Bei Tiefe 3 ist die vierte Spalte die letzte, ihre Ordner sind gelb.
- **Suche, Favoriten, Popover-Suche, Filter-Zählungen:** Objekte jenseits der Tiefe fehlen. Eine zentrale Funktion `MockIndex.allItems(mediumID:maxDepth:)` für alle Aufrufer; bei „5+" liefert sie alles.
- **Slider-Änderung wirkt sofort:** Tiefe in den Cache-Schlüssel aufnehmen oder erst nach dem Cache filtern.
- Ein Demo-Favorit liegt jenseits von Ebene 3 und erscheint erst ab Tiefe 4.

### 23.10 Statusleiste in Suche und Favoriten (Layout Sektionen 10/11)
- Unter der Tabelle, wie die Fußleiste der Spaltenansicht ([ColumnBrowserPathFooter.swift](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserPathFooter.swift)): Mindesthöhe 27, Trennlinie oben, Fläche `text.opacity(0.05)`, Schrift 11,5 pt in `text.opacity(0.55)`.
- **Rechts** „N Objekte" (Innenabstand 6 × 16). Bei aktivem Filter „x von y Objekten"; dieselbe Formatierungsfunktion wie in der Spaltenansicht verwenden.
- Die Leiste bleibt unten stehen, die Tabelle scrollt darüber. In der leeren Suche gibt es keine Leiste.

### 23.11 Trenner in der Toolbar ([MainWindowToolbar.swift](diskindex/diskindex/Views/MainWindowToolbar.swift))
Zwischen dem Favoriten- und dem Einstellungen-Icon eine senkrechte Linie 1 × 20 pt in Divider-Farbe (wie die übrigen Trennlinien).

---



---

# Nachtrag 29.09. — Aufgabe 24 (Code freigegeben)

Freigabe Claude 29.09.: Build ✅. Tiefenregel (Spalten, `allItems(maxDepth:)` mit `<`, `openObject`, `clampPathToScanDepth`) konsistent; ✕-Segment nach Layout (Unterlappung 7, sichtbar 25, `IconX` bold, nur bei `hasEffectiveFilters`, Leiste bleibt offen). Zusätzlich `compositingGroup()` vor Schatten – sinnvoll.

## 24. Scan-Tiefe korrigieren, Filter-Reset ✕

**Status:** Erledigt durch Claude (29.09.). `xcodebuild` ✅ ohne Warnungen, App startet. Filterleiste, Filter-Popover und Slider habe ich per `ImageRenderer` gerendert und angesehen (temporärer Debug-Hook, danach wieder entfernt). Nicht durchgeklickt.
- **24.1:**
  - `AppSettings.isFolderBeyondScanDepth(level:)` → `level + 1 >= scanDepth`.
  - `MockIndex.allItems(mediumID:maxDepth:)` → erfasst, wenn Ordner im Pfad `< maxDepth`.
  - Kommentare in beiden Dateien beschreiben die Regel „Tiefe d = d Spalten, Ordner in Spalte d − 1 gelb“.
  - Neuer Demo-Favorit `Archiv › Projekte/Kunde B/Assets/Moodboard.pdf` (3 Ordner, ab Tiefe 4) neben `…/RAW-Export/Shooting_Auswahl.pdf` (4 Ordner, ab 5+).
  - Spaltenkopf: Einzahl „1 ELEMENT“.
  - **Zusätzlich:** Die Spaltenansicht kürzt beim Erscheinen einen offenen Pfad, der nach dem Verringern der Tiefe zu tief wäre (`clampPathToScanDepth`), sonst stünden alte tiefe Spalten da.
  - `MediumNavigation.openObject` nutzt dieselbe Regel.
- **24.2:**
  - `MainWindowFilterBar`: `filterButtonCombo` = Filter-Button (`zIndex(1)`) + `resetAllFiltersSegment` in einer `HStack(spacing: 0)`, gleiche Höhe über `fixedSize(vertical)`.
  - Segment: Fläche und Rand `control`, `UnevenRoundedRectangle` nur rechts (Radius 6), 7 pt unter den Button geschoben (negativer Versatz + 7 pt Innenabstand), sichtbarer Teil 25 pt, Icon `IconX` (Phosphor x bold, neues Template-Asset) 12 × 12 weiß.
  - Sichtbar nur bei `hasEffectiveFilters`. Klick: `searchState.filters = SearchFilters()`, das Popover schließt, die Leiste bleibt offen. Hand-Cursor, `.help` und `accessibilityLabel` „Alle Filter zurücksetzen“. Die Chips behalten ihr eigenes ✕.
- **Nebenbefund bei der Sichtprüfung, behoben:** `.shadow` wirkte ohne `compositingGroup()` auf jede Unteransicht; im Filter-Popover hatte jeder Chip einen eigenen Schatten. `.compositingGroup()` vor dem Schatten ergänzt in Filter-Popover, Kontextmenü, Detail-Modal, „Neues Medium“-Dialog und Einstellungen-Tab.

### 24.1 Scan-Tiefe um eine Ebene zu tief (Nutzertest)
**Befund (Screenshot des Nutzers):** Bei Tiefe **1** öffnet „Archiv 2019–2021 › Backup Skripte" noch eine zweite Spalte, erst „logs" ist gelb. Erwartet ist, dass bei Tiefe 1 nur die Wurzelspalte sichtbar ist und deren Ordner gelb sind. Die App-eigene Beispielzeile unter dem Slider zeigt es bereits richtig: Tiefe 1 = nur „Festplatte", Tiefe 3 = „Festplatte → Unterordner 1 → Unterordner 2".
Die Vorgabe in 23.9 („Bei Tiefe 3 ist die vierte Spalte die letzte") war von Claude falsch formuliert. Richtig ist:

**Regel:** Tiefe *d* = **d Spalten** mit Inhalt (Spalte 0 = Wurzel des Mediums). Die Ordner in Spalte *d − 1* sind gelb („Inhalt nicht erfasst") und öffnen keine weitere Spalte. Die Wurzelebene ist immer erfasst. Bei „5+" gibt es keine Grenze.

| Tiefe | sichtbare Spalten | gelbe Ordner in Spalte |
|---|---|---|
| 1 | 0 | 0 (Wurzel) |
| 2 | 0–1 | 1 |
| 3 | 0–2 | 2 |
| 4 | 0–3 | 3 |

**Soll:**
- **`AppSettings.isFolderBeyondScanDepth(level:)`:** `level + 1 >= scanDepth` statt `level + 1 > scanDepth`. `level` = Spaltenindex, in dem der Ordner steht.
- **`MockIndex.allItems(mediumID:maxDepth:)`:** Ein Objekt ist erfasst, wenn die Anzahl der Ordner in seinem Pfad **< Tiefe** ist (bisher ≤). Wurzel-Objekte haben 0 Ordner im Pfad und sind bei Tiefe 1 also enthalten. Der Inhalt von Wurzelordnern (1 Ordner im Pfad) ist erst ab Tiefe 2 enthalten. Gilt für Suche, Favoriten, Popover-Suche und Zählungen.
- **Demo-Favorit** `…/RAW-Export/Shooting_Auswahl.pdf` (4 Ordner im Pfad) erscheint damit erst ab Tiefe 5+. Einen zweiten Favoriten mit 3 Ordnern im Pfad ergänzen, der ab Tiefe 4 erscheint, damit jede Stufe testbar bleibt.
- **Kommentare** in `AppSettings` und `MockIndex` an die Regel anpassen.
- **Spaltenkopf:** „1 ELEMENTE" → Einzahl „1 ELEMENT" (wie `ObjectCountFormatting` bei „1 Objekt").

**Prüfung:**
- Tiefe 1: nur die Wurzelspalte, alle Ordner gelb; die Suche findet nur Wurzel-Objekte.
- Tiefe 3: drei Spalten, die Ordner der dritten Spalte gelb.
- 5+: alles offen.
- Der Slider wirkt jeweils sofort.

### 24.2 ✕ am Filter-Button: alle Filter auf einmal zurücksetzen (Layout Sektion 08 „Farbe", Zustände in 08 und 10)
**Layout:** „Sobald mindestens ein Filter gesetzt ist, hängt rechts am Filter-Button ein schwarzes ✕, das alle Filter auf einmal zurücksetzt." Referenz-Screenshot vom Nutzer: blauer „Filter"-Button, rechts daran ein schwarzes Segment mit weißem ✕.

**Aufbau** in [MainWindowFilterBar.swift](diskindex/diskindex/Views/MainWindowFilterBar.swift), als eine zusammenhängende Kombi aus zwei Buttons:
- `HStack(spacing: 0)`, beide Teile gleich hoch (das ✕-Segment streckt sich auf die Höhe des Filter-Buttons).
- **Links:** der bestehende „Filter"-Button (23.3) im gefüllten Zustand. Er liegt **vorne** (`zIndex(1)`) und behält alle vier Ecken mit Radius `DesignRadius.sm` (6).
- **Rechts, das ✕-Segment:**
  - Fläche und Rand 1 pt in `DesignColor.control` (#1F1F1F).
  - Ecken **nur rechts** gerundet (Radius 6), links eckig: `UnevenRoundedRectangle(bottomTrailingRadius: 6, topTrailingRadius: 6)`.
  - Es schiebt sich mit **7 pt** (Radius + 1) **unter** den Filter-Button: negativer linker Versatz 7, dazu 7 pt Innenabstand links. So ist die runde rechte Ecke des blauen Buttons auf schwarzem Grund zu sehen.
  - **Sichtbarer Teil 25 pt breit**, das ✕ darin horizontal und vertikal zentriert.
- **Icon:** Phosphor **`x` bold**, 12 × 12, weiß. Neues Template-Asset `IconX` (Pfad beginnt mit `M208.49,191.51a12,12,0,0,1-17,17L128,145…`; Phosphor „x", Gewicht bold), wie die übrigen Phosphor-Assets angelegt.

**Verhalten:**
- Sichtbar **nur**, solange `appState.hasEffectiveFilters` wahr ist. Außerhalb der Suche zählt eine Medium-Auswahl also nicht. Ohne Filter steht der Filter-Button allein, umrandet (23.3).
- Klick setzt **alle** Filter zurück: `searchState.filters = SearchFilters()` (Dateityp, Alter, Medium-Auswahl, folderOnly). Ein offenes Filter-Popover schließt sich.
- Die **Filterleiste bleibt offen**. Das ist der Unterschied zum Filter-Icon in der Toolbar, das die Leiste schließt und dabei ebenfalls alle Filter aufhebt.
- Danach verschwinden die Chips, der Filter-Button wird wieder umrandet und das ✕ verschwindet.
- Hand-Cursor. `accessibilityLabel("Alle Filter zurücksetzen")`, als Tooltip (`.help`) derselbe Text; das ist ein echter UI-Text aus dem Layout, keine Annotation.
- Einzelne Chips behalten ihr eigenes ✕ („jeder Chip lässt sich einzeln per ✕ entfernen", Sektion 10).

**Prüfung:**
- In Spaltenansicht, Suche und Favoriten: Filter setzen → ✕ erscheint.
- Klick auf ✕ → alle Chips weg, Leiste bleibt offen, Button umrandet.

---



---

# Nachtrag 29.09. — K1 sowie Aufgaben 26–33 (Code freigegeben)

Freigabe Claude 29.09.: Debug- und Release-Build ✅ ohne Warnungen. K1 (Icon im Dateiendungs-Feld) und 26–33 gegen Aufgabe, README und Layout geprüft, im Code bestätigt (App-Icon pixelgleich, Medium-Kontextmenü, Fokus-Fix, Dokumente-Filter, Einmal-Start/Systemstart, roter Bereinigen-Button, eigene Dateiendungen, Oder/Und-Verknüpfung). Einzige offene Empfehlung: 30.1 (Einmal-Start) aus dem gebauten .app-Bundle heraus testen, nicht nur aus Xcode — siehe Klicktest-Checkliste.

## Review Claude 29.09. — Korrektur zu 32.2

Code gegen Aufgabe, README und Layout geprüft (26–33), Debug- **und** Release-Build ✅ ohne Warnungen. 26, 27, 28, 29, 30, 31, 33 sind im Kern korrekt und freigegeben (Details im Archiv). Ein offener Punkt bleibt:

- **K1 (32.2) Icon im Dateiendungs-Feld fehlt noch:** Der Nutzer wollte hier explizit das leere Dokument (`FileTypeGeneric`) statt der Lupe (Nachricht nach dem ursprünglichen Briefing von 32, in die Aufgabe eingearbeitet). [MediumSidebarSearchField.swift](diskindex/diskindex/DesignSystem/MediumSidebarSearchField.swift) hat weiterhin nur `Image("IconMagnifyingGlass")` fest verdrahtet, kein Icon-Parameter. Vermutlich stand die Ergänzung noch nicht in der Aufgabe, als Cursor sie gelesen hat.
  - Neuer optionaler Parameter `icon: String = "IconMagnifyingGlass"` an `MediumSidebarSearchField`.
  - Im Aufruf in `extensionBlock` (`SearchFilterPopover.swift`) `icon: "FileTypeGeneric"` übergeben, Farbe bleibt `text.opacity(0.5)` wie das Icon schon jetzt gefärbt ist.
  - „Medium suchen…" (Spaltenansicht-Sidebar und Filter-Popover) bleibt bei der Lupe (Standardwert).

**Status:** Erledigt durch Claude (29.09.). `MediumSidebarSearchField` hat den neuen Parameter `icon: String = "IconMagnifyingGlass"` (vor `onSubmit`, der Trailing-Closure-Aufruf bleibt gültig). `extensionBlock` übergibt `icon: "FileTypeGeneric"`, die Farbe bleibt `text.opacity(0.5)`. Das Asset ist ein Template. Die beiden anderen Aufrufer (Sidebar, „Medium suchen…“ im Popover) nutzen den Standard, also die Lupe. `xcodebuild` ✅ ohne Warnungen.

---

## 26. App-Icon: Symbol größer (Entscheidung Nutzer 29.09.)

**Status:** Erledigt durch Claude (29.09.).
- `GenerateAppIcons.swift`: Glyph `tile.width * 54 / 72`, Kopfkommentar angepasst.
- Das Skript schreibt jetzt zusätzlich `DockIcon.png`, und zwar aus demselben 1024er PNG. Ohne Argument landet es in `DockIcon.imageset/`, mit Ausgabeordner dort.
- Prüfung: in einen Temp-Ordner gerendert und pixelweise verglichen. Alle zehn App-Icon-PNGs **und** `DockIcon.png`: **0 abweichende Pixel**. Die eingecheckten Dateien habe ich nicht überschrieben.

Der Nutzer hat für das Laufwerk-Symbol im App-Icon eine größere Variante gewählt: **54/72 der Kachelkante** statt 38/72. Sichtbar ist das Symbol damit ~56 % statt ~40 % der Kachelbreite. Claude hat die zehn PNGs in `AppIcon.appiconset` und `DockIcon.imageset/DockIcon.png` bereits neu erzeugt. **Nicht überschreiben.**
- In [Scripts/GenerateAppIcons.swift](diskindex/Scripts/GenerateAppIcons.swift) Zeile 118 `tile.width * 38 / 72` → `tile.width * 54 / 72`, Kopfkommentar Zeile 6 entsprechend anpassen. Referenz: [archiv/GenerateAppIcons-referenz-2026-09-29.swift](archiv/GenerateAppIcons-referenz-2026-09-29.swift).
- Das Skript soll künftig zusätzlich `DockIcon.imageset/DockIcon.png` schreiben (= Kopie der 1024er Variante), damit Dock-Bild und App-Icon nie auseinanderlaufen.
- Prüfung: In einen Temp-Ordner rendern und pixelweise mit den eingecheckten PNGs vergleichen, es darf keine Abweichung geben.

---

## 27. Medium-Kontextmenü im neuen Design (Entscheidung Nutzer 29.09.)

**Status:** Erledigt durch Claude (29.09.). `xcodebuild` ✅ ohne Warnungen, App startet. Nicht durchgeklickt. Den Rahmen konnte ich nicht per `ImageRenderer` prüfen: Der Renderer zeichnet den eingebetteten Rechtsklick-`NSView` nur als Platzhalter. Das ist eine Grenze des Renderers, in der App ist es kein Problem.
- `contextMenuGroups`: Für `kind == .medium` steht vorne eine Gruppe „Inhalt anzeigen“ (neues Asset `IconColumns`, Phosphor columns regular) und „Details“ (`IconFadersHorizontal`). Danach folgen unverändert Finder · Favorit · Suchen · Ignorieren; Dateiendung und beide Ignorieren-Einträge sind bei Medien ausgegraut.
- „Inhalt anzeigen“ ist ausgegraut, wenn die Spaltenansicht dieses Medium schon zeigt. Dabei zählt auch der Fall, dass keine Auswahl gesetzt ist und die Ansicht auf das erste Medium zurückfällt.
- Beide Aktionen rufen danach `MenuBarPopoverDismiss.openMainWindow` auf, damit sie auch aus der Popover-Suche funktionieren (Medium-Treffer dort bekommen dasselbe Menü). Im Hauptfenster holt das nur das Fenster nach vorn.
- Umgestellt auf `.objectContextMenu(.fromMedium(medium), highlightCornerRadius:)`: Übersichtskarte (Radius `md`, liegt über dem roten Fehlerrand), Speichermedien-Zeile (Radius 0, Zeilenform), kompakte Medium-Karte (Radius `md`). Die Sidebar der Spaltenansicht hatte das Menü schon.
- `objectContextMenu` hat einen neuen Parameter `highlightCornerRadius` (Standard `DesignRadius.sm`).
- `mediumContextMenu(mediumID:)` und `MediumContextMenuItems` sind gelöscht, per Grep ohne weitere Verwendung. Der Linksklick ist unverändert, der Rechtsklick-Fänger lässt ihn durch.

Die Übersichtskarten ([MediumDashboardCard.swift:50](diskindex/diskindex/Views/Dashboard/MediumDashboardCard.swift:50)) und die Tabelle unter Einstellungen → Speichermedien ([RegistryTableRow.swift:64](diskindex/diskindex/Views/Registry/RegistryTableRow.swift:64)) nutzen noch das native `.contextMenu` (`mediumContextMenu` in [MediumNavigation.swift](diskindex/diskindex/App/MediumNavigation.swift)). Sie bekommen das eigene Panel-Menü aus 21.1 ([ObjectFileContextMenu.swift](diskindex/diskindex/DesignSystem/ObjectFileContextMenu.swift)).

**Einheitliches Medium-Menü:** Es gilt für jede Stelle, an der ein Medium einen Rechtsklick hat: Übersichtskarte, Speichermedien-Tabelle, kompakte Medium-Karte (Suche/Favoriten) und Sidebar der Spaltenansicht. Für `target.kind == .medium` steht **vor** den bisherigen vier Gruppen eine zusätzliche erste Gruppe:
1. **Inhalt anzeigen:** Icon Phosphor `columns` regular (neues Template-Asset `IconColumns`). Aktion `MediumNavigation.openColumnBrowser(for:)`. Ausgegraut, wenn die Spaltenansicht mit diesem Medium schon offen ist.
2. **Details:** Icon `IconFadersHorizontal` (Styleguide „Details/Regler"). Aktion `MediumNavigation.openDetails(for:)`.

Danach folgen unverändert, durch Trenner getrennt: Finder · Favorit · Suchen · Ignorieren. Für Medien bleiben „Nach Dateiendung suchen" und beide Ignorieren-Einträge wie bisher ausgegraut (gleiche Menüstruktur, Layout Sektion 12). Keine Menüzeilen-Texte mit Hinweisen oder Annotationen ([layout/CLAUDE.md](layout/CLAUDE.md)).

**Umsetzung:**
- Beide Stellen auf `.objectContextMenu(.fromMedium(medium))` umstellen.
- Danach `mediumContextMenu(mediumID:)` und `MediumContextMenuItems` löschen (sonst nirgends verwendet, per Grep prüfen).
- **Schwarzer Rahmen** während das Menü offen ist (bestehender Mechanismus über `contextMenuHighlightObjectID`):
  - Er folgt der Form des Elements. Auf der Übersichtskarte also der Karten-Eckradius statt `DesignRadius.sm`, in der Tabellenzeile die Zeilenform.
  - Dafür bekommt `objectContextMenu` einen optionalen Parameter für den Eckradius, Standard `DesignRadius.sm`.
  - Der Fehlerzustand-Rand der Karte (rot) wird für die Dauer des Menüs vom schwarzen Rahmen überdeckt.
- **Linksklick** auf Karte und Zeile bleibt unverändert. Der Rechtsklick-Fänger lässt Linksklicks durch.

**Prüfung:**
- Rechtsklick auf eine Übersichtskarte und auf eine Zeile der Speichermedien-Tabelle öffnet das neue Menü mit fünf Gruppen, der Rahmen sitzt passgenau.
- „Details" öffnet das Detail-Modal, „Inhalt anzeigen" die Spaltenansicht.
- In der Spaltenansicht-Sidebar ist „Inhalt anzeigen" für das aktuelle Medium ausgegraut.

---

## 28. Suchfeld hat beim Öffnen des Hauptfensters den Fokus (Nutzertest)

**Status:** Erledigt durch Claude (29.09.). `xcodebuild` ✅ ohne Warnungen. **Zur Laufzeit geprüft** mit einem temporären Hook, danach wieder entfernt: Er öffnet das Fenster neu, holt es danach mit einer Suche („rechnung“, Weg wie Kontextmenü/Popover) erneut nach vorn und gibt `window.firstResponder` aus.
  - Mit Fix: in allen drei Messungen `NSWindow`.
  - **Gegenprobe ohne Fix:** `_SystemTextFieldFieldEditor`, also Cursor im Suchfeld. Der Befund ist damit reproduziert und behoben.
- `AppWindowPresenter.clearInitialFocus(in:appState:)` läuft nach **beiden** `makeKeyAndOrderFront`-Aufrufen in `openMain`:
  - Im nächsten Runloop `window.makeFirstResponder(nil)`.
  - Nach 0,15 s ein Nachzügler, falls SwiftUI den Fokus erst nach dem Layout setzt. Er entfernt nur einen Textfeld-Fokus (`firstResponder is NSText`).
- SwiftUI-Seite: neuer Zähler `AppState.searchFieldFocusResetCount`. Das Scaffold setzt bei Änderung `isSearchFocused = false`, damit `@FocusState` sicher mitzieht.
- Kein Eingriff bei `didBecomeKey`: Nach ⌘-Tab zurück bleibt der Cursor. Klick ins Feld und Tab funktionieren wie gewohnt.
- Alle Wege gehen durch `openMain`: „Disk Index öffnen“, Medium-Zeile, „Alle N Ergebnisse“, Kontextmenü, Menüleisten-Rechtsklick → „Disk Index anzeigen“.
- **Dock-Icon:** `AppDelegate.applicationShouldHandleReopen` ruft bei **nicht sichtbarem** Fenster (z. B. minimiert) `openMain` auf, also ebenfalls ohne Fokus. Bei sichtbarem Fenster bleibt das Standardverhalten, wie bei ⌘-Tab.

**Befund:** Öffnet man das Hauptfenster, blinkt der Text-Cursor sofort im Feld „Objekte suchen…". Ursache ist ein AppKit-Standardverhalten: Wird ein Fenster key, macht AppKit das erste Element der Key-View-Loop (hier das Toolbar-Suchfeld) zum First Responder. [AppWindowPresenter.openMain](diskindex/diskindex/App/AppWindowPresenter.swift) ruft `makeKeyAndOrderFront` auf (neues Fenster **und** Wiederanzeigen eines vorhandenen), nimmt den Fokus danach aber nicht weg. Der Fix aus Aufgabe 15 (Fokus bei Klick daneben abgeben, `ObjectSearchFocusMonitor`) betrifft nur Klicks und greift hier nicht.

**Soll:**
- Nach dem Öffnen und nach jedem erneuten Nach-vorne-Holen durch `openMain` hat **kein** Feld den Fokus.
- In `openMain` nach beiden `makeKeyAndOrderFront(nil)`-Aufrufen im nächsten Runloop-Durchlauf den First Responder auf das Fenster setzen: `DispatchQueue.main.async { window.makeFirstResponder(nil) }`. Das `async` ist nötig, weil SwiftUI/AppKit den Fokus erst nach dem ersten Layout setzen.
- Die SwiftUI-Seite muss mitziehen: `@FocusState isSearchFocused` im Scaffold ist danach `false`. Kurz prüfen, ob es sich von selbst angleicht; sonst zusätzlich eine Benachrichtigung bzw. einen Zähler in `AppState` auslösen, auf den das Scaffold mit `isSearchFocused = false` reagiert.
- **Nicht** bei jedem `didBecomeKey` den Fokus wegnehmen. Wer im Feld tippt, per ⌘-Tab wegwechselt und zurückkommt, soll den Cursor behalten (Standardverhalten).
- Gilt für alle Wege ins Fenster, auch wenn die Aktion direkt eine Suche öffnet (Popover „Alle N Ergebnisse anzeigen", Kontextmenü „Nach Namen suchen"): Der Begriff steht im Feld, der Fokus aber nicht.
- Klick ins Feld und Tab fokussieren weiterhin wie gewohnt.

**Prüfung:**
- Das Fenster ohne Fokus im Suchfeld öffnen, und zwar über jeden dieser Wege:
  - „Disk Index öffnen" im Popover
  - Klick auf eine Medium-Zeile im Popover
  - „Alle N Ergebnisse anzeigen"
  - Rechtsklick auf das Menüleisten-Icon → „Disk Index anzeigen"
  - Klick aufs Dock-Icon
- Jeweils einmal mit neuem und einmal mit schon offenem Fenster.
- Tippen ohne vorherigen Klick ins Feld bewirkt nichts.

---

## 29. Filter „Dokumente" findet keine Dokumente (Nutzertest)

**Status:** Erledigt durch Claude (29.09.). `SearchFileTypeFilter.matches`: `.documents` = `Self.pdf.matches(…) || Self.text.matches(…) || officeExtensions.contains(ext)`. Die neue private Konstante `officeExtensions` hält die bisherigen Office-Endungen; `rtf` steckt bereits in „Text“, und keine Endungsliste ist doppelt. „PDF“ und „Text“ sind unverändert. Ordner kehren vorher mit `false` zurück (außer bei „Ordner“). Erwartung bei Externe Platte 5 › Dokumente: „Dokumente“ 2 von 3, „PDF“ 1, „Text“ 1. Nicht durchgeklickt.

**Befund (Screenshot des Nutzers):** Externe Platte 5 › Dokumente enthält `2024/`, `Notizen.txt`, `Übersicht.pdf`. Filter „Dokumente" → „0 VON 3". Ursache: `SearchFileTypeFilter.matches` in [SearchState.swift](diskindex/diskindex/Models/SearchState.swift) trennt strikt. „Dokumente" = nur Office-Formate, `txt/md/rtf/csv` = „Text", `pdf` = „PDF". Dabei zeigt die App `Notizen.txt` selbst mit dem Dokument-Icon an.

**Soll (Entscheidung, README 29.09. (3)):**
- **„Dokumente" ist der Oberbegriff:** Alles aus „Text" + „PDF" + die bisherigen Office-Formate (`doc, docx, xls, xlsx, ppt, pptx, pages, numbers, key, odt, ods, odp`). `rtf` gehört ebenfalls dazu.
- „PDF" und „Text" bleiben als **engere** Filter unverändert. Mehrfachauswahl ist wie bisher eine Oder-Verknüpfung, Überschneidungen sind also unschädlich.
- Umsetzung ohne doppelte Endungslisten: `case .documents: return Self.pdf.matches(…) || Self.text.matches(…) || officeExtensions.contains(ext)`.
- Ordner zählen nie als Dokument.

**Prüfung:**
- Externe Platte 5 › Dokumente mit Filter „Dokumente" → „2 VON 3" (`Notizen.txt`, `Übersicht.pdf`).
- Filter „PDF" → 1, „Text" → 1.
- In der Suche findet „Dokumente" auch `.docx`/`.pptx` (z. B. `Notizen.docx`, `Präsentation.pptx`).

---

## 30. Nur eine Instanz & „Automatisch bei Systemstart" (Entscheidung Nutzer 29.09.)

**Status:** Erledigt durch Claude (29.09.). `xcodebuild` Debug + Release ✅ ohne Warnungen.
- **30.1** ([AppDelegate.swift](diskindex/diskindex/App/AppDelegate.swift)): `ensureSingleInstance()` in `applicationWillFinishLaunching`, vor `install`. Andere Instanzen findet sie über `NSRunningApplication.runningApplications(withBundleIdentifier:)` ohne den eigenen Prozess. `Logger` (Subsystem `xjonx.diskindex`, Kategorie `SingleInstance`) schreibt in beiden Fällen eine Zeile.
  - **Release:** Postet `xjonx.diskindex.showMainWindow` (nur Name), ruft `others[0].activate()` auf und beendet sich. Die laufende Instanz beobachtet den Namen und ruft `openMain` auf.
  - **Debug — Abweichung vom Spec, begründet:** `other.terminate()`/`forceTerminate()` **wirken im Sandbox nicht** auf fremde Prozesse. Im Test liefen beide Instanzen weiter. Deshalb postet die neue Instanz zusätzlich `xjonx.diskindex.quitOlderInstance`, mit ihrer PID als `object`-String (übersteht die Sandbox, anders als `userInfo`). Laufende Instanzen beenden sich darauf selbst und ignorieren das eigene Signal. `terminate`/`forceTerminate` bleiben als Versuch für nicht-sandboxed Builds.
  - **Zur Laufzeit geprüft:** Debug: A starten, dann B → A beendet, B läuft. Release: Start bei laufender Instanz → neue beendet sich sofort, die alte bleibt.
  - Hinweis: Instanzen aus Builds **vor** dieser Änderung kennen das Signal nicht und bleiben stehen (einmal von Hand beenden).
- **30.2:** Neuer Typ `LaunchAtLogin` ([App/LaunchAtLogin.swift](diskindex/diskindex/App/LaunchAtLogin.swift)) mit `state` (`.on`/`.off`/`.requiresApproval` aus `SMAppService.mainApp.status`), `isEnabled`, `setEnabled(_:)` (`register`/`unregister`, Fehler nur per `Logger`) und `openSystemSettings()`. Standard ist aus, die App meldet sich nie selbst an.
  - **Einstellungen → Allgemein:** erster Abschnitt „SYSTEMSTART“ mit Beschreibungstext, Checkbox „Automatisch bei Systemstart“ (gleicher Stil wie „Mitteilung aktivieren“) und darunter eine Trennlinie. Bei `.requiresApproval` erscheint darunter die gelbe Zeile „In den Systemeinstellungen freigeben“ (öffnet die Anmeldeobjekte, Hand-Cursor). Der Status wird beim Erscheinen und bei jeder App-Aktivierung neu gelesen. „Auf Standard zurücksetzen“ fasst den Systemstart nicht an.
  - **Menüleisten-Rechtsklick** (natives `NSMenu`): „Disk Index anzeigen“ · Trenner · „Automatisch bei Systemstart“ mit Häkchen (bei jedem Öffnen frisch gelesen, `.requiresApproval` = an) · Trenner · „Disk Index beenden“. Ein Klick schaltet um.
  - **Nicht getestet:** Ein Test hätte einen echten Anmeldeeintrag in deinem System angelegt. Die Prüfung aus der Aufgabe (Anmeldeobjekte, Ab-/Anmelden) steht noch aus.

### 30.1 App darf nur einmal laufen
**Befund:** Man kann die App doppelt starten → zwei Menüleisten-Icons. macOS verhindert das nur für **eine** Kopie des Bundles. Liegen mehrere Kopien vor (Xcode-DerivedData, alte `diskindex.app`, Prüf-Builds), startet jede eine eigene Instanz. Ein Direktstart der ausführbaren Datei umgeht die Sperre ebenfalls.
**Soll:** In [AppDelegate.swift](diskindex/diskindex/App/AppDelegate.swift) in `applicationWillFinishLaunching` (vor `install`, damit kein zweites Menüleisten-Icon aufblitzt) prüfen: `NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)`, ohne den eigenen Prozess (`processIdentifier != ProcessInfo.processInfo.processIdentifier`).
- **Release:** Läuft schon eine Instanz, holt die neue das Hauptfenster der laufenden nach vorn und beendet sich sofort (`NSApp.terminate(nil)`). Signal über `DistributedNotificationCenter.default().postNotificationName(Notification.Name("xjonx.diskindex.showMainWindow"), object: nil, userInfo: nil, deliverImmediately: true)`. Nur der Name, keine `userInfo`, denn im Sandbox wird `userInfo` entfernt. Die laufende Instanz beobachtet diesen Namen und ruft `AppWindowPresenter.openMain(appState:)` auf, dazu `other.activate()`.
- **Debug** (`#if DEBUG`): umgekehrt. Die **neue** Instanz beendet die alte (`other.terminate()`, nach 2 s `forceTerminate()`) und läuft weiter. Sonst würde jeder Xcode-Run sofort enden, wenn noch eine alte Instanz läuft.
- Log-Zeile per `Logger` bei jedem der beiden Fälle.

**Prüfung:**
- Release-Build zweimal öffnen (z. B. `open -n`) → ein Menüleisten-Icon, das Hauptfenster kommt nach vorn.
- Xcode-Run bei laufender alter Instanz → die alte verschwindet, die neue läuft.

### 30.2 „Automatisch bei Systemstart"
Nutzerwunsch: Die Option steht unter **Einstellungen → Allgemein** und zusätzlich im **Rechtsklick-Menü des Menüleisten-Icons**. Das Layout hat die Option noch nicht; sie wird nach dem Muster der übrigen Abschnitte in „Allgemein" gebaut.

**Technik:**
- `SMAppService.mainApp` (ServiceManagement, macOS 13+, Deployment-Ziel 15.7; funktioniert im Sandbox ohne Helper).
- **Einschalten:** `register()`. **Ausschalten:** `unregister()`.
- **Quelle der Wahrheit ist das System**, nicht `AppSettings`: Der Nutzer kann den Eintrag auch in Systemeinstellungen → Allgemein → Anmeldeobjekte entfernen. Den Zustand deshalb bei jedem Anzeigen neu aus `SMAppService.mainApp.status` lesen: beim Erscheinen des Tabs und beim Öffnen des Menüs.
  - `.enabled` = an.
  - `.requiresApproval` = an, aber vom Nutzer noch nicht freigegeben.
  - `.notRegistered` / `.notFound` = aus.
- **Fehler** bei `register`/`unregister`: Schalter auf den tatsächlichen Status zurücksetzen und per `Logger` protokollieren. Keine Fehlermeldung mit Code im UI.
- **Standard: aus.** Die App meldet sich nie ungefragt an.
- Kapseln in einem kleinen Typ, z. B. `LaunchAtLogin` mit `isEnabled` (lesen) und `setEnabled(_:)`. Beide Stellen nutzen ihn.

**Einstellungen → Allgemein** ([SettingsGeneralTab.swift](diskindex/diskindex/Views/Settings/SettingsGeneralTab.swift)), als **erster** Abschnitt über „Scan-Tiefe", gleicher Aufbau wie „Hinweis zu Online-Favoriten" (links Titel und Beschreibung, rechts das Bedienelement, Trennlinie dazwischen):
- Titel: `SYSTEMSTART`.
- Beschreibung (12 pt, `text.opacity(0.6)`): „Disk Index startet nach der Anmeldung am Mac automatisch in der Menüleiste, damit angeschlossene Speichermedien sofort erkannt werden."
- Rechts: Checkbox „Automatisch bei Systemstart", im selben Stil wie „Mitteilung aktivieren" (16 × 16, schwarz, 12,5 pt semibold, Abstand 9).
- Bei `.requiresApproval`: darunter eine Zeile in Gelb (`DesignColor.stateIgnored`), 11,5 pt: „In den Systemeinstellungen freigeben". Klick darauf öffnet `SMAppService.openSystemSettingsLoginItems()`, mit Hand-Cursor.
- „Auf Standard zurücksetzen" in diesem Tab ändert den Systemstart **nicht** (Systemeinstellung, kein App-Wert).

**Menüleisten-Rechtsklick** ([MenuBarController.swift](diskindex/diskindex/MenuBar/MenuBarController.swift) `showContextMenu`; bleibt ein natives `NSMenu`, das ist dort Systemstandard):
- Aufbau: „Disk Index anzeigen" · Trenner · **„Automatisch bei Systemstart"** mit Häkchen (`state = .on/.off` aus `SMAppService.mainApp.status`; `.requiresApproval` zählt als `.on`) · Trenner · „Disk Index beenden".
- Klick schaltet um. Wenn die Einstellungen offen sind, aktualisiert sich die Checkbox dort beim nächsten Anzeigen.

**Prüfung:**
- Einschalten → in Systemeinstellungen → Anmeldeobjekte steht „Disk Index".
- Dort entfernen → Menü und Einstellung zeigen „aus".
- Nach Ab- und Anmelden startet die App nur in der Menüleiste, ohne Hauptfenster und ohne Dock-Icon.

---

## 31. „Erfasste Objekte jetzt bereinigen" rot (Nutzertest)

**Status:** Erledigt durch Claude (29.09.). Der Button nutzt jetzt `DestructiveBorderButtonStyle()`, „Auf Standard zurücksetzen“ bleibt grau. Grep nach Lösch- und Bereinigungsaktionen (lösch/entfern/vergessen/forget/bereinig/purge): Die einzige weitere echte destruktive Aktion ist „Vergessen“ im Detail-Modal, und die ist schon rot. Alle übrigen Treffer entfernen nur Filter- oder Ignore-Chips; das ist nicht destruktiv und bleibt so.

**Befund:** In Einstellungen → Ignorierte Objekte ist der Button „Erfasste Objekte jetzt bereinigen" grau (`SecondaryBorderButtonStyle`, [SettingsIgnoredObjectsTab.swift:22](diskindex/diskindex/Views/Settings/SettingsIgnoredObjectsTab.swift:22)). Im Layout (Sektion 05) hat er Rand und Schrift in Rot #E04830. Farbkonzept: Rot = destruktive Aktion.
**Soll:**
- `.buttonStyle(DestructiveBorderButtonStyle())`, derselbe Stil wie „Vergessen" im Detail-Modal. Kein neuer Stil.
- „Auf Standard zurücksetzen" daneben bleibt grau.
- Per Grep prüfen, ob es weitere destruktive Aktionen mit grauem Stil gibt (z. B. Entfernen aus der Ignore-Liste ist **nicht** destruktiv). Nur echte Lösch-/Bereinigungsaktionen werden rot. Fundstellen im Status nennen.

---

## 32. Filter: eigene Dateiendungen (Layout-Update 29.09., Sektion 09)

**Status:** Erledigt durch Claude (29.09.). `xcodebuild` ✅ ohne Warnungen.
- **32.1:** `SearchFilters.customExtensions` mit `normalizedExtension(_:)` (trim, lowercase, `*` und führende Punkte weg, genau ein Punkt davor; erlaubt Buchstaben/Ziffern/`-`/`_`/innere Punkte; max. 16 Zeichen; außerdem kein `..` und kein Punkt am Ende). `addCustomExtension(_:)` liefert `false` bei ungültiger Eingabe; ist die Endung schon vorhanden, zählt das als Erfolg, das Feld wird geleert. `SearchItemFilter.matches`: Kategorie **oder** `hasSuffix(ext)` bilden eine Dateityp-Gruppe, Ordner passen nie auf eine Endung. `hasActiveObjectFilters` berücksichtigt die Endungen, neu ist `hasFileTypeFilter`.
- **32.2:** Unter den Kategorien (16 pt Abstand) der Block „DATEIENDUNG“: `MediumSidebarSearchField` mit Platzhalter „Endung eingeben, z. B. jpg“. Das Feld hat dafür einen neuen optionalen `onSubmit` bekommen, Enter übernimmt die Endung. Darunter blaue `FilterValueChip`s mit ✕. Die Spaltenbreite ist jetzt 195 (Layout, vorher 200).
- **32.3:** Die eigenen Endungen erscheinen zusätzlich als Chips in der Filterleiste, hinter den Kategorien. ✕-Reset und Ansichtswechsel leeren sie über `SearchFilters()`.
- **Mock:** `Plakat_A1.psd` und `Katalog_2021.indd` liegen in Archiv › Projekte › Kunde B. **Abweichung:** `Mitschnitt.log` liegt in Projekt NVMe › Projekte › **Disk Index** statt in `…/Scripts`, weil `Scripts` 3 Ordner tief ist und bei Standardtiefe 3 nicht erfasst würde (Regel aus 24.1).
- **Nebenbei ans Layout angeglichen:**
  - Die Gruppenüberschriften im Popover sind jetzt „DATEITYP / MEDIUM / ALTER / DATEIENDUNG“ in Versalien, 10 pt, Laufweite 0,8, 50 % wie im Layout (vorher „Dateityp“ 11 pt semibold).
  - Die Lupe im kleinen Medium-Suchfeld ist jetzt das Phosphor-Asset statt SF Symbol.
- **Zur Laufzeit geprüft** (temporärer Hook, wieder entfernt):
  - Normalisierung: `psd`→`.psd`, `.INDD`→`.indd`, `*.log`→`.log`, `JPG`→`.jpg`, `tar.gz`→`.tar.gz`; `a b`, `/`, leer, `..`, 17 Zeichen, `.jpg.` → abgelehnt.
  - Eingabe von `psd`, `.INDD`, `*.log`, `PSD` ergibt genau drei Chips; die Treffer sind `Katalog_2021.indd`, `Plakat_A1.psd`, `Mitschnitt.log`.
  - Oder-Verknüpfung: „PDF“ allein 14 Treffer, „PDF“ + `.psd` 15.
  - Aufgabe 29 gleich mitgeprüft: Externe Platte 5 › Dokumente → „Dokumente“ 2 von 3, „PDF“ 1, „Text“ 1.
  - Das Popover habe ich als Bild gerendert und die Anordnung passt. Eingabefelder und Checkboxen zeigt der Renderer nur als Platzhalter.

Das Layout hat im Filter-Popover unter „Dateityp" einen neuen Block **„DATEIENDUNG"**: freie Eingabe eigener Endungen (z. B. `.psd`, `.indd`), die wie Dateityp-Kategorien filtern. Layout-Text: „Eingabe mit Enter bestätigen, die Endung erscheint als blauer Chip direkt unter dem Feld (per ✕ entfernbar). ‚jpg' und ‚.jpg' sind gleichwertig — fehlt der Punkt, setzt das System ihn für den Abgleich automatisch davor; Groß-/Kleinschreibung wird ignoriert, angezeigt wird immer mit Punkt."

### 32.1 Modell & Abgleich ([SearchState.swift](diskindex/diskindex/Models/SearchState.swift))
- `SearchFilters` bekommt `customExtensions: [String]` (Reihenfolge der Eingabe, ohne Duplikate). Gespeichert wird **normalisiert**: kleingeschrieben, mit genau einem führenden Punkt (`.psd`).
- **Normalisierung** in einer Funktion, z. B. `SearchFilters.normalizedExtension(_ input: String) -> String?`:
  - Leerzeichen trimmen.
  - Ein führendes `*` und führende Punkte entfernen, dann genau einen Punkt davorsetzen. Also `jpg`, `.jpg`, `*.jpg`, `JPG` → `.jpg`.
  - Erlaubt sind nur Buchstaben, Ziffern, `-`, `_` und innere Punkte (`.tar.gz`). Maximal 16 Zeichen ohne führenden Punkt.
  - Ungültig oder leer → `nil`, es wird nichts hinzugefügt und das Feld behält den Text.
  - Schon vorhanden → nicht doppelt hinzufügen, das Feld wird trotzdem geleert.
- **Abgleich:** Eine Datei passt, wenn `name.lowercased().hasSuffix(ext)` (damit funktionieren auch mehrteilige Endungen wie `.tar.gz`). Ordner passen nie.
- **Verknüpfung:** Kategorien und eigene Endungen bilden **eine** Dateityp-Gruppe mit Oder-Verknüpfung. Ein Objekt passt, wenn es eine gewählte Kategorie **oder** eine eigene Endung trifft. Mit Alter und Medium wird wie bisher Und-verknüpft. Umsetzung in `SearchItemFilter.matches`.
- `hasActiveObjectFilters` berücksichtigt `!customExtensions.isEmpty`. Damit greifen automatisch Filter-Button (blau gefüllt), ✕-Reset (24.2), Spaltenkopf „x VON y" und die Statusleisten.

### 32.2 Popover-UI ([SearchFilterPopover.swift](diskindex/diskindex/Views/Search/SearchFilterPopover.swift), Dateityp-Spalte)
- Direkt unter den Kategorie-Chips, 16 pt Abstand: Überschrift **„DATEIENDUNG"**, gleicher Stil wie „DATEITYP"/„MEDIUM" (10 pt, Laufweite 0,8, `text.opacity(0.5)`), 8 pt Abstand darunter.
- **Eingabefeld:** Gleiche Maße wie „Medium suchen…" (`MediumSidebarSearchField` bzw. deren Stil: 12 pt, Mindesthöhe 24, Icon 11 pt links). **Icon ist aber keine Lupe**, sondern das leere Dokument: Phosphor `file` regular = vorhandenes Asset `FileTypeGeneric`, in `text.opacity(0.5)` (Nutzervorgabe + Layout). Dafür bekommt `MediumSidebarSearchField` einen optionalen Icon-Parameter (Standard: Lupe). Platzhalter **„Endung eingeben, z. B. jpg"**. Das graue ✕ zum Leeren gilt wie bei jedem Suchfeld (Styleguide „Suchfeld — Reset-Verhalten").
  - **Enter** fügt die Endung hinzu und leert das Feld. Enter darf das Popover **nicht** schließen, und es darf nicht die Objektsuche in der Toolbar auslösen.
  - Kein Live-Filtern beim Tippen.
- **Chips darunter** (8 pt Abstand, `FlowLayout` 6): Je Endung ein blauer Chip nach Chip-Rezept (Schrift, Rand, ✕ in `filterSearch`, Fläche 5 %), Text mit Punkt (`.psd`), ✕ 9 pt, 6 pt Abstand. Klick aufs ✕ entfernt die Endung, mit Hand-Cursor.
- Spaltenbreite der Dateityp-Spalte bleibt wie bisher (Layout max. 195). Lange Endungen brechen im `FlowLayout` um.

### 32.3 Filterleiste ([MainWindowFilterBar.swift](diskindex/diskindex/Views/MainWindowFilterBar.swift))
- Jede eigene Endung erscheint **zusätzlich** als blauer Chip in der Filterleiste (Layout: „Jede Auswahl erscheint sofort als blauer Chip in der Filterleiste"), nach den Kategorie-Chips, gleicher `FilterValueChip`, Text `.psd`. Ihr ✕ entfernt die Endung.
- Der ✕-Reset am Filter-Button und der Ansichtswechsel (23.2) leeren auch die eigenen Endungen, das geschieht automatisch über `SearchFilters()`.

### Mock-Daten
Damit sich die Funktion testen lässt, in [MockIndex.swift](diskindex/diskindex/Models/MockIndex.swift) einige Dateien mit Endungen ergänzen, die keine Kategorie abdeckt. Zum Beispiel `Plakat_A1.psd` und `Katalog_2021.indd` (Archiv › Projekte › Kunde B) und `Mitschnitt.log` (Projekt NVMe › Projekte › Disk Index › Scripts). Innerhalb der Scan-Tiefe 3 platzieren, sonst sind sie bei der Standardtiefe unsichtbar.

**Prüfung:**
- In der Suche `psd`, `.INDD` und `*.log` eingeben, jeweils mit Enter. Es erscheinen drei Chips `.psd`, `.indd`, `.log` im Popover und in der Leiste, und die Treffer stimmen.
- Doppelte Eingabe erzeugt keinen zweiten Chip; `a b` oder `/` werden nicht angenommen.
- Kategorie „PDF" + `.psd` zeigt beide Dateiarten (Oder).
- In der Spaltenansicht filtert `.psd` den aktuellen Ordner.
- ✕-Reset leert alles, ebenso der Wechsel der Ansicht.

---

## 33. Filter-Verknüpfung „Oder"/„Und" (Layout-Update 29.09., Sektionen 08/09)

**Status:** Erledigt durch Claude (29.09.). `xcodebuild` ✅ ohne Warnungen.
- **33.1:** `combineButton` in der Filterleiste, direkt nach der Filter-Kombi (Abstand 8), 27 × 27, Radius sm, Icon `IconLink` (Phosphor link, neues Asset) 13 × 13. Die drei Zustände und Tooltips (`.help` = `accessibilityLabel`) sind wie in der Tabelle umgesetzt. Deaktiviert heißt: `.disabled`, `opacity(0.35)`, kein Hand-Cursor. Den Suchbegriff liefert `AppState.hasActiveSearchTerm` (nur in der Suche, abgeschickter Begriff, getrimmt).
  - **Abweichung:** Die Höhe ist fest 27 statt `stretch`. Die Filter-Kombi ist ebenfalls 27 hoch, und ein `maxHeight: .infinity` hätte die ganze Filterleiste in die Höhe ziehen können.
- **33.2:** `folderOnly` entfernt. Neu: `combineWithAnd`, `effectiveCombineWithAnd(hasSearchTerm:)` (einzige Berechnung, genutzt von UI und Matching) und zusätzlich `isCombineDisabled(hasSearchTerm:)` für den Button-Zustand.
- **33.3:** `SearchItemFilter.matches` nach Vorgabe, dazu der zusätzliche Default-Parameter `foldersIgnoreTypeFilter` für 33.5. `SearchIndex.matching` übergibt `hasSearchTerm: !query.isEmpty`; es gibt dort nur eine Aufrufstelle. Spaltenansicht und Favoriten rufen ohne `hasSearchTerm` auf. Der Freitext bleibt per Und außen vor.
- **33.4:** Der Chip „Ordner“ ist deaktiviert (`opacity(0.35)`, kein Hand-Cursor, nicht antippbar), sobald ein anderer Typ, eine Endung oder „Und“ gesetzt ist. Antippen eines anderen Typs entfernt `.folder`; `addCustomExtension` entfernt `.folder` ebenfalls. Im Popover steht kein Hinweistext.
- **33.5:** `AppSettings.showFoldersRegardlessOfFilter = true`, wird von `resetGeneral()` mit zurückgesetzt. Neuer Abschnitt „ORDNER WEITERHIN ANZEIGEN“ in Allgemein, nach der Scan-Tiefe. Wirkt nur in `ColumnBrowserView.filteredItems` (`foldersIgnoreTypeFilter:`): Ordner prüfen dann nur das Alter. Favoriten und Suche bleiben strikt.
- **Zur Laufzeit geprüft** (temporärer Hook, wieder entfernt), Tiefe 5+:
  - PDF allein 16 Treffer, „Letzter Monat“ allein 69, **Oder 80** (= 16 + 69 − 5), **Und 5**.
  - Mit Suchbegriff „rechnung“ ist Und wirkungslos (9 = 9).
  - Die Verknüpfung ist gesperrt mit Ordner (`effectiveCombineWithAnd` = false) und mit Suchbegriff.
  - Eine Endung entfernt „Ordner“.
  - Spaltenansicht Archiv-Wurzel mit Filter PDF: 4 Objekte mit „Ordner weiterhin anzeigen“, 0 strikt.
  - Filterleiste in Oder, Und und gesperrt als Bild gerendert, alle drei Zustände stimmen.
  - Hinweis: Ordner haben kein Datum und zählen deshalb beim Alter-Filter als passend („unbekanntes Datum schließt nicht aus“, wie vorgegeben).

Neuer dritter Button in der Filterleiste (nach dem Filter+✕-Kombi aus 24.2, mit demselben Abstand 8 wie die übrigen Elemente der Leiste): ein Link-Icon, das steuert, wie **Dateityp-Gruppe** (Kategorien + eigene Endungen aus Aufgabe 32, intern weiterhin per Oder verknüpft) und **Alter** zueinander stehen, wenn beide gesetzt sind.

- **Inaktiv = „Oder" (Standard):** Treffer passen zu mindestens einer der beiden Dimensionen.
- **Aktiv = „Und":** Treffer erfüllen beide Dimensionen.
- Ist nur eine der beiden Dimensionen gesetzt (oder keine), hat der Button keine Wirkung — er bleibt aber bedienbar.
- **Medium-Auswahl bleibt davon unberührt**, sie ist ein reiner Suchbereich und wirkt immer zusätzlich per Und (unverändert, `matchesMedium` bleibt eine eigene Prüfung).
- **Freitext** (Suchbegriff) wird **immer per Und mit dem Filterergebnis verbunden** — auch wenn Dateityp/Alter selbst per Oder verknüpft sind: `Suchbegriff UND (Filter ODER Filter)`. Das ist bereits so, weil der Text-Treffer separat per `&&` mit `SearchItemFilter.matches` kombiniert wird ([SearchIndex.swift:44-46](diskindex/diskindex/Models/SearchIndex.swift:44)) — daran nichts ändern, nur sicherstellen, dass die neue Und/Oder-Logik das nicht durchbricht.

### 33.1 Zustände & Deaktivierung des Buttons (Layout Sektion 08, „Verknüpfung" + Beispielzeile)
Drei Zustände, exakt nach Layout-Vorgabe (Button 27 × 27, `align-self: stretch`, Radius `DesignRadius.sm`, Icon 13 × 13, neues Template-Asset `IconLink` = Phosphor `link`, Pfad beginnt `M240,88.23a54.43,54.43,0,0,1-16,37…`):

| Zustand | Rand/Fläche | Icon | Tooltip (`.help`, identisch `accessibilityLabel`) |
|---|---|---|---|
| Oder (inaktiv, bedienbar) | Rand `neutral500`, Fläche `bg` | `text` | „Filter mit „Und" verknüpfen" |
| Und (aktiv) | Rand + Fläche `filterSearch` | Weiß | „Filter mit „Und" verknüpft" |
| Deaktiviert | wie Oder, zusätzlich `opacity(0.35)`, `cursor: .arrow`/kein Hand-Cursor | `text` | „Mit Suchbegriff oder Ordnern nicht verknüpfbar" |

**Deaktiviert, wenn:** `filters.fileTypes.contains(.folder)` **oder** (in der Suche) ein Suchbegriff aktiv ist (`searchState.submittedQuery`, getrimmt, nicht leer — der abgeschickte Begriff, nicht der Live-Text). In Spaltenansicht und Favoriten gibt es keinen Suchbegriff, dort zählt nur die erste Bedingung.

### 33.2 Modell ([SearchState.swift](diskindex/diskindex/Models/SearchState.swift))
- `SearchFilters.folderOnly` **entfernen** (totes Feld, wurde nirgends gesetzt, nur gelesen — siehe [SearchIndex.swift:97](diskindex/diskindex/Models/SearchIndex.swift:97); der aktive „Ordner"-Zustand läuft ausschließlich über `fileTypes.contains(.folder)`).
- Neu: `var combineWithAnd: Bool = false`.
- Neu: `func effectiveCombineWithAnd(hasSearchTerm: Bool) -> Bool { combineWithAnd && !fileTypes.contains(.folder) && !hasSearchTerm }` — **einzige** Stelle, die die tatsächliche Verknüpfung berechnet; sowohl die UI (Button-Zustand) als auch das Matching nutzen sie.

### 33.3 Matching ([SearchIndex.swift](diskindex/diskindex/Models/SearchIndex.swift), `SearchItemFilter.matches`)
Neuer Parameter mit Default, bestehende Aufrufer (Spaltenansicht, Favoriten) bleiben unverändert:

```swift
static func matches(_ item: IndexedItem, filters: SearchFilters, hasSearchTerm: Bool = false) -> Bool {
    let hasType = filters.hasFileTypeFilter
    let hasAge = filters.age != nil

    let typeOK: Bool = {
        guard hasType else { return true }
        let categoryOK = filters.fileTypes.contains { $0.matches(fileName: item.name, isFolder: item.isFolder) }
        let extensionOK = !item.isFolder && filters.customExtensions.contains { item.name.lowercased().hasSuffix($0) }
        return categoryOK || extensionOK
    }()

    let ageOK: Bool = {
        guard let age = filters.age, let date = item.modifiedAt else { return true } // unbekanntes Datum / kein Alter-Filter: schließt nicht aus
        return age.matches(date)
    }()

    guard hasType || hasAge else { return true }
    if hasType, hasAge {
        return filters.effectiveCombineWithAnd(hasSearchTerm: hasSearchTerm) ? (typeOK && ageOK) : (typeOK || ageOK)
    }
    return hasType ? typeOK : ageOK
}
```

In `SearchIndex.matching(query:filters:media:maxDepth:)`: an beiden Aufrufstellen von `SearchItemFilter.matches` (Zeile ~44) `hasSearchTerm: !query.isEmpty` übergeben (`query` dort ist bereits der getrimmte, abgeschickte Begriff). `ColumnBrowserView.filteredItems` und `FavoritesView` rufen weiterhin ohne den Parameter auf (Default `false`).

### 33.4 „Ordner" im Popover: gegenseitiger Ausschluss (Layout Sektion 09)
Layout-Text: „Sobald ein Dateityp oder eine Endung gesetzt ist, ist „Ordner" deaktiviert." In [SearchFilterPopover.swift](diskindex/diskindex/Views/Search/SearchFilterPopover.swift):
- Der Chip **„Ordner"** (`SearchFileTypeFilter.folder`) ist deaktiviert (nicht antippbar, `opacity(0.35)`, kein Hand-Cursor), wenn `!filters.fileTypes.subtracting([.folder]).isEmpty || !filters.customExtensions.isEmpty` **oder** `filters.combineWithAnd` aktiv ist (zweite Bedingung aus 33.1/Sektion 08 „Ordner im Popover nicht wählbar, solange „Und" aktiv ist").
- **Umgekehrt:** Wird eine andere Kategorie (≠ `.folder`) angetippt oder eine eigene Endung hinzugefügt, während `.folder` aktuell gewählt ist, wird `.folder` automatisch entfernt (`fileTypes.remove(.folder)`). So bleiben „Ordner" und echte Typen/Endungen nie gleichzeitig gesetzt.
- Kein zusätzlicher Text/Hinweis im Popover selbst (Regel [layout/CLAUDE.md](layout/CLAUDE.md)) — die Erklärung steht nur hier in der Aufgabe.

### 33.5 Neue Einstellung „Ordner weiterhin anzeigen" (Layout Sektion 09, Allgemein, Standard: an)
Layout-Text: „Ordner bleiben in der Spaltenansicht über die Einstellung „Ordner weiterhin anzeigen" (Allgemein, Standard: an) sichtbar, damit man sich zu den Treffern durchklicken kann; in der Suche wirkt der Filter strikt."
- `AppSettings.showFoldersRegardlessOfFilter: Bool = true` (Name frei wählbar, aber `resetGeneral()` setzt sie mit zurück).
- **Einstellungen → Allgemein** ([SettingsGeneralTab.swift](diskindex/diskindex/Views/Settings/SettingsGeneralTab.swift)): neuer Abschnitt „ORDNER WEITERHIN ANZEIGEN" nach der Scan-Tiefe-Sektion, gleicher Aufbau wie „Hinweis zu Online-Favoriten" (Titel + Beschreibung links, Checkbox rechts im Stil von „Mitteilung aktivieren"). Beschreibungstext (12 pt, `text.opacity(0.6)`): „Ordner bleiben in der Spaltenansicht auch dann sichtbar, wenn ein Dateityp- oder Endungs-Filter sie eigentlich ausschließen würde — so lässt sich zu den Treffern durchklicken. Die Suche filtert weiterhin strikt."
- **Wirkung nur in der Spaltenansicht** ([ColumnBrowserView.swift:87-94](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift:87), `filteredItems`): Ist die Einstellung an, wird ein Ordner nicht durch die Dateityp-Gruppe ausgeschlossen (er durchläuft trotzdem den Alter-Filter normal). Am einfachsten: in `filteredItems` für `item.isFolder && item.id nicht schon durch Ordner-Chip erfasst` das Ergebnis von `typeOK` durch `true` ersetzen, bevor die Und/Oder-Kombination greift — konkret z. B. ein zweiter, column-spezifischer Wrapper um `SearchItemFilter.matches`, der bei Ordnern nur den Alter-Teil prüft, wenn die Einstellung an ist. Ist sie aus, gilt die normale, strikte Logik aus 33.3 auch für Ordner in der Spaltenansicht.
- **Favoriten bleiben strikt** wie die Suche (keine Navigations-Notwendigkeit dort, kein Durchklicken zu tieferen Treffern) — diese Ausnahme gilt **nur** für die Spaltenansicht. Falls das nicht gewünscht ist, bitte zurückmelden.

**Prüfung:**
- Popover: „PDF" wählen → „Ordner" ausgegraut. „Ordner" allein wählen, dann „Bild" antippen → „Ordner" verschwindet aus der Auswahl, „Bild" ist gesetzt.
- Spaltenansicht, Filter „PDF" + Alter „Letzte 30 Tage", Verknüpfung „Oder": mehr Treffer als „Und". Umschalten auf „Und": nur PDFs der letzten 30 Tage.
- Verknüpfungs-Button in der Suche: bei gesetztem Suchbegriff ausgegraut, Tooltip nennt den Grund; Begriff löschen → wieder bedienbar.
- „Ordner weiterhin anzeigen" ausschalten: In der Spaltenansicht verschwinden Ordner, sobald ein echter Dateityp-Filter aktiv ist; in der Suche war das schon vorher so.
- „Auf Standard zurücksetzen" (Allgemein) setzt die neue Einstellung mit zurück.

---



---

# Nachtrag 29.09. — Aufgabe 34 (Code freigegeben)

Freigabe Claude 29.09.: Build ✅. `isCombineDisabled` sperrt den Verknüpfungs-Button jetzt korrekt, wenn nicht beide Dimensionen (Dateityp-Gruppe + Alter) gesetzt sind. Einzige geänderte Zeile, keine Nebenwirkungen.

## 34. Verknüpfungs-Button ohne Wirkung bleibt bedienbar (Nutzertest, Korrektur zu 33)

**Status:** Erledigt durch Cursor. `SearchFilters.isCombineDisabled(hasSearchTerm:)` sperrt den Button zusätzlich, wenn keine Dateityp-Gruppe oder kein Alter-Filter gesetzt ist (`!hasFileTypeFilter || age == nil`). `effectiveCombineWithAnd` und `SearchItemFilter.matches` unverändert; `combineWithAnd` wird beim Ausgrauen nicht zurückgesetzt. UI unverändert (`MainWindowFilterBar` ruft nur diese Funktion). Datei: `SearchState.swift`.

**Befund:** Mehrere eigene Dateiendungen gesetzt (z. B. `.psd` + `.indd`) oder mehrere Kategorien (z. B. „Archiv" + „Dokumente"), aber **kein** Alter-Filter — der Verknüpfungs-Button lässt sich trotzdem anklicken. Er bewirkt dabei nichts (innerhalb der Dateityp-Gruppe bleibt es immer Oder, das ist so gewollt), wirkt für den Nutzer aber wie ein funktionierender Schalter. Ursache: die eigene Spezifikation aus Aufgabe 33 („Ist nur eine der beiden Dimensionen gesetzt, hat der Button keine Wirkung — er bleibt aber bedienbar") — das war falsch, der Button darf in diesem Fall gar nicht erst bedienbar sein.

**Soll:** Der Verknüpfungs-Button ist nur aktiv, wenn **beide** Dimensionen gleichzeitig gesetzt sind: mindestens ein Dateityp/eine Endung **und** ein Alter-Filter. Fehlt eine der beiden, ist er ausgegraut — genau wie bei den beiden bestehenden Gründen (Ordner gewählt, Suchbegriff gesetzt).

In [SearchState.swift](diskindex/diskindex/Models/SearchState.swift), `SearchFilters.isCombineDisabled(hasSearchTerm:)` um die neue Bedingung erweitern (einzige Stelle, der Button in [MainWindowFilterBar.swift](diskindex/diskindex/Views/MainWindowFilterBar.swift) ruft nur diese Funktion auf, an der UI selbst ändert sich nichts):

```swift
func isCombineDisabled(hasSearchTerm: Bool) -> Bool {
    fileTypes.contains(.folder) || hasSearchTerm || !hasFileTypeFilter || age == nil
}
```

`effectiveCombineWithAnd(hasSearchTerm:)` und das Matching in `SearchItemFilter.matches` bleiben unverändert — sie liefern für den Fall „nur eine Dimension gesetzt" schon korrekt `false` bzw. ignorieren `combineWithAnd`, nur die UI-Sperre hat gefehlt.

**Prüfung:**
- Nur „.psd" + „.indd" gesetzt (kein Alter): Button ausgegraut.
- Nur „Archiv" + „Dokumente" gesetzt (kein Alter): Button ausgegraut.
- Nur ein Alter-Filter gesetzt (kein Typ): Button ausgegraut.
- Ein Dateityp **und** ein Alter-Filter zusammen: Button aktiv, verhält sich wie in Aufgabe 33 geprüft.
- War „Und" vorher aktiv und der Nutzer entfernt den Alter-Filter (oder den letzten Dateityp) wieder, bis nur eine Dimension übrig ist: Button wird ausgegraut, `combineWithAnd` darf dabei nicht zurückgesetzt werden (der gespeicherte Zustand kehrt zurück, sobald wieder beide Dimensionen gesetzt sind — wie bei Ordner/Suchbegriff schon jetzt).

---



---

# Nachtrag 30.09. — Nachbesserung Messwerkzeug K1–K6 (Code freigegeben)

Freigabe Claude 30.09.: K1 (CFUUID), K2 (Ziel je Zeile), K4 (Rauschen), K5 (Kandidatenregel) und K6 im Code bestätigt; Release enthält das Diagnosefenster nicht. Die Messung durch den Nutzer (Aufgabe 35) bleibt offen.

## Review Claude 30.09. — Nachbesserung Messwerkzeug (zu 35)

Erster Bericht des Nutzers (SD-Karte, Sandbox an) ausgewertet, Ergebnisse in [README.md](README.md) → „Messergebnisse Spike“. Das Werkzeug hat zwei Fehler und liefert zu viel Rauschen. Bitte nachbessern, danach misst der Nutzer weiter.

- **K1 DiskArbitration-UUID falsch gelesen:** `kDADiskDescriptionVolumeUUIDKey` liefert eine `CFUUID`. [VolumeListing.swift:147](diskindex/diskindex/Diagnostics/VolumeListing.swift:147) `uuidString(_:)` prüft aber nur `String`, `UUID` und `NSUUID`. Ergebnis: überall „—“, selbst für APFS. Ergänzen: Ist `CFGetTypeID(value as CFTypeRef) == CFUUIDGetTypeID()`, dann `CFUUIDCreateString(nil, value as! CFUUID) as String` zurückgeben.
- **K2 Abschnitt B nennt das Volume nicht:** Jede Zeile in B beginnt mit „Ziel: <Name> | <Pfad>“. Sonst lässt sich nicht sagen, wofür ein „Erfolg“ gilt (im ersten Bericht unklar). Ebenso in C, D und E.
- **K3 Kennungs-Kandidaten in A:** Je Kandidaten-Volume (Regel K5) zusätzlich protokollieren:
  - URL-Werte: `volumeCreationDateKey`, `volumeIdentifierKey` (Beschreibung), `volumeSupportsPersistentIDsKey`, `volumeLocalizedFormatDescriptionKey`.
  - `statfs`: `f_fsid` (beide Ganzzahlen).
  - DiskArbitration: `kDADiskDescriptionMediaUUIDKey`, `kDADiskDescriptionMediaNameKey`, `kDADiskDescriptionMediaContentKey`, `kDADiskDescriptionDeviceVendorKey`, `kDADiskDescriptionDeviceRevisionKey`, `kDADiskDescriptionDeviceModelKey`.
  - Zusätzlich `fileResourceIdentifierKey` der Wurzel und der ersten Datei (für die Frage, ob Datei-IDs auf FAT taugen).
- **K4 Rauschen:** Bei jedem Lauf gibt A alle DiskArbitration-Geräte erneut aus (rund 70 Zeilen je Lauf, meist interne Apple-Fabric-Geräte und APFS-Systemvolumes), und „OHNE UUID (DiskArbitration)“ wiederholt sie. Nur Kandidaten (K5) ausgeben, den Rest als eine Zeile „N interne Einträge ausgeblendet“. „OHNE UUID“ nur für Kandidaten.
- **K5 Kandidatenregel im Bericht:** Spalte „Kandidat: ja/nein“ nach der README-Regel: lokal, nicht `/`, nicht unter `/System/Volumes/`, nicht `autofs`, und (wechselbar **oder** auswerfbar **oder** nicht intern). Für die SD-Karte muss „ja“ herauskommen.
- **K6 Auswerfen protokollieren:** `willUnmount`/`didUnmount` und DiskArbitration „verschwunden“ erscheinen im Protokoll mit Zeitstempel und Pfad (im ersten Bericht fehlten sie, weil nichts ausgeworfen wurde). Kurzer Hinweis im Fenster, dass dafür ausgeworfen werden muss.

**Status:** Erledigt durch Cursor. K1: DiskArbitration-UUID über `CFUUIDGetTypeID` / `CFUUIDCreateString` (`unsafeBitCast` statt `as!`, gleiche Umwandlung, ohne Warnung). K2: jede Zeile in B–E beginnt mit `Ziel: Name | Pfad`. K3: bei Kandidaten zusätzlich Erstelldatum, `volumeIdentifier`, persistente IDs, Format, `statfs.f_fsid`, Media-UUID/Name/Content, Vendor, Revision, Modell, Datei-ID der Wurzel und der ersten Datei. K4: nur Kandidaten im Protokoll, der Rest als „N interne Einträge ausgeblendet“; „OHNE UUID“ nur für Kandidaten (Null-UUID zählt als keine). K5: Spalte `Kandidat=ja/nein` (lokal, nicht `/`, nicht unter `/System/Volumes/`, nicht `autofs`, wechselbar oder auswerfbar oder nicht intern). K6: `willUnmount`/`didUnmount` und DiskArbitration „verschwunden“ bleiben im Protokoll; Hinweis im Fenster, dass dafür ausgeworfen werden muss. `xcodebuild` Debug erfolgreich. Noch vom Nutzer zu messen: Zugriff ohne Sandbox, C, D, Auswerfen.

---



---

# Nachtrag 30.09. — Aufgaben 35 (Technik-Spike) und 36 (Speicher, SQLite) samt K7 (Code freigegeben)

Freigabe Claude 30.09.: Debug- und Testlauf grün (9 Tests). Spike vom Nutzer an einer SD-Karte (FAT32) mit und ohne Sandbox gemessen, Ergebnisse in README → „Messergebnisse Spike“. Wichtigste Folgen: Sandbox wird ausgeschaltet (Weg A), Kennung für FAT über Erstelldatum statt UUID (Aufgabe 37).

## Review Claude 30.09. — Korrektur zu 36

Debug-Build und alle 9 Tests geprüft. Datenbank, Schema, Tombstones, Suche (FTS ab 3 Zeichen, darunter `LIKE`) und die SQL-Spiegelung von Dateityp-, Alter- und Verknüpfungslogik sind sauber umgesetzt. Ein Punkt bleibt:

- **K7 (36.3) Leistungstest ist wackelig:** `insertingTwoHundredThousandEntriesStaysFast` hat eine feste Grenze von 5 s für das Einfügen. Gemessen: 2,98 s bei Cursor, 4 s bei mir im vollen Testlauf und **13 s** bei parallel laufendem Build (Test schlug fehl, Einzellauf danach grün). Als Rauchtest darf er nicht von der Rechnerlast abhängen.
  - Grenze für das Einfügen auf **20 s**, für die Suche auf **500 ms**. Es geht nur darum, Größenordnungsfehler (Minuten statt Sekunden) zu finden.
  - Die tatsächlich gemessene Dauer zusätzlich ausgeben (`print` oder Testanhang), damit Verschlechterungen sichtbar bleiben.

**Status:** Erledigt durch Cursor. `insertingTwoHundredThousandEntriesStaysFast`: Einfügen unter 20 s, Suche unter 500 ms. Die gemessene Dauer geht per `print` ins Testprotokoll und als Anhang `indexstore-smoke.txt` in den Testbericht. Dieser Lauf: Einfügen 15,757 s, Suche 0,019 s (unter der alten Grenze von 5 s wäre er rot gewesen). Alle 9 Tests grün, keine Warnungen.

---

## 35. Technik-Spike Indexierung (nur Debug, Messung am echten Gerät)

**Status:** Erledigt durch Cursor. Debug-Fenster „Diagnose: Indexierung…“ im Rechtsklick-Menü (nur Debug), rohes `NSWindow` über `AppWindowPresenter.openIndexDiagnostics()` ohne `setActivationPolicy`. Abschnitte A–E unter `diskindex/diskindex/Diagnostics/` (`#if DEBUG`): Volumes + NSWorkspace + DiskArbitration, Zugriff mit Sandbox-Flag und Fehlerdetails, ebenenweiser Scan, FSEvents mit Stand in UserDefaults, SQLite3 mit synthetischen Zeilen. Bericht in UserDefaults und per „Bericht kopieren“ in die Zwischenablage. `INFOPLIST_KEY_NSRemovableVolumesUsageDescription` in Debug und Release. Sandbox bleibt an.

Ohne Gerät geprüft: `SQLiteSpike.run` direkt (dieselbe Datei, nicht das Fenster, nicht ein externes Medium), sqlite 3.43.2, fts5 und trigram ja, WAL. 100 000 Zeilen: Insert 0,079 s (1 264 268 Zeilen/s), Indizes 0,057 s, FTS-Aufbau 0,109 s. 1 000 000 Zeilen: Insert 0,771 s (1 296 598 Zeilen/s), Indizes 0,586 s, FTS-Aufbau 1,403 s. FTS „foto“/„rechn“ trifft, FTS „ab“ 0 Treffer, LIKE „ab“ trifft (100 000: 5 000, 1 000 000: 50 000). Abfragen unter 1 ms erscheinen als 0,000 s. A–D und der Systemdialog sind nicht gemessen.

Lauf ohne Sandbox (Nutzer): Xcode → Target diskindex → Signing & Capabilities → App Sandbox entfernen → neu starten → Abschnitt B erneut. Danach App Sandbox wieder aktivieren. Dialog wiederholen: `tccutil reset SystemPolicyRemovableVolumes xjonx.diskindex`. Feld „Systemdialog erschienen“ im Fenster ausfüllen. `xcodebuild` Debug und Release erfolgreich, keine Swift-Warnungen in den neuen Dateien. Die Release-Binary enthält „Diagnose: Indexierung“ nicht. Der AppIntents-Metadaten-Schritt meldet weiterhin „Metadata extraction skipped“ (kein AppIntents-Framework).

**Ziel:** Antworten auf die offenen Technikfragen aus [README.md](README.md) → „Technische Grundlagen und Empfehlung", gemessen am echten Gerät. **Kein Produktcode:** Alles hinter `#if DEBUG`, kein Anschluss an `AppState`, keine Design-Vorgaben für das Diagnosefenster (Systemcontrols, schlicht). Die Ergebnisse entscheiden über Sandbox und Bauweise der Aufgaben 36 bis 40.

**Zugang:** Im Rechtsklick-Menü des Menüleisten-Icons (nur Debug) ein Eintrag „Diagnose: Indexierung…". Er öffnet ein eigenes Fenster über den bestehenden Presenter-Mechanismus (`AppWindowPresenter`, rohes `NSWindow`). Inhalt:
- Liste der eingebundenen Volumes (Abschnitt A) mit Auswahl,
- je Test (B bis E) ein Knopf und ein Textfeld für das Live-Protokoll,
- Knopf „Bericht kopieren": legt den gesamten Bericht als Markdown in die Zwischenablage (Speichern in eine Datei geht in der Sandbox nicht, `ENABLE_USER_SELECTED_FILES` ist nur lesend). Zusätzlich jede Zeile per `Logger` ausgeben.

**Vorbereitung (auch fürs Produkt nötig):** Im App-Target (Debug und Release) `INFOPLIST_KEY_NSRemovableVolumesUsageDescription = "Disk Index liest Namen und Ordnerstruktur externer Speichermedien, um sie zu indizieren und offline durchsuchbar zu machen."` setzen. Ohne diesen Schlüssel kann macOS den Wechseldatenträger-Dialog nicht sauber zeigen.

### A. Volumes und Ereignisse
- Alle eingebundenen Volumes auflisten: `FileManager.mountedVolumeURLs` mit den Schlüsseln Name, `volumeUUIDStringKey`, intern/extern/wechselbar/auswerfbar/lokal, Gesamt- und freie Kapazität, Dateisystemtyp (z. B. über `statfs` → `f_fstypename`).
- **Live-Protokoll der Ereignisse** `NSWorkspace.didMountNotification`, `willUnmountNotification`, `didUnmountNotification` (Zeitstempel, Pfad). Der Nutzer steckt dabei Medien an und zieht sie ab.
- **Zusätzlich DiskArbitration** (`DARegisterDiskAppearedCallback`, `DARegisterDiskDisappearedCallback`, `DADiskCopyDescription`): je Datenträger protokollieren: Volume-UUID, Volume-Art (Dateisystem), Geräteprotokoll (USB, SATA, NVMe …), intern, wechselbar, auswerfbar, Modell, Medium-Größe. Nur Einträge mit Einhängepfad sind Volumes; die übrigen (ganze Geräte) markieren, nicht weglassen.
- **Bericht:** Je Volume eine Zeile mit allen Werten. Markiere Volumes ohne UUID und Volumes mit gleicher UUID (Klone).

### B. Zugriff (Sandbox und Systemdialog)
- Für das gewählte Volume das Wurzelverzeichnis lesen (`contentsOfDirectory`). Protokollieren: Erfolg oder Fehler mit Domain, Code, POSIX-Fehler (`errno`), Dauer.
- Zusätzlich `sandboxed: ja/nein` (Umgebungsvariable `APP_SANDBOX_CONTAINER_ID` vorhanden).
- **Zusätzlich** den ersten Lesezugriff einmal ohne Sandbox testen: Das geschieht durch den Nutzer, indem er in Xcode unter Signing & Capabilities „App Sandbox" entfernt und neu startet. Cursor beschreibt die Schritte im Status. Beide Läufe gehören in den Bericht.
- Für die Wiederholung des Dialogs: `tccutil reset SystemPolicyRemovableVolumes xjonx.diskindex` (Kommando im Fensterhinweis als Text anzeigen).
- Cursor kann das Verhalten nicht selbst sehen (Systemdialog erscheint nur auf dem Gerät des Nutzers). Im Bericht gibt es dafür ein Feld „Systemdialog erschienen: ja/nein/wann" zum Nachtragen durch den Nutzer.

### C. Scan-Leistung (ebenenweise)
- Breitenweiser Scan des gewählten Volumes bis zur Ebene *N* (Eingabe 1 bis 5, Standard 3), abbrechbar. **Genau die Vorgehensweise der README:** Ebene 1 vollständig lesen, dann Ebene 2 usw. Keine Rekursion in die Tiefe.
- Je Ordner `contentsOfDirectory(at:includingPropertiesForKeys:options:)` mit vorab geladenen Schlüsseln: Name, `isDirectory`, `isPackage`, `fileSize`, `contentModificationDate`, `fileResourceIdentifier`. Symlinks nicht folgen. Ausgeschlossen: `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `.TemporaryItems`, `.DocumentRevisions-V100`.
- Nichts speichern außer Zählern. Protokoll je Ebene: Anzahl Objekte, Anzahl Ordner, Dauer, Objekte pro Sekunde. Am Ende die Summen. Läuft abseits des Hauptthreads (Aufgabe mit niedriger Priorität, `.utility`); die Oberfläche bleibt bedienbar.
- **Richtwert für die Auswertung:** Unter ca. 5 000 Objekten pro Sekunde auf einer HDD lohnt sich später ein Umstieg auf `getattrlistbulk`. Das ist **nicht** Teil des Spikes.

### D. Änderungserkennung (FSEvents)
- Auf dem gewählten Volume einen FSEvents-Strom starten, **dateigenau** (`kFSEventStreamCreateFlagFileEvents`), Verzögerung 1 Sekunde. Live-Protokoll: Pfad, Ereignis-ID, Flags (lesbar, z. B. angelegt/entfernt/umbenannt/geändert, `MustScanSubDirs`, `HistoryDone`, `RootChanged`, `Mount`, `Unmount`).
- Beim Start protokollieren: `stat.st_dev` des Volumes, `FSEventsCopyUUIDForDevice`, `FSEventsGetCurrentEventId`.
- **Nachspielen:** Beim Stoppen und beim Abziehen (`willUnmount`) die zuletzt gesehene Ereignis-ID und die UUID in `UserDefaults` sichern. Beim nächsten Start für dasselbe Volume `sinceWhen = gespeicherte ID` verwenden und protokollieren, wie viele Ereignisse nachgespielt werden und wann `HistoryDone` kommt. Vorher UUID vergleichen und den Vergleich protokollieren.
- **Testablauf (für den Nutzer, im Fenster als Text):** Strom starten. Im Finder eine Datei anlegen, umbenennen, löschen. Strom stoppen, Medium auswerfen, wieder anstecken, Strom mit gespeicherter ID starten. Optional: Medium an einem anderen Rechner ändern (Datei anlegen), dann prüfen, ob das Nachspielen sie zeigt (erwartet: nein).

### E. Speicher (SQLite)
- Systemeigenes SQLite über `import SQLite3` (**keine** Fremdbibliothek im Spike). Datei im temporären Ordner der App.
- Ausgabe von `sqlite_version()` und ob `fts5` sowie der Tokenizer `trigram` verfügbar sind (Fehlermeldung protokollieren, falls nicht).
- Schema wie in der README skizziert (`medium`, `item` mit Indizes auf Medium+Eltern und Änderungsdatum). **Synthetische Daten,** Anzahl wählbar (100 000 / 1 000 000): Namen aus Wortlisten, Tiefe 1 bis 6.
- Messen und protokollieren: Einfügen in Stapeln von 5 000 je Transaktion (Zeilen pro Sekunde), Aufbau des FTS5-Trigram-Index, Dauer für die Suchen „foto", „rechn" und „ab" (nur zwei Buchstaben, dann Ausweichen auf `LIKE`), jeweils mit FTS und mit `LIKE '%…%'` ohne Index. Zusätzlich Abfrage „Kinder eines Ordners" (Medium+Eltern) und „alle mit Änderungsdatum der letzten 30 Tage".

### Abnahme (Cursor liefert, Nutzer misst)
- Alles baut, Debug und Release, keine Warnungen. Release enthält weder Menüeintrag noch Diagnosefenster.
- Cursor trägt im Status ein: Was wurde gebaut, was konnte **ohne** Gerät geprüft werden (z. B. Bericht mit synthetischen Daten aus E), und was fehlt zur Messung. **Keine erfundenen Messwerte.**
- Der **Nutzer** führt danach die Tests A bis D mit möglichst unterschiedlichen Medien durch (soweit vorhanden): APFS oder HFS+, exFAT oder FAT32, NTFS, ein USB-Stick, eine externe HDD, eine externe SSD, eine SD-Karte. Er kopiert je Lauf den Bericht in den Chat. Daraus entscheidet Claude Sandbox-Weg, Volume-Kennung und Umfang des FSEvents-Nachspielens.

---

## 36. Speicher: SQLite-Datenbank und `IndexStore` (noch ohne Anschluss an die Oberfläche)

**Status:** Erledigt durch Cursor. Ordner `diskindex/diskindex/Storage/`: `IndexDatabase` (Pool, WAL, `foreign_keys`, `synchronous = NORMAL`, Migration `v1`), `IndexStore` (Actor), Datensätze `ScannedEntry`, `VolumeIdentity`, `StoredMedium`, `StoredItem`. Datei `Application Support/Disk Index/index.sqlite`. Oberfläche und Diagnosefenster unverändert. GRDB 7.11.1 nur am App-Target; das Test-Target nutzt `@testable import` und den Testhost, kein eigener Paketverweis. Abweichungen: Eindeutigkeit der Wurzel über `ifnull(parentID, 0)`, weil SQLite NULL im UNIQUE-Constraint nicht zusammenfasst. Null-UUID wird als NULL gespeichert, der Vergleich ist kleingeschrieben. Neue Zeilen landen je Ebene mit einem `INSERT … SELECT` im FTS-Index; Änderung und Löschen bleiben Trigger. Ein Trigger je Insert lag bei 200 000 Zeilen über 5 s (5,35 s), der Stapel im Test bei 2,98 s inklusive Suche „rechn“. `SearchFilters` und die beiden Filter-Enums sind `nonisolated`/`Sendable`, damit der Actor sie nehmen kann. Unter XCTest überspringt die App Einzelinstanz und Launch-Agent, sonst beendet eine zweite Kopie den Testhost. `xcodebuild test` Debug: 9 Tests grün, keine Warnungen. Release-Build ohne Warnungen.

Erster Baustein des echten Indexings, unabhängig von Sandbox-Entscheidung und Medienzugriff (die Datenbank liegt im Application-Support-Ordner der App und funktioniert mit und ohne Sandbox). Die bestehende Oberfläche bleibt **unverändert auf den Mock-Daten**; der Anschluss folgt in Aufgabe 40. Konzept: [README.md](README.md) → „Speicherung“ und „Änderungen, Löschen, Wiederherstellen“.

**Voraussetzung (macht der Nutzer, ca. eine Minute):** GRDB.swift als Swift-Paket hinzufügen: Xcode → File → Add Package Dependencies → `https://github.com/groue/GRDB.swift` → Regel „Up to Next Major Version“ ab 7.0.0 → Produkt `GRDB` dem Target `diskindex` (und dem Test-Target, falls dort `@testable import diskindex` genutzt wird) zuweisen. Fehlt das Paket, die Aufgabe **nicht** beginnen, sondern im Status melden. Die `.xcodeproj` nicht von Hand um Paketverweise erweitern.

### 36.1 Datenbank
- Datei `index.sqlite` in `Application Support/Disk Index/` (Ordner bei Bedarf anlegen). `DatabasePool`, WAL, `foreign_keys = ON`, `synchronous = NORMAL`.
- Schema per `DatabaseMigrator`, Migration `v1`. Tabellen:
  - **`medium`:** `id` INTEGER PK, `uuid` TEXT UNIQUE (die stabile App-ID, entspricht `Medium.id`), `volumeUUID` TEXT NULL (nur nicht-Null-UUIDs, siehe README „Kennung“), `fsType`, `volumeTotalBytes`, `diskSizeBytes` NULL, `name`, `type` (usb/ssd/hdd), `decision` (`undecided`/`index`/`ignore`), `rememberDecision`, `indexStatus`, `allowIndexing`, `autoIndexPaused`, `capacityUsedBytes`, `fileCount`, `folderCount`, `lastSeenAt`, `firstIndexedAt`, `lastIndexedAt`, `isForgotten`, `showAbsoluteCapacity`, `isFavorite`, `fsEventsUUID` NULL, `lastEventID` NULL, `completedDepth` (letzte vollständig gelesene Ebene, Standard 0), `createdAt`.
  - **`item`:** `id` INTEGER PK, `mediumID` FK (`ON DELETE CASCADE`), `parentID` NULL (Ebene 1 = NULL), `name`, `isFolder`, `isPackage`, `ext` (klein, ohne Punkt, NULL bei Ordnern), `sizeBytes` NULL, `modifiedAt` NULL, `fileID` TEXT NULL (Datei-ID des Dateisystems), `depth` (1 = oberste Ebene des Mediums), `path` (z. B. `/Projekte/Kunde B/`, mit Schrägstrich am Ende, immer mitgespeichert), `lastSeenAt`, `removedAt` NULL, `isFavorite`.
  - **Eindeutig:** `(mediumID, parentID, name)`. Ein Objekt, das wieder auftaucht, **nutzt seine Zeile weiter** (Favorit bleibt).
  - **Indizes:** `(mediumID, parentID)`, `(mediumID, removedAt)`, `(mediumID, path)`, `modifiedAt`, `ext`.
  - **`item_fts`:** FTS5, extern zu `item`, Spalte `name`, `tokenize='trigram'`, per Triggern (oder `synchronize(withTable:)`) aktuell gehalten.
- Kein SwiftData, kein Core Data.

### 36.2 `IndexStore` (Swift-`actor`, nur diese Schnittstelle kennt GRDB)
Sprechende, kleine Schnittstelle, alle Methoden `async`, keine GRDB-Typen nach außen:
- **Medien:** `upsertMedium(_:)`, `media()`, `medium(uuid:)`, `updateMedium(uuid:_:)`, `candidates(for identity: VolumeIdentity)` (liefert Kandidaten nach README „Kennung“: erst `volumeUUID`, sonst Dateisystem + Volume-Größe; der Namensvergleich mit der obersten Ebene folgt in Aufgabe 37), `forgetMedium(uuid:)` (`isForgotten`, Daten bleiben).
- **Lesen einer Ebene:** `applyDirectory(mediumUUID:, parentID:, entries: [ScannedEntry], seenAt:)` in **einer Transaktion**: Einträge einfügen oder aktualisieren (nach `(medium, parent, name)`), alle **anderen** vorhandenen Kinder desselben Ordners mit `removedAt = seenAt` markieren und **deren Unterbaum** ebenfalls (`UPDATE … WHERE path LIKE :prefix || '%'`). Tauchen sie später wieder auf, `removedAt` auf NULL setzen.
- **Ebene abschließen:** `completeLayer(mediumUUID:, depth:)` setzt `completedDepth` (nur vorwärts) und aktualisiert `fileCount`/`folderCount`/`lastIndexedAt`.
- **Abfragen:** `children(mediumUUID:, parentID:)` (Ordner zuerst, dann Name), `item(id:)`, `search(query:, filters:, limit:)` (Namenssuche: ab 3 Zeichen über FTS, darunter `LIKE`; Filter Dateityp, Endung, Alter, Medium wie in `SearchFilters`; `removedAt IS NULL`), `setFavorite(itemID:_:)`, `favorites()`.
- **Nie hart löschen** außer `DELETE` des ganzen Mediums (`ON DELETE CASCADE`), das es vorerst nur für Tests gibt.

`ScannedEntry` (Name, Ordner ja/nein, Paket ja/nein, Größe, Änderungsdatum, Datei-ID) und `VolumeIdentity` (`volumeUUID?`, `fsType`, `volumeTotalBytes`, `diskSizeBytes?`, `name`) als einfache `struct`s.

### 36.3 Tests (Test-Target, temporäre Datenbankdatei je Test)
- Migration erzeugt alle Tabellen und Indizes.
- `applyDirectory` zweimal mit gleichen Einträgen: keine Duplikate, gleiche `id`s.
- Datei fehlt beim zweiten Lauf → `removedAt` gesetzt; erscheint wieder → `removedAt` NULL, **`isFavorite` bleibt**.
- Ordner fehlt → sein ganzer Unterbaum ist `removedAt`-markiert; kommt zurück → Unterbaum wieder da, sobald die Ordner gelesen werden.
- `children`-Reihenfolge, `completeLayer` läuft nie rückwärts.
- Suche: „foto“ (FTS), „ab“ (LIKE), Groß-/Kleinschreibung egal, entfernte Objekte fehlen.
- Kandidatensuche: Medium mit UUID, Medium ohne UUID (FAT), Null-UUID zählt als „keine“.
- Leistung, Rauchtest: 200 000 Einträge in Ebenen zu je 5 000 einfügen dauert unter 5 s; Suche „rechn“ unter 100 ms.

### 36.4 Abgrenzung
Nicht Teil dieser Aufgabe: Anschluss an `AppState`/Oberfläche, Entfernen der Mock-Daten, Scanner, Medienerkennung, FSEvents. Das Diagnosefenster (Aufgabe 35) und `SQLiteSpike` bleiben unverändert. Keine neue Design-Arbeit.

**Abnahme:** Debug und Release bauen ohne Warnungen (auch keine Swift-6-Warnungen zu `Sendable`/Isolation in den neuen Dateien), alle Tests grün, Ordner `Storage/` mit klarer Trennung (`IndexDatabase`, `IndexStore`, Datensätze). Im Status: Was ist gebaut, welche Abweichungen, was blieb offen.

---



---

# Nachtrag 30.09. — Aufgaben 37 (Kennung im Speicher), 38 (Medienerkennung, Zugriffsprobe, Dialog) und K1 (Code freigegeben)

Freigabe Claude 30.09.: Debug und Release ohne Warnungen, 24 Tests grün. Nicht am Gerät geprüft (Prüfung durch den Nutzer): macOS-Dialog „Wechseldatenträger“ beim ersten Zugriff aus dem Finder, erneutes Anstecken ohne Dialog, Abziehen ohne Auswerfen, Ablehnen und späteres Freigeben. Ergebnisse dazu fließen in Aufgabe 39 ein.

## Review Claude 30.09. — Korrektur zu 38

Debug- und Release-Build ohne Warnungen, alle 23 Tests grün, Kandidatenregel, Monitor, Zugriffsprobe, Kennungsregeln (37) und die Brücke zur Oberfläche gelesen und in Ordnung. **Ein Fehler** im Ablauf:

- **K1 (38.4) Bekanntes Medium mit verweigertem Zugriff öffnet den Dialog:** Wird bei `.denied` das Medium mit `decision = .undecided` und `indexStatus = .error` gespeichert und danach **abgezogen und wieder angesteckt**, erkennt `volumeAppeared` es als bekannt (Treffer `.uuid`/`.fingerprint`) und ruft `connectKnown` auf. Dort steht `if fresh.decision == .undecided { requestDialog(...) }` **ohne erneute Zugriffsprobe**. Ergebnis: Der Dialog „Neues Speichermedium erkannt“ erscheint für ein Medium, das die App gar nicht lesen darf; „Indizieren“ führte dann in einen Zustand, der nicht funktioniert. Die Aufgabe verlangte „Kein Dialog“ und eine erneute Probe bei jedem Anschließen. Nur die App-Aktivierung (`reprobeDeniedVolumes`) ist umgesetzt.
  - **Soll:** In `connectKnown` vor allem anderen: Ist `stored.indexStatus == .error`, zuerst `access.probe(volume)`. `.denied` → Zustand Fehler beibehalten (Zeile „Kein Zugriff …“), `lastSeenAt` und Verbindung aktualisieren, **kein Dialog**, Ende. `.granted` → `indexStatus = .pending`, dann weiter wie bisher (bei `decision == .undecided` Dialog).
  - Das gilt später auch für Medien, deren Zustand `.error` durch Lesefehler beim Scan entstand (Aufgabe 39): Sie werden beim Anschließen ebenfalls erst erneut geprobt.
  - **Test ergänzen** in `MediumCoordinatorTests`: (a) unbekannt + `.denied` → abziehen → wieder anstecken, Probe weiter `.denied` → **kein** Dialog, Zustand bleibt Fehler. (b) danach Probe `.granted` beim erneuten Anstecken → Dialog, Zustand `pending`.

**Status:** Erledigt durch Cursor. `connectKnown` prüft bei `indexStatus == .error` zuerst die Zugriffsprobe. Bleibt sie verweigert, bleiben Zustand Fehler und „Kein Zugriff …“, `lastSeenAt` und Verbindung werden aktualisiert, kein Dialog. Klappt sie, wird der Zustand `pending` und bei `decision == .undecided` der Dialog geöffnet. Neuer Test `deniedKnownMediumStaysClosedUntilAccessIsGranted`: abziehen und wieder anstecken bei weiter verweigertem Zugriff öffnet nichts; die nächste Probe mit Zugriff öffnet den Dialog.

---

## 37. Kennung im Speicher an die Messungen anpassen (Nachtrag zu 36)

**Status:** Erledigt durch Cursor. `volumeCreatedAt` in Migration `v1`, `VolumeIdentity.createdAt` (1970-01-01 und 1980-01-01 UTC sowie Null-UUID werden `nil`). `candidates(for:)` liefert `MediumCandidate` mit `MatchStrength` (`.uuid`, `.fingerprint`, `.weak`), sortiert nach Stärke. `recordIdentity` trägt fehlende UUID und fehlendes Erstelldatum nach und überschreibt vorhandene Werte nicht. Vorhandene `index.sqlite` unter Application Support und im alten Sandbox-Container gelöscht. Tests a–g ersetzen den alten Kandidatentest. Abweichung: mehrere gleich starke Treffer werden nicht automatisch zu einem Medium vermischt.

Zwei Medien gemessen (README → „Vierter“ und „Fünfter Bericht“, „Kennung, endgültiger Entwurf“): Bei FAT hat ein USB-Stick eine feste **Version-3-UUID** (aus der Seriennummer abgeleitet), die SD-Karte eines Aufnahmegeräts die **Null-UUID**. `volumeIdentifier` und Datei-IDs wechseln bei jeder Einbindung, das Erstelldatum bleibt gleich. Die UUID kommt aus **DiskArbitration**, nicht aus dem URL-Schlüssel (der lieferte einmal eine Zufalls-UUID).

- **Schema:** In `medium` neue Spalte `volumeCreatedAt` (Datum, NULL erlaubt). Migration `v1` direkt anpassen, es gibt noch keine Nutzdaten. Eine eventuell vorhandene `index.sqlite` unter `Application Support/Disk Index/` einmal löschen.
- **`VolumeIdentity`:** Neues Feld `createdAt: Date?`. Ein Datum, das fehlt oder genau `1980-01-01 00:00:00` oder `1970-01-01 00:00:00` (UTC) ist, wird zu `nil` normalisiert. Die Null-UUID wird zu `nil` normalisiert (das ist schon so, beibehalten).
- **Vertrauen:** Die UUID zählt bei **allen** Dateisystemen, wenn sie nicht Null ist. Es gibt keine Sonderregel „nur apfs/hfs“.
- **`candidates(for:)`:** Gibt die **Vereinigung** aller Treffer zurück, jeweils mit Stärke `MatchStrength`:
  - Haben beide Seiten eine UUID: gleiche UUID → `.uuid`. **Verschiedene UUIDs → kein Kandidat**, auch wenn Dateisystem, Größe und Erstelldatum gleich sind.
  - Fehlt auf mindestens einer Seite die UUID: gleiches Dateisystem **und** gleiches Erstelldatum (auf die Sekunde) **und** gleiche Volume-Größe in Bytes → `.fingerprint`.
  - Fehlt auf mindestens einer Seite das Erstelldatum (und die UUID): gleiches Dateisystem, gleiche Größe und gleicher Name → `.weak`.
  - Sortiert nach Stärke. Ein Fingerabdruck ohne Erstelldatum wird nie `.fingerprint`.
- **Nachtragen:** Neue Methode `recordIdentity(mediumUUID:_ identity:)`. Sie ergänzt am Medium `volumeUUID` und `volumeCreatedAt`, wenn sie dort fehlen, und überschreibt vorhandene Werte nicht mit anderen.
- **Tests** (den Test `candidatesMatchUUIDOrFingerprintAndTreatNullUUIDAsNone` ersetzen):
  - (a) SD-Karte mit Null-UUID findet dasselbe Medium über `.fingerprint`, obwohl `volumeIdentifier` wechselt.
  - (b) Zwei FAT-Medien gleicher Größe mit verschiedenem Erstelldatum sind zwei Medien.
  - (c) Zwei Sticks mit gleichem Dateisystem, gleicher Größe und gleichem Erstelldatum, aber **verschiedenen UUIDs**, sind zwei Medien.
  - (d) Gleiche UUID, anderer Name (umbenannt) → `.uuid`.
  - (e) Stick ohne UUID gespeichert, später erscheint eine UUID → Treffer über `.fingerprint`, `recordIdentity` trägt die UUID nach.
  - (f) Kein Erstelldatum (oder 1980-01-01) → nur `.weak`.
  - (g) Zwei gespeicherte Medien mit gleichem Fingerabdruck liefern beide Kandidaten (die Entscheidung liegt beim Aufrufer).

**Abnahme:** Debug und Release bauen ohne Warnungen, alle Tests grün. Oberfläche und Diagnosefenster bleiben unverändert.

---

## 38. Medienerkennung, Zugriffsprobe und Dialog „Neues Speichermedium erkannt“ (ohne Sandbox)

**Status:** Erledigt durch Cursor. `ENABLE_USER_SELECTED_FILES` entfernt, Sandbox war schon `NO`, Hardened Runtime bleibt an. Neu unter `Recognition/`: `VolumeCandidateRule`, `VolumeInfo`, `VolumeLookup`, `DiskArbitrationLookup`, `MediumAccess`/`DirectMediumAccess`, `MediumMonitor`, `MediumCoordinator`. Start in `AppDelegate` über `IndexStore.openDefault()`; schlägt das fehl, läuft die App ohne Erkennung weiter. Bekannte Medien (genau ein `.uuid`- oder `.fingerprint`-Treffer) ohne Dialog, Unbekannte nach gelungener Probe mit Dialog, bei Fehler `indexStatus = .error` und die zweite Zeile „Kein Zugriff, in den Systemeinstellungen freigeben“ (Karte und Popover; gilt auch für das bisherige Fehler-Medium in den Testdaten). Entscheidung im Dialog schreibt `decision` und `rememberDecision`; „Indizieren“ lässt `pending` und ruft `onIndexRequested` einmal. Testdaten bleiben, echte Medien kommen zusätzlich in `AppState` (`TODO Aufgabe 41`). Im Test wird das Panel nicht geöffnet, nur `newMediumDialogMediumID` gesetzt. 23 Tests grün, Debug und Release ohne Warnungen. Nicht am Gerät geprüft: macOS-Dialog „Wechseldatenträger“, erneutes Anstecken, Ablehnen der Freigabe.

Zweiter Baustein des echten Indexings. Konzept: [README.md](README.md) → „Ablauf beim Anschließen“, „Kennung, endgültiger Entwurf“, „Berechtigung und Vertrieb“. **Entscheidung Nutzer 30.09.: ohne App-Sandbox.** Bitte nach Aufgabe 37 beginnen. Ein Medium kommt nur bis in den Speicher und bis zum Dialog, **gelesen (gescannt) wird noch nichts**. Das folgt in Aufgabe 39.

### 38.1 Projekt ohne Sandbox
- Im App-Target (Debug und Release): `ENABLE_APP_SANDBOX = NO`, `ENABLE_USER_SELECTED_FILES` entfernen. **Hardened Runtime bleibt an.** `INFOPLIST_KEY_NSRemovableVolumesUsageDescription` bleibt (der macOS-Dialog „Wechseldatenträger“ nutzt den Text).
- Folgen prüfen: Die Datenbank liegt jetzt in `~/Library/Application Support/Disk Index/` (kein Container). Einzelinstanz, Launch Agent und Diagnosefenster laufen weiter. Das Diagnosefenster zeigt „sandboxed: nein“.

### 38.2 Schnittstelle `MediumAccess` (Naht für eine spätere App-Store-Variante)
Eine kleine Schnittstelle, damit der Rest der App nicht weiß, **wie** der Zugriff zustande kommt:
```swift
protocol MediumAccess: Sendable {
    func probe(_ volume: VolumeInfo) async -> MediumAccessResult   // .granted oder .denied(reason)
}
```
Einzige Implementierung jetzt: `DirectMediumAccess`. Sie versucht, das Wurzelverzeichnis zu lesen (`contentsOfDirectory`), `.granted` bei Erfolg, `.denied` bei Fehler (`NSCocoaErrorDomain` 257 / POSIX 1) und beschreibt die Ursache in `reason`. Keine App-Store-Variante bauen.

### 38.3 `VolumeInfo` und `MediumMonitor`
- **`VolumeInfo`:** Einhängepfad, Name, Dateisystem (`statfs` → `f_fstypename`), Gesamt- und freie Größe, Größe des ganzen Datenträgers (DiskArbitration), **UUID aus DiskArbitration** (`kDADiskDescriptionVolumeUUIDKey`, `CFUUID`; Null → `nil`), Erstelldatum (`volumeCreationDateKey`, normalisiert wie in Aufgabe 37), wechselbar, auswerfbar, intern, Geräteprotokoll, Modell. `identity` liefert die `VolumeIdentity` aus Aufgabe 37. Datei-IDs und `volumeIdentifier` werden **nicht** übernommen.
- **DiskArbitration** für ein eingehängtes Volume: `DASessionCreate`, `DADiskCreateFromVolumePath`, `DADiskCopyDescription`.
- **Kandidatenregel** als eigene, testbare Funktion (`VolumeCandidateRule`): Kandidat ist ein lokales Volume, dessen Einhängepfad mit `/Volumes/` beginnt und das wechselbar **oder** auswerfbar **oder** nicht intern ist. **Nicht** Kandidat: `/`, alles unter `/System/Volumes/`, `/private/…`, Netzlaufwerke, `autofs`, Disk-Images (Geräteprotokoll „Virtual Interface“ / „Disk Image“), Time-Machine-Snapshots.
- **`MediumMonitor`** (`@MainActor`) meldet als `AsyncStream<MediumEvent>`: `.appeared(VolumeInfo)`, `.willDisappear(path)`, `.disappeared(path)`. Quellen: `FileManager.mountedVolumeURLs` beim Start, `NSWorkspace` `didMount`, `willUnmount`, `didUnmount` und `didWake`. Doppelte Meldungen für denselben Pfad innerhalb einer Sekunde zusammenfassen.

### 38.4 `MediumCoordinator`: Ablauf beim Anschließen
Eigene Klasse, die den `IndexStore`, `MediumAccess` und `AppState` bekommt, damit sie sich mit Attrappen testen lässt.
1. **Bekannt?** `store.candidates(for: identity)`. Gibt es einen Kandidaten `.uuid` oder `.fingerprint`, ist es ein bekanntes Medium: `recordIdentity`, Name und Kapazität aktualisieren, `lastSeenAt` setzen, `connectionStatus = .connected`. **Kein Dialog.** War `decision == .ignore`, wird das Medium nicht weiter beachtet, aber als angeschlossen geführt.
2. **Unbekannt** (kein oder nur `.weak`-Kandidat): `access.probe(volume)`.
   - **`.granted`:** Medium mit `decision = .undecided`, `indexStatus = .pending` in den Speicher schreiben, in `AppState` aufnehmen und den Dialog öffnen (`newMediumDialogMediumID`, bestehender Mechanismus, schwebt über allen Fenstern).
   - **`.denied`:** Medium mit `indexStatus = .error` speichern und in `AppState` aufnehmen. Die zweite Zeile im Popover und in den Karten lautet „Kein Zugriff, in den Systemeinstellungen freigeben“ (der Zustand Fehler ist im Layout schon vorgesehen, keine neue Oberfläche). **Kein Dialog.** Bei jedem erneuten Anschließen und bei `NSApplication.didBecomeActiveNotification` wird für Medien in diesem Zustand erneut geprobt. Klappt es dann, weiter wie bei `.granted`.
3. **Abziehen:** `.disappeared` setzt `connectionStatus = .offline` und `lastSeenAt` im Speicher und in `AppState`. Der Index bleibt erhalten.
4. **Entscheidung im Dialog:** „Indizieren“ setzt `decision = .index`, „Nicht indizieren“ `decision = .ignore`. „Für dieses Medium merken“ setzt `rememberDecision`. Nach „Indizieren“ ruft der Koordinator den Haken `onIndexRequested(mediumUUID)`, der **noch leer** ist (Aufgabe 39). Bis dahin bleibt der Zustand `pending`.
5. **Ist `decision == .undecided` bei einem bekannten Medium** (Dialog wurde zuvor geschlossen, ohne zu antworten): Dialog erneut öffnen.
6. **Typ:** Ist das Medium wechselbar, gilt `MediumType.usb`, sonst `.hdd`.
7. **App-Start:** Alle beim Start schon eingehängten Kandidaten laufen durch denselben Ablauf. Der Speicher wird beim Start geöffnet (`IndexStore.openDefault()`). Schlägt das Öffnen fehl, per `Logger` protokollieren und die App ohne Erkennung weiterlaufen lassen.

### 38.5 Vorläufige Brücke zur Oberfläche
Die Oberfläche hängt noch an den Testdaten (`AppState.media`, `MockData`). Bis Aufgabe 41 gilt: `StoredMedium` → `Medium` (`id` = `StoredMedium.uuid`) und das Medium **zusätzlich** in `AppState.media` aufnehmen, damit Dialog, Übersicht und Popover das echte Medium zeigen (ohne Dateien, bis Aufgabe 39). Mit `// TODO Aufgabe 41` markieren. Testdaten nicht entfernen. Keine neuen Layout-Elemente.

### 38.6 Tests
- **`VolumeCandidateRule`** (Tabelle): SD-Leser (intern, wechselbar) → ja. USB-Stick (extern) → ja. `/` → nein. `/System/Volumes/Update/mnt1` → nein. `/private/tmp/tmp-mount-x` → nein. `/System/Volumes/Data/home` (`autofs`) → nein. Netzlaufwerk → nein. Disk-Image → nein.
- **`MediumCoordinator`** mit Attrappen für Ereignisse, Zugriff und Speicher (temporäre Datenbank): (a) unbekannt + `.granted` → Medium gespeichert, Dialog angefordert. (b) bekannt → kein Dialog, Verbindung online. (c) unbekannt + `.denied` → Zustand Fehler, kein Dialog, erneute Probe bei App-Aktivierung öffnet danach den Dialog. (d) Abziehen → offline, Daten bleiben. (e) `decision == .ignore` → kein Dialog. (f) Entscheidung „Indizieren“ speichert `decision` und `rememberDecision` und ruft `onIndexRequested` genau einmal.

**Abnahme durch Cursor:** Debug und Release bauen ohne Warnungen, alle Tests grün. Im Status stehen die gebauten Dateien, Abweichungen und was ohne Gerät nicht prüfbar war (keine erfundenen Ergebnisse).

**Prüfung durch den Nutzer** (das gebaute `Disk Index.app` **aus dem Finder** starten, nicht aus Xcode; vorher `tccutil reset SystemPolicyRemovableVolumes xjonx.diskindex`):
1. SD-Karte oder Stick anstecken. Erscheint zuerst ein macOS-Dialog „Wechseldatenträger“? App-Name und Wortlaut notieren. Danach soll unser Dialog „Neues Speichermedium erkannt“ mit Name, Art und Größe erscheinen.
2. „Indizieren“ und „Für dieses Medium merken“ wählen. Auswerfen, wieder anstecken: **kein** Dialog, Medium ist wieder online.
3. Abziehen ohne Auswerfen: Medium wird offline, kein Fehler.
4. Dialog von macOS ablehnen: Medium erscheint als Fehler „Kein Zugriff …“. In den Systemeinstellungen freigeben, App nach vorn holen: der Dialog erscheint.

---



---

# Nachtrag 30.09. — Aufgabe 42 (Erkennungs-Dialog nach Layout, Code und Gerät freigegeben)

Freigabe Claude 30.09.: Screenshot des Nutzers vom echten Gerät (USB-Stick) zeigt randlose Karte, rechtsbündige Knöpfe und die eigene Checkbox mit Ring, wie Layout Sektion 02. Zuvor lieferte der Test: Für den **externen USB-Stick** erscheint zuerst der macOS-Dialog „Disk Index möchte Zugriff auf Dateien auf einem Wechselmedium“, danach unser Dialog. Beim eingebauten Kartenleser erscheint kein Systemdialog.

## 42. Erkennungs-Dialog nach Layout, eigene Checkbox (Nutzertest 30.09.)

**Status:** Erledigt durch Cursor. Randloses `KeyablePanel` (transparent, schwebend, verschiebbar, Escape über `onExitCommand`, Return = „Indizieren“). Karte 300 pt, Radius 14, Innenabstand 16, Abstand 12, Knöpfe rechts. `DesignCheckbox` im Dialog (Standard an) und in der Filter-Medienliste; „Alle Medien“ in `filterSearch` und fett, wenn gewählt, übrige Zeilen 11 pt wie bisher. Einstellungen bleiben Systemschalter. Schattenraum 32 pt um die Karte, damit der SwiftUI-Schatten nicht abgeschnitten wird (wie beim Kontextmenü). Gerendert und gegen Sektion 02 gehalten: nur die Karte, rechtsbündige Knöpfe, Checkbox mit Ring. Am Gerät nicht geprüft (Einstellungen → Speichermedien → „Neues Medium (Demo)“).

**Befund:** Beim ersten echten Test (USB-Stick angesteckt) sah das Fenster „Neues Speichermedium erkannt“ anders aus als im Layout ([Sektion 02](layout/Disk%20Index%20App.dc.html)). Vergleich Layout ↔ `NewMediumDetectedDialog` ([NewMediumDetectedDialog.swift](diskindex/diskindex/Views/Registry/NewMediumDetectedDialog.swift)) und `AppWindowPresenter.openNewMedium`:
1. **Doppelter Rahmen:** Das Panel ist ein `.titled`-Systemfenster („Neues Speichermedium“, Titelleiste, 400 × 320) und darin liegt die Karte mit eigenem Rand, Radius und Schatten. Das Layout zeigt **nur die Karte**.
2. **Buttons linksbündig:** Im Layout stehen sie **rechtsbündig** (`justify-content: flex-end`, Abstand 8, 8 pt über der Reihe).
3. **„Für dieses Medium merken“** ist ein System-Schalter. Das Layout zeichnet eine **eigene Checkbox** (Klasse `.radio` mit Radius 3).
4. **Maße:** Layout Karte 300 breit, Innenabstand 16, Elementabstand 12, Titel 16 pt fett, Text 13 pt, Checkbox-Zeile 14 pt mit 4 pt Abstand oben. Code: Innenabstand 20, Abstand 14, Checkbox-Zeile 13 pt.
5. **Schatten:** Layout `--shadow-lg` (y 12, Weichzeichner 32, 22 % #2D2B2B). Code: 12 %, Radius 20, y 6.

**Soll:**
- **Randloses Panel** statt Systemfenster: Wie beim Kontextmenü ([ObjectFileContextMenu.swift](diskindex/diskindex/DesignSystem/ObjectFileContextMenu.swift), `KeyablePanel`, transparent, Schatten in SwiftUI, Außenabstand für den Schatten). Mit der Karte als einzigem Inhalt: Breite 300, Radius 14 (`DesignRadius.lg`), Fläche `DesignColor.bg`, Rand 1 pt (`neutral300`), Schatten `neutral900.opacity(0.22)`, `radius: 16`, `y: 12`. `padding(24)` und `minWidth/minHeight` in `NewMediumDialogWindowHost` entfallen.
- **Verhalten:** schwebt über allen Fenstern (`.floating`, `hidesOnDeactivate = false`, `orderFrontRegardless`), mittig auf dem Bildschirm, verschiebbar am Hintergrund (`isMovableByWindowBackground`). **Escape schließt** und bedeutet wie bisher „später entscheiden“ (die vorhandene Schließen-Logik in `register(panel)` bleibt). Return löst „Indizieren“ aus (Standardknopf).
- **Karte:** `VStack(alignment: .leading, spacing: 12)`, `padding(16)`. Icon 30, Titel 16 pt fett, Text 13 pt (`text.opacity(0.85)`), Checkbox-Zeile 14 pt mit 4 pt zusätzlichem Abstand oben. Knopfreihe: `Spacer()` links, dann „Nicht indizieren“ und „Indizieren“ mit Abstand 8, 8 pt Abstand nach oben.
- **Neue wiederverwendbare Checkbox `DesignCheckbox`** (als `ToggleStyle` unter `DesignSystem/`), nach dem CSS `.radio`:
  - 16 × 16, Radius 3, Rand 1,5 pt in `DesignColor.divider`, Abstand zum Text 8, Hand-Cursor.
  - Hover: Rand `DesignColor.control`.
  - **An:** Rand und Fläche `DesignColor.control` mit einem **4-pt-Ring in `DesignColor.bg`** (sichtbar bleibt eine schwarze Mitte von 8 × 8 innerhalb eines schwarzen Rands). Kein Häkchen.
  - Tastaturfokus: Rahmen 2 pt `control`, Abstand 2.
- **Einsatz:** Dialog („Für dieses Medium merken“, Standard **an**, wie im Layout) und die Medienliste im Filter-Popover (Layout Sektion 09: „Alle Medien“ blau und fett, wenn gewählt; die übrigen Zeilen normal). Die Häkchen in den **Einstellungen** bleiben Systemschalter, dort zeichnet das Layout eine native Checkbox. Abweichungen im Status nennen.

**Prüfung:**
- `NewMediumDetectedDialog` als Bild rendern und neben Layout Sektion 02 halten (Maße, Abstände, rechtsbündige Knöpfe, Checkbox mit Ring).
- Am Gerät: Einstellungen → Speichermedien → „Neues Medium (Demo)“ öffnet den Dialog. Er hat keine Titelleiste, ist verschiebbar, Escape schließt ihn, er liegt über anderen Fenstern.
- Die Filter-Medienliste zeigt die neue Checkbox, Auswahl und „Alle Medien“ verhalten sich wie vorher.

---



---

# Nachtrag 30.09. — Aufgaben 45, 39 (samt K1/K2), 41, 43, 44 (freigegeben)

Freigabe Claude 30.09. (Feinprüfung im Nutzertest): Debug und Release ohne Warnungen, 73 Tests grün, `grep` auf `MockData`/`MockIndex` außerhalb der Diagnose leer, Screenshot des Nutzers zeigt echte Daten aus dem Stick in der Spaltenansicht. Icon laut Nutzer „passt jetzt“. Offen gemeldet: Leertexte (41.4) noch vom Nutzer zu bestätigen; Laufzeit bei einer Million Einträgen nicht gemessen.

## 45. App-Icon: Kachel wie vorher, Symbol 60 % der Kachel (zweite Korrektur, Nutzer 30.09.)

**Status:** Erledigt durch Cursor. Kachel unverändert (824 von 1024, Rand 100, Radius 185,4, Schatten ab 64 px). Symbolrahmen jetzt `tile.width * 58 / 72`. Alle zehn PNGs und `DockIcon.png` neu erzeugt, beide 1024er Dateien bytegleich. Gemessen an 1024 px: Kachel 80,5 % der Leinwand (824/1024), Ecke Alpha 0, Symbolbreite 60,4 % der Kachel. 128 px: Kachel 81,2 %, Symbol 59,6 %. 32 px: Kachel 81,2 %, Symbol 53,8 % (Antialiasing unter der Helligkeitsschwelle, die Balken bleiben sichtbar). 16 px: Symbolmessung 0 % aus demselben Grund. Debug- und Release-Build ohne Warnungen. Dock nach Neustart und `killall Dock` nicht geprüft.

**Verlauf:**
1. Ursprünglich: Kachel 82 % der Leinwand, Symbol 55 % der Kachel. Nutzer: Symbol im Icon zu klein.
2. Erste Fassung: Kachel vollflächig (100 %), Symbol 60 % der Kachel. Nutzer: Das Symbol „ist in sich stimmig“, aber das **ganze Icon ist größer als alle anderen im Dock**.
3. Zweite Fassung (jetzt gebaut): Kachel wieder 82 %, Symbol **68 %** der Kachel (`tile.width * 67 / 72`). Das ist mehr als die 60 %, die der Nutzer als stimmig bezeichnet hat.

**Soll (endgültig):**
- **Kachel wie vor dem 30.09.:** 824 von 1024 mit 100 px transparentem Rand, Eckradius 185,4, Schatten wie bisher, Verlauf unverändert (bleibt so, wie es jetzt ist).
- **Symbol: sichtbare Breite 60 % der Kachelbreite.** Der Rahmen um das Symbol ist `0,60 / 0,75 = 80 %` der Kachelbreite, im Skript `tile.width * 58 / 72` (statt `67 / 72`). Damit ist das Verhältnis Symbol zu Kachel dasselbe, das dem Nutzer in der ersten Fassung stimmig vorkam, aber die Kachel hat wieder die Normalgröße im Dock.
- Alle zehn PNGs in `AppIcon.appiconset` und `DockIcon.imageset/DockIcon.png` neu erzeugen (`DockIcon.png` ist die 1024er Fassung, alles aus demselben Rendering).

**Prüfung durch Cursor:** PNGs vermessen und eintragen: Kachel 82 % ± 1 % der Leinwand, Ecken transparent, Symbolbreite 60 % ± 1 % der Kachelbreite, `icon_512x512@2x.png` und `DockIcon.png` bytegleich. Debug und Release ohne Warnungen.

**Prüfung durch den Nutzer:** Nach dem Bauen die App **neu starten** und `killall Dock`, sonst zeigt das Dock noch das alte Bild. Wenn das Icon dann immer noch größer wirkt als die Nachbarn, bitte ein Bild vom Dock schicken. Dann wird nur die Kachel angepasst (Rand 12 % statt 9 %), das Symbol bleibt.

---

## Review Claude 30.09. — Korrekturen zu 39

Debug und Release ohne Warnungen, alle Tests grün (DirectoryIndexer, IgnoreMatcher, IndexingService, Speicher, Erkennung). Ebenenfolge, Tiefe (Tiefe *d* liest die Ebenen 1 bis *d*, Ordner der letzten Ebene bleiben zu), Fortsetzen, übersprungene Ordner, Pakete und Symlinks sind wie beauftragt umgesetzt. **Zwei Fehler**, einer davon sichtbar:

- **K1 (39.5) Fortschritt springt sofort auf 99 %:** In [DirectoryIndexer.swift](diskindex/diskindex/Indexing/DirectoryIndexer.swift) steht `discoveredFolders = 1` (nur die Wurzel), und die Ordner aus einer Ebene werden erst gezählt, **wenn die nächste Ebene beginnt**. Nach dem Lesen der Wurzel ist damit `completedFolders / discoveredFolders = 1 / 1`, die Anzeige springt auf `min(0,99, 1) = 99 %` und bleibt dort, weil sie nie fallen darf. Der Nutzer sähe fast den ganzen Lauf lang „99 %“. Die Vorgabe „bisher **entdeckte** Ordner“ meint: sobald ein Ordner in einer Auflistung auftaucht, zählt er.
  - **Soll:** Beim Start `discoveredFolders = Anzahl der Ordner der Startebene` (Wurzel = 1, beim Fortsetzen die Ordner der fortgesetzten Ebene). **Sobald ein Ordner erfolgreich aufgelistet ist**, `discoveredFolders += Anzahl der darin gefundenen Ordner`, aber **nur**, wenn diese Ordner auch geöffnet werden (`maxDepth == nil || depth < maxDepth`). Die Addition zu Beginn einer Ebene (`discoveredFolders += parents.count`, `= parents.count`) entfällt. Verhältnis wie bisher, nie fallend, bis zum Ende höchstens 99 %, am Ende 100 %.
  - **Test ergänzen:** Baum Wurzel → 10 Ordner → je 10 Ordner (Tiefe 3). Nach der Wurzel ist der Fortschritt höchstens 1/11, er steigt danach schrittweise, fällt nie und erreicht die 99 %-Grenze erst, wenn alle Ordner gelesen sind. Bei Tiefe 2 zählen die Ordner der Ebene 2 nicht mit (sie werden nicht geöffnet).
- **K2 (39.1) Fehler beim letzten Stapel einer Ebene wird verschluckt:** `if !batch.isEmpty { try? await store.applyDirectories(...) }` ignoriert einen Schreibfehler. Danach markiert `completeLayer` die Ebene trotzdem als fertig, und ein Fortsetzen würde sie überspringen, obwohl Ordner fehlen. **Soll:** Behandeln wie den Fehler mitten in einer Ebene (Lauf endet mit `indexStatus = .error`, **kein** `completeLayer`, Protokoll). Test mit einem Speicher, dessen Schreiben fehlschlägt: `completedDepth` bleibt unverändert.
- **Zur Kenntnis, keine Änderung:** Die Anzeige `counts()` (Zählung aller Einträge, alle 250 ms) und die Abfrage `indexingIsActive` (je Ordner) sind bei rund einer Million Einträgen nicht gemessen. Sobald eine große Platte da ist, die Dauer im Lauf protokollieren. Die Ergebnisse gehören in den Status der nächsten Aufgabe.

**Status:** Erledigt durch Cursor. K1: `discoveredFolders` startet mit der Zahl der Ordner der Startebene; nach erfolgreichem Auflisten kommen nur die Ordner dazu, die noch geöffnet werden. Die Addition zu Beginn der nächsten Ebene ist weg. Test `progressCountsFoldersWhenTheyAreDiscovered`: nach der Wurzel höchstens 1/11, monoton, die 99 %-Grenze erst bei den letzten beiden Stichproben (110/111 und 111/111 liegen beide auf der Kappe). K2: der letzte Stapel einer Ebene fängt `applyDirectories` ab, `indexStatus = .error`, kein `completeLayer`, `completedDepth` bleibt. Dateien: `DirectoryIndexer.swift`, `IndexStore.swift` (`setDirectoryWritesFailing`), `IndexRecords.swift`. Dauer von `counts()` und `indexingIsActive` bei rund einer Million Einträgen nicht gemessen (keine große Platte). Unit-Tests der App grün, Release-Build ohne neue Warnungen.

**Status:** Erledigt durch Cursor. Dateien: `MediumAccess.listDirectory`, `Indexing/IgnoreMatcher.swift` (`ScanConfiguration`, `IndexingLimits.parallelDirectoryReads = 1`), `Indexing/DirectoryIndexer.swift`, `Indexing/IndexingService.swift`; `IndexStore.folders`, `applyDirectories`, `counts`, Lauf-Token; `onIndexRequested` ist `(UUID, VolumeInfo)`, Abziehen leert `requestedIndex` und bricht den Lauf ab (`pending`, `completedDepth` bleibt). Popover-Schalter und „Neu indizieren“ rufen den Dienst. Ein hängendes `.indexing` wird beim Anschließen wie `.pending` fortgesetzt. Fortschritt = Ordnerverhältnis, nie fallend, bis zum Ende höchstens 99 %; `fileCount`/`folderCount` kommen aus `counts()`. Die bestehende Zeile „N / M“ rechnet weiter `fileCount × indexingProgress`, es gibt keinen zweiten Zähler. Pro Medium gibt es in den Einstellungen keinen Pause-Schalter, `autoIndexPaused` wird trotzdem beim Start und zwischen Stapeln gelesen. Tests a–m grün. Rauchtest (l): 0,596 s für 20 000 Dateien in 500 Ordnern. Debug- und Release-Build ohne neue Warnungen (AppIntents „Metadata extraction skipped“ wie bisher). Am echten Medium nicht geprüft.

Dritter Baustein. Konzept: [README.md](README.md) → „Schichtweise lesen“, „Änderungen, Löschen, Wiederherstellen“, „Was die bestehende Oberfläche dabei zeigt“. Der Scanner liest die Ebenen eines Mediums **breitenweise** und schreibt sie in den Speicher (Aufgabe 36/37). Angestoßen wird er von `onIndexRequested` aus Aufgabe 38. Live-Änderungen (FSEvents) und der Abgleich **beim erneuten Anschließen eines fertig indizierten Mediums** sind Aufgabe 40. Die Oberfläche bleibt bis Aufgabe 41 an den Testdaten, Fortschritt und Zähler des echten Mediums gehen über die vorhandene Brücke (`publish`, `TODO Aufgabe 41`).

### 39.1 Regeln, was gelesen und gespeichert wird
- **Ebenen:** Ebene 1 = Inhalt der Wurzel des Mediums (Einträge mit `depth = 1`). Ebene *k* = Inhalt aller Ordner der Ebene *k − 1*. Ein Lauf liest bis zur **Scan-Tiefe** aus den Einstellungen (`AppSettings.scanDepth`, 1 bis 4; bei „5+“ ohne Grenze bis keine Ordner mehr übrig sind). Ordner der letzten gelesenen Ebene werden gespeichert, aber **nicht** geöffnet (in der Oberfläche später „Inhalt nicht erfasst“). Das entspricht der Regel aus Aufgabe 24 (Tiefe *d* = *d* Spalten mit Inhalt).
- **Reihenfolge:** Eine Ebene wird **vollständig** gelesen und **in einer oder mehreren Transaktionen gespeichert**, bevor die nächste beginnt. Nie in einen Ordner der nächsten Ebene springen, solange die aktuelle nicht fertig ist.
- **Pakete** (`.app`, `.bundle` u. a.; `isPackageKey`): als **Datei** speichern (`isFolder = false`, `isPackage = true`, Größe `nil`), **nicht** betreten.
- **Symbolische Links:** nicht folgen, als Datei speichern.
- **Nicht gespeichert:** `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `.TemporaryItems`, `.DocumentRevisions-V100` und alle Namen, die mit `._` beginnen (immer). Versteckte Einträge (Name beginnt mit `.` oder Flag `isHiddenKey`) nur, wenn `AppSettings.ignoreHiddenFiles` **aus** ist. Zusätzlich die **Ausschlussliste** `AppSettings.excludedPatterns`: `*.endung` trifft auf das Namensende, jeder andere Eintrag auf den vollständigen Namen (ohne Beachtung der Groß-/Kleinschreibung); getroffene Ordner werden samt Inhalt übersprungen. Als eigener, testbarer Typ (`IgnoreMatcher`).
- **Gespeichert wird je Eintrag:** Name, Ordner ja/nein, Paket ja/nein, Größe (logisch, nur Dateien), Änderungsdatum. `fileID` bleibt **`nil`** (auf FAT nicht dauerhaft; Verschieben erkennen ist Aufgabe 40).
- **Fehler:** Kann ein Ordner nicht gelesen werden, wird er **übersprungen**: nichts aus seinem bisherigen Inhalt als „entfernt“ markieren, Zähler `readErrors` erhöhen, per `Logger` protokollieren, weitermachen. Nur ein **erfolgreich gelesener** Ordner (auch leer) gilt als Wahrheit und markiert fehlende Kinder als entfernt (das leistet `applyDirectory` bereits). Kann die **Wurzel** nicht gelesen werden: Lauf endet mit `indexStatus = .error`.
- **Kein Schreiben auf das Medium.**

### 39.2 Zugriff hinter der Schnittstelle
Das Lesen eines Ordners gehört zur Schnittstelle `MediumAccess` (Aufgabe 38): neue Methode zum Auflisten eines Verzeichnisses. `DirectMediumAccess` liest mit `FileManager.contentsOfDirectory(at:includingPropertiesForKeys:options:)` (Schlüssel: `isDirectoryKey`, `isPackageKey`, `isSymbolicLinkKey`, `isHiddenKey`, `fileSizeKey`, `contentModificationDateKey`). Der Scanner benutzt **nur** diese Schnittstelle. So lässt er sich mit einer Attrappe (Speicherbaum im Test) prüfen.

### 39.3 Speicher-Erweiterungen (`IndexStore`)
- `folders(mediumUUID:, depth:) -> [(id: Int64, path: String)]`: alle vorhandenen Ordner (nicht entfernt) genau dieser Ebene.
- `applyDirectories(mediumUUID:, batches: [(parentID: Int64?, entries: [ScannedEntry])], seenAt:)`: mehrere Ordner in **einer** Transaktion (wie `applyDirectory`, nur gebündelt). Der Scanner sammelt Ordner, bis ca. 5 000 Einträge zusammen sind (oder die Ebene endet), und schreibt dann.
- `counts(mediumUUID:) -> (files: Int, folders: Int)` für Zähler.
- Der Scanner liest Ordner der Ebene nacheinander (Reihenfolge der `folders`-Abfrage). Eine feste Konstante für die Anzahl gleichzeitiger Lesevorgänge (Standard 1) vorsehen, damit später an einer SSD gemessen werden kann.

### 39.4 `IndexingService`
- Eigene Klasse (`@MainActor` für die Anbindung, Arbeit in `Task`s abseits des Hauptthreads, Priorität `.utility`), gehalten vom `AppDelegate` neben dem `MediumCoordinator`.
- `start(mediumUUID:, volume: VolumeInfo, fromScratch: Bool)`, `cancel(mediumUUID:)`, `cancelAll()`. Pro Medium höchstens ein Lauf.
- **`onIndexRequested` bekommt das Volume mit** (`(UUID, VolumeInfo) -> Void`), weil der Einhängepfad je Anschluss anders sein kann (`/Volumes/NO NAME 1`).
- **Ablauf eines Laufs:** `indexStatus = .indexing` (Menüleisten-Badge und Popover-Spinner laufen über den vorhandenen Zustand). Dann Ebene für Ebene. Nach jeder Ebene `completeLayer`. Am Ende `indexStatus = .indexed`, `lastIndexedAt = jetzt`, `firstIndexedAt` nur setzen, wenn noch leer, Zähler aus `counts`, `indexingProgress = 1`.
- **Fortsetzen:** Zu Beginn `completedDepth` lesen. Ist er 0, mit der Wurzel beginnen, sonst mit Ebene `completedDepth + 1` (Ordner aus `folders(depth: completedDepth)`). `fromScratch: true` (Knopf „Neu indizieren“, vorhandene `AppState.reindexMedium`) setzt `completedDepth` auf 0 zurück; vorhandene Zeilen bleiben, der Lauf markiert Verschwundenes als entfernt.
- **Medium verschwindet** (`.disappeared`, Lesefehler wegen fehlendem Datenträger): Lauf leise abbrechen, `indexStatus = .pending`, `completedDepth` bleibt. Beim nächsten Anschließen eines Mediums mit `decision == .index` und `indexStatus == .pending` startet der Koordinator den Lauf wieder (den Satz `requestedIndex` beim Abziehen leeren, sonst kommt kein zweiter Aufruf).
- **Pause:** Ist `AppState.globalAutoIndexPaused` oder `Medium.autoIndexPaused` gesetzt, startet kein Lauf; wird die Pause **während** eines Laufs eingeschaltet, endet er nach dem aktuellen Stapel, `completedDepth` bleibt. Beim Aufheben der Pause wird fortgesetzt. Die vorhandenen Schalter in Popover und Einstellungen rufen dafür den Dienst auf.
- **Einstellungen** werden beim Start des Laufs als Schnappschuss gelesen (`ScanConfiguration`: Scan-Tiefe, Ausschlussliste, versteckte Dateien).

### 39.5 Fortschritt (README „Fortschritt“)
- **Prozent** = abgeschlossene Ordner ÷ bisher entdeckte Ordner **dieses Laufs** (die Wurzel zählt als 1; Ordner, die wegen der Scan-Tiefe nicht geöffnet werden, zählen nicht). **Nie fallend**, bis zum Ende höchstens 99 %, am Ende 100 %.
- **„N / M Dateien“:** N = bisher gespeicherte Dateien dieses Laufs, M = bisher entdeckte Dateien (wächst mit).
- Zähler und Fortschritt gehen **höchstens alle 250 ms** an die Oberfläche (`fileCount`, `folderCount`, `indexingProgress` am Medium in `AppState` über die vorhandene Brücke). Die Oberfläche selbst bleibt unverändert.

### 39.6 Tests
Mit Attrappe für `MediumAccess` (Speicherbaum im Arbeitsspeicher) und temporärer Datenbank:
- (a) Tiefe 3: Einträge der Ebenen 1 bis 3 sind gespeichert, Ordner der Ebene 3 werden **nie** aufgelistet (die Attrappe merkt sich Aufrufe).
- (b) „5+“: alles wird gelesen.
- (c) **Ebenenfolge:** Die Attrappe protokolliert die Reihenfolge; kein Ordner der Ebene *k + 1* wird aufgelistet, bevor alle Ordner der Ebene *k* durch sind. `completedDepth` steigt Ebene für Ebene.
- (d) **Fortsetzen:** Nach Abbruch nach Ebene 2 setzt ein neuer Lauf bei Ebene 3 an und listet die Wurzel **nicht** erneut.
- (e) Ausschlüsse: `.Spotlight-V100`, `._x`, `.DS_Store` (versteckt), Muster `*.tmp`, Ordner `node_modules`, jeweils mit `ignoreHiddenFiles` an und aus.
- (f) Nicht lesbarer Ordner (Attrappe wirft): übersprungen, alte Kinder bleiben unberührt, Lauf endet `.indexed`, `readErrors` = 1. Nicht lesbare Wurzel: `.error`.
- (g) Zweiter Lauf mit gelöschter und wieder hinzugefügter Datei: Grabstein und Wiederbelebung, Favorit bleibt (Integration mit dem Speicher).
- (h) Fortschritt nie fallend, Endwert 1, Zustandsfolge `pending → indexing → indexed`, `firstIndexedAt` nur einmal gesetzt.
- (i) Paket (`.app`) wird als Datei mit `isPackage = true` gespeichert und nicht betreten. Symlink wird nicht verfolgt.
- (j) Abziehen mitten im Lauf: `indexStatus = .pending`, `completedDepth` bleibt; Koordinator startet beim erneuten Anschließen genau einen neuen Lauf.
- (k) **Echte Dateien:** In einem temporären Ordner auf der Platte einen kleinen Baum (3 Ebenen, versteckte Datei, Symlink, `._`-Datei) anlegen und mit `DirectMediumAccess` scannen. Ergebnis stimmt mit dem Baum überein.
- (l) Rauchtest Leistung: 20 000 Dateien in 500 Ordnern scannen (temporär auf der Platte) in unter 30 s, die tatsächliche Dauer wird ausgegeben.
- (m) `IgnoreMatcher`: Tabelle (`*.log`, `node_modules`, Groß-/Kleinschreibung, Namen ohne Muster).

### 39.7 Abgrenzung
Nicht Teil dieser Aufgabe: FSEvents und Abgleich fertig indizierter Medien beim Anschließen (Aufgabe 40), Anschluss der Oberfläche an den Speicher und Entfernen der Testdaten (Aufgabe 41), Bereinigung „Ignorierte Objekte“ nach 1 Stunde, Suche und Ansichten über den echten Index. **Keine neue Oberfläche.**

**Abnahme durch Cursor:** Debug und Release bauen ohne Warnungen (auch keine Swift-6-Warnungen zu `Sendable`/Isolation in den neuen Dateien), alle Tests grün. Im Status: gebaute Dateien, Abweichungen, gemessene Dauer aus (l), und was ohne Gerät nicht prüfbar war.

**Prüfung durch den Nutzer** (Build aus dem Finder starten, Karte oder Stick anstecken, „Indizieren“ wählen):
1. Popover und Menüleiste zeigen „wird indiziert“ mit Fortschritt, danach fertig ohne Chip. Zeit und Anzahl notieren.
2. In den Einstellungen (Scan-Tiefe) einmal 3 und einmal „5+“ probieren: „Neu indizieren“. Ist die Anzahl der Objekte plausibel (Vergleich mit dem Finder, ohne versteckte Dateien)?
3. Mitten im Lauf abziehen (bei einem größeren Medium) und wieder anstecken: Der Lauf setzt fort und endet.
4. Datei auf dem Medium löschen, „Neu indizieren“: Sie fehlt danach im Index.

---

## 41. Oberfläche an den Speicher: Medien, Einstellungen, Leerzustände, Testmedien raus

**Status:** Erledigt durch Cursor. `AppState.media` startet leer. Vor der Erkennung lädt `loadStoredMedia` alle gespeicherten Medien als offline (`AppDelegate.startMediumRecognition`). `MockData.swift` ist gelöscht, Vorschauen nutzen `PreviewData` unter `#if DEBUG`. Der Demo-Button ist weg. `IndexStore.changes` ist ein `AsyncStream`; die Oberfläche lädt darüber nach, `publish` bleibt bis zum Abgleich. Änderungen an `showAbsoluteCapacity`, `isFavorite`, `autoIndexPaused`, `allowIndexing` und `type` werden nach höchstens 500 ms geschrieben (`flushMediumEdits` für Tests). „Vergessen“ ruft `deleteMedium`. `AppSettings` ist `Codable` in `UserDefaults` (`diskindex.appSettings`), ebenfalls gebündelt; Zurücksetzen schreibt die Standardwerte. Systemstart bleibt bei `SMAppService`. Leertexte aus 41.4 sind eingebaut und vom Nutzer noch nicht bestätigt. Die Spaltenansicht hatte keinen Satz „Wähle ein Speichermedium“, deshalb steht dort derselbe Text wie in der Übersicht. Tests a–f grün.

Ziel des Nutzers (30.09.): **Alle Testdaten raus**, die App startet mit leerer Datenbank und zeigt nur echte Medien. Diese Aufgabe stellt Medien und Einstellungen um. Spaltenansicht (43), Suche/Favoriten/Popover (44) und Live-Änderungen (40) folgen in dieser Reihenfolge. Nach 39-Korrekturen beginnen. Die mit `TODO Aufgabe 41` markierten Stellen (`MediumCoordinator.publish`, `asMedium`) sind hier aufzulösen.

### 41.1 Medien aus dem Speicher
- `AppState.media` startet **leer** (`MockData.media` entfällt). Beim App-Start werden alle `StoredMedium` aus dem Speicher geladen (`Medium` mit `connectionStatus = .offline`, bis der `MediumCoordinator` sie als angeschlossen meldet). Zuerst laden, **dann** die Erkennung starten, damit ein bekanntes Medium nicht doppelt erscheint.
- `MockData.swift` wird gelöscht. Vorschauen (`#Preview`) bekommen Beispielmedien aus einer Datei unter `#if DEBUG` (`PreviewData`), die **nie** zur Laufzeit benutzt wird. Der Button „Neues Medium (Demo)“ unter Einstellungen → Speichermedien entfällt.
- `IndexStore` liefert Änderungen als `AsyncStream` (Medium geändert, Ebene fertig, Zähler geändert). Die Oberfläche lädt daraufhin nach. Das ersetzt die manuelle Brücke `publish` nach und nach; bis Aufgabe 44 darf sie bestehen bleiben.

### 41.2 Änderungen am Medium werden gespeichert
Heute lebt `AppState.updateMedium` nur im Arbeitsspeicher. Jede Änderung, die die Oberfläche macht, muss in den Speicher geschrieben werden (gebündelt, höchstens alle 500 ms): `showAbsoluteCapacity`, `isFavorite`, `autoIndexPaused`, `allowIndexing`, `type` (Details), `isForgotten`.
- **„Vergessen“** (Detail-Modal, rot): löscht das Medium **und seinen Index** aus dem Speicher (`deleteMedium`, Kaskade). Es verschwindet aus allen Listen. Wird es später angeschlossen, ist es unbekannt und der Dialog erscheint wieder.
- **Neu indizieren** und die Pause-Schalter rufen wie in Aufgabe 39 den `IndexingService`.

### 41.3 Einstellungen bleiben erhalten
`AppSettings` (Scan-Tiefe, Ausschlussliste, versteckte Dateien, Mitteilung Online-Favoriten, „Ordner weiterhin anzeigen“) lebt heute nur im Arbeitsspeicher und wäre bei jedem Start zurückgesetzt. Als `Codable` in `UserDefaults` sichern, beim Start laden, bei jeder Änderung speichern (gebündelt). „Auf Standard zurücksetzen“ wirkt wie bisher. Der **Systemstart** bleibt beim System (nicht hier speichern).

### 41.4 Leerzustände (Text-Vorschläge, vom Nutzer noch bestätigen)
Die Layout-Sektionen zeigen keine Leerzustände. Bis zur Bestätigung gelten diese Texte im Stil des Leerzustands der Suche (Sektion 10): Icon 40 pt in `text.opacity(0.35)`, Titel 15 pt halbfett in `text.opacity(0.7)`, Zeile darunter 13 pt in `text.opacity(0.55)`, zentriert:
- **Übersicht** ohne Medien: „Noch kein Speichermedium erfasst“ / „Schließe ein Speichermedium an. Disk Index erkennt es automatisch.“ (Icon `hard-drives`).
- **Einstellungen → Speichermedien** ohne Medien: derselbe Text, ohne Icon.
- **Popover** ohne angeschlossene Medien: „Kein Speichermedium angeschlossen“ (13 pt, `text.opacity(0.55)`), Suchfeld bleibt.
- **Spaltenansicht** ohne Medium: „Wähle ein Speichermedium“ wie bisher, falls schon vorhanden, sonst derselbe Text wie die Übersicht.

### 41.5 Tests
- (a) Start mit leerer Datenbank: keine Medien in `AppState`, Leerzustände sichtbar (als Bild gerendert).
- (b) Start mit zwei gespeicherten Medien: beide erscheinen offline, danach meldet die Erkennung eines als angeschlossen.
- (c) Änderung an `showAbsoluteCapacity`/`isFavorite`/`autoIndexPaused` überlebt einen Neustart (neuer `AppState` mit derselben Datenbank).
- (d) `AppSettings` überstehen einen Neustart; „Auf Standard zurücksetzen“ auch.
- (e) „Vergessen“ entfernt Medium und Zeilen.
- (f) `grep` in der App (ohne Vorschauen und Tests) findet **kein** `MockData` mehr.

---

## 43. Spaltenansicht, Details und Kontextmenü auf dem echten Index

**Status:** Erledigt durch Cursor. `IndexRepository` lädt `IndexStore.children` asynchron und hält den Ordnerinhalt. Offene Spalten werden über den Änderungsstrom geleert und neu geladen. `IndexedItem` liegt in `IndexedItem.swift`, die ID bleibt die bisherige SHA-256-UUID, zusätzlich `rowID`. `folderID(mediumUUID:path:)` löst `pathStack` auf. Ein Ordner der Tiefe d ist gelb, wenn `d >= min(completedDepth, Scan-Tiefe)` (`isFolderContentUncaptured`); bei „5+“ zählt nur `completedDepth`. Dateidetails kommen aus der Zeile. Favoriten am Objekt gehen über `setFavorite`, `favoriteIndexedItemIDs` ist weg. Ignorieren bleibt in den Einstellungen. Offline-Medien bleiben sichtbar. Tests a–e auf einer Fixture mit drei Ebenen grün.

Zweiter Schritt der Umstellung. `MockIndex.children` und `MockIndex.item` in [ColumnBrowserView.swift](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift) (Zeilen um 36, 411, 416) werden durch den Speicher ersetzt. Die Oberfläche bleibt unverändert.

- **Datenzugriff:** Eine `@MainActor @Observable`-Klasse `IndexRepository` hält geladene Ordnerinhalte im Zwischenspeicher und lädt **asynchron** aus `IndexStore.children`. Die Ansicht rechnet nicht mehr synchron. Bis ein Ordner geladen ist, zeigt die Spalte leer ohne Fehlermeldung.
- **Neu laden:** Über den Änderungsstrom aus Aufgabe 41 aktualisieren sich offene Spalten, wenn Ebenen fertig werden oder sich Zeilen ändern. **Ein laufender Scan füllt die Spalten also sichtbar von vorn nach hinten.**
- **Objektkennung:** `IndexedItem.id` bleibt eine `UUID`, damit die vorhandenen Ansichten unverändert weiterlaufen. Sie wird **deterministisch** aus Medium, Pfad und Art gebildet (wie `MockIndex.itemID`), zusätzlich trägt `IndexedItem` die Zeilennummer `rowID` der Datenbank. Der Pfad des ausgewählten Ordners (`pathStack`, Namen) wird über die gespeicherte Pfadspalte in die `parentID` aufgelöst (neue Methode am Speicher, z. B. `folderID(mediumUUID:, path:)`).
- **„Inhalt nicht erfasst“:** Ein Ordner der Ebene *d* zeigt seinen Inhalt, wenn `d < min(completedDepth, Scan-Tiefe)`, sonst gilt er als nicht erfasst (gelb, Detail-Chip wie bisher). Das deckt drei Fälle: normale Grenze, gesenkte Scan-Tiefe (Daten bleiben, werden nur nicht gezeigt) und gesteigerte Scan-Tiefe (Ordner der letzten fertigen Ebene sind gelb, „Neu indizieren“ erfasst sie).
- **Objektdetails:** Datei-Detail liest aus dem Speicher (Größe, Änderungsdatum, „zuletzt gesehen“ = `lastSeenAt`).
- **Favoriten am Objekt** (Kontextmenü) schreiben `item.isFavorite` (`setFavorite`), nicht mehr in eine Menge im Arbeitsspeicher. Die Menge `AppState.favoriteIndexedItemIDs` entfällt oder wird zum abgeleiteten Zwischenspeicher aus dem Speicher.
- **Ignorieren-Einträge** des Kontextmenüs bleiben wie bisher in den Einstellungen.
- **Filter in der Spaltenansicht** wirken auf die geladenen Kinder des offenen Ordners wie bisher (`SearchItemFilter.matches`, „Ordner weiterhin anzeigen“).
- **Fußleiste:** Freier Speicher aus dem Medium, Pfad, Anzahl der Objekte im offenen Ordner wie bisher.
- **Offline-Medium:** Wird wie bisher gezeigt (Hinweis über den Spalten), gelesen wird aus dem Speicher.
- **Tests:** Fixture-Datenbank mit 3 Ebenen. (a) Wurzelspalte zeigt Ordner vor Dateien alphabetisch. (b) Klick auf einen Ordner öffnet die nächste Spalte mit dessen Kindern. (c) Ordner an der Grenze der Scan-Tiefe ist „nicht erfasst“. (d) Ein neu geschriebener Stapel taucht ohne erneutes Öffnen auf. (e) Favorit am Objekt überlebt Neustart.

---

## 44. Suche, Favoriten und Popover auf dem echten Index; Testdaten löschen

**Status:** Erledigt durch Cursor. Suche, Favoriten und Popover lesen `IndexStore.search`, `searchCount` und `favorites`, jeweils mit `depth <= Scan-Tiefe` (bei „5+“ ohne Grenze). Enter startet die Suche, „Suche läuft…“ bis das Ergebnis da ist, eine neuere Suche verwirft die ältere. Die Tabelle zeigt höchstens 500 Zeilen, die Fußleiste die Zählabfrage. Medienkacheln bleiben die Namenssuche über `AppState.media`. `MockIndex.swift` und `MockData.swift` sind gelöscht. `grep` auf `MockData` und `MockIndex` in `diskindex/diskindex/` ohne `Diagnostics` ist leer. Die Laufzeit bei einer Million Einträgen ist nicht neu gemessen. Tests a–e grün: „rechn“ ohne entfernte Zeilen, Swift- und SQL-Filter gleiche Menge, gesenkte Tiefe, Popover-Zählung, Favorit nach Neustart.

Dritter Schritt. Danach gibt es **keine** Testdaten mehr im Programm.

- **Suche** ([SearchIndex.swift](diskindex/diskindex/Models/SearchIndex.swift)): `matching`, `unfilteredItemCount`, `favoriteObjects` lesen aus `IndexStore.search`/`favorites`/Zählabfragen. Namenssuche, Filter (Dateityp, eigene Endungen, Alter, Oder/Und, Medium) und Suchbegriff-Regeln bleiben wie bisher (`SearchItemFilter` und die SQL-Spiegelung im Speicher müssen zusammen dieselben Treffer liefern; ein Test vergleicht beide auf derselben Fixture).
- **Tiefengrenze:** Alle Abfragen zeigen nur Objekte mit `depth <= Scan-Tiefe` (bei „5+“ alle), damit eine gesenkte Scan-Tiefe sofort wirkt (`indexedMaxDepth`).
- **Medien-Treffer** (Kacheln über der Tabelle): passende Medien nach Name wie bisher, aus `AppState.media`.
- **Asynchron:** Enter startet die Suche, „Suche läuft…“ erscheint bis das Ergebnis da ist, veraltete Ergebnisse werden verworfen (schnell hintereinander gestartete Suchen). Ziel: Ergebnis bei 1 Mio. Einträgen unter 200 ms für Suche und Anzeige der ersten 200 Zeilen. Die Tabelle zeigt weiter höchstens die ersten N Treffer (N in `IndexStore.search(limit:)`, Standard 500) und rechts unten die Zahl der Treffer aus einer Zählabfrage.
- **Favoriten-Ansicht:** `favorites()`; Verbindungsfilter Alle/Online/Offline und Filterleiste wie bisher.
- **Popover-Suche** ([PopoverSearch.swift](diskindex/diskindex/Models/PopoverSearch.swift)): die ersten 3 Treffer je Kategorie (Speichermedien, Dateien, Ordner) und „Alle N Ergebnisse anzeigen“ aus Zählabfragen.
- **Löschen:** `MockIndex.swift` und `MockData.swift` samt `demoFavoriteItemIDs`. `IndexedItem` zieht in eine eigene Datei. `favoriteIndexedItemIDs` (falls noch vorhanden) entfällt. Vorschauen und Tests nutzen `PreviewData`/Fixtures unter `#if DEBUG` bzw. im Testziel.
- **Abnahme:** `grep -rn "MockData\|MockIndex"` in `diskindex/diskindex/` (ohne `Diagnostics`, das eigene Messwerkzeug bleibt) liefert nichts. Debug und Release ohne Warnungen, alle Tests grün.
- **Tests:** (a) Suche „rechn“ auf Fixture liefert die erwarteten Treffer, entfernte Objekte fehlen. (b) Dateityp + Alter + Oder/Und liefern in Swift und in SQL dieselbe Menge. (c) Gesenkte Scan-Tiefe blendet tiefere Treffer aus. (d) Popover-Zählung stimmt mit der Suchansicht überein. (e) Favoriten überleben einen Neustart.

---



---

# Nachtrag 30.09. (2) — Korrekturen 40, Aufgaben 40, 46, 47, 48 (freigegeben)

Freigabe Claude 30.09.: Release-Build grün, Unit-Tests (`diskindexTests`) grün. Der UI-Test `testLaunch` scheitert an fehlender Bedienungshilfen-Freigabe (Umgebung, kein Codefehler). Code geprüft: `ChangeWatcher.flush` (K1–K3 behoben), `ColumnBrowserFiltering`, Filterleiste `In „<Medium>“`, `DesignColor` dynamisch, keine festen Hex-Werte außerhalb der Tokens. Visueller Dark-Vergleich und Nutzertest stehen beim Nutzer aus.

## Reihenfolge (Stand 30.09.)

1. **40 Korrekturen** (Abschnitt „Review Claude 30.09. — Korrekturen zu 40“ direkt darunter; Aufgabe 40 selbst steht weiter unten und ist bis auf diese Korrekturen erledigt).
2. **46** Filter wirkt in allen Spalten.
3. **47** Vorläufig immer hell.
4. **48** Dunkelmodus (ersetzt 47, Vorlage: Dark-Blöcke in Sektion 02 bis 13 des Layouts).

Nach jeder Aufgabe den Status eintragen. Debug- und Release-Build und alle Tests müssen grün sein.

---

## Review Claude 30.09. — Korrekturen zu 40

Live-Überwachung gelesen ([ChangeWatcher.swift](diskindex/diskindex/Indexing/ChangeWatcher.swift)). Aufbau, Ruhezeit, Ausschlüsse, Ereignisstand und Pause sind in Ordnung. **Drei Fehler in `flush`**, keiner wird von den bisherigen Tests erfasst (es gibt keinen Test für neue Ordner und keinen für fehlgeschlagenes Lesen):

- **K1 Ein neu angelegter Ordner wird nicht gelesen:** `flush` schreibt alle Stapel erst **nach** der Schleife (`applyDirectories` am Ende). Kommt ein neuer Ordner an die Reihe, kennt der Speicher ihn noch nicht (`folderID` liefert nichts), der Ordner wird per `continue` übersprungen. Zusätzlich steht er dann schon in `seen`, sodass der spätere Eintrag aus dem Elternordner ihn nicht mehr nachholt. Ergebnis: Kopiert der Nutzer einen **Ordner mit Dateien** auf das Medium, erscheint der Ordner leer und bleibt es bis zum nächsten Abgleich. Das ist der typische Fall.
  - **Soll:** Jeden Ordner sofort nach dem Lesen schreiben (`applyDirectories` je Ordner, oder je Ebene), damit die `parentID` neuer Ordner bekannt ist, bevor ihr Inhalt gelesen wird. Neue Ordner werden mit Unterbaum bis zur Scan-Tiefe gelesen.
- **K2 Lesefehler zählt als „leer“ und markiert alles als entfernt:** `(try? await access.listDirectory(...)) ?? []` macht aus einem fehlgeschlagenen Lesen eine leere Liste. `applyDirectories` markiert dann **alle bisherigen Einträge dieses Ordners als entfernt**. Passiert, wenn das Medium zwischen Ereignis und Nachlesen abgezogen wird (Abziehen ohne Auswerfen gibt kein `willUnmount`) oder der Zugriff entzogen wird. Die Aufgabe 39 verlangt: Nur ein **erfolgreich gelesener** Ordner ist die Wahrheit, sonst überspringen.
  - **Soll:** Schlägt das Lesen fehl, den Ordner überspringen (kein Stapel), Protokollzeile, weiter. Bleiben so Ordner ungelesen, das Ereignis im nächsten Abgleich nachholen (kein Sonderfall nötig).
- **K3 Jede Änderung liest den ganzen Baum bis zur Scan-Tiefe neu:** `flush` hängt **alle** Unterordner eines gelesenen Ordners an `directories` an (`for entry in entries where entry.isFolder`), nicht nur neue. Eine Änderung im Wurzelordner führt so zu einem vollständigen Lauf über alle Ordner der Tiefe, alle 2 Sekunden Aktivität. Bei einer großen Platte wäre das ein Dauerlauf.
  - **Soll:** Nur in Ordner absteigen, die **neu** sind (im Speicher nicht vorhanden oder als entfernt markiert), oder die selbst ein Ereignis ausgelöst haben.
- **Tests ergänzen** (`ChangeWatcherTests`): (a) Ordner mit zwei Dateien darin wird angelegt (Ereignisse für Ordner und Dateien): nach der Ruhezeit sind Ordner und beide Dateien im Speicher. (b) Lesen eines gemeldeten Ordners schlägt fehl: bisherige Einträge bleiben unberührt, keine Grabsteine. (c) Änderung in der Wurzel liest **nur** die Wurzel, nicht die Unterordner (Attrappe zählt Aufrufe). (d) Ein Ordner, der als entfernt markiert war und wieder auftaucht, wird samt Unterbaum wieder gelesen.

**Status:** Erledigt durch Cursor. `ChangeWatcher.flush` schreibt jeden erfolgreich gelesenen Ordner sofort, bevor neue Kinder gelesen werden. Fehlt die Elternzeile, wird der Pfad bis zu zweimal zurückgestellt. Ein Lesefehler schreibt keinen Stapel und wird protokolliert; bestehende Einträge bleiben. Abgestiegen wird nur in Ordner, die im Speicher fehlen oder selbst ein Ereignis ausgelöst haben, und nur innerhalb der Scan-Tiefe. Tests a–d in `ChangeWatcherTests` grün, die bisherigen Watcher-Tests ebenfalls.

---

## 46. Filter wirkt in allen Spalten (Konzeptkorrektur, Nutzer 30.09.)

**Status:** Erledigt durch Cursor. `ColumnBrowserFiltering` filtert jede Ordnerspalte. „Ordner weiterhin anzeigen“ (Standard) lässt alle Ordner stehen; aus blendet sie aus, der geöffnete Ordner bleibt. Jede Spalte, die etwas ausblendet, zeigt `NAME · x VON y`, sonst `NAME · N ELEMENTE`. Die Fußleiste zählt weiter nur die rechte Spalte. In der Spaltenansicht steht in der Filterleiste `In „<Mediumname>“`. Der Mediumwechsel setzt den Pfad zurück (`selectMedium`), die Filter bleiben. Tests a–d in `ColumnFilterTests`.

**Befund (Screenshot des Nutzers):** Filter „Audio“, Ordner „Hip-Hop DE“ geöffnet. Die rechte Spalte zeigt nur Audiodateien, die **Wurzelspalte links zeigt wieder Nicht-Audio** („Bildschirmfoto …png“). Das ist inkonsistent. Ursache: [ColumnBrowserView.swift](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift) `filteredItems` filtert nur die Spalte `columnIndex == pathStack.count` (die rechte). Das folgt dem Layout (Sektion 08: „übergeordnete Spalten bleiben vollständig“).

**Entscheidung Nutzer 30.09.:** Der Filter gilt für **alle Ordnerspalten** des geöffneten Pfads, nicht nur für die rechte. Die Layout-Regel in Sektion 08 ist damit **überholt** (der Nutzer passt das Layout an).

**Soll:**
- `filteredItems` filtert **jede** Ordnerspalte mit denselben Filtern (Dateityp, eigene Endungen, Alter, Oder/Und).
- **Ordner** in allen Spalten: Ist „Ordner weiterhin anzeigen“ an (Standard), bleiben **alle** Ordner sichtbar. Ist sie aus, fallen Ordner heraus wie bisher, **außer** dem Ordner, der in der nächsten Spalte geöffnet ist (der Pfad bleibt sichtbar und markiert).
- **Spaltenkopf:** In jeder Spalte, in der der Filter etwas ausblendet, `NAME · x VON y`, sonst `NAME · N ELEMENTE` (bisher nur rechts). Die **Fußleiste** bleibt wie sie ist (rechte Spalte, „x von y Objekten“).
- **Beschriftung rechts in der Filterleiste** (Spaltenansicht): statt „In „<Ordner>““ jetzt **„In „<Mediumname>““**. Der Filter gilt für das ganze Medium in dieser Ansicht, nicht mehr für einen Ordner. Favoriten bleiben bei „In Favoriten“.
- Beim Wechsel des Mediums in der Seitenleiste bleiben die Filter (unverändert, Aufgabe 23.2), der Pfad wird zurückgesetzt.
- Detail-Spalte und Suche unverändert.
- **Tests:** Fixture mit Wurzel (Ordner, `.mp3`, `.png`) und Unterordner (`.mp3`, `.txt`). (a) Filter „Audio“: Wurzelspalte zeigt Ordner und `.mp3`, **kein** `.png`; Unterspalte zeigt nur `.mp3`. (b) „Ordner weiterhin anzeigen“ aus: Wurzelspalte zeigt nur `.mp3` und den geöffneten Ordner. (c) Spaltenköpfe „x VON y“ in beiden Spalten, Fußleiste zählt die rechte. (d) Filter zurücksetzen (✕) zeigt wieder alles.

---

## 47. Vorläufig immer hell: Dunkelmodus des Macs (Nutzertest 30.09.)

**Status:** Erledigt durch Cursor und von Aufgabe 48 ersetzt. Erzwungenes Hell (`NSApp.appearance = .aqua` in `applicationWillFinishLaunching`, vor Fenstern, nicht unter XCTest) steht nicht im Code: 48 nimmt es zurück. Die App folgt dem System. Das Menüleisten-Symbol bleibt Template, natives `NSMenu` und Systemdialoge bleiben systemgesteuert. Der Check „alle Screens hell bei dunklem Mac“ entfällt.

**Befund (Screenshot des Nutzers, Mac im Dunkelmodus):** Die Toolbar ist dunkelblau, die Platzhalter „Objekte suchen…“ und „Medium suchen…“ sind unsichtbar (weiße Systemschrift auf hellem Feld), Icons und Beschriftungen kaum lesbar. Ursache: Die App nutzt feste helle Farben (`DesignColor`, laut Layout nur Hell), die System-Elemente (Textfelder, Titelleiste, Fenster) folgen aber dem Dunkelmodus. Das Layout kennt keinen Dunkelmodus.

**Soll (vorläufig, kleine Änderung):** Die App bleibt **immer hell**: `NSApp.appearance = NSAppearance(named: .aqua)` früh beim Start (`applicationWillFinishLaunching`). Das gilt für alle Fenster und Panels (Hauptfenster, Erkennungs-Dialog, Kontextmenü-Panel, Menüleisten-Popover, Einstellungen). Das Menüleisten-Symbol (Template) folgt weiter dem System, das ist richtig. Natives `NSMenu` (Rechtsklick auf das Menüleisten-Symbol) und Systemdialoge von macOS bleiben systemgesteuert.

**Nicht Teil:** Ein echter Dunkelmodus. Er braucht zuerst ein Farbkonzept für Dunkel im Layout und wird danach als eigene Aufgabe geplant.

**Prüfung:** Mac auf Dunkel stellen. Übersicht, Spaltenansicht, Suche, Favoriten, Einstellungen, Erkennungs-Dialog, Menüleisten-Popover, Kontextmenü und Filter-Popover sehen aus wie in Hell, Platzhaltertexte sind lesbar. Zurück auf Hell: unverändert.

---

## 48. Dunkelmodus (Layout vom 30.09., Sektion 13 „Farbrollen · Dark Mode“)

**Status:** Erledigt durch Cursor. `DesignColor` ist dynamisch (`NSColor`-Anbieter, `bestMatch` aus darkAqua/aqua) mit der Wertetabelle. Auswahl ist in Dunkel `#4A4949` und damit getrennt von `control`. Chip-Fläche 12 % in Dunkel, 5 % in Hell. Schrift auf `control` ist in Dunkel `#1F1F1F` (`onControl`), Schrift auf der Auswahl bleibt weiß (`onSelection`). Kein erzwungenes Hell, Umschalten ohne Neustart, keine Einstellung Hell/Dunkel/System. Hex-Werte außerhalb der Tokens nur im Icon-Skript. Weiß bleibt die Platte hinter dem Menüleisten-Badge; Schwarz bleibt die unsichtbare Klickfläche (Deckkraft 0,001), die Abdunkung des Detail-Overlays (0,08) und die Verlaufsmaske. `AppearanceColorTests` prüft `bg`, `text`, `control`, `stateOnline` und die Chip-Deckkraft. Debug-Testlauf und Release-Build grün. Der visuelle Vergleich mit den Dark-Blöcken (Sektionen 02–13) und das Live-Umschalten am Mac sind nicht gelaufen.

**Quelle:** [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html): jede Sektion 02 bis 12 hat darunter einen Block „DARK MODE“ (02 Erkennungs-Dialog, 03 Dropdown/Popover, 04 Übersicht, 05 Einstellungen, 06 Detail-Overlay, 07 Spaltenansicht, 08 Spalten mit Filter, 09 Filter-Auswahl, 10 Suche, 11 Favoriten, 12 Kontextmenü) und Sektion 13 den Styleguide „DARK MODE · FARBROLLEN“. **Kein Screenshot abtippen, die Werte unten gelten.** Kein invertierter Kontrastmodus: schwarzer Grund, Fenster #1F1F1F, Flächen #2A2A2A.

**Vorbedingung:** Aufgaben 46 und 47 sind erledigt. Diese Aufgabe **ersetzt** 47 (erzwungenes Hell wird entfernt).

**Farbwerte (sRGB, aus OKLCH umgerechnet; Hell = bisheriger Wert in `DesignTokens.swift`):**

| Rolle (`DesignColor`) | Hell | Dunkel |
|---|---|---|
| `bg` (Fenster, Seitenleiste) | #F3F2F2 | **#1F1F1F** |
| `surface` (Dialoge, Menüs, Detail-Panel) | #EAE9E9 | **#2A2A2A** |
| `text` | #201E1D | **#EAE9E9** |
| `divider` | #201E1D, 40 % | **#EAE9E9, 18 %** |
| `control` (Bedienung: Primär-Button, aktive Tabs, Selectgroup, Slider, Checkbox, Rechtsklick-Rahmen) | #1F1F1F | **#EAE9E9** |
| Auswahl (`sidebarActiveBackground`, ausgewählte Zeilen, Reset-✕ am Filter-Button) | #1F1F1F | **#4A4949**, Schrift/Icons darauf **weiß** |
| `stateOnline` (grün) | #20A04E | **#5BBD74** |
| `stateError` (rot) | #E04830 | **#F57050** |
| `stateIgnored` (gelb) | #EDA12D | **#EDA12D** (unverändert) |
| `filterSearch` (blau) | #3986E4 | **#65A7FA** |
| `favorite` (violett) | #9D69D2 | **#B98CEA** |
| `settingsActive` (türkis) | #00B5B5 | **#00BFC0** |
| `stateOff` (grau) | #868686 | **#929292** |
| `neutral100 … neutral900` | F8F4F4, EAE7E7, D7D3D3, BAB6B6, 9B9797, 7D7979, 605D5D, 444141, 2D2B2B | **2D2B2B, 444141, 605D5D, 7D7979, 9B9797, BAB6B6, D7D3D3, EAE7E7, F8F4F4** (Stufen laufen umgekehrt, Namen bleiben) |
| **Chip-Fläche** (`chipFill`) | Rollenfarbe 5 % | **Rollenfarbe 12 %** (5 % verschwindet auf Dunkel) |
| Chip-Rand | Rollenfarbe | Rollenfarbe (unverändert, gestrichelt = unvollständig bleibt) |

Text-Abstufungen im Layout sind `text` mit Deckkraft (60 %, 55 %, 35 %); die bleiben prozentual gleich.

**Soll:**
1. **`DesignColor` dynamisch machen:** jede Farbe als dynamische `Color` (`NSColor(name:nil){ appearance in … }` oder Asset-Katalog mit „Any/Dark“), abhängig von `NSApp.effectiveAppearance`. Alle Werte oben, keine harten Hex-Werte mehr in Views (kurz per `grep -rn "Color(hex\|0x[0-9A-F]\{6\}"` prüfen, was außerhalb der Tokens steht, und auf Tokens umstellen).
2. **Erzwungenes Hell aus Aufgabe 47 entfernen.** Die App folgt dem System (Hell/Dunkel), auch live beim Umschalten ohne Neustart. Gilt für Hauptfenster, Erkennungs-Dialog, Kontextmenü-Panel, Menüleisten-Popover, Einstellungen, Filter-Popover.
3. **Systemelemente:** Textfelder, Platzhalter, Titelleiste und Toolbar stimmen mit dem Dunkel-Layout überein (Platzhalter lesbar, `text` 35–60 %). Nichts mit `.white`/`.black` fest verdrahten (Ausnahme: Schrift auf Auswahl = weiß).
4. **Icon-Farben je Rolle** wie „ICONS JE FARBE“ im Dark-Styleguide (Grün online, Rot Fehler, Gelb ignoriert, Blau Filter, Violett Favorit, Türkis Einstellungen, Grau pausiert/aus, Hell Bedienung).
5. **Menüleisten-Symbol** bleibt Template (folgt dem System). **App-Icon** unverändert (ein Icon für beide Modi).
6. **Menüleisten-Popover** (Sektion 03 „Dropdown“) hat einen eigenen Dark-Block und gilt wie alle anderen: gegen ihn bauen und vergleichen.

**Prüfung:** Mac auf Dunkel stellen und alle Screens gegen die Dark-Blöcke im Layout vergleichen (Sektionen 02 bis 12, dazu Menüleisten-Popover). Live-Umschalten Hell↔Dunkel bei offener App. Hell sieht exakt aus wie vorher. Unit-Test: Dunkelwerte der Tabelle (mindestens `bg`, `text`, `control`, `stateOnline`, `chipFill`-Deckkraft) unter erzwungener dunkler Appearance.

---

## 40. Live-Änderungen und Abgleich beim Anschließen *(Freigabe erst nach den Korrekturen oben)*

**Status:** Erledigt durch Cursor. `ChangeWatcher` plus `ChangeSource` (`FSEventsChangeSource` mit `sinceWhen = jetzt`, Latenz 1 s, dateigenau; Tests speisen `ScriptedChangeSource`). Ruhe 2 s in der App, in Tests kürzer. Ausgeschlossene Namen und `._…` lösen nichts aus. Pfade jenseits der Scan-Tiefe lesen nur den Ordner der letzten gespeicherten Ebene neu. Ein neuer Ordner innerhalb der Tiefe wird samt Unterbaum bis zur Scan-Tiefe gelesen. `MustScanSubDirs` und `RootChanged` starten einen vollen Lauf über `IndexingService.start(fromScratch: true)` (Zeilen bleiben, es gibt keinen eigenen Unterbaum-Lauf). `fsEventsUUID` und `lastEventID` werden alle 5 s, nach jedem Ordnerstapel und bei `willUnmount` geschrieben. Ein bekanntes, fertig indiziertes Medium startet zuerst den Strom, dann den Abgleich. Ein laufender Abgleich wird beim Abziehen auf `pending` gesetzt und beim nächsten Anschließen fortgesetzt. Pause unterdrückt Strom und Abgleich; Aufheben holt einen Abgleich nach. Tests a–i grün. Der Nutzertest aus der README ist nicht gelaufen.

Letzter Baustein. Konzept: [README.md](README.md) → „Änderungen, Löschen, Wiederherstellen“ und „Ablauf beim Anschließen“ (Schritte 7 bis 9). Gemessen im Spike: FSEvents liefert auf externen Medien dateigenau (Ereignis-ID, Flags, unter 10 ms), beim Auswerfen kommt `willUnmount`, beim Abziehen ohne Auswerfen nur `didUnmount`.

- **`ChangeWatcher`:** je angeschlossenem, fertig indiziertem Medium (`decision == .index`, `indexStatus == .indexed`) ein FSEvents-Strom auf dem Einhängepfad, dateigenau, Verzögerung 1 s, `sinceWhen = jetzt`. Hinter einer Schnittstelle (`ChangeSource`), damit Tests Ereignisse einspeisen können.
- **Sammeln statt sofort lesen:** Ereignisse landen in einer Menge „geänderte Ordner“ (Elternordner des geänderten Pfads). Ausgenommen: ausgeschlossene Namen und `._…` (Regeln aus 39.1), Pfade tiefer als die Scan-Tiefe (nur ihr Ordner der letzten Ebene zählt), Pfade außerhalb des Einhängepunkts. Nach **2 s Ruhe** werden die gesammelten Ordner neu gelesen (`applyDirectories` mit neuem `seenAt`): Neues erscheint, Gelöschtes wird als entfernt markiert, Wiederhergestelltes wieder aktiv, Favoriten bleiben.
- **Neuer Ordner** innerhalb der Scan-Tiefe: seinen Unterbaum bis zur Scan-Tiefe nachlesen.
- **Überlauf** (`MustScanSubDirs`, verworfene Ereignisse) und `RootChanged`: betroffenen Unterbaum bzw. das ganze Medium ebenenweise neu lesen (`IndexingService` ohne Zurücksetzen).
- **Zustand sichern:** `fsEventsUUID` und `lastEventID` am Medium **laufend** speichern (gebündelt alle 5 s und bei jedem verarbeiteten Ordnerstapel), zusätzlich bei `willUnmount`. Abziehen ohne Auswerfen verliert höchstens wenige Sekunden. Der Ereignisstand dient nur der Beschleunigung, verlassen wir uns nicht darauf.
- **Abgleich beim Anschließen** eines bekannten, fertig indizierten Mediums (`decision == .index`): **immer** ein vollständiger ebenenweiser Lauf gegen den gespeicherten Stand (`IndexingService.start(fromScratch: true)`), weil ein anderer Rechner oder Windows Änderungen gemacht haben kann. Vorher den Ereignisstrom starten (`sinceWhen = jetzt`), damit Änderungen während des Abgleichs nicht verloren gehen. Der alte Stand bleibt währenddessen sichtbar und durchsuchbar; die Oberfläche zeigt den vorhandenen Zustand „wird indiziert“. Ohne Änderungen sieht der Nutzer danach exakt dasselbe wie vorher.
- **Medium verschwindet:** Strom stoppen, Zustand sichern, Medium offline. Ein laufender Abgleich bricht leise ab (`pending`) und setzt beim nächsten Anschließen fort.
- **Pause:** Ist das automatische Indizieren pausiert, laufen weder Strom noch Abgleich (Überwachung wird bei Aufheben der Pause nachgeholt: ein Abgleich).
- **Tests** (mit `ChangeSource`-Attrappe und temporärer Datenbank): (a) Ereignis für eine neue Datei → nach 2 s Ruhe steht sie im Speicher. (b) Mehrere Ereignisse desselben Ordners in 1 s ergeben **ein** Nachlesen. (c) Gelöschte Datei wird als entfernt markiert, neu angelegte gleichen Namens belebt die Zeile mit Favorit. (d) `._`-Datei und ausgeschlossene Namen lösen nichts aus. (e) Ereignis tiefer als die Scan-Tiefe wirkt nur bis zur letzten Ebene. (f) Überlaufereignis startet einen Lauf. (g) Bekanntes, fertig indiziertes Medium wird beim Anschließen abgeglichen, unbekanntes nicht. (h) `lastEventID` wird gespeichert und nach Neustart gelesen. (i) Abziehen bricht laufenden Abgleich ab, erneutes Anschließen setzt fort.
- **Prüfung durch den Nutzer** steht im Testablauf am Ende der Umstellung (Abschnitt „Nutzertest“ in der README).

---



---

# Nachtrag 30.09. (3) — Aufgaben 53, 50, 51, 52, 54, 55 (freigegeben)

Freigabe Claude 30.09.: Debug-Tests und Release-Build grün. Absturzschreiber real geprüft: Release-Build gestartet, `kill -SEGV`: `crash-last.txt` mit `CRASH signal=SIGSEGV` und Stapelspur, beim nächsten Start „previous run ended abnormally“ und der Dialog „Disk Index wurde unerwartet beendet“ mit „Bericht kopieren“. Nicht am Bildschirm geprüft: Dark-Vergleich, Dock-Icon-Zustände, Mehrfachauswahl, Schatten.

## 53. Erweitertes Protokoll für Tests (Nutzer 30.09.)

**Status:** Erledigt durch Cursor. `DiskIndexLog` schreibt nach `~/Library/Logs/Disk Index/diskindex.log`, jede Zeile sofort (`synchronizeFile`), Rotation ab 5 MB auf `diskindex.1.log` und `diskindex.2.log`. Kategorien `app`, `medium`, `index`, `watcher`, `store`, `ui`, `perf` gehen zusätzlich an `os.Logger` (Subsystem `xjonx.diskindex`, Pfade dort `privacy: .private`). Die Aktionsspur hält die letzten 50 `ui`-Zeilen. `NSSetUncaughtExceptionHandler` und die Signale `SIGABRT`, `SIGILL`, `SIGTRAP`, `SIGSEGV`, `SIGBUS` schreiben `CRASH signal=…`, die Spur und `backtrace_symbols_fd`, danach das Standardverhalten. Fehlt am Dateiende `app terminate ok`, steht beim nächsten Start `previous run ended abnormally`. Schreibfehler von `applyDirectories`, `setFavorites`, `updateMedium`, `deleteMedium` und `writeMedium` werden als `store`/`watcher` error protokolliert. Unter XCTest schreibt die gemeinsame Instanz nicht in den Nutzerordner. Einstellungen → Allgemein und das Menüleisten-Kontextmenü haben „Protokoll im Finder zeigen“. Tests a–d grün. Der Absturz selbst ist nicht ausgelöst.

**Anlass:** Der Absturz aus Aufgabe 49 tritt beim Nutzer in der normal gestarteten App auf, **nicht** wenn er aus Xcode läuft (Debug). Ohne Xcode gibt es keine Konsole und keinen Absturzbericht in `~/Library/Logs/DiagnosticReports`. Wir brauchen eine Spur, die die App selbst schreibt und die den Absturz überlebt. Mögliche Ursachen des Unterschieds, die Cursor bei 49 mit dem Protokoll prüft: Release statt Debug (Optimierung, andere Laufzeitprüfungen), Zustand der Datenbank, zweite Instanz/Einzelinstanz-Regel, Startweg (Login-Item, Finder).

**Soll:**
1. **Protokolldatei:** `~/Library/Logs/Disk Index/diskindex.log`, Textzeilen mit Zeitstempel (ms), Kategorie, Stufe, Meldung. **Jede Zeile sofort auf die Platte schreiben** (kein Puffer, der beim Absturz verloren geht). Rotation: bei 5 MB nach `diskindex.1.log`, höchstens 3 Dateien. Läuft in Debug **und** Release, immer an (kein Schalter nötig).
2. **Kategorien** über `os.Logger` (Subsystem `xjonx.diskindex`) und zusätzlich in die Datei gespiegelt: `app` (Start, Version/Build, Debug/Release, macOS, Instanz-Übergabe, Beenden), `medium` (erkannt, ein-/ausgehängt, Entscheidung, Kennung/Treffer-Stärke), `index` (Lauf Start/Ebene/Ende/Fehler, Zähler), `watcher` (Ereignisse gebündelt, Nachlesen, Fehler, Ereignisstand), `store` (jede Schreiboperation mit Art und Anzahl, Fehler mit vollem Text), `ui` (Aktionen des Nutzers, siehe 3), `perf` (Vorgänge über 200 ms mit Dauer).
3. **Aktionsspur („Breadcrumbs“):** Jede Nutzeraktion mit Ziel protokollieren, mindestens: Ansicht gewechselt, Medium gewählt, Ordner geöffnet, Suche gestartet, Filter geändert, **Favorit an/aus mit Art (Datei/Ordner/Medium), Zeilen-ID, Ansicht**, Kontextmenü-Eintrag gewählt, Einstellungen geändert, Medium vergessen/Neu-Indizieren/Pause. Beispiel: `ui  toggleFavorite kind=file id=… rowID=… view=columns`.
4. **Ausnahmen und Abstürze festhalten:** `NSSetUncaughtExceptionHandler` und Signal-Handler für `SIGABRT`, `SIGILL`, `SIGTRAP`, `SIGSEGV`, `SIGBUS` schreiben `CRASH signal=… ` plus **Stapelspur** (`Thread.callStackSymbols` bzw. `backtrace_symbols_fd` auf den Dateideskriptor, signalsicher) und die **letzten 50 Zeilen der Aktionsspur** in die Datei, danach Standardverhalten. (Swift-Laufzeitfehler wie Force-Unwrap, Indexfehler, doppelte Wörterbuchschlüssel enden als `SIGILL`/`SIGTRAP`.) Beim nächsten Start: steht am Ende der alten Datei kein `app terminate ok`, protokollieren `previous run ended abnormally`.
5. **Fehler nicht verschlucken:** Jedes `try?` auf dem Schreib- und Indexpfad (`IndexStore`, `IndexingService`, `ChangeWatcher`, `AppState.writeMedium/toggleFavorite`) meldet bei Fehler `store`/`index` **error** mit dem Fehlertext. Keine `catch {}` ohne Zeile.
6. **Datenschutz:** Dateinamen und Pfade nur in der Datei (lokal), nie an einen Dienst senden. Keine Zugangsdaten. Im `os.Logger` Pfade als `privacy: .private`.
7. **Bedienung:** Einstellungen → Allgemein, ganz unten ein unauffälliger Eintrag „Protokoll im Finder zeigen“ (öffnet den Ordner mit der Datei) und Menüleisten-Kontextmenü gleicher Eintrag. Kein neues Layout nötig, nur Texteintrag im bestehenden Stil (Nutzer darf ihn später ins Layout übernehmen).
8. **Tests:** (a) Zeile erscheint sofort in der Datei (kein Puffer). (b) Rotation bei Größe. (c) Aktionsspur liefert die letzten 50 in Reihenfolge. (d) Der Absturz-Pfad selbst wird nicht per Test ausgelöst, aber der Schreibaufruf mit einer künstlichen Spur schon.

**Prüfung durch den Nutzer:** App normal starten (nicht aus Xcode), Favorit markieren, Absturz auslösen. Danach steht in `diskindex.log` die letzte Aktion, das Signal und die Stapelspur. Diese Datei an Claude weitergeben.

---

## 50. Schatten im Dunkelmodus zu hell (Nutzertest 30.09.)

**Status:** Erledigt durch Cursor. `DesignColor.shadow` ist fest `#2D2B2B`. Kontextmenü, Filter-Popover, Erkennungs-Dialog, Detail-Overlay, Einstellungen-Seitenleiste und Spaltenansicht nutzen ihn. Das Menüleisten-Popover setzt denselben Schatten als `NSShadow` (22 %, y 12, Blur 32) statt des Systemschattens. Die Abdunkung des Detail-Overlays bleibt Schwarz. Der visuelle Vergleich mit den Dark-Blöcken ist nicht gelaufen.

**Befund:** Im Dunkelmodus hat das Kontextmenü einen hellen „Glow“. Ursache: Die Schatten benutzen `DesignColor.neutral900` bzw. `DesignColor.text`. Beide Rollen kippen im Dunkelmodus auf fast Weiß (#F8F4F4, #EAE9E9), aus dem Schatten wird ein Leuchten. Das Layout nimmt in beiden Modi **dieselbe dunkle Farbe** #2D2B2B (`--shadow-sm/md/lg`), nicht die Rolle.

**Soll:**
- Neuer Token `DesignColor.shadow` = **#2D2B2B in Hell und in Dunkel** (nicht dynamisch). Deckkraft und Radius bleiben wie im Layout (`sm` 14 %/y1/Blur2, `md` 16 %/y3/Blur10, `lg` 22 %/y12/Blur32).
- Alle Schatten darauf umstellen: [ObjectFileContextMenu.swift:156](diskindex/diskindex/DesignSystem/ObjectFileContextMenu.swift), [SearchFilterPopoverPanel.swift:29](diskindex/diskindex/Views/Search/SearchFilterPopoverPanel.swift), [NewMediumDetectedDialog.swift:89](diskindex/diskindex/Views/Registry/NewMediumDetectedDialog.swift), [MediumDetailModalView.swift:50](diskindex/diskindex/Views/Detail/MediumDetailModalView.swift), [SettingsView.swift:47](diskindex/diskindex/Views/Settings/SettingsView.swift), [ColumnBrowserView.swift:161](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift), Menüleisten-Popover. `grep -rn "\.shadow(" diskindex` muss danach kein `DesignColor.text`/`neutral*` mehr enthalten.
- Prüfen, dass **nichts anderes** dieselbe Falle hat: Verwendungen von `neutral*` und `text` als **Effekt** (Schatten, Abdunkung, Verlaufsmaske) statt als Flächen- oder Schriftfarbe. Abdunkung des Detail-Overlays bleibt schwarz.
- Vergleich: Dark-Block Sektion 12 (Kontextmenü), 02 (Dialog), 09 (Filter-Popover), 06 (Detail-Overlay). Der Schatten ist dort kaum sichtbar auf #000-Grund, das Menü hebt sich über die Fläche #2A2A2A und die Trennlinie ab.

---

## 51. „Im Finder anzeigen“ (Nutzertest 30.09.)

**Status:** Erledigt durch Cursor. `FinderReveal` hängt den gespeicherten Pfad an `mountPath` des Koordinators (`AppState.mountPath`). Offline liefert `nil`, der Menüeintrag bleibt aus, solange `isMediumOnline` falsch ist. Fehlt die Datei, wird der übergeordnete Ordner geöffnet, wenn er existiert. Ein Medium öffnet den Einhängepfad. Tests: Sonderzeichen, Leerzeichen, Umlaute, Offline, Medium. In „Später“ stand der Eintrag nicht mehr.

**Befund:** Der Menüeintrag „Im Finder anzeigen“ (Kontextmenü, Detail-Spalte) hat keine Wirkung: `AppState.revealInFinder` ist leer. Es gibt jetzt echte Pfade.

**Soll:**
- `revealInFinder(_ target:)`: Vollständigen Pfad bilden = Einhängepfad des **angeschlossenen** Mediums + gespeicherter relativer Pfad des Objekts (`StoredItem.path`, mit Namen). Dann `NSWorkspace.shared.activateFileViewerSelecting([url])`.
- Ist das Objekt ein **Medium**: das Volume im Finder zeigen (Einhängepfad).
- Das Medium ist **offline**: Eintrag deaktiviert (ausgegraut) wie im Layout für Offline-Objekte, keine Aktion. Existiert die Datei nicht mehr (zwischenzeitlich gelöscht): den übergeordneten Ordner öffnen, sonst nichts tun. Kein Absturz.
- Der Einhängepfad kommt vom Koordinator (`MediumCoordinator`/`VolumeInfo.mountPath`), nicht aus dem Speicher ableiten. Lege dafür eine kleine Abfrage `mountURL(for: mediumID)` an, in Tests austauschbar.
- Aus „Später“ entfernen (dort erledigt).
- **Tests:** Pfadbildung (relativer Pfad plus Einhängepfad, Sonderzeichen, Leerzeichen, Umlaute), Offline liefert `nil`, Medium liefert Einhängepfad.

---

## 52. Dock-Icon unterschiedlich groß je nach Fensterzustand (Nutzer 30.09.)

**Status:** Erledigt durch Cursor. Ursache: `applicationIconImage` wurde nur beim Wechsel auf `.regular` gesetzt. Ist das Fenster nicht aktiv, zeichnet das Dock das Bundle-Icon und skaliert es größer, obwohl `AppIcon` und `DockIcon.png` pixelgleich sind. Dieselbe Laufzeitgrafik wird jetzt nach dem Policy-Wechsel und bei `didBecomeActive` sowie `didResignActive` gesetzt, solange die Policy `.regular` ist. Die Bilddateien sind unverändert. Die fünf Dock-Zustände (Fenster aktiv, andere App vorn, Fenster zu, angeheftet ohne Lauf, Debug und Release) sind hier nicht am Bildschirm verglichen.

**Befund (Nutzer):** Ist die App aktiv und das Hauptfenster offen und aktiv, hat das Dock-Icon die richtige Größe. Ist das Hauptfenster **nicht aktiv**, erscheint das Icon **zu groß**. Die Bilddateien sind nicht schuld: `AppIcon` (1024 px) und `DockIcon.png` sind pixelgleich (sichtbare Kachel 81…943 px, Raster stimmt). Es liegt am **Weg**, wie das Dock das Bild bekommt: [AppActivationPolicy.swift](diskindex/diskindex/App/AppActivationPolicy.swift) setzt `NSApp.applicationIconImage = NSImage(named: "DockIcon")` (Laufzeitbild, wird unverändert gezeichnet). In anderen Zuständen kommt das Bild aus dem Bundle-Icon (`AppIcon`), das macOS selbst skaliert/maskiert.

**Soll:**
1. Zustände durchprobieren und im Status festhalten, wie groß das Icon im Dock jeweils ist (mit einem Nachbar-Icon vergleichen): (a) Hauptfenster offen und aktiv, (b) Hauptfenster offen, andere App aktiv, (c) Fenster geschlossen, Policy `.accessory`, (d) App nicht gestartet, angeheftet, (e) Debug aus Xcode und Release.
2. Ursache benennen und **einen** Weg wählen, sodass das Icon **in allen Zuständen gleich groß** ist (so groß wie die Apple-Icons daneben):
   - Bevorzugt: Laufzeitbild `applicationIconImage` **nicht** setzen, sondern das Bundle-Icon verwenden (Info.plist `CFBundleIconName`/`CFBundleIconFile` prüfen, AppIcon-Set vollständig 16 bis 1024). Falls der leere Dock-Tile nach dem Policy-Wechsel (Aufgabe 23.1) dann wieder auftritt, `applicationIconImage` erst **nach** dem Wechsel und beim Aktivieren/Deaktivieren (`didBecomeActive`, `didResignActive`) erneut setzen, damit es nie auf einen anderen Stand zurückfällt.
   - Achtung: Diese Aufgabe ändert **nicht** die Bilddateien und **nicht** die Kachel-/Symbolgröße (die sind vom Nutzer freigegeben).
3. **Prüfung durch den Nutzer:** Icon im Dock gleich groß bei aktivem Fenster, inaktivem Fenster (andere App vorn), und nach Schließen und Neuöffnen des Fensters.

---

## 54. Mehrfachauswahl in der Spaltenansicht (Nutzer 30.09., Layout folgt)

**Status:** Erledigt durch Cursor. `ColumnSelection` ersetzt `selectedFileID`: Klick, ⌘-Klick, ⇧-Klick, ⌘A auf die sichtbaren Zeilen, Esc lässt das zuletzt Angeklickte, Pfeile mit ⇧ erweitern. Eine Auswahl gilt nur in einer Spalte. Ein einzelner Ordner öffnet die nächste Spalte, mehrere Objekte schließen die Spalten rechts. Die Detail-Spalte zeigt bei Mehrfachauswahl `FileTypeFiles`, „N Objekte“ und „Größe gesamt“. Die Fußleiste zeigt „n von m ausgewählt“ und hat Vorrang vor dem Filter. Das Kontextmenü graut Finder und beide Suchen aus (Deckkraft 0,4), Favorit und Ignorieren sind Sammelaktionen in einem Schreibvorgang (`setFavorites`, `toggleIgnoredPatterns`). Rechtsklick außerhalb ersetzt die Auswahl. Medienwechsel und Ansichtswechsel leeren die Auswahl. Tests a–k grün. Der Klick-Ablauf in Hell und Dunkel ist nicht am Bildschirm geprüft.

**Konzept (Entscheidung Nutzer, von Claude ausgearbeitet):** In einer Ordnerspalte lassen sich mehrere Objekte gleichzeitig markieren. Mit Mehrfachauswahl gibt es keine Einzelaktionen wie „Im Finder anzeigen“, dafür Sammelaktionen wie „Favorit“ und „Ignorieren“.

**Layout:** [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html), Sektion 07 „BEISPIEL — MEHRFACHAUSWAHL“ (Hell und Dunkel), Regeltext in Sektion 12 („Im Finder anzeigen … bei Mehrfachauswahl ausgegraut“). Auswahlzeilen sehen aus wie die Einzelauswahl (Rollenfarbe `control` hell bzw. `#4A4949` dunkel, Schrift weiß), jede gewählte Zeile so, mit 2 pt Abstand dazwischen.

**Auswahlregeln (wie im Finder):**
- **Klick** wählt eins (ersetzt die Auswahl). **⌘-Klick** fügt hinzu bzw. nimmt heraus. **⇧-Klick** wählt den Bereich vom Anker bis zur Zeile. **⌘A** wählt alle **sichtbaren** Zeilen der Spalte (bei aktivem Filter nur die gefilterten). **Esc** hebt die Mehrfachauswahl auf (bleibt das zuletzt Angeklickte). Pfeil hoch/runter mit ⇧ erweitert den Bereich.
- Eine Auswahl gilt **nur innerhalb einer Spalte**. Ein Klick in eine andere Spalte ersetzt sie.
- **Genau ein Ordner ausgewählt:** wie bisher, die nächste Spalte zeigt seinen Inhalt. **Mehr als ein Objekt ausgewählt** (auch mehrere Ordner): Spalten rechts der Auswahl werden geschlossen, es öffnet sich nichts. Zurück auf eine Einzelauswahl öffnet wie gewohnt.
- **Detail-Spalte bei Mehrfachauswahl (Layout):** Kopf `DETAIL`, darunter Icon `ph-files` (Phosphor „files“, 26 pt, wie das Datei-Icon im Einzeldetail), Zeile fett **„N Objekte“**, darunter in Sekundärfarbe **„Größe gesamt: 2,5 MB“** (Summe der Dateigrößen). Ordner ohne eigene Größe zählen nicht mit. Kein Dateiname, keine „Im Finder anzeigen“-Schaltfläche, kein Alter/Zuletzt gesehen. Der Medien-Fuß („x GB frei von y GB“, Status) bleibt wie im Einzeldetail.
- **Fußleiste (Layout):** bei Mehrfachauswahl rechts **„2 von 3 ausgewählt“** (Anzahl ausgewählt von Elementen der Spalte). Ohne Mehrfachauswahl wie bisher „N Objekte“ bzw. „x von y Objekten“ (Filter). Sind Auswahl und Filter beide aktiv, hat die Auswahl Vorrang.
- Ausgewählte Zeilen bleiben beim Filter-/Suchwechsel ausgewählt, solange sie sichtbar sind. Nicht mehr sichtbare fallen aus der Auswahl. Beim Mediumwechsel und beim Wechsel der Ansicht wird die Auswahl geleert.
- Gilt **nur für die Spaltenansicht** (Ordnerspalten). Suche und Favoriten bleiben Einzelauswahl, Medien in der Übersicht auch.

**Kontextmenü bei Rechtsklick:**
- Rechtsklick auf eine Zeile **innerhalb** der Auswahl wirkt auf die **ganze Auswahl**. Rechtsklick **außerhalb** ersetzt die Auswahl durch diese Zeile (Einzelmenü wie bisher).
- Menü bei Mehrfachauswahl (gleiche Gruppen, gleiche Optik wie bisher):
  | Eintrag | Verhalten bei Mehrfachauswahl |
  |---|---|
  | Im Finder anzeigen | **ausgegraut** |
  | Als Favorit markieren | Sammelaktion. Sind **alle** schon Favorit: Haken sichtbar, Klick nimmt bei allen heraus. Sonst: Klick markiert **alle**. Ein Schreibvorgang für alle, nicht einer je Zeile. |
  | Nach Namen suchen | **ausgegraut** |
  | Nach Dateiendung suchen | **ausgegraut** |
  | Dateinamen ignorieren | Sammelaktion. Fügt **alle** Namen der Auswahl der Ignore-Liste hinzu. Sind alle schon drin: Haken (rot), Klick entfernt alle. |
  | Dateitypen ignorieren | Sammelaktion über die **verschiedenen Endungen** der ausgewählten Dateien. Ausgegraut, wenn keine Datei eine Endung hat. Dieselbe Haken-Logik. |
- **Keine Anzahl im Menü:** Das Layout hängt den Einträgen **nichts** an, die Titel bleiben unverändert („Als Favorit markieren“). Ausgegraut = Deckkraft 0,4, keine Hover-Farbe, Cursor Standard.
- Gemischte Auswahl (Dateien und Ordner): „Dateinamen ignorieren“ gilt für alle Namen, „Dateitypen ignorieren“ nur für Dateien mit Endung.
- **Offline-Medium:** „Im Finder anzeigen“ ist ohnehin aus. Favorit und Ignorieren gehen auch offline (wirken auf den Speicher).

**Umsetzung:**
- `ColumnBrowserState.selectedFileID` (Einzel) wird ersetzt durch eine geordnete Menge (`selectedIDs: Set<UUID>` plus `anchorID`, `focusColumnIndex`). Die Einzelauswahl bleibt der Sonderfall mit einem Element. `selectedUncapturedFolderID` (Detail statt Spalte) gilt nur bei Einzelauswahl.
- `ObjectContextTarget` bekommt eine Variante für **mehrere** Ziele (Liste der Ziele). Menü-Builder liefert je nach Anzahl das Einzel- oder Sammelmenü.
- **Speicher:** neue Sammelmethode `setFavorite(itemIDs: [Int64], _ isFavorite: Bool)` (eine Transaktion, ein `emit(.items)`), Cache `setFavoriteLocally` für alle IDs in einem Zug. `toggleIgnoredPattern` für mehrere Muster ohne mehrfaches Speichern der Einstellungen (`scheduleSettingsSave` sammelt ohnehin).
- Aktionsspur (Aufgabe 53): `ui selection count=… column=…`, `ui toggleFavorite kind=multi count=…`.
- Die Sammelaktion von „Favorit“ darf **nicht** mit dem Absturz aus Aufgabe 49 zusammenfallen: erst 49 beheben, dann diese Aufgabe.

**Tests:** (a) ⌘-Klick fügt hinzu, zweiter ⌘-Klick nimmt heraus. (b) ⇧-Klick wählt den Bereich, Anker bleibt. (c) Auswahl in Spalte 2, Klick in Spalte 1 ersetzt sie. (d) Zwei Objekte gewählt: nächste Spalte geschlossen; eins davon abgewählt: Ordner öffnet sich wieder. (e) ⌘A mit Filter wählt nur sichtbare. (f) Favorit-Sammelaktion: alle an, dann bei allen an: alle aus, gemischt: alle an. (g) Menü bei Mehrfachauswahl: Finder und beide Suchen deaktiviert, Favorit/Ignorieren aktiv, Titel unverändert. (h) Ignorieren: drei Namen, alle drin, dann alle entfernt. (i) Endungen: drei Dateien mit `.mp3`, `.mp3`, `.flac` ergeben zwei Muster. (j) Summe der Größen in der Detail-Zusammenfassung. (k) Fußleiste „2 von 3 ausgewählt“.

**Prüfung durch den Nutzer:** Drei Dateien mit ⌘-Klick wählen, Rechtsklick: Menü zeigt die drei ausgegrauten Einträge, „Als Favorit markieren“ setzt alle drei. Detail-Spalte zeigt „3 Objekte“ und die Größe, die Fußleiste „3 von N ausgewählt“, in Hell und Dunkel wie das Beispiel in Sektion 07. Klick auf einen einzelnen Ordner öffnet die nächste Spalte wieder.

---

## 55. Absturzbericht zum Kopieren, Protokoll-Lücken, Aufräumen (Review Claude 30.09.)

**Status:** Umgesetzt. A: Dialog „Disk Index wurde unerwartet beendet“ (`CrashReportDialog` / `AppWindowPresenter.openCrashReport`) beim Start, wenn das vorherige Protokoll weder mit `app terminate ok` noch mit `app crash reported` endet; Schließen schreibt `app crash reported` und merkt die Signatur, der Dialog kommt einmal je Absturz. Bericht (`CrashReportText`) mit Version, Build, Debug/Release, macOS, `hw.model`, Start, Laufzeit, CRASH, 50 Aktionen, 100 Protokollzeilen, Datenbankgröße, optional Kopf des neuesten DiagnosticReports; Medien- und Objektzahl stehen noch als „unbekannt“. „Diagnosebericht kopieren“ in Einstellungen → Allgemein und im Menüleistenmenü (ohne CRASH, 300 Zeilen). DEBUG-Menü „Absturz testen“ ruft `fatalError`. Signalhandler: `tryLock`, `crash-last.txt` per `write`, Ring 50×240, `backtrace_symbols_fd`, `sigaltstack` und `SA_ONSTACK`. Tests a–d grün. B: `medium`/`index`/`watcher` laufen über `DiskIndexLog`; die alten `Logger` in MediumCoordinator, DirectoryIndexer, IndexingService und ChangeWatcher sind weg, LaunchAtLogin und SingleInstance bleiben. `perfIfSlow` auf Ebene, `applyDirectories`, Suche, Favoriten, Kinder-Cache und Anschluss-Abgleich. UI-Aktionen (Ziel, Filter, Suche, Medium, Auswahl, Kontext, Einstellungen, Pause, Popover, Favorit, Finder, Vergessen, Neuindex) werden geschrieben. Schreibfehler werden geloggt (`resetCompletedDepth`, `updateMedium`, `finishIndexing`, `applyDirectories`). Stille `try?` bleiben bei Lesezugriffen (`medium`, `counts`, `children`, `folderID`, `folders`) und bei `Task.sleep` (Abbruch ist kein Fehler); `IndexStore` hat kein `try?` mehr. C: entfernt `SearchResultsState`, `cancelAll`, `isOpen`, `clearButtonTrailingPadding`, Parameter `mirror`. Nur für Tests behalten, mit Kommentar: `flushMediumEdits`, `flushSettings`, `recentBreadcrumbs`, `loadChildren`, `schemaSnapshot`, `setDirectoryWritesFailing`, `waitForChoice`, `ScriptedChangeSource`. `neutral400/600/900` und `Diagnostics/` bleiben. SurfaceTests-Warnung an `record` behoben. Später: Scan-Tiefe und unsichtbare Dateien wirken über `ScanConfiguration` in `DirectoryIndexer`/`IgnoreMatcher`; `requestIgnoredObjectsPurgeNow` ist weiter leer. Debug- und Release-Build ohne Warnung, Unit-Tests grün. Dialog-Optik und ein echter Absturz außerhalb von Xcode nicht geprüft.

Review von 49 bis 54: Debug-Tests grün, Release-Build ohne Fehler. Die Aufgaben 50, 51, 52 und 54 sind im Code wie beschrieben. **Offen bleibt der Absturz aus 49** (nicht nachgestellt, nur gehärtet) und die Absicht hinter 53: Der Nutzer soll bei einem Fehler **einen Bericht einfach kopieren** können. Das fehlt noch.

**A. Absturzbericht zum Kopieren (neu)**
1. **Nach einem abnormalen Ende** (am Dateiende von `diskindex.log` fehlt `app terminate ok`, oder es steht ein `CRASH signal=`) zeigt die App beim nächsten Start **einen Dialog** im Stil des Erkennungs-Dialogs (Sektion 02, gleiche Komponenten): Titel „Disk Index wurde unerwartet beendet“, Text „Ein Bericht liegt bereit. Er enthält Programmversion, System, die letzten Aktionen und den Fehlerort, keine Dateiinhalte.“ Schaltflächen: **„Bericht kopieren“** (Primär, legt den Text in die Zwischenablage und schreibt „Kopiert“ in den Button für 2 s), **„Protokoll zeigen“**, **„Schließen“**. Erscheint einmal je Absturz.
2. **Berichtstext (reiner Text, ein Block):** Kopfzeile mit Version, Build, Debug/Release, macOS, Gerätemodell (`hw.model`), Startzeit, Laufzeit bis zum Absturz; darunter der **`CRASH`-Abschnitt** (Signal, Stapelspur), die **letzten 50 Aktionen**, die **letzten 100 Protokollzeilen** davor, Datenbankgröße und Anzahl Medien/Objekte. Pfade und Dateinamen sind lokal und dürfen drin bleiben, der Nutzer schickt den Text selbst weiter. Keine Zugangsdaten. Zusätzlich, falls vorhanden, den Kopf des neuesten macOS-Berichts (`~/Library/Logs/DiagnosticReports/Disk Index*.ips`, Ausnahme und Stapel des Absturz-Threads) anhängen.
3. **Jederzeit ohne Absturz:** Einstellungen → Allgemein neben „Protokoll im Finder zeigen“ ein zweiter Eintrag **„Diagnosebericht kopieren“** (gleicher Text, ohne CRASH-Abschnitt, letzte 300 Zeilen) und derselbe Eintrag im Menüleisten-Kontextmenü. Für den Fall „es hängt“ oder „es sieht falsch aus“.
4. **Absturzschreiber robust machen** (`DiskIndexLog.handleSignal`): Er benutzt `NSLock`, `Data`, `String`-Formatierung, `Thread.callStackSymbols` im Signal-Handler. Das ist nicht signalsicher. Stürzt die App **während** eines Schreibvorgangs ab (Sperre gehalten), **hängt** der Handler auf der Sperre und die App friert ein, statt Bericht und Absturz zu liefern. Sofort: `tryLock` mit kurzer Frist, sonst ohne Sperre weiter. Besser: beim Start eine **zweite Datei** `crash-last.txt` mit reservierter Puffergröße öffnen und im Handler nur `write(2)` auf den Deskriptor mit vorformatierter Aktionsspur (Ringpuffer als feste C-Puffer) und `backtrace_symbols_fd` verwenden. Stapelüberlauf (`SIGSEGV` auf dem Hauptthread): `sigaltstack` einrichten und `sigaction` mit `SA_ONSTACK`. Test: Handler-Aufruf **bei gehaltener Sperre** kehrt zurück und schreibt trotzdem.
5. **Tests:** (a) Bericht enthält Kopf, CRASH-Abschnitt, 50 Aktionen. (b) „Abnormal“ wird erkannt (`app terminate ok` fehlt), Dialog nur einmal je Absturz. (c) Diagnosebericht ohne CRASH. (d) Handler bei gehaltener Sperre.

**B. Protokoll-Lücken (53 war unvollständig)**
- `medium` und `index` sind angelegt, aber **von niemandem benutzt**: `MediumCoordinator`, `DirectoryIndexer`, `IndexingService`, `ChangeWatcher` (teilweise) protokollieren nur über eigene `Logger` (nur in der Systemkonsole, nicht in der Datei). Umstellen auf `DiskIndexLog.shared.record(.medium/.index/.watcher, …)`: Medium erkannt/eingehängt/ausgehängt (Kennung, Treffer-Stärke, Entscheidung), Lauf Start/Ebene fertig (Zähler)/Ende/Fehler/Abbruch, Ereignisstand gespeichert. Die drei alten `Logger` dort entfernen, `LaunchAtLogin`/`SingleInstance` dürfen bleiben.
- `perfIfSlow` wird **nirgends aufgerufen**. Einsetzen: Ebene lesen, `applyDirectories`, `favorites`, `search`, Cache-Ladevorgang in `IndexRepository`, Abgleich beim Anschließen.
- Aktionsspur (`ui`) fehlt für: Kontextmenü-Einträge (Finder, Suche, Ignorieren, Favorit im Menü), Einstellungen ändern, Filter-Popover-Auswahlen, Pause an/aus, Popover öffnen/schließen. Ergänzen.
- Verbleibende `try?` auf dem Schreib-/Indexpfad (`IndexingService`, `ChangeWatcher`, `IndexStore`, `AppState`, 17 Stück) melden bei Fehler `error` mit Text, oder begründen im Kommentar, warum still.

**C. Toter Code (Review)**
- Entfernen: `SearchResultsState` (enum samt `empty`) in [SearchState.swift](diskindex/diskindex/Models/SearchState.swift), `IndexingService.cancelAll`, `ObjectContextMenu`-Panel `isOpen` ([ObjectFileContextMenu.swift:312](diskindex/diskindex/DesignSystem/ObjectFileContextMenu.swift)), `DesignSearchField.clearButtonTrailingPadding`, der Parameter `mirror` in `DiskIndexLog.write` (wird mit `_ = mirror` verworfen).
- Prüfen und entscheiden: nur von Tests benutzte Produktionsfunktionen (`flushMediumEdits`, `flushSettings`, `recentBreadcrumbs`, `loadChildren`, `schemaSnapshot`, `setDirectoryWritesFailing`, `waitForChoice`, `ScriptedChangeSource`). Behalten, wenn sie nur für Tests da sind, aber dann mit Kommentar oder `#if DEBUG`/Test-Target verschieben. Nichts still löschen, im Status auflisten.
- Die Farb-Stufen `neutral400/600/900` sind ungenutzt: **behalten** (Palette laut Styleguide), nicht entfernen.
- `Diagnostics/` (1 486 Zeilen Spike-Code, nur Debug): behalten, solange der Nutzertest läuft. Nach Freigabe des Nutzertests durch Claude entscheiden.
- Testwarnung `SurfaceTests.swift:761` „result of call to 'record' is unused“ beheben.
- In „Später“ stehen zwei überholte Einträge (Scan-Tiefe/unsichtbare Dateien wirken inzwischen echt, `requestIgnoredObjectsPurgeNow` prüfen): Zustand klären und im Status nennen.

**Prüfung durch den Nutzer:** App normal starten, in der Konsole (`kill -SEGV <pid>` ist tabu für den Nutzer, stattdessen Debug-Menüpunkt „Absturz testen“ nur in Debug, ruft `fatalError`) einen Absturz erzeugen, neu starten: Dialog erscheint, „Bericht kopieren“, Text in eine Nachricht einfügen. Danach „Diagnosebericht kopieren“ aus den Einstellungen.

---



---

# Nachtrag 30.09. (4) — Aufgaben 56, 58, 57 (Teil A) freigegeben

Freigabe Claude 30.09.: Debug-Tests und Release-Build grün. Code stichprobenartig geprüft: `AFTER UPDATE OF name`, Bereichsabfrage `path >= … AND path < …`. Nicht geprüft: Mail.app öffnet den Anhang, Rechte der echten Ordner unter `~/Library` (werden beim nächsten Start nachgezogen).

## 56. Kleine Korrekturen aus dem Review (Claude 30.09.)

**Status:** Umgesetzt. Dialog ist 440 pt breit (340 pt reicht für drei Beschriftungen nicht); Buttons mit `lineLimit(1)` und fester Breite, damit „Protokoll zeigen“ einzeilig bleibt. Hell/Dunkel nicht gegen Sektion 02 verglichen. Bericht liest Medienzahl und aktive Objekte (`removedAt IS NULL`) über `IndexDatabase.inventoryLabels()`; fehlt die Datei oder schlägt die Abfrage fehl, steht „nicht lesbar“. `SIGTERM` schreibt signalsicher `app terminate ok` und löst keinen Absturz-Dialog aus. Test `sigtermWritesACleanEnd` grün.

1. **Absturz-Dialog:** Der Button „Protokoll zeigen“ bricht in zwei Zeilen um ([CrashReportDialog](diskindex/diskindex/Views/Registry)). Dialog breiter machen (etwa 340 pt) oder die Buttons untereinander angeordnet lassen, sodass alle Beschriftungen **einzeilig** bleiben. Hell und Dunkel gegen Sektion 02 vergleichen.
2. **Bericht:** „Medien- und Objektzahl“ stehen als „unbekannt“. Aus dem Speicher füllen (Zahl Medien, Zahl aktiver Objekte), falls der Speicher nicht erreichbar ist „nicht lesbar“.
3. **Beenden per Signal:** Bei `SIGTERM` (Abmelden, `kill`, Neustart des Macs) `app terminate ok` schreiben, damit kein falscher Absturz-Dialog folgt. `applicationWillTerminate` läuft dann nicht immer.

---

## 58. Sicherheit und Leistung (Review Claude 30.09.)

**Status:** Umgesetzt. `FilePrivacy.restrict` setzt den Ordner auf `0700` und die Dateien darin auf `0600`, beim Öffnen der Datenbank und bei jedem Protokoll-Start, auch für schon vorhandene Dateien (`-wal`/`-shm` über denselben Ordner). Tests: `databaseFilesArePrivateToTheUser`, `logDirectoryIsPrivate`. Volltext-Trigger ist `AFTER UPDATE OF name` (Migration `v2-fts-name`). `applyDirectory` schreibt ein volles `UPDATE` nur, wenn sich mehr als `lastSeenAt` ändert; sonst ein Sammel-`UPDATE` in Blöcken zu 400. Zweiter Lauf über 200 000 unveränderte Zeilen lässt `item_fts_data` gleich und ist kürzer als der erste (`secondPassLeavesTheFullTextIndex`). Entfernte Ordner werden mit `path >= Präfix AND path < nächstes Präfix` markiert. Test `specialNamesStayInsideTheirFolder` mit `100%`, `a_b`, `c\d` und der Datei `100%EXTRA`. `InstanceHandoff.shouldQuit` beendet nur bei PID eines laufenden Prozesses derselben Bundle-ID mit späterer Startzeit, sonst Protokollzeile „instance handoff ignoriert“. `showMainWindow` bleibt. Hardened Runtime bleibt an, keine Entitlements, kein Netzwerk. SQLCipher nicht eingebaut. Die echten Ordner unter `~/Library` werden erst beim nächsten Start der App nachgezogen, hier nicht mit `ls` geprüft.


**Befunde und Soll:**
1. **Datenbank und Protokoll sind für andere Benutzer lesbar.** `~/Library/Application Support/Disk Index/` ist `755`, `index.sqlite` (samt `-wal`, `-shm`) und `~/Library/Logs/Disk Index/*` sind `644`. Darin stehen alle Dateinamen der Medien und Suchbegriffe (`ui search query=…`). Auf einem Mac mit mehreren Benutzern kann jeder mitlesen. **Soll:** Ordner `0700`, Dateien `0600` beim Anlegen (`FileManager`-Attribute `posixPermissions`) und bei jedem Start **nachziehen**, auch bei bestehenden Dateien. Für DB-`-wal`/`-shm` gilt es über den Ordner. Test: nach dem Öffnen stimmen die Rechte.
2. **Volltext-Trigger feuert bei jeder Änderung.** `item_fts_update` ist `AFTER UPDATE ON item`. `applyDirectory` schreibt bei **jedem** Nachlesen für **jede** vorhandene Zeile ein `UPDATE` (u. a. `lastSeenAt`), der Trigger löscht und fügt dann jedes Mal den Namen im Volltextindex neu ein, obwohl der Name gleich bleibt. Das vervielfacht die Schreiblast beim Abgleich, beim Anschließen und bei jeder Live-Änderung (die WAL-Datei ist schon jetzt größer als die Datenbank). **Soll:** neue Migration: Trigger als `AFTER UPDATE OF name ON item`, und im `applyDirectory` das `UPDATE` nur ausführen, wenn sich etwas außer `lastSeenAt` geändert hat, `lastSeenAt` der unveränderten Zeilen in **einem** Sammel-`UPDATE … WHERE id IN …` (oder gar nicht je Lauf; dann Lauf-Marke am Medium). Test mit 200 000 Zeilen: zweiter Lauf ohne Änderungen schreibt keine FTS-Zeilen (Zähler über `item_fts`-Änderungen oder Laufzeit deutlich kürzer als der erste).
3. **Löschmarkierung liest große Teilbäume ohne Index.** Beim Entfernen eines Ordners: `path LIKE ? ESCAPE '\'`. SQLite nutzt dafür den Index `item_path` nur mit `NOCASE`-Spalte oder eingeschaltetem `case_sensitive_like`, sonst Volltabellenlauf **je entferntem Ordner**. **Soll:** Bereichsabfrage `path >= ? AND path < ?` (Präfix und Präfix mit letztem Zeichen +1, in Binärreihenfolge) auf `(mediumID, path)`. Test mit Ordnern, deren Namen `%`, `_` und `\` enthalten.
4. **Beenden-Signal der zweiten Instanz kann jeder auslösen.** `quitOlderInstance` läuft über `DistributedNotificationCenter`; jeder lokale Prozess kann sie posten, und die App beendet sich. **Soll:** Nur beenden, wenn `notification.object` eine PID ist, die zu einem laufenden Prozess derselben Bundle-ID gehört und **jünger** ist (Startzeit) als der eigene. Sonst ignorieren und protokollieren. Ebenso `showMainWindowNotification`: nur ein Fenster öffnen, das ist harmlos, bleibt.
5. **Vertrieb:** Für die Weitergabe außerhalb dieses Macs: Signatur mit Developer ID, Notarisierung, `ENABLE_HARDENED_RUNTIME = YES` (ist gesetzt), **keine** Ausnahmen (Entitlements gibt es nicht, das ist richtig). Kein Netzwerkcode, kein Skript-/Prozess-Aufruf, keine Web-Ansicht im Code (geprüft). Das so lassen; 57 bringt als Erstes Netzwerk und wird deshalb gesondert bewertet.
6. **Nicht nötig, bewusst entschieden:** Datenbank-Verschlüsselung (SQLCipher). Schlüsselverwaltung wäre aufwendig und würde Suche verlangsamen, FileVault schützt die Ruhedaten. Wer die Datenbank lesen darf, ist mit 1. geregelt.

**Prüfung:** `ls -laO` auf beide Ordner zeigt 700/600. Zweiter Abgleich desselben Mediums ohne Änderung: sichtbar weniger Schreibaktivität und kürzere Laufzeit (`perf`-Zeile im Protokoll).

---

## 57. Absturzbericht per Mail oder als Ticket senden (Nutzer 30.09.)

**Status:** Teil A umgesetzt. `ReportTarget.mailAddress` ist `mail@xjonx.com`. Absturz-Dialog und Diagnosebericht (Einstellungen, Menüleiste) haben „Per Mail senden“. Vorher sieht man den Text, den Hinweis auf Dateinamen und den Schalter „Namen unkenntlich machen“ (Standard an). Versand über `NSSharingService.composeEmail` mit Anhang `diskindex-bericht-<Datum>.txt`, sonst `mailto:` mit den ersten 1 500 Zeichen, sonst „Kein Mail-Programm gefunden“ und Zwischenablage. Teil B ist nur `TicketLink` mit Kommentar „Ticket später“, ohne Schaltfläche. Tests: Empfänger, Betreff, Anhang, Plan ohne Mail-Programm, `mailto`-Kürze und Escaping, Unkenntlichmachen, Link-Länge. Ob Mail.app den Anhang wirklich öffnet, ist hier nicht geprüft.


**Entscheidung Nutzer 30.09.:** Versand **per Mail** an **mail@xjonx.com** (Konstante `ReportTarget.mailAddress`). Ein Ticketsystem gibt es noch nicht: **Teil B nicht umsetzen**, nur als Hinweis im Code („Ticket später“).

**Grundsatz:** Nie automatisch senden. Der Nutzer sieht vorher den Text und entscheidet. Keine Zugangsdaten, keine Token in der App (ein Token im Programm ist auslesbar). Nichts an Dritte außer an die vom Nutzer angegebene Adresse.

**A. Mail (ohne Server, sofort machbar):** Im Absturz-Dialog (und bei „Diagnosebericht“) neue Schaltfläche **„Per Mail senden“**. Umsetzung mit `NSSharingService(named: .composeEmail)`: Empfänger aus **einer** Konstante (`ReportTarget.mailAddress`), Betreff „Disk Index \(Version) Absturzbericht“, Text = kurzer Hinweis, der Bericht als **Anhang** (`diskindex-bericht-<Datum>.txt` in einem temporären Ordner). `mailto:` nur als Rückfall (Text gekürzt auf die ersten 1 500 Zeichen, weil URLs begrenzt sind und Anhänge fehlen). Ist kein Mail-Programm eingerichtet: Meldung „Kein Mail-Programm gefunden“ und Bericht **in die Zwischenablage**.

**B. Ticket:** Schaltfläche **„Ticket anlegen“**. Zwei Stufen, nur die erste jetzt:
1. **Vorbefüllter Link** (kein Token nötig): öffnet im Browser die „Neues Ticket“-Seite des Systems mit Titel und gekürztem Text (GitHub: `…/issues/new?title=&body=`; Linear/Jira analog), der **volle Bericht liegt zusätzlich in der Zwischenablage**, mit Hinweis „Bericht ist kopiert, im Ticket einfügen“. URL-Längenlimit beachten (Text auf ~6 000 Zeichen kürzen, nur Kopf, CRASH, letzte 10 Aktionen).
2. **Direkter Versand** an eine Erfassungsstelle (z. B. Sentry mit öffentlichem DSN): nur nach Rücksprache, weil das erste Netzwerkzugriffe der App wären (Datenschutz, Nutzer-Einwilligung „Berichte senden“ in den Einstellungen, standardmäßig aus, Text vorher einsehbar).

**Daten im Bericht:** enthält Dateinamen und Pfade (lokal). Vor dem Senden anzeigen: „Der Bericht enthält Namen von Dateien und Ordnern.“ und ein Schalter **„Namen unkenntlich machen“** (ersetzt Namen im Pfad durch `…`, Endungen bleiben), Standard **an**, wenn gesendet wird.

**Tests:** Mailversand baut Empfänger, Betreff, Anhang; ohne Mail-Programm Zwischenablage; Link-Bau kürzt auf Limit, escaped Sonderzeichen; Namen-Unkenntlichmachen ersetzt Namen, lässt Endungen.

---



---

# Nachtrag 01.10. — Aufgabe 49 geschlossen (nicht reproduzierbar)

Entscheidung Nutzer 01.10.: Der Favorit-Absturz ließ sich nicht nachstellen. Die verdächtigen Stellen sind gehärtet (`uniquingKeysWith`, doppelte Medium-IDs, Fehler protokolliert). Falls er wiederkehrt, liefert der Absturzbericht (Aufgabe 55/57) Signal, Stapelspur und letzte Aktionen. Dann neue Aufgabe mit diesem Bericht.

## 49. Absturz beim Markieren als Favorit (Nutzertest 30.09.)

**Status:** Erledigt durch Cursor. Der Absturz ließ sich hier nicht nachstellen (er tritt beim Nutzer nur außerhalb von Xcode auf, ohne DiagnosticReport). Gehärtet ist die Stelle, die bei doppeltem Schlüssel sofort stirbt: `Dictionary(uniqueKeysWithValues:)` in `loadStoredMedia`, `SearchIndex.matching`, `favoriteObjects` und `PopoverSearch` nutzt `uniquingKeysWith`. `loadStoredMedia` verwirft doppelte Medium-IDs. `toggleFavorite` protokolliert fehlende Zeilen und Schreibfehler und läuft weiter. Favoriten-Ergebnisse werden nach ID eindeutig gemacht. Tests: Datei, Ordner und Medium, zwei Medien derselben ID, Favorit an einem entfernten Objekt. Die genaue Absturzzeile des Nutzers steht erst in `diskindex.log` nach dem nächsten Lauf außerhalb von Xcode.

**Befund:** Der Nutzer markiert im Nutzertest (Dunkelmodus, echter Stick) ein Objekt als Favorit, die App stürzt ab. Es gibt keinen Absturzbericht in `~/Library/Logs/DiagnosticReports`, die genaue Zeile ist Claude nicht bekannt. Welches Objekt (Datei, Ordner, Medium) und in welcher Ansicht (Spaltenansicht, Suche, Favoriten) ist offen.

**Soll:**
1. **Reproduzieren und die Absturzzeile nennen** (Debug aus Xcode: Konsole/Breakpoint). Für Datei, Ordner und Medium, jeweils aus Spaltenansicht, Suche und Favoriten, mit und ohne Filter. Ergebnis im Status festhalten.
2. **Ursache beheben, nicht das Symptom.** Verdächtige Stellen, die Claude beim Lesen gefunden hat, alle prüfen und härten:
   - `Dictionary(uniqueKeysWithValues:)` stürzt bei doppeltem Schlüssel ab: [AppState.swift](diskindex/diskindex/App/AppState.swift) (`loadStoredMedia`, zwei Stellen), [SearchIndex.swift](diskindex/diskindex/Models/SearchIndex.swift) `favoriteObjects`, [PopoverSearch.swift](diskindex/diskindex/Models/PopoverSearch.swift). Auf `Dictionary(_, uniquingKeysWith:)` umstellen. Zusätzlich klären, wie ein Medium doppelt in `media` kommen kann (`MediumCoordinator` hängt mit `media.append` an, `reloadMedium` ebenfalls) und das verhindern.
   - Kette beim Favorisieren: `toggleFavorite` → `setFavorite` → `emit(.items)` → `applyIndexChange` (`reloadMedium`, `invalidate`, `reloadFavorites`, Suche neu). Auf Änderung von `media`/Cache während laufender Ansicht (SwiftUI-`ForEach` mit doppelten IDs, Index außerhalb) achten.
   - `IndexedItem.id`/`rowID` deterministisch aus SHA-256: prüfen, dass ein Eintrag im Favoriten-Ergebnis nicht doppelt vorkommt (`ForEach`-IDs eindeutig).
3. **Kein `!`, kein `try!`, kein `fatalError` und keine ungeprüften Indizes** auf diesem Pfad. Fehler werden protokolliert, die App läuft weiter.
4. **Tests:** Favorit an/aus für Datei, Ordner und Medium gegen eine temporäre Datenbank (Speicher, `favoriteObjects`, Cache). Test mit **zwei Medien gleicher ID im Zustand** darf nicht abstürzen. Favorit an einem Objekt, das gleichzeitig durch einen Lauf entfernt wird (`removedAt`).

---


---

# Nachtrag 01.10. (2) — Aufgaben 60, 61, 59 freigegeben

Freigabe Claude 01.10.: 60 und 61 vom Nutzer erfolgreich getestet (Dock-Größe 1,00 gemessen, Klick öffnet Fenster, Bericht kommt am Server an). 59: Debug-Tests und Release-Build grün; Messung bei Cursor, ein Host, Attrappe ohne Plattenzugriff: Erstlauf Tiefe 5 von 74 s auf 12,5 s (~40 000 Einträge/s, Ziel 50 000 knapp verfehlt), unveränderter Abgleich 3,2 s (26 % des Erstlaufs), Spalte mit 500 000 Zeilen Laden von 51 s auf 3,14 s (Ziel 3 s knapp verfehlt), RAM danach 418 MB (Ziel 400 MB knapp überschritten, Zeilen bleiben im Zwischenspeicher), Leerlauf 0,2 % CPU, 20 Zyklen kein Wachstum. Entscheidung: keine weitere Runde, die Restabweichung liegt unter 5 %.

## 60. Start- und Dock-Verhalten, Dock-Icon zu groß (Nutzer 01.10., Messung Claude)

**Review Claude 01.10.:** Code gelesen, `LSUIElement` ist `NO`, Launch-Agent übergibt `--background`, Tests und Release-Build grün. **Offen bleibt die Messung im Dock**: Verhältnis zum Nachbar-Icon ist nicht gemessen (Dock war verdeckt). Das prüft der Nutzer (Punkte a bis e unten). Falls das Symbol weiterhin zu groß ist: Variante C aus Punkt 5, mit Messwerten des Nutzers. Ob beim Anmelden ein Dock-Symbol aufblitzt, beurteilt der Nutzer.

**Status (Cursor):** Umgesetzt. `applyRuntimeDockIcon` und `applicationIconImage` sind weg, ebenso die Beobachter bei Aktivieren und Deaktivieren. `LSUIElement` ist `NO`. `AppLaunch` erkennt Anmeldung an `--background` oder `XPC_SERVICE_NAME == xjonx.diskindex.launcher` und setzt dann sofort `.accessory`, ohne Fenster. Jeder andere Start bleibt `.regular` und öffnet das Hauptfenster. Die Release-Übergabe protokolliert `app launch kind=handoff` und die laufende Instanz öffnet das Fenster über `showMainWindowNotification`. Schließen des Fensters setzt weiter `.accessory`. Der Launch-Agent übergibt `--background`. Tests: Anmeldung, Klick, Reopen, Übergabe öffnet das Fenster. Auf Wunsch neu gezeichnet: Kachel 824/1024, Rand 100, Radius 185,4, ohne eigenen Schatten (`GenerateAppIcons.swift`, AppIcon und DockIcon). Dock beendet, Icon-Cache geleert, Debug-App neu gestartet. Messung 01.10. am Dock-Fenster (5120×2880): Disk Index deckend 68×87 px, Nachbarn (Wellenform, Haus) ebenfalls 68×87 px, Verhältnis 1,00. Die zuvor größeren Kacheln (Elefant 86, WoW 80) sind andere Apps. Ob beim Anmelden kurz ein Dock-Symbol aufblitzt, ist nicht geprüft.


### Konzept (Entscheidung Nutzer 01.10.)
Der Nutzer legt die App **fest ins Dock**, um sie zu starten. Es gibt zwei Rollen derselben App:
- **Hintergrundprozess:** läuft immer (Menüleiste, Überwachung der Medien), **ohne aktives Dock-Symbol und ohne Fenster**.
- **Hauptfenster:** öffnet **bei jedem Klick auf die App** (Dock, Programme, Finder). **Der Klick startet auch den Hintergrundprozess, wenn er noch nicht läuft.**

**Verhalten (Soll):**
1. **Klick auf die App, App läuft nicht:** startet **und öffnet das Hauptfenster**. Dock zeigt die App als laufend (Punkt), Symbol wie Nachbar-Apps.
2. **Klick auf die App, läuft schon im Hintergrund:** Hauptfenster öffnet (`applicationShouldHandleReopen`, auch wenn kein Fenster sichtbar ist). Die Einzelinstanz-Regel (neuer Prozess übergibt an den laufenden und beendet sich) bleibt, **die Übergabe öffnet das Hauptfenster** (`showMainWindowNotification`).
3. **Start beim Anmelden** (Login-Item/Launch-Agent, Aufgabe 36 bzw. `LaunchAtLogin`): **still**, **kein** Fenster, nur Menüleisten-Symbol, Dock-Symbol nicht aktiv. Erkennen: Der Agent startet die App mit Argument `--background` (in `LaunchAgent/xjonx.diskindex.plist` unter `ProgramArguments`) oder über `XPC_SERVICE_NAME == xjonx.diskindex.launcher`. Alles andere ist ein Klick (Fall 1).
4. **Hauptfenster schließen:** App fällt zurück in den Hintergrund (Fall 3), das **angeheftete** Dock-Symbol bleibt als Starter, **ohne Laufpunkt**. Das ist das Verhalten der Aufgabe 17.
5. **Menüleisten-Symbol:** unverändert (Popover, Kontextmenü, „Hauptfenster öffnen“).

### Dock-Symbol zu groß (Befund Claude, Screenshot des Nutzers)
Gemessen am Screenshot (Dock mit Wispr Flow links, Disk Index rechts): Kachel Wispr **70 px**, Disk Index **86 px**, Verhältnis **1,23 = 1 / 0,81**. Unsere Kachel füllt im Dock den ganzen Platz, die Nachbarn lassen ihren Rand. **Die Dateien sind gleich:** Kachelbreite in `AppIcon.icns` 80,5 %, bei Wispr 81,2 %; unser Symbol 60 % gegen 62 %. Ursache: Das Dock zeichnet das Bild, das wir zur Laufzeit mit `NSApp.applicationIconImage = NSImage(named: "DockIcon")` setzen, **ohne** den Rand des Bundle-Icons. Aufgabe 52 hat nur mehr Zustände auf dasselbe Laufzeitbild gelegt und das Problem nicht gelöst.

**Folgerung aus dem Konzept:** Das **angeheftete Symbol im Dock ist das Bundle-Icon** (`AppIcon`). Es soll auch laufend **dasselbe** sein. Ein Laufzeitbild darf es nicht ersetzen.

### Soll (Umsetzung)
1. **Laufzeitbild entfernen:** `applyRuntimeDockIcon`, `applicationIconImage` und die Beobachter (`didBecomeActive`/`didResignActive`) aus Aufgabe 52 **ganz entfernen**. Das Dock nimmt das Bundle-Icon.
2. **Leere Kachel (Grund von 23.1) anders lösen, ohne Laufzeitbild:** `LSUIElement` auf **NO** setzen (normale App, Bundle-Icon vom Start an), und die App wechselt **sofort beim Start** (`applicationWillFinishLaunching`) bei **Anmelde-Start** (Fall 3) auf `.accessory`, bei **Klick-Start** (Fall 1) bleibt sie `.regular`. Schließen des Hauptfensters: `.accessory` (Fall 4), Öffnen: `.regular`. Prüfen, dass das Dock **kein leeres Symbol** und **keinen zweiten Eintrag** zeigt, auch nach mehrfachem Öffnen/Schließen. Falls es mit `LSUIElement = NO` ein kurzes Aufblitzen beim Anmelde-Start gibt, im Status benennen (Wirkung beurteilt der Nutzer).
3. **Fall 1 bis 4 umsetzen** wie oben (Start-Art erkennen, Hauptfenster bei Klick-Start öffnen, Übergabe öffnet Fenster, Anmelde-Start still). Aktionsspur/Protokoll: `app launch kind=click|login|handoff`.
4. **Messskript** (Debug, `Werkzeuge/`): Bildschirmfoto des Docks, findet die Kachel der App und eines Nachbarn, gibt Kachelbreiten und Verhältnis aus. **Zielwert 1,00 ± 0,03** zu einem Nachbar mit Apple-Raster. Das Dock muss sichtbar sein (keine Vollbild-App davor). Gemessen in: angeheftet und App aus; laufend mit Fenster aktiv; Fenster inaktiv (andere App vorn); Fenster geschlossen (Hintergrund); Debug **und** Release.
5. **Falls Verhältnis nach 1. und 2. nicht 1,00 ist:** Ursache im Status nennen, dann **Variante C**: Bundle-Icon-Satz um den fehlenden Rand ergänzen (nur wenn gemessen; **Kachel- und Symbolgröße der Dateien bleiben**).
6. **Nicht ändern:** Bilddateien `AppIcon`/`DockIcon.png` und die Optik des Symbols (vom Nutzer freigegeben).

**Tests:** Start-Art-Erkennung (Argument `--background`, `XPC_SERVICE_NAME`) mit Attrappe; Reopen-Handler öffnet das Fenster ohne sichtbares Fenster; Übergabe öffnet das Fenster; Anmelde-Start öffnet **kein** Fenster.

**Prüfung durch den Nutzer:** App im Dock angeheftet. (a) App aus, Klick: Fenster öffnet. (b) Fenster schließen: Dock-Symbol bleibt als Starter, kein Laufpunkt, Menüleisten-Symbol bleibt. (c) Klick im Dock: Fenster öffnet wieder. (d) Mac neu anmelden: App startet still, kein Fenster. (e) Symbol im Dock gleich groß wie Nachbarn.

---

## 61. Berichte an den Issue-Tracker senden (Nutzer 01.10.)

**Review Claude 01.10.: eine Korrektur.** `ReportTarget.endpoint` muss **`http://localhost:8888/issue-tracker/api/`** sein (mit `/api/`). Unter `/issue-tracker/` antwortet der Server mit **200 und einer HTML-Seite**, nicht mit `{"ok":true}`; die App würde das als nicht gesendet werten und endlos wiederholen. Konstante und Tests anpassen. **Zusätzlich:** Antwortet der Server mit 2xx, aber der Body ist **kein** `{"ok":true}` (z. B. HTML), dann gilt das wie ein Serverfehler (bleibt im Ausgang, Abstand wächst) und wird protokolliert (`app report failed status=200 body=nicht-ok`). Test dafür ergänzen. Alles Übrige freigegeben (Build und Tests grün).

**Status (Cursor):** Umgesetzt. `ReportTarget.endpoint` ist `http://localhost:8888/issue-tracker/api/`. Antwort 2xx ohne `{"ok":true}` bleibt im Ausgang, der Abstand wächst, Protokoll `app report failed status=200 body=nicht-ok` (Test `successWithoutOKBodyStaysAndBacksOff`). Debug-Tests und Release-Build ohne Warnung. Absturz-Dialog wie das Erkennungsmodal: Warn-Icon, Checkbox „Namen unkenntlich machen“, links Schließen, rechts Bericht anzeigen und Bericht senden. Senden legt `kind: crash` mit dem Zustand der Checkbox in die Outbox, nicht automatisch beim Öffnen. „An Tracker senden“ bleibt in den Einstellungen und im Menü (`kind: diagnostic`). Fehler aus `store`, `index`, `watcher` und `medium` werden je Signatur höchstens einmal pro Stunde und höchstens zehnmal am Tag gesendet, mit den letzten 20 Aktionen. JSON hat genau die Vertragsfelder, `createdAt` in UTC mit `Z`, UUIDs in Großbuchstaben. Namen sind standardmäßig unkenntlich (Schalter in den Einstellungen). Outbox unter Application Support, Dateien `0600`, höchstens 50 Dateien oder 5 MB. Erfolg nur bei HTTP 200 und `{"ok":true}`. 5xx, 408, 429 und kein Netz bleiben mit Abstand 1, 2, 4 … 24 Stunden. Andere 4xx werden verworfen. Release lehnt `http` ab, Debug erlaubt `http://localhost`. Schalter „Berichte an den Issue-Tracker senden“ ist bei localhost standardmäßig an, sonst aus; der Absturz-Dialog fragt dann nach. Aus speichert nur. Tests a–j grün. Ob der PHP-Endpunkt die Datei annimmt, ist hier nicht geprüft.


**Entscheidung Nutzer:** Alle Probleme aus dem Programm gehen per HTTP-POST an den Endpunkt **`http://localhost:8888/issue-tracker/api/`** (wird gerade entwickelt, ein PHP-Skript speichert das JSON). Einfach einbauen, die Gegenseite folgt. Mail (57) bleibt als zweiter Weg.

**Endpunkt:** `ReportTarget.endpoint` (eine Konstante, später änderbar). Von Claude am 01.10. mit einem Test-POST geprüft: Antwort `200` und `{"ok":true}`. `http://localhost` ist für ATS erlaubt (unqualifizierter Host). **Release-Builds akzeptieren nur `https`** (Debug darf `http://localhost`): Prüfung beim Senden, sonst Protokollzeile und nicht senden.

**Was gesendet wird („alle Issues“):**
1. **Absturzberichte** (`kind: "crash"`): nach einem abnormalen Ende automatisch **beim nächsten Start** (im Hintergrund, nicht blockierend), zusätzlich bleibt der Absturz-Dialog aus 55 (Mail, Kopieren).
2. **Diagnoseberichte** (`kind: "diagnostic"`): Schaltfläche **„An Tracker senden“** neben „Per Mail senden“ (Absturz-Dialog, Einstellungen → Allgemein, Menüleisten-Kontextmenü).
3. **Fehler ohne Absturz** (`kind: "error"`): jede Protokollzeile der Stufe `error` aus `store`, `index`, `watcher`, `medium` (also die, die 53/55 jetzt schreiben). **Gedrosselt:** je Signatur (Kategorie + Meldung ohne Pfade/Zahlen) höchstens einmal je Stunde, insgesamt höchstens 10 je Tag. Jede Meldung mit den letzten 20 Aktionen.

**Nutzlast (JSON, UTF-8, `Content-Type: application/json`):**
```json
{
  "schema": 1,
  "id": "<UUID je Bericht>",
  "kind": "crash | diagnostic | error",
  "createdAt": "2026-10-01T14:23:10Z",
  "install": "<zufällige Installations-ID, einmal erzeugt, in UserDefaults>",
  "app": { "version": "1.0", "build": "1", "config": "Release|Debug" },
  "system": { "macOS": "15.7.4", "model": "Mac14,2" },
  "runtimeSeconds": 8123,
  "signature": "store/applyDirectories …",
  "crash": { "signal": "SIGSEGV", "stack": ["…"] },
  "actions": ["… letzte 50 …"],
  "logTail": ["… letzte 100 …"],
  "inventory": { "media": 3, "items": 1204331, "dbBytes": 111000000 },
  "namesRedacted": true
}
```
`crash` nur bei `kind: crash`. Feld `install` ist anonym (kein Gerätename, keine Seriennummer, kein Benutzername). Pfade und Dateinamen: **`namesRedacted` standardmäßig true** (Namen im Pfad durch `…` ersetzt, Endungen bleiben, wie in 57). Schalter in den Einstellungen („Dateinamen in Berichten unkenntlich machen“, Standard an).

**Ablauf und Fehlerfälle:**
- **Ausgang** (Outbox): jeder Bericht wird zuerst als Datei in `~/Library/Application Support/Disk Index/outbox/<id>.json` gelegt (Rechte `0600`, höchstens 50 Dateien/5 MB, älteste fliegen), dann gesendet. Erfolg (HTTP 2xx und Antwort `{"ok":true}`) löscht die Datei. Kein Netz, Zeitüberschreitung (10 s), Serverfehler (5xx): Datei bleibt, **nächster Versuch** beim nächsten Start und danach stündlich, mit wachsendem Abstand (1, 2, 4 … bis 24 Stunden). Antwort 4xx: Datei verwerfen und protokollieren (ein falscher Bericht wird nicht ewig wiederholt), Ausnahme 408/429 wie 5xx.
- **Nie blockieren:** Senden läuft im Hintergrund (`URLSession`, eigene Aufgabe), niemals im Absturzpfad (dort wird nur die Datei geschrieben, gesendet wird beim Neustart).
- **Einwilligung:** Einstellungen → Allgemein, Schalter **„Berichte an den Issue-Tracker senden“**. Solange der Endpunkt `localhost` ist (Entwicklung), **Standard an**. Für jeden anderen Endpunkt ist er **Standard aus** und muss beim ersten Absturz im Dialog ausdrücklich bestätigt werden (Dialog sagt: „Der Bericht enthält Version, System und die letzten Aktionen. Dateinamen sind unkenntlich gemacht.“). Aus bedeutet: nichts wird gesendet, nur gespeichert.
- **Protokoll:** `app report queued/sent/failed kind=… id=… status=…` (ohne Inhalt).

**Tests (mit `URLProtocol`-Attrappe, ohne echtes Netz):** (a) Absturzbericht wird gebaut und gesendet, Outbox danach leer. (b) Server 500: Datei bleibt, Wiederholung mit wachsendem Abstand. (c) 400: Datei verworfen. (d) Kein Netz: bleibt. (e) Release lehnt `http://` ab, Debug erlaubt `http://localhost`. (f) Drosselung: gleiche Signatur zweimal in einer Stunde ergibt eine Sendung, elfter Bericht am Tag wird nicht gesendet. (g) Namen unkenntlich, wenn Schalter an, Pfade enthalten keine Dateinamen. (h) Schalter aus: nichts gesendet. (i) Nutzlast enthält alle Pflichtfelder und gültiges JSON (Schema 1). (j) Outbox-Rechte 0600 und Obergrenze.

**Vertrag (verbindlich, Nutzer 01.10.):** Die Struktur oben ist **genau so** an die Gegenseite weitergegeben, keine Felder umbenennen, keine hinzufügen. Der Server antwortet bei Erfolg mit **HTTP 200** und Body `{"ok":true}`; nur das gilt als gesendet. Bei `kind: error` steht der Fehlertext in `signature` und in der letzten Zeile von `logTail` (es gibt kein eigenes Feld `message`). Listen: `actions` höchstens 50 (bei `error` 20), `logTail` höchstens 100, jede Zeile höchstens 500 Zeichen, gesamter Body höchstens 256 KB (sonst `logTail` kürzen, dann `actions`). Zeitstempel `createdAt` UTC mit `Z`. `id` und `install` als UUID in Großbuchstaben mit Bindestrichen.

**Prüfung durch den Nutzer:** Die Gegenseite (PHP) läuft auf `localhost:8888`. In der App einen Diagnosebericht senden: Datei erscheint beim Server mit allen Feldern. Absturz auslösen (Debug-Menü „Absturz testen“), neu starten: Bericht kommt an, Ausgang leer.

---

## 59. Langzeitbetrieb: Leistung bei großen Platten (zurück von Claude)

**Status:** Profil mit `sample` (1 ms, 01.10., ein Test-Host). Fenster „Spalte laden“ (4278 Abtastungen, alles in `loadChildren`): (1) `IndexSQL.items` 67 %, (2) `Row`-Zugriff über den Spaltennamen 66 %, (3) `Row.index(forColumn:)` lineare Namenssuche, (4) `IndexStore.children` inklusive 100 %, (5) `DatabasePool.read`. Fenster „Tiefe 5, ohne Änderung“ lag beim ersten Profil noch im Schreiben (`IndexSQL.applyDirectory`, Blatt `sqlite3_step`); nach der Änderung ist dieser Lauf der Stempelvergleich. Umgesetzt: Zeilen positionsweise lesen; `IndexedItem.stableID` aus Medium-UUID und `rowID` ohne SHA (Test `stableRowIDIsDeterministicAndUnique`); Inhaltsstempel `contentStamp`/`rootContentStamp` (Migration v3), bei Entfernen gelöscht, unveränderter Ordner überspringt das Lesen der Kinder; `lastSeenAt` nur bei echter Änderung; Anweisungen je Stapel einmal vorbereitet; Favorit aus `IndexedItem.isFavorite`; Meldungen höchstens alle 750 ms, Zwischenspeicher nur für den sichtbaren Ordner, höchstens 30 Ordner, erste 2000 Zeilen sofort; Fortschritt höchstens alle 150 ms, Proben auf 1000 begrenzt; Überwachung spätestens nach 30 s; `stop()` setzt `.pending`. Voller Lauf beim Anschließen unverändert. `parallelDirectoryReads` bleibt 1. Messung 01.10., ein Host, `/tmp/diskindex-scale.txt`: Tiefe 5 (12 Ordner × 10 Dateien, etwa 498 000 Einträge) Erstlauf 12,47 s / 12,60 s CPU, etwa 40 000 Einträge/s (Ziel 50 000 nicht erreicht; eine Spalte mit 500 000 Zeilen speichert in 11,0 s, das ist die Grenze des zeilenweisen Einfügens); unverändert 3,19 s = 26 % des Erstlaufs (Ziel unter 30 % erreicht); 1 % geändert 3,41 s. Spalte 500 000 laden 3,14 s (Lauf davor 3,00 s; Ziel unter 3 s knapp verfehlt). Baum mit 299 592 Ordnern (8×2, Tiefe 6, etwa 374 000 Einträge) 11,95 s / 12,47 s CPU, etwa 31 000 Einträge/s, RAM danach 124 MB. Leerlauf 5 Medien, 60 s: CPU 0,13 s (0,2 %), RAM 125 → 88 MB. 20 kleine Zyklen: RAM 97,1 → 97,4 MB (unter 1 %). Parallelität 1/4/8 auf der Attrappe (kein Plattenzugriff): 1,02 / 0,99 / 0,99 s, kein Gewinn, Voreinstellung bleibt 1. RAM der 500 000er-Spalte danach 418 MB (Zielspitze 400 MB überschritten, die Zeilen bleiben im Zwischenspeicher). Suche `datei-1` mit leerer Medienliste: 0 Treffer. Debug-Tests und Release-Build ohne Warnung.

**Schon vorhanden (Cursor, abgenommen):** `ScaleMeasurementTests` (läuft nur, wenn `/tmp/diskindex-scale.on` existiert), Attrappe `SyntheticMediumAccess`, Messung von Dauer, CPU (`getrusage`), RAM (`task_info`), WAL. Bisherige Werte (Baum 12 Ordner × 10 Dateien je Ordner):

| Lauf | Dauer | CPU | RAM danach |
| --- | --- | --- | --- |
| Tiefe 5, erster Lauf (~22 600 Ordner gelesen, ~500 000 Einträge) | **74,3 s** | **70,4 s** | 87 MB |
| Tiefe 5, ohne Änderung | **72,1 s** | 62,3 s | 58 MB |
| Tiefe 5, 1 % geändert | 68,8 s | 61,5 s | 60 MB |
| Eine Spalte mit 500 000 Dateien | **Speichern 78 s, Laden 51 s** | — | 173 → 259 MB |

**Befund:** RAM ist unkritisch. **Prozessor und Dauer sind das Problem:** ~3,3 ms je Ordner, ~6 700 Einträge/s, **bei einer Attrappe ohne Plattenzugriff**. Echte Platte mit 3 Mio. Einträgen: über 7 Minuten reine CPU. Der unveränderte Lauf ist fast so lang wie der erste (trotz 58), die Zeit liegt also **nicht** im Schreiben der Zeilen. Laden einer Spalte: ~100 µs je Zeile.

**Soll (in dieser Reihenfolge):**
1. **Profilieren, nicht raten.** Lauf „Tiefe 5, ohne Änderung“ und „Spalte mit 500 000 Dateien laden“ mit **Instruments (Time Profiler)** oder `sample` aufnehmen. Die **fünf teuersten Funktionen mit Anteil** in den Status schreiben. Zu prüfende Verdachtsstellen: (a) je Ordner `SELECT MAX(id)`, Abfrage `WHERE mediumID=? AND parentID IS ?` und `parentContext` (je ein Zugriff über den Actor), (b) je Ordner `await onProgress`/`note`, (c) `parentsFor` mit `store.folders(depth:)` zweimal je Ebene und alle Ordner einer Ebene auf einmal im Speicher, (d) `applyDirectory` je Ordner eigene Transaktion statt je Stapel, (e) **SHA-256** je Zeile in `IndexedItem` (`id`, `rowID`, [IndexedItem.swift:34](diskindex/diskindex/Models/IndexedItem.swift)) plus Umwandlung `StoredItem → IndexedItem`, (f) Actor-Wechsel je Ordner.
2. **Beheben, was das Profil zeigt.** Ziele: Erstlauf **mindestens 50 000 Einträge/s**; unveränderter Abgleich in **unter 30 %** der Dauer des Erstlaufs; Spalte mit 500 000 Zeilen **Laden unter 3 s**. `IndexedItem.id` ohne SHA (z. B. UUID aus Medium-UUID und `rowID` per fester Bitaufteilung, deterministisch, eindeutig; Test auf Stabilität und Eindeutigkeit).
3. **Ohne Messung nachziehen (klein, sicher):**
   - `IndexRepository.cachedItem` ist linear über den ganzen Zwischenspeicher und wird von `isFavorite(target)` **je Zeile beim Zeichnen** gerufen. Favoritenstatus aus dem Zeilenwert (`IndexedItem.isFavorite`) lesen.
   - Änderungsmeldungen **bündeln** (höchstens alle 750 ms je Medium): bisher löst jeder Stapel (5 000 Einträge) `reloadMedium`, Verwerfen des Zwischenspeichers, `reloadFavorites`, Suche und Popover-Suche aus. Zwischenspeicher nur verwerfen, wenn der **sichtbare** Ordner betroffen ist. Der Strom hat `bufferingNewest(200)`: nach einem Rückstau einmal alles neu laden.
   - Zwischenspeicher der Spaltenansicht begrenzen (z. B. 30 Ordner oder 50 MB, LRU); sehr große Ordner als Ausschnitt laden und die Liste verzögert aufbauen.
   - `DirectoryIndexer.samples` in Produktion nicht sammeln (oder bei 1 000 Einträgen ausdünnen).
   - **Live-Überwachung:** Ruhezeit (2 s) beginnt bei jedem Ereignis neu; bei ständiger Schreibaktivität wird nie nachgelesen. **Höchstwartezeit 30 s** ergänzen.
   - `stop()` in `DirectoryIndexer` hat `… ? .pending : .pending` (beide Zweige gleich): aufräumen.
4. **Messung wiederholen** mit größerem Baum (**300 000 Ordner**), Leerlauf (**5 Medien, 60 s, CPU-Zeit und RAM**) und **20 Zyklen**. Tabelle in den Status. Grenzen: Leerlauf unter 150 MB RAM und unter 1 % CPU; Spitze beim Erstlauf unter 400 MB; kein Wachstum über 10 % nach 20 Zyklen.
5. **Nicht ändern:** das Verhalten „voller Lauf bei jedem Anschließen“. Claude legt die Entscheidung (FSEvents nachspielen oder nicht) dem Nutzer vor, wenn die Zahlen nach 2. stehen. Parallelität (`parallelDirectoryReads` 1/4/8) in der Messung vergleichen und das Ergebnis berichten (HDD 1, SSD/Stick 4 als Vorschlag).

---



---

# Nachtrag 02.10. — Aufgaben 73, 74, 62 freigegeben

Freigabe Claude 02.10.: **73** Farben vom Nutzer bestätigt („die Farben passen jetzt“), Screenshot zeigt neutrale Toolbar und Auswahl. **74** Debug-Tests und Release-Build grün, Bereinigung mit Tests (a)–(k); optisch noch nicht am Bildschirm. **62** Das **dunkle Icon** ist das App-Icon (Nutzerentscheidung 02.10.); Katalog und `DockIcon.png` sind byteidentisch mit `Werkzeuge/icon-kandidat/` (SHA-256 `d04d1432…`). Das helle Icon bleibt als Archiv in `Werkzeuge/icon-kandidat-hell/`, kein Wechsel nach Erscheinungsbild.

## 73. Dunkelmodus: Farbabweichungen (Nutzer 01.10., Messung Claude am Screenshot der Spaltenansicht)

**Status:** Titelleiste transparent, Fensterfläche `DesignColor.windowChrome` (text 6 % über bg), Toolbar `DesignColor.toolbar`, Fenstertitel text bei 60 %. `DesignDivider` statt `Divider()` in den Einstellungen. Seitenleiste: Deckkraft 0,4 nur auf nicht ausgewählte Offline-Zeilen, Auswahl bleibt `#4A4949` mit weißer Schrift. Spalten- und Seitenleistenlinien nutzen `DesignColor.divider`. Test `DarkChromeTests`. Dashboard-Karten ohne Auswahl behalten ihre eigene Deckkraft.

Der Nutzer meldet, im Dunkelmodus passten die Farben nicht. Claude hat den Screenshot **Pixel für Pixel** gegen den Dark-Block von Layout 07 (Spaltenansicht) gemessen. **In Ordnung** (Abweichung unter 5 %): Spaltenfläche `#1F1F1F`, Seitenleiste `#2B2B2B`, Offline-Banner `#292929`, Fußleiste `#292929`, Spaltenkopf (~45 %), Textfarben der Zeilen. **Abweichungen (bitte alle beheben, Messwerte als Ausgangspunkt):**

| Stelle | Ist (gemessen) | Soll (Layout, Dunkel) | Ursache (Vermutung) |
|---|---|---|---|
| **Titelleiste und Toolbar** | `#3D3938` / `#3B3736` (warm, braun-grau) | **neutral `#2B2B2B`** = `bg` `#1F1F1F` + `text` 6 % (`color-mix(text 6 %, bg)`); Trennlinie darunter `divider` | Systemmaterial der Titelleiste/Toolbar (Vibrancy, Hintergrundbild schimmert durch) statt `DesignColor` |
| **Trennlinien** | `#4C4A48` (warm) | **neutral**: `text` 18 % (`#EAE9E9`, 18 %), ≈ `#444444` auf `#1F1F1F` | System-`Divider()`/`separatorColor` statt `DesignColor.divider` (u. a. `SettingsGeneralTab`, `SettingsIgnoredObjectsTab`) |
| **Seitenleiste, ausgewähltes Medium** (Zeile „NO NAME“) | Hintergrund `#3B3B3B`, Text `#AFAFAF` | **Auswahl `#4A4949`**, Schrift **weiß `#FFFFFF`**, fett (600) | [ColumnBrowserView.swift:156](diskindex/diskindex/Views/ColumnBrowser/ColumnBrowserView.swift): `.opacity(connectionStatus == .offline ? 0.55 : 1)` dimmt die **ganze Zeile inklusive Auswahl** |
| **Seitenleiste, nicht ausgewähltes Offline-Medium** („ZOOM_H4E“) | Text `#9C9C9C` (≈ 0,6) | **Deckkraft 0,4** der Zeile (Layout: `opacity:.4`) | gleiche Zeile: 0,55 statt 0,4 |

**Soll:**
1. **Titelleiste und Toolbar** deterministisch einfärben: Titelleiste **transparent** (`titlebarAppearsTransparent`) bzw. gleiche Fläche wie die Toolbar, **kein** Material/Vibrancy (kein `NSVisualEffectView`, kein `.regularMaterial`, kein `toolbarBackground` mit Systemfarbe); Fensterfläche `DesignColor.bg`, Toolbarfläche `DesignColor.toolbar` (neuer Token: `text` 6 % über `bg`, in Hell entsprechend). Der Fenstertitel „Disk Index“ bleibt; wirkt seine Systemfarbe im Dunkeln warm, `DesignColor.text` mit 60 % setzen.
2. **Alle `Divider()`/System-Trennlinien** in Views und Fenstern durch `DesignColor.divider` ersetzen (App-weit prüfen: `grep -rn "Divider()\|separator"`). Die Linie ist **neutral**, nie warm.
3. **Auswahlzeile** (Seitenleiste, Spalten, Tabellen): Hintergrund `DesignColor.selection` (`#4A4949` dunkel), Schrift und Icons `#FFFFFF`, **nie** abgeblendet. **Deckkraft nur auf nicht ausgewählte Offline-Zeilen, 0,4.**
4. **Prüfen:** Alle anderen Stellen, an denen `.opacity(…)` auf eine ganze Zeile oder Karte gelegt wird, ob eine Auswahl mit abgedunkelt wird.
5. **Hell prüfen:** Der Hellmodus darf dadurch nicht abweichen (Titelleiste/Toolbar dort ebenfalls aus `DesignColor`, kein Systemmaterial).
6. **Test:** Unit-Test der Token (`toolbar`, `divider`, `selection` in Dunkel/Hell) und ein Rendertest (`NSHostingView` → Bitmap, Pixel an fester Stelle: Auswahlzeile `#4A4949`, Toolbar `#2B2B2B`, Trennlinie neutral, Rot/Grün/Blau um höchstens 2 auseinander). Aufgabe 71 nimmt diese Stellen als Prüfpunkte auf.

**Prüfung durch den Nutzer:** Mac auf Dunkel, Spaltenansicht mit einem Offline-Medium ausgewählt: Toolbar und Titelleiste neutral dunkelgrau (nicht bräunlich), Auswahl hellgrau mit weißer Schrift, übrige Offline-Medien gedimmt.

---

## 74. Index entspricht den Einstellungen: Anzeige sofort, Löschen nach 1 Stunde, „Index jetzt bereinigen“ (KONZEPT.md Abschnitt 4)

**Status:** Anzeige filtert sofort über `IndexScope` (Tiefe, Unsichtbare, Artefakte, Ausschlüsse) in `children`, Suche, Favoriten und Zählern. `pruneAt` liegt in den UserDefaults, jede weitere Verkleinerung startet die Stunde neu, Erweitern hebt sie nicht auf. Beim Start prüft der bestehende Zeitgeber alle 30 s, beim Aufwachen sofort. Löschen ist endgültig, in Blöcken, fortsetzbar; danach Stempel an der Tiefengrenze, `completedDepth`, Zähler, `incremental_vacuum` und Checkpoint. Knopf in Erweitert heißt „Index jetzt bereinigen“ (schwarz, ein Knopf). Der Knopf unter den Ausschlüssen und das gelbe Prohibit-Icon sind weg. Neue Datenbanken: `auto_vacuum = INCREMENTAL`; bestehende einmal per `VACUUM` vor dem Öffnen. Tests (a)–(k) in `IndexPruneTests`. Debug-Tests grün, Release-Build ohne Compiler-Warnung.

**Anlass:** Verringert der Nutzer die Scan-Tiefe und stellt sie wieder hoch, erscheinen die tieferen Ebenen sofort wieder, weil sie nie gelöscht wurden. Dasselbe gilt für Artefakte, Unsichtbare und eigene Ausschlüsse. **Ein gemeinsamer Mechanismus** (Maßgeblich: [KONZEPT.md](KONZEPT.md), Abschnitt 4, „Index entspricht den Einstellungen“; Layout 05, Tab „Erweitert“, Abschnitt „SCAN-TIEFE UND AUSGESCHLOSSENE DATEIEN & ORDNER“, Knopf **„Index jetzt bereinigen“**).

1. **Auslöser (Verkleinern):** Scan-Tiefe verringert; „Unsichtbare Dateien ignorieren“ an; „Artefakte ignorieren“ an; eigener Ausschluss hinzugefügt. Jede dieser Änderungen **setzt den Bereinigungstermin `pruneAt = jetzt + 1 Stunde`** (**jede weitere Verringerung startet die Stunde neu**). Ein Termin je Installation (nicht je Medium), in `UserDefaults` oder Datenbank, **überlebt Neustart und Ruhezustand**. Beim Start und beim Aufwachen: ist `pruneAt` überfällig, sofort bereinigen. Zeitgeber setzen.
2. **Anzeige sofort:** Betroffene Einträge sind **sofort nicht mehr sichtbar**: Spaltenansicht, Suche, Favoriten, Zähler (Spaltenkopf, Fußleiste, Dashboard-Dateizahl). Bei der Tiefe: Ordner jenseits der neuen Tiefe zeigen „Inhalt nicht erfasst“ (gelb, wie bisher). Filter über `depth <= maxDepth` und über die Regel (Name/Endung/Artefakt/Unsichtbar) in **jeder** Abfrage (`children`, `search`, `favorites`, `counts`).
3. **[bestätigt 02.10.]** Das bisherige Verhalten aus Aufgabe 65 für **Ausschlüsse** („noch 1 Stunde sichtbar mit gelbem Prohibit-Icon“, `exclusionAddedAt`) **entfällt**: Auch Ausschlüsse werden **sofort ausgeblendet** (Layout 05 „Erweitert“: „verschwinden sofort aus der Ansicht“). Das gelbe Prohibit-Icon an Objekten entfällt; das Häkchen im Kontextmenü (rot) bleibt, **solange der Ausschluss besteht**.
4. **Löschen nach 1 Stunde:** Bei `pruneAt ≤ jetzt` werden alle Einträge **endgültig gelöscht** (nicht als entfernt markiert), die **nicht mehr zu den Einstellungen passen**: `depth > Scan-Tiefe` (bei 5+ nichts), Namen aus Ausschlüssen, Artefaktregeln (wenn an), Punkt-Namen (wenn „Unsichtbare“ an), samt Unterbaum. **Favoriten werden ohne Warnung mit gelöscht.** Gilt für **alle** Medien in der Datenbank, **auch nicht angeschlossene**.
5. **„Index jetzt bereinigen“** (Einstellungen → Erweitert; heißt bisher „Aus dem Index entfernen“, **umbenennen** in Aufgabe 65/67-Code, Tests und Texten): führt dasselbe **sofort** aus (schwarzer Bestätigungsmodus, zwei Klicks). **Ein Knopf für alle** Einschränkungen. Die Dateien auf den Medien bleiben unberührt.
6. **Erweitern (Tiefe höher, Schalter aus, Ausschluss entfernt):** Es erscheint **alles, was noch im Index steht**. **Ordner, deren Inhalt fehlt** (weil nie gelesen oder bereinigt), werden **beim nächsten Lauf nachgelesen**; das Medium zeigt bis dahin „x % indiziert“ (Status „Index unvollständig“, KONZEPT.md 2a). Läuft das Medium bereits und ist angeschlossen, startet der Lauf automatisch (wie „Neu indizieren“); sonst beim nächsten Anschließen. Ein noch offener `pruneAt` wird durch das Erweitern **nicht** aufgehoben, er löscht nur, was dann noch nicht zu den Einstellungen passt.
7. **Keine Terminzeile** und kein Knopf „Jetzt entfernen“ unter „Scan-Tiefe“ oder „Ausschlüsse“ (Nutzerentscheidung). Der Hinweistext steht im Layout.
8. **Technik:** Löschen in Blöcken (z. B. 5 000 Zeilen je Transaktion), abbrechbar und wiederaufnahmefähig (idempotent, beim Start prüfen). Volltextindex mitpflegen (Trigger `AFTER DELETE`, bei sehr großen Mengen `rebuild`). Danach Platz freigeben: `PRAGMA incremental_vacuum` (dafür `auto_vacuum = INCREMENTAL` bei neuen Datenbanken, bei bestehenden einmal per Migration `VACUUM`) und `wal_checkpoint(TRUNCATE)`. **Inhaltsstempel** (`contentStamp`) der Ordner an der neuen Tiefengrenze **zurücksetzen**, `completedDepth` auf `min(completedDepth, neue Tiefe)` setzen, Medium-Zähler (`fileCount`, `folderCount`) neu berechnen. Protokoll: `index prune removed=… ms=…` (ohne Namen).
9. **Tests (mit temporärer Datenbank):** (a) Tiefe 5 → 2: Anzeige sofort ohne tiefere Ebenen, Daten noch da, nach Termin gelöscht. (b) Tiefe 2 → 5 vor dem Termin: alles wieder sichtbar, nichts nachzulesen. (c) Tiefe 2 → 5 nach dem Löschen: Stempel zurückgesetzt, unvollständige Ordner werden nachgelesen. (d) Zweite Verringerung startet die Stunde neu. (e) Termin überlebt Neustart, überfällig wird sofort bereinigt. (f) Favorit in gelöschter Ebene ist weg, ohne Warnung. (g) Offline-Medium wird mitbereinigt. (h) „Index jetzt bereinigen“ löscht sofort alle vier Arten. (i) Artefakte an/aus, Unsichtbare an/aus, Ausschluss hinzu/weg. (j) Ein harter Stopp mitten im Löschen: beim Start wird fortgesetzt, keine Waisenzeilen. (k) Datei schrumpft (Größe vor/nach bei großem Löschen).

**Prüfung durch den Nutzer:** Tiefe 5 → 1: tiefere Ebenen sofort weg, in „Erweitert“ „Index jetzt bereinigen“: Datenbank wird kleiner. Tiefe zurück auf 5: Medium zeigt „x % indiziert“ und liest wieder.

---

## 62. App-Icon veredeln: leichter Verlauf und größenoptimierte Varianten (Nutzer 01.10.)

**Status:** Zwei freigegebene Icons. **Dunkel** (`Werkzeuge/icon-kandidat/`, Verlauf `#575757` oben links nach `#1F1F1F` unten rechts, helles Symbol) ist das Icon für den **Dark Mode** und liegt im Asset-Katalog (`AppIcon.appiconset` und `DockIcon.png`). **Hell** (`Werkzeuge/icon-kandidat-hell/`, oben `#F4F4F4`, unten `#D9D8D8`, Symbol `#1F1F1F`) ist das Icon für den **Light Mode**. Bei beiden ist die Endfarbe auf dem letzten Viertel der Diagonale schon erreicht. Die Umschaltung nach Erscheinungsbild ist noch nicht verdrahtet; im Katalog liegt vorerst nur das dunkle Icon. Sicherung der vorherigen Icons: `archiv/icon-freigegeben-2026-10-01/`.

**Ausgangslage:** Das Icon ist laut Nutzer **jetzt korrekt** (Kachel 824/1024, Rand 100, Radius 185,4, Symbol 60 % der Kachelbreite, gemessen im Dock 1,00 zu den Nachbarn). **Das darf nicht wieder kaputtgehen.** Aufgabe ist nur **Feinschliff**: (1) ein leichter Verlauf in der Kachel, (2) für jede Größe eine eigens gerechnete Variante statt Herunterskalieren, damit es in 16, 32 und 64 px scharf bleibt.

**Schutzregeln (verbindlich):**
1. **Sicherung zuerst:** den heutigen Stand (`AppIcon.appiconset`, `DockIcon.imageset`, `GenerateAppIcons.swift`) unverändert nach `archiv/icon-freigegeben-2026-10-01/` kopieren (Dateien samt `SHA-256`-Liste `pruefsummen.txt`). Nie mehr verändern.
2. **Kandidaten statt Ersetzen:** Das Skript erzeugt die neue Fassung mit Ausgabeordner (`GenerateAppIcons.swift <Ordner>`, gibt es schon) nach `Werkzeuge/icon-kandidat/`, **nicht** ins Projekt. Dazu ein **Vergleichsblatt** `vergleich.png`: freigegebener Stand und Kandidat nebeneinander in 1024, 512, 256, 128, 64, 32, 16 px, auf hellem und dunklem Grund, plus eine Dock-Simulation (Kachel mit Nachbar-Raster).
3. **Prüfskript statt Augenmaß** (`Werkzeuge/icon-pruefen`, gibt Zahlen aus, Abbruch bei Verstoß):
   - **Form unverändert:** Alphakanal der Kachel in jeder Größe wie freigegeben (Kachelbreite 80,5 % ±0,3 %, Mittelpunkt ±0,5 px, Eckradius ±0,5 px bei 1024, entsprechend skaliert).
   - **Symbol unverändert:** Begrenzung des Symbols (Breite, Höhe, Mittelpunkt) in jeder Größe ≤ 0,5 px Abweichung bei ≥ 128 px, ≤ 1 px bei kleineren Größen (dort ist optisches Nachjustieren erlaubt, siehe 5.).
   - **Mittelwert der Kachelfarbe** (Mitte der Kachel) liegt innerhalb ΔE ≤ 3 der freigegebenen Fläche, damit der Verlauf nur fein ist.
   - **Kein Schatten, kein Rahmen, keine neue Farbe** außerhalb der Kachel (Alpha außerhalb der Kachel = 0; Ausnahme nur der bisherige weiche Rand, falls vorhanden).
4. **Der Nutzer entscheidet.** Erst wenn der Nutzer das Vergleichsblatt freigibt, schreibt Cursor die Kandidaten ins Projekt. Davor bleibt `AppIcon`/`DockIcon` byteidentisch (Prüfsumme gegen `pruefsummen.txt`).

**Verlauf (leicht):** vertikal, oben etwas heller, unten Ausgangston. Kachelfarbe unten = heutige Farbe, oben **höchstens +4 % Helligkeit** (OKLCH L, Chroma/Farbton gleich). Kein zweiter Farbton, keine Glanzkante, keine Lichtreflexe. Symbol bleibt reines Weiß (`#F2F2F2` wie heute), ohne Schatten.

**Größenoptimierung („optische Größen“):** Das Skript rendert **jede Größe einzeln aus dem Vektor** (16, 32, 64, 128, 256, 512, 1024 und die @2x-Paare), nicht aus der 1024er herunterskaliert, mit:
- **Pixelraster:** Kanten des Symbols und der Kachel auf ganze Pixel legen, wo möglich (16 und 32 px).
- **Strichstärke:** bei ≤ 32 px das Symbol um bis zu **+8 %** kräftiger (Mindeststrich 1,5 px bei 16 px, 2 px bei 32 px), Abstand der zwei Geräte-Kästen bleibt ≥ 2 px, Punkte (Laufwerks-LEDs) bei 16 px entfallen oder werden zu einem Pixel, wenn sie sonst matschig sind. **Silhouette bleibt gleich** (Kachel und Symbolgröße nach 3.).
- **Glättung:** Mehrfachabtastung (≥ 4×4) beim Rendern, `sRGB`, 8 Bit, ohne Farbprofil-Sprünge.

**Technik:**
- Die Größen gehören in **`AppIcon.appiconset`** (alle 10 Einträge der macOS-Vorlage). `DockIcon.png` bleibt **identisch mit der 1024er** (wie bisher dokumentiert).
- `Contents.json` unverändert (Dateinamen bleiben).
- Optional: zusätzlich ein `AppIcon.icns` in `Werkzeuge/icon-kandidat/` zum Ansehen (`iconutil`).

**Tests:** (a) Prüfskript-Werte aus 3. als Unit-Test auf die erzeugten Dateien im Kandidatenordner. (b) Nach der Freigabe: alle Dateien im Projekt entsprechen byteweise den Kandidaten. (c) `DockIcon.png` = `icon_512x512@2x.png`.

**Prüfung durch den Nutzer:** `vergleich.png` ansehen (zuerst), dann Cursor das Ersetzen freigeben. Danach im Dock, im Finder (Listen- und Symbolansicht), im Programme-Ordner und unter „Über diesen Mac / Programme wechseln“ (⌘-Tab) ansehen. Wenn etwas anders aussieht als vorher: Ersetzen rückgängig durch Kopie aus `archiv/icon-freigegeben-2026-10-01/`.

---



---

## Freigegeben 02.10. (Review Claude per Bildschirmfoto-Vergleich: Einstellungen, Fehler-Modal, Spaltenansicht, Dropdown bestätigt; Dashboard-Fußzeile weiter in 79)

## 71. Bildschirmfotos aller Screens zum Layoutvergleich (Claude prüft damit)

**Status:** **Review Claude 02.10.: zurück, Werkzeug liefert leere Bilder und nur 3 Screens, siehe 71 (Korrektur) weiter unten.** Cursor-Stand: `--screenshots <Ordner>` nur im Debug-Start. `ScreenshotRunner` schreibt die Namen aus `ScreenshotPlan` als PNG 1280×800 @2x mit Fixture und beendet die App. Keine echte Datenbank. Test prüft nur die Argumentzerlegung.

Damit Claude **alles** gegen das Layout prüfen kann, ohne die App zu bedienen (Claude hat keine Bedienungshilfen-Freigabe): Startargument **`--screenshots <Ordner>`** (nur Debug): die App rendert **jeden Screen** in **Hell und Dunkel** mit **festen Testdaten** (Fixture, keine echten Medien) in PNG-Dateien, fester Fenstergröße 1280 × 800 @2x, und beendet sich. Dateinamen wie `04-uebersicht-hell.png`. Zu rendern (Layout-Nummer): 02 Erkennungs-Dialog; 03 Dropdown (Ruhezustand, Pause-Auswahl an/pausiert, Suche, Hover); 04 Übersicht; 05 Einstellungen (alle vier Tabs, Erscheinungsbild in allen drei Stellungen **mit Szene**, Mitteilungen mit Hover je Ereignis, Bestätigungsmodus Zustände „1. Klick“/„2. Klick“); 06 Detail-Overlay; 07 Spaltenansicht (Datei online, Ordner jenseits Scan-Tiefe, Kontextmenü am Ordner, Mehrfachauswahl); 08 mit Filter; 09 Filter-Popover; 10 Suche (alle Zustände 1 bis 6); 11 Favoriten (inkl. Kontextmenü); 12 Kontextmenü; 13 Absturzbericht-Dialog; 14 Indizierungsfehler-Modal und Mitteilung. **Fixture** nach den Texten und Zahlen im Layout (aber **ohne** Medien ohne Index in Dashboard und Seitenleiste, siehe KONZEPT.md 2.6) („Studio Backup“, „Backup SSD“, „Archiv 2019–2021“, „Externe Platte 5“ …). Ein Kommando legt alle Dateien in `Werkzeuge/screenshots/<Datum>/` ab. Die Layout-Vergleichsbilder rendert Claude selbst aus dem HTML. **Kein** Eingriff in die Produktion außer dem Startargument und einer Fixture (kein echter Zugriff auf Datenbank/Medien: eigene temporäre Datenbank).

---

## 75. Texttreue und Aufbau der Einstellungen (Layout 05, `layout-texte.md`)

**Status:** Fenstertexte der Einstellungen, des Erkennungs-Dialogs, der Medium-Details, des Absturzberichts und des Indizierungsfehlers stehen in `LayoutCopy` und werden von den Views verwendet. Mitteilungsvorschau: Pause abgelaufen, „48.210 Objekte“, „7 Favoriten“. Scan-Tiefe 5+ zeigt „Festplatte → maximale Indextiefe“. `LayoutCopyTests` liest `layout-texte.md` (Sektionen 02, 05, 06, 13, 14, ohne Beispieldaten, `{{ }}` und den Entwicklerblock ab „BESTÄTIGUNGSMODUS“) und verlangt jede Zeile in `LayoutCopy.swift`.

**Belegte Abweichungen** (aus dem Code gelesen, Stand 02.10.):
| Stelle | App heute | Layout (wörtlich, siehe `layout-texte.md`) |
|---|---|---|
| Allgemein: Autostart | Überschrift „SYSTEMSTART“, Schalter „Automatisch bei Systemstart“, Zusatzknopf „In den Systemeinstellungen freigeben“ | Überschrift **„AUTOSTART“**, Text „Disk Index startet nach dem Anmelden automatisch in der Menüleiste, damit angeschlossene Speichermedien sofort erkannt werden.“, Checkbox **„Beim Anmelden starten“** (der Freigabe-Hinweis darf nur erscheinen, wenn macOS ihn verlangt) |
| Allgemein: Erscheinungsbild | Überschrift ohne Text | Text „Hell oder Dunkel legt das Erscheinungsbild fest. Automatisch folgt der Systemeinstellung von macOS.“ |
| Dateien & Ordner: Überschrift der Spaltenfilter-Einstellung | „ORDNER WEITERHIN ANZEIGEN“ | **„DATEITYP-FILTER IN DER SPALTENANSICHT“**, Text „Legt fest, wie sich gesetzte Dateityp- und Endungsfilter beim Durchblättern von Ordnern verhalten.“, Checkbox „Ordner weiterhin anzeigen“, darunter „Ordner bleiben sichtbar, damit man sich bis zu den passenden Dateien durchklicken kann.“ |
| Dateien & Ordner: Scan-Tiefe | Beispiel bei **5+ mit vier Brotkrumen** („Festplatte → Unterordner 1 → Unterordner 2 → maximale Indextiefe“) | Bei 5+ **genau zwei**: „Festplatte → maximale Indextiefe“. Beschreibung inklusive der neuen Sätze zu Verringern/Erhöhen (Layout) |
| Dateien & Ordner: Ausschlüsse | zusätzlicher Knopf „Auf Standard zurücksetzen“, Text weicht ab | Knopf entfällt (nicht im Layout); Text wörtlich wie Layout |
| Dateien & Ordner: Unsichtbare Dateien | „Nimmt versteckte Systemdateien und -ordner von der Indizierung aus (z. B. .DS_Store, .git).“ | „Schließt versteckte Systemdateien und -ordner vom Index aus. …“ (wörtlich, mit dem neuen Zusatz) |
| Erweitert: Mitteilungen | Schalter „Mitteilungen“, keine Beschreibung, Vorschautexte falsch | Schalter **„Mitteilungen aktivieren“**, Beschreibung wörtlich, Ereignis-Beschriftungen „Systemmeldungen“, „Speichermedium vollständig indiziert“, „Speichermedium mit Favoriten angeschlossen“, Vorschau-Texte siehe Punkt 3 |
| Erweitert: Index bereinigen | Knopf „Aus dem Index entfernen“ (liegt im Code in zwei Dateien) | Überschrift **„SCAN-TIEFE UND AUSGESCHLOSSENE DATEIEN & ORDNER“**, Text wörtlich, Knopf **„Index jetzt bereinigen“** (Aufgabe 74 benennt um, hier die Texte prüfen) |
| Erweitert: Voreinstellungen, Speichermedien, Fehlerberichte | Knöpfe ohne die Beschreibungstexte, „Künftig automatisch senden“ lose | Je **Überschrift + Beschreibungstext + Schaltfläche** wie im Layout; „Alle Speichermedien vergessen“ mit **fettem, nicht rotem** Warnsatz „Löscht alle Daten. Das kann nicht rückgängig gemacht werden.“ links unter dem Infotext; Abschnitt **„FEHLERBERICHTE“** mit Text und Checkbox „Künftig automatisch senden“ |

**Soll:**
1. **Alle Texte des Einstellungsfensters** (vier Tabs) **wörtlich** aus `layout-texte.md` übernehmen (Überschriften, Beschreibungen, Beschriftungen). Reihenfolge der Abschnitte je Tab wie im Layout. **Nicht** in der App: der Block „BESTÄTIGUNGSMODUS“ und die Tabelle „VOREINSTELLUNGEN“ unter dem Fenster (Dokumentation für Entwickler), ebenso Zeilen in `{{ … }}` (Platzhalter für echte Werte).
2. **Alle App-Texte, die für das Layout relevant sind, zentral** in eine Datei (z. B. `LayoutCopy.swift`) legen, damit sie prüfbar sind; Views verwenden nur diese Konstanten.
3. **Mitteilungsvorschau (`NoticeCopy.preview` in `RestModels.swift`) ersetzen** durch die Texte des Layouts: (1) Systemmeldungen: „Die Pause ist abgelaufen. Automatisches Indizieren ist wieder an.“ (2) Vollständig indiziert: „Medium „Archiv 2019–2021“ ist vollständig indiziert – 48.210 Objekte“ (3) Mit Favoriten angeschlossen: „Medium „Archiv 2019–2021“ mit 7 Favoriten ist online“. Die heutige Systemmeldung „Disk Index wurde 59 Sekunden nicht beendet.“ ist **falsch** (Vermischung mit der 59-Sekunden-Schwelle). Echte Mitteilungen setzen Name und Zahlen echter Daten ein, Zahlen mit Tausenderpunkt (de).
4. **Test (Texttreue):** Ein Test liest `layout-texte.md` (Pfad im Repo), extrahiert die Fensterzeilen der Sektionen 02, 05, 06, 13, 14 (ohne Beispieldaten und `{{ }}`) und prüft, dass **jede** dieser Zeilen in `LayoutCopy` vorkommt. Beispieldaten sind in einer Ausnahmeliste im Test benannt.
5. **Nach der Umsetzung** Bildschirmfotos (Aufgabe 71, korrigiert) aller vier Tabs in Hell und Dunkel und Claude zum Vergleich geben.

---

## 71 Korrektur. Bildschirmfoto-Werkzeug liefert leere Bilder und nur 3 von etwa 20 Screens

**Status:** `ScreenshotRunner` zeichnet ein echtes Fenster (1280×800, Retina), wartet 0,6 s und speichert über `cacheDisplay`. Einfarbige Bilder beenden das Werkzeug mit Fehler. `ScreenshotPlan` hat 34 Flächen je Hell und Dunkel (02 bis 14, inklusive Pause, Einstellungen, Suche 1–6, Kontextmenü, Fehler). Fixture ohne Medien ohne Index im Dashboard. Ausgabe: `Werkzeuge/screenshots/2026-10-02/` (68 Dateien). Test prüft die Namensliste und dass ein flaches Bild als leer gilt.

**Befund (Claude, 02.10.):** `Disk Index --screenshots <Ordner>` schreibt nur **6 Dateien** (02, 04 und 13, je Hell und Dunkel). **Alle sind komplett leer** (alle Pixel `0, 0, 0` transparent/schwarz, 2560 × 1600). Die Aufgabe 71 verlangt alle Screens 02 bis 14 mit festen Testdaten. Die Prüfung der App gegen das Layout ist damit nicht möglich.

**Soll:**
1. **Rendern reparieren:** Das Fenster muss **wirklich gezeichnet** werden, bevor das Bild entsteht. Bewährt: echtes `NSWindow` (Größe 1280 × 800) mit dem Inhalt, `appearance` gesetzt, `orderFrontRegardless`, Runloop **0,6 s drehen** (SwiftUI/Animationen fertig), danach das Bild des Fensters über `CGWindowListCreateImage` (Fenster-ID) **oder** `contentView.bitmapImageRepForCachingDisplay(in:)` + `cacheDisplay(in:to:)`. **Kein** `ImageRenderer` für Views mit AppKit-Controls. Nach dem Rendern prüft das Werkzeug selbst, ob das Bild **nicht einfarbig** ist und beendet sonst mit Fehler (Test dazu).
2. **Alle Screens**, je Hell und Dunkel, mit Namen laut `ScreenshotPlan`: 02 Erkennungs-Dialog; 03 Dropdown (Ruhezustand, Pause-Auswahl bei An, bei Pausiert, Suche, Hover); 04 Übersicht (Fixture ohne Medien ohne Index, Chips Online, Offline, „x % indiziert“, „45 % indiziert, offline“, Fehler); 05 Einstellungen **alle vier Tabs**, Erscheinungsbild in allen drei Stellungen, Mitteilungen mit Hover je Ereignis; 06 Detail-Overlay; 07 Spaltenansicht (online, Ordner jenseits der Tiefe, Kontextmenü am Ordner, Mehrfachauswahl); 08 mit Filter; 09 Filter-Popover; 10 Suche (Zustände 1 bis 6); 11 Favoriten; 12 Kontextmenü; 13 Absturzbericht; 14 Indizierungsfehler (Modal und Mitteilungsansicht).
3. **Fixture** nach den Beispielwerten im Layout („Studio Backup“, „Backup SSD“, „Archiv 2019–2021“, „Reise-SSD“, „NAS Klon“, „Foto-SSD“ …).
4. Ergebnis liegt in `Werkzeuge/screenshots/<Datum>/`. **Claude** rendert die Layout-Seiten daneben und prüft Bild für Bild.

---

## 77. Optik-Korrekturen aus dem Bildschirmfoto-Vergleich (Claude, 02.10.)

**Status:** Tag/Nacht: Nachtanteil von rechts, Sonne und Mond an der oberen linken Ecke (versteckt bei `top` 70). Pause-Menü eigene Fläche, Überschrift, Textzeilen, Häkchen, „Pausiert“ in `#3A3A3A`. Artefakte-Abschnitt da, Ausschluss-Block bündig, Reset-Knopf weg. Filterchip „Offline“. Tabellenkopf `text` 5 %. Erweitert zweispaltig, Warnsatz fett links. Such-Icon öffnet die Filterleiste. Medien-Kästchen mit Häkchen, „Alle Medien“ blau mit Trennlinie. Karten mindestens 185 pt. „Disk Index öffnen“ bleibt in der Leiste, auch ohne Medien. Bilder: `Werkzeuge/screenshots/2026-10-02/`.

**Quelle:** 12 Bildschirmfotos der App (vom Nutzer, Hell und Dunkel) gegen die gerenderten Layout-Seiten 03, 05, 09, 10. Alles unten ist **gemessen am Bild, nicht geraten**. Texte der Einstellungen stehen in Aufgabe 75, hier nur Aufbau und Optik.

1. **Tag/Nacht-Szene (Einstellungen → Allgemein), zwei Fehler:**
   a) **Automatisch** ist **seitenverkehrt**: Im Layout ist die **rechte** Hälfte Nacht (`clip-path: inset(0 0 0 50%)` zeigt die rechte Hälfte), links Tag mit Sonne (22 %), rechts Mond (76 %). Die App zeigt links Nacht mit der Sonne mitten im Dunkeln, rechts Tag mit dem Mond.
   b) **Positionen sind Mittelpunkte statt linke obere Ecke.** Im Layout bedeutet `left`/`top` die **obere linke Ecke** des Kreises (Sonne 22 pt, Mond 20 pt). Die App setzt den Mittelpunkt (`.position`). Folge: In **Dunkel** schaut die **Sonne unten über den Boden** hervor, in **Hell** der **Mond**. Versteckt heißt: `top: 70 pt` (Oberkante unter der 64-pt-Fläche, also vollständig unsichtbar). Sonne und Mond mit `.offset`/Alignment oben links statt Mittelpunkt setzen; Sterne ebenso (obere linke Ecke).
2. **Pause-Popover (Dropdown 03):** Die App zeigt ein **bläulich getöntes Systemmaterial** mit **blauen Pillenknöpfen** und **ohne Überschrift**. Layout: **neutrale Fläche** (`bg`, in Dunkel `#1F1F1F`/`surface`), Rand `divider`, Schatten `DesignColor.shadow`, Pfeil unter „Pausiert“, Überschrift **„PAUSIEREN FÜR“** (klein, Großbuchstaben, 45 %), darunter **schlichte Textzeilen** (kein Hintergrund, Hover grau) „30 Minuten“, „1 Stunde“, „Bis morgen“, „Für immer“. **Pausiert-Variante:** oben fett „Pausiert für 1 Stunde“, darunter klein „bis 15:42 Uhr“, Trenner, Überschrift **„ÄNDERN AUF“**, die aktive Dauer mit Häkchen und ausgegraut, die anderen wählbar. **Kein** `.popover`-Standardmaterial, **keine** Akzentfarbe des Systems (die App darf nie vom Hintergrundbild oder der Systemakzentfarbe eingefärbt sein). Dunkelblock beachten.
   **Maße aus dem Layout-Bild des Nutzers (02.10., Bild bei 2x, Werte in pt):** Popover **≈ 209 pt breit**, Rand 1 pt `divider`, Radius **≈ 8 pt**, Fläche **gleich der Dropdown-Fläche** (`surface`/`bg`, nicht transparent, kein Material), weicher Schatten `DesignColor.shadow`. Es hängt **unmittelbar unter** dem Schalter „An | Pausiert“ (Abstand ≈ 6 pt) und **überlagert** den Fuß des Dropdowns („Disk Index öffnen“ wird zum Teil verdeckt). **Pfeil:** kleines Dreieck (≈ 10 × 6 pt, gleiche Fläche und Rand wie das Popover) **oben mittig unter dem Segment „Pausiert“**. **Innenabstand links ≈ 15 pt**, Überschrift „PAUSIEREN FÜR“ **≈ 10,5 pt**, Buchstabenabstand 0,08 em, Farbe `text` 45 %. **Zeilen:** Höhe **≈ 32 pt**, Text **≈ 13 pt** regular in `text`, **Einzug links ≈ 39 pt** (Spalte davor ist für das Häkchen reserviert, auch wenn keines steht), kein Hintergrund, bei Hover `text` 6 %. **Pausiert-Variante:** erste Zeile **„Pausiert für 1 Stunde“ fett ≈ 13 pt**, darunter **„bis 15:42 Uhr“ ≈ 11,5 pt** `text` 60 %; darunter **Trennlinie** (eingerückt ≈ 5 pt, `divider`); dann Überschrift **„ÄNDERN AUF“**; die **aktive Dauer** mit **Häkchen** in der Einzugsspalte und **Text `text` 45 %** (ausgegraut, nicht anklickbar), die anderen normal. **Selectgroup oben:** bei **An** ist „An“ gefüllt (`control`, Schrift weiß, fett), „Pausiert“ Rand und grauer Text; bei **Pausiert** ist „Pausiert“ gefüllt (dunkles Grau **≈ `#3A3A3A` hell**, Schrift weiß fett), „An“ Rand und grauer Text. **Beim indizierenden Medium** steht bei **Pause das Pause-Icon (II)** statt des Spinners vor „14 %“ (gestrichelt unterstrichen), bei An der Spinner. **Abnahme:** gerendertes Layout 03 (Hell und Dunkel) neben die App legen, Abstand und Größen nachmessen.
3. **Einstellungen → Dateien & Ordner:** (a) **Abschnitt „ARTEFAKTE“ fehlt** (Überschrift, Text, Schalter „Ignorieren“, Standard an). (b) Der Block **„DATEIEN & ORDNER AUSSCHLIESSEN“** ist **40 pt eingerückt** gegenüber den anderen Abschnitten (gleiche linke Kante wie Scan-Tiefe und Filter). (c) **Knöpfe „Aus dem Index entfernen“ und „Auf Standard zurücksetzen“** gehören **nicht** in diesen Tab (Layout: nur in Erweitert, dort „Index jetzt bereinigen“; „Auf Standard zurücksetzen“ gibt es nicht). (d) Die Chips `node_modules`, `*.tmp`, `Cache` stammen aus alten Voreinstellungen; Voreinstellung ist **leer** (Aufgabe 64.6). (e) Der Text nennt noch „Erfasste Objekte jetzt bereinigen“ und „gelbes Prohibit-Icon“ (veraltet, siehe Aufgabe 75 und 74).
4. **Einstellungen → Speichermedien:** Filterchips **„Pausiert“ → „Offline“** (Layout: Alle / Indiziert / Offline / Nicht erlaubt). Kopfzeile der Tabelle hat einen **rosa Stich** in Hell (Fläche neutral, `text` 4 bis 6 %).
5. **Einstellungen → Erweitert:** **Aufbau fehlt komplett.** Layout: Abschnitte mit Überschrift, Beschreibung und Steuerung: **MITTEILUNGEN** (Text, links Checkbox „Mitteilungen aktivieren“, darunter drei Ereignis-Checkboxen mit **Beschriftung rechts neben der Checkbox**, Vorschaukarte „BEISPIEL“), **SCAN-TIEFE UND AUSGESCHLOSSENE DATEIEN & ORDNER** (Text, Knopf „Index jetzt bereinigen“), **VOREINSTELLUNGEN**, **SPEICHERMEDIEN** (fetter, nicht roter Warnsatz, roter Knopf „Alle Speichermedien vergessen“), **FEHLERBERICHTE** (Text, Checkbox „Künftig automatisch senden“). Die App zeigt nur lose Checkboxen **mit Label links und Checkbox rechts** („System ☑“) und gestapelte Knöpfe. Layout durchgehend **zweispaltig** (links Überschrift und Beschreibung, rechts Steuerung), Trennlinien zwischen den Abschnitten, wie in Allgemein.
6. **Suche, Zustand 1:** Über das **Such-Icon** geöffnet muss die **Filterleiste offen** sein und **beide Icons blau** (Layout 08/10). Die App zeigte beim Öffnen nur das Such-Icon blau, **ohne** Filterleiste. (Hinweistext „Suchbegriff eingeben oder Filter verwenden / Durchsucht alle erfassten Speichermedien – auch offline.“ stimmt.)
7. **Filter-Popover (09):** Die **Medium-Checkboxen** zeigen ein **gefülltes schwarzes Quadrat** („gemischt“), das Layout hat **schlichte Kästchen** (leer, bei Auswahl Häkchen); „Alle Medien“ blau mit Trennlinie darunter. Zähler „x von y Medien“ stimmt im Prinzip (Layout „6 von 21 Medien“ ist Beispielzahl).
8. **Dashboard 04 (Dunkel):** Kartenbreite etwa 255 pt, Layout etwa 185 pt (fünf Karten in einer Zeile bei 1100 pt Fensterbreite); Kapazitätszeile „14 % belegt“ (gestrichelt unterstrichen, klickbar zwischen % und absolut) bei **Online**-Medien prüfen, bei Offline entfällt sie wie im Layout. Typ-Icon je Medium (HDD, SSD, USB) beibehalten.
9. **Dropdown (03), Knopf „Disk Index öffnen“ fehlt im Bild** (Nutzer 02.10.): Im Code gibt es ihn ([MenuBarPopoverView.swift:130](diskindex/diskindex/MenuBar/MenuBarPopoverView.swift) `openAppFooter`), im Bildschirmfoto ist er nicht zu sehen. Vermutung: `MenuBarPopoverLayout.panelHeight` rechnet die Fußzeile nicht (immer) ein, im leeren Zustand („Kein Speichermedium angeschlossen“) ist das Panel zu niedrig. Layout 03: **Eigene Zeile „Disk Index öffnen“ (fett, links) ganz unten, in jedem Zustand** (Ruhezustand, Pause-Auswahl, Suche), unter der Zeile „Automatisches Indizieren“. Prüfen in Hell und Dunkel, auch mit Pause-Popover offen (es darf die Zeile teilweise verdecken, wie im Layout).
10. **Favoriten (Dunkel):** Chips Alle/Online/Offline, Tabellenkopf, Statuschips und Fußleiste „3 Objekte“ **stimmen** mit dem Layout.

**Test/Abnahme:** Mit dem reparierten Bildschirmfoto-Werkzeug (Aufgabe 71, Korrektur) alle betroffenen Screens in Hell und Dunkel neu aufnehmen. Claude vergleicht sie mit den gerenderten Layout-Seiten.

---

## 78. Korrekturen aus dem Bildschirmfoto-Vergleich (Claude, 02.10., zweite Runde)

**Status:** Allgemein: Erscheinungsbild vor Autostart, zweispaltig, `AppearanceSegmentedControl` (Rahmen `#1F1F1F`, aktiv 12 pt fett). Indizierungsfehler: Dialog wie 13/02 (Icon, Karte 360 pt, Schatten, gleich breite Knöpfe, dimmed Overlay in `MainWindowHostView`). Dashboard: Karten `minHeight` 158, Chip einzeilig, Fußzeile zweizeilig statt abgeschnitten, Grid max. 255 pt. Spaltenansicht: `IndexRepository.seedScreenshotCache`, Fixture `ScreenshotFixture.configureColumnBrowser` für 07/08; 07-kontext/mehrfach mit `MainWindowHostView` + Kontextmenü; Seitenleiste ohne Verlauf (`fadeTitleWhenSelected: false`), `FadeMaskText` nur bei Überlauf. Szene: Sonnenring mit negativem Padding. Screenshots neu: `Werkzeuge/screenshots/2026-10-02/` (68 PNGs). Tests 170/170 grün, Release-Build OK.

Grundlage: `Werkzeuge/screenshots/2026-10-02/` (Werkzeug funktioniert, 71 Korrektur ist damit erfüllt). Verglichen mit dem Layout-HTML. **Bestätigt in Ordnung:** Dropdown mit „Disk Index öffnen“ (03 Ruhe), Pause-Popover, Einstellungen Dateien & Ordner, Erweitert, Speichermedien (Texte und Aufbau), Absturz-Dialog 13, Medium-Details 06.

**Abweichungen (alle beheben):**
1. **Einstellungen → Allgemein (05) hat falsche Reihenfolge und Aufbau.** Layout: **zuerst ERSCHEINUNGSBILD**, dann Trennlinie, dann **AUTOSTART**. Je Abschnitt zweispaltig: links Überschrift + Beschreibung, rechts Bedienelement. Erscheinungsbild rechts: Segment **Hell | Dunkel | Automatisch** (Rahmen und aktives Segment in `#1F1F1F`, aktives Segment schwarz mit weißem Text, 12 pt, fett) und darunter die Szene (64 × 260 pt). **Es gibt kein Zeilenlabel „ERSCHEINUNGSBILD“ links vom Segment** (im Bild bricht es als „ERSCHEI-NUNGSBILD“ um) und die Beschreibung steht links in der Spalte, nicht über die ganze Breite. Autostart: Checkbox „Beim Anmelden starten“ rechts in der Spalte.
2. **Indizierungsfehler-Modal (14) ist kein Dialog.** Layout: Dialogkarte 360 pt breit, Rahmen, Schatten, Warndreieck-Icon 30 pt oben, Titel 16 pt, zwei Absätze 13 pt, darunter **zwei gleich breite Knöpfe** (`flex:1`, 14 pt fett, Innenabstand 10/18): „Schließen“ (sekundär, Rahmen `neutral-500`) und „Erneut versuchen“ (primär, schwarz). Aktuell steht der Text lose auf der Fläche mit zwei kleinen Standardknöpfen und ohne Icon, ohne Karte. Die Karte liegt über dem Hauptfenster (Hintergrund leicht abgedunkelt wie bei 06).
3. **Dashboard-Karten (04):** Karten in einer Reihe müssen **oben bündig** und **gleich hoch** sein. Aktuell sitzen „Foto-SSD“ (zweizeiliger Chip) und „NAS Klon“ höher beziehungsweise höher gebaut als die anderen (Oberkante 110/106 statt 118 px). Chip „45 % indiziert, offline“ darf **nicht umbrechen** (eine Zeile, Karte wenn nötig breiter, Mindestbreite im Layout prüfen). Fußzeile „35 % belegt · zuletzt gesehen…“ wird abgeschnitten; mit Layout-Text vergleichen und Zeile so setzen, dass nichts abgeschnitten wird.
4. **Spaltenansicht (07) im Bildschirmfoto leer** („0 Elemente“). Fixture muss Ordner und Dateien enthalten (wie im Layout: Spalten mit Auswahl, Vorschau/Details), sonst lässt sich 07, 08, 12 nicht prüfen. Gleiches für `07-tiefe`, `07-kontext`, `07-mehrfach`: aktuell identisch mit `07-spalten`/`12-kontext` (gleiche Farbzahl), das Werkzeug muss den jeweiligen Zustand wirklich herstellen.
5. **Seitenleiste Spaltenansicht:** Der Name der ausgewählten Zeile „Studio Backup“ läuft in einen Ausblend-Verlauf („Backup“ zu „Backu p“), obwohl Platz ist. Verlauf nur bei echtem Überlauf.
6. **Szene Allgemein:** Sonne links, Mond rechts, wie im Layout: Maße prüfen nach Umbau 1 (Sonne 22 pt mit 5 pt Ring `#EDA12D` 18 %, Mond 20 pt, Boden 12 pt, vier Sterne).

Danach alle betroffenen Screens neu aufnehmen (Hell und Dunkel), Status ausfüllen.

---



---

## Freigegeben 02.10. (optisch gegen Layout geprüft)

## 64. Einstellungen umbauen: vier Tabs, Erscheinungsbild, Autostart, Voreinstellungen (Layout Sektion 05)

**Status:** **Review Claude 02.10.: zurück, Aufbau und Texte weichen vom Layout ab, siehe Aufgabe 75 und 77 (Szene seitenverkehrt, Abschnitte fehlen).** Cursor-Stand: Vier Tabs: Allgemein, Dateien & Ordner, Speichermedien, Erweitert. Erscheinungsbild setzt `NSApp.appearance` sofort (Hell `.aqua`, Dunkel `.darkAqua`, Automatisch `nil`) und speichert in `AppSettings`. `DayNightScene` 64×260, Radius 8, Nachtanteil 0 / 0,5 / 1, Kurve 0,6 s. Scan-Tiefe-Standard 5 nur für neue Einstellungen und „Voreinstellungen anwenden“; gespeicherte Tiefe bleibt. Speichermedien-Tabelle Ja | Nein schreibt `decision`. „Aus dem Index entfernen“ und „Alle Speichermedien vergessen“ über `ConfirmButton`. Autostart bleibt der vorhandene `LaunchAtLogin`-Spiegel, der Test ruft `SMAppService` nicht auf. Test `RestCoverageTests` (Tiefe 5, alte JSON-Tiefe 3).

Quelle: Layout **05 „Einstellungen“** (Hell/Dunkel), Voreinstellungstabelle darunter, `konzept-anmerkungen.txt` (Artefakte). Das Einstellungsfenster bleibt eine Ansicht im Hauptfenster, kein Modal.

1. **Vier Tabs links:** „Allgemein“, „Dateien & Ordner“, „Speichermedien“, „Erweitert“ (heute drei: „Ignorierte Objekte“ fällt weg und geht in „Dateien & Ordner“ auf).
2. **Allgemein:** **Autostart** („Beim Anmelden starten“, hängt an `LaunchAtLogin`/`SMAppService`; Standard An: beim **ersten Start** registrieren; ist die Freigabe in macOS (Systemeinstellungen → Allgemein → Anmeldeobjekte) nötig (`.requiresApproval`), steht neben dem Schalter ein Hinweis mit Knopf „Systemeinstellungen öffnen“ und der Schalter zeigt den echten Zustand, Info-Text laut Layout; der Menüleisten-Eintrag „Beim Anmelden starten“ bleibt und zeigt denselben Zustand). **Erscheinungsbild:** Umschalter **Hell / Dunkel / Automatisch**, Standard Automatisch. Hell/Dunkel erzwingt `NSApp.appearance` (`.aqua`/`.darkAqua`), Automatisch `nil` (folgt macOS), **sofort wirksam, auch live**, gilt für alle Fenster, Popover und Panels. Darunter die **Tag/Nacht-Szene** (Sonne/Mond/Sterne), die auf den Umschalter reagiert (Layout nur im hellen Screen, im dunklen Screen nicht vorhanden): **Animation genau nach Layout (nativ in SwiftUI nachbauen, keine HTML-Übernahme):** Szene 64 pt hoch, höchstens 260 pt breit, Radius 8, Rand `divider`, beschneidet Inhalt. Tagesfläche **#F3EFE6**. Darüber eine **Nachtfläche #1C2233**, die per **Maske von links** erscheint: Hell **unsichtbar** (Anteil 0), Dunkel **voll** (1), Automatisch **rechte Hälfte** (0,5). Boden: Streifen unten, 12 pt hoch, `#8A8577` mit 35 %. **Sonne:** Kreis 22 pt **#EDA12D** mit Ring 5 pt (`#EDA12D` 18 %); Position (x vom linken Rand, y von oben): Hell und Automatisch **22 % / 14 pt**, Dunkel **18 % / 70 pt** (unter dem Rand, verschwunden). **Mond:** Sichel (Kreis 20 pt, innerer Schatten −6/−3 in `#EAE9E9`, um −20° gedreht): Hell **76 % / 70 pt** (unten, verschwunden), Dunkel **46 % / 14 pt**, Automatisch **76 % / 14 pt**. **Sterne:** vier weiße Punkte (2, 2, 3, 2 pt) bei (58 % / 14), (72 % / 30), (88 % / 12), (64 % / 44) pt: **Deckkraft 0** bei Hell, sonst 1. **Zeiten:** Maske, Sonne und Mond **0,6 s** mit Kurve `cubic-bezier(.6, 0, .3, 1)`; Sterne **0,5 s** Deckkraft mit Verzögerung 0,2 / 0,3 / 0,25 / 0,35 s; Selectgroup-Hintergrund/Schrift **0,2 s**. Die Szene gibt es in **Hell und Dunkel** (Dunkelblock: gewählter Knopf in `#4A4949`). **Das Umschalten wirkt zugleich auf das ganze Fenster** (wie 64.2, mit weicher Überblendung der App, wenn technisch möglich; sonst sofort).
3. **Dateien & Ordner:** (a) **Scan-Tiefe** (1, 2, 3, 4, 5+; **Voreinstellung 5+**, vorher 3, siehe unten) mit Beispiel-Pfad; (b) **Dateityp-Filter in der Spaltenansicht**: „Ordner weiterhin anzeigen“ (heute unter „Allgemein“); (c) **Dateien & Ordner ausschließen** (Chips mit „Hinzufügen“, wie die heutige Ignore-Liste; Texte aus dem Layout, inkl. Hinweis 1 Stunde im Index und gelbes Prohibit-Icon, siehe 65); (d) **Unsichtbare Dateien** (Schalter „Ignorieren“, Standard An); (e) **Artefakte** (Schalter „Ignorieren“, Standard An). Die Schalter-Texte und Titel genau nach Layout.
4. **Speichermedien** (Layout 21:52): Filterchips **Alle / Indiziert / Offline / Nicht erlaubt**, Spalten **Name, Typ, Status, „Indizieren“** mit Selectgroup **Ja | Nein** je Medium (wie „Soll indiziert werden“ in den Medium-Details 06, Aufgabe 69). **Alle registrierten Medien** stehen hier (auch ohne Entscheidung und ohne Index), neue erscheinen **sofort** (Live-Aktualisierung). Tabellenregel wie im Layout (aktive Spalte schwarz, keine Sortierpfeile). Klick auf Name oder Detail-Icon öffnet die Medium-Details (06).
5. **Erweitert:** **Mitteilungen** (siehe 66), **Ausgeschlossene Dateien und Ordner** (Schaltfläche „Aus dem Index entfernen“, siehe 65), **Voreinstellungen** („Voreinstellungen anwenden“: setzt **alle Programmeinstellungen** auf die Voreinstellung zurück, **nicht** Speichermedien, Index, Favoriten; „Fehlerberichte künftig automatisch senden“ geht auf Aus; eigene Ausschlüsse werden geleert), **Speichermedien** („Alle Speichermedien vergessen“, Warntext **links unter dem Infotext, fett, nicht rot**: „Löscht alle Daten. Das kann nicht rückgängig gemacht werden.“) der Abschnitt **„Fehlerberichte“** (Erklärtext und Checkbox „Künftig automatisch senden“, siehe 63) und der **Bestätigungsmodus** (67). Reihenfolge der Abschnitte wie im Layout: Mitteilungen, Ausgeschlossene Dateien und Ordner, Voreinstellungen, Speichermedien, Fehlerberichte.
6. **Voreinstellungstabelle** (Layout, unter dem Fenster) ist verbindlich: Beim Anmelden starten An · Erscheinungsbild Automatisch · Scan-Tiefe **5+** · Ordner weiterhin anzeigen An · Unsichtbare Dateien ignorieren An · Artefakte ignorieren An · Mitteilungen aktivieren An · Mitteilung Systemmeldungen An · vollständig indiziert An · mit Favoriten angeschlossen An · **Fehlerberichte künftig automatisch senden Aus**. Die Zeilen „Ausgeschlossen“ und „Soll indiziert werden (neue Medien)“ gibt es **nicht** (vom Nutzer gestrichen). **Eigene Ausschlüsse sind in der Voreinstellung leer** (node_modules, `*.tmp` usw. deckt der Artefakt-Schalter ab); `AppSettings.defaultExcludedPatterns` wird `[]`, bestehende Nutzerlisten bleiben unberührt.
7. **Migration:** Bestehende gespeicherte Einstellungen (`AppSettings` in UserDefaults) bleiben lesbar. Die neue Voreinstellung 5+ gilt **nur** für Neuinstallation und „Voreinstellungen anwenden“, **nicht** rückwirkend. `ignoreHiddenFiles` und `excludedPatterns` bleiben, `artifactsIgnored` kommt neu (Standard An).
8. **Hinweis zur Scan-Tiefe 5+ als Standard (Claude):** Jede neue Platte wird dann bis zum Ende erfasst. Die Messung aus Aufgabe 59 (Stempelvergleich) hält den Abgleich kurz, der **Erstlauf** einer großen Platte ist aber lang. Der Nutzer hat die Voreinstellung im Layout so festgelegt: so umsetzen. Fortschritt und Pausieren müssen auch bei Stunden-Läufen stabil sein.
9. **Tests:** Vier Tabs in dieser Reihenfolge; Erscheinungsbild wechselt Appearance live und speichert; Voreinstellungen anwenden setzt nur Programmeinstellungen; Migration lädt alte Einstellungen; Autostart-Schalter spiegelt `SMAppService.status`.

---

## 66. Mitteilungen (Layout Sektion 05, Tab „Erweitert“)

**Status:** **Review Claude 02.10.: zurück, Aufbau der Mitteilungen in Erweitert und Vorschautexte weichen ab, siehe 75 und 77.** Cursor-Stand: Schalter „Mitteilungen“ und drei Ereignisse `notifySystem`, `notifyIndexed`, `notifyFavorites` in `AppSettings`. Zeiger über Label oder Checkbox zeigt die Vorschau. Alte `favoriteOnlineNotificationsEnabled` füllt `notifyFavorites`, wenn der neue Schlüssel fehlt. Schwelle `NoticeCopy.minimumVisibleSeconds` = 59. Berechtigung nur beim normalen Start (`NoticePermission`), nicht bei Tests, `--background` oder `--screenshots`. Test `RestCoverageTests`.

1. **Schalter „Mitteilungen aktivieren“** (Standard An) und **drei Ereignisse** als Checkboxen (alle Standard An): **Systemmeldungen** (Hinweise zu Fehlern und abgelaufenen Pausen), **Speichermedium vollständig indiziert**, **Speichermedium mit Favoriten angeschlossen**. Ist der Hauptschalter **aus**, sind die drei Checkboxen **ausgegraut** (nicht verborgen). **Mitteilungsvorschau (Animation/Verhalten, Layout 05 „BEISPIEL“):** Karte mit gestricheltem Rand (`divider`), Radius 6, Innenabstand 8 × 10, Fläche `text` 3 %. Kopf „BEISPIEL“ 9 pt, Abstand 0,06 em, `text` 45 %. Zeile: Icon 16 pt (Phosphor duotone) und rechts **„Disk Index“** fett 11 pt, darunter der Text 11 pt in `text` 55 %. **Standard: Systemmeldung.** Fährt der Zeiger über ein Ereignis (Label **oder** Checkbox), wechselt die Vorschau **sofort** auf dessen Mitteilung, beim Verlassen zurück zur Systemmeldung. Inhalte: (1) **Systemmeldungen**, Icon `info`, Farbe `text`: „Die Pause ist abgelaufen. Automatisches Indizieren ist wieder an.“ (2) **Vollständig indiziert**, Icon `check-circle`, Farbe Grün (`#20A04E`): „Medium „Archiv 2019–2021“ ist vollständig indiziert – 48.210 Objekte“ (3) **Mit Favoriten angeschlossen**, Icon `bookmarks-simple`, Farbe Violett (`#9D69D2`): „Medium „Archiv 2019–2021“ mit 7 Favoriten ist online“. (Medienname, Zahl der Objekte und Favoriten in der Vorschau sind Beispielwerte; echte Mitteilungen setzen den echten Namen und die echten Zahlen ein, Tausenderpunkt wie „48.210“ im deutschen Format.) **Ist „Mitteilungen aktivieren“ aus:** die drei Ereignisse **ausgegraut** (Deckkraft 0,45), Checkboxen deaktiviert, Zeiger Standard statt Hand; die Vorschau bleibt wirksam.
2. **Technik:** `UNUserNotificationCenter`. **Entscheidung Nutzer 01.10.: Die Berechtigung wird direkt beim ersten Start der App angefragt** (Mitteilungen sind standardmäßig An, der Nutzer ist dann noch aufmerksam). Nicht erneut anfragen, wenn macOS schon entschieden hat; später nur über die Systemeinstellungen änderbar. Wurde sie abgelehnt, zeigt die App einen Hinweis „In den macOS-Systemeinstellungen unter Mitteilungen ändern“ (Link auf die Einstellungen), der Schalter bleibt, es kommt nichts an.
3. **Auslöser:** (a) **Vollständig indiziert** nur, wenn der Lauf **länger als 59 Sekunden** gedauert hat; gilt für Erstlauf **und** für Abgleich/„Neu indizieren“ (der Status bleibt dabei „Online“, nur das Menüleisten-Symbol zeigt den Spinner). (b) **Mit Favoriten angeschlossen:** wenn ein Medium mit mindestens einem Favoriten anschließt (ersetzt die bisherige Einstellung `favoriteOnlineNotificationsEnabled`, Wert übernehmen). (c) **Systemmeldungen:** Indizierungsfehler (`indexStatus = .error` neu) und **Pause abgelaufen** (siehe 68).
4. **Tests:** Hauptschalter aus unterdrückt alle; Ereignis aus unterdrückt nur dieses; Schwelle 59 s (Uhr-Attrappe); Berechtigung abgelehnt zeigt Hinweis; Übernahme des alten Favoriten-Schalters.

---

## 68. Pausieren mit Dauer, Popover am Dropdown (Layout Sektion 03)

**Status:** **Review Claude 02.10.: zurück, Das Popover entspricht nicht dem Layout 03, siehe 77.** Cursor-Stand: Globale Pause in `GlobalPause` (`diskindex.globalPause`). `until == nil` ist für immer. Popover am Schalter „Pausiert“: 30 Minuten, 1 Stunde, Bis morgen (nächster Tag 09:00 Ortszeit), Für immer. „An“ ruft `resumeIndexing`. Ablauf und Aufwachen rufen `refreshGlobalPause`. Pause-Icon statt Spinner in Chip und Menüleiste. Test `RestCoverageTests`.

0. **Es gibt nur die globale Pause** (Layout 21:52: „Global für alle Medien“). Pausen je Medium gibt es nicht (Aufgabe 69). Während der Pause ruht das Indizieren auf **allen** Medien; beim Ende (Zeit oder „An“) läuft es für alle Medien weiter, die **Ja** haben.
1. **Klick auf „Pausiert“** im Dropdown (Menüleisten-Popover) schaltet **nicht** sofort um, sondern öffnet ein **Popover „PAUSIEREN FÜR“** mit **30 Minuten, 1 Stunde, Bis morgen, Für immer**. Erst die Auswahl pausiert. **„An“** setzt sofort fort und löscht die Pause.
2. **Ist schon pausiert**, zeigt das Popover oben **„Pausiert für X“** und die Endzeit **„bis 15:42 Uhr“**; die **aktive Dauer ist ausgegraut**, die anderen **ändern** die Pause („ÄNDERN AUF“). Bei „Für immer“: „Pausiert“ ohne Endzeit.
3. **Popover-Optik:** Pfeil, **derselbe Abstand zum Button wie die Filter-Popover** (Sektionen 08/09). Dazu **Filter-Popover näher am Button** (Abstand wie im Layout). Dunkelblock beachten.
4. **Während der Pause** steht beim indizierenden Medium ein **Pause-Icon statt des Spinners**.
5. **Technik (vom Nutzer bestätigt):** Pause hat ein **Enddatum** (`pausedUntil`, `nil` bei „Für immer“), **überlebt Neustart**. „Bis morgen“ = **nächster Tag 09:00 Uhr** Ortszeit (Entscheidung Nutzer; Anzeige „bis 09:00 Uhr“). Bei Ablauf: Pause endet, laufende Indizierung wird fortgesetzt (Abgleich wie bei Aufheben, Aufgabe 40), und bei aktiver Mitteilung „Systemmeldungen“ erscheint eine Meldung „Automatisches Indizieren wieder aktiv“ (66). Zeitgeber erneut aufbauen beim Start. Wake aus dem Ruhezustand prüft das Enddatum.
6. **Tests:** Auswahl setzt Enddatum (Uhr-Attrappe) und pausiert; „An“ löscht; „Ändern auf“ ersetzt; Neustart behält; Ablauf setzt fort und meldet; „Für immer“ ohne Enddatum; aktive Dauer deaktiviert.

---

## 72. Indizierungsfehler-Modal (Layout Sektion 14, KONZEPT.md 2b)

**Status:** `IndexingFailureDialog` mit „Schließen“ und „Erneut versuchen“. Grundzeile nur bei bekannter `IndexFailureReason`, unbekannt ohne Zeile, kein Pfad. Automatisch höchstens 3-mal je Medium und Stunde (`FailureModalThrottle`). Ein Lauf mit `.error` setzt die Meldung. Test `RestCoverageTests`.

Layout **14 „Indizierungsfehler“** (Hell und Dunkel): Modal und macOS-Mitteilung. Maßgeblich **KONZEPT.md Abschnitt 2b**. **Abweichung Layout 23:09 ↔ Konzept (Nutzerentscheidung 01.10.):** Das Modal hat die Knöpfe **„Schließen“ und „Erneut versuchen“** (nicht „Medium ignorieren“); der Nutzer zieht das Layout nach. Das Modal zeigt zusätzlich eine **Grundzeile**, wenn der Grund bekannt ist.

1. **Auslöser:** Ein Lauf auf einem **angeschlossenen** Medium endet in `.error` (nicht bei Abbruch, Abziehen oder Pause). Ist das **Hauptfenster geöffnet**, erscheint das **Modal** „„<Medium>“ konnte nicht indiziert werden“, darunter „Beim Indizieren ist ein Fehler aufgetreten. Das Medium konnte nicht indiziert werden.“ und, **falls bekannt, eine Zeile mit dem aufbereiteten Grund**. Knöpfe: **„Schließen“** (Standard, Esc) und **„Erneut versuchen“** (**primär**, rechts). Aufbau wie der Erkennungs-Dialog (02).
2. **Grund aufbereitet (`IndexFailureReason`):** Fehler in Kategorien abbilden und in **verständlichem Deutsch** zeigen: Leserechte („Disk Index darf dieses Medium nicht lesen. Das lässt sich in den Systemeinstellungen unter Datenschutz & Sicherheit ändern.“), Verbindung unterbrochen („Die Verbindung zum Medium wurde unterbrochen.“), Zeitüberschreitung („Das Medium reagiert nicht.“), Speicherplatz („Auf diesem Mac ist nicht genug Speicherplatz frei.“), Datenbank („Der Index konnte nicht gespeichert werden.“). **Unbekannt ⇒ keine Grundzeile.** Nie rohe Fehlertexte, Pfade oder Dateinamen im Modal oder in der Mitteilung. Der rohe Fehler geht ins Protokoll (Aufgabe 53/63, ohne Namen im Bericht).
3. **„Erneut versuchen“:** setzt das Medium falls nötig auf **Ja** (Aufgabe 69) und startet den Lauf neu (ab der nächsten Ebene, `completedDepth`). **„Schließen“** lässt den Fehlerzustand **bestehen** (Chip „Fehler“, „!“), bis ein Lauf gelingt oder der Nutzer „Soll indiziert werden“ auf **Nein** setzt (Details 06 oder Einstellungen).
4. **Mitteilung:** Parallel eine macOS-Mitteilung (Ereignis „Systemmeldungen“, Aufgabe 66): Titel „Disk Index“, „„<Medium>“ konnte nicht indiziert werden“, darunter der aufbereitete Grund, sonst „Beim Indizieren ist ein Fehler aufgetreten.“ Klick darauf öffnet das **Hauptfenster mit diesem Dialog**. Ist „Mitteilungen aktivieren“ oder „Systemmeldungen“ aus: keine Mitteilung, Modal bleibt.
5. **Wo das Modal sonst aufgeht:** Klick auf das **„!“** im Menüleisten-Symbol, auf den **Fehlerstatus im Dropdown** und auf den **Chip „Fehler“ im Dashboard** (nur für **angeschlossene** Medien).
6. **Mehrfach und Wiederholung (bestätigt):** Mehrere Fehler zugleich **nacheinander**, eins je Medium. Schlägt „Erneut versuchen“ sofort wieder fehl, erscheint das Modal erneut, aber **höchstens 3-mal je Medium und Stunde** automatisch, danach nur noch über „!“. Ist das **Hauptfenster zu**: nur Mitteilung und „!“, beim nächsten Öffnen **einmal** das Modal, wenn der Fehler noch offen ist.
7. **Tests:** Fehlerlauf löst Modal und Mitteilung aus; „Schließen“ lässt `.error` bestehen, kein erneutes automatisches Modal für denselben Fehler; „Erneut versuchen“ startet neu; kein Modal bei Abbruch/Pause/Abziehen; Fenster zu: nur Mitteilung, beim Öffnen einmal Modal; Wiederholungsdrossel 3 pro Stunde; Klick auf Mitteilung öffnet Fenster mit Dialog; kein Modal und kein „!“ für Offline-Medien; Grundkategorien liefern den Text, unbekannt liefert keine Zeile, kein Pfad im Text.

---



---

## Freigegeben 02.10. (Code-Review Claude; Restarbeiten in Aufgabe 80)

## 63. Fehlerbericht neu: nur Absturz, nur Endpunkt, ohne Namen (Layout Sektion 13)

**Status:** Dialog nur noch „Bericht nicht senden“ und „Bericht senden“, Checkbox „Künftig automatisch senden“ (Standard aus, Schlüssel `diskindex.autoSendCrashReports`). Schema 2 ohne `install` und `namesRedacted`, nur `kind=crash`. `ReportScrubber` ersetzt Namen, Pfade und Suchbegriffe; Prüflauf blockiert Versand bei `/Volumes/`, `/Users/` oder bekannten Namen. Auslöser nur `crash-last.txt` mit `CRASH`; harter Stopp schreibt `previous run ended without clean exit` ohne Dialog. Marker wandert nach `crash-handled/` (höchstens 5). Mail, Diagnosebericht, Tracker-Menü und `kind=error`/`diagnostic` sind aus der Oberfläche. `ReportMail.swift` bleibt ungenutzt von der App, die alten Mail-Tests laufen weiter.

**Entscheidung Nutzer 01.10.:** Es gibt **einen** Weg: Absturzbericht an den Endpunkt, nach Zustimmung im Dialog. Keine Mail, kein Kopieren, kein Ticket, kein Diagnosebericht, keine Fehlerberichte ohne Absturz. **Der Bericht enthält keine Datei- oder Ordnernamen und keine Suchbegriffe**, nur technische Eigenschaften. Layout: Sektion **13 „Error Reporting“** (Hell und Dunkel).

**A. Dialog** ([CrashReportDialog.swift](diskindex/diskindex/Views/CrashReportDialog.swift)), wie Sektion 13, Aufbau wie Erkennungs-Dialog (02), Warn-Icon:
- Titel: „Disk Index wurde unerwartet beendet“
- Text: „Es liegt ein Bericht vor. Er enthält die Programmversion, Informationen zu deinem System, die letzten Aktionen und den Ort des Fehlers. Er enthält keine Datei- oder Ordnernamen und keine Suchbegriffe, nur technische Eigenschaften wie die Länge oder Sonderzeichen.“
- Checkbox **„Künftig automatisch senden“** (Standard aus). Ist sie an, gehen spätere Berichte **ohne Rückfrage** raus (Dialog erscheint dann nicht mehr). **Dieselbe Einstellung** steht in Einstellungen → **Erweitert → „Fehlerberichte“** (Checkbox „Künftig automatisch senden“, Layout 05, Voreinstellung **Aus**) und lässt sich dort wieder ausschalten. „Voreinstellungen anwenden“ setzt sie auf Aus.
- Schaltflächen: **„Bericht nicht senden“** (verwirft den Bericht, schließt den Dialog, löscht ihn aus dem Ausgang) und **„Bericht senden“** (**nur diese ist primär**). Kein „Bericht anzeigen“, kein „Schließen“, kein Schalter „Namen unkenntlich machen“ mehr.
- Erscheint beim nächsten Start nach einem Absturz, einmal je Absturz.

**B. Entfernen:** `ReportMail`/Mail-Versand, Zwischenablage-Kopie, `TicketLink`, „Diagnosebericht kopieren/Per Mail/An Tracker senden“ in Einstellungen und Menüleiste, `DiagnosticMailDialog`, Versand von `kind: diagnostic` und `kind: error`, Drosselung dafür, der Schalter „Dateinamen in Berichten unkenntlich machen“ und „Berichte an den Issue-Tracker senden“ aus den Einstellungen (Layout 05 hat nur die Checkbox „Künftig automatisch senden“ unter „Fehlerberichte“). **Bleiben:** Protokolldatei (lokal), Menüleisten-Eintrag „Protokoll im Finder zeigen“, Ausgang (Outbox) mit Wiederholung und Wiederholungsabstand, Absturzschreiber. Debug-Menü „Absturz testen“ bleibt.

**C. Vertrag, Schema 2 (Nutzer gibt ihn an den Server weiter, genau so):**
```json
{
  "schema": 2,
  "id": "<UUID, Großbuchstaben>",
  "kind": "crash",
  "createdAt": "2026-10-01T14:23:10Z",
  "app": { "version": "1.0", "build": "1", "config": "Release" },
  "system": { "macOS": "15.7.4", "model": "Mac14,2" },
  "runtimeSeconds": 8123,
  "signature": "store/applyDirectories",
  "crash": { "signal": "SIGSEGV", "stack": ["…"] },
  "actions": ["… letzte 50, bereinigt …"],
  "logTail": ["… letzte 100, bereinigt …"],
  "inventory": { "media": 3, "items": 1204331, "dbBytes": 111000000 }
}
```
**Gegenüber Schema 1 entfallen:** `install` (Pseudonym), `namesRedacted`, `kind` `diagnostic`/`error`. Antwort: HTTP 200 und `{"ok":true}`, sonst wie in 61 (5xx/408/429/kein Netz: Wiederholung, übrige 4xx: verwerfen).

**D. Bereinigung (der Kern, vorher Audit):** Kein Name, kein Pfad, kein Suchbegriff und keine Ordner-/Dateiliste darf in `actions`, `logTail`, `signature` oder `crash.stack` stehen. Vorgehen:
1. **Audit:** Alle `DiskIndexLog`-Aufrufe durchgehen (`record`, `ui`, `privateDetail`, `perfIfSlow`). Liste der Stellen mit Nutzertext in den Status (Beispiele: `search query=…`, Namen in `ui`-Zeilen, `reread … privateDetail`, Fehlertexte von `FileManager`/GRDB mit Pfaden).
2. **Berichtsbau schließt aus:** `privateDetail` **nie** in den Bericht. Textfelder mit Nutzerinhalt gehen durch `ReportScrubber`:
   - `‹name chars=12 bytes=18 nf=NFC|NFD|mixed ext=.pdf flags=emoji,rtl,combining,control,trailing-space,leading-dot,invalid-utf8,case-collision›`
   - Suchbegriff: `‹query chars=5 flags=…›`
   - Pfad: `‹path depth=4›`
   - Die **Endung** bleibt lesbar (Dateityp ist technisch), sonst keine Zeichen des Namens. Enthält eine Endung selbst Sonderzeichen, nur `ext=‹odd›`.
   - Fehlertexte: Pfade (alles mit `/Volumes/…`, `/Users/…`, `~`) durch `‹path›` ersetzen, Dateinamen in Anführungszeichen ebenso.
3. **Zeichenprofil statt Name:** Warum: Sonderzeichenfehler (NFD, Emoji, RTL, Steuerzeichen, doppelte Leerzeichen, ungültige UTF-8-Folgen) erkennen wir weiter. Für **Unicode-Skalare** außerhalb Basis-Lateinisch/Ziffern/üblicher Satzzeichen zusätzlich `U+XXXX` **nur der auffälligen Zeichen** (höchstens 5 je Name), nie der gewöhnlichen Buchstaben.
4. **Stapelspur:** enthält Programmsymbole, keine Nutzerdaten (prüfen, `backtrace_symbols_fd` Rohdaten ebenso).
5. **Sicherheitsnetz:** Vor dem Senden läuft ein **Prüflauf** über den fertigen JSON-Text: Enthält er einen Treffer aus den Mustern `/Volumes/`, `/Users/`, `.localized`, eine Zeichenfolge aus den Namen der aktuell indizierten Medien oder ihrer obersten Ordner (Namen aus der Datenbank), wird der Bericht **nicht gesendet**, bleibt lokal, Protokollzeile `report blocked leak=<kategorie>` (ohne den Fund).
6. **Test (wichtig):** Fixture mit Dateinamen `Müller – Übersicht 🎵 (final) .pdf` (NFC), derselbe NFD, ein Name mit RTL-Zeichen, mit Steuerzeichen, Suchbegriff „Steuererklärung 2024“, Pfad `/Volumes/KUNDE/Rechnungen/…`. Alle Aktionen und Fehler mit diesen Namen protokollieren, Bericht bauen: **kein** Fund der Namen im JSON (weder Nfc noch Nfd noch Teilstrings ab 3 Zeichen), aber `nf=NFD`, `flags=emoji` und `ext=.pdf` sind drin. Zweiter Test: Prüflauf blockiert absichtlich eingeschleusten Pfad.

**E. Tests:** Dialogtext und -knöpfe wie Layout (genau zwei Schaltflächen, eine primär), „Künftig automatisch senden“ speichert und sendet beim nächsten Absturz ohne Dialog, „Bericht nicht senden“ löscht den Ausgang, JSON entspricht Schema 2 (Pflichtfelder, keine entfallenen), Wiederholung/Verwerfen wie 61.

**F. Fehler: Dialog erscheint nach jedem Start, egal ob gesendet oder nicht (Nutzer 01.10., Claude hat die Ursache gelesen).** In [DiskIndexLog.swift](diskindex/diskindex/App/DiskIndexLog.swift) `start()` entscheidet die App über die **letzte Zeile des alten Protokolls**: steht dort weder `app terminate ok` noch `app crash reported`, gilt der Lauf als Absturz (`shouldShowCrashDialog = token != signature`, `signature` = diese letzte Zeile). Nach der Bestätigung folgen weitere Zeilen, und jeder **harte Stopp** (Xcode „Stop“, `kill -9`, Programm beenden erzwingen, Stromausfall) hinterlässt wieder eine beliebige letzte Zeile ≠ gemerkte Zeile: Der Dialog erscheint **bei jedem Start danach**. **Soll:**
1. **Nur ein echter Absturz löst den Dialog aus:** Der Absturzschreiber hat im Signal- oder Ausnahmepfad `crash-last.txt` mit `CRASH signal=…` geschrieben. **Nur wenn diese Datei beim Start vorhanden ist und `CRASH` enthält**, erscheint der Dialog (oder bei „Künftig automatisch senden“ geht der Bericht ohne Dialog raus). Ein Lauf ohne `app terminate ok` **ohne** `crash-last.txt` ist ein harter Stopp: nur Protokollzeile `previous run ended without clean exit` (kein Dialog, kein Bericht).
2. **Einmalig:** Sofort nach der Entscheidung („Bericht senden“, „Bericht nicht senden“ oder automatisches Senden) wird `crash-last.txt` **verschoben/gelöscht** (z. B. nach `crash-handled/<Zeitstempel>.txt`, höchstens 5 behalten). Kein Merken über „letzte Zeile“ mehr. Das Löschen geschieht **vor** dem Neuöffnen der Datei im nächsten Lauf (die Datei wird beim Start zum Schreiben geöffnet: erst lesen, dann leeren).
3. **Der Bericht wird aus `crash-last.txt` gebaut**, nicht aus dem Protokollende.
4. **Tests:** (a) `crash-last.txt` vorhanden: Dialog genau einmal, nach „Bericht nicht senden“ beim nächsten Start **kein** Dialog. (b) Kein `terminate ok`, aber auch keine `crash-last.txt` (harter Stopp): **kein** Dialog. (c) Zwei Abstürze nacheinander: zwei Dialoge, je einer. (d) „Künftig automatisch senden“: kein Dialog, Bericht im Ausgang. (e) Xcode-Stop-Szenario: Lauf, Stopp ohne Marker, Neustart: kein Dialog.

**Prüfung durch den Nutzer:** Absturz auslösen (Debug-Menü), neu starten: Dialog wie Sektion 13 in Hell und Dunkel. „Bericht senden“: Datei beim Server mit `schema: 2`, ohne Namen. Danach `grep` im Bericht nach einem bekannten Dateinamen vom Stick: kein Treffer.

---

## 65. Artefakte, Unsichtbares und „Aus dem Index entfernen“ (Layout Sektion 05, README, „Regelliste Artefakte“)

**Status:** `ArtifactRules` und `NamePattern`. `IgnoreMatcher` verbindet Unsichtbar, Artefakte und eigene Muster. Harte Ausschlüsse bleiben. `artifactsIgnored` Standard an, alte Einstellungen bleiben lesbar. `exclusionAddedAt` speichert je Muster den Zeitpunkt. `ExclusionMarks` hält den Treffer 3600 s, danach `startExclusionSweep()` (alle 60 s und nach Neustart) über `purgeSkipped`. Chip entfernen löscht den Stempel, der nächste Scan nimmt den Namen wieder auf. Gelbes `IconProhibit` in Spaltenansicht, Suche und Favoriten. Tests `ArtifactRulesTests`, `RestCoverageTests`.

Quelle: README, „Regelliste Artefakte“ (Stand 01.10., maßgeblich für die Regelliste) und Layout 05 (Tabs „Dateien & Ordner“ und „Erweitert“).

1. **Regelliste im Code** (kein UI): `ArtifactRules` mit den Kategorien 5.1 bis 5.5 der Datei. **Abgleich:** Namen werden **Unicode-klein** (locale-unabhängig, `lowercased()` reicht für v1, keine Sprachregeln) auf **beiden Seiten** verglichen. Zwei Regeltypen: **exakt** und **Muster** (ein `*` nur ganz am Anfang oder ganz am Ende, kein `?`, keine `[]`; Endungs-Muster immer mit Punkt: `*.part` trifft, nicht `*.part*`). Verglichen wird nur der **Name**, nie der Pfad. Gilt für Datei- **und** Ordnernamen; trifft eine Regel einen Ordner, wird der **ganze Teilbaum übersprungen** (nicht betreten, nicht gezählt, keine „übersprungen“-Statistik).
2. **Verhältnis zu „Unsichtbare Dateien“:** zwei unabhängige Filter (Tabelle in Abschnitt 4 der Datei): Unsichtbar aus: alle Punkt-Namen draußen. Unsichtbar an und Artefakte an: Punkt-Namen drin, außer die der Sammlung 5.5. Unsichtbar an, Artefakte aus: alles drin. Ein Element wird ausgelassen, sobald **ein aktiver Filter** es trifft.
3. **Eigene Ausschlüsse addieren sich** (Vereinigung) zu Artefakten. Die Wildcard-Regeln der eigenen Ausschlüsse folgen **derselben** Semantik (heute nur `*.endung` und exakt: auf die Regeln aus 1. erweitern, `.git*`-artiges Präfix-Muster zulassen, `*` in der Mitte weiterhin nicht).
4. **Immer ausgeschlossen (Entscheidung Nutzer 01.10., steht im README (Konzept, „Immer ausgeschlossen“) und **nicht** in der Konzeptdatei):** `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `System Volume Information`, dazu wie bisher im Code `.TemporaryItems`, `.DocumentRevisions-V100` und `._*`. Sie bleiben **unabhängig** von „Unsichtbare Dateien“ und „Artefakte“ ausgeschlossen (Zugriffsfehler, riesige Systembäume, Datenschutz). Die Regelliste `ArtifactRules` enthält sie **nicht** (aus README, „Regelliste Artefakte“ gestrichen). In der Konzeptdatei steht stattdessen `.trash` und `.trash-*` (Linux-Laufwerke).
5. **Ausschluss nachträglich (Layout):** Wird ein Ausschluss hinzugefügt, bleiben bereits erfasste Treffer **noch 1 Stunde** im Index und tragen ein **gelbes Prohibit-Icon** (Rolle `stateIgnored`, Phosphor „prohibit“) neben dem Namen in der Spaltenansicht, Suche und Favoriten. Danach bereinigt die App **automatisch** (Zeitgeber, überlebt Neustart: Zeitstempel je Ausschluss in der Datenbank). Wird ein Chip **entfernt**, werden die betroffenen Dateien **beim nächsten Scan wieder erfasst** (kein sofortiger Scan nötig).
6. **„Aus dem Index entfernen“** (Tab „Erweitert“, schwarze Bestätigungsstufe, siehe 67): entfernt alle erfassten Objekte, die einem **aktuellen** Ausschluss oder Artefaktregel entsprechen, **sofort** (als entfernt markieren, wie Löschungen), anschließend läuft die automatische Bereinigung weiter. Dateien auf den Medien bleiben unberührt. Das ersetzt den leeren Hook `requestIgnoredObjectsPurgeNow()`. **Eigene Ausschlüsse** (Chips unter „Dateien & Ordner“, Rechtsklick „Dateinamen/Dateitypen ignorieren“) bleiben als Funktion **unverändert erhalten**; die Liste ist in der Voreinstellung **leer**.
7. **Nicht umsetzen:** „Ausnahme-Pfad einschließen“ aus der Konzeptdatei (Abschnitt 2) ist im Layout nicht vorgesehen, v1 ohne. Kategorien einzeln abschaltbar: nicht in v1.
8. **Tests (Fixture-Baum mit Fällen aus Abschnitt 5):** je Kategorie mindestens ein Treffer und ein Nicht-Treffer (`*.part` trifft `a.part`, nicht `a.part1.rar`; `.git*` trifft `.gitignore` und `.github`; `.env` bleibt); Großschreibung (`Node_Modules`, `THUMBS.DB`); `Icon\r` mit echtem Wagenrücklauf; Teilbaum eines ausgeschlossenen Ordners wird nicht betreten; Tabelle „Unsichtbar × Artefakte“ in allen vier Kombinationen; harte Ausschlüsse bleiben bei beiden Schaltern aus; 1-Stunden-Frist (mit Uhr-Attrappe) und Entfernen sofort per Schaltfläche.

---

## 67. Bestätigungsmodus: zwei Klicks (Layout Sektion 05)

**Status:** `ConfirmButton` und `ConfirmGate`: erster Klick nur „Bestätigen“, zweiter führt aus, Verlassen und 3 s setzen zurück, Mindestbreite 108. „Vergessen“ in den Medium-Details, „Aus dem Index entfernen“ und „Alle Speichermedien vergessen“ nutzen ihn. Test `ConfirmButtonTests`.

Zwei Stufen, **beide brauchen zwei Klicks**: **Rot** (Daten löschen oder Medien vergessen): „Alle Speichermedien vergessen“ (Erweitert) und „Vergessen“ in den Medium-Details (06). **Schwarz** (nicht kritisch, aber nicht rückgängig): „Aus dem Index entfernen“ (Erweitert). Ablauf: **1. Klick führt nichts aus**, der Button wird **komplett rot gefüllt** und zeigt **„Bestätigen“** (bei **beiden** Stufen rot). **2. Klick** löst die Aktion aus. **Zurück in den Ausgangszustand**, wenn der Zeiger den Button **verlässt** oder **3 Sekunden** ohne Klick vergehen. **Breite bleibt gleich** (Platz für „Bestätigen“ vorab reservieren). Als wiederverwendbare Komponente `ConfirmButton` (rot/schwarz) bauen, bestehende „Vergessen“-Bestätigung ersetzen. Tests: erster Klick löst nichts aus, zweiter schon; Timeout 3 s (Uhr-Attrappe); Verlassen setzt zurück; Breite konstant.

---

## 69. „Indizieren“ Ja | Nein je Medium, Registrierung, Sichtbarkeit, Vergessen, Pause nur global (README.md (Konzept) Abschnitte 2 und 3)

**Status:** `decision` ist `.undecided`, `.index` oder `.dontIndex`. `allowIndexing` wird daraus abgeleitet und beim Schreiben gesetzt. Anschließen legt `.undecided` an und öffnet den Erkennungs-Dialog. Dashboard, Seitenleiste, Suche und Favoriten nutzen `indexedMedia` (`isBrowsable`). Einstellungen zeigen die ganze Registrierung. `MediumChip` ist der einzige Status-Chip. Ja/Nein setzt `decision`. Vergessen löscht die Zeile. „!“ öffnet das Hauptfenster. Test `RestCoverageTests`.

**Maßgeblich: [README.md (Konzept)](README.md (Konzept)) Abschnitt 2 (Medien-Lebenszyklus) und 3 (Pausieren).** Layout 02, 05, 06, 07 zeigen das Aussehen; **bei Widerspruch gilt README.md (Konzept)** (Layout wird vom Nutzer nachgezogen: Filterchip „Pausiert“ entfällt; „Externe Platte 5“ ohne Index steht im Layout in Dashboard 04 und Seitenleiste 07/08, gehört dort nicht hin).

**Soll:**
1. **Pause je Medium entfernen:** `autoIndexPaused` und alle Bedienelemente dafür (Popover, Detail, Tabelle). Pause gibt es nur global (68).
2. **Entscheidung ist `decision`:** `.undecided`, `.index` (= **Ja**), `.dontIndex` (= **Nein**). Das doppelte Feld `allowIndexing` entfällt (abgeleitet), Migration v4: `allowIndexing == false` oder `.dontIndex` ⇒ `.dontIndex`; `autoIndexPaused` wird verworfen.
3. **Sofort registrieren:** Jedes erkannte Medium (Kandidatenregel unverändert) bekommt **sofort beim Anschließen** einen Eintrag mit `.undecided`. Er erscheint **sofort** in **Einstellungen → Speichermedien** (Live-Aktualisierung auch bei **offenem** Einstellungsfenster), Status „Ausstehend“, Auswahl „Indizieren“ **ohne Vorauswahl**, **gleichzeitig** öffnet sich der **Erkennungs-Dialog**. „Indizieren“ ⇒ Ja und Lauf startet, „Nicht indizieren“ ⇒ Nein; „Für dieses Medium merken“ unterdrückt den Dialog für künftige Anschlüsse.
4. **Hat Index** (`hasIndex`): mindestens eine **abgeschlossene Ebene** (`completedDepth ≥ 1`) **oder** mindestens ein nicht entferntes Objekt. **Sichtbarkeit (verbindlich, siehe README.md (Konzept) 2.6):** **Einstellungen → Speichermedien:** alle registrierten Medien. **Dashboard/Übersicht (04), Spaltenansicht-Seitenleiste (07), Suche (Medienkacheln und Medien-Auswahl im Filter-Popover), Favoriten:** nur Medien mit `hasIndex` **und** `decision != .undecided`; **Dashboard-Status nur Online, Offline, x % indiziert, Fehler, nie „Ausstehend“** (README.md (Konzept) 2a). Ein **Fehler ohne Index** erscheint **nicht** im Dashboard; dafür gibt es ein **Fehler-Modal** (vom Menüleisten-„!“), **Layout folgt vom Nutzer, bis dahin nicht bauen** (das „!“ öffnet vorläufig das Hauptfenster). **Dropdown (03):** angeschlossene Medien.
5. **Ja | Nein ändern (06, 05):** **Ja** ohne Index: Erstlauf starten (angeschlossen und nicht global pausiert; sonst „Ausstehend“, startet mit dem Ende der Pause). **Ja** mit Index: Abgleich/Überwachung wieder aufnehmen. **Nein:** laufender Lauf geht auf `pending`, keine Live-Überwachung, kein Abgleich beim Anschließen. **Der vorhandene Index bleibt erhalten, sichtbar und durchsuchbar** (Nutzer: „stoppen heißt nicht löschen oder verstecken“).
6. **Vergessen:** löscht **Registrierung, Index und Favoriten** des Mediums vollständig (`deleteMedium` mit Kaskade, keine Reste wie Kennung, `rememberDecision` oder `isForgotten`-Zeile). Beim **nächsten Anschließen** gilt das Medium als **unbekannt**, es wird neu registriert und der **Erkennungs-Dialog erscheint wieder** (auch wenn „Für dieses Medium merken“ vorher gesetzt war). Test: Medium mit „merken“ und Index, vergessen, erneut „anschließen“ (Attrappe): Dialog erscheint, Status „Ausstehend“. Mit der Pause hat das nichts zu tun (Vergessen = nie gesehen, Pause = nur Indizieren).
7. **Global pausiert und neues Medium:** Registrierung und **Dialog erscheinen trotzdem**. „Indizieren“ ⇒ Ja, der Lauf wartet („Ausstehend“) und **startet automatisch, wenn die Pause endet, sofern das Medium noch online ist** (sonst beim nächsten Anschließen). Die Pause betrifft **nur das Indizieren**: Erkennen, Registrieren und Dialog bleiben unverändert.
8. **Status (README.md (Konzept) 2a, verbindlich): genau ein Chip je Medium, nie zwei.** Texte: angeschlossen und vollständig **„Online“** (grün; nie „Indiziert“), angeschlossen und unvollständig **„x % indiziert“** (grün, gestrichelt, Spinner bzw. Pause-Icon), angeschlossen mit Fehler **„Fehler“** (rot); **nicht angeschlossen** (Index vorhanden): **„Offline“** bei vollständigem Index, **„x % indiziert, offline“** bei unvollständigem Index, **„Fehler, offline“** bei zuletzt Fehler, jeweils **als ein Chip in Offline-Grau, gestrichelt, ohne Fläche**. Zusatzinfos (Dateizahl, „zuletzt gesehen“, „Fehler vor 2 Std. · erneut versuchen“) als **Textzeile**. **Ohne Index:** „Ausstehend“ (offen oder Ja, noch nicht begonnen) oder „Nicht erlaubt“ (Nein), **nur** in Einstellungen → Speichermedien, **nie** im Dashboard. Ein Medium mit Nein **und** Index zeigt den normalen Status, die Entscheidung steht in der Auswahl „Indizieren“. Das Menüleisten-„!“ erscheint nur für **angeschlossene** Medien mit Fehler. **Filterchips: Alle / Indiziert / Offline / Nicht erlaubt**: „Indiziert“ = Index vollständig (online oder offline), „Offline“ = nicht angeschlossen mit Index, „Nicht erlaubt“ = Nein ohne Index; Überschneidung erlaubt.
9. **Medium-Details (06):** „Soll indiziert werden“ Ja | Nein. „Inhalt anzeigen“ **ausgegraut ohne Index**. „Vergessen“ mit Bestätigungsmodus (67).
10. **Menüleisten-Badge (Priorität):** **Fehler „!“** vor **Neu erkannt** vor **Pausiert „X“** (nur globale Pause) vor **Wird indiziert**.
11. **Tests:** Migration deckt Altkombinationen ab; sofortige Registrierung und Live-Zeile bei offenem Einstellungsfenster; `.undecided` erscheint nur in Einstellungen; `.dontIndex` ohne Index nur in Einstellungen; `.dontIndex` mit Index bleibt sichtbar und durchsuchbar, wird nicht aktualisiert; Vergessen löscht alles und führt beim erneuten Anschließen zum Dialog; Pause plus neues Medium: Dialog, Start nach Pause; Badge-Priorität; „Inhalt anzeigen“ ausgegraut ohne Index.

---

## 70. Zuverlässigkeit bei langen Läufen (Nutzer 01.10.: „alles muss zuverlässig bleiben“)

**Status:** 1 Fortschritt: geprüft, Cap 0,99 und Hochwasser in `DirectoryIndexer.note`, Test `IndexRunGuard.nextProgress`. 2 Wiederaufnahme: geprüft, Start bei `completedDepth + 1` (vorher vorhanden). 3 Zeitlimit: geändert, 30 s je Ordner, nach 3 Folgefehlern `pending`, Test `shouldPending`. 4 Datenbank: geändert, `PRAGMA quick_check`, beschädigte Datei nach `index-damaged-<Zeit>.sqlite`, neuer Start legt neu an; Schreibfehler stoppt über `failWrite`; WAL-Checkpoint bei `willSleep`. 5 Ruhezustand: geändert, `heldForSleep` hält den Lauf an, Aufwachen setzt fort. 6 1-Mio-Lauf: Werkzeug `--soak-million` (`SoakProbe`), nicht Teil von `xcodebuild test`. 7 Grundkategorien in `IndexFailureReason`, Test ohne Pfad im Text.

Die Scan-Tiefe 5+ als Standard macht den Erstlauf großer Platten zum Stunden-Vorgang. Prüfen und härten, jeweils **mit Test** (Attrappen, kein echtes Medium nötig):
1. **Fortschritt:** nie fallend, springt nicht auf 100 % vor dem Ende (Cap 99 %), übersteht Pause/Fortsetzen und Neustart der App (Anzeige „x % indiziert“ zeigt nach Neustart den gespeicherten Stand, nicht 0).
2. **Wiederaufnahme nach jedem Abbruch:** Abziehen mitten im Lauf, App-Beenden, Absturz, Ruhezustand/Aufwachen, Medium wird neu eingehängt (neuer Einhängepfad `/Volumes/NAME 1`). Der Lauf setzt bei der **nächsten ungelesenen Ebene** fort (`completedDepth`), nicht bei null; **kein doppeltes Schreiben**, keine Grabsteine für nicht gelesene Ordner.
3. **Hängende Platte:** Ein Lesevorgang, der nicht zurückkehrt (Platte schläft, USB hängt), darf den Lauf nicht für immer blockieren: **Zeitlimit je Ordner** (z. B. 60 s, einstellbar im Code), danach Ordner überspringen und protokollieren, Wiederholung am Ende der Ebene; mehrere Fehler hintereinander: Lauf auf `pending` und Meldung („Medium reagiert nicht“) im Status, **kein** Absturz und **keine** Dauerschleife.
4. **Datenbank:** (a) beim Start `PRAGMA quick_check` (bei Auffälligkeiten `integrity_check` im Hintergrund); ist sie beschädigt, wird sie **nicht gelöscht**, sondern als `index.sqlite.corrupt-<Datum>` beiseitegelegt und neu angelegt, die Medien werden beim Anschließen neu indiziert, Hinweis an den Nutzer. (b) **Voller Datenträger / Schreibfehler:** Lauf stoppt sauber (`pending`/Fehler mit Grund „Speicherplatz“), keine Teil-Transaktion bleibt hängen, Hinweis; nach Freigabe von Platz kann fortgesetzt werden. (c) **WAL-Wachstum:** Checkpoints (`wal_autocheckpoint`/`wal_checkpoint(TRUNCATE)` nach großen Läufen und im Leerlauf), Test dass die WAL nach einem 500 000-Zeilen-Lauf wieder klein wird.
5. **Ruhezustand:** Beim Einschlafen Lauf anhalten (`willSleep`), beim Aufwachen prüfen, ob das Medium noch da ist, dann fortsetzen (Abgleich), kein Fehlerzustand durch Schlaf.
6. **Dauerlauf-Test (Debug-Werkzeug, nicht im normalen Testlauf):** Synthetische Platte (Attrappe) mit 1 Mio. Ordnern, Lauf mit **zufälligen** Abbrüchen (Pause, Abziehen, Neustart der Dienste, Schreibfehler) alle 30 s bis zum Ende. Prüfung am Ende: Zahl der Einträge **identisch** zu einem Lauf ohne Abbrüche, kein Eintrag doppelt, keine Grabsteine, Fortschritt nie rückwärts, Speicher stabil (RAM-Wachstum < 10 %).
7. **Mitteilungen/Statusanzeige** bei Fehlern: ein Lauf, der in `.error` endet, nennt den **Grund** in den Details (Leserechte, Zeitüberschreitung, Speicherplatz, Datenbank) und erscheint als Systemmeldung (66).
8. Ergebnis: im Status je Punkt „geprüft“/„geändert“/„Lücke“ mit Zahlen.

---



---

## Freigegeben 02.10. (79, 80)

## 79. Dashboard-Karten: Fußzeile einzeilig wie im Layout (Claude, 02.10.)

**Status:** Fußzeile wieder einzeilig (`HStack`, Belegung links / „zuletzt gesehen“ rechts), kein `minHeight` 158; `DashboardEqualHeightRow` für gleiche Zeilenhöhe; Raster min. 200 pt. `layout-texte.md` entfernt, `LayoutCopyTests` liest `layout/Disk Index App.dc.html` (Hell-Block, Filter wie zuvor). Kommentare in `LayoutCopy.swift` und `ArtifactRules.swift` angepasst. Screenshots `04-*` und `14-*` in `Werkzeuge/screenshots/2026-10-02/` neu. Unit-Tests grün, Release-Build OK.

Review 78: alles angenommen außer den Dashboard-Karten (04). Layout (`card-meta`): **eine Zeile** „35 % belegt“ links und „zuletzt gesehen: jetzt“ rechts (`justify-content:space-between`, `white-space:nowrap`), Kartenhöhe ergibt sich aus dem Inhalt, **keine Mindesthöhe 158**. Aktuell ist die Fußzeile zweizeilig und die Karte hat eine große Lücke in der Mitte.
1. Kartenmindestbreite so wählen, dass beide Teile der Fußzeile nebeneinander passen (bei Bedarf Raster mit größerer Mindestbreite, höchstens so viele Spalten wie passen), kein Abschneiden.
2. `minHeight` entfernen; Karten einer Reihe gleich hoch und oben bündig (Raster mit gleicher Zeilenhöhe), Offline-Karten ohne Kapazität nur „zuletzt gesehen: …“ allein.
3. **Aufräumen `layout-texte.md`:** Die Datei ist nur ein Auszug aus dem Layout und soll weg. `LayoutCopyTests` liest stattdessen **direkt** `layout/Disk Index App.dc.html` (Sektionen 02, 05, 06, 13, 14; Texte aus den Elementen ziehen, Tags, `{{ }}`, Beispieldaten und Entwicklerblock „BESTÄTIGUNGSMODUS“ ausnehmen; gleiche Regeln wie bisher). Kommentar in `LayoutCopy.swift` anpassen; Kommentar in `ArtifactRules.swift` („konzept-anmerkungen.txt“) auf „README, Regelliste Artefakte“ ändern. Test grün, dann `layout-texte.md` löschen und in `prompt.md` den Verweis in der „Regel“ auf das Layout-HTML ändern.
4. Danach 04 und 14 neu aufnehmen (Hell/Dunkel), Status ausfüllen.

---

## 80. Restarbeiten aus dem Code-Review (Claude, 02.10.)

**Status:** Toten Code entfernt: `ReportMail` + Tests, `SoakProbe`, `ExclusionGrace`/`ExclusionMarks`, `exclusionAddedAt`-Sweep/`purgeSkipped`, `IssueConsent`-Altlasten (nur `autoSend` bleibt), `ReportTarget` in `IssueTracker`. `DiskIndexLog.crashSection` bevorzugt `crash-last.txt`. `ConfirmButton` bestätigt mit `#E04830` / Rand `#B5381F`. `ArtifactRules` ohne `.temporaryitems`/`.documentrevisions-v100`. Tests: `MediumDecisionTests`, Erkennungs-Tests (Vergessen, Pause+Dialog), `crashExcerptPrefersCrashLastFile`; Detail „Inhalt anzeigen“ deaktiviert ohne Index. Unit-Tests grün, Release-Build OK.

Review von 63, 65, 67, 69, 70 per Code und Bildschirmfoto: Verhalten stimmt, die Aufgaben sind archiviert. Übrig bleiben **toter Code** und **fehlende Tests**. Nichts davon ändert das sichtbare Verhalten.

**A. Toten Code entfernen** (jeweils mit Suche belegen, dass nichts mehr darauf zeigt):
1. **Fehlerbericht (63):** `App/ReportMail.swift` (`ReportMail`, `TicketLink`) und `diskindexTests/ReportMailTests.swift` löschen. In `App/IssueTracker.swift`: `enabledKey`, `redactKey`, `installKey` samt `sendingEnabled`, `setSendingEnabled`, `needsConfirmation`, `namesRedacted`, `setNamesRedacted`, `installID`, im `IssueDraft` das Feld `namesRedacted`, im Payload-Bau den Parameter `install`, alle Reste für `kind == "error"` (`limit: … "error"`, `noteError` nur als Protokollzeile behalten oder entfernen, wenn `onTrackedError` nichts mehr braucht). Tests anpassen. Zusätzlich: `DiskIndexLog.crashSection` soll **zuerst `crash-last.txt`** lesen (Spezifikation 63 D.3), das Protokollende nur als Rückfall.
2. **Ausschluss-Fristen (65, überholt durch 74):** `ExclusionGrace`, `ExclusionMarks`, `AppSettings.exclusionAddedAt` (Schlüssel beim Lesen ignorieren, nicht mehr schreiben), `AppState.sweepExpiredExclusions` und die Schreibzugriffe in `toggleIgnoredPatterns` und `SettingsIgnoredObjectsTab` entfernen, ebenso `IndexStore.purgeSkipped`, falls nur dort benutzt, und den Test `exclusionMarkExpiresAfterOneHour`. Maßgeblich ist allein der Mechanismus aus 74 (`IndexSchedule`, `pruneAt`).
3. **Soak-Werkzeug (70):** `SoakProbe` in `App/RestModels.swift` ist nur ein Gerüst ohne Aufrufer. Entfernen (die Leistung ist über `ScaleMeasurementTests` belegt und vom Nutzer abgenommen).
4. `ArtifactRules`: `.temporaryitems` und `.documentrevisions-v100` aus der Liste streichen (stehen in `alwaysSkipped`). Kommentar im Kopf: „Kuratierte Ausschlüsse (README, Regelliste Artefakte, 5.1–5.5)“.
5. **Bestätigungsknopf (67):** Zweiter Klick: Fläche `#E04830`, Rand **`#B5381F`** (Layout „BESTÄTIGUNGSMODUS“), aktuell derselbe Rotton für Fläche und Rand.

**B. Fehlende Tests (69, Punkt 11 der Aufgabe):** Migration der Altkombinationen (`allowIndexing`/Pause) auf `decision`; sofortige Registrierung als `.undecided`; `.undecided` ohne Index nur in den Einstellungen (nicht in Dashboard, Seitenleiste, Suche, Favoriten); `.dontIndex` ohne Index nur in den Einstellungen; `.dontIndex` mit Index bleibt sichtbar und durchsuchbar und wird nicht aktualisiert; Vergessen, danach erneutes Anschließen (Attrappe): Dialog erscheint, Status „Ausstehend“; globale Pause plus neues Medium: Dialog erscheint, Lauf startet erst nach der Pause; Badge-Priorität (Fehler vor Neu erkannt vor Pausiert vor Wird indiziert); „Inhalt anzeigen“ ausgegraut ohne Index.

Danach Debug- und Release-Build ohne Warnung, alle Tests grün, Status ausfüllen.

---



---

## Freigegeben 02.10. (82, am echten Stick bestätigt vom Nutzer)

## 82. Eigentliche Ursache: Datenbank lässt sich nicht öffnen (Claude, 02.10. 17:33, belegt)

**Status (Cursor):** `prepareDatabase` setzt `journal_mode`/`auto_vacuum` nur noch auf **Schreib**-Verbindungen (`!db.configuration.readonly`). Tests: Datei schließen/neu öffnen, parallele Reads, Legacy `auto_vacuum=0` (`installSchemaForTesting`), Fixture 1 Medium + 40 Objekte. Bei `openDefault`-Fehler: Log Kategorie `store`, Dialog + „Erneut versuchen“, Menüleisten-`!`, Mitteilung bei `--background`. Dateien: `IndexDatabase`, `AppDelegate`, `AppState`, `StoreOpenFailureDialog`, `MainWindowHostView`, `LayoutCopy`, `IndexStoreTests`, `MediumDecisionTests`.

Die Korrektur in 81 A (Monitor früher starten) hat das Problem **nicht** gelöst. Neues Protokoll nach dem Neustart um 17:32:

`17:32:24.159 medium error store open SQLite error 8: attempt to write a readonly database - while executing PRAGMA auto_vacuum = INCREMENTAL`

Das ist die Ursache, **warum gar nichts funktioniert**: `IndexStore.openDefault()` wirft, `startMediumRecognition` kehrt zurück, es gibt **keinen Store**, keine Erkennung, keine Indizierung. Der Fehler stand vorher nur im `os_log` und nirgends sichtbar, deshalb kam er im Protokoll nie vor.
1. **Fehler beheben** in `Storage/IndexDatabase.swift`: `configuration.prepareDatabase` läuft für **jede** Verbindung des `DatabasePool`, auch für die **nur lesenden**. `PRAGMA auto_vacuum = INCREMENTAL` (und `journal_mode = WAL`) darf dort nur für den **Schreiber** laufen (z. B. `if !db.configuration.readonly` bzw. in einer Schreibverbindung vor dem Pool, `upgradeAutoVacuum` setzt es für bestehende Dateien ohnehin einmalig). Neue Dateien: das Pragma **vor** dem Anlegen der Tabellen in der Schreibverbindung.
2. **Test, der das fängt** (die vorhandenen Tests haben es nicht gesehen): eine **Datei** im Temp-Ordner (kein In-Memory) einmal anlegen, schließen, **neu öffnen** (bestehende Datei, `auto_vacuum` je 0 und INCREMENTAL), danach **lesen und schreiben** über `IndexStore`. Zusätzlich: Start mit der echten Datei einer Kopie von `~/Library/Application Support/Disk Index/index.sqlite` (Test-Resource, vorher leeren), die schon 1 Medium und 40 Objekte enthält.
3. **Kein lautloses Scheitern mehr:** Scheitert `IndexStore.openDefault()`, schreibt `startMediumRecognition` die **Fehlermeldung in `diskindex.log`** (Kategorie `store`, Level error), zeigt dem Nutzer **einmal** einen Hinweis (Mitteilung oder Hauptfenster: „Die Index-Datenbank konnte nicht geöffnet werden. Disk Index kann Speichermedien derzeit nicht verarbeiten.“ plus Knopf „Erneut versuchen“) und der Menüleisten-Zustand zeigt **„!“**. Nach einem Fehlschlag **nicht** untätig weiterlaufen.
4. Mit dem echten Stick prüfen: **Auswerfen, Einhängen, App starten mit eingehängtem Stick**; erwartete Zeilen in `diskindex.log`: `store open ok`, `eingehängt id=… entscheidung=index`, Abgleich startet. Unter 81 A: Status der Prüfung ergänzen.

---



---

## Freigegeben 02.10. (81, 83; Restpunkte in Aufgabe 84)

## 81. Test am echten Gerät: Medium wird nicht erkannt, Pause-Popover, Szene, Erweitert-Knöpfe (Nutzer 02.10.)

**Status (A, Cursor):** Ursache: Erkennung startete erst nach `loadStoredMedia()`/`refreshVisibleCounts()` (blockierte den Monitor). Fix: `MediumRecognitionStartup.bootstrap` startet Monitor und Change-Loop **sofort**, Medien-Laden asynchron; Zählungen in Hintergrund-Task. Protokoll Kategorie `medium`: `recognition start`, `store open ok`, `monitor started`, `loaded media=`, `event appeared/disappeared`, `candidate=`, Abbruchgründe. Dateien: `MediumRecognitionStartup.swift`, `AppDelegate`, `MediumCoordinator`, `AppState`. Tests: `MediumRecognitionStartupTests`, erweiterte `MediumRecognitionTests` (bekannt/indexiert, pending, unbekannt beim Start). **Am Stick:** bitte Nutzer prüfen — erwartete Logzeilen siehe unten.

**A. Dringend: Das angeschlossene Medium wird von der App nicht verarbeitet.** Befund (von Claude am 02.10. 17:03 geprüft, Debug-App aus Xcode, Prozess seit 16:56):
- Stick „NO NAME“ (FAT32, `/Volumes/NO NAME`) war am Mac **eingehängt**. In der Datenbank steht er seit 30.09. als bekanntes Medium (`decision=index`, `indexStatus=indexed`, 40 Objekte, `lastSeenAt` unverändert 30.09.).
- `~/Library/Logs/Disk Index/diskindex.log` enthält **keine einzige Zeile der Kategorien `medium`, `index`, `store`, `watcher`**, nur `app` und `ui`. Weder beim App-Start (der Stick war schon da: `eingehängt …`/`unbekannt` müsste erscheinen) noch beim **Auswerfen und erneuten Einhängen** (`diskutil unmount` und `mount` um 17:03: keine Zeile `ausgehängt …`, keine Zeile `eingehängt …`). Auch `os_log` (`subsystem xjonx.diskindex`) zeigt außer `IndexDiagnostics` und `ui` nichts, **auch keinen Fehler** `Index konnte nicht geöffnet werden`.
- Die Diagnose-Ansicht **im selben Prozess** erkennt den Stick, liest ihn und scannt ihn (Abschnitte A bis E ohne Fehler, Sandbox aus). Das Betriebssystem liefert also die Ereignisse, Zugriff und Kandidatenregel sind in Ordnung. Die Datenbank ist heil (`quick_check ok`, Migrationen bis `v4-decision`).
- Schluss: **Die Kette `startMediumRecognition` → `coordinator.start(events:)` → `volumeAppeared` läuft in diesem Prozess nicht oder bricht lautlos ab.** Vermutung: das `Task` in `startMediumRecognition` kommt nie bei `coordinator.start` an (z. B. `await appState.loadStoredMedia()`/`refreshVisibleCounts()` hängt oder wirft früh, oder `startMediumRecognition` kehrt vorher zurück). Das ist ein **Fehler seit den letzten Aufgaben (69/70/74/78/80)**, am 30.09. lief die Erkennung.
1. **Reproduzieren und beheben.** Schritt-Protokoll in `diskindex.log` mit Kategorie `medium`: `recognition start`, `store open ok`, `loaded media=<n>`, `monitor started`, je Ereignis `event appeared`/`event willDisappear`/`event disappeared` mit Pfadlänge (kein Pfad im Klartext), `candidate=ja/nein` und bei jedem Abbruch **mit Grund**. Jeder `return` in `startMediumRecognition`, `volumeAppeared`, `connectKnown`, `receiveUnknown` bekommt eine Zeile. **Kein lautloses Verwerfen** mehr.
2. **Alle Wege prüfen** und je Weg einen Test (Attrappe `MediumAccess` und Ereignisse): (a) **unbekanntes** Medium beim Start schon angeschlossen, (b) unbekanntes Medium wird angeschlossen: Eintrag `.undecided`, Dialog, „Indizieren“ startet den Lauf, (c) **bekanntes** Medium (`decision=index`, `indexed`): Abgleich startet, Status Online, (d) bekanntes Medium mit `decision=index`, `pending`: Lauf startet, (e) Auswerfen und erneut Anschließen, (f) Start der App **mit** angeschlossenem Medium, (g) Start der App im Hintergrund (`--background`).
3. Danach am echten Stick prüfen und in den Status schreiben, was in `diskindex.log` stand.

**B. Pause-Popover liegt falsch** (Dark, Nutzer-Screenshot): Es überdeckt die Kopfzeile und den Schalter. Layout 03 (Sektionen „PAUSIEREN — AUSWAHL BEI AN“ und „BEI PAUSIERT“): Popover **unter dem Schalter „Pausiert“, am rechten Rand 16 pt eingerückt, Breite 210 pt, kleiner Pfeil oben rechts (11 pt, Abstand 24 pt vom Rand) nach oben auf den Schalter, ragt unten über das Panel hinaus**; das Panel selbst bleibt unverändert sichtbar (Medien, Schalter, „Disk Index öffnen“). Kopfzeile bei „An“: **„PAUSIEREN FÜR“** (10 pt, Abstand 0,1 em), vier Zeilen 13 pt mit 14 pt Platz links für das Häkchen. Bei „Pausiert“: Kopf **„Pausiert für 1 Stunde / bis 11:04 Uhr“** (12,5 pt fett, darunter Zeit), Trenner, **„ÄNDERN AUF“**, vier Zeilen (aktive mit Häkchen, ausgegraut). Mein Fehler: Auf dem Bildschirmfoto `03-pause-pausiert` lag das Popover **über** den Zeilen und nicht unter dem Schalter, das habe ich fälschlich abgenommen. Fenster-Eigenschaften: Fenster wird größer als das Panel (NSPanel), darf den Bildschirmrand nicht abschneiden.

**C. Szene Hell/Dunkel (Allgemein):** Die Szene sitzt **links neben** dem Segment. Im Layout stehen Segment und Szene **in derselben Spalte linksbündig** (gleiche linke Kante wie das Kästchen „Beim Anmelden starten“, 64 pt Höhe, maximal 260 pt Breite). Aktuell beginnt das Segment weiter rechts als die Szene (Dark-Screenshot: Szene ab x 1167, Segment ab x 1213). Beide an die Spaltenkante setzen. Sonne und Mond (Anker `left`/`top` wie im Layout, Dunkel: Mond bei 46 %, Hell: Sonne bei 22 %, Auto: Sonne 22 %, Mond 76 %) sind in den Werten richtig, nur der Ort der Szene stimmt nicht.

**D. Einstellungen → Erweitert, Knöpfe** (README, Konzept 6: **alle drei** mit Bestätigungsmodus): „Index jetzt bereinigen“ (schwarz), **„Voreinstellungen anwenden“ (schwarz, bisher einfacher Knopf)**, „Alle Speichermedien vergessen“ (rot). Alle drei **gleich hoch und gleich groß gesetzt** (Innenabstand 8/14, Schrift 13 pt fett, Mindestbreite wie das Layout, im Bestätigungszustand **gleiche Breite**); aktuell ist „Voreinstellungen anwenden“ kleiner als die beiden anderen. Der zweite Klick füllt rot (`#E04830`, Rand `#B5381F`) mit „Bestätigen“.

**Tests/Abnahme:** Tests je Punkt A bis D, Debug- und Release-Build ohne Warnung, Bildschirmfotos `03-pause-an`, `03-pause-pausiert`, `05-allgemein`, `05-erweitert` (Hell/Dunkel) neu. **Nutzer prüft am Stick** (A).

---

## 83. Nach der Datenbank-Korrektur: Dashboard mit einem Medium, „Alle vergessen“, Abbruchmeldungen (Claude, 02.10. 17:45)

**Status (Cursor):** (1) Dashboard-Raster: `DashboardGridLayout`, Kartenbreite max. 255 pt, Zeilen linksbündig (`DashboardView`, `DashboardGridLayoutTests`). (2) `ScreenshotPlan`: `04-uebersicht-einzeln`; Ein-Medium-Szenarien in Runner. (3) `ConfirmButton` 240×35, drei Stufen inkl. grün „Bestätigt“, `.contentShape(Rectangle())`; alle vier Knöpfe inkl. Voreinstellungen; `forgetAllMedia()` leert UI sofort + Log `forget all count=`; Systemmitteilungen über `SystemNotice` + `LayoutCopy`-Texte (Schalter Systemmeldungen). (4) `CancellationError` kein Fehler-Log/`onTrackedError`. (5) Pause-Popover unter Panel, 210 pt, Pfeil; Szene/Segment linksbündig 260 pt. Tests: `DashboardGridLayoutTests`, `ConfirmButtonTests`, `forgetAllClearsUIAndDatabase`, `cancellationIsNotOperationalFailure`. Debug/Release-Build grün, 183 Tests grün.

82 ist am Stick bestätigt (Dialog „Neues Speichermedium erkannt“, Lauf, Karte „NO NAME“ Online, 6 Dateien). Neu vom Nutzer:

1. **Dashboard mit nur einem Medium (04):** Die Karte zieht sich über die **ganze Fensterbreite** (Screenshot: 1770 px breit). Karten haben **feste Breite** (Layout: Raster `repeat(auto-fill, minmax(…))`, Karte höchstens so breit wie eine Spalte), unabhängig von der Anzahl. Ursache: `DashboardEqualHeightRow` verteilt die Zeile auf die volle Breite. Karte darf nicht breiter als `gridMaxWidth` (255 pt) werden, Zeile **linksbündig**. Test mit 1, 2, 5 und 9 Medien in 900 und 1400 pt Breite (Karte nie breiter als 255 pt, nie schmaler als die Mindestbreite, Reihen linksbündig). Bildschirmfoto `04-uebersicht-einzeln` (Hell/Dunkel) ergänzen.
2. **„Modal“ bei einem Medium defekt (Nutzer):** Alle Fenster und Dialoge, die ein Medium zeigen, mit **genau einem Medium** prüfen und in `ScreenshotPlan` aufnehmen: Medium-Details (06) mit einem Medium im Hintergrund, Erkennungs-Dialog (02), Fehler-Modal (14), Popover (03). Auffälligkeiten (Höhe, Abschneiden, Überlagerung, falsche Mitte, falsche Breite) beheben und im Status aufführen. Wenn eines davon nicht dem Layout entspricht, **Maße aus dem Layout nennen**, nicht raten.
3. **Bestätigungsknöpfe in Erweitert (belegter Fehler, Nutzer 02.10.):** Klickt man „Alle Speichermedien vergessen“ **am rechten Rand**, passiert nichts; klickt man etwa in der Breite des (roten) „Bestätigen“-Knopfs, geht er auf. Die Klickfläche stimmt also nicht mit der sichtbaren Fläche überein (Knopf ist nur so breit wie sein Text, `.frame(maxWidth: .infinity)` verteilt ihn, die Trefferfläche sitzt woanders). Bei „Voreinstellungen anwenden“ gibt es **gar keine** Bestätigung (einfacher `Button`), „Index jetzt bereinigen“ hat dasselbe Klickproblem. **Neu im README (Konzept 6, Bestätigungsmodus in drei Stufen):**
   - **Alle vier Knöpfe** (`Alle Speichermedien vergessen`, `Vergessen`, `Index jetzt bereinigen`, `Voreinstellungen anwenden`) nutzen **dieselbe** `ConfirmButton`-Komponente: **feste Größe 240 × 35 pt**, **`contentShape(Rectangle())` auf die ganze Fläche**, Breite in allen Stufen gleich.
   - Stufen: 1. Beschriftung (rot umrandet / schwarz umrandet / grau umrandet bei „Voreinstellungen anwenden“), 2. rote Fläche (`#E04830`, Rand `#B5381F`) mit „Bestätigen“, 3. **grüne Fläche** (`#519C61`, Rand etwas dunkler) mit Häkchen **„Bestätigt“** (Phosphor „check“) für 2 s, danach zurück. Zurücksetzen bei Verlassen und nach 3 s nur in Stufe 2, **nicht** während Stufe 3.
   - **Systemmeldung nach Ausführung (vom Nutzer bestätigt 02.10.):** Je nach Knopf wird eine Mitteilung gesendet (`UNUserNotificationCenter`, gleiches Format wie die übrigen Systemmeldungen: Titel „Disk Index“, Text darunter). Sie hängt am Schalter **„Systemmeldungen“** (Erweitert): ist er aus, kommt keine. Ist „Mitteilungen aktivieren“ aus, kommt keine. Texte (in `LayoutCopy`, mit den anderen Mitteilungstexten): „Alle Speichermedien wurden vergessen.“ (Alle Speichermedien vergessen), „Index bereinigt.“ (Index jetzt bereinigen), „Voreinstellungen angewendet.“ (Voreinstellungen anwenden). **Für „Vergessen“ in den Medium-Details keine Mitteilung** (nur die grüne Stufe). Die 59-Sekunden-Schwelle gilt hier nicht. Test: Mitteilung wird bei eingeschaltetem Schalter erzeugt, bei ausgeschaltetem nicht; Texte stimmen.
   - **Alle Speichermedien vergessen** muss die Oberfläche **sofort leeren** (Registry, Dashboard-Leerzustand, Seitenleiste, Suche, Favoriten, Popover), Protokollzeile `forget all count=<n>`. Test: zwei Medien (eins mit Index, eins ohne), Knopf zweimal, Registry, Dashboard und Datenbank leer. Test: Klick an allen vier Rändern und in der Mitte löst aus.
   - Bildschirmfotos aller vier Knöpfe in allen drei Stufen (Hell/Dunkel).
4. **Abbruch ist kein Fehler:** Im Protokoll beim Lauf um 17:38:29: `store error reloadMedium CancellationError()` und `index error favorites CancellationError()` samt `app error index error …`. `CancellationError` (und `Task.isCancelled`) darf **nicht** als Fehler protokolliert werden und nicht `onTrackedError` auslösen (Fehlerzähler, Mitteilung, „!“). Nur echte Fehler zählen.
5. Danach 81 B bis D (Popover, Szene, Erweitert-Knöpfe): Bildschirmfotos für Claude zur Abnahme.

---



---

## Freigegeben 02.10. (84; Rest in 85)

## 84. Abnahme 81/83: Rückschritte im Popover und letzte Abweichungen (Claude, 02.10. 18:05)

**Status (Cursor):** (1) Medienzeilen `.padding(.horizontal, 16)`; Konstanten `panelHorizontalInset`/`footerOpenAppTextInset`. (2) Fußzeile „Disk Index öffnen“: volle Breite, 12/16 pt Innenabstand, ~56 pt Höhe, `MenuBarGhostButton` `.popoverFooter` (12 pt, Radius md). (2b) Pause-Menü als Overlay (`top = Panel − 62 pt`), Fensterhöhe `+ (Menühöhe − 62)`. (3) Segment Dunkel: aktive Schrift weiß. (4) „Alle vergessen“ zweispaltig wie Erweitert. (5) `ScreenshotPlan` + Runner: `05-bestaetigung-*` Stufen 1–3. (6) Screenshots neu: `Werkzeuge/screenshots/2026-10-02/` **94 Dateien**, erzeugt **02.10. 23:51**. Tests: `MenuBarPopoverLayoutTests`; 187 Tests grün; Debug/Release ohne Warnung.

Ich habe die Bildschirmfotos **selbst neu erzeugt** (`Disk Index --screenshots <Ordner>`), weil `Werkzeuge/screenshots/2026-10-02/` nicht aktualisiert war (Stand 16:46, `04-uebersicht-einzeln` fehlte). **In Ordnung:** Dashboard mit einem Medium (Karte 255 pt, linksbündig), Pause-Popover unter dem Schalter (210 pt, Pfeil, Köpfe „PAUSIEREN FÜR“ und „Pausiert für 1 Stunde / ÄNDERN AUF“), Szene und Segment linksbündig in einer Spalte, alle vier Erweitert-Knöpfe 240 × 35, Voreinstellungen mit grauem Rand.

**Rückschritte und Abweichungen (alle beheben):**
1. **Popover-Panel (03): Zeilen ohne Seitenabstand.** Belegt auch an der **echten App** (Nutzer-Screenshot 18:05: Symbol „NO NAME“ halb vom linken Rand abgeschnitten). **Ursache gelesen:** `MenuBarPopoverView.connectedRows` setzt für die Zeilen **keinen** `.padding(.horizontal, 16)` (nur der Leertext und die Überschrift haben ihn), `MenuBarConnectedMediumRow` hat selbst keinen. Fix: `.padding(.horizontal, 16)` auf die Zeilen (Hover-Hintergrund bleibt mit `-6` darüber hinaus, wie bisher). Rechts: „92 %“ bzw. „Neu indizieren“ enden 16 pt vor dem Rand. Test (Layout-Messung): Abstand zwischen Panel-Kante und Symbol = 16 pt, zwischen Zusatz am rechten Rand und Panel-Kante = 16 pt, jeweils mit 1 und mit 4 Medien und im Suchzustand.
2. **Zeile „Disk Index öffnen“ komplett nach Layout 03 (Nutzer: „komplett nicht korrekt“).** Ist: zentriert, Tönung nur 112 pt breit (**Ursache gelesen:** `openAppFooter` ist ein `HStack` ohne Breite, `.background` hängt an der natürlichen Knopfbreite, der Eltern-`VStack` zentriert), Schrift 11 pt, Zeilenhöhe 44 pt. **Soll (aus dem Layout-CSS, `ds-disk-index.css` und Inline-Stil der Zeile):**
   - Zeile über die **volle Panelbreite**, Fläche `text` 4 % (Dunkel gleiche Regel), **Innenabstand 12 pt oben/unten, 16 pt links/rechts**, Inhalt **linksbündig**, **Höhe aus dem Inhalt** (12 + Knopf + 12, Knopf = 14,4 pt Zeile + 2 × 8 pt Abstand + 2 × 1 pt Rand ≈ 32,4 pt → Zeile ≈ **56 pt**, statt `footerOpenAppHeight = 44`; `MenuBarPopoverLayout` entsprechend ändern, `idleFullHeight` und `panelMaxHeight` prüfen).
   - Knopf (`.btn.btn-ghost`): Schrift **12 pt**, Gewicht wie `--font-heading-weight` (semibold), Farbe `text`, **Innenabstand 8 pt vertikal, 4 pt horizontal**, **Radius `md`** (nicht `sm`), 1 pt transparenter Rand; Text beginnt also **20 pt** vom linken Panelrand. Hover: Fläche `accent` 10 %, gedrückt 18 %. Der Knopf hat **keine** dauerhaft sichtbare Fläche.
   - Fix: `HStack { MenuBarGhostButton(…); Spacer(minLength: 0) }` mit `.padding(.horizontal, 16)`, `.padding(.vertical, 12)`, `.frame(maxWidth: .infinity, alignment: .leading)` **vor** `.background`. `MenuBarGhostButton` (Schrift 11 pt, Radius `sm`, 8/4 vertauscht) an die Werte oben anpassen; er wird auch für „Neu indizieren“ in den Zeilen benutzt: dort Layout 03 prüfen und ggf. eine zweite Größe.
   - Test (Messung): Zeilenhöhe, Abstand Textanfang zur linken Kante (20 pt), Tönung füllt die Breite.
2b. **Pause-Popover sitzt an der falschen Stelle (Nutzer: „unter dem Fenster und nicht am Button“).** Layout: Das Popover ist **absolut im Panel-Container** platziert: `right: 16pt; top: calc(100% − 62pt)`, Breite 210 pt, Pfeil `top: −6pt; right: 24pt`. Das heißt: Oberkante **62 pt über der Panel-Unterkante**, also **direkt unter dem Schalter „An | Pausiert“** und **über der Zeile „Disk Index öffnen“**, der Pfeil zeigt auf den Schalter, nur der untere Teil des Popovers ragt über das Panel hinaus. Ist: Das Popover steht **komplett unterhalb** des Panels (neue `VStack`-Zeile mit 8 pt Abstand). Fix: Popover als **Overlay** auf dem Panel (`.overlay(alignment: .bottomTrailing)` mit `.offset`/`.padding(.trailing, 16)`, Oberkante = Panelhöhe − 62 pt), Fensterhöhe des Panels = Panelhöhe + (Popoverhöhe − 62 pt) statt + `pauseMenuExtensionHeight` (224), Hintergrund des Fensters bleibt transparent. Der Pfeil sitzt mittig über dem Schalter (rechts 24 pt). Test/Messung: Oberkante Popover = Unterkante Schalterzeile + (Höhe „Disk Index öffnen“-Zeile − 62 pt), also Abstand zum Schalter ≈ 6 pt; bei „Pausiert“ gleiche Lage. Bildschirmfoto `03-pause-an`/`03-pause-pausiert` zeigen die **Überlappung mit der Zeile „Disk Index öffnen“**.
3. **Allgemein (Dunkel): Segment unlesbar.** Aktives Segment hat graue Fläche **mit dunkler Schrift**. Layout (Dunkel): Fläche `var(--di-sel)` = `#4A4949`, **Schrift `#fff`**, Nicht-aktive Schrift 55 % Text. Hell stimmt (schwarz, weiß).
4. **Erweitert: „Alle Speichermedien vergessen“ liegt am rechten Rand** und die Beschreibung läuft über die ganze Breite. Alle Abschnitte haben **dieselbe zweispaltige Aufteilung**: Text links (bis 50 %), Knopf in der rechten Spalte **an derselben linken Kante wie „Index jetzt bereinigen“ und „Voreinstellungen anwenden“** (x 1158 px im Foto). Warntext „Löscht alle Daten…“ bleibt in der linken Spalte unter der Beschreibung.
5. **Bildschirmfotos für den Bestätigungsmodus fehlen.** In `ScreenshotPlan` je Knopf (Alle Speichermedien vergessen, Vergessen in den Medium-Details, Index jetzt bereinigen, Voreinstellungen anwenden) die **drei Stufen** (1. Klick, 2. Klick rot „Bestätigen“, grün „✓ Bestätigt“) in Hell und Dunkel, Namen `05-bestaetigung-<knopf>-<stufe>-<hell|dunkel>`. Das Werkzeug muss die Stufen **herstellen** (nicht nur den Ausgangszustand aufnehmen).
6. **Ordner `Werkzeuge/screenshots/2026-10-02/` nach jeder Aufgabe vollständig neu erzeugen** (alle Dateien, nicht nur einzelne) und im Status die Uhrzeit der Erzeugung nennen.

Tests wie bisher, Debug- und Release-Build ohne Warnung, alle Tests grün, Status.

---



---

## Freigegeben 03.10. (85, Bildschirmfotos 00:03)

## 85. Letzte Abweichungen im Popover und in Erweitert (Claude, nach Abnahme von 84)

Abnahme 84 (Bildschirmfotos 23:50): bestätigt sind Seitenabstand der Zeilen, Fußzeile „Disk Index öffnen“ (volle Breite, links), Pause-Popover als Überlagerung unter dem Schalter mit Pfeil, Allgemein Dunkel (aktives Segment weiß auf `#4A4949`), Erweitert (alle Knöpfe in der rechten Spalte), alle Stufen des Bestätigungsmodus (rot, grün).

1. **Zeilentext wird jetzt abgeschnitten (Rückschritt durch 84).** „Zuletzt indiziert: heute, 23:…“ und „Kein Zugriff, in den System…“ brechen ab, obwohl Platz ist: `MenuBarConnectedMediumRow.trailingSlotWidth = 108` reserviert die rechte Spalte **immer**. Die Spalte nur reservieren, wenn rechts etwas steht (Fortschritt „92 %“, „Neu indizieren“ bei Hover); sonst nutzt der Text die Breite bis 16 pt vor dem Rand. Hinweis: Das Layout 03 kürzt „Kein Zugriff, in den Systemei…“ erst bei Platzmangel. Test: `Zuletzt indiziert: heute, 23:41` wird vollständig dargestellt.
2. **Popover bei „Pausiert“ in Dunkel: Schalter unlesbar.** In `03-pause-pausiert-dunkel`: das aktive „Pausiert“ hat dunkle Schrift auf grauer Fläche (nicht lesbar). Aktives Segment Dunkel: Fläche `var(--di-sel)` = `#4A4949` **oder** `accent`, **Schrift immer `#fff`** wie bei 05 Allgemein, Hell unverändert (schwarz, weiß). Layout 03 (Dunkel, „Pausiert“-Zustand) gegenlesen und genau diese Werte nehmen.
3. **„Index jetzt bereinigen“: Rand.** Layout (`btn-secondary`, Rand `1px solid var(--color-text)`): **schwarzer** Rand. Im Foto ist der Rand grau. „Voreinstellungen anwenden“ behält den grauen Rand (`neutral-500`), „Alle Speichermedien vergessen“ den roten.

Debug- und Release-Build ohne Warnung, Tests grün, Bildschirmfotos neu (Uhrzeit nennen), Status.

**Status:** (1) `MenuBarConnectedMediumRow`: rechte Spalte (108 pt) nur bei Indizierung oder Hover mit „Neu indizieren“, sonst volle Textbreite. (2) `BinaryButtonGroup`: aktives zweites Segment immer weiße Schrift (`onSelection`); Token `binaryGroupSecondSelected` (Hell neutral-800, Dunkel #4A4949); Popover ohne Hardcode-Fill. (3) `ConfirmButton` `.neutral`: Rand `DesignColor.text` (schwarz/hell im Layout); ungenutzte Variable in `body` entfernt (Release-Warnung). Geändert: `MenuBarConnectedMediumRow.swift`, `BinaryButtonGroup.swift`, `DesignTokens.swift`, `ConfirmButton.swift`, `MenuBarPopoverView.swift`. Screenshots: `Werkzeuge/screenshots/2026-10-02/` (94 PNG), erzeugt **03.10. 00:03**. Debug/Release ohne Compiler-Warnung, Tests grün.

---



---

## Dokumentationsblock 03./04.10. (Cursor, Nutzer-Follow-ups 1–16), von Claude am 04.10. gelesen; Befunde in Aufgabe 90

## Dokumentation (Nutzer-Follow-ups 03.10., ab Pause-Badge-X)

Chronologische Umsetzung ohne neue Aufgabennummer — für Claude-Review und Archiv. Build/Tests jeweils grün, sofern nicht anders vermerkt.

1. **Menüleisten-Badge „Pausiert“ (X auf weißem Kreis):** Im Dunkelmodus war `neutral800`/`text` auf der weißen Badge-Fläche zu hell. Fix: feste Tinte `DesignColor.menuBarBadgeInk` (`#201E1D`) für **X** und **!** in `MenuBarStatusBadgeView.swift`; Token in `DesignTokens.swift`. Konzept in [README.md](README.md) (Menüleisten-Symbol): Badge-Grundfläche weiß, Zeichen nicht an dynamisches `text` koppeln.

2. **Mitteilungen bei Pause (Inhalt, Nutzerklärung):** Kein Banner, wenn macOS Mitteilungen für die App blockiert — Systemeinstellung des Nutzers. Wenn erlaubt: Titel **„Disk Index“**, Texte als volle Sätze (nicht nur „Pausiert“/„Läuft“); Umsetzung über Aufgabe **86 B** (`SystemNotice`, `PauseNoticeCopy`, Schalter „Mitteilungen aktivieren“ + „Systemmeldungen“).

3. **Einstellungen → Erweitert → Mitteilungen (Checkbox-Hierarchie):** „Mitteilungen aktivieren“ oben; die drei **Ereignis**-Checkboxen (Systemmeldungen, vollständig indiziert, Favoriten) **25 pt eingerückt** darunter — nicht auf einer Flucht mit der Haupt-Checkbox. Alle mit `DesignCheckbox()`, `VStack(spacing: 8)`. „Künftig automatisch senden“ (Fehlerberichte) ebenfalls `DesignCheckbox`, ohne Einrückung. Layout-HTML: `padding-left: 25px` bei `notifEvents`. Dateien: `SettingsGeneralTab.swift` (`noticeEventsLeadingInset`), `DesignCheckbox.swift`, `layout/Disk Index App.dc.html`.

4. **BinaryButtonGroup / Selectgroup — Klickfläche inaktives Segment:** Bei `.buttonStyle(.plain)` und transparentem Hintergrund war nur der Text klickbar, nicht die volle Segmentfläche. Fix: `.contentShape(Rectangle())` auf dem Segment-Label nach Padding/Frame. Betroffen: `BinaryButtonGroup.swift` (Popover An/Pausiert, Registry Ja/Nein, Medium-Details). Gleiches Muster in `AppearanceSegmentedControl.swift` (Hell/Dunkel/Automatisch).

5. **Popover Screen 03 — Fuß, Chrome, Abstände (Nutzer 03.10., Layout-Update):** **Äußere Form** (Ruhe + Suche): `MenuBarPopoverChrome` nach `.frame(340×H)` — `DesignRadius.lg` (14 pt), **1-pt-Rand** `DesignColor.divider`, Schatten wie `--shadow-lg` (SwiftUI); AppKit-Dropdown ohne rechteckigen `NSShadow`, `clipsToBounds` am Hosting-View. **Trennlinien** intern: `MenuBarPopoverSeparator` (= voller Divider, nicht 35 %). **Fuß:** `MenuBarPopoverActionFooter` für „Disk Index öffnen“ / „Alle X Ergebnisse“ — 7 %-Band, Button klein rechts, **feste Fußhöhe** (`height`, nicht `minHeight`). **Abstände:** Ruhe-Liste **12 pt** horizontal (`idleContentHorizontalInset`); Kopf/Fuß **16 pt**; Suche Inhalt **16 pt** Padding, Gruppen-Gap **12 pt**; Kategorie-Label **+6 pt** unten; Hover-Zeile **8 %**, 5×6 pt, `margin: 0 -6px`. **Höhen:** Suche **flexibel** nach Trefferzahl (kein `panelMinHeight`-Floor); `searchRowBlockHeight` = Zeile + Padding; Panel-Resize nach async `popoverResults` via `menuBarPopoverLayoutInvalidated`. `searchContentHeight` = SwiftUI-Parität (Label-Zeile 12 pt + 6 pt unten + **6 pt** zum ersten Treffer; Gruppen-`gap` 12 pt). Fuß-Button **26 pt** Inhalt (compact Secondary). **Fix 03.10.:** „Alle N Ergebnisse“ unten abgeschnitten — Formel zu niedrig + Hosting-`clipsToBounds`; Button `.lineLimit(1)`. Dateien: `MenuBarPopoverChrome.swift`, `MenuBarPopoverView.swift`, `MenuBarPopoverSearchContent.swift`, `MenuBarPopoverLayout.swift`, `MenuBarPopoverActionFooter.swift`, `MenuBarController.swift`, `AppState.swift`, `MenuBarPopoverLayoutTests`.

6. **Einstellungen → Erscheinungsbild (Segment + Day/Night-Animation):** Wie Layout HTML: Buttongruppe nur **oben** abgerundet (`UnevenRoundedRectangle`), Animation nur **unten**; **2 px** Abstand; Animation **exakt so breit** wie die drei Segmente (`VStack(spacing: 2)` + `fixedSize(horizontal: true)`), kein fixes 260 pt. Gemeinsamer Randton `sidebarActiveBackground`. Dateien: `AppearanceSegmentedControl.swift`, `DayNightScene.swift`, `SettingsGeneralTab.swift`.

7. **Ausschluss-Chips (`IgnoredPatternChip`) — X-Klickzone:** Klickfläche volle Chip-Höhe, horizontal vom Label bis zum rechten Rand, **Optik unverändert**. `ChipRemoveButton` mit `ChipRemoveHitArea.band` (Abstände 6/10/5 wie zuvor). Datei: `ChipRemoveButton.swift`, `IgnoredPatternChip.swift`.

8. **Filter-Chips (`FilterValueChip`) — X-Klickzone + Text (Nutzer 03.10., mehrere Iterationen):**
   - **Anforderung:** Chip sieht aus wie vorher (8×4 Padding, 4 pt zwischen Text und X, kleines X); Text **nicht kürzen**; Klickfläche des X ein **Quadrat**, **so hoch wie der gesamte Chip** (bis Ober-/Unterrand des Rahmens), rechts am Chip.
   - **Verworfen:** (a) `band` mit `maxWidth: .infinity` neben dem Text → Label wurde in der Filterleiste gestaucht/gekürzt. (b) `squareTrailing` mit X im Layout als breiter Button → fehlendes rechtes Padding, Optik nicht mehr wie der ursprüngliche Chip.
   - **Maßgeblich:** Layout wieder **`HStack(spacing: 4)` + `.padding(.horizontal, 8)` + `.padding(.vertical, 4)`**; sichtbares X nur Dekoration (`allowsHitTesting(false)`); Label **`fixedSize(horizontal: true, vertical: false)`**. Hit-Test **`ChipRemoveSquareHitOverlay`** als `.overlay` auf dem fertigen Chip: `GeometryReader`, unsichtbarer Button, **Seitenlänge = `geo.size.height`**, am **trailing** ausgerichtet. Dateien: `FilterValueChip.swift`, `ChipRemoveButton.swift` (`ChipRemoveSquareHitOverlay`).

9. **Pausentimer & Einstiegskachel (Nutzer 03.10.) — erledigt:** **Einstiegskachel** springt beim Öffnen des Pausentimers nicht (Oberkante fest unter dem Menüleisten-Symbol; kein Overlay/Höhenzuschlag für das Pause-Menü in der Kachel). **Pausentimer** = eigenes **`KeyablePanel`**-Kindfenster (`MenuBarController`, `MenuBarPauseDropdownRoot`, `MenuBarPauseMenuChrome` / `PauseDurationMenu`); Position über **`MenuBarPauseMenuPositioning`** und Toggle-Anker **`PauseToggleAnchorKey`**. **Layout 03:** 210 pt breit, **rechts bündig mit An/Pausiert**, unter dem Schalter (+4/+6 pt), bei Bedarf Flip nach oben; **Nase** im Fenster-Headroom (8 pt), Pfeil 11 pt, abgerundetes Menü (8 pt), Container-Padding 5 pt, Menühöhen 184 / 244 pt; Timer-Zeilen mit Hover und Hand-Cursor. **„Pausiert“-Schalter:** Pausentimer per Klick **toggeln** (`AppState.popoverPauseMenuOpen` allein); **`BinaryButtonGroup.onReselectTrailing`** wenn Segment schon aktiv (Pause läuft); bei **„An“** aktiv öffnet/schließt „Pausiert“ nur das Menü (Pause erst nach Dauerwahl); nach **Zeilenwahl** Menü zu und Segment **Pausiert** aktiv (`pauseIndexing`). **„An“:** `resumeIndexing` + Menü zu. **Fix Toggle (03.10.):** Lokaler Außenklick-Monitor schloss das Menü bei **jedem** Popover-Klick, bevor der Button toggelte → Doppel-Umschaltung / Panel kurz bei `(0,0)`. Klicks auf **An/Pausiert** (`pauseToggleScreenRect`, Anker `BinaryButtonGroup`) vom „Menü schließen“ ausgenommen; Logik `MenuBarPauseToggleLogic.shouldCloseMenuOnPopoverClick`. Escape, Außenklick außerhalb Toggle, Suche schließen Menü. Log `pause toggle click …` / `pause menu open …`. Tests: `MenuBarPauseMenuPositioningTests`, `MenuBarPopoverLayoutTests`, `Task86Tests` (`MenuBarPauseToggleLogic`, inkl. Popover-Klick auf Toggle).

10. **Einheitliche Button-Rahmenstärke (Nutzer 03.10., Code-Audit):**
    - **Maßgeblich:** Alle klickbaren Controls mit sichtbarem Rand nutzen **`DesignBorder.width`** (1 pt, Mockup `border: 1px`) — u. a. `PrimaryAccentButtonStyle`, `SecondaryBorderButtonStyle`, `DestructiveBorderButtonStyle`, `ConfirmButtonStyle`, `BinaryButtonGroup`, `AppearanceSegmentedControl`, Filter-/Chip-Buttons, `RevealInFinderButton`, Detail-Modal-Schließen-Icon.
    - **Korrekturen:** `PauseDurationMenu` (hardcoded `lineWidth: 1` → Token); `DesignCheckbox` (Rand/Fokus 1,5/2 pt → Token); Kontextmenü-Highlight `ObjectFileContextMenu` (2 pt → Token); **`PrimaryAccentButtonStyle`:** `clipShape` **vor** Rand-Overlay, damit der 1-pt-Rand nicht beschnitten wird. Gestrichelte Hilfslinien (`DashedUnderline`, `NoticePreviewCard`) ebenfalls auf Token umgestellt.
    - **Nachziehen (Nutzer Screenshots 03.10.):** `designControlBorder` + `DesignBorder.secondaryControlBorderColor` (`neutral500`) für Sekundär-Buttons, „Hinzufügen“-Zeile, `BinaryButtonGroup`; **`AppearancePickerBlock`** mit **`VStack(spacing: 2)`** und zwei 1-pt-Rändern (kein gemeinsamer Kasten — 2 px Abstand bleibt). Confirm „Voreinstellungen“: Rand `neutral500`; „Index bereinigen“: Rand `text` (Mockup).
    - **Bewusst ohne Rand:** Ghost-/Icon-Buttons (`MenuBarGhostButton`, Toolbar-Navigation/Filter-Icons) — entspricht Mockup `.btn-ghost` / Icon-only. **Keine Button-Ränder:** Spinner (`IndexingSpinnerRing`), Offline-Punkt Spaltenansicht, Häkchen-Strich innerhalb der Checkbox (Innenlinie), Sonnen-Glow `DayNightScene`.

11. **Dock: Hintergrund zuerst, Fenster beim zweiten Klick (Nutzer 03.10.) — erledigt:** **Kaltstart** (Dock/Finder/Spotlight, `.click`) startet nur **Menüleiste + Dienste**, kein Hauptfenster (`AppLaunch.opensMainWindow` nur für `.handoff`); bei `.click` **`NSApp.setActivationPolicy(.regular)`** für sichtbares Dock-Symbol. **Zweiter Dock-Klick** bei laufender Instanz ohne sichtbares Fenster → `applicationShouldHandleReopen` → `openMain`. **Handoff** (Release, zweiter Start) öffnet weiterhin das Fenster. **`AppActivationPolicy.hideDockIconIfMainWindowClosed`** ohne Wechsel zu `.accessory` (Dock bleibt). Index-Store-Fehler beim Kaltstart öffnet weiter das Hauptfenster (nicht bei Login). Konzept [README.md](README.md) §7. Tests: `AppLaunchTests`. Debug/Release-Build grün.

12. **Spaltenansicht — Pfad-Markierung (Nutzer 03.10.):** Fußzeilen-Breadcrumb (`pathStack` + ggf. Datei) stimmte, aber nur die zuletzt geklickte Zeile war dunkel markiert. Fix: `ColumnBrowserSelectionHighlight` markiert zusätzlich jeden Ordner `pathStack[spaltenIndex]` in seiner Spalte (Finder-Parität). Tests: `ProtocolAndSelectionTests.pathStackFoldersStaySelectedInTheirColumn`. README §4 Spaltenansicht.

13. **Spaltenansicht — „Wird indiziert“ vs. Laden großer Ordner (Layout Screen 07, Nutzer 03.10.):** **`ColumnFolderOpenState`** trennt **pendingIndex** (Indizierung läuft, Ebene > `completedDepth`: Zeile ausgegraut, Folgespalte erlaubt, Detail `IndexingFolderDetailChip`) von **uncaptured** (Scan-Tiefe, gelb, keine Folgespalte). **`IndexRepository`:** sequentielles Laden je Ordner (`loadBatchSize` 500, `LIMIT`/`OFFSET` in `IndexStore.children`), Zwischenergebnisse in den Cache, **`isLoading`** → Spaltenkopf `ColumnBrowserColumnHeader` + `LayoutCopy.columnContentsLoading`. Kein 2000er-Abschnitt mehr. Texte `LayoutCopy.indexingInProgress`. README §4. Tests: `indexingFrontierIsPendingNotUncaptured`.

14. **Live-Sync — Medium-Meta, UI, Badge, Watcher (Nutzer 04.10.):** Index-Zähler und Aktivitätszeit bei jedem DB-Schreibvorgang in einer Transaktion (`IndexSQL.commitMediumMeta`); Migration `v5-medium-activity` (`lastIndexActivityAt`). `applyDirectory`/`applyDirectories`/`completeLayer`/Prune emittieren `.counts`. `AppState.flushIndexChange`: `reloadMedium`, debounced Spalten-`invalidate`, `mediumLiveSyncIDs` + Badge `.syncing`. Watcher-Flush in `ChangeWatcherEngine` (actor). Popover-Datum: `lastIndexActivityAt ?? lastIndexedAt`. README Konzept Live-Überwachung. Tests: `LiveSyncMetaTests`. Debug/Release-Build grün.

**Status (14):** Migration v5; `commitMediumMeta` in `IndexStore`/`IndexSQL`; `StoredMedium`/`Medium.lastIndexActivityAt`; `AppState` Live-Sync-Lifecycle + Flush; `MenuBarBadgePreview.syncing` + `MenuBarStatusBadgeView` (blauer Ring); `ChangeWatcherEngine.swift`; `ChangeWatcher` delegiert Flush + syncing-Hooks; `MenuBarConnectedMediumRow` Aktivitätsdatum; `LiveSyncMetaTests`. Kein JSON-Meta-Feld. Unit-Tests grün (04.10.). **Nachziehen 04.10. (Performance Spalten):** Große Ordner: `LazyVStack` + vertikaler Scroll pro Spalte; kein `onChange(of: items.map(\.id))`; Repository publiziert Zwischenstände max. ~350 ms; Spalten-`invalidate` beim Live-Sync debounced (450 ms). **Nachziehen 04.10. (Neustart):** `onReconcileRequested` startet nur noch den Watcher, keinen Indexer; Absturz-Recovery `indexing`→`indexed` wenn `lastIndexedAt` gesetzt. **Nachziehen 04.10.:** Abgleich beim Anschließen `fromScratch: false` (kein `completedDepth`-Reset); Pause-Ende startet nur Watcher, kein zweiter Vollabgleich; `Medium.fileCount` bleibt DB-Gesamtzahl (nicht Scope); `hasIndex`/Chip/Popover-Text bei `pending`+bestehendem Index korrigiert; `scheduleColumnCacheInvalidate` statt sofortigem `invalidate` bei jedem Meta-Tick.

15. **Spaltenansicht — Indizierungs-Spinner in der Medium-Seitenleiste (Nutzer 04.10.):** Während `indexStatus == .indexing` zeigt die Zeile unter „Alle Speichermedien“ statt des Typ-Icons einen **`IndexingSpinnerRing`** in derselben Farbe wie die Icons (`medium.iconColor`, bei Auswahl `onSelection`). `ColumnBrowserRow.showsIndexingSpinner`, `ColumnBrowserView` Sidebar.

16. **Konsolenwarnung Fenster-Wiederherstellung (Nutzer 04.10.):** `Unable to find className=(null)` bei `NSWindowRestoration` — AppKit/SwiftUI-Rauschen (leere `Settings`-Scene + manuelle Fenster). Kein Funktionsfehler. **`NSQuitAlwaysKeepsWindows`**, `applicationSupportsSecureRestorableState` → false, `window.isRestorable = false` in `AppWindowPresenter.register`, `INFOPLIST_KEY_NSQuitAlwaysKeepsWindows`. Fensterposition weiter über `setFrameAutosaveName`.

**Offen für Review:** Ob Claude die Punkte 1–16 freigibt und diesen Block ins Archiv überführt; Aufgabe **86** separat prüfen/archivieren.

---



---

## 86 (04.10.): A und B von Claude per Code geprüft (in Ordnung); C und D (Popover-Flackern, „An“ zweimal) nur Code, am echten Gerät prüft der Nutzer

## 86. Und-Knopf ausblenden, Mitteilungen bei Pause, Popover flackert, „An“ braucht zwei Klicks (Nutzer 03.10.)

**A. Und/Oder-Knopf (`MainWindowFilterBar.combineButton`, README Konzept 5):** nur **sichtbar**, wenn „Und“ wirken kann: Suchbegriff nicht abgeschickt, „Ordner“ nicht gewählt, **und Dateityp-Gruppe und Alter beide gesetzt**. Sonst **ausgeblendet** (nicht ausgegraut, kein Platz in der Leiste). Sichtbar: **inaktiv** (Oder, bisherige Optik ohne blaue Fläche), Klick = aktiv (blau). Wird er unsichtbar, `combineWithAnd` auf `false` zurücksetzen. Tests (Sichtbarkeit je Kombination, Rücksetzen), Bildschirmfotos `08-filter-und-sichtbar`/`-aus` (Hell/Dunkel).

**B. Mitteilungen bei Pause (README Konzept 6, „Mitteilungen bei Pause“):** (a) Pausenbeginn: „Automatisches Indizieren ist pausiert bis HH:mm Uhr.“ bzw. „Automatisches Indizieren ist pausiert.“ (Für immer); (b) Ablauf: bestehender Text; (c) Nutzer schaltet auf „An“: „Automatisches Indizieren ist wieder an.“ Alle über `SystemNotice`, am Schalter „Systemmeldungen“ **und** „Mitteilungen aktivieren“, Texte in `LayoutCopy`. **Keine Doppelmeldung** (Ablauf und manuelles „An“ gleichzeitig nur eine). Mitteilungsvorschau in Erweitert bleibt. Tests (Texte, Schalter, keine Doppelung).

**C. Popover geht „manchmal einfach zu und direkt wieder auf“ (Nutzer, Klick auf das Menüleisten-Symbol).** Nicht reproduziert, Hypothese aus dem Code (`MenuBarController`): Klick auf das Symbol bei **offenem** Popover: `mouseDown` löst `handleOutsideClick` aus (lokaler/globaler Monitor). Liegt der Klick **nicht** im `statusItemScreenRect` (Rechteck ungenau, z. B. wenn `button.window` noch nil, Badge-Overlay, zweiter Bildschirm, Mausposition am Rand), schließt `closePanel()` bei `mouseDown`, danach `mouseUp` → `statusBarButtonClicked` → `isDropdownOpen == false` → `showDropdown` öffnet **neu**. Fix: Klicks auf das Symbol **nie** im Monitor behandeln (immer überspringen, `NSStatusBarButton` über `event.window === button.window` erkennen statt über Bildschirmkoordinaten) **und** nur im `statusBarButtonClicked` umschalten; Öffnen unmittelbar nach Schließen (< 250 ms, Animation) ignorieren (Zustand `isClosing`). Zusätzlich **Protokoll** (`ui`-Zeilen): `statusitem click open=<bool> inside=<bool>`, `outside click close`, `popover open reason=<click|…>`, damit der Fall beim nächsten Auftreten sichtbar ist. Test (Attrappe): schneller Doppelklick, Klick auf Symbol bei offenem Popover = schließt **ohne** Wiederöffnen.

**D. „Automatisches Indizieren: An“ (Pause beenden) musste zweimal geklickt werden (Nutzer).** Teilweise mit Pausentimer-Toggle-Fix (Dokumentation Punkt 9): Außenklick-Monitor schloss das Menü auch bei Klick auf An/Pausiert → erster Klick wirkte oft nur als „Menü zu“. Weiter prüfen am Gerät: `KeyablePanel`/`acceptsFirstMouse`, Rand des Schalters. Protokoll `ui`: `pause toggle click …`. Test: „An“ bei Pausiert (mit/ohne offenes Menü) beendet Pause **beim ersten Mal**.

Debug- und Release-Build ohne Warnung, Tests grün, Bildschirmfotos neu (Uhrzeit nennen), Status.

**Status:** **A:** Link-Button nur bei `isCombineButtonVisible` (Dateityp + Alter, kein Ordner, kein abgeschickter Suchbegriff); ausgeblendet statt ausgegraut; `clampCombineWithAnd` bei Filteränderung. **B:** `SystemNotice` bei Pausenbeginn (`PauseNoticeCopy`/`LayoutCopy`), Ablauf (`previewSystem`), manuelles „An“ (`noticePauseResumedManual`); Ablauf-Task `schedulePauseExpiryCheck`; Doppelung vermieden (`resumeIndexing` nur bei `wasPaused`, `refreshGlobalPause` nur bei echtem Ablauf). `noticesText` → „zu Pausen“. **C:** Statusleisten-Klick per `event.window === button.window`; Reopen-Sperre 250 ms (`MenuBarDropdownLogic`); UI-Logzeilen. **D:** Pause-Menü als `ZStack` (kein Vollflächen-Overlay); `KeyablePanel.sendEvent` macht Panel beim ersten Klick key; Pause-Toggle-Log. Tests: `Task86Tests`, `RestCoverageTests`. Screenshots: `Werkzeuge/screenshots/2026-10-02/` (98 PNG), **03.10. 00:38**. Debug/Release ohne Warnung, Unit-Tests grün.

---



---

## Paket 1 (05.10.), von Claude per Code, Tests und Statuszeilen geprüft

## 100. Tests grün: `hasIndex` zurücknehmen (alt: 90 A)

Stand 05.10.: `xcodebuild test` = **214 bestanden, 2 fehlgeschlagen** (Claude, mit UI-Tests). Zwei Tests schlagen fehl: `RestCoverageTests/undecidedMediumIsHiddenUntilIndexed` und `MediumDecisionUnitTests/dontIndexWithoutIndexIsOnlyInRegistry`. Ursache: `Medium.hasIndex` (`Models/Medium.swift`) zählt seit der Live-Sync-Änderung auch `lastIndexedAt != nil || lastIndexActivityAt != nil`; die Fixture `PreviewData.media[0]` hat diese Felder gesetzt, die Tests setzen nur `completedDepth`/`fileCount` zurück. **Entscheiden und beheben:** (1) fachlich: **„Hat Index“ = mindestens eine abgeschlossene Ebene oder mindestens ein nicht entferntes Objekt** (README 2.6, 2a). `lastIndexedAt`/`lastIndexActivityAt` gehören **nicht** dazu (ein leerer Lauf ist kein Index). `hasIndex` entsprechend zurücknehmen. (2) Danach alle Tests grün, **Regel ab jetzt: Status „Tests grün“ nur mit Zahl (`Executed N tests, 0 failures`) und Uhrzeit**.

Grund der Reihenfolge: Alle weiteren Aufgaben setzen einen **grünen Ausgangsstand** voraus.

**Status (Cursor, 05.10.2026 ~09:25):** `Medium.hasIndex` nur noch `completedDepth >= 1 || fileCount + folderCount > 0` ([Models/Medium.swift](diskindex/diskindex/Models/Medium.swift)). `RestCoverageTests/undecidedMediumIsHiddenUntilIndexed` und `MediumDecisionUnitTests/dontIndexWithoutIndexIsOnlyInRegistry` bestanden im Lauf mit UI-Tests. Gezielter Unit-Lauf: `dontIndexWithoutIndexIsOnlyInRegistry` + `undecidedMediumIsHiddenUntilIndexed` grün. Hinweis: `LayoutCopyTests/windowLinesFromTheLayoutAreInLayoutCopy` und `diskindexUITestsLaunchTests.testLaunch` fielen im Gesamtlauf einmal flaky fehl, Einzellauf LayoutCopy grün — Paket-Gate erneut prüfen.

---

## 101. Datenbank-Zähler nicht mehr O(N) je Schreibvorgang (alt: 90 B1)

**`IndexSQL.commitMediumMeta` zählt bei JEDEM Schreibvorgang das ganze Medium** (`SELECT COUNT(*) … WHERE mediumID=? AND isFolder=… AND removedAt IS NULL`, zweimal) — O(N) je Stapel, **O(N²/5000) für den Lauf** (1 Mio. Einträge: 200 Stapel × 1 Mio. × 2). Beim Watcher kommt das bei **jedem** Ereignisbündel dazu. 

**Fix:** Zähler **inkrementell** (Zuwachs/Abnahme aus `DirectoryWriter.apply`: eingefügt, wieder sichtbar, als entfernt markiert) oder nur bei `completeLayer`/Lauf-Ende/Prune neu zählen und dazwischen Zuwächse addieren. Test mit 200.000 Zeilen (bestehender `insertingTwoHundredThousandEntriesStaysFast` bleibt unter 10 s).

Abnahme: Test mit 200.000 Zeilen und 40 Stapeln; Dauer der Zählung je Stapel konstant (< 5 ms), `index.sqlite`-Zähler stimmen mit `COUNT(*)` nach Lauf-Ende überein (Prüftest nach Hinzufügen, Ändern, Entfernen, Wiederherstellen).

**Status (Cursor, 05.10.2026 ~09:30):** `MediumCountDelta` + inkrementelles `commitMediumMeta` (`MAX(0, fileCount + Δ)`); `DirectoryWriter.apply` liefert Δ (Insert, Wiederherstellung, Entfernung inkl. Unterbaum-Zählung vor `mark`). `forceRecount: true` bei `completeLayer` und Prune. Dateien: [IndexStore.swift](diskindex/diskindex/Storage/IndexStore.swift), Tests [IndexStoreTests.swift](diskindex/diskindexTests/IndexStoreTests.swift) (`mediumCountsStayAccurateWithIncrementalMeta`, COUNT-Check in `insertingTwoHundredThousandEntriesStaysFast`). `IndexStoreTests`: **TEST SUCCEEDED** (~09:30).

---

## 115. Chip-Texte nur nach Layout: „x % indiziert, offline“ fehlt, erfundene Texte entfernen (neu, Nutzer 05.10.)

**Beobachtung (Nutzer):** In den Tests erscheint nie der Chip **„x % indiziert, offline“** (Layout 04 Dashboard, 05 Speichermedien, 06 Details, 15 Styleguide). **Ursache (Code gelesen, `DesignSystem/StatusChip.swift`, `MediumChip.presentation`):** Für `indexStatus == .pending` mit Index gibt der Code **eigene Texte** zurück: **„Wird fortgesetzt“** (angeschlossen) und **„Fortsetzen, offline“** (offline). Beide stehen **nirgends im Layout oder Konzept**. Ein beim Abziehen unterbrochener Lauf ist `pending` und zeigt deshalb nie „x % indiziert, offline“. Dazu kommt: `indexingProgress` wird nicht gespeichert (Aufgabe 105), der Wert wäre nach Neustart 0.

**Soll (README 2a, Layout 04 und 15):** **Genau diese Chip-Texte und keine anderen:** „Online“, „x % indiziert“ (grün, gestrichelt; Spinner nur, solange ein Lauf aktiv ist, Pause-Icon bei Pause), „Fehler“ (rot), „Offline“, „x % indiziert, offline“, „Fehler, offline“ (grau, gestrichelt), „Ausstehend“, „Nicht erlaubt“ (nur Einstellungen). Dazu in der Zählphase „Zählt …“ (Aufgabe 105). Alles andere (auch „Wird fortgesetzt“, „Fortsetzen, offline“) **entfernen**.
1. `MediumChip.presentation`: Zweig für `.pending` entfernen; `.pending` mit Index und unvollständig = **„x % indiziert“** (angeschlossen: Spinner, wenn ein Lauf aktiv ist, sonst gestrichelt ohne Spinner; Pause: Pause-Icon) bzw. **„x % indiziert, offline“**. Prozent aus `Medium.indexProgressPercent` (Aufgabe 105).
2. **Test-Tabelle** `MediumChipTests`: alle Kombinationen aus `connection` (angeschlossen/offline) × `indexStatus` (`pending`, `indexing`, `indexed`, `error`) × `hasIndex` (ja/nein) × `decision` (`undecided`, `index`, `dontIndex`) × Pause (an/aus) mit **erwartetem Text, Farbe, Strich, Spinner**. Zusätzlich ein Test, der **alle Texte** der Ausgabe gegen die erlaubte Liste prüft.
3. **Bildschirmfotos** in `ScreenshotPlan`: Dashboard und Einstellungen → Speichermedien mit allen Zuständen in einer Ansicht (Hell/Dunkel): Online, 92 % indiziert, 45 % indiziert, offline, Offline, Fehler, Ausstehend, Nicht erlaubt.
4. **Abbruchtest:** Lauf starten (Attrappe), mitten im Lauf Medium abziehen → Medium zeigt **„x % indiziert, offline“** mit dem **gleichen** Prozentwert wie vor dem Abziehen.

Debug- und Release-Build ohne Warnung, alle Tests grün (Zahl nennen), Status.

**Status (Cursor, 05.10.2026 ~09:35):** `Medium.indexProgressPercent` / `indexProgressFraction` (Vorstufe 105, `floor`, 100 nur bei `.indexed`). `MediumChip.presentation` ohne „Wird fortgesetzt“/„Fortsetzen, offline“; `.pending` mit Index → Prozent offline/online wie unvollständiger Index. Popover-Zweitzeile: `LayoutCopy.indexingInProgress`. Tests: [MediumChipTests.swift](diskindex/diskindexTests/MediumChipTests.swift) inkl. Allowlist-Muster, Abbruchtest, Floor. **Offen:** ScreenshotPlan-Dashboard-Stati (105/116); Prozent nach App-Neustart → Aufgabe **105**. `MediumChipTests`: **TEST SUCCEEDED** (~09:35).

---

## 116. Chips (Ausschlüsse, Filter, überall) werden nie gekürzt (neu, Nutzer 05.10.)

**Beobachtung (Nutzer):** Die Chips der **eigenen Ausschlüsse** (Einstellungen → Dateien & Ordner) werden gekürzt („…“). **Das darf an dieser Stelle nie sein.** **Ursache (Code gelesen, `DesignSystem/IgnoredPatternChip`, `Views/Search/SearchFilterPopover.FlowLayout`):** Der Chip-`Text` hat kein `fixedSize`, `FlowLayout` misst und platziert mit der Breite des Behälters. Ist ein Muster länger als die verfügbare Breite oder drückt die Klickfläche des X (`ChipRemoveButton`, `.band`) den Text zusammen, kürzt SwiftUI den Text.
1. **Regel (README 10, „Chips“):** **Kein Chip kürzt je seinen Text.** Passt der Text nicht in die Zeile, **bricht der Chip auf die nächste Zeile**; ist der Text **länger als der Behälter**, bricht er **innerhalb des Chips um** (Chip wächst in der Höhe), das X bleibt **oben rechts**. Gilt für **Ausschluss-Chips (gelb)**, **Filter-Chips (blau)**, **Medium-Chips**, **Dateiendungs-Chips** im Filter-Popover, **Statusschips** (Dashboard, Details, Tabelle: bei zu wenig Platz bricht der Text auf zwei Zeilen um, wie „45 % indiziert, offline“ in der Dashboard-Karte schon heute).
2. **Umsetzung:** `Text(pattern).fixedSize(horizontal: false, vertical: true)` mit `lineLimit(nil)` und `multilineTextAlignment(.leading)`; `FlowLayout` begrenzt die Chipbreite auf `bounds.width` (`proposal: ProposedViewSize(width: min(natural, bounds.width), height: nil)`) und misst die Höhe mit dieser Breite; **kein** `lineLimit(1)`, **kein** `truncationMode`, **keine** `frame(maxWidth:)` in Chips. Die Klickfläche des X (`ChipRemoveButton`) darf den Text **nie** verdrängen: Text hat Vorrang (`layoutPriority(1)`).
3. **Test (Messung):** Chips mit 4, 24, 80 und 200 Zeichen in Behältern von 200 und 600 pt: **gerenderter Text = voller Text** (kein „…“), Chip nie breiter als der Behälter, Zeilenumbruch im Chip bei Überlänge. Bildschirmfoto `05-dateien-chips` (Hell/Dunkel) mit einem sehr langen Muster.
4. **Audit:** `grep` nach `lineLimit(1)`, `truncationMode`, `.lineLimit(` in `DesignSystem/*Chip*`, `Views/**/Chip*`, `Views/Search/*`; je Fundstelle begründen oder entfernen (Tabellenzellen und Dateinamen in Spalten bleiben mit Verlauf **laut Layout 07** „blenden per Verlauf aus“, das ist kein Chip).

Debug- und Release-Build ohne Warnung, alle Tests grün (Zahl nennen), Status.

**Status (Cursor, 05.10.2026 ~09:45):** `FlowLayout` misst/platziert mit `ProposedViewSize(width: min(natürlich, Behälter))`; Chips: [IgnoredPatternChip.swift](diskindex/diskindex/DesignSystem/IgnoredPatternChip.swift), [FilterValueChip.swift](diskindex/diskindex/DesignSystem/FilterValueChip.swift), [NeutralFilterChip.swift](diskindex/diskindex/DesignSystem/NeutralFilterChip.swift), [StatusChip.swift](diskindex/diskindex/DesignSystem/StatusChip.swift), [SearchFilterPopover.swift](diskindex/diskindex/Views/Search/SearchFilterPopover.swift) (`FilterTypeChipButton`). Tests: [ChipWrappingTests.swift](diskindex/diskindexTests/ChipWrappingTests.swift) (FlowLayout-Höhe, grep-Audit ohne `lineLimit(1)` in Chip-Dateien). Screenshot `05-dateien-chips`: offen (ScreenshotRunner nicht in Paket-Gate). `ChipWrappingTests`: **TEST SUCCEEDED** (~09:45).

---



---

## 117 (05.10.): Test grün, Texte, Bildschirmfotos geliefert; Befunde aus den Bildschirmfotos in Aufgabe 118

## 117. Paket-1-Abschluss: `LayoutCopyTests` rot, fehlende Bildschirmfotos (neu, Claude 05.10.)

**Befund (Claude, `xcodebuild test`, 05.10., Zahl: 224 bestanden, 1 fehlgeschlagen, `** TEST FAILED **`):** `LayoutCopyTests/windowLinesFromTheLayoutAreInLayoutCopy` schlägt **reproduzierbar** fehl (auch im Einzellauf, auf beiden Testprozessen). Cursor meldete das als „flaky“; es ist **nicht flaky**: Der Test liest das Layout-HTML, und der Nutzer hat das Layout am **05.10. 08:48** überarbeitet (neue und geänderte Texte). Der Test hat seine Aufgabe erfüllt: `LayoutCopy` stimmt nicht mehr mit dem Layout überein.
1. **Fehlende Zeilen ermitteln:** Test laufen lassen, die Meldung `fehlt in LayoutCopy: …` **vollständig** in den Status schreiben (die Ausgabe erscheint im Xcode-Testbericht, nicht in der Konsole; Test `#expect` mit `Comment` ausgeben oder `print` in Debug). Jede Zeile **einzeln** abarbeiten: entweder in `LayoutCopy` ergänzen und in der Oberfläche verwenden, oder (nur wenn die Zeile ausdrücklich nicht in die App gehört, z. B. Beispieldaten) in `exceptions` **mit Begründung** aufnehmen.
2. **Neue Layout-Texte dieser Runde einbauen** (Layout 07, 05.10.): „Der Inhalt dieses Ordners wird wegen der Scan-Tiefe nicht indiziert.“, „Scan-Tiefe ändern“, „Inhalte werden geladen“, „Dieser Ordner enthält sehr viele Objekte. Die Liste erscheint erst, wenn alle geladen sind.“, „… von … Objekten geladen“ (Format mit Punkt als Tausendertrenner, README 10 „Zahlen“, die Abweichung des Layouts bleibt als Ausnahme im Test mit Begründung), Dashboard-/Details-Texte nach Layout 04 und 06.
3. **Bildschirmfotos nachholen** (Paket 1, Cursor meldete sie als offen): `ScreenshotPlan`: Dashboard und Einstellungen → Speichermedien mit allen Chip-Zuständen (Online, 92 % indiziert, 45 % indiziert offline, Offline, Fehler, Ausstehend, Nicht erlaubt), `05-dateien-chips` (sehr langes Muster, Umbruch statt Kürzung). **Und** `Werkzeuge/screenshots/2026-10-02/` vollständig neu erzeugen (Uhrzeit nennen).
4. **Chips (Review 116):** `IgnoredPatternChip` setzt `.frame(maxWidth: .infinity)` auf den Text; die Regel verbot `frame(maxWidth:)` in Chips. Durch `fixedSize(horizontal: false, vertical: true)` mit Breite aus `FlowLayout` ersetzen und nachweisen, dass der Chip im **Filter-Popover und in anderen Behältern** nicht auf volle Breite wächst (Test mit Behälter 600 pt, Chip „*.log“ bleibt schmal).
5. **Kleinigkeit (Review 101):** `IndexSQL.commitMediumMeta` hat vier fast gleiche `UPDATE`-Zweige: auf **einen** Aufbau mit optionalen Spalten reduzieren (Aufgabe 111 erledigt den Rest der Struktur).

Debug- und Release-Build ohne Warnung, **alle** Tests grün (`Executed N tests, 0 failures`, N und Uhrzeit nennen), Status.

**Status (Cursor, 05.10.2026 ~09:55):** (1) `LayoutCopyTests`: fehlende Layout-Zeilen waren Beispielwerte **„Dateien  238 421“** / **„Ordner  12 908“** → `exceptions` im Test; neue Texte in [LayoutCopy.swift](diskindex/diskindex/DesignSystem/LayoutCopy.swift) (Scan-Tiefe-Hinweis, Ladetexte, `folderLoadingProgress`). UI: [UncapturedFolderScanDepthHint.swift](diskindex/diskindex/Views/ColumnBrowser/UncapturedFolderScanDepthHint.swift), Chip über `LayoutCopy`. (2) Screenshots: **102 PNG** je in [Werkzeuge/screenshots/2026-10-05](Werkzeuge/screenshots/2026-10-05) und [2026-10-02](Werkzeuge/screenshots/2026-10-02); Plan erweitert um `04-dashboard-chips`, `05-dateien-chips` ([RestModels.swift](diskindex/diskindex/App/RestModels.swift), [ScreenshotRunner.swift](diskindex/diskindex/App/ScreenshotRunner.swift)). (3) `IgnoredPatternChip`: `.frame(maxWidth: .infinity)` entfernt; Test `shortFilterChipStaysNarrowInWideContainer`. (4) `commitMediumMeta`: ein dynamisches `UPDATE` ([IndexStore.swift](diskindex/diskindex/Storage/IndexStore.swift)). **Tests:** `xcodebuild test` **TEST SUCCEEDED**, UI inkl. (~09:52); **228** `passed on`-Zeilen im Log; Release-Build grün.

---



---

## 118 (05.10.): von Claude geprüft (Test 228 grün, Bildschirmfotos selbst neu erzeugt: *.log einzeilig, Karte ohne „gerade angeschlossen“)

## 118. Paket-1-Nacharbeit aus den Bildschirmfotos (neu, Claude 05.10.)

Grundlage: `Werkzeuge/screenshots/2026-10-05/` (09:48) von Claude angesehen.
1. **Regression Chips: kurze Chips brechen um.** `05-dateien-chips-hell`: Der Chip **„\*.log“ steht in zwei Zeilen („\*.lo“ / „g“)**. Ein **kurzer** Text darf nie umbrechen; Umbruch gilt nur, wenn der Text **breiter als der Behälter** ist. Ursache (Code): `IgnoredPatternChip` mit `Text.fixedSize(horizontal: false, vertical: true)` plus `FlowLayout`, die die Chipbreite mit `.unspecified` misst und dann mit genau dieser Breite neu vorschlägt; die Breite des X-Bereichs (`ChipRemoveButton` `.band`) wird dabei vom Text abgezogen. Fix: **natürliche Breite messen = Text einzeilig + Innenabstand + X**; nur wenn diese **größer als der Behälter** ist, die Behälterbreite vorschlagen. Der lange Chip füllt die Zeile (gewollt, X bleibt oben rechts; im Bild steht das X mittig, **oben** setzen). **Test, der das fängt:** Chip mit „\*.log“ in Behälter 200 und 600 pt: **eine Zeile, Breite = natürliche Breite (±1 pt)**; Chip mit 200 Zeichen: mehrzeilig, Breite = Behälter. Der bisherige Test (`shortFilterChipStaysNarrowInWideContainer`) prüft nur das Filter-Popover und rendert nicht: **mit `ImageRenderer` oder `NSHostingView`-Messung** gegen die Textbreite prüfen.
2. **Dashboard-Karte zeigt „gerade angeschlossen“ (nicht im Layout).** `MediumDashboardCard.metaLine`: für `indexStatus == .pending` steht ein **erfundener Text** „gerade angeschlossen“ (Karte „Foto-SSD“, **offline**, 45 % indiziert). Layout 04: Karten zeigen **nur** `x % belegt` und `zuletzt gesehen: …` (bei Fehler „Fehler vor 2 Std. · erneut versuchen“). **Zweig entfernen**, `pending` verhält sich wie `indexed`/`indexing`.
3. **Die Fußzeile der Karte mit „x % belegt“** und einer Spalte „zuletzt gesehen“ bleibt in einer Zeile (besteht, 118 keine Änderung).
4. **Weitere Texte auf Herkunft prüfen:** Jeder deutsche Text in Karten, Popover, Details, Tabellen, der **nicht aus `LayoutCopy`** kommt und **nicht im Layout steht**, gehört auf eine Liste im Status (Datei, Zeile, Text) und wird **entweder ins Layout-Konzept aufgenommen** (Liste an Claude) **oder entfernt**. Suche: `Text("` mit deutschem Literal in `Views/**`, `MenuBar/**`, `DesignSystem/**`, außer `LayoutCopy.swift`, `EmptyStateCopy`.

Debug- und Release-Build ohne Warnung, alle Tests grün (Zahl nennen), Bildschirmfotos neu (`04-dashboard-chips`, `05-dateien-chips`), Status.

**Status (Cursor, 05.10.2026 ~10:30):** (1) `FlowLayout`: natürliche Chipbreite wenn ≤ Behälter, sonst Umbruch; `ChipRemoveButton` ohne `.frame(maxWidth: .infinity)` — `*.log` einzeilig. Tests [ChipWrappingTests.swift](diskindex/diskindexTests/ChipWrappingTests.swift) mit `NSHostingView`-Messung. (2) [MediumDashboardCard.swift](diskindex/diskindex/Views/Dashboard/MediumDashboardCard.swift): „gerade angeschlossen“ entfernt; Fehler-/Fußzeilen über [LayoutCopy.swift](diskindex/diskindex/DesignSystem/LayoutCopy.swift) (`dashboardErrorRetry`, `dashboardLastSeenPrefix`, `dashboardOccupiedSuffix`). (3) Screenshots [2026-10-05](Werkzeuge/screenshots/2026-10-05) neu. (4) **Text-Audit (noch nicht in LayoutCopy, für Claude/Konzept):** `ColumnBrowserView` — „ALLE SPEICHERMEDIEN“, „Offline — Inhalt aus dem Index…“, „DETAIL“, „Größe gesamt:“, „Geändert:“, „Größe:“, „Zuletzt gesehen:“; `MainWindowFilterBar` — „Filter“; `SearchView` — „Suche läuft…“, Leerzustand-Sätze; `MenuBarPopoverSearchContent` — „Keine Treffer für …“. **`xcodebuild test` TEST SUCCEEDED** (~10:28).

---



---

## 103 (05.10., Claude-Abnahme per Messung am Stick, Release): `lesen bulk=ja`, Erstlauf 30.000 Dateien in 13 s, DB 30.000 = Stick 30.000. Offen aus 103 (Messreihe 1/2/4/8, IsRotational-IOKit) in Aufgabe 108.

## 103. Lesen großer Ordner: `getattrlistbulk` richtig aufrufen (Rest, Review Claude 05.10. 13:50)

**Belegter Fehler (Claude):** `BulkDirectoryReader.readBulk` ruft `getattrlistbulk` **ohne `ATTR_CMN_RETURNED_ATTRS`** auf. Das System antwortet auf **FAT32 und APFS** mit `EINVAL` („Invalid argument“, geprüft mit eigenem Testprogramm); der Code wertet `EINVAL` als „nicht unterstützt“ und fällt **still auf `FileManager` zurück**. Der „echte Bulk-Pfad“ läuft also **nie**, die Tests (APFS-Temp) laufen über den Rückfall und bleiben grün. Damit gilt weiter: **Stick, 14.300er-Ordner kalt: 16 bis 26 s statt 0,25 s** (Messung Claude, Release; `Werkzeuge/benchmarks/getattrlistbulk-bench.swift`).
**Pflicht:**
1. **Aufruf korrigieren:** `commonattr = RETURNED_ATTRS | NAME | OBJTYPE | MODTIME`, `fileattr = DATALENGTH`, Option `FSOPT_PACK_INVAL_ATTRS`. **Satzaufbau je Eintrag (arm64):** `length` (u32) · `attribute_set_t` (20 Byte, aus `RETURNED_ATTRS`) · `name` (`attrreference`, 8 Byte, Name liegt ab `attr_dataoffset` **relativ zur Position der Referenz**) · `objtype` (u32) · `modtime` (`timespec`, **16 Byte**) · `datalength` (u64). Heute liest der Code `tv_nsec` als `Int32` (4 statt 8 Byte) und die Größe von falscher Stelle. **Mit `loadUnaligned`** lesen (nicht `load(as:)`). Nur Felder lesen, die in `returned` gesetzt sind.
2. **`EINVAL` ist ein Fehler, kein „nicht unterstützt“.** Rückfall nur bei `ENOTSUP` (Dateisystem kann es nicht), mit **Protokollzeile** `lesen fallback grund=…`. Je Lesevorgang im Protokoll `lesen bulk=ja|nein`.
3. **Tests, die den Pfad wirklich prüfen:** `ReadStats.usedBulk == true` auf APFS-Temp **und** auf einem **FAT32-Image** (`hdiutil create -fs "MS-DOS FAT32"`, Test legt es an und löscht es); Größe, Änderungsdatum, Typ (Datei/Ordner/Symlink/Paket), versteckt, Namen mit Umlauten und NFD **gleich** wie `stat`/`FileManager` für 2.000 Einträge; `._*` werden verworfen ohne weiteren Aufruf.
4. **Zählphase nur Name + Typ** (eigener Attributsatz ohne Datum und Größe) und eine **Warteschlange mit Index** statt `removeFirst()` (O(n²) bei vielen Ordnern). Die Zählphase **liest dieselben Ordner**: Reihenfolge so, dass der Betriebssystem-Cache der zweiten Phase hilft.
5. **Rest der Spezifikation:** Parallelität nach `isRotational` (IOKit) statt Heuristik, **Messreihe 1/2/4/8** Ordner/s (Formen b und c aus 105) im Status.
6. **Abnahme (Release, Stick `NO NAME`, 30.000 Dateien):** 14.300er-Ordner kalt **≤ 1 s**, Erstlauf **Lesezeit < 20 s**, kein `ordner lesestall`; Zahlen **vorher (Claude-Messung) / nachher** im Status.

Ausführliche Vorgaben und bisheriger Status: Archiv `prompt-spezifikationen-paket2-2026-10-05.md`.

**Status (Cursor 05.10. ~14:45):** `BulkDirectoryReader` — **`ATTR_CMN_RETURNED_ATTRS`** im Aufruf, Parser mit **20-Byte-`attribute_set_t`**, **`loadUnaligned`**, **`timespec` 16 Byte**, **`datalength` u64**, Name relativ zur **`attrreference`**; **`EINVAL` kein Fallback** (nur `ENOTSUP`/`ENOSYS` + `lesen fallback grund=…`, `lesen bulk=ja|nein`). **`BulkDirectoryReadMode.nameAndTypeOnly`** für Zählphase, BFS mit **Index statt `removeFirst`**. **`BulkDirectoryReadStats`**, Tests **`usedBulk`** (APFS + FAT32-Image wenn `hdiutil` geht). **`IndexingVolumeTuning`**: DiskArbitration **„Media Solid State“**. **Offen:** Messreihe 1/2/4/8 Ordner/s, **Release-Stick-Abnahme** (14 300 ≤ 1 s, Erstlauf &lt; 20 s). **`diskindexTests` 222/222** grün (05.10. ~15:05, Debug).

---


---

## Paket 2 Rest (06.10., Claude-Review: 104, 105, 106, 108 abgenommen; Unit-Tests seriell 240 grün; Stick-Messung 05.10. 19:28)

## 104. In Stücken schreiben (Rest: nur Prüfung)

Umgesetzt laut Status (`finalize`-Stücke, 350-ms-Drossel, Abschluss je Ordner). **Offen:** Test „Abbruch mitten in einem Ordner mit 14.300 Einträgen, Fortsetzen: kein Eintrag verloren, kein doppelter, Tombstone erst nach `finalize`“; Test „Meta-Commit höchstens alle 350 ms“.

**Status (Cursor 05.10. ~20:30):** **`LargeFolderIndexingTests`** (`@Suite(.serialized)`): **`abortMidLargeFolderThenResumeWithoutLossOrDuplicates`** (6 100 Dateien, `batchEntryLimit=800`, Halt bei ≥2 500 sichtbaren Einträgen; Fortsetzen ohne Duplikate, ID-Stabilität) und **`tombstoneOnlyAfterFolderFinalize`**; Produkt: **`DirectoryIndexInterrupted`** + Halt zwischen Chunks (`DirectoryIndexer`, `IndexingLimits.batchEntryLimit` variabel). **`metaCommitBatchesRapidChunksUntilFlush`** unverändert. Tests: **248 grün**, 1 übersprungen (20:20).

---
## 105. Fortschritt in Prozent (Rest)

**Grundsatz (README 4, unverändert):** Last = Anzahl der **Einträge** (Dateien und Ordner, nach Ausschlussregeln, ohne `._*`), niemals Ordner; zwei Phasen (Zählen, Indizieren); Fortschritt `min(0,99, gespeichert ÷ max(Gesamt, gespeichert))`, stetig, nie fallend, abgerundet; eine Funktion für alle Anzeigen (`Medium.indexProgressPercent`); „belegt“ ≠ „indiziert“.
**Gebaut:** Zählphase, `scanTotal` (`v6`), Fortschritt nach Einträgen. **Offen:**
1. **Tests (alle mit Attrappe):** 5 Ordner (700, 700, 14.300, 14.300, 1.400) → **mindestens 20 verschiedene Werte, kein Sprung > 5 Punkte**, monoton, 100 nur nach `finishIndexing`; Gesamtzahl wächst: kein Fallen; Wiederholungslauf zeigt **von Anfang an Prozent**; Neustart mit halbem Index: gleicher Wert; Chip, Popover, Dashboard, Details liefern denselben Wert (ein Test über alle); Zählphase schreibt nichts in die Datenbank.
2. **Wiederholungslauf:** gespeicherte `scanTotal` sofort als Schätzung nutzen, Zählen im **Hintergrund** (noch nicht gebaut).
3. **Texte** „Zählt …“ und „Dateien werden gezählt: …“ in `ProposalCopy` (rot) und im Chip/Popover **sichtbar**; Bildschirmfotos der Stufen (Zählt …, 9 %, 47 %, 99 %).
4. **Zählphase billig machen:** siehe 103, Punkt 4 (nur Name + Typ). Heute liest sie jeden Ordner **voll** und damit doppelt so langsam wie nötig.

**Status (Cursor 05.10. ~20:30):** **`StickProgressTests`**: Stick-Attrappe ÷10, `directoryChunkSize=50` im Test für ≥20 Prozentwerte, Monotonie, ≤5-Punkte-Sprünge, Zählphase ohne DB-Wachstum, Wiederholungslauf mit `scanTotal`. **`IndexProgressTests.allSurfacesUseIndexProgressPercent`**. **`ScreenshotRunner`**: `04-dashboard-chips-zaehlt/9/47/99`; PNGs unter `Werkzeuge/screenshots/2026-10-05-fortschritt/`. **Bewusst:** Spec-Punkt „Zählen im Hintergrund bei Wiederholung“ ist im Code (`DirectoryIndexer` Task-Recount), prompt-Zeile 53 war veraltet — README/105.2 bleibt Produkt-Lücke für spätere Aufgabe, nicht Paket-2-Rest.

---
## 106. Immer vollständiger Abgleich (Rest)

**Abgenommen (Claude 19:28, Release, Stick):** Der Abgleich liest jetzt ab Tiefe 1 alles (`abgleich=true start=1`), veralteter Index (1.400) → **30.000 Dateien in 8 s**. **Offen:** (1) `FSEvents`-Resume nur bei gleicher UUID (gebaut, ohne Test); (2) **Abweichung erkannt** (Ereignis für unbekannten Pfad, Lesefehler, `mustScanSubDirs`): Ordner sofort neu lesen, bei Wiederholung das ganze Medium (heute nur Warteschlangen-Retry); (3) Tests: Datei bei ausgeworfenem Stick ändern → nach Anschließen sichtbar; Ordner neu angelegt/entfernt; Abgleich während Pause startet erst danach.

**Status (Cursor 05.10. ~20:30):** **`FSEventsResume.swift`** + **`FSEventsResumeTests`**; Integration **`eventCursorAdvancesAfterWatcherRestart`**. **`ChangeWatcherEngine`**: fehlende Elternzeile → zuerst Parent-Reread, sonst **`needsFullReconcile`**; Tests **`unknownFolderPathTriggersFullReconcile`**, **`newFolderUnderKnownParentAppearsAfterQuiet`**. Stick-Offline-Änderung bleibt manuelle Release-Abnahme (Spec 106.3).

---
## 108. Stresstest-Werkzeug und Abnahme (Rest)

**Status (Cursor 05.10. ~20:30):** Hybrid unter **`Werkzeuge/`**: **`stresstest.sh`** (Orchestrator), **`stress_fill_stick.sh`**, **`stress_verify.sh`**, **`stress_count.sh`**, optional **`stress_fill_form.sh`** (`STRESS_FORM=a|b|c`), Env **`STRESS_BUILD_IMAGE`**, **`STRESS_FILL_STICK`**, **`STRESS_PARALLEL`**. CI-Default: Log-Verify ohne Fill. Abnahme (4)(5)(6) dokumentiert halb-manuell; Vorher/Nachher-Zahlen nur in Skript-Kommentaren, kein hartes Gate.

**Gebaut:** 20.000-Dateien-Rauchtest (< 60 s), `Werkzeuge/stresstest.sh` nur als Gerüst (Protokollprüfung). **Offen:** (1) `stresstest.sh` baut ein **FAT32-Image** (`hdiutil create -size 600m -fs "MS-DOS FAT32" -volname STRESS`), füllt es für die **Formen** (a) 3 × 100.000 Dateien, (b) 100.000 Ordner × 5, (c) 20.000 Ordner × 50 **und** die Stick-Struktur (2 × 14.300 + 2 × 700 + 1 × 1.400, mit `._*`-Begleitdateien wie auf dem echten Stick), hängt ein und gibt `find | wc -l` aus; (2) **6 Abnahmepunkte** aus dem Archiv (Dateizahl DB = Medium, kein Zeitlimit/Lesestall, Dauer unter 60 s, Auswerfen/Anschließen mitten im Lauf, Änderung bei ausgeworfenem Stick, drei Läufe ohne Abweichung); (3) **Vorher/Nachher** mit den Claude-Zahlen (14.300er-Ordner kalt 16 bis 26 s → Ziel ≤ 1 s).

---
