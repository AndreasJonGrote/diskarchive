# Paket 45 — Zielversion 0.4.0 (freigegeben 29.10.2026, abgenommen 29.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nachtest E5 des Nutzers 29.10. 16:56 mit der App von 16:33 (Paket 44), H4-Karte „ZOOM_H4E“ (**FAT32**). Konzept: `konzept/datenbank.md`, Absatz „Umbenennen und Verschieben erkennen“ (Nutzer 29.10.).

## Abnahme Host 29.10. (Gesamtlauf 18:03–18:36)

- Diff gelesen (`DirectoryWriterV3.reconnectMovedFolders` am Laufende vor den einzelnen Einträgen, `mergeMovedFolder` rekursiv, verschwundene Ordner einmal je Lauf über `items_gone`, `goneNamesMovedOutDuringRun` im Store; Schutz: kein Sichtbares unter dem alten Ordner, kein Einhängen in eigene Nachfahren). Nichts Wesentliches. Stufe 2 (Worker): Abbruch mitten im Lesen des neuen Ordners → Folgelauf kennt die einzeln weggeholten Namen nicht, Ordner bleibt neu (vorher ebenso) → Backlog.
- Gesamtlauf bei Last 3,3: Debug und Release 0 Warnungen, seriell 1234/1234, parallel 3× grün (je 1228, 6 übersprungen), Sabotage 3/3 rot (229-a 2/2, -b 1/1, -c 1/1), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 18:36:01, Signatur gültig.
- Offen: Nachtest E5 mit der H4-Karte (Ordner) und mit einer Datei.

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (jetzt `archiv/sabotage/paket-45/`) (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3). Keine Gesamtläufe (Regel 13/14), nur die betroffenen Suites.

**Reihenfolge (HALT am Ende):** `bug.0.4.229`. **HALT.**

## Aufgaben

- **bug.0.4.229 — Verschobener Ordner auf FAT/exFAT verliert beim Wiederanstecken seinen Favoriten (Nutzer 29.10.):**
  - **Nutzer sieht:** Favorit auf einen Ordner gesetzt, Ordner im Finder in einen anderen Ordner verschoben, Medium abgezogen und wieder angesteckt: Der Ordner steht am neuen Ort, **der Favorit ist weg**. Dasselbe gilt für alles im Ordner (Favoriten auf Dateien darin, später Metadaten).
  - **Wann:** Jedes FAT/exFAT-Medium (Karten, Rekorder, Kameras, Sticks), wenn ein Ordner verschoben wird, während die App nicht zusieht: auf einem anderen Gerät, oder kurz vor dem Abziehen (Ruhezeit der Überwachung 2 s). **Stufe 1:** in der echten App nachgewiesen.
  - **Beleg (Host, Protokoll, Datenbank nur lesend):**
    - 16:56:21 `toggleFavorite kind=folder rowID=5661845` (Ordner `250714_184701` im Hauptordner). 16:56:32 abgezogen, kein Ereignis der Überwachung davor.
    - 16:56:43 eingesteckt, Abgleich `abgleich=true`, fertig nach 0,4 s. Danach liegt `250714_184701` in `250714_184641` unter **neuer** Kennung 6356012; Zeile 5661845 und ihr Eintrag in `favorites` sind gelöscht.
  - **Ursache:** `DirectoryWriterV3.folderGoneCandidateIsConfident` (Z. ~837) lässt einen verschwundenen Ordner nur zu, wenn **Name und Elternordner** gleich sind. Ein verschobener Ordner hat einen anderen Elternordner und wird neu eingefügt. Bisher stand das so im Konzept; der Nutzer hat es am 29.10. geändert.
  - **Soll (Konzept `datenbank.md`, Nutzer 29.10.):**
    - Ein Ordner an einem neuen Ort ist derselbe wie ein verschwundener Ordner (`status = 2`), wenn es **genau einen** verschwundenen Ordner mit **demselben Namen** gibt und die **Namen der direkten Einträge** beider Ordner übereinstimmen.
    - **Leere Ordner** zählen nicht, sie gelten als neu. Mehrere Kandidaten mit gleichem Namen und gleichen Einträgen: neu. Umbenannt **und** verschoben: neu.
    - Die alte Zeile wird an den neuen Ort gehängt (Kennung, Favorit bleiben), und **alles darin behält seine Kennung**: Dateien und Unterordner in jeder Tiefe, mit ihren Favoriten. Keine doppelten Zeilen, keine verwaisten Zeilen, Zähler des Mediums stimmen.
    - Beide Richtungen: Ordner **tiefer** verschoben (alter Ort wird zuerst als verschwunden markiert, wie im Beleg) und **höher** verschoben (neuer Ort wird gelesen, bevor der alte als verschwunden gilt; dann am Laufende wie `reconnectInsertedWithGone`).
    - APFS/HFS+ (`fileID`) und die Überwachung (FSEvents „alt → neu“) bleiben, wie sie sind.
  - **Weg (Vorschlag, du entscheidest):**
    - Die Namen der direkten Einträge kennt der Schreiber, wenn der Ordner beim Schreiben **seines Inhalts** dran ist (eine Ebene später), oder am Laufende. Der Store liest dafür **nicht** von der Platte (Invariante 8).
    - Naheliegend: am Laufende (oder beim Schreiben des Inhalts) neu eingefügte Ordner mit verschwundenen Ordnern gleichen Namens vergleichen; bei eindeutigem Treffer die alte Zeile umhängen und die neuen Kind-Zeilen mit den alten (gleicher Name) zusammenführen, rekursiv. Für Dateien darin gelten dieselben Merkmale wie heute (Größe, Datum, Endung); was nicht passt, bleibt neu bzw. verschwunden.
    - Invariante 9 beachten: keine Abfrage je Kandidat über das ganze Medium; verschwundene Ordner einmal je Lauf nach Namen sammeln.
  - **Gegenprobe (Tests, Regel 10):**
    1. **Realistischer Test (FAT, `trustsFileID == false`):** Medium mit `A/X/{a.txt, b.wav, Sub/c.txt}` indiziert, Favorit auf `X` und auf `Sub/c.txt`. Danach liegt `X` unter `B/X` (auf der Platte verschoben, App sah nicht zu). Abgleich: `X`, `a.txt`, `b.wav`, `Sub`, `c.txt` behalten ihre IDs, beide Favoriten bleiben, keine Zeilen mit `status = 2` übrig, Zähler stimmen.
    2. Dasselbe in die andere Richtung: `A/B/X` → `X` im Hauptordner (höher verschoben).
    3. Zwei verschwundene Ordner `X` mit gleichen Einträgen (oder `X` an zwei neuen Orten): beide neu, kein Favorit wandert an einen falschen Ort.
    4. Gleicher Name, aber andere Einträge: neu. Leerer Ordner verschoben: neu.
    5. Ordner umbenannt und verschoben: neu (wie bisher).
    6. Die bestehenden Tests zu `bug.0.4.015`, `141`, `156`, `165`, `169`, `225`, `227`, `228` (`FatReconnectIndexerTests`, `PartialReadOnDemandTests`, `LargeFolderChunkTests`, `LargeMediumFolderCostTests` u. a.) bleiben grün; Test 1 aus `LargeMediumFolderCostTests` hält seine Grenze.
  - **Patches (rot erwartet):**
    1. `bug.0.4.229-a.patch`: wieder nur Name + Eltern. Test 1 und 2 werden rot.
    2. `bug.0.4.229-b.patch`: Inhalt nicht vergleichen (nur Name). Test 4 wird rot.
    3. `bug.0.4.229-c.patch`: Kind-Zeilen nicht zusammenführen (nur der Ordner wird umgehängt). Test 1 wird rot (Favorit auf `c.txt` weg oder doppelte Zeilen).
  - **So lassen:** Teil-Prüfsumme nur bei Bedarf (`bug.0.4.225`), Store-Actor ohne Plattenzugriff (`bug.0.4.226`, Invariante 8), Abgleich mit verschwundenen Einträgen nur bei `finalize` (`bug.0.4.227`), gemerkte Größen und `items_gone` (`bug.0.4.228`), Lebenszyklus der Läufe (`konzept/lauf-lebenszyklus.md`), Ruhezeit der Überwachung (2 s). Kein neues Schema (vorher fragen).
  - **Status:** Bereit zur Prüfung. Ursache bestätigt (rot 17:23: X und Sub neu, Dateien darin schon einzeln wiederverbunden). Weg: am Laufende (`reconnectInsertedWithGone` → neu `reconnectMovedFolders`), beide Richtungen, ohne Plattenzugriff; verschwundene Ordner einmal je Lauf nach Namen (`INDEXED BY items_gone`).
    Fix: eindeutiger Name + gleiche Namen der direkten Einträge (beim alten Ordner zählen auch die im Lauf einzeln weggeholten Namen, Store-Zustand `goneNamesMovedOutDuringRun`); alte Zeile an den neuen Ort, Kinder rekursiv nach Namen zusammengeführt (Dateien: Größe, Endung, Datum ±1 h). Kein neues Schema.
    Tests: `MovedFolderFatTests` 1–5 (FAT, echte Dateien), Rauchtest-Zeile `movedFatFolderKeepsItsIDsAndFavorites`; Test 1/2 rot 17:23, alle grün 17:31; 29 betroffene Suites 233/233 (17:33–17:36), Endstand 63/63 (17:36).
    Patches a/b/c rot 3/3, 0 Mängel (`pruefung.sh sabotage` 17:37–17:39); Debug clean mit Testziel 0 Warnungen (17:40).
    Selbstprüfung: nichts Wesentliches. Stufe 2: Abbruch mitten im Lesen des neuen Ordners → Folgelauf kennt die schon weggeholten Namen nicht, Ordner bleibt neu (vorher ebenso).
