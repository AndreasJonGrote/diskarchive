# Disk Archive – Änderungsprotokoll

Neueste Einträge oben. Datei: `App: Layout.dc.html`, sofern nicht anders angegeben.

## 2026-10-29

### DMG-Hintergrund – Layout neu, Hell-Variante
- Ringe kleiner, auf das App-Icon zentriert und nach außen ausgeblendet; kreuzen keinen Text mehr.
- Icon-Zone auf y = 200 (Finder: 170/200, 490/200), Pfeil mittig dazu; Headline 24 px.
- Neue Variante „Hell“ (hellgrauer Grund, weißer Lichtverlauf, Tinte), jeweils Finder-Vorschau + Export-Bild.

## 2026-10-28

### Sektion 03 + 04 – Status „Wird geprüft“ auch beim Wiederanschließen
- Gilt jetzt für neue und wieder angeschlossene Medien: zwischen Erkennen und Start einer Indizierung „Wird geprüft“ statt kurzem Sprung auf 99 %. Folgt eine Indizierung → „x % indiziert“, sonst → Ruhezustand / „Online“.
- 03: Variante umbenannt in „Neu oder wieder angeschlossen“, zweite Zeile „Reise-SSD“ (wieder angeschlossen) mit pulsierendem Punkt. Beschreibung ergänzt.
- 04: Neuer Chip „Wird geprüft“ (gestrichelt grün, pulsierender Punkt) an „Reise-SSD“, hell und dunkel. Beschreibung ergänzt.

## 2026-10-10

### Sektion 05 – Tab „Lizenz“ (alle 3 Zustände)
- Ruhiger neu aufgebaut: zweispaltig statt Kacheln. Links Icon, Headline, Text und Schlüssel (Eingabe + „Aktivieren“ bzw. maskierter Schlüssel + Belegung). Rechts die drei Lizenzstufen als schlichte Liste (aktuelle fett mit Punkt, andere gedämpft) und die weiteren Aktionen als dezente Textlinks („Lizenz holen“ / „Zur Website“, „Lizenz deaktivieren“) statt Buttons.

### Sektion 03 – Dropdown
- Neuer Zustand „Neues Medium — Speichermedium wird geprüft“: bei sehr vielen Dateien steht die Erstindizierung bis zu 2 Min. auf 0 %, weil erst die Platte geprüft wird. Statt Ladebalken: Zweitzeile „Speichermedium wird geprüft“ mit pulsierendem grünem Punkt („Neu erkannt“), ohne Spinner und ohne Prozentangabe. Beschreibungstext der Sektion ergänzt.
- „Zuletzt indiziert: heute, 09:14“ ersetzt durch Clock-Icon + „heute, 09:14“ (alle 8 Stellen). Clock-Strich um 0,5 px verstärkt.
- Zwei neue Dropdown-Varianten:
  - „Suche läuft — dauert länger“: Spinner, „Deine 12 Speichermedien und 48.230 Dateien werden durchsucht …“, „… einen Moment bitte.“
  - „Kein Suchergebnis“: Lupe, „Keine Suchergebnisse“, „Suchbegriff ändern.“

### Detail-Ansicht – Metadaten je Medientyp
Jeweils Beispiel + Variante „unbekannte Werte“ (fehlende Werte = Gedankenstrich). Allen gemeinsam: Dateiname, Geändert, Größe.
- **Video:** Vorschaubild mit Dauer (Overlay); Auflösung, Bildrate, Video-Codec, Audio-Codec.
- **Foto:** Vorschau; Auflösung, Megapixel, Farbraum.
- **Audio:** Wellenform statt Vorschaubild; Dauer, Samplerate, Qualität, Kanäle.
- **PDF:** Seitenvorschau; Seitenzahl, Seitenformat.

### Offen / Hinweise
- „Erfolgreich indiziert“-Icon (Haken im Kreis) ist im Projekt nicht definiert; vorübergehend probiert, dann wieder durch Clock ersetzt.
- Layout-Check meldet Überlappungen im Pausieren-Menü und abgeschnittene Dateinamen in den Suchzeilen (nicht geprüft/angefasst).
