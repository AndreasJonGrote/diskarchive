# Disk Archive — Konsistenz-Audit

Stand 2026-10-08. Grundlage: `App: Layout.dc.html` (Source of Truth, seit 2026-10-31 aufgeteilt in `App-Layout …`). Die Maße des Soll-Zustands stehen im Komponentenkatalog `App: Komponenten.dc.html`.

## Gefunden und bereinigt

| Bereich | Vorher | Jetzt |
|---|---|---|
| Schriftgrößen | 9 / 10 / 10,5 / 11 / 11,5 / 12 / 12,5 / 13 / 14 | 10 · 11 · 12 · 13 · 14 (+ Überschriften, Icons) |
| Gaps | 2 / 4 / 5 / 6 / 7 / 8 / 9 / 10 / 14 px | Skala 2 · 4 · 6 · 8 · 12 · 16 · 24 · 32 |
| Radien | 8 px / 10 px / 14 px hart, daneben Tokens | nur `--radius-sm/md/lg` (6/8/14) |
| Buttons | 5 Größen, uneinheitliche Rahmen | groß (14 px, 10/18) und klein (12 px, 4/12), 1 px, Sekundär grau |
| Selectgroups | Höhe wich vom kleinen Button ab | Zeilenhöhe 1,2, Padding 4/12, gleiche Höhe wie Button klein |
| Chips | 9/10/11 px | 10 px, Padding 3/10 |
| Grau | `oklch(0.66 0 0)` und `0.62 0` | nur `oklch(0.62 0 0)` |
| Begriffe | „Im Finder zeigen“ und „anzeigen“ | „Im Finder anzeigen“ |
| Lange Namen | „…“ und Verlauf gemischt | Verlauf, Tooltip mit vollem Namen |
| Zahlen | Leerzeichen als Tausendertrenner | Punkt |

## Bewusst unterschiedlich (dokumentiert)

- **Mikro-Radien** 1–3 px bei Checkbox, Fortschrittsbalken und Cursor-Marker.
- **Statusfarben** als feste Werte: Rot `#E04830` / `#B5381F`, Gelb `#EDA12D`, Grün-Bestätigt `#2E9E5B` / `#237A46`. Im Dark Mode ist Rot `oklch(0.70 0.17 35)`.
- **Kombi-Controls** (Filter-Button mit Icon-Anhang) haben eine eigene Geometrie.
- **Icon-Größen** 12–30 px, je nach Kontext.

## Offen

- „Inhalt nicht erfasst“ (Chip) und „wird nicht indiziert“ (Hinweistext) benennen denselben Zustand. Ein Begriff sollte gewählt werden.
- Veraltete Dateien (alter Katalog, `ds-modernist.css`, Screenshots, Uploads) sind entfernt.

## Update-Hinweis

- Neuer Screen 13 „Updatedialog“ (Absturzbericht jetzt 15, Indizierungsfehler 14, Styleguide 16).
- Einstellungen → Allgemein: neuer Block „Updates“ mit Checkbox „Auf Updates hinweisen“.
- Link „Zur neuen Version“: https://www.diskarchive.app/


## 2026-11-02 · Offene Punkte aus dem Code (Mitteilungen/Indizierungsfehler)

- Der Grund erscheint nur im Dialog (14) und in der Mitteilung (18, Nr. 11). Chip, Kachel und Medium-Details sagen nur „Fehler“ – wer beides weggeklickt hat, sieht nirgends mehr, warum.
- „Fehler · erneut versuchen“ in der Kachel klingt nach Knopf, hat aber keinen eigenen Klick; die Kachel öffnet wie immer die Spaltenansicht.
- Mitteilungen Nr. 6 und 7 enden ohne Punkt, alle anderen mit.
- Grund f und der allgemeine Dialogtext sagen fast dasselbe zweimal („nicht gespeichert“ / „nicht indiziert“).
- Vorschau in den Einstellungen nutzt im Code „Archiv 2019–2021“ (7 Favoriten); das Layout verwendet laut Styleguide „Masterarbeit Backup“ und „Unterwegs“.
