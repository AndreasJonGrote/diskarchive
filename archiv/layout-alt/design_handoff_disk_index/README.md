# Handoff: Disk Index — macOS Menu-Bar App for External Storage Indexing

## Overview
"Disk Index" is a macOS menu-bar app that automatically indexes external storage media (USB sticks, external SSDs/HDDs, SD cards — **not internal drives**) so files can be found even when the media is disconnected. This package documents the full design: the menu-bar icon and its status badges, the click-dropdown, the main app window (dashboard, detail modal, column browser, search), the icon system, and a binding visual styleguide.

## About the Design Files
The files in this bundle (`Catalog App Design.dc.html`, `ds-modernist.css`) are **design references built in HTML** — a single scrollable spec page containing every screen as a static, annotated mockup. They are **not production code to copy directly**. The task is to **recreate these designs in the target codebase's environment** — native SwiftUI/AppKit for a real macOS menu-bar app is the natural choice given the brief (menu bar extra + popover + a full app window), but if the codebase already establishes another stack (e.g. Electron/React), follow that instead. Use the existing app's component/state patterns; treat this HTML only as the visual/behavioral spec.

Note: the HTML file is a single page with all screens stacked vertically, each in its own `<section>`, numbered 00–09 with a `card-kicker` label (e.g. "01 — NEUES SPEICHERMEDIUM & REGISTRY"). Each section also carries a small tag noting whether it is a full **ANSICHT** (view/window content) or a **MODAL** (overlay dialog) — this distinction matters for implementation (views are persistent app-window content; modals are transient overlays with a close affordance).

## Fidelity
**High-fidelity (hifi).** Colors, spacing, typography, icon choices, and interaction states are final. Recreate pixel-accurately using the target platform's native controls (e.g. SwiftUI `Color`, `Font`, `ButtonStyle`) rather than copying HTML/CSS.

## Design System Basis
Built on a design system called "Modernist" (`ds-modernist.css`): flat, architectural, Archivo typeface, but for this app the following overrides are **the source of truth** (see Design Tokens below) — the accent color, corner radius, and border weights were all customized away from that base system's defaults during this project. Follow the values in this README, not the base Modernist defaults.

## Screens / Views

### 00 — Konzept & Ablauf (reference only, not a screen)
A 6-step horizontal flow diagram explaining the product concept. Not a UI screen to build — useful context for the developer:
1. User connects an external storage medium.
2. If unknown, app shows a dialog asking whether to index it (see Screen 01).
3. If allowed, indexing starts and runs continuously while connected (blue = active).
4. Indexing can be paused globally (menu bar / main window) or per-medium.
5. Two search modes: search for a **medium** vs. search for a **file/folder** (with filters).
6. Clicking a search result opens the Column Browser (Screen 06) at the right location — a medium's root, a folder's contents, or a file highlighted among its siblings.

### 01 — Neues Speichermedium & Registry
**Two parts, side by side:**

**A. "Neues Speichermedium erkannt" dialog — MODAL.**
- Small dialog (~300px wide), drive icon (HDD), title, body text: `„Externe Platte 5“ (HDD, 2 TB) wurde angeschlossen. Soll sie indiziert werden?`
- One checkbox: "Für dieses Medium merken" (remember the choice).
- Two buttons: **Nicht indizieren** (secondary, gray border) / **Indizieren** (primary, blue fill, `border-color` one shade darker than the fill — see Button Border Rule below).

**B. Registry table — ANSICHT.**
- Filter chip row above the table: `Alle`, `Indiziert`, `Pausiert`, `Nicht erlaubt` (neutral gray chips).
- Table columns, in order: **Name** (medium name + type icon), **Typ** (USB/SSD/HDD text), **Status** (chip — see Status Chip Colors below), **Indizieren** (Ja/Nein button-group), then a final **unlabeled icon-only column** with a `›` chevron button that opens the Column Browser (Screen 06) for that medium.
- **Name**, **Typ**, and **Indizieren** column headers are sortable (small up/down-arrow icon next to the label, filled with the accent color on the active sort column, muted gray on the others).
- The **Status** and **Indizieren** columns must sit immediately adjacent with no visual gap between them (both right-aligned, touching) — implement via `width: 1%; white-space: nowrap` on both table columns so they shrink to content width instead of the browser's auto-layout stretching a gap between them.
- The last row's bottom border is removed (no divider under the final row).
- Six example rows demonstrate every state: actively indexing, indexed, offline, error, not-allowed, and pending (new/undecided — see Button-Group States below).

### 02 — Menüleisten-Icon (System-UI)
The macOS menu-bar item itself.
- **App icon / menu-bar glyph**: a "stacked disks" icon (Phosphor `hard-drives`, regular/thin weight — never bolded). Rendered as a template icon so macOS tints it automatically for light/dark menu bars.
- **Status badge**: a small circle (≈12–13px) anchored bottom-right of the glyph, white fill, containing one of:
  - **Indiziert** (idle/current) — no badge at all.
  - **Indiziert wird** (actively indexing) — a small spinning ring (CSS border-spinner, accent blue, `border-top-color: transparent`, `animation: spin 0.9s linear infinite`).
  - **Neu erkannt** (new device) — a small solid accent-blue dot, pulsing opacity (`animation: pulse 1.6s ease-in-out infinite`).
  - **Pausiert** — a small **X** icon, drawn as two thin crossed bars (not a bold vector icon — see note below), dark gray/black.
  - **Fehler** — a bold "!" character (not an icon glyph), dark gray/black.
- **Rule**: the main glyph is always regular/thin weight. Only these small status badges may render "thicker" — and even then, the X and "!" are literal thin CSS shapes / text characters, not bold icon paths, per the last round of feedback (a bold vector X read as too heavy).

### 03 — Dropdown (Ansicht, Popover)
The panel shown when the user clicks the menu-bar icon. Two states documented side by side:

**Ruhezustand (idle state):**
- Header row: app glyph + "Disk Index" wordmark + a small search field (fixed 150px) — this is the **compact** search field size (see Design Tokens → Search Fields).
- "ANGESCHLOSSEN" (connected) section listing connected media, each row: type icon, name, and either:
  - an indexing-progress bar (**solid accent blue**, not the storage-fill gradient — this bar means "% of files indexed so far", a different metric from disk-fill capacity) with a clickable percentage/absolute-size toggle (click swaps between "92 %" and "3,77 TB / 4,1 TB"), or
  - a status chip like "Indiziert" / "Index aktuell".
- A hover-state row is shown as its own example: reveals a ghost "Neu indizieren" (re-index) button on the right.
- Footer: "Automatisches Indizieren" label + An/Pausiert button-group (global pause toggle for auto-indexing).
- Bottom bar: a ghost "Disk Index öffnen" button that opens the full app window.

**Während der Suche (while searching):** same panel, but content replaced by top-3 grouped results (Speichermedien / Dateien / Ordner), each file/folder row muted gray, long names truncated with `text-overflow: ellipsis`, and the storage location appended after an en-dash (e.g. `rechnung_2021_q1.pdf – Backup SSD`). A "Alle 9 Ergebnisse anzeigen" button at the bottom opens the full search view (Screen 07).

### 04 — Hauptfenster · Übersicht (Ansicht)
The main app window's dashboard — a macOS window chrome (traffic lights) containing a title bar (app name + a single "Objekte suchen…" search field, standard/wide size, top-right) and a responsive card grid, one card per medium.

Each card: type icon (top-left), status chip (top-right), medium name (bold), one-line spec (`HDD · 4,1 TB · 238 421 Dateien`), a **storage-fill gradient bar** (see Design Tokens → Füllstand-Skala below — this is a *different* bar from the blue indexing-progress bar in Screen 03), and a meta line (`92% belegt · zuletzt gesehen: jetzt`, with the percentage clickable to toggle to an absolute value). Offline cards are dimmed (`opacity: .55`). The error-state card has a red border and a red-tinted "! Fehler" chip.

### 05 — Hauptfenster · Detail-Overlay (Modal)
Clicking a dashboard card opens this modal (white background, not translucent/glassy, sitting over a light gray scrim — not a dark one). A close "✕" icon-button sits top-right.
- Header: type icon, medium name, connection description, and a status chip.
- A small stats table (`Gesamt`, `Belegt / Frei`, `Dateien / Ordner`, `Zuletzt gesehen`, `Zuerst indiziert`) — background tinted very lightly, rounded corners, with a couple of pixels of margin so its border doesn't touch the modal's own edge.
- **All settings live as rows inside this same table** (not separate buttons floating below): "Soll indiziert werden" (Ja/Nein button-group), "Index erneuern" (re-index button), "Medium entfernen" (destructive red "Vergessen" button, red border one shade darker than its text).
- One primary action below the table: **"Index anzeigen"** (opens the Column Browser at this medium's root) — note the label is deliberately *not* "Dateien anzeigen"; that name was rejected as misleading.

### 06 — Hauptfenster · Ordner-Navigation (Ansicht)
A Finder-style multi-column browser for exploring a medium's indexed contents even while it's offline.
- Title bar: traffic lights, app name, a breadcrumb (`Alle Speichermedien / Archiv 2019–2021`), and the **standard-size** "Objekte suchen…" field, top-right (widened to ~280px per feedback).
- Left sidebar (fixed 200px, tinted background, inset shadow to visually separate it as a sidebar): a **small/compact "Medium suchen…" field** (this is the *small* search-field size, distinct from the main search — see Design Tokens), then the full list of media. The active medium row is dark (`#1c1c1e` bg, white text).
- Main area: a horizontally-scrollable row of folder columns (each 180px) leading to a final **Detail column** (200px) showing the selected file's name, modified date, size, last-seen date, and online/offline tag. The whole row has `min-width: 1020px` with `overflow-x: auto` on its parent so columns never get crushed on narrow viewports.
- **Hover affordance**: every dark/active row (in the sidebar's medium list *and* in each folder column) reveals, on hover, a bold white "open in Finder" icon (Phosphor `arrow-square-out`, bold weight) at the row's right edge — shown only for **online** items. If the row's label text is too long, it fades out via a CSS `mask-image: linear-gradient(to right, #000 ~80%, transparent 100%)` against the row's own dark background, rather than a hard ellipsis cut.
- A slim banner above the columns reads "Offline — Inhalt aus dem Index, zum Öffnen bitte anschließen" when the selected medium isn't connected.

### 07 — Hauptfenster · Suche (Ansicht)
The dedicated search screen. **One unified search — no toggle between "media" and "files" modes** (an earlier version had a segmented switch; it was removed because the search is meant to cover everything at once).
- Top row: a **"Filter" button** (funnel icon, violet `#9c27b0`) + active filter chips (violet background/border, e.g. `Ort: Alle Medien ✕`, `Typ: PDF, Text ✕`) + the standard-size "Objekte suchen…" field, right-aligned.
- If the search matches media (not just files), matching media render as small preview **cards above the results table** (same visual language as the Screen 04 dashboard cards, condensed).
- Results table columns: icon, **Name** (sortable, active sort shown in accent blue), **Datum**, **Speichermedium**, **Pfad**, **Status** (right-aligned), then a final unlabeled **"In Spalten anzeigen"** icon-button column (same chevron icon as Screen 01) — always the visually rightmost, touching the Status column with minimal gap, same rule as Screen 01.
- Online items show the same hover-to-open-in-Finder icon described in Screen 06 (not shown here as a permanent icon — it's a hover affordance).

### 07B — Filter-Hover (separate sketch)
**This is deliberately its own standalone mockup, not part of the Screen 07 layout** — it documents what appears when the user hovers the "Filter" button in Screen 07, shown as a popover anchored below/left of a `Filter` button mock with a small CSS-triangle pointer connecting the two. Contains three filter groups side by side:
- **Dateityp**: multi-select chips (PDF/Text/Bild/Video/Audio/Archiv/Ordner), selected chip in violet.
- **Medium**: because the real app may have 20+ media, this is **not a flat static list** — it has its own small search field ("Medium suchen…"), an "Alle Medien" checkbox pinned above, then a **scrollable** checkbox list (`max-height: ~110px; overflow-y: auto`) with a helper caption like "7 von 22 Medien · scrollt". Build this as a searchable, virtualized-if-needed list in the real app.
- **Alter** (age): a flat list of range options (Letzte 24 Stunden / Letzte Woche / Letzter Monat / Letztes Jahr / Älter), active one bold + accent-colored.

### 08 — Icon-Sets (reference)
A legend of every icon used, grouped into three sets — **all in regular/thin weight except Status, which is "dezent fetter" (slightly bolder)**:
- **Speichermedientypen**: `usb` (USB-Stick), `cpu` (SSD), `hard-drive` (HDD).
- **Status**: a CSS spinner ring (Wird indiziert), `check-circle` (Indiziert), a bold "!" character (Fehler), `circle-dashed` (Neu erkannt), a two-bar CSS X (Pausiert).
- **Dateitypen**: `folder`, `file-text` (Dokument), `file-pdf`, `file-image`, `file-video`, `file-audio`, `file-zip` (Archiv), `file-code`, `file-xls` (Tabelle), `file-ppt` (Präsentation), `file` (Sonstige). All from the [Phosphor Icons](https://phosphoricons.com) regular weight.

### 09 — Farbwelt & Designelemente (binding styleguide)
The final reference for color roles, button/chip patterns, search field sizes, and the table rule. Treat every value here as binding for all screens above. See Design Tokens below for the exact values.

## Interactions & Behavior
- **Click** a dashboard/registry percentage (or the dropdown's) toggles its display between a relative `%` and an absolute size (e.g. `92 %` ⇄ `3,77 TB / 4,1 TB`). In the prototype this is a single shared boolean state (`showAbs`) driving every instance at once — in the real app each medium should track this independently, or as a single global display-preference toggle, per product decision.
- **Hover** on a medium row in the dropdown reveals a "Neu indizieren" (re-index) action button.
- **Hover** on any online file/folder/medium row (in the Column Browser's dark/active rows, and implicitly in Search) reveals a bold white "open in Finder" icon at the row's right edge. Offline items never show this icon.
- **Button-group states** (Ja/Nein, An/Pausiert) — see the dedicated rule below; this recurs on every screen with a binary toggle.
- **Sortable table headers**: clicking a sortable column header (small up/down arrow icon) sorts by that column; the active sort column's arrow icon is accent-blue, others are muted gray.
- **Filter chips** are removable via their trailing "✕".
- **Modal close**: Screen 05's overlay has an explicit "✕" icon-button, top-right — modals must always be dismissible this way (distinct from "Ansicht" screens, which are persistent window content with no close action).

## State Management
- `showAbs: boolean` — global percent-vs-absolute display toggle (prototype simplification; consider per-item in production).
- Per medium: `type` (usb/ssd/hdd), `connectionStatus` (connected/offline), `indexStatus` (indexing/indexed/error/pending), `allowIndexing` (boolean, drives the Ja/Nein group), `autoIndexPaused` (boolean, per-medium and global), `capacityUsedPercent`, `lastSeenAt`, `firstIndexedAt`.
- Registry: list of all media ever seen, each carrying the fields above plus a `neverConnectedAgain`-style "forgotten" flag once a user clicks "Medium vergessen".
- Search: `query: string`, `filters: { medium?: string[], fileType?: string[], age?: enum, folderOnly?: boolean }`, `sort: { column, direction }`.
- Column Browser: `selectedMediumId`, `pathStack: string[]` (breadcrumb / open columns), `selectedFileId` (drives the final Detail column).

## Design Tokens

### Colors
| Role | Value | Usage |
|---|---|---|
| Blue (accent) | `#0074e0` | "Indiziert" / active state: chips, buttons, spinners, sort-active icon, indexing-progress bar. Ramp: 100 `#e3f0fd`, 300 `#8ac3f6`, 700 `#004a8f` (text-on-tint / darker border shade), 800 `#073b6c`. |
| Violet | `#9c27b0` | **Exclusively** filter chips + the filter funnel icon. Tint `#f3e0f7`, border `#d9a6e0`, text `#6a1b76`. |
| Dark gray | `--color-neutral-700` / `--color-neutral-800` (`#605d5d` / `#444141`) | "Nein" / off / empty / not-allowed states — never blue. |
| Red | `#e9410c` | Error status only, and the one destructive action ("Medium vergessen"). Tint `#fde3d7`, text `#a52f08`, darker border `#c23709`. |
| Neutral bg/ink | inherited from base Modernist tokens (`--color-bg`, `--color-text`, `--color-surface`, `--color-divider`) | Page/card backgrounds, body text, dividers. |

### Füllstand-Skala (storage-fill gradient — capacity bars only)
A **smooth** (not hard-edged/banded) linear gradient, always starting gray regardless of fill %:
```
linear-gradient(to right, #b8b8b8 0%, #4caf50 20%, #f2c744 50%, #e9410c 90%)
```
Zones: 0–20% gray (empty/low), 20–50% green (healthy), starting at 50% shifts into yellow (caution), starting at 90% shifts into red (critical). This is rendered via a "zoomed" background technique so a bar showing only e.g. 35% fill still starts gray and only reveals the portion of the gradient up to its own percentage:  the fill `<div>` gets `width: {percent}%` and `background-size: {100/percent*100}% 100%` with the gradient above as `background`.
**This gradient is unrelated to the solid-blue indexing-progress bar** used in Screen 03's dropdown (that one is always flat `var(--color-accent)`, no gradient — it means "% of files indexed," not "% of disk full").

### Button-Group / Toggle Rule (Ja/Nein, An/Pausiert)
Always rendered as one connected, touching two-button group (`display:inline-flex; border-radius:6px; overflow:hidden`) — **never** as two separated buttons with a gap. The **group's shared border color reflects only the active option**: blue (`accent-700` border) when the affirmative/"on" option is active, dark gray (`neutral-700` border) when the negative/"off" option is active, plain neutral divider color when neither is chosen yet (pending state). The inactive button inside the group is always plain/transparent — it must never independently show a colored border, and "Nein" specifically must never be blue.

### Status Chip Colors
| Status | Style |
|---|---|
| Wird indiziert … | No background fill, blue border + blue text (`accent-400` border / `accent-700` text), small spinning-ring icon. |
| Indiziert | **Blue background fill** (`accent-100` bg / `accent-800` text / `accent-300` border) — note this is the opposite fill-vs-outline pairing from "Wird indiziert" above; do not swap them. |
| Offline | Gray outline, no fill (`neutral-500` border / `neutral-700` text). |
| Nicht erlaubt | Same gray outline style as Offline. |
| Fehler | Red background fill (`#fde3d7` bg / `#a52f08` text / `#e9410c` border), bold "!" glyph. |
| Ausstehend (new/pending) | Blue **dashed** border, no fill. |

### Search Fields — two fixed sizes, used consistently
- **Objekte-Suche** (object search) — always top-right of any full window/view screen. `padding-left: 34px` (room for a 15px magnifying-glass icon), `font-size: 14px`, width ~220–280px depending on the toolbar. Identical treatment everywhere it appears (Screens 04, 06, 07).
- **Medium-Suche** (medium search) — smaller and more subdued, used only inside sidebars/lists where you're picking a medium (Screen 06 sidebar, Screen 07B's Medium filter group). `padding-left: 24–26px`, `font-size: 11–12px`, `min-height: 22–26px`.

### Typography, Radius, Spacing
Inherited from the base Modernist system (Archivo typeface) with two overrides for this project:
- `--radius-sm/md/lg`: **6px / 8px / 14px** (the base system's default of 0px/sharp corners was overridden — every corner in this app is subtly rounded).
- Border weight: base 2px dividers were thinned to **1px** throughout; adjacent-column table gaps use `width:1%; white-space:nowrap` rather than extra padding.

### Table Rule (binding, all tables)
The last column of any table is always right-aligned, and its content (text, tag, or action buttons) is anchored flush to the right edge — never centered or left-hanging.

## Assets
All icons are from [Phosphor Icons](https://phosphoricons.com) (regular weight, inlined as raw SVG paths — no icon font/webfont dependency, to avoid load-order rendering issues). No other image assets are used; this design uses no photography or illustration.

## Files
- `Catalog App Design.dc.html` — the full design spec, all screens 00–09 in one scrollable page. Open in a browser to review.
- `ds-modernist.css` — the base design-system stylesheet this spec was built on top of (see Design Tokens for the project-specific overrides layered on top of it).
