# Übergabe — Disk Archive (Host, 08.11.2026)

**Anlass:** Der Nutzer macht ein paar Tage etwas anderes und kommt dann zurück. Es läuft nichts: kein Worker-Auftrag, kein Loop, kein Prüflauf. Alles ist in den festen Dateien dokumentiert; diese Datei ist nur der Einstieg. Der neue Host liest sie zuerst, prüft sie gegen das Repository, übernimmt den Stand und löscht sie dann (`claude/AGENTS.md`).

## Stand

- **0.4.3:** Pakete 57–62 abgenommen (zuletzt 62 am 06.11., Gesamtlauf 00:25–01:03). Übrig ist nur **Paket 63** (Version 0.4.3, DMG; [claude/todo/paket-63.md](claude/todo/paket-63.md)), noch nicht freigegeben.
- `claude/PROMPT.md`: „Kein Auftrag“. `claude/todo/sabotage/` gibt es nicht (alle Patches unter `claude/archiv/sabotage/paket-NN/`).
- App des Nutzers: gebaut im Gesamtlauf 06.11. (Stand Paket 62, Versionsnummer noch 0.4.2).
- **0.5 (Metadaten):** Entwurf [claude/todo/plan-0.5.md](claude/todo/plan-0.5.md), Pakete 64–67 vorgeschlagen, nicht freigegeben. Entschieden 05.11.: parallel lesen, Balken „Metadaten“ nur lesbare Formate, „Nach Updates suchen“ erst mit Layout. **Offen:** Ja des Nutzers zur Suche in Metadaten (angezeigte Werte plus Suchwörter „16:9“, „4K“, „HDR“ …, Frage 1 im Plan).

## Erste Schritte des neuen Hosts (in dieser Reihenfolge)

1. **Nachtest laden:** [claude/todo/nachtest-0.4.3.md](claude/todo/nachtest-0.4.3.md) (16 Punkte, Pakete 58–62) **sofort als interaktives Widget** zeigen – Format „Nachtest Paket 46“ (Karten, gefüllte Knöpfe OK/Fehler/Nicht getestet, Notiz, Senden). Antworten in die Datei eintragen; Fehler nach den drei Stufen, Stufe 1 als Korrektur vor 63.
2. **Vor Paket 63 (Host):** DMG-Hintergrund nach `layout/DMG Hintergrund.dc.html` neu rendern (660×400, Fußzeile „www.diskarchive.app“ statt Version) nach `Werkzeuge/dmg/hintergrund.png` und `@2x`; das vorhandene Bild hat 660×480 / 1320×960 – Maß gegen das Layout und `Werkzeuge/dmg-erstellen.sh` prüfen.
3. **Paket 63 freigeben** (Zeile in `claude/TODO.md`, Kopf der Paketdatei, `PROMPT.md` mit Schlusslauf `Werkzeuge/pruefung.sh voll`), dann die Loop-Frage stellen.
4. **0.5:** Antwort zu Frage 1 einholen, dann Pakete 64–67 ausschreiben; `ROADMAP.md` 0.5 („Nicht abschaltbar“) an das Konzept angleichen (Schalter „Metadaten laden“).

## Hinweise

- Feste Regeln: `claude/AGENTS.md` und der Speicher des Hosts (kein verändernder Git-Befehl, Commit-Nachricht ohne Co-Authored-By, `pruefung.sh` ohne `S=`, Nutzerschritte als Widget).
- Bekanntes Muster (Stufe 3): Tests mit `waitUntil(timeout: 5)` werden unter Parallellast gelegentlich rot (Helfer prüft nach Ablauf nicht noch einmal). Neue Tests mit 20 s; Helfer nicht ändern. `MediumEjectTests` wird in Paket 63 angehoben.
- Zeittest `firstIndexOfLargeSameSizeFolderIsFast` liegt gelegentlich knapp über 15 s (Stufe 3).
- Layout-Fragen ohne Folge für den Nutzer (`openQuestions` in `LayoutCopyTests`): `copy.settings.tab.media`, `copy.medium.indexed_value`, `copy.popover_search.group.folders`, `copy.menubar.about`; Englisch „1 MATCHES“ ohne Einzahl in 20.
