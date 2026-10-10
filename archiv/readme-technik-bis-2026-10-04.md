# Technische Umsetzung — Planung, Spike-Messungen, Nutzertest (archiviert 04.10.2026)

Aus der README ausgelagert. Der aktuelle Stand steht in README, „Architektur“.

# Technische Umsetzung

Stand 2026-09-29. Ab hier ersetzt das echte Indexing die Mock-Daten. Die Oberfläche (Menüleisten-Popover, Scan-Tiefe-Slider, Prozentanzeige, Chips und Platzhalter wie „Inhalt nicht erfasst") bleibt die aus dem Layout — sie hängt künftig am echten Index, nicht an Testdaten.

### Testdaten entfallen
Sämtliche Mock-Medien, Mock-Bäume und Demo-Einträge werden entfernt. Was die App zeigt, kommt von angeschlossenen Medien und dem gespeicherten Index.

### Zwei Systemdialoge, bevor ein Medium bei uns existiert
macOS fragt selbst, bevor wir ein Medium lesen können. Beides sind Systemdialoge, nicht unsere UI:

1. **Beim Anschließen:** das System fragt, ob das Medium vom Betriebssystem verwendet werden darf.
2. **Beim ersten Zugriff durch die App:** das System fragt, ob diese Software das Medium lesen darf. Das ist die niederschwellige Freigabe pro Medium — nicht der vollständige Festplattenzugriff in den Systemeinstellungen.

Ohne diese Freigabe können wir das Medium nicht lesen. Es erscheint dann nicht in Popover, Übersicht oder Speichermedien.

> **Präzisierung (Claude, 29.09.):** Der erste Dialog stammt allein vom System; wir sehen ein Medium erst, wenn macOS es eingebunden hat. Der zweite Dialog (Datenschutz „Wechseldatenträger") erscheint automatisch beim ersten Lesezugriff der App und gilt nach bisherigem Wissen **pro App**, nicht pro Medium. Das wird im Spike geprüft. Außerdem blockiert die aktuell eingeschaltete App-Sandbox das Lesen von Medien unabhängig von diesem Dialog. Details und Entscheidung: „Technische Grundlagen und Empfehlung" weiter unten.

### Danach unser Dialog
Erst wenn das System den Zugriff erteilt hat, erscheint unser Dialog aus dem Layout (Sektion 02): „Indizieren" oder „Nicht indizieren". Er ist unabhängig davon, ob das Hauptfenster offen ist (Entscheidung vom 2026-09-20). Vergleichbar mit Dropbox, das beim Anschließen fragt, ob ein Medium synchronisiert oder nur heruntergeladen werden soll: das System hat den Datenträger schon freigegeben, die App fragt danach, was sie damit tun soll.

„Nicht indizieren" lässt das Medium unangetastet. „Indizieren" startet den Lauf unten.

### Schichtweise lesen, nicht in die Tiefe zuerst
Ein Lauf geht Ebene für Ebene vor, nicht Ordner für Ordner bis zum Grund.

Nicht so: Root öffnen, den ersten Ordner finden, in ihn hineingehen, dort den nächsten Ordner finden, und so weiter, bis dieser Ast zu Ende ist.

Sondern so:

1. Medium ist angeschlossen und zum Indizieren freigegeben.
2. Den Inhalt des Root lesen und speichern: Dateien und die Ordner, die direkt dort liegen. Das ist Ebene 1.
3. Erst wenn Ebene 1 steht, die Ordner dieser Ebene nacheinander öffnen und jeweils nur ihren direkten Inhalt speichern. Das ist Ebene 2. Nicht in die Ordner hineinspringen, die dabei neu auftauchen.
4. Dieselbe Runde für die nächste Ebene, dann die übernächste.

Jede abgeschlossene Ebene wird gespeichert, bevor die nächste beginnt. Bricht die Verbindung ab, bleibt alles bis zur letzten fertigen Ebene erhalten.

Der Lauf endet, wenn eine der Grenzen erreicht ist:

- keine tiefere Ebene mehr,
- die Scan-Tiefe aus Einstellungen → Allgemein (1–5, „5+" = keine Tiefengrenze),
- das Medium ist nicht mehr lesbar (getrennt, ausgeworfen, Freigabe entzogen).

Ordner jenseits der Scan-Tiefe bleiben als „Inhalt nicht erfasst" sichtbar, wie im Layout. Die oberste Ebene eines Mediums ist immer erfasst.

### Warum schichtweise
Eine Platte hängt oft nur kurz. Dann sollen mindestens die ersten beiden Ebenen schon da sein — nicht ein einzelner Ordner bis in die letzte Unterebene, während der Rest des Root noch leer ist.

### Was die bestehende Oberfläche dabei zeigt
Popover, Übersicht, Suche und Speichermedien lesen denselben Index. Die Prozentanzeige ist der Fortschritt dieses Speicherns, solange ein Lauf läuft. Der Scan-Tiefe-Slider ist die Grenze, bis zu der eine neue Ebene überhaupt gelesen wird.

## Technische Grundlagen und Empfehlung (Claude, 2026-09-29)

Antwort auf die offenen Technikfragen aus der Skizze oben. Was am echten Gerät geprüft werden muss, ist mit **(Spike)** markiert. Aufgabe 35 in [prompt.md](prompt.md) misst genau diese Punkte.

### Bausteine auf einen Blick

| Aufgabe | Technik | Warum |
|---|---|---|
| Medium wird angeschlossen / abgezogen | `NSWorkspace`-Benachrichtigungen (`didMount`, `willUnmount`, `didUnmount`); beim App-Start zusätzlich `FileManager.mountedVolumeURLs`. Optional DiskArbitration für Gerätedetails (Bus, Dateisystem, Modell) | Ereignisbasiert, kein Abfragen im Takt |
| Medium wiedererkennen | Volume-UUID (`volumeUUIDStringKey`); Ersatz: Name + Größe + Dateisystem **(Spike: gibt es die UUID auch bei FAT/exFAT/NTFS?)** | Die Kennung steckt im Dateisystem, der Name ändert sich |
| Darf die App lesen? | Datenschutz-Kategorie „Wechseldatenträger" plus App-Sandbox | Zwei voneinander unabhängige Sperren, siehe unten |
| Ebene für Ebene lesen | Eigener Scanner mit Warteschlange je Ebene, `FileManager.contentsOfDirectory` mit vorab geladenen Attributen | Volle Kontrolle über Reihenfolge, Abbruch und Fortschritt |
| Änderungen live mitbekommen | FSEvents, dateigenau, auf dem Volume | Die macOS-eigene Meldung für Dateiänderungen |
| Zustand beim Wiederanschließen | Ebenenweiser Vergleichslauf gegen den gespeicherten Stand | Findet auch Änderungen, die ein anderer Rechner gemacht hat |
| Speicherung | SQLite in einer Datei, Zugriff über GRDB.swift | Kein Server nötig, transaktionssicher, schnell bei Millionen Zeilen |
| Namenssuche | SQLite FTS5 mit Trigram-Tokenizer **(Spike)** | Teilstring-Suche wie heute („enthält"), aber indiziert |

Zum PHP-Vergleich: MySQL wäre ein eigener Server. Hier passt eine eingebettete Datenbank, und SQLite gehört schon zu macOS. SwiftData wird nicht verwendet (die Projektvorlage nutzt es nicht, und es ist für Millionen Einträge und Teilstring-Suche nicht geeignet).

### Ablauf beim Anschließen

1. **Ereignis:** Ein Volume wird eingebunden. Die App sammelt Name, Einhängepfad, UUID, Größe, intern/extern und Dateisystem.
2. **Filter:** Kandidat ist ein lokales Volume, das wechselbar **oder** auswerfbar **oder** nicht intern ist. Der Einhängepfad beginnt mit `/Volumes/`. Ausgeschlossen: `/`, alles unter `/System/Volumes/` (auch die kurzen Systemeinhängungen wie `/System/Volumes/Update/mnt1` und `/private/tmp/tmp-mount-…`, die bei jedem Systemupdate-Check als `didMount` auftauchen), Netzlaufwerke (`autofs`), Disk-Images und Time-Machine-Snapshots. „Nur extern“ reicht nicht: Der eingebaute SD-Kartenleser meldet Karten als **intern** (Messung vom 30.09.).
3. **Bekannt?** UUID steht in der Datenbank: Die gespeicherte Entscheidung („Indizieren" oder „Nicht indizieren", ggf. „merken") gilt, weiter mit Schritt 7.
4. **Unbekannt: Zugriffsprobe.** Die App versucht, das Wurzelverzeichnis zu lesen. Beim ersten Mal zeigt macOS dabei den Systemdialog. Wir können ihn nicht selbst auslösen oder vorher abfragen. Das Ergebnis der Probe sagt uns, ob wir dürfen.
5. **Probe gelungen:** Unser Dialog aus dem Layout (Sektion 02). **Probe verweigert:** kein Dialog. Das Medium erscheint mit Zustand „Zugriff fehlt", mit Verweis auf die Systemeinstellungen (Datenschutz → Wechseldatenträger). Bei jedem erneuten Anschließen wird die Probe wiederholt.
6. **„Indizieren":** Lauf ebenenweise (siehe oben), jede fertige Ebene wird gespeichert. **„Nicht indizieren":** Das Medium wird vermerkt und nie gelesen.
7. **Bekanntes Medium ist wieder da: Abgleich.** Ebene für Ebene neu lesen und mit dem gespeicherten Stand vergleichen (neu, geändert, weg). Der alte Stand bleibt dabei sofort durchsuchbar, der Abgleich läuft im Hintergrund. Die Oberfläche zeigt dafür denselben Chip „wird indiziert" wie beim ersten Lauf, es gibt keinen neuen Zustand.
8. **Solange verbunden:** FSEvents-Überwachung. Geänderte Ordner werden nachgelesen, gebündelt nach ca. 1 bis 2 Sekunden Ruhe. Ordner tiefer als die Scan-Tiefe und ignorierte Objekte werden übersprungen.
9. **Abziehen:** Überwachung stoppen, Zeitpunkt und Ereignisstand speichern, Medium wird „Offline". Der Index bleibt durchsuchbar. Bricht ein Lauf durch Abziehen ab, setzt er beim nächsten Anschließen nach der letzten fertigen Ebene fort.

### Änderungen, Löschen, Wiederherstellen

- **Zeilen werden nie gelöscht, sondern mit `removedAt` markiert.** Taucht derselbe Pfad wieder auf („wiederhergestellt"), wird die Markierung aufgehoben. Favoriten und Ignorier-Markierungen bleiben dabei erhalten. Deshalb immer aktualisieren statt löschen und neu anlegen.
- **Verschieben und Umbenennen** erkennt die Datei-ID (nur APFS/HFS+). Bei FAT/exFAT gilt es als Löschen plus Neu.
- **Ausgeschlossen:** `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `.TemporaryItems`, `.DocumentRevisions-V100` und alle Namen, die mit `._` beginnen (Begleitdateien auf FAT/exFAT). Ein Objekt im Papierkorb des Mediums zählt damit als „weg", zurücklegen als „wieder da".
- **Die App schreibt nie auf das Medium.**
- **Grenze von FSEvents:** Es meldet nur Änderungen, die dieser Mac macht, solange das Medium hängt. Was ein anderer Mac ohne Disk Index, ein Windows-PC oder eine Kamera ändert, findet nur der Abgleich. Deshalb ist der **Abgleich beim Anschließen immer die Wahrheit**. FSEvents ist die Beschleunigung für die Zeit dazwischen. Ob sich FSEvents mit gespeicherter Ereignis-ID auf externen Medien nachträglich abspielen lässt (Zeitersparnis beim Wiederanschließen), klärt der Spike; darauf verlässt sich das Konzept nicht.

### Scan-Regeln (festgelegt für Aufgabe 39)

- **Ebenen:** Ebene 1 = Inhalt der Wurzel. Tiefe *d* = *d* Ebenen mit Inhalt, die Ordner der letzten Ebene bleiben ungeöffnet („Inhalt nicht erfasst“).
- **Pakete** (`.app` u. a.) zählen als Datei und werden nicht betreten, wie im Finder. **Symbolische Links** werden nicht verfolgt.
- **Nie gespeichert:** `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `.TemporaryItems`, `.DocumentRevisions-V100`, `._…`. Versteckte Einträge nur, wenn „unsichtbare Dateien“ eingeschaltet ist. Zusätzlich die Ausschlussliste aus den Einstellungen.
- **Fehler:** Ein nicht lesbarer Ordner wird übersprungen, ohne seinen bisherigen Inhalt als entfernt zu markieren. Nur ein erfolgreich gelesener Ordner ist die Wahrheit. Ist die Wurzel nicht lesbar, ist das Medium im Zustand Fehler.
- **Abziehen mitten im Lauf:** Der Lauf bricht leise ab und setzt beim nächsten Anschließen nach der letzten fertigen Ebene fort.
- **Nur Leseoperationen auf dem Medium.** (macOS selbst legt auf angeschlossenen Medien eigene Dateien wie `.fseventsd` an, das ist nicht die App.)

### Speicherung

Eine Datei `index.sqlite` im Application-Support-Ordner der App. Kein iCloud, kein CloudKit. Grobes Schema:

- `medium`: Volume-UUID, Name, Typ, Kapazität, Entscheidung, Verbindungs- und Indexstatus, erster/letzter Lauf, zuletzt gesehen, Ereignisstand (FSEvents-UUID und letzte Ereignis-ID), Favorit, Pausiert. Weitgehend die vorhandene Struktur `Medium`.
- `item`: id, mediumID, parentID, Name, Ordner ja/nein, Endung, Größe, Änderungsdatum, Datei-ID, Ebene, zuletzt gesehen, `removedAt`, Favorit.
- Anforderungen: Schreiben in einer Transaktion je Ebene, Lesen aus der Oberfläche ohne Blockierung (WAL-Modus), Index auf (Medium, Eltern), Trigram-Index auf dem Namen, Index auf Änderungsdatum. Pfade werden für Ergebnislisten mitgespeichert.
- Suche, Filter, Spaltenansicht und Favoriten behalten ihre heutige Logik und bekommen nur eine echte Datenquelle statt der Mock-Daten.

### Messergebnisse Spike, Zwischenstand (2026-09-30)

Gemessen mit einer SD-Karte (32 GB, FAT32 = „msdos“) im eingebauten Kartenleser, App-Sandbox an.

**Gesichert**
- **Erkennen:** `NSWorkspace.didMountNotification` kommt in der Sandbox an, rund 0,4 s nach dem ersten DiskArbitration-Ereignis. DiskArbitration meldet zuerst nur das Gerät ohne Einhängepfad, den Pfad liefert es erst später. Für „Medium ist da“ wird deshalb `NSWorkspace` genommen, DiskArbitration nur für Gerätedetails.
- **Kartenleser zählt als „intern“:** Die Karte hat `intern=ja`, zugleich `wechselbar=ja` und `auswerfbar=ja`. Der Filter in Schritt 2 (Ablauf) ist deshalb angepasst.
- **Keine Volume-UUID bei FAT32:** `volumeUUIDStringKey` ist für die Karte leer, nur APFS-Volumes haben eine. `diskutil info` bestätigt es: Die „Volume UUID“ der Karte ist `00000000-0000-0000-0000-000000000000` (Null-UUID, das Dateisystem wurde vom Aufnahmegerät ohne Seriennummer angelegt). FAT und exFAT sind bei Sticks und Karten Standard. Ein Ersatz für die UUID ist damit **nötig**, keine Randfrage. Eine Null-UUID zählt als „keine UUID“.
- **Weitere Merkmale der Karte (`diskutil`):** Partitionstyp `Windows_FAT_32`, Partitionsbeginn 4 194 304 Byte, Größe des ganzen Datenträgers 31 910 789 120 Byte, Volume-Größe 31 902 433 280 Byte, Protokoll „Secure Digital“, „Solid State: Info not available“. Der Datenträgertyp (SSD/HDD) ist hier also nicht ermittelbar, bei Karten ist USB-Stick/Karte ohnehin die passende Art.
- **Lesen in der Sandbox:** Das Wurzelverzeichnis der Karte zu lesen scheitert mit Fehler 257 / POSIX 1 („Operation not permitted“) nach 2 ms, ohne Systemdialog. Das deckt sich mit der Erwartung, ist aber erst bewiesen, wenn der Lauf ohne Sandbox gelingt.
- **SQLite (von Cursor mit synthetischen Daten gemessen):** SQLite 3.43.2, FTS5 und Trigram vorhanden. Einfügen rund 1,3 Mio. Zeilen pro Sekunde, Trigram-Index für 1 Mio. Zeilen in 1,4 s. Die Suche „foto“ und „rechn“ trifft über den Index, bei nur zwei Buchstaben („ab“) muss auf `LIKE` ausgewichen werden. **SQLite und FTS5 sind damit bestätigt.**

**Nicht belastbar**
- Der einzige „Erfolg“ beim Lesen (23:57:38, 5 Einträge) nennt kein Volume. Vermutlich war ein Systemvolume gewählt. Nicht als Beleg für Zugriff auf Medien werten.
- Die DiskArbitration-UUID steht überall auf „—“, auch bei APFS. Das ist ein Fehler im Messwerkzeug: DiskArbitration liefert eine `CFUUID`, keinen String. Wird nachgebessert (Aufgabe 35, Korrekturen).

**Zweiter Bericht (2026-09-30, gleiche SD-Karte, Sandbox weiterhin an)**
- **Kandidatenregel greift:** Die Karte ist „Kandidat=ja“, 8 interne Einträge werden ausgeblendet. Die DiskArbitration-UUID wird jetzt richtig gelesen und ist bei der Karte die Null-UUID, wie `diskutil` sie zeigt.
- **Sandbox blockiert das Lesen, jetzt eindeutig:** Abschnitt B und C scheitern mit dem ausdrücklichen Ziel „ZOOM_H4E“ (Fehler 257 / POSIX 1, 2 ms, kein Dialog). Der „Erfolg“ im ersten Bericht war ein anderes Volume. Weder Scan (C) noch FSEvents-Ereignisse (D) konnten so etwas messen.
- **Neuer Fund zur Kennung:** Für die FAT32-Karte liefert macOS trotz Null-UUID zwei brauchbare Merkmale:
  - `volumeIdentifierKey` = `0x4a8c900100000000` (8 Byte). Dieselben Bytes stecken in der Datei-ID des Wurzelverzeichnisses. ⚠️ *Vermutung „Seriennummer des Dateisystems“ am 30.09. widerlegt (siehe „Vierter Bericht“): Der Wert ändert sich bei jedem Einbinden.*
  - `volumeCreationDateKey` = 2024-06-11 11:26:44 Z, passt zum Formatierzeitpunkt, aus dem FAT die Seriennummer bildet.
  - Nicht brauchbar: `statfs.f_fsid` (`16777237,24`, hängt vom Gerät ab), Datei-IDs (auf FAT nicht dauerhaft, `persistenteIDs=nein`), DiskArbitration-`mediaUUID` (leer), `mediaName` („Untitled 1“).
  - **Noch zu bestätigen:** Der Wert muss nach Auswerfen und erneutem Einstecken (auch an einem anderen Kartenleser) gleich bleiben.
- **FSEvents-UUID** ist für die Karte vorhanden (`309782D4-…`, aktuelle Ereignis-ID 542287174), das Nachspielen ist noch nicht gemessen.
- **SQLite:** Der Lauf des Nutzers deckt sich mit Cursors Zahlen (100 000 Zeilen in 0,12 s, 1 Mio. in 1,2 s, FTS-Aufbau 2,3 s, Suchen unter 10 ms, 1 Mio. Zeilen).

**Dritter Bericht (2026-09-30, gleiche SD-Karte, Sandbox aus, aus Xcode gestartet)**
- **Zugriff:** Das Wurzelverzeichnis der Karte lässt sich lesen (17 Einträge, 2 ms), **ohne** dass ein Systemdialog erschien. Mit Sandbox an war dieselbe Probe verboten. Damit ist belegt: Die Sandbox ist das Hindernis. **Einschränkung:** Aus Xcode gestartete Apps werden bei der Datenschutzabfrage oft Xcode zugerechnet, und Xcode hat möglicherweise schon eine Freigabe. „Kein Dialog“ ist deshalb noch nicht die Antwort für die fertige App (Kontrolle: das gebaute `Disk Index.app` einmal direkt aus dem Finder starten).
- **Kennung:** Die Datei-ID der ersten Datei (`ZOOM.SYS`) trägt in den letzten 8 Bytes dieselbe Zahl `4a8c900100000000` wie die `volumeIdentifier`. ⚠️ *Die Schlussfolgerung „Seriennummer“ ist falsch, siehe „Vierter Bericht“. Es ist eine Kennung der Einbindung.*
- **Scan:** 3 Ebenen der Karte in 0,09 s (27 Objekte, 14 Ordner). Die Karte ist zu klein für eine Leistungsaussage; der Richtwert „5 000 Objekte pro Sekunde“ misst hier nur den festen Aufwand je Ordner (rund 1,5 ms). Für Zahlen braucht es ein größeres Medium, am besten eine USB-Platte.
- **FSEvents auf dem externen Volume funktioniert dateigenau.** Beim Kopieren einer Datei kamen sofort (unter 10 ms) die Ereignisse „angelegt, Datei“, „geändert“ und ein zweites für die Begleitdatei `._…`. Strom, Ereignis-ID und Volume-UUID (`309782D4-…`) ließen sich beim Auswerfen speichern (`willUnmount`, Ereignis-ID 542326908).
- **`._`-Begleitdateien:** Auf FAT legt macOS für jede kopierte Datei eine versteckte Datei `._Name` an. Sie erscheint in Scans und Ereignissen und ist **kein** Nutzerinhalt. Der Scanner schließt Namen mit `._` am Anfang immer aus (zusätzlich zu den Ausschlüssen unten).
- **Auswerfen:** Die Reihenfolge ist `willUnmount` → `didUnmount` (rund 0,7 s später) → DiskArbitration „verschwunden“. Wird eine Karte **abgezogen, ohne auszuwerfen**, gibt es kein `willUnmount`. Der Ereignisstand darf deshalb nicht nur beim Auswerfen gesichert werden, sondern **laufend** (gebündelt alle paar Sekunden und nach jedem verarbeiteten Ordner).
- **Noch nicht gemessen:** Nachspielen der Ereignisse nach dem Wiedereinstecken und die Kennung nach dem Wiedereinstecken. Beide Punkte stehen im nächsten kurzen Durchgang.

**Dritter Bericht (2026-09-30, gleiche SD-Karte, Sandbox aus, aus Xcode gestartet)**
- **Zugriff:** Das Wurzelverzeichnis der Karte lässt sich lesen (17 Einträge, 2 ms), **ohne** dass ein Systemdialog erschien. Mit Sandbox an war dieselbe Probe verboten. Damit ist belegt: Die Sandbox ist das Hindernis. **Einschränkung:** Aus Xcode gestartete Apps werden bei der Datenschutzabfrage oft Xcode zugerechnet, und Xcode hat möglicherweise schon eine Freigabe. „Kein Dialog“ ist deshalb noch nicht die Antwort für die fertige App (Kontrolle: das gebaute `Disk Index.app` einmal direkt aus dem Finder starten).
- **Kennung:** Die Datei-ID der ersten Datei (`ZOOM.SYS`) trägt in den letzten 8 Bytes dieselbe Zahl `4a8c900100000000` wie die `volumeIdentifier`. ⚠️ *Die Schlussfolgerung „Seriennummer“ ist falsch, siehe „Vierter Bericht“. Es ist eine Kennung der Einbindung.*
- **Scan:** 3 Ebenen der Karte in 0,09 s (27 Objekte, 14 Ordner). Die Karte ist zu klein für eine Leistungsaussage; der Richtwert „5 000 Objekte pro Sekunde“ misst hier nur den festen Aufwand je Ordner (rund 1,5 ms). Für Zahlen braucht es ein größeres Medium, am besten eine USB-Platte.
- **FSEvents auf dem externen Volume funktioniert dateigenau.** Beim Kopieren einer Datei kamen sofort (unter 10 ms) die Ereignisse „angelegt, Datei“, „geändert“ und ein zweites für die Begleitdatei `._…`. Strom, Ereignis-ID und Volume-UUID (`309782D4-…`) ließen sich beim Auswerfen speichern (`willUnmount`, Ereignis-ID 542326908).
- **`._`-Begleitdateien:** Auf FAT legt macOS für jede kopierte Datei eine versteckte Datei `._Name` an. Sie erscheint in Scans und Ereignissen und ist **kein** Nutzerinhalt. Der Scanner schließt Namen mit `._` am Anfang immer aus (zusätzlich zu den Ausschlüssen unten).
- **Auswerfen:** Die Reihenfolge ist `willUnmount` → `didUnmount` (rund 0,7 s später) → DiskArbitration „verschwunden“. Wird eine Karte **abgezogen, ohne auszuwerfen**, gibt es kein `willUnmount`. Der Ereignisstand darf deshalb nicht nur beim Auswerfen gesichert werden, sondern **laufend** (gebündelt alle paar Sekunden und nach jedem verarbeiteten Ordner).
- **Noch nicht gemessen:** Nachspielen der Ereignisse nach dem Wiedereinstecken und die Kennung nach dem Wiedereinstecken. Beide Punkte stehen im nächsten kurzen Durchgang.

**Kennung, überarbeiteter Entwurf** (ersetzt den Punkt 2 unten, sobald das Wiedereinstecken bestätigt ist): 1. Volume-UUID, wenn vorhanden und nicht Null. 2. Sonst **Dateisystem + `volumeIdentifier` + Erstelldatum**. 3. Sonst Größe + Name mit der Prüfung der obersten Ebenen. Damit ist der Fall „zwei Karten desselben Aufnahmegeräts“ voraussichtlich kein Problem mehr, weil sie zu verschiedenen Zeitpunkten formatiert wurden.

**Vierter Bericht (2026-09-30): Wiedereinstecken zeigt, welche Kennungen der FAT-Karte taugen**

Dieselbe Karte, dreimal eingebunden (23:55, 08:21, 08:27), gemessen mit Sandbox aus:

| Merkmal | 1. Einbindung | 2. Einbindung | 3. Einbindung | taugt? |
|---|---|---|---|---|
| `volumeIdentifier` | `4a8c9001…` | `205ea001…` | `baa8a101…` | **nein**, ändert sich bei jeder Einbindung (die 8 Byte stecken auch in allen Datei-IDs; passt zu `persistenteIDs=nein`) |
| `volumeUUIDString` (URL) | leer | leer | `367F151D-75EB-414B-80EE-…` | **nein**, meist leer, einmal eine Zufalls-UUID (Version 4) |
| UUID laut `diskutil` / DiskArbitration | Null-UUID | Null-UUID | Null-UUID | **nein**, immer Null |
| `volumeCreationDate` | 2024-06-11 11:26:44 Z | gleich | gleich | **ja**, in allen Lesungen identisch |
| Gesamtgröße Volume | 31 902 433 280 | gleich | gleich | ja (aber nicht einzigartig) |

**Fünfter Bericht (2026-09-30): zweites Medium, USB-Stick „NO NAME“ (FAT32, `intern=nein`, `extern=ja`)**

| Merkmal | ZOOM_H4E (SD-Karte) | NO NAME (USB-Stick) |
|---|---|---|
| Volume-UUID laut `diskutil` / System | **Null-UUID** | `6BD83668-6281-3EEE-99D2-DBA062DAB8E9` |
| Art der UUID | – | Version 3 (aus einem Wert abgeleitet, also **fest**) |
| `volumeUUIDStringKey` (URL) | leer, einmal Zufalls-UUID (Version 4) | gleiche UUID wie `diskutil` |
| Erstelldatum | 2024-06-11 11:26:44 | 1980-03-12 22:03:36 (Fabrikwert) |
| Kartenleser / Anschluss | intern (eingebauter Leser) | extern (USB) |
| `volumeIdentifier` | wechselt je Einbindung | wechselt je Einbindung |

**Folgerungen**
- **Bei FAT hängt es vom Datenträger ab:** Hat die Formatierung eine Seriennummer, leitet macOS daraus eine feste **Version-3-UUID** ab (USB-Stick). Ist die Seriennummer 0, ist die UUID Null (Karte des Aufnahmegeräts). Meine erste Regel „bei FAT/exFAT die UUID ignorieren“ war damit zu streng, die zweite Vermutung „Seriennummer steckt im `volumeIdentifier`“ war falsch.
- **Quelle der UUID ist DiskArbitration, nicht der URL-Schlüssel.** `diskutil` und DiskArbitration geben für ZOOM durchgehend Null zurück. Der URL-Schlüssel lieferte dort einmal eine Zufalls-UUID.
- **`volumeIdentifier` und Datei-IDs** sind auf FAT nur für die laufende Einbindung gültig und werden nie gespeichert.
- **Erstelldatum:** stabil (bei ZOOM in allen Lesungen gleich), aber bei Fabrik-formatierten Sticks ein Fabrikwert und darum nur Ersatzmerkmal.
- **Der Kartenleser gilt als intern, der USB-Stick als extern.** Beide gehen durch die Kandidatenregel (wechselbar oder auswerfbar oder nicht intern).

**Kennung, endgültiger Entwurf**
1. **UUID des Systems** (aus DiskArbitration, Null-UUID = keine): Wenn beide Seiten eine haben, ist gleiche UUID = gleiches Medium und **verschiedene UUIDs = verschiedene Medien**, auch wenn Größe und Erstelldatum übereinstimmen (Schutz vor Fabrik-Klonen).
2. **Ersatz ohne UUID:** Dateisystem + **Erstelldatum (auf die Sekunde)** + Volume-Größe in Bytes. Gilt nur, wenn auf mindestens einer Seite keine UUID vorhanden ist. Umbenennen ändert die Kennung nicht. Ein Erstelldatum, das fehlt oder genau dem Beginn der FAT-Zeitrechnung (1980-01-01) oder 1970-01-01 entspricht, zählt als nicht vorhanden.
3. **Gar kein Erstelldatum:** Größe + Name, mit Prüfung der ersten zwei Ebenen. Bei unsicherem Ergebnis fragt die App einmal („Ist das dieselbe Karte wie …?“, noch nicht im Layout, noch nicht bestätigt).
4. **Immer alle Merkmale prüfen und sammeln:** Gefunden wird per Vereinigung, die stärkste Übereinstimmung gewinnt. Neu gesehene Merkmale werden am Medium nachgetragen (etwa eine UUID, die erst später erscheint).
5. Die Datenbank speichert dafür `volumeUUID` und `volumeCreatedAt` (Aufgabe 37).

**Typ HDD / SSD / USB (Regel, wie bestätigt):** Ist das Medium **wechselbar** (Stick, Karte), gilt „USB“. Alles andere gilt als „HDD“ und ist später in den Medium-Details änderbar. SSD ist hinter USB-Gehäusen nicht erkennbar (`Solid State: Info not available`).

**Nicht gemessen und nicht nötig für die Entscheidung:** Nachspielen der Ereignisse nach dem Wiedereinstecken (das Konzept verlässt sich nicht darauf), Systemdialog bei einer nicht aus Xcode gestarteten App (die Zugriffsprobe behandelt beide Ausgänge), USB-Platte (nur für Scan-Leistung, eine Leistungsaussage braucht ein größeres Medium).

**Systemdialog „Wechseldatenträger“ (Test 30.09., App aus dem Finder, Freigabe vorher mit `tccutil reset` gelöscht, App neu gestartet):** Bei der **SD-Karte im eingebauten Leser** erschien **kein** macOS-Dialog, nur unser Dialog. Der eingebaute Leser meldet Karten als „intern“, möglicherweise gilt der Schutz dort nicht. **Beim USB-Stick (extern) erscheint er:** „Disk Index“ möchte Zugriff auf Dateien auf einem Wechselmedium. Darunter steht unser Text aus `NSRemovableVolumesUsageDescription`, Knöpfe „Nicht erlauben“ / „Erlauben“. Danach folgt unser Dialog. Die Reihenfolge entspricht also dem Konzept (erst Systemdialog, dann unserer), aber **nur bei externen Medien**. Beim eingebauten Kartenleser fehlt der Systemdialog. Die Zugriffsprobe behandelt beide Ausgänge.

**Noch offen (nicht blockierend):** Scan-Leistung an einem größeren Medium (USB-Platte), Verhalten von exFAT. Die Entscheidung Sandbox aus (Weg A) und die Kennungsstrategie stehen.

**Entwurf Kennung ohne UUID** (wird nach den weiteren Messungen bestätigt):
1. Volume-UUID, wenn vorhanden und nicht Null.
2. Sonst Fingerabdruck aus Dateisystem, Größe in Bytes und Name (ggf. Erstelldatum, wenn die Messung eines liefert).
3. Trifft ein Fingerabdruck auf ein **Offline-Medium**, prüft die App die oberste Ebene: Sind mindestens die Hälfte der gespeicherten Namen vorhanden, ist es dasselbe Medium, sonst ein neues. So werden zwei gleich benannte Karten gleicher Größe („NO NAME“, 32 GB) nicht verwechselt.
4. Zwei gleichzeitig angeschlossene Volumes mit gleichem Fingerabdruck sind immer zwei Medien.
5. **Grenze des Verfahrens:** Zwei Karten desselben Aufnahmegeräts (gleicher Name, gleiche Größe, gleiche Ordner wie `FOLDER01`) sind auf oberster Ebene kaum zu unterscheiden. Deshalb vergleicht die Prüfung in Schritt 3 die ersten **zwei** Ebenen mit Dateinamen. Ist die Übereinstimmung unsicher (Vorschlag: zwischen 30 und 90 %), fragt die App einmal: „Ist das dieselbe Karte wie …?“ (Ja / Nein, neues Medium). Sonst würde ein Medium mit dem Verlauf eines anderen vermischt. Der Dialog ist noch nicht im Layout und noch nicht bestätigt.

### Nutzertest (nach Abschluss der Aufgaben 39, 41, 43, 44, 40)

Ein durchgehender Ablauf mit leerer Datenbank. Bei jedem Schritt steht, was passieren soll. Weicht etwas ab, bitte Screenshot und den Schritt nennen.

**Vorbereitung:** Im Terminal `Werkzeuge/testzustand-zuruecksetzen.sh --mit-freigabe` ausführen (beendet die App, löscht die Datenbank und die macOS-Freigabe). Die frisch gebaute `Disk Index.app` aus dem Build-Ordner **im Finder** starten. Der USB-Stick ist noch nicht angesteckt.

| Schritt | Aktion | Erwartet |
|---|---|---|
| 1 | App starten, Hauptfenster öffnen | Übersicht leer mit Text „Noch kein Speichermedium erfasst“. Menüleisten-Popover: „Kein Speichermedium angeschlossen“. Keine Testmedien. |
| 2 | USB-Stick anstecken | macOS-Dialog „Disk Index möchte Zugriff auf Dateien auf einem Wechselmedium“: **Erlauben**. Dann unser Dialog „Neues Speichermedium erkannt“ mit „NO NAME“, USB, Größe. |
| 3 | „Für dieses Medium merken“ an lassen, **Indizieren** | Popover und Übersicht: Stick „wird indiziert“, Fortschritt steigt gleichmäßig (springt **nicht** sofort auf 99 %), danach fertig ohne Chip. Menüleisten-Symbol zeigt währenddessen den Ring. |
| 4 | Spaltenansicht öffnen (Stick anklicken) | Ordner und Dateien wie im Finder (ohne versteckte Dateien). Klick auf einen Ordner öffnet die nächste Spalte. Ordner an der Tiefengrenze sind gelb. |
| 5 | Suchen (Enter) nach einem Dateinamen vom Stick, Dateityp-Filter setzen, ein Objekt per Rechtsklick als Favorit markieren | Treffer stimmen, Favorit erscheint in der Favoritenansicht. |
| 6 | Stick im Finder **auswerfen** | Medium wird offline, bleibt durchsuchbar, Spaltenansicht zeigt den Offline-Hinweis. |
| 7 | Stick wieder anstecken | **Kein** Dialog. Kurz „wird indiziert“ (Abgleich), danach genauso wie vorher. |
| 8 | Auf dem Stick im Finder eine Datei anlegen, umbenennen, löschen | Nach etwa 3 Sekunden ist die Änderung in Spaltenansicht und Suche zu sehen. |
| 9 | App beenden, am Stick eine Datei löschen (Finder), App starten | Nach dem Abgleich fehlt die Datei im Index. |
| 10 | SD-Karte anstecken | Dialog „Neues Speichermedium erkannt“ für „ZOOM_H4E“. **Nicht indizieren** wählen: Medium bleibt in der Liste ohne Inhalt. |
| 11 | App beenden und neu starten | Beide Medien erscheinen wieder, Einstellungen (Scan-Tiefe) bleiben erhalten. |
| 12 | Einstellungen → Scan-Tiefe auf 2, dann auf „5+“ | Ansicht zeigt weniger bzw. nach „Neu indizieren“ alle Ebenen. |

### Bausteine in der App

`MediumMonitor` (Anschließen/Abziehen) · `AccessProbe` (Zugriffsprobe) · `IndexStore` (Datenbank, ein Akteur) · `Indexer` (ebenenweiser Scanner) · `ChangeWatcher` (FSEvents) · `Reconciler` (Abgleich). Jeder Baustein bleibt einzeln testbar und läuft abseits des Hauptthreads.

### Berechtigung und Vertrieb: Entscheidung nötig

Die App läuft aktuell mit **App-Sandbox** (Xcode-Standard, „vom Nutzer gewählte Dateien: lesen"). So kann sie `/Volumes/<Medium>` nicht lesen, auch wenn macOS die Freigabe „Wechseldatenträger" erteilt. Zwei Wege:

- **A. Direktvertrieb** (Developer ID, notarisiert), Sandbox aus. Kein zusätzlicher Schritt für den Nutzer: automatisch erkennen, lesen, live überwachen, genau wie in der Skizze. Einziger Dialog ist der macOS-Dialog für Wechseldatenträger. Kein Mac App Store.
- **B. Mac App Store**, Sandbox an. Für jedes neue Medium einmal ein Öffnen-Dialog („Ordner auswählen", danach als Lesezeichen gemerkt). Unser Dialog „Indizieren" würde dorthin führen. Ein zusätzlicher Klick pro Medium; automatisches Erkennen bleibt.

**Entscheidung Nutzer (30.09.): A, ohne Sandbox.** Belegt durch den Spike: Mit Sandbox ist das Lesen einer Karte verboten (Fehler 257), ohne Sandbox klappt es. Der Zugriff auf Medien liegt hinter einer kleinen eigenen Schnittstelle (`MediumAccess`, Aufgabe 38), damit sich später eine App-Store-Variante (Sandbox, Ordner-Freigabe je Medium) mit einem kleinen Test prüfen lässt, ohne die Architektur zu ändern. Für die Weitergabe, gleich ob Direktvertrieb oder App Store, ist das Apple Developer Program nötig (ca. 99 US-Dollar pro Jahr). Für Entwicklung und Test auf dem eigenen Mac nicht.

### Weitere Punkte (vom Nutzer am 29.09. bestätigt)

- **Fortschritt (Prozent und „N / M Dateien"):** Vor dem Lesen ist die Gesamtzahl unbekannt. Vorschlag: Prozent = abgeschlossene Ordner ÷ bisher entdeckte Ordner, nie fallend. „N / M Dateien" mit M = bisher entdeckt (wächst mit). Bei Abgleichläufen ist der Stand des letzten Laufs die Bezugsgröße und damit verlässlicher.
- **Typ HDD / SSD / USB:** Best effort. Wechselbare Medien (Stick, SD) sind erkennbar, HDD und SSD hinter einem USB-Gehäuse oft nicht **(Spike)**. Vorschlag: Standard „HDD", später in den Medium-Details änderbar.

### Umsetzungsreihenfolge

35 Spike, 36 Speicher, 37 Kennung, 38 Erkennung, 42 Erkennungs-Dialog (alle erledigt) → 39 Scanner (Korrekturen offen) → 41 Medien, Einstellungen, Leerzustände, Testmedien raus → 43 Spaltenansicht auf echtem Index → 44 Suche, Favoriten, Popover auf echtem Index, Testdaten löschen → 40 Live-Änderungen und Abgleich.
