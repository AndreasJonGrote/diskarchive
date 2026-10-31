# Paket 46 — Zielversion 0.4.0 (freigegeben 29.10.2026, abgenommen 29.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Herkunft: Nutzer 29.10. („SSD ist SSD und nicht HDD“). Konzept: `konzept/medien.md`, Abschnitt **2c. Medientyp** (Nutzer 29.10.).

## Abnahme Host 29.10. (Gesamtlauf 20:06–20:38, Korrektur 23:24)

- Diff gelesen: IOKit „Medium Type“ über die Elternebenen in `DiskArbitrationLookup`, reine Regel `VolumeInfo.mediumType(isRemovable:deviceMedium:)`, `MediumCodecV3.updateRecognitionFields` schreibt den Typ (bekannte Medien behielten ihn sonst). Übrige Aufrufer schreiben den gespeicherten Typ unverändert zurück. Nichts Wesentliches; Stufe 2 (Zweig `denied`) → Paket 47 (`bug.0.4.231`).
- Gesamtlauf bei Last 3,7: Debug und Release 0 Warnungen, Sabotage 3/3 rot (230-a 2/2, -b 1/1, -c 1/1), keine `.ips`, 0 neue Dateien in `~/Library/Preferences`, App des Nutzers 20:38:40, Signatur gültig. Seriell und parallel 3× je **ein** roter Test (`noNewHardCodedGermanTextsInTheSources`, IOKit-Schlüssel als „deutscher Text“) → Korrektur nur im Test (drei Ausnahmen); `pruefung.sh schnell` 23:24–23:25: 0 Warnungen, grün. Alle übrigen Tests waren im Gesamtlauf grün (seriell 1236/1237, parallel je 1230/1231).
- Nachtest des Nutzers ~20:50 (App 20:38): S0–S4 bestanden („Daten I“, „Daten“ SSD; H4-Karte USB). Abnahmerunde 22:07–22:23: „Transfer“ (USB-SSD) SSD, Sticks und Karten USB.
- Patches: `archiv/sabotage/paket-46/`.

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (jetzt `archiv/sabotage/paket-46/`) (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3). Keine Gesamtläufe (Regel 13/14), nur die betroffenen Suites.

**Reihenfolge (HALT am Ende):** `bug.0.4.230`. **HALT.**

## Aufgaben

- **bug.0.4.230 — Externe SSDs erscheinen als „HDD“ (Nutzer 29.10.):**
  - **Nutzer sieht:** Jede angeschlossene externe SSD hat das HDD-Icon und in Einstellungen → Speichermedien den Typ „HDD“. Typ und Icon sind damit für SSDs falsch.
  - **Wann:** Immer, bei jeder externen SSD (USB, Thunderbolt, NVMe-Gehäuse). **Stufe 1.**
  - **Beleg (Host, nur lesend, 29.10.):**
    - „Daten I“ (SanDisk Extreme 55AE, USB, exFAT) und „Daten“ (Samsung 990 EVO Plus im Gehäuse, PCI-Express, APFS): `diskutil info` → `Removable Media: Fixed`, `Solid State: Yes`. In der App: beide HDD.
    - H4-Karte „ZOOM_H4E“ (eingebauter SD-Leser): `Removable Media: Removable`, `Solid State: Info not available` → bleibt USB.
  - **Ursache:** `VolumeInfo.mediumType` (Z. ~49) ist `isRemovable ? .usb : .hdd` (Vorgabe von 28.09., Aufgabe 38.4 Punkt 6). SSD wird nie gesetzt.
  - **Wichtig – die Angabe liegt nicht in DiskArbitration:** `DADiskCopyDescription` hat **keinen** Schlüssel „Media Solid State“ (Host geprüft für alle vier eingehängten Medien; es gibt nur `DAMediaRemovable`, `DAMediaEjectable`, `DADeviceProtocol`, `DADeviceModel` u. a.). macOS führt sie in IOKit als `"Device Characteristics"` → `"Medium Type"` mit den Werten `"Solid State"` bzw. `"Rotational"` am Gerät, **mehrere Ebenen über** dem Volume (bei APFS über Container und Partition).
  - **Geprüfter Weg (Host, Skript außerhalb des Projekts, 29.10.):**
    ```swift
    let media = DADiskCopyIOMedia(disk)          // disk aus DADiskCreateFromVolumePath
    defer { IOObjectRelease(media) }
    let value = IORegistryEntrySearchCFProperty(media, kIOServicePlane, "Device Characteristics" as CFString, nil,
                                                IOOptionBits(kIORegistryIterateParents | kIORegistryIterateRecursively))
    let type = (value as? [String: Any])?["Medium Type"] as? String
    ```
    Ergebnis: „Daten I“ → `Solid State`, „Daten“ (APFS) → `Solid State`, `/` → `Solid State`, ZOOM_H4E → `nil`, Disk-Image → `nil`.
  - **Soll (Konzept `medien.md` 2c):**
    1. Wechselbar (`isRemovable`) → **USB**, egal was IOKit sagt (Sticks und Karten bleiben USB).
    2. Sonst `"Solid State"` → **SSD**, `"Rotational"` → **HDD**, keine Angabe → **HDD**.
    3. Gelesen wird beim Bau von `VolumeInfo` (`VolumeLookup.infoSync`, schon abseits des Main Actors), z. B. als neues Feld an `DiskArbitrationAttributes`/`VolumeInfo`. Kein Plattenzugriff im Store (Invariante 8). Die Regel in 1–2 als **reine Funktion**, damit sie ohne Platte testbar ist.
    4. Speichern und Anzeige laufen über die bestehenden Wege (`MediumCoordinator` setzt `type = volume.mediumType` bei bekannten und neuen Medien; Icon `MediumTypeIcon`, Spalte `RegistryTableRow`). Bereits gespeicherte SSDs werden beim nächsten Anschließen bzw. App-Start mit angeschlossenem Medium richtig; **kein** Schema, **keine** Migration.
  - **Gegenprobe (Tests, Regel 10):**
    1. Reine Regel: wechselbar + Solid State → USB; fest + Solid State → SSD; fest + Rotational → HDD; fest + keine Angabe → HDD.
    2. **Echte Abfrage:** Die IOKit-Abfrage für `/` liefert Solid State (jeder Mac mit macOS 15 auf Apple Silicon bootet von SSD; das Startvolume ist ein APFS-Volume wie „Daten“, also prüft das die Suche über die Elternebenen). Liefert sie auf dem Rechner `nil`, wird der Test übersprungen, nicht grün gemeldet.
    3. Bekanntes Medium mit gespeichertem Typ HDD, angeschlossen mit `VolumeInfo` fest + Solid State → gespeicherter Typ und `AppState`-Medium sind SSD.
    4. Bestehende Tests zur Erkennung (`MediumCoordinator…`, `VolumeCandidate…`, Rauchtests) bleiben grün.
  - **Patches (rot erwartet):**
    1. `bug.0.4.230-a.patch`: Regel wieder `isRemovable ? .usb : .hdd`. Test 1 und 3 rot.
    2. `bug.0.4.230-b.patch`: Solid State vor „wechselbar“ prüfen. Test 1 rot (Karte/Stick würde SSD).
    3. `bug.0.4.230-c.patch`: IOKit-Suche ohne `kIORegistryIterateParents | kIORegistryIterateRecursively`. Test 2 rot.
  - **So lassen:** `IndexingVolumeTuning.isRotational` und die Zahl paralleler Lesevorgänge (liest heute denselben nicht vorhandenen Schlüssel und fällt bei USB auf 1 zurück; Änderung erst nach Entscheidung des Host, steht im Backlog). Erkennung, Kandidatenregeln, Dialoge, Icons und Asset-Namen. Kein neues Schema (vorher fragen).
  - **Status:** Bereit zur Prüfung. Ursache bestätigt, rot 19:53–19:54 (Test 1: fest + Solid State → HDD; Test 2: IOKit-Feld fehlte, `nil`; Test 3: gespeichert und angezeigt HDD). Dabei gefunden: `updateRecognitionFields` schrieb `type` nie, bekannte Medien behielten den alten Typ in der Datenbank.
    Fix: `DeviceMedium` (IOKit „Medium Type“ über die Elternebenen, Weg aus dem Paket) in `DiskArbitrationLookup.attributes` → `VolumeInfo.deviceMedium` (Vorgabe `nil`); reine Regel `VolumeInfo.mediumType(isRemovable:deviceMedium:)`; `MediumCodecV3.updateRecognitionFields` schreibt jetzt auch `type`. Kein Schema, `IndexingVolumeTuning` unverändert.
    Tests: neu `MediumTypeTests` (Test 1, Test 2 mit `.enabled(if:)` über `diskutil info -plist /` als unabhängige Voraussetzung), `MediumCoordinatorTests/knownHDDConnectedAsSolidStateBecomesSSD` (Test 3); grün 19:56; 17 betroffene Suites 195/195 (19:57–19:58).
    Sabotage `pruefung.sh sabotage` 19:58–20:00: a rot 2/2, b 1/1, c 1/1, 0 Mängel. Debug clean build-for-testing 0 Warnungen (20:00).
    Selbstprüfung: nichts Wesentliches. Stufe 2: bekanntes Medium im Fehlerstatus ohne Zugriff (Zweig `denied`) zeigt bis zur Freigabe noch den alten Typ.

## Korrektur Host 29.10. (Gesamtlauf 20:06–20:38)

- Diff gelesen: nichts Wesentliches. Die übrigen Aufrufer von `updateMediumRecognition` (Z. ~168, 217, 382, 448) gehen vom gespeicherten Medium aus und schreiben dessen Typ unverändert zurück. Stufe 2 (Zweig `denied`) → Backlog.
- Gesamtlauf: Debug und Release 0 Warnungen, Sabotage 3/3 rot, App des Nutzers 20:38:40. **Seriell und parallel 3× je 1 rot:** `EnglishLocalizationTests/noNewHardCodedGermanTextsInTheSources` meldet `DiskArbitrationLookup.swift` Z. 46, 49, 50 (`"Device Characteristics"`, `"Medium Type"`, `"Solid State"`): Das Muster hält großgeschriebene Wörter mit Leerzeichen für deutschen Oberflächentext.
- **Korrektur (nur Test, kein App-Code):** In `EnglishLocalizationTests.exceptions` (Z. ~107) drei Ausnahmen für `Recognition/DiskArbitrationLookup.swift` mit den Stücken `Device Characteristics`, `Medium Type`, `Solid State`, Grund „IOKit-Schlüssel“ (wie die bestehende Zeile für `IndexingVolumeTuning.swift`). Danach `pruefung.sh schnell EnglishLocalizationTests MediumTypeTests` grün (auch `everyExceptionStillMatchesALine`). Kein Gesamtlauf.
- **Status Korrektur:** Bereit zur Prüfung. Drei Ausnahmen in `EnglishLocalizationTests.exceptions` (`Recognition/DiskArbitrationLookup.swift`: `Device Characteristics`, `Medium Type`, `Solid State`, Grund „IOKit-Schlüssel“, direkt unter der Zeile für `IndexingVolumeTuning.swift`); kein App-Code.
  `pruefung.sh schnell EnglishLocalizationTests MediumTypeTests` 23:20–23:21: Build 0 Warnungen, 8/8 grün in 2 Suites (inkl. `noNewHardCodedGermanTextsInTheSources` und `everyExceptionStillMatchesALine`).
