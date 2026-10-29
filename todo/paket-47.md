# Paket 47 — Zielversion 0.4.0 (freigegeben 29.10.2026, nach Abnahme von Paket 46)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nutzer 29.10. („Wir hätten jetzt noch die Zeit für ein paar Fixes“, Auswahl „Alles“); Backlog-Zeilen 29.10. Paket 46. Baut auf `bug.0.4.230` auf (`VolumeInfo.deviceMedium`).

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3). Keine Gesamtläufe (Regel 13/14), nur die betroffenen Suites.

**Reihenfolge (HALT am Ende):** `todo.0.4.051`, `bug.0.4.231`. **HALT.**

## Aufgaben

- **todo.0.4.051 — Lesetempo nach Plattentyp (Nutzer 29.10.):**
  - **Nutzer sieht:** USB-SSDs wie „Daten I“ werden mit **1** Lesevorgang gleichzeitig gelesen statt mit 4; Erstindex und Abgleich dauern länger als nötig. Drehende Platten an Thunderbolt/PCIe werden mit **4** gleichzeitig gelesen (Kopf springt).
  - **Ursache:** `IndexingVolumeTuning.isRotational` (Z. ~18) fragt `"Media Solid State"` aus DiskArbitration ab; den Schlüssel gibt es dort nicht (Host 29.10., `bug.0.4.230`). Es greift immer der Ersatz „Protokoll USB = drehend“.
  - **Soll:** `parallelDirectoryReads(for:)` als **reine Regel** über `isRemovable`, `deviceMedium`, `deviceProtocol`, `isInternal`:
    1. `deviceMedium == .rotational` → **1**.
    2. `deviceMedium == .solidState` und **nicht** wechselbar → **4**.
    3. Sonst wie heute ohne den DiskArbitration-Schlüssel: Protokoll enthält „usb“ → 1, sonst 4. (Sticks und Karten bleiben damit wie heute.)
    - Die Abfrage `isRotational` mit `DADiskCopyDescription` entfällt; dafür die Ausnahme `("Indexing/IndexingVolumeTuning.swift", "Media Solid State", …)` in `EnglishLocalizationTests.exceptions` entfernen (sonst wird `everyExceptionStillMatchesALine` rot).
    - Der Indexer liest sonst nichts anders. Invariante 8 (Store ohne Plattenzugriff) und 9 bleiben.
  - **Gegenprobe (Tests, Regel 10):**
    1. Regel als Tabelle: fest+Solid State+USB → 4; fest+Rotational+PCI-Express → 1; wechselbar+Solid State+USB → 1; fest+keine Angabe+USB → 1; fest+keine Angabe+PCI-Express → 4; intern+keine Angabe → 4.
    2. Bestehende Tests der Indizierung (`DirectoryIndexer…`, `LargeFolderChunkTests`, `LargeMediumFolderCostTests`, `MovedFolderFatTests`, `FatReconnectIndexerTests`) bleiben grün.
  - **Patches (rot erwartet):** `todo.0.4.051-a.patch`: `deviceMedium` nicht beachten (Regel 3 für alle) → Test 1 rot. `todo.0.4.051-b.patch`: Solid State auch bei wechselbar → 4 → Test 1 rot.
  - **Messung (Nutzer, nach der Abnahme):** „Daten I“ neu indizieren und danach ab- und anstecken. Bisher (29.10., 1 Lesevorgang): Erstindex 1 min 53 s, Abgleich 1 min 14 s. Wird es **langsamer**, nimmt der Host die Regel 2 zurück (exFAT kann parallele Zugriffe ausbremsen).
  - **So lassen:** alles aus Paket 43–46, Wächterzeit, Stückgröße, Lebenszyklus der Läufe. Kein neues Schema.
  - **Status:**

- **bug.0.4.231 — Medium ohne Zugriff zeigt den alten Typ (Stufe 2 aus Paket 46, Nutzer 29.10. „Alles“):**
  - **Nutzer sieht:** Ein bekanntes Medium, auf das die App gerade keinen Zugriff hat (Status „Fehler“, „Kein Zugriff …“), zeigt bis zur Freigabe den gespeicherten Typ, also z. B. HDD statt SSD.
  - **Wann:** Erstes Anstecken eines solchen Mediums nach dem Update.
  - **Ursache:** `MediumCoordinator`, Zweig `denied` (Z. ~205–217): `denied` wird aus `stored` gebaut, ohne `type = volume.mediumType`.
  - **Soll:** Auch dort `type = volume.mediumType` setzen, bevor gespeichert und veröffentlicht wird (wie Z. ~238 und `publishConnectKnownReadOnly`).
  - **Gegenprobe:** Test im `RecognitionRig`: bekanntes Medium Typ HDD, Zugriff verweigert, Volume fest + Solid State → gespeichert und angezeigt SSD, Status Fehler. **Patch** `bug.0.4.231-a.patch`: Zeile wieder entfernen → rot.
  - **Status:**
