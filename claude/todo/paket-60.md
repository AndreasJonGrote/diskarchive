# Paket 60 — Zielversion 0.4.3 (freigegeben 03.11.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). Pfade relativ zu `claude/`; Code, `layout/`, `Werkzeuge/` im Hauptverzeichnis. **Drittes von sechs Paketen für 0.4.3: Erkennung und Popover.** Vorlage: Layout 00 („Anschließen und Erkennen“, „Status“), 01, 02 (02.01–02.03), 03 (alle Varianten, 03.09–03.11), 04 (Chip „Wird geprüft“, 04.01a), 19. Konzept: `konzept/medien.md`, `konzept/lauf-lebenszyklus.md`.

**Für dieses Paket gilt:**
- **Texte nur aus `layout/App-Layout 20 Texte.json`** (DE/EN); die 3 Schlüssel mit `pendingPackage = 60` in `LayoutCopyTests` hier erledigen, dazu `copy.a11y.overview` → „Zur Übersicht“ aus 20 (aus `openQuestions` nehmen). **Layout 03.11. (5):** `copy.action.retry` englisch „Try Again“ statt „Try again“ (sonst wird `LayoutCopyTests` rot). Fehlt ein Text: „Frage:“ (Regel 2).
- **Icons** nur aus `Werkzeuge/phosphor/` (Regel 4a). **Maße und Farben** aus dem Layout; Fade erst am Ende.
- **Die Lauf-Regeln bleiben** (`konzept/lauf-lebenszyklus.md`, Fenster dort „bewusst offen“). Dieses Paket ändert, was angezeigt wird, nicht wann ein Lauf startet oder endet. Braucht ein Zustand eine neue Information aus dem Lauf, „Frage:“ statt Umbau.
- Sabotage-Patch (Regel 9) je Verhaltensänderung. Läufe per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Git. **Vor „Bereit zur Prüfung“** alle Suites mit `Popover`, `MenuBar`, `Dashboard`, `NewMedium`, `Replace`, `Prompt`, `Recognition`, `Medium` oder `Pixel` im Namen laufen lassen (Lehre aus Paket 59).
- **So lassen:** Spaltenansicht und Einstellungen › Dateien & Ordner (Paket 61); Banner, Über, Update, Datenbank-/Einstellungsfehler (62). Fehlerzeile der Kachel bleibt „Fehler · erneut versuchen“, bis der Nutzer über die Zeit entscheidet.

**Reihenfolge (HALT am Ende):** `todo.0.4.3.012` → `todo.0.4.3.013` → `todo.0.4.3.014` → `todo.0.4.3.015`. **HALT.**

## Aufgaben

- **todo.0.4.3.012 — „Ersetzt dieses Medium …?“ (Layout 02.03, 00):**
  - Wird ein Medium angeschlossen, dessen Name zu einem bekannten, aber **nicht angeschlossenen** Medium gehört, fragt der Dialog laut 02.03 (Texte aus 20). „Altes vergessen“ entfernt das alte Medium mit Index und Favoriten, danach folgt der Erkennungs-Dialog für das neue. „Behalten“ führt beide getrennt weiter (danach Erkennungs-Dialog für das neue).
  - Den vorhandenen `ReplaceMediumDialog` und seinen Auslöser gegen 02.03 abgleichen: Bedingung, Texte, Knöpfe, Reihenfolge der Dialoge, Stapel mit mehreren Dialogen (02.02). Weicht die heutige Bedingung ab (z. B. andere Kennung als der Name), im Status nennen und „Frage:“, nicht still ändern.
  - **Test:** beide Knöpfe mit Folge (vergessen inkl. Favoriten / getrennt), Dialog nur bei bekanntem, nicht angeschlossenem Namen. Sabotage-Patch, falls sich Verhalten ändert.
  - **Status:**

- **todo.0.4.3.013 — Status „Wird geprüft“, „Entscheidung ausstehend“, „Speichermedium fehlerhaft“ (00, 03, 04, 01):**
  - **„Wird geprüft“:** für **neue und wieder angeschlossene** Medien zwischen dem Erkennen und dem Start einer Indizierung. Kachel: Chip „Wird geprüft“ (grün gestrichelt, pulsierender Punkt, keine Fläche). Popover: Zweitzeile „Speichermedium wird geprüft“ mit pulsierendem grünem Punkt, ohne Prozent. Folgt eine Indizierung → „{n} % indiziert“; ist nichts zu tun → „Online“ bzw. Ruhezustand. Der kurze Sprung auf 99 % beim Wiedererkennen entfällt. Ein reiner Abgleich auf einem vollständig indizierten Medium lässt die Kachel bei „Online“ (04).
  - **„Entscheidung ausstehend“** (nur Popover): gelber pulsierender Punkt, wenn das Medium online ist, aber die Antwort im Erkennungs-Dialog fehlt. Klick auf die Zeile öffnet den Erkennungs-Dialog **für genau dieses Medium**, nicht die Spaltenansicht.
  - **„Speichermedium fehlerhaft“** (nur Popover): roter pulsierender Punkt, wenn das Medium angeschlossen ist, sich aber nicht lesen lässt (14).
  - Menüleisten-Icon (01): Badges laut 01 prüfen (Neu erkannt = pulsierender grüner Punkt solange ein Erkennungs-Dialog wartet).
  - **Test:** Zustandsfolge neu → geprüft → indiziert/online, wieder angeschlossen ohne Änderung → nie 99 %, Klick „Entscheidung ausstehend“ öffnet den Dialog des Mediums. Sabotage-Patch.
  - **Status:**

- **todo.0.4.3.014 — Popover aufgeräumt und Popover-Suche (03):**
  - Der Umschalter zwischen Dateien und Prozent entfällt. Ein Chip erscheint nur, solange ein Medium indiziert wird (Spinner; während der Pause Pause-Icon). Kein Chip = online und vollständig indiziert. Zeitangabe mit Uhr-Icon + Datum („heute, {1}“) statt „Zuletzt indiziert: …“. Nur angeschlossene Medien.
  - **Leerzustände 03.09/03.10:** „Kein Speichermedium angeschlossen“ und „Kein indiziertes Speichermedium angeschlossen“ mit schwarzem Medien-Icon, hell und dunkel.
  - **Suche:** Zustand „Suche läuft — dauert länger“ (Spinner, „Deine {1} Speichermedien und {2} Dateien werden durchsucht …“, Einzahl laut 20, verzögert wie im Fenster) statt sofort „Keine Treffer“; „Keine Suchergebnisse“ / „Suchbegriff ändern.“ erst nach fertiger Suche; „Alle {1} Ergebnisse anzeigen“ / „1 Ergebnis anzeigen“. „Einen Moment bitte“ entfällt.
  - Benannte Medien und Favoriten wie in Paket 59 (`listLabel`).
  - **Test:** keine Umschalt-Steuerung mehr; Chip nur bei Lauf; Suche zeigt erst Warten, dann Ergebnis oder Leerzustand. Sabotage-Patch für die Suche.
  - **Status:**

- **todo.0.4.3.015 — Startzustand „Inhalte werden geladen“ (03.11, 04.01a):**
  - Solange beim Start der Index geöffnet wird, zeigen Hauptfenster (statt Dashboard) und Popover (statt Medienliste) nur den schwarzen Spinner mit „Inhalte werden geladen“, Aufbau wie 07.02.08. Vorhandenen `StoreLoadingView` gegen das Layout abgleichen (Größe, Schrift, Abstände), hell und dunkel.
  - **Test:** Pixel- oder Strukturtest gegen 03.11/04.01a.
  - **Status:**
