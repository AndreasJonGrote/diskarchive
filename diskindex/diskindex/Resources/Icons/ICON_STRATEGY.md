# Icon-Strategie

## Entscheidung

- **Phosphor Icons**, Regular Weight (Status-Badges teils SwiftUI-Shapes/Text).
- **Kein Web-Font** — SVG in `Assets.xcassets` mit **Preserve Vector Data** und **Template Rendering** (Menüleiste, Navigation, Dateitypen).
- **Menüleiste:** `MenuBarHardDrives` → `HardDrivesTemplateIcon` (`NSImage`, `isTemplate = true`).
- **Popover-Header:** gleiches Motiv via `HardDrivesGlyph` (Asset-Template).
- **Animierte Badges** (Spinner, X, „!“) bleiben SwiftUI-Shapes in `MenuBarStatusBadgeView`.

## Assets (Aufgabe 10)

| Asset | Phosphor | Verwendung |
|---|---|---|
| `MenuBarHardDrives` | hard-drives | Menüleiste |
| `MediumTypeUSB/SSD/HDD` | usb, cpu, hard-drive | Medientyp |
| `NavHouseLine`, `NavHouseLineDuotone` | house-line (regular / duotone) | Übersicht: inaktiv Kontur, aktiv Duotone schwarz |
| `NavGear` | gear | Einstellungen |
| `IconMagnifyingGlass` | magnifying-glass | Such-Icon Toolbar, leere Suche, Kontextmenü |
| `IconArrowSquareOut` | arrow-square-out (bold) | Kontextmenü „Im Finder anzeigen“ |
| `IconFileMagnifyingGlass`, `IconProhibit`, `IconCheck` | file-magnifying-glass, prohibit, check | Kontextmenü |
| `NavCaretRight` | caret-right | Registry-Chevron |
| `IconFunnel` | funnel | Filter (violett in Search) |
| `IconCheckCircle`, `IconCircleDashed` | check-circle, circle-dashed | Status-Referenz / spätere Chips |
| `FileType*` | folder, file-* | `FileTypeIcon` — Objektzeilen in Suche, Favoriten, Spaltenansicht, Popover |
| `NavBookmarks`, `NavBookmarksDuotone` | bookmarks-simple (regular / duotone) | Favoriten-Navigation: inaktiv Kontur, aktiv Duotone violett |
| `IconBookmarkSimple`, `IconBookmarkSimpleDuotone` | bookmark-simple (regular / duotone) | Favorit am Objekt (nicht markiert / markiert) |
| `IconFadersHorizontal` | faders-horizontal | Details/Regler (Einstellungen → Speichermedien) |

Quell-SVGs zusätzlich unter `Resources/Icons/` als Referenz (Export aus [phosphor-icons/core](https://github.com/phosphor-icons/core)).
