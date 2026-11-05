# Plan 0.5 — Metadaten (Entwurf Host 05.11.2026, nicht freigegeben)

Index: [TODO.md](../TODO.md). Grundlage: `konzept/roadmap.md` „0.5 Metadaten“ (Nutzer 02.11./03.11., maßgeblich), Layout 05.01 (Schalter), 06 (Details-Fenster, Balken „Metadaten“), 07.04 (Detailspalte je Dateityp), Texte aus Sektion 20 (05, 07). Datenbank: `item_meta` (Schlüssel/Wert mit Herkunft, `meta_keys`) gibt es seit 0.3, leer; nur erweitern, nie umbauen (`konzept/datenbank.md`).

**Rahmen (aus dem Konzept, schon entschieden):**
- Globaler Schalter „Metadaten laden“, ab Werk an, nicht je Medium. Aus: sofort ausgeblendet, nach 1 Stunde gelöscht, innerhalb der Stunde wieder an behält die Werte.
- Eigener zweiter Durchgang nach dem Index, im Hintergrund, nur bei angeschlossenen Medien, hält mit der globalen Pause an, setzt nach dem Wiederanschließen fort. Das Indizieren selbst wird nicht langsamer.
- Felder: Video Auflösung, Dauer, FPS, Codec, Farbraum mit SDR/HDR („Rec.2020 · HDR (HLG)“); Foto/RAW Auflösung, Megapixel, Farbraum, Kamera; Audio Dauer, Samplerate, Qualität, Kanäle; PDF Seiten und Seitenformat. Fotos und Videos „Aufgenommen“ zwischen „Erstellt“ und „Geändert“. Office ohne Metadaten. Fehlende Werte „—“.
- Anzeige nur in der Detailspalte, kein Chip, kein Banner, Kachel bleibt „Online“. Noch nicht gelesen: grau „Weitere Angaben folgen“. Durchsuchbar über die normale Suche; eigener Filter später.
- Nie Dateiinhalte (`datenschutz-plattform.md`): nur Kopfdaten der Formate, kein Text, keine Bilddaten dekodieren.
- Vorschaubilder (0.6) bleiben verborgen, auch Balken und Schalter „Vorschaubilder“.

## Pakete (Vorschlag)

| Paket | Inhalt | Kern |
|---|---|---|
| **64** | **Zweiter Durchgang** | Warteschlange je Medium nach fertigem Index, niedrige Priorität, ein Leser je Medium; Pause, Abziehen, Wiederanschließen, App-Ende mitten im Durchgang; Markierung „gelesen“ je Datei (Schlüssel in `item_meta`, Herkunft System) mit Größe + Änderungsdatum, damit geänderte Dateien neu gelesen werden; Schalter „Metadaten laden“ mit 1-Stunden-Regel. Zunächst mit einem Test-Leser, noch ohne echte Formate. |
| **65** | **Leser je Format** | Foto/RAW über ImageIO (nur Eigenschaften, kein Dekodieren), Video und Audio über AVFoundation (Spuren und Formatbeschreibung, HDR aus der Übertragungsfunktion), PDF über CGPDFDocument (Seitenzahl, Format der ersten Seite). Werte als Schlüssel in `item_meta`, Rest des Gelesenen als Blob (`info`). Zuordnung Endung → Art aus `SearchFileTypeFilter`. Messung: Dateien je Minute auf einem Testordner und auf einem echten Medium des Nutzers (nur lesend). |
| **66** | **Anzeige** | Detailspalte 07.04 für Video, Foto, Audio, PDF, Office, „unbekannte Werte“, „Weitere Angaben folgen“, „Metadaten aus“; Formatierung (Dauer, Auflösung, Megapixel, Farbraum, Samplerate); Details-Fenster 06 mit Balken „Metadaten“ (Fortschritt je Medium, aus = grau „Aus“); Schalter und Texte in Einstellungen 05.01. |
| **67** | **Suche und Version** | Metadaten-Werte durchsuchbar (Felder siehe Frage 1); Version 0.5.0 und DMG wie Paket 63. |

## Fragen an den Nutzer (entschieden 05.11., außer 1)

1. **Was ist durchsuchbar?** Nutzer 05.11.: „16:9“ und „709“ müssen Treffer bringen. Neuer Vorschlag: jeder angezeigte Wert als Text, so wie er in der Detailspalte steht („3840 × 2160“, „Rec.709 · SDR“, „HEVC“, Kamera), dazu wenige abgeleitete Suchwörter, die nicht angezeigt werden: Seitenverhältnis („16:9“, „4:3“, „3:2“, „21:9“ …), Auflösungsnamen („4K“, „UHD“, „1080p“, „720p“), „HDR“/„SDR“, „HLG“/„PQ“. Dauer, Samplerate und Aufnahmedatum nicht (zu viele Zufallstreffer bei Zahlen); „Aufgenommen“ als Filter kommt nach 0.6. Gespeichert als eigene Suchspalte je Datei (neue Tabelle, nur Erweiterung), gesucht wie Namen.
2. **Last – entschieden (Nutzer 05.11.: „parallel sollte das Ziel sein“, Rest Host):** Medien werden gleichzeitig gelesen, jedes mit eigenem Leser. Innerhalb eines Mediums mehrere Leser nach Art des Mediums wie beim Indizieren (`IndexingVolumeTuning`: SSD parallel, HDD nacheinander); die Zahl legt die Messung in Paket 65 fest. Der Durchgang weicht nur dem Indizieren **desselben** Mediums und der globalen Pause.
3. **Balken „Metadaten“ – entschieden (Nutzer 05.11.):** zählt nur Dateien mit lesbarem Format (Foto, Video, Audio, PDF).
4. **`todo.0.5.004` „Nach Updates suchen“ – entschieden (Nutzer 05.11.):** nicht in diesem Plan; kommt, sobald das Layout dafür da ist.

**Abgleich:** `ROADMAP.md` 0.5 sagt noch „Nicht abschaltbar“; das Konzept vom 02.11. abends (Schalter) gilt. Host gleicht `ROADMAP.md` bei der Freigabe an.
