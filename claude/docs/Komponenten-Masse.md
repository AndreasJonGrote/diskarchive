# Komponenten-Maße (gemessen von Claude am 07.10.2026 am alten Katalog `bis 0.4.1`; seit 31.10. gilt `layout/App: Komponenten.dc.html`)

**Quelle der Wahrheit für Maße, Farben und Zustände:** die Layout-Seite „Komponentenkatalog“ (`layout/App: Komponenten.dc.html`, jede Komponente hell und dunkel). Abweichungen in Screens gelten als Fehler. Diese Datei ist nur die gemessene Zusammenfassung (px im Layout = pt in der App); bei Widerspruch gilt die Layout-Seite. Cursor liest Zahlen aus dieser Datei und prüft sie im Test, ändert sie nicht.

## Schrift
14 Button groß · 13 Fließtext, Listenzeilen · 12 Button klein, Detail, Beschreibung, Eingabefeld · 11 Meta, Fußzeile, Tabellenkopf · 10 Chip, Spaltenkopf, Label.

## Abstände und Radien
Abstände 2 · 4 · 6 · 8 · 12 · 16 · 24 · 32. Radien: klein 6 (Chips, Zeilen, Selectgroup), mittel 8 (Knöpfe, Eingabe, Kachel), groß 14 (Dialog, Kontextmenü-Fläche).

## Knöpfe
| Art | Schrift | Innenabstand | Höhe | Rahmen | Radius |
|---|---|---|---|---|---|
| **Groß** (Primär, Sekundär, Ghost, Destruktiv, Bestätigen, Bestätigt) | **14 / 600**, Zeilenhöhe 16,8 | **10 oben/unten, 18 links/rechts** | **38,8** | 1 px | 8 |
| **Klein** (z. B. Filter, Dropdown „Deutsch“, Im Finder anzeigen) | **12 / 600**, Zeilenhöhe 14,4 | **4 oben/unten, 12 links/rechts** | **24,4** | 1 px | 8 |
| Icon-Knopf (Toolbar) | 14 | 0 | 30 hoch, 27,9 breit | 1 px (transparent) | 8 |

Farben groß: Primär Rand und Fläche `#1f1f1f`, Schrift `#eae9e9`. Sekundär Rand `#9b9797`, Fläche leer, Schrift `#1f1f1f`. Ghost Rand transparent. Destruktiv Rand und Schrift `#e04830`, Fläche leer. **Bestätigen:** Fläche `#e04830`, Rand `#b5381f`, Schrift weiß. **Bestätigt:** Fläche `#2e9e5b`, Rand `#237a46`, Schrift weiß. Filter-Knopf aktiv: Rand und Schrift Blau `oklch(0.62 0.16 255)`. Symbol-Abstand im Knopf 6 (klein 8 bei Dropdown mit Pfeil).

**Selectgroup (Ja | Nein):** Höhe 24,4 (= Knopf klein), Außenrahmen 1 px `#1f1f1f`, Radius 6; Segment Schrift 12, Innenabstand 4/12; gewählt: Fläche `#1f1f1f`, Schrift `#eae9e9`, **700**; ungewählt: transparent, **600**, Schrift 60 % Text.

## Chips
Schrift **10 (Gewicht 400)**, Zeilenhöhe 15,5, Innenabstand **3 oben/unten, 10 links/rechts**, **Höhe 23,5**, Rahmen 1 px, Radius 6, Inhalt **vertikal mittig**, Fläche = Basisfarbe 5 % (dunkel 12 %). Entfernbar: Symbol ✕ 10, Abstand 4. Filter-Auswahl im Popover: Haken ✓ statt ✕, nicht entfernbar. Basisfarben: Grün `oklch(0.62 0.16 150)`, Rot `#e04830`, Gelb `#eda12d`, Grau `oklch(0.62 0 0)`, Blau `oklch(0.62 0.16 255)`, Violett `oklch(0.62 0.16 305)`, neutral Rand/Schrift `#1f1f1f`.

## Zeilen
- **Medienzeile (Seitenleiste):** Schrift 13/400 (gewählt **600**), Innenabstand **7 oben/unten, 10 links/rechts**, Radius 6, Abstand Icon–Text 8, Höhe 34,1, Mitte ausgerichtet. Gewählt: Fläche `#1f1f1f`, Schrift `#eae9e9`. Liste in Behälter mit Innenabstand 8, Radius 8, Fläche 7 % Text.
- **Ordner-/Dateizeile (Spalte, Breite 180):** gleiche Maße wie Medienzeile; Spaltenbehälter Innenabstand 8, Rahmen 1 px 40 % Text, Radius 8.
- **Tabellenzeile:** Kopf Schrift 11/**700**, Farbe 60 % Text, Innenabstand 11/10, Höhe 40; Zeile Schrift 14 (Name 600), Innenabstand 11/10, Höhe 47,5.
- **Kontextmenü:** Fläche Radius 14, Innenabstand 4, Breite 230, Rahmen 1 px; Eintrag Schrift 13/400, Innenabstand **7 oben/unten, 12 links/rechts**, Radius 6, Abstand Icon–Text 8, Höhe 34,1; destruktive Einträge Rot.

## Flächen
- **Kachel (Dashboard):** Breite 240 (Katalog „220“ im Titel ist die Mindestbreite, Maß 240 gemessen), Innenabstand 12, Radius 8, Rahmen 1 px 40 % Text, Abstand der Inhalte 8, Schatten „elev-md“.
- **Dialog:** Breite 340, Innenabstand 16, Radius 14, Rahmen 1 px, Abstand 12; Knöpfe groß, gleich breit bei zwei Antworten (149 × 38,8).
- **Eingabefeld:** Schrift 12, Höhe 32,6, Innenabstand 6/10 (links 26 mit Lupe), Rahmen 1 px 40 % Text, Radius 8, Breite im Katalog 260.

## Einstellungen (Layout 05, gemessen)
- Überschrift und erste Zeile der Bedienelemente haben **dieselbe Oberkante** (Checkbox-Zeile Höhe 18,6, Kästchen 16 × 16 mit 1,3 Versatz). Nicht vertikal zentrieren.
- Mitteilungen: Zeilenabstand **27** (Zeilenhöhe 19 + 8), Einrückung der drei Unterpunkte **25**, Beispielkasten **15** unter der letzten Zeile, Höhe 74, gestrichelter Rahmen 1 px 40 % Text.

## Ergänzungen ohne Katalogseite (Host)
- **Spaltenkopf deaktiviert** (Suche, Pfad/Status über 500 Treffer, `bug.0.4.038`, 17.10.): Deckkraft 0,45 wie `MenuBarGhostButton`, kein Zeigefinger, kein Klick. Beim Layout-Durchgang (`todo.0.4.040`) in den Katalog übernehmen oder korrigieren.
