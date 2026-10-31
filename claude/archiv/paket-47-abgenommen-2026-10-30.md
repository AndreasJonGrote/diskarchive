# Paket 47 — Zielversion 0.4.0 (freigegeben 29.10.2026, abgenommen 30.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nutzer 29.10. („Wir hätten jetzt noch die Zeit für ein paar Fixes“, Auswahl „Alles“); Backlog-Zeilen 29.10. Paket 46. Baut auf `bug.0.4.230` auf (`VolumeInfo.deviceMedium`).

## Abnahme Host 30.10. (Gesamtlauf 29.10. 23:56 – 30.10. 00:28)

- Diff gelesen: `IndexingVolumeTuning.parallelDirectoryReads(isRemovable:deviceMedium:deviceProtocol:)` als reine Regel (drehend 1, feste SSD 4, sonst USB 1, Rest 4); die DiskArbitration-Abfrage entfällt samt Ausnahme im Quelltext-Test. `isInternal` fällt weg (interne Platten sind keine Kandidaten). Zweig `denied` setzt den Typ. Nichts Wesentliches.
- Gesamtlauf bei Last 2,7: Debug und Release 0 Warnungen, seriell 1239/1239, parallel 3× grün (je 1233, 6 übersprungen), Sabotage 3/3 rot (051-a, 051-b, 231-a je 1/1), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 00:28:13, Signatur gültig.
- **Messung des Nutzers 30.10. (App 00:28, M0–M4 „passt“, Zeiten aus dem Protokoll):** nach „Alle vergessen“ Erstindex 00:51:49–00:54:10 = **2 min 21 s** (vorher 1 min 53 s; Platte erst 00:51 angesteckt, kalter Zwischenspeicher), „Neu indizieren“ 00:56:03–00:57:25 = **1 min 22 s**, Abgleich nach Wiederanstecken 00:57:39–00:58:12 = **33 s** (vorher 1 min 14 s, damals zugleich mit dem Erstindex von „Daten“). Kein klares Langsamer, Abgleich doppelt so schnell; Spaltenansicht und Suche flüssig → **Regel bleibt** (Host).
- Patches: `archiv/sabotage/paket-47/`.

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (jetzt `archiv/sabotage/paket-47/`) (Regel 9).
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
  - **Status:** Bereit zur Prüfung. Rot 23:42 (Tabelle: fest+Solid State+USB → 1 statt 4, fest+Rotational+PCI-Express → 4 statt 1), grün 23:43.
    Fix: `IndexingVolumeTuning.parallelDirectoryReads(isRemovable:deviceMedium:deviceProtocol:)` als reine Regel 1–3; `isRotational` mit `DADiskCopyDescription` entfällt; Ausnahme „Media Solid State“ aus `EnglishLocalizationTests.exceptions` entfernt. `isInternal` nicht in der Signatur: Regel 3 ergibt mit und ohne dasselbe (heute auch).
    Test: `MediumTypeTests/parallelReadsFollowTheDeviceMedium` (6 Zeilen wie verlangt). 21 betroffene Suites 223/223 (23:44–23:46, inkl. DirectoryIndexer, IndexingService, LargeFolderChunk, LargeMediumFolderCost, MovedFolderFat, FatReconnectIndexer, EnglishLocalization). Build 0 Warnungen.
    Sabotage 23:46–23:48: a rot 1/1, b rot 1/1.
    Selbstprüfung: nichts Wesentliches. Messung „Daten I“ durch den Nutzer nach der Abnahme.

- **bug.0.4.231 — Medium ohne Zugriff zeigt den alten Typ (Stufe 2 aus Paket 46, Nutzer 29.10. „Alles“):**
  - **Nutzer sieht:** Ein bekanntes Medium, auf das die App gerade keinen Zugriff hat (Status „Fehler“, „Kein Zugriff …“), zeigt bis zur Freigabe den gespeicherten Typ, also z. B. HDD statt SSD.
  - **Wann:** Erstes Anstecken eines solchen Mediums nach dem Update.
  - **Ursache:** `MediumCoordinator`, Zweig `denied` (Z. ~205–217): `denied` wird aus `stored` gebaut, ohne `type = volume.mediumType`.
  - **Soll:** Auch dort `type = volume.mediumType` setzen, bevor gespeichert und veröffentlicht wird (wie Z. ~238 und `publishConnectKnownReadOnly`).
  - **Gegenprobe:** Test im `RecognitionRig`: bekanntes Medium Typ HDD, Zugriff verweigert, Volume fest + Solid State → gespeichert und angezeigt SSD, Status Fehler. **Patch** `bug.0.4.231-a.patch`: Zeile wieder entfernen → rot.
  - **Status:** Bereit zur Prüfung. Rot 23:42 (`deniedKnownMediumTakesTheConnectedType`: gespeichert und angezeigt HDD), grün 23:43.
    Fix: `MediumCoordinator.connectKnown`, Zweig `denied`: `denied.type = volume.mediumType` vor Speichern und Veröffentlichen.
    Test: `WindowTestGroup/MediumCoordinatorTests/deniedKnownMediumTakesTheConnectedType` (HDD gespeichert, Zugriff verweigert, fest + Solid State → SSD, Status Fehler); Suites wie oben.
    Sabotage `bug.0.4.231-a` rot 1/1 (23:46–23:47), gesamt 3/3, 0 Mängel.
    Selbstprüfung: nichts Wesentliches.
