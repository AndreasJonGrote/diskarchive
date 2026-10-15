# Disk Archive (vormals Disk Index) — README

**Diese Datei enthält das aktuell gültige Konzept.** Rollen und Workflow: [AGENTS.md](AGENTS.md). Offene Aufgaben: [TODO.md](TODO.md) · Erledigt: [DONE.md](DONE.md). Erledigte Aufgaben: [archiv/prompt-verlauf-bis-2026-09-28.md](archiv/prompt-verlauf-bis-2026-09-28.md). Älterer Entscheidungsverlauf: [archiv/readme-verlauf-bis-2026-10-02.md](archiv/readme-verlauf-bis-2026-10-02.md).

## Name, Systemvoraussetzung, Veröffentlichung (Nutzer 09.10.)

- **Produktname: „Disk Archive“** (Website https://diskarchive.app/). Die App zeigt überall **„Disk Archive“** (das neue Layout ist bereits umbenannt; Nutzer 09.10.: Layout-Altstände nicht anfassen, große Layout-Änderungen folgen). Interne Namen (Xcode-Projekt `diskindex`, Typnamen wie `DiskIndexLog`) bleiben, sie sind für Nutzer unsichtbar.
- **Bundle-ID `app.diskarchive`** (umgekehrte Domain), Launch-Agent `app.diskarchive.launcher`, Log-Subsystem `app.diskarchive`. Datenordner `~/Library/Application Support/Disk Archive/`, Protokoll `~/Library/Logs/Disk Archive/`. **Keine Übernahme** aus „Disk Index“ (Nutzer 09.10.: Alpha, einziger Nutzer, alte App samt Daten gelöscht).
- **Mindest-macOS 14.0** (Nutzer: „wenn unser Code es zulässt“). Claude-Probebau 09.10. mit 14.0: nur `pointerStyle` (2 Stellen, ab 15) und `CGSize: Hashable` (ab 15) fehlen → mit Ausweichweg für 14 lösbar.
- **Fehlerbericht-Ziel (Nutzer 09.10., Doku `http://localhost:8888/disk-archive/api/docs/`):** `POST …/api/issues/`, JSON Schema 2 (Felder wie heute in der App: `schema`, `id`, `kind`, `createdAt`, `app{version,build,config}`, `system{macOS,model}`, `runtimeSeconds`, `signature`, `crash{signal,stack}`, `actions`, `logTail`, `inventory{media,items,dbBytes}`), höchstens 256 KB. **Erfolg = 201 `{"id": …}`.** Debug: `http://localhost:8888/disk-archive/api/issues/`, Release: `https://diskarchive.app/api/issues` (live seit 09.10.). `GET …/api/version/` liefert die aktuelle Version (noch nicht genutzt).
- **Systemfreigaben (Claude geprüft 09.10.):** nur **Wechselmedien** (und **Netzlaufwerke**, falls gelesen) und **Mitteilungen**; Autostart erzeugt nur den macOS-Hinweis „Hintergrundobjekt“. Keine Bedienungshilfen, kein voller Festplattenzugriff. Tests dürfen keine Systemrechte auslösen (TODO Regel 21).
- **Weitergabe außerhalb des App Store:** Signatur „Developer ID Application“ + Notarisierung durch Apple (Bezahl-Mitgliedschaft im Apple Developer Program nötig).

## Roadmap (Nutzer 10.10.)

Ausführliche Fassung mit Abnahmekriterien: [ROADMAP.md](ROADMAP.md). **Maßgeblich ist dieser Abschnitt.** Die Nummern sind die Versionsnummern der App (`MARKETING_VERSION`, ab 11.10. dreistellig `n.n.n`: 0.2.0, 0.3.0, 0.3.1, 0.3.2 …; Aufgabe 220). **0.2 am 11.10. eingefroren; 0.3 (Datenbank), 0.3.1 (API-Warteschlange) und der Code von 0.3.2 sind abgenommen (14.10.); vom Umfang 0.4 sind Versions-Check, Update-Modal und Beta-Sperre schon gebaut.** Die Versionsnummer im Xcode-Projekt steht noch auf 0.2.0 (Aufgabe `todo.0.3.2.002`). Fehler aus dem Alltag haben weiter Vorrang. Aufgaben und Fehler heißen `todo.<Version>.<Nr>` und `bug.<Version>.<Nr>` (siehe TODO.md).

| Version | Inhalt |
|---|---|
| **0.1 Beta** | **jetzt** |
| **0.2** | alle bekannten Fehler beheben (Live-Überwachung, Indizieren, nicht angezeigte Dinge, Glitches) |
| **0.3** | neue Datenbankstruktur ✓ (Schema eingefroren, Abschnitt „Datenbank“) |
| **0.3.1** | ✓ **API-Warteschlange** (Nutzer 11.10.): ein Weg ins Netz für Fehlerberichte (später Update-, Versions-, Lizenz-Check); online sofort leeren (macOS-Netzmeldung), offline Ping alle 60 s. Details: Abschnitt „Datenbank“ |
| **0.3.2** | **Erkennung und Dashboard (Alltag), Code ✓, Layout 02 und 04 offen:** Warteschlange für den Erkennungs-Dialog (je Medium, nacheinander; keine Indizierung ohne explizites Ja/Nein); Dashboard-Kacheln mit Belegung und „Zuletzt indiziert“ in der unteren Meta-Zeile. Details: [ROADMAP.md](ROADMAP.md) § 0.3.2 |
| **0.4** | letzte Fixes (Audit-Fehler `bug.0.4.*`). **Beta für Beta-Tester.** Ab hier laden andere die App. Versions-Check, Update-Modal und Beta-Sperre sind schon gebaut ✓ |
| **0.5** | Metadaten und EXIF (Code und Design) |
| **0.6** | Vorschaubilder |
| **0.7** | Export von CSV-Listen |
| **0.8** | Duplikate erkennen |
| **0.9** | Lizenz |
| **1.0** | erste fertige Version |

- **Layout-Reminder (0.3.2):** Der Code für den Erkennungs-Stapel und die Dashboard-Meta-Zeile ist gebaut (`todo.0.3.2.003`). Die Mockups in [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html) müssen nachgezogen werden: **02** (Erkennungs-Dialog: mehrere Medien, Stapel/Warteschlange) und **04** (Dashboard-`card-meta`: Belegung links, „Zuletzt indiziert“ rechts in einer unteren Zeile). Aufgabe `todo.0.3.2.001` (Nutzer). Künftig gilt wieder: erst Layout, dann Aufgabe in `TODO.md`.
- **Grundsatz (Nutzer):** Mit 0.4 sind **alle Probleme erledigt**. Was Fehler ist, muss **in 0.2** gelöst sein. 0.3 und 0.4 sind Umbau und Politur. Neues, das kein Fehler ist, kommt ins Backlog der nächsten Version.
- **Bis 1.0 keine Rücksicht auf vorhandene Daten (Nutzer 10.10.):** Datenbank, Einstellungen und Protokolle **auf dem Mac des Nutzers** dürfen jederzeit verändert, verworfen oder gelöscht werden; Agenten müssen dabei nicht vorsichtig sein. Für andere Rechner ab 0.4 siehe „Stichtag“.
- **Nach 0.3 nur noch erweitern (Nutzer 11.10.):** Keine bestehende Tabelle wird mehr verändert; neue Funktionen über neue Schlüssel in `settings`/`storage_meta`/`item_meta` oder neue Tabellen (Beispiel: Scan-Tiefe je Medium = Schlüssel in `storage_meta`).
- **Stichtag:** 0.3 ist die letzte Version, in der die Datenbank frei verworfen und neu gebaut werden darf. **Ab 0.4 nur noch erweitern (Nutzer 10.10.):** Die Struktur aus 0.3 ist so gebaut, dass spätere Funktionen (Metadaten, EXIF, Vorschaubilder, Prüfsummen) **nur neue Tabellen oder neue Spalten hinzufügen**, nie bestehende umbauen. Die Baumtabelle enthält nur den Baum und die Grunddaten aus dem Dateisystem (Name, Endung, Größe, Änderungsdatum); alles Weitere kommt erst nach 0.4 als eigene Tabelle dazu. Auf **anderen Rechnern** (ab 0.4) wird nie etwas gelöscht: ein Update erweitert die Datenbank einmalig beim Start, die App funktioniert danach mit den vorhandenen Daten weiter. Auf dem **Mac des Nutzers** darf bis 1.0 alles gelöscht werden. Vor jeder Erweiterung eine Sicherungskopie, Schutz vor Rückschritt (ältere App öffnet eine neuere Datenbank nicht).
- **0.3 Datenbank (abgenommen, Schema eingefroren):** Aufbau, Regeln und Messergebnisse im Abschnitt „Datenbank“ weiter unten.
- **0.4 zusätzlich (Nutzer 11.10.):** Versions-Check gegen `api/version/` mit **Update-Modal**; Beta-Sperre (API ≥ 1.0: 7 Tage, frisch installiert sofort, keine Entsperrung), „API 1 Monat nicht erreicht“ → gesperrt; gesperrt = 100 % nur ansehen (auch Überwachung aus).
- **0.4 Voraussetzungen für die Weitergabe [Annahme]:** Developer-ID-Signatur und Notarisierung, Download-Seite, Versions-Check (`GET …/api/version/` existiert), Beta-Verfallsdatum, zentrale Stelle „Darf der Nutzer das?“ (immer ja), Test auf macOS 14, Fehlerbericht mit echten Protokollzeilen, Update durch Ersetzen der App (Bundle-ID und Datenordner gleich, Einzelinstanz-Übergabe, Launch-Agent neu registrieren).
- **Funktionen 0.5 bis 0.9 sind Entwürfe (Nutzer 10.10.):** Jede muss **vor dem Start einzeln besprochen** werden (Umfang, Last, Layout, Grenzen). Die Angaben unten sind Ausgangspunkte, keine Beschlüsse.
- **Ab 0.5 kommen neue Layouts** dazu; Claude übersetzt sie wie bisher in Aufgaben. Darunter ein **Wartescreen der Suche** (Nutzer 11.10.), der auch das Warten auf den Markierungslauf nach Regeländerungen abdeckt (siehe Abschnitt „Datenbank“, „Status je Eintrag“).
- **0.5 Metadaten:** je Dateityp (Felder: [ROADMAP.md](ROADMAP.md) § 0.5), als zweiter Durchgang nach dem Index, damit das Indizieren so schnell bleibt.
- **0.6 Vorschaubilder [offen, zu besprechen]:** mit **Abschalter** (global und je Medium), eigene Datei mit Obergrenze. **Größe: 250 px lange Seite** (Nutzer 10.10.; 400 px wären problematisch: etwa 20 KB je Bild, 5.000 Fotos ca. 100 MB). Bei 250 px etwa 8 bis 12 KB je Bild, 5.000 Fotos ca. 40 bis 60 MB, 100.000 Fotos ca. 1 GB (Überschlag, nicht gemessen). Zu klären: Schärfe auf Retina-Anzeige in der Detailspalte.
- **0.7 CSV-Export:** noch nicht ausgearbeitet **[offen]** (Was wird exportiert, welche Spalten, Trennzeichen und Kodierung für deutsches Excel, Metadaten dabei?).
- **0.8 Duplikate:** über alle Medien, stufenweise (Größe → Anfang/Ende → volle Prüfsumme nur bei Treffern), nur im Hintergrund.
- **0.9 Lizenz:** Stufen nach Medienzahl — **max. 1 / max. 50 / max. 250 Medien**. Die 250 ist **nur eine Lizenzgrenze**, keine Systemgrenze (Nutzer 11.10.): die App muss mehr Medien tragen (Messung 0.3 mit 300 und 1.000). In der Beta (0.1 bis 0.8) gibt es keine Grenze.

**Offene Fragen Lizenz (vor 0.9 zu klären):** Was zählt als Medium (alle erkannten, nur „Indizieren: Ja“, auch offline)? Gibt „Vergessen“ einen Platz frei? Was passiert beim Erreichen der Grenze (Erkennungs-Dialog sagt es, Medium bleibt sichtbar aber wird nicht indiziert)? Was passiert bei Herabstufung mit mehr Medien als erlaubt (Index bleibt durchsuchbar, keine Aktualisierung)? Prüfung der Lizenz online über diskarchive.app oder offline per Schlüssel?

## Spaltenansicht: Scrollen (Nutzer 09.10.)

- **Gilt für alle langen Listen (Nutzer 11.10.):** Suche, Einstellungen → Speichermedien, sehr große Ordner.
- **Systemleisten zulassen (Nutzer 10.10.):** Scrollleisten kommen vom System (Overlay oder dauerhaft, je nach Systemeinstellung) und werden nicht unterdrückt. **Jede Ordnerspalte** zeigt bei vielen Einträgen ihre **eigene senkrechte Leiste** am rechten Rand der Spalte (wie die Einstellungen). Sie liegt innerhalb der Spalte, nie auf der Trennlinie oder der Nachbarspalte; im dauerhaften Stil wird der Text davor gekürzt, nicht überdeckt.
- **Waagerechte Scrollleiste** liegt **im Spaltenbereich über der Statusleiste** und überdeckt sie nie; die letzte Zeile bleibt lesbar. Gilt in beiden Stilen.
- **Kein Demo-Medium mehr (Nutzer 10.10.):** „Spalten-Zustände (Demo)“ entfällt; die Layouts der Spaltenzustände sind abgenommen.
- **Detail-Spalte** nur bei gewählter Datei oder Mehrfachauswahl, auch wenn die Ordnerspalten breiter als das Fenster sind (Nutzer 10.10.).
- **Sortierung (Nutzer 11.10., kommt mit 0.3):** wie im Finder – natürlich („Datei 2“ vor „Datei 10“), Umlaute wie ihr Stammlaut, **Ordner und Dateien gemischt nach Namen** (nicht mehr Ordner oben).
- **Automatisch nach rechts:** Öffnet eine Nutzeraktion (Datei wählen, Ordner öffnen, Pfeiltaste) die Details-Spalte oder eine neue Spalte außerhalb der Sicht, springt die Ansicht so weit nach rechts, dass sie ganz sichtbar ist (kurz, 0,2 s). Nie bei Live-Änderungen oder Nachladen.

## Verhältnis zum Layout

**Vorschlagstexte (Nutzer 11.10.):** Alle bisher rot markierten Vorschlagstexte gelten als festgelegt; die rote Markierung entfällt. Neue Texte ohne Layout-Vorlage legt der Umsetzer normal an und listet sie zur Prüfung auf.

Maßgeblich für Optik, Farben, Icons, Screen-Struktur und **alle Texte** sind [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html) (Sektionen 00–15) und [layout/Farbschema.dc.html](layout/Farbschema.dc.html). Bei Widerspruch zwischen Layout und Konzept gilt das **Konzept** (außer reine Optik), das Layout wird angepasst. Jede Abweichung der App von Text oder Aufbau des Layouts ist ein Fehler.

Neue Entscheidungen trägt Claude direkt in das Konzept ein (überholte werden ersetzt, nicht angehängt).

---

# Konzept (aktuell gültig)

**Eine Stelle für alle konzeptionellen Entscheidungen, nach Thema sortiert.** Hier steht, wie die App **sein soll**. Das Layout zeigt, wie sie **aussieht**. Die chronologische Entstehung steht in [README.md](README.md) (Verlauf), die offenen Arbeiten in [TODO.md](TODO.md) · Erledigt: [DONE.md](DONE.md).

**Pflege:** Claude trägt jede Entscheidung des Nutzers hier ein. Überholte Entscheidungen werden **ersetzt**, nicht angehängt.
- Stand: 08.10.2026, Layout gelesen mit Stand 08.10. 08:33; offene Widersprüche stehen in Abschnitt 11. Markierung **[offen]** = noch nicht entschieden, **[Annahme]** = von Claude angenommen, bestätigt vom Nutzer noch nicht.

---

## 1. Produkt
- Disk Index kümmert sich **nur um externe Speichermedien** (USB-Sticks, externe SSDs/HDDs, SD-Karten). Keine Netzlaufwerke, keine Systemplatte, keine Disk-Images.
- Die App läuft **dauerhaft in der Menüleiste**. Jedes je angeschlossene und zur Indizierung freigegebene Medium behält seinen **Index**, auch offline bleibt der Inhalt durchsuchbar.
- **Eine Suche** findet Medien und Objekte (Dateien und Ordner) zugleich. Treffer öffnen die Spaltenansicht an genau der Stelle. Wichtige Objekte lassen sich als **Favoriten** markieren.

## 2. Medien-Lebenszyklus
1. **Erkennung:** Jedes angeschlossene, lokale, externe Volume (Regel siehe README „Technische Grundlagen“) wird **sofort registriert**, auch wenn noch keine Entscheidung vorliegt. Es erscheint **sofort** in Einstellungen → Speichermedien (Status „Ausstehend“), auch wenn das Fenster dabei schon offen ist. Gleichzeitig öffnet sich der **Erkennungs-Dialog**.
2. **Identität:** UUID des Volumes (DiskArbitration), sonst Fingerabdruck aus Dateisystem, Erstelldatum und Größe. Details im README.
3. **Entscheidung (Erkennungs-Dialog, 02):** **„Indizieren“** = Ja, **„Nicht indizieren“** = Nein, **„Für dieses Medium merken“**: der Dialog erscheint dann für dieses Medium nicht mehr. Die Entscheidung ist jederzeit in **06 (Medium-Details)** und **05 (Einstellungen → Speichermedien)** als **„Soll indiziert werden“ / „Indizieren“ Ja | Nein** änderbar.
4. **Nein stoppt, löscht nichts und versteckt nichts.** Ein vorhandener Index bleibt erhalten, sichtbar und durchsuchbar. Es gibt nur keine Aktualisierungen mehr (keine Live-Überwachung, kein Abgleich beim Anschließen). **Ja** nimmt auf (Erstlauf oder Abgleich).
5. **Index vorhanden** heißt: mindestens eine abgeschlossene Ebene oder mindestens ein nicht entferntes Objekt.
6. **Sichtbarkeit (verbindlich):**

   | Ort | Zeigt |
   |---|---|
   | Einstellungen → Speichermedien (05) | **alle registrierten** Medien, auch ohne Entscheidung und ohne Index |
   | Dashboard / Übersicht (04) | nur Medien **mit Index** (Status Online, Offline, x % indiziert, Fehler), nie „Ausstehend“ |
   | Spaltenansicht-Seitenleiste (07), Suche (Medienkacheln, Medien-Auswahl im Filter), Favoriten | nur Medien **mit Index** (und Entscheidung) |
   | Dropdown in der Menüleiste (03) | **angeschlossene** Medien |

7. **Vergessen** ist die Hauptfunktion zum Entfernen (Medium-Details 06, Alle Speichermedien vergessen in Einstellungen → Erweitert; rote Bestätigung mit zwei Klicks). Es löscht die **Registrierung, den Index und die Favoriten** vollständig, sodass das Medium beim **nächsten Anschließen als unbekannt** gilt und der **Erkennungs-Dialog erneut** erscheint. Ist es beim Vergessen angeschlossen, enden Lauf und Überwachung sofort. **Begründung:** Ein vergessenes Medium wird behandelt, als hätte die App es nie gesehen. Es soll nie passieren, dass ein Medium versehentlich nicht mehr indiziert werden kann. Mit der Pause hat das **nichts** zu tun (siehe Abschnitt 3).
8. **Offline:** Ein Medium mit Index bleibt mit seinem Index sichtbar (gestrichelter Offline-Chip), „Im Finder anzeigen“ ist dann ausgegraut.
9. **Fehler:** Schlägt die Indizierung fehl, zeigt das Menüleisten-Symbol „!“. Ein Klick öffnet das **Indizierungsfehler-Modal** (Layout 14, siehe Abschnitt 2b). Hat das Medium schon einen Index, steht zusätzlich „Fehler“ im Dashboard.

## 2a. Statusmodell eines Mediums (Nutzer 01.10., Klarstellung)
Ein Medium hat **drei unabhängige Eigenschaften**:
1. **Entscheidung:** **Ja** (soll indiziert werden), **Nein**, **offen** (noch keine Entscheidung).
2. **Verbindung:** **angeschlossen** oder **nicht angeschlossen**.
3. **Index:** **keiner**, **unvollständig** (läuft, wartet, gestoppt oder fehlgeschlagen) oder **vollständig**.

**Angezeigter Status (Chip):** „Online“ und „Offline“ bedeuten **immer: ein Index ist vorhanden**; Online = angeschlossen und vollständig indiziert, Offline = nicht angeschlossen (egal ob vollständig oder unvollständig, weil ohne Anschluss nichts weiter indiziert werden kann).

| Index | Verbindung | Status | Erscheint im Dashboard (04)? |
|---|---|---|---|
| vollständig | angeschlossen | **Online** | ja |
| vorhanden (egal ob vollständig) | nicht angeschlossen | **Offline** | ja |
| unvollständig | angeschlossen | **x % indiziert** (läuft, wartet auf Pause-Ende oder gestoppt) | ja |
| letzter Lauf fehlgeschlagen, Index vorhanden | beides | **Fehler** | ja |
| **keiner** | beides | **Ausstehend** (offen oder Ja, noch nicht begonnen) bzw. **Nicht erlaubt** (Nein) | **nein, nie** |

**Genau ein Chip je Medium (Nutzer 01.10.).** Chips werden nie übereinandergelegt. **Offline kommt als Zusatz in denselben Chip**, in **Offline-Grau, gestrichelt**. Der zuletzt eingetretene Zustand steht vorn:

| Zustand | Chip-Text | Farbe |
|---|---|---|
| angeschlossen, Index vollständig | **Online** | Grün (Online ist stärker als „indiziert“: nie „Indiziert“) |
| angeschlossen, Index unvollständig | **x % indiziert** | Grün, gestrichelt, Spinner bzw. Pause-Icon |
| angeschlossen, letzter Lauf fehlgeschlagen | **Fehler** | Rot |
| nicht angeschlossen, Index vollständig | **Offline** | Offline-Grau, gestrichelt, ohne Fläche |
| nicht angeschlossen, Index unvollständig | **x % indiziert, offline** (z. B. „45 % indiziert, offline“) | Offline-Grau, gestrichelt |
| nicht angeschlossen, zuletzt Fehler | **Fehler, offline** | Offline-Grau, gestrichelt |

Weitere Information (Dateizahl, „zuletzt gesehen …“, „Fehler vor 2 Std. · erneut versuchen“) steht als **Textzeile**, nicht als zweiter Chip. **Das Menüleisten-„!“ erscheint nur für angeschlossene Medien mit Fehler** *(bestätigt)*.

- **„Ausstehend“ erscheint nie im Dashboard.** Es bedeutet „kein Index“, und ohne Index gibt es dort nichts zu zeigen. „Ausstehend“ und „Nicht erlaubt“ stehen nur in **Einstellungen → Speichermedien** (und „Ausstehend“/„Neu erkannt“ im Dropdown und im Menüleisten-Symbol).
- **Nein mit vorhandenem Index** (Nein gesetzt, nachdem indiziert wurde): Status ergibt sich aus Verbindung und Index wie in der Tabelle (Online/Offline/x %); **die Entscheidung Nein steht nur in der Auswahl „Indizieren“** (Ja | Nein). „Nicht erlaubt“ als Status gilt nur für Nein **ohne Index** *(bestätigt 01.10.)*. **Nein plus unvollständiger Index, angeschlossen:** Status „x % indiziert“, der Lauf steht still *(bestätigt)*.
- **Vollständig indiziert, App-Neustart oder Anstecken (Nutzer 04.10.: „egal was passiert, es muss immer alles indiziert werden“):** Bei **jedem Anschließen** und **jedem App-Start mit angeschlossenem Medium** läuft ein **vollständiger Abgleich**: **jeder Ordner wird vollständig gelesen** (keine Abkürzung über Ordner-Änderungsdatum oder FSEvents-Verlauf, FAT-Sticks haben keinen), mit dem Index verglichen und **ergänzt, geändert oder als entfernt markiert**. Der Inhaltsstempel eines Ordners (Hash über Namen, Größen, Änderungsdaten) spart nur das **Schreiben**, nie das **Lesen**. Status bleibt **„Online“**, **kein Badge** in der Menüleiste (Layout 01: online und fertig = kein Badge; Nutzer 08.10.: kein blauer Spinner). Danach übernimmt die **Live-Überwachung**. **„Neu indizieren“**: Lauf von Grund auf, Status kann **„x % indiziert“** sein, Spinner grün. Dauert ein Lauf **länger als 59 Sekunden**, geht die **Mitteilung** „Medium vollständig indiziert“ raus *(bestätigt)*. **Passt etwas nicht** (Ereignis für einen Pfad, der im Index fehlt oder nicht stimmt; Zähler weichen ab; Lesefehler), **prüft die App den betroffenen Ordner sofort neu**, bei Zweifel das ganze Medium.
- **Fehler ohne Index:** Ein fehlgeschlagener Erstlauf **ohne** Index erscheint nicht im Dashboard. Das „!“ im Menüleisten-Symbol öffnet das **Indizierungsfehler-Modal** (Abschnitt 2b).

## 2b. Indizierungsfehler-Modal (Layout 14; Nutzer 01.10.)
- **Wann:** Schlägt ein Lauf auf einem **angeschlossenen** Medium fehl, erscheint ein **Modal „<Medium> konnte nicht indiziert werden“**, **aber nur, solange das Hauptfenster geöffnet ist**. Es ist die Antwort auf den Fehler-Status im Menüleisten-Symbol (01), im Dropdown (03) und im Dashboard (04): ein Klick darauf öffnet es.
- **Knöpfe:** **„Schließen“** und **„Erneut versuchen“** (primär). „Erneut versuchen“ startet den Scan neu (setzt das Medium falls nötig auf Ja). „Schließen“ lässt den Fehlerzustand **bestehen** (Chip „Fehler“, „!“ im Menüleisten-Symbol), bis ein Lauf gelingt oder der Nutzer in Einstellungen/Details „Soll indiziert werden“ auf Nein setzt. Esc = Schließen. *(bestätigt 01.10.; der Knopf „Medium ignorieren“ aus dem Layout-Stand 23:09 entfällt.)*
- **Grund, aufbereitet:** Kennt die App den Grund, steht er **in verständlichem Deutsch** im Modal (eine Zeile), sonst keine Grundzeile. Beispiele: Leserechte („Disk Archive darf dieses Medium nicht lesen. Das lässt sich in den Systemeinstellungen unter Datenschutz & Sicherheit ändern.“), Verbindung unterbrochen („Die Verbindung zum Medium wurde unterbrochen.“), Zeitüberschreitung („Das Medium reagiert nicht.“), Speicherplatz („Auf diesem Mac ist nicht genug Speicherplatz frei.“), Datenbank („Der Index konnte nicht gespeichert werden.“). Technische Fehlertexte, Pfade und Dateinamen erscheinen **nie** im Modal.
- **Parallel** erscheint eine **macOS-Mitteilung** (Ereignis „Systemmeldungen“, Einstellungen → Allgemein → Mitteilungen): Titel „Disk Archive“, „<Medium> konnte nicht indiziert werden“, darunter der aufbereitete Grund (sonst „Beim Indizieren ist ein Fehler aufgetreten.“). Ein **Klick auf die Mitteilung** öffnet das Hauptfenster **mit diesem Dialog**.
- **Mehrere Fehler gleichzeitig:** Modals **nacheinander**, eins je Medium. **Schlägt „Erneut versuchen“ sofort wieder fehl:** das Modal erscheint erneut, aber **höchstens 3-mal je Medium und Stunde** automatisch, danach nur noch über das „!“. **Ist das Hauptfenster beim Fehler zu:** nur Mitteilung und „!“; beim nächsten Öffnen erscheint das Modal **einmal**, wenn der Fehler noch offen ist. *(alle drei bestätigt)*
- Das **Menüleisten-„!“** erscheint nur für **angeschlossene** Medien mit Fehler (siehe 2a).

## 3. Pausieren
- **Begriffe und Aufbau (Nutzer 03.10.):** **Einstiegskachel** = Popover am Menüleisten-Symbol (Layout 03: 340 pt, **Radius 14 pt**, **1-pt-Rand** `divider`, Schatten `--shadow-lg` — **Ruhe und Suche gleich**), **Pausentimer** = das kleine Menü unter „Pausiert“. Die Einstiegskachel **verändert nie ihre Position** (nur die Höhe, Oberkante fest direkt unter dem Symbol). **Suchzustand:** Panel-Höhe = Kopf + Trefferliste + Fuß („Alle N Ergebnisse“); die AppKit-Höhe folgt `MenuBarPopoverLayout` **1:1** der SwiftUI-Messung (sonst schneidet `clipsToBounds` den Fuß ab). Der Pausentimer ist ein **eigenes Kindfenster** (`KeyablePanel`), **rechts bündig mit An/Pausiert**, mit **Nase (Pfeil)** am Schalter (Layout Screen 03: 210 pt, Abrundung 8 pt, Hover/Hand-Cursor auf den Dauer-Optionen); er überdeckt die Kachel teilweise und verändert sie nicht.
- Es gibt **nur eine globale Pause** (Dropdown, 03). **Medien können nicht einzeln pausiert werden.**
- Dauer: **30 Minuten, 1 Stunde, Bis morgen (= nächster Tag 09:00 Uhr), Für immer.** Ist schon pausiert, zeigt das Popover „Pausiert für X, bis HH:MM Uhr“ (aktive Dauer ausgegraut, andere ändern die Pause). „An“ setzt sofort fort.
- **„Pausiert“-Segment:** Klick **toggelt** nur das Pausentimer-Menü (Pause erst nach Dauerwahl); erneuter Klick schließt. Klicks auf An/Pausiert schließen das Menü **nicht** über den Popover-Außenklick-Monitor (sonst Doppel-Umschaltung). Dauerwahl → Menü zu, Segment „Pausiert“ aktiv.
- Die Pause **überlebt einen Neustart** (Enddatum wird gespeichert). Bei Ablauf geht die **Systemmeldung** „Medien werden wieder indiziert.“, wenn Mitteilungen an sind.
- **Die Pause betrifft nur das Indizieren.** Alle anderen Funktionen laufen unverändert weiter: Erkennen neuer Medien, Registrierung, Erkennungs-Dialog, Suche, Anzeige. Während der Pause ruht das Indizieren auf **allen** Medien. Wird ein **unbekanntes Medium angeschlossen**, erscheint der **Dialog trotzdem**; bei „Indizieren“ wartet der Lauf („Ausstehend“) und **startet automatisch, wenn die Pause endet, sofern das Medium dann noch online ist** (sonst beim nächsten Anschließen).
- **Menüleisten-Symbol:** Fehler **„!“** hat Vorrang, sonst bei Pause **„X“**; sonst grüner Spinner (**wird indiziert**: Erstlauf oder „Neu indizieren“), pulsierender Punkt (neu erkannt, Dialog offen). Online und fertig = kein Badge, **auch während Abgleich und Live-Sync** (Nutzer 08.10., Layout 01). Priorität: Fehler, Neu erkannt, Pausiert, Wird indiziert. **Badge-Grundfläche immer weiß (~12 pt);** das **X** (und das „!“ laut Layout 02) in **fester dunkler Tinte `#201E1D`**, nicht an `text`/`neutral-800` gekoppelt — sonst ist das X im Dunkelmodus auf dem weißen Kreis unlesbar.

## 4. Indizieren
- **Ebenenweise** (Breitensuche), jede fertige Ebene wird geschrieben, ein Abbruch setzt bei der nächsten Ebene fort. **Fortschritt (Nutzer 05.10.: „erst die Summe der Dateien erfassen, darauf Prozent und Fortschritt“; heute springen die Werte 0, 50, 60 %):** **Eine** Definition für **jede** Anzeige (Chip, Popover, Dashboard, Einstellungen, Details, Menüleiste). **Vorlauf (Nutzer 10.10.):** Beim ersten Lauf ohne gespeicherte Gesamtzahl werden **zuerst Ebene 1 und 2 geschrieben**, damit die Platte nach Sekunden sichtbar ist (bei 1 TB sonst 2 Minuten nichts); Anzeige dabei wie in der Zählphase. Danach hat ein Lauf **zwei Phasen**: **(1) Zählen:** alle Ordner werden einmal nur nach Namen und Typ gelesen (kein Schreiben in die Datenbank), das Ergebnis ist die **Gesamtzahl der Einträge** (Dateien und Ordner, nach Ausschlussregeln). Chip und Popover zeigen dabei **„0 % indiziert“** mit Spinner (Nutzer 07.10.: keine eigenen Texte wie „Zählt …“ oder „Dateien werden gezählt: 12.400“, nur das, was das Layout kennt; **keine Zahlen von Dateien in Chip, Popover oder Details**). Bei einem **erneuten Lauf** (Abgleich, „Neu indizieren“) dient die **gespeicherte Gesamtzahl** des letzten Laufs als Schätzung, sodass sofort Prozent erscheinen; die Zählphase korrigiert sie. **(2) Indizieren:** Fortschritt = **gespeicherte Einträge ÷ Gesamtzahl**, **stetig** (nach jedem Stück von höchstens 2.000 Einträgen, die Anzeige höchstens alle 250 ms aktualisiert), **nie fallend**, höchstens **99 %** bis zum Ende, ganze Zahlen **abgerundet**. Wächst die Gesamtzahl während des Laufs (neue Dateien), gilt `min(0,99, gespeichert ÷ max(Gesamtzahl, gespeichert))`. Die Gesamtzahl wird **in der Datenbank gespeichert** (`medium.scanTotal`), damit auch ein **unvollständiger Index** nach App-Neustart oder Abziehen **denselben Prozentwert** zeigt (heute nicht gespeichert, daher 0 %). **„Belegt“ (Speicherplatz, z. B. „35 % belegt“) ist etwas anderes** und heißt nie „indiziert“.
- **Scan-Tiefe:** 1, 2, 3, 4 oder **5+ (uneingeschränkt). Voreinstellung: 5+.** Ordner jenseits der Scan-Tiefe werden gespeichert, aber nicht geöffnet (Hinweis in der Spalte „Inhalt wird nicht indiziert“).
- **Ausgeschlossen** wird in drei Schichten:
  1. **Immer ausgeschlossen** (unabhängig von allen Schaltern): `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `System Volume Information`, `.TemporaryItems`, `.DocumentRevisions-V100`, `._*`.
  2. **Artefakte** (Schalter, Voreinstellung An): Regelliste aus Abschnitt „Regelliste Artefakte“ weiter unten (temporäre Dateien, Backups, Systemreste, Abhängigkeitsordner, unsichtbare Artefakte). Case-insensitiv, exakt oder ein `*` am Anfang/Ende, nur Namen, Teilbaum wird übersprungen.
  3. **Eigene Ausschlüsse** (Chips unter Dateien & Ordner, Kontextmenü „Dateinamen/Dateitypen ignorieren“): Voreinstellung **leer**. Bereits erfasste Treffer verschwinden **sofort aus der Ansicht** und werden nach **1 Stunde** aus dem Index gelöscht; sofort über **„Index jetzt bereinigen“** (Erweitert), siehe „Index entspricht den Einstellungen“. Wird ein Chip entfernt, werden die Dateien beim nächsten Scan wieder erfasst.
  - **Unsichtbare Dateien** (Punkt-Namen): eigener Schalter, Voreinstellung An (ignorieren). Ein Element wird ausgelassen, sobald **ein aktiver Filter** es trifft.
- **Index entspricht den Einstellungen (Nutzer 02.10.):** Alles, was den Index **verkleinert**, wirkt so: **Scan-Tiefe verringern, Unsichtbare Dateien ignorieren an, Artefakte ignorieren an, eigener Ausschluss hinzufügen.**
  - **Anzeige sofort:** Betroffene Einträge **verschwinden sofort aus der Ansicht** (Spalten, Suche, Favoriten). Ordner jenseits der verringerten Tiefe zeigen den Hinweis „Inhalt wird nicht indiziert“.
  - **Löschen nach 1 Stunde:** Die Einträge werden **erst nach 1 Stunde endgültig aus der Datenbank gelöscht**, **auch Favoriten, ohne Warnung**, auch bei Medien, die gerade **nicht angeschlossen** sind. **Jede weitere Verringerung startet die Stunde neu.** Der Termin überlebt einen Neustart; ist er beim Start überfällig, wird sofort bereinigt.
  - **Sofort:** Einstellungen → Erweitert → **„Index jetzt bereinigen“** (schwarze Zwei-Klick-Bestätigung) löscht sofort, **ein Knopf für alle** Einschränkungen. Die Dateien auf den Medien bleiben immer unberührt.
  - **Wieder erweitern** (Tiefe höher, Schalter aus, Ausschluss entfernt): Es erscheint **alles, was noch im Index ist**; **unvollständige Ordner** (deren Inhalt fehlt) werden beim nächsten Lauf nachgelesen, das Medium zeigt bis dahin „x % indiziert“. Es gibt **keine Terminzeile** in den Einstellungen.
  - **Technik (für die Umsetzung):** Einträge außerhalb der Tiefe bekommen `status = 1` (Warteschlange, Abschnitt „Datenbank“), Löschen in Blöcken nach der Frist, danach Platz freigeben (`incremental_vacuum`, WAL kürzen). Ein Zurücksetzen der Inhaltsstempel ist nicht mehr nötig.
  - **Ausschlüsse verschwinden ebenfalls sofort**, das gelbe Prohibit-Icon an Objekten entfällt; das rote Häkchen im Kontextmenü bleibt, solange der Ausschluss besteht *(bestätigt 02.10., Layout 08:44 angepasst)*.
- **Live-Überwachung** angeschlossener Medien (FSEvents, nach Ruhezeit gebündelt, mit Höchstwartezeit) **startet bei jedem Einhängen und nach dem Aufwachen des Macs neu** (Nutzer 09.10.: nach Ruhezustand wurde der Stick neu eingehängt, die alte Überwachung lieferte nichts mehr) **ergänzt** den Abgleich beim Anschließen, **ersetzt** ihn nie. **Vollständiger Abgleich** (kein „Neu indizieren“, kein Badge) außerdem bei FSEvents `MustScanSubDirs`/`RootChanged` oder erkannter Abweichung (Claude 09.10.: ein Neu-Lauf mit grünem Spinner beim Kopieren vieler Dateien wäre unerklärlich); läuft gerade ein Lauf, wird der Abgleich danach einmal nachgeholt. Unvollständiger Index (`pending`) setzt den Lauf fort. **Nach dem Ende einer Pause** läuft für jedes angeschlossene, indizierte Medium ein vollständiger Abgleich (während der Pause ruht auch die Überwachung). **Lesen großer Ordner (Nutzer 04.10., Stresstest 30.000 Dateien auf FAT32-Stick: 2 × 700 und 2 × 14.300 Dateien):** Ein Ordner wird **vollständig und in Stücken** gelesen; es gibt **kein festes Zeitlimit pro Ordner**, sondern eine **Wächterzeit ohne Lebenszeichen** (kommen 30 s lang keine Einträge mehr, gilt das Medium als hängend). Ein **nicht lesbarer Ordner wird nie stillschweigend übersprungen**: wiederholen (3×), sonst als **nicht lesbar** markieren und im Status melden, der Index gilt dann als **unvollständig** („x % indiziert“). **Eine Wahrheit in der DB:** Inventar in `item`; aggregierte Kennzahlen pro Medium (`fileCount`, `folderCount`, `lastIndexActivityAt`, `lastIndexedAt`) werden bei **jedem** Schreibvorgang (Watcher, Scanner-Batch, Bereinigung) in derselben Transaktion aktualisiert (`commitMediumMeta`). **`lastIndexActivityAt`** = letzte Index-Aktivität; **`lastIndexedAt`** = Ende eines Ebenen-/Vollabschlusses. **Dateizahlen** in Popover/Dashboard-Spec nutzen die **DB-Gesamtzahlen** auf `medium`; Filter wirken auf Spalteninhalte, nicht auf diese Summe. Nach Meta-Commit: Medium neu laden; Spalten-Cache für das Medium **debounced** invalidieren (~450 ms). **Invalidieren heißt „veraltet“, nicht „leeren“** (Nutzer 09.10.): Sichtbare Spalten zeigen den alten Inhalt, bis der neue geladen ist, dann Tausch in einem Schritt; keine leere Spalte, keine Ladefläche. **Kein Menüleisten-Badge** während Live-Abgleich (Nutzer 08.10.); **„indexing“** (grüner Spinner) nur während Erstlauf/„Neu indizieren“. Schwerer Watcher-Flush läuft im **`ChangeWatcherEngine`** abseits des Main Actors.
- **Zuverlässigkeit hat Vorrang:** Fortschritt, Pause, Wiederaufnahme, hängende Platten, Datenbankschäden und Speicherplatz sind abgesichert und getestet (Aufgabe 70).

- **„Neu indizieren“: Sperre (Nutzer 08.10.):** Der Knopf wird **beim ersten Klick sofort** deaktiviert, an **jeder** Stelle (Menüleisten-Popover, Medium-Details, jede weitere Stelle mit dieser Aktion) für dieses Medium. Er bleibt gesperrt **vom Start des Laufs bis 59 Sekunden nach dessen Ende**; erst dann ist er wieder klickbar. Gilt je Medium.
- **Popover-Fortschritt (Layout 03):** rechts in der Zeile „x %“ mit Spinner, gestrichelt unterstrichen; Klick wechselt zur Byte-Angabe „0,57 TB / 4,1 TB“ (Fortschritt × Gesamtkapazität / Gesamtkapazität) und zurück. Nie Dateizahlen.
- **Fortschritt mindestens 1 Sekunde sichtbar (Nutzer 08.10.):** Ist ein Lauf schneller, zeigen Prozentzahl **und** Balken trotzdem einmal eine **gleichmäßige Bewegung von 0 auf 100 % über 0,6 Sekunden** (Nutzer 08.10.: „kann schneller“; vorher 1 s), **„100 %“ ist dabei kurz (0,3 s) sichtbar**, danach der Endzustand. Angezeigt wird `min(echter Fortschritt, Zeit seit Start ÷ 0,6 s)`, nie fallend; nach dem Ende läuft die Anzeige bis 100 % weiter und wechselt erst dann.

## 5. Suchen, Filtern, Navigieren
- **Leerzustände (Layout vom 07.10.):** Dashboard ohne Medien, Einstellungen › Speichermedien ohne Medien (beide: „Noch keine Speichermedien erfasst“, drei schwarze Medien-Icons), Favoriten leer („Keine Favoriten“, violettes Icon, Chip-Leiste bleibt), leere oder nicht gestartete Suche (blaue Icons). Texte und Aufbau nur nach Layout.
- **Medienliste (Seitenleiste, Layout 07 vom 07.10.):** Breite **ziehbar** (Nutzer 07.10., Voreinstellung 200 pt), lange Namen einzeilig mit **Fade-Verlauf** (auch für den gewählten Eintrag), Tooltip mit vollem Namen, Markierung endet innerhalb der Spalte.
- **Statusflächen füllen die Restbreite (Nutzer 07.10., Layout 07):** „Inhalte werden geladen“, „Wird indiziert“, „Inhalt wird nicht indiziert“ sind keine schmalen Ordnerspalten, sondern nehmen wie die Detail-Spalte die ganze Restbreite; rechts daneben bleibt freie Fläche, solange noch nicht feststeht, ob Details oder Dateien folgen.
- **Spaltenansicht ohne Info-Chips (Nutzer 06.10.):** Weder Spalten noch Detail-Spalte zeigen Status-Chips (kein „Online“/„Offline“, kein „Wird indiziert“, kein „Inhalt nicht erfasst“). Zustände eines Ordners erscheinen als **Hinweisfläche in der Ordnerspalte** (Spinner/Icon, Titel, Satz; Texte laut Layout 07: „Wird indiziert“, „Inhalte werden geladen“, „Inhalt wird nicht indiziert“ mit Link „Scan-Tiefe ändern“). **Spaltenkopf = nur der Ortsname**, keine Elementanzahl.
- **Spaltenansicht:** Navigation wie im Finder; **jeder Ordner im geöffneten Pfad (`pathStack`) bleibt in seiner Spalte markiert** — gleicher Pfad wie in der Fußzeile (Medium › … › Datei). **Medium-Seitenleiste:** während Indizierung **`IndexingSpinnerRing`** statt Typ-Icon, gleiche Icon-Farbe. **Sonderzustände in der Ordnerspalte (Layout Screen 07, 06.10.) — nicht in der grauen Detail-Spalte:** (1) **Ordner wird noch indiziert** — Ordnerzeile ausgegraut, trotzdem öffnen; in der **nächsten Spalte** grüner Spinner, Titel **„Wird indiziert“**, Fließtext (kein Chip). Das ist **nicht** Scan-Tiefe/Ausschluss. (2) **Ordner bewusst nicht indiziert** (Scan-Tiefe, Ausschluss, unreadable): Klick auf Scan-Tiefe-Ordner **ohne** Pfaderweiterung → **virtuelle Spalte** mit Warn-Icon, Titel **„Inhalt wird nicht indiziert“**, Hinweis + Link **„Scan-Tiefe ändern“** (Einstellungen → Dateien & Ordner); bei Ausschluss/Lesefehler analog `UncapturedFolderContextHint` (Vorschlagstexte wo Layout noch folgt). Ordner-Icon gelb (`stateIgnored`). (3) **Sehr große Ordner:** keine Teilliste; **schwarzer** Spinner 22 px, „Inhalte werden geladen“, Fließtext, Ladestand; Hinweis **erst nach 1 s** Ladezeit (Nutzer 06.10.), Fußzeile „–“ während des Ladens. **Detail-Spalte** nur bei **Datei** oder **Mehrfachauswahl**. Technik großer Ordner: Batches (`IndexRepository`), **`LazyVStack`**, Nachladen gedrosselt (~350 ms). **Filter gilt für das ganze geöffnete Medium** (alle Spalten), Ordner bleiben sichtbar, wenn „Ordner weiterhin anzeigen“ an ist (Voreinstellung An). In der **Suche** gilt der Filter global über alle Medien.
- **Filter:** Dateityp (Mehrfachauswahl, eigene Endungen), Medium (nur Suche), Alter. **Oder/Und** über den Link-Button; **der Knopf ist nur sichtbar, wenn „Und“ wirken kann** (Nutzer 03.10.): kein Suchbegriff abgeschickt, „Ordner“ nicht gewählt und **Dateityp-Gruppe und Alter beide gesetzt**. Sonst ist er **ausgeblendet** (nicht ausgegraut). Sichtbar ist er **inaktiv** (Oder, ohne Fläche); ein Klick macht ihn aktiv (blau, Und). Fällt die Bedingung weg, verschwindet er wieder und der Zustand wird auf Oder zurückgesetzt. Blau = Filter/Suche aktiv.
- **Mehrfachauswahl** in einer Spalte (⌘, ⇧, ⌘A). Bei mehr als einem Objekt bleiben die Spalten rechts zu; „Im Finder anzeigen“, „Nach Namen/Dateiendung suchen“ sind ausgegraut, Favorit und Ignorieren gelten für alle. Detail zeigt Anzahl und Gesamtgröße, Fußleiste „x von y ausgewählt“.
- **Kontextmenü** (Finder · Favorit · Suchen · Ignorieren), nicht verfügbare Einträge ausgegraut statt ausgeblendet.
- **Favoriten:** Medien und Objekte; Icons violett. Favoritenansicht wie Suche aufgebaut.
- **Textfelder:** X zum Zurücksetzen, Hand-Cursor auf allem Klickbaren.

## 6. Einstellungen
- **Vier Tabs (Nutzer 09.10., ersetzt Layout 05 bis zum Layout-Update):** **Allgemein** = Sprache, Erscheinungsbild, **Mitteilungen** (ganzer Abschnitt mit Beispielkasten). **Dateien & Ordner** = Scan-Tiefe, Dateityp-Filter-Verhalten, Ausschlüsse, Unsichtbare Dateien, Artefakte. **Speichermedien** = je Medium „Indizieren“ Ja | Nein, Filterchips Alle / Indiziert / Offline / Nicht erlaubt. **Erweitert** = **Autostart**, **Fehlerberichte**, danach die Lösch- und Rücksetzknöpfe: Index jetzt bereinigen, Voreinstellungen, Alle Speichermedien vergessen.
- **Voreinstellungen** (nach Installation und „Voreinstellungen anwenden“): Beim Anmelden starten An, Erscheinungsbild Automatisch, Scan-Tiefe 5+, Ordner weiterhin anzeigen An, Unsichtbare Dateien ignorieren An, Artefakte ignorieren An, Mitteilungen An (alle drei Ereignisse An), Fehlerberichte künftig automatisch senden Aus. „Voreinstellungen anwenden“ berührt Medien, Index und Favoriten nicht.
- **Erscheinungsbild:** Hell / Dunkel / Automatisch (folgt macOS), wirkt sofort in allen Fenstern; Tag/Nacht-Szene als Animation.
- **Sprache (Layout 05):** Deutsch oder Englisch. **Erststart:** bevorzugte Systemsprache (`de*` → Deutsch, `en*` → Englisch, sonst Englisch), gespeichert in den Einstellungen. **Änderung** in Einstellungen › Allgemein › Sprache: Catalog-Texte (`LayoutCopy`/`L10n`) **sofort**, Persistenz und `AppleLanguages` unmittelbar; Hinweistext laut Layout: „Die Änderung gilt sofort.“ (Nutzer 08.10.). Technik: [docs/Lokalisierung.md](docs/Lokalisierung.md).
- **Autostart:** Voreinstellung An (macOS kann eine Freigabe unter Anmeldeobjekte verlangen).
- **Mitteilungen:** Die Berechtigung wird **beim ersten Start** angefragt. Drei Ereignisse: Systemmeldungen (Fehler, abgelaufene Pausen), Medium vollständig indiziert (nur wenn der Lauf **länger als 59 Sekunden** dauerte; gilt für den Erstlauf **und** für Abgleich/„Neu indizieren“), Medium mit Favoriten angeschlossen.
- **Mitteilung beim Ein- und Ausschalten der Mitteilungen (Nutzer 08.10.):** Wird der Hauptschalter „Mitteilungen aktivieren“ umgeschaltet, kommt eine Mitteilung zu dieser Änderung (an: „Mitteilungen sind eingeschaltet.“, aus: „Mitteilungen sind ausgeschaltet.“ — feste Konzepttexte, Nutzer 08.10.: brauchen kein Layout, **nicht rot**); beide Meldungen erscheinen **auch bei aktiver App** und **unabhängig vom Hauptschalter** (die Aus-Meldung kommt ja gerade beim Ausschalten); die Aus-Meldung geht **vor** dem Abschalten raus. **Sperre:** dieselbe Meldung (an bzw. aus) frühestens **5 Sekunden** nach der letzten gleichen Meldung; schnelles Hin- und Herschalten löst also höchstens eine Meldung je Zustand und 5 s aus.
- **Mitteilungen bei Pause (Layout 03, Nutzer 08.10.: Layout gilt):** Beim Pausieren „**Indizierung pausiert bis HH:MM Uhr.**“ (bei „Für immer“: „**Indizierung pausiert.**“); beim Ende der Pause (Ablauf, auch nach dem Aufwachen) **oder** beim Klick auf „An“: „**Medien werden wieder indiziert.**“ Beide hängen am Schalter „Systemmeldungen“ und an „Mitteilungen aktivieren“. Layout 05: „Systemmeldungen umfassen Hinweise zu Fehlern und zu Pausen.“
- **Bestätigungsmodus (Layout 05, Nutzer 08.10.: Layout gilt):** Rote Stufe (löschen/vergessen: roter Rahmen und Text) und schwarze Stufe (nicht kritisch, nicht umkehrbar: „Index jetzt bereinigen“, „Voreinstellungen anwenden“ — **Darstellung wie Sekundär-Knopf: grauer Rahmen `#9B9797`, schwarze Schrift**, so zeichnet es das Layout) brauchen **zwei Klicks**: erster Klick füllt den Knopf **rot** mit „Bestätigen“, zweiter Klick führt aus, dann kurz grün „Bestätigt“ mit Häkchen. **Zurück in den Ausgangszustand nur nach 3 s ohne Klick** (Nutzer 08.10. abends: Verlassen mit dem Zeiger setzt **nicht** zurück; Layout angepasst). Die Breite bleibt in allen Stufen gleich.
- **Bestätigungsknopf, Maße:** **Breite = der längste der drei Texte („Beschriftung“, „Bestätigen“, „✓ Bestätigt“) plus Innenabstand, nie gestreckt (Nutzer 05.10.: „so breit wie er muss“)**, bleibt in allen drei Stufen **gleich**; Höhe wie alle Standard-Knöpfe (siehe „Button-Regeln“ in 10). Die ganze Fläche ist klickbar. Gilt für „Alle Speichermedien vergessen“, „Vergessen“ (Medium-Details), „Index jetzt bereinigen“ und **„Voreinstellungen anwenden“** (alle vier brauchen den Bestätigungsmodus). **Zusätzlich** (Nutzer: „soll über die Mitteilungen kommen“) **(vom Nutzer bestätigt 02.10.)**: Nach Ausführung geht eine **Systemmeldung** (Schalter „Systemmeldungen“ in Erweitert) mit dem Ergebnis raus, z. B. „Alle Speichermedien wurden vergessen.“, „Index bereinigt.“, „Voreinstellungen angewendet.“ Die Texte sind von Claude vorgeschlagen und gelten, bis das Layout sie festlegt (Nutzer: „Genau so“).

## 7. Start und Dock
- Die App kann **fest im Dock** liegen. **Jeder Start zeigt alles (Nutzer 15.10., ersetzt die früheren Regeln „nur Menüleiste“ und „Anmeldung still“):** Ob Klick auf das Dock-Symbol, Finder, Spotlight oder **Start beim Anmelden** — es starten **Menüleiste und Hauptfenster zusammen** und der **Versions-/Update-Check läuft sofort** (über die API-Warteschlange; Update-Modal oder Sperre erscheinen damit im sichtbaren Fenster). Grund: Meldungen bleiben sonst unbemerkt. **Erneuter Klick auf das Dock**, während die Instanz läuft und kein Hauptfenster sichtbar ist, **öffnet das Hauptfenster** (`applicationShouldHandleReopen`). Fenster schließen = zurück in den Hintergrund; **das Dock-Symbol bleibt sichtbar**, solange der Prozess läuft. **Einzelinstanz:** startet der Nutzer die App erneut, während sie läuft, übernimmt die laufende Instanz (Release: Handoff → Hauptfenster). Explizite Aktionen (Menü „Disk Index anzeigen“, Popover „Disk Index öffnen“) öffnen das Fenster **sofort**. Das Dock-Symbol ist das Bundle-Icon.
- **Fenster:** Hauptfenster per **`AppWindowPresenter`** (kein SwiftUI-Window-Restore); **Position/Größe** über Frame-Autosave. macOS-Fenster-Wiederherstellung ist **abgeschaltet** (`NSQuitAlwaysKeepsWindows`, `isRestorable = false`) — vermeidet Konsolenwarnungen; kein Einfluss auf die App-Funktion.

## 8. Fehlerberichte und Datenschutz
- **Nur Absturzberichte, nur über die Schnittstelle** der Disk-Index-API, **nur nach Zustimmung** im Dialog (13). **Optional „Künftig automatisch senden“** (Voreinstellung Aus, auch in Einstellungen → Erweitert änderbar). Das automatische Senden bleibt **bewusst still**: einmal gefragt, jederzeit änderbar.
- Der Bericht enthält **keine Datei- oder Ordnernamen und keine Suchbegriffe**, nur Version, System, Fehlerort, letzte Aktionen und technische Eigenschaften von Namen (Länge, Sonderzeichen, Unicode-Form). Kein Mail-, Kopier- oder Ticketweg.
- Der Dialog erscheint **nur nach einem echten Absturz** und je Absturz **einmal**, nicht nach einem harten Stopp (Xcode „Stop“, Programm beenden erzwingen).
- Release akzeptiert nur `https`.

## 9. Plattform und Sicherheit
- **Ohne App-Sandbox** (damit Medien automatisch lesbar sind), **Hardened Runtime** an, keine Ausnahmen. Datenbank und Protokoll sind nur für den Benutzer lesbar (700/600). Netzwerk nur über die API-Warteschlange (ab 0.3.1: Fehlerbericht, Versions-, Update-, Lizenz-Check) zu `diskarchive.app`. Keine Verschlüsselung der Datenbank (FileVault schützt die Ruhedaten). Weitergabe braucht Developer-ID-Signatur und Notarisierung.
- **Speichermedien: ausschließlich Lesezugriff (Nutzer 15.10., verbindlich, Haftung).** Die App darf auf Speichermedien **nichts schreiben, ändern, umbenennen, verschieben, löschen, auswerfen oder in den Papierkorb legen**, und sie bietet dafür auch **keine Funktion** an (Menüs, Kontextmenüs, Tastenkürzel). Erlaubt sind nur: Verzeichnisse und Metadaten lesen (`getattrlistbulk`, `stat`), Dateien **nur zum Lesen** öffnen (Teil-Prüfsumme, später Metadaten und Vorschaubilder), FSEvents beobachten, „Im Finder anzeigen“. Alles, was die App schreibt (Datenbank, Protokoll, Fehlerbericht-Ausgang, Absturzdatei, Vorschaubilder), liegt im eigenen Datenordner **auf dem Mac, nie auf einem Medium**. Nachweis: eine zentrale Schreibschranke (`todo.0.4.014`) und ein Wächter-Test über den Quelltext. Grenze, die man ehrlich nennen muss: macOS kann beim bloßen Lesen die Zugriffszeit einer Datei ändern und legt auf Medien eigene Dateien an (`.DS_Store`, `.Spotlight-V100`, `.fseventsd`); das geschieht durch das System, nicht durch die App, und ändert keinen Dateiinhalt. Eine technische Erzwingung über das Betriebssystem (Sandbox) ist nicht möglich, weil die App Medien automatisch lesen muss (siehe oben).
- Daten: SQLite (GRDB, WAL), `~/Library/Application Support/Disk Archive/archive.sqlite`; Protokoll `~/Library/Logs/Disk Archive/`. Schema und Regeln: Abschnitt „Datenbank“.

## 10. Darstellung
- **Chips werden nie gekürzt (Nutzer 05.10.):** Passt der Text nicht in die Zeile, bricht der Chip um; ist der Text länger als der Behälter, bricht er im Chip um. Gilt für alle Chips (Ausschlüsse, Filter, Medien, Status).
- **Texte ohne Layout-Vorlage (Nutzer 05.10.):** Jeder Text, der nicht im Layout steht, ist ein **Vorschlag** (`ProposalCopy`) und erscheint im **Debug-Build rot** (Debug-Menü „Vorschlagstexte rot“), nicht darstellbare Texte (Mitteilungen, Alerts) mit Präfix „[V] “. Der Nutzer nimmt sie ins Layout auf oder streicht sie. `LayoutCopy` enthält nur Layout-Texte.
- **Zahlen (Nutzer 05.10.):** Tausendertrenner ist der **Punkt** („12.480“, „238.421 Dateien“), wie macOS auf Deutsch (Layout seit 07.10. ebenso).
- **Button-Regeln (Nutzer 05.10.: „es gibt keinen Mix aus Buttons“):** (1) **Zwei Größen, Maße nur aus dem Komponentenkatalog** (`layout/Komponenten.dc.html`, Zusammenfassung `docs/Komponenten-Masse.md`; ersetzt die alten Werte 35/28 pt): **Groß** = 14/600, Innenabstand 10/18, Höhe **38,8**, Radius 8, Rahmen 1 px — für Dialoge, Details, Einstellungen; **Klein** = 12/600, Innenabstand 4/12, Höhe **24,4**, Radius 8 — für Popover, Selectgroups, Filterleiste, Dropdown. (2) **In einer Gruppe nie gemischt:** Alle Knöpfe, die nebeneinander oder untereinander als Auswahl stehen (Details: „Vergessen“, „Neu indizieren“, „Inhalt anzeigen“), haben **dieselbe Größe und dieselbe Höhe**. Die Größe bestimmt das Layout der Sektion, nicht der Knopf. (3) **Breite = Inhalt + Innenabstand**, nie gestreckt und keine Mindestbreite, **Ausnahme** nur, wenn das Layout `flex:1` vorgibt (Dialoge 13 und 14: zwei gleich breite Knöpfe). (4) Der Bestätigungsknopf hält seine Breite in allen Stufen (längster der drei Texte). (5) Neu angelegte Knöpfe nehmen **eine** Stilvorlage (`PrimaryButtonStyle`, `SecondaryButtonStyle`; rote Aktionen über den Bestätigungsknopf; `DestructiveButtonStyle`/`GhostButtonStyle` entfallen, 10.10. ungenutzt) mit Parameter `size: .standard | .compact`, keine eigenen Abstände je Ansicht.
- Hell und Dunkel nach Layout (Rollenfarben, Auswahl #4A4949 dunkel, Schatten immer #2D2B2B). **Farbe bedeutet Zustand, bedient wird in Schwarz.** App-Icon: Kachel 824/1024, Symbol 60 % der Kachel; **das dunkle Icon (Verlauf #575757 nach #1F1F1F, helles Symbol) ist das eine App-Icon in Hell und Dunkel, kein Wechsel nach Erscheinungsbild** (Nutzer 02.10.).

## 11. Offene Entscheidungen
- **Filterchips in Einstellungen → Speichermedien** (Alle / Indiziert / Offline / Nicht erlaubt): **[Annahme]** „Indiziert“ = Index vollständig (online oder offline), „Offline“ = nicht angeschlossen und Index vorhanden, „Nicht erlaubt“ = Nein ohne Index. Chips können sich überschneiden.
- **Widersprüche Layout ↔ Konzept:** am 08.10. alle acht entschieden bzw. im Layout korrigiert (Bestätigungsknopf, Knopffarbe, Pausen-Mitteilungen, Sprache, kein blauer Spinner, Icon-Füllung 50 %, keine Chips in der Spaltenansicht, „zu Pausen“).

---

# Regelliste Artefakte (Spezifikation)

**Immer ausgeschlossen** (unabhängig von allen Schaltern, nicht Teil der Artefakt-Regelliste): `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `System Volume Information`, außerdem im Code `.TemporaryItems`, `.DocumentRevisions-V100` und `._*`. Grund: Zugriffsfehler, riesige Systembäume, Datenschutz. **Eigene Ausschlüsse** des Nutzers (Chips, Kontextmenü): Voreinstellung leer.


```
KONZEPT: ARTEFAKTDATEIEN IGNORIEREN
Disk Index, Stand 01.10.2026
===================================================================

1. ZIEL
-------------------------------------------------------------------
Eine kuratierte, schreibgeschützte Regelliste ("Artefaktdateien"), die
per Schalter aktiviert wird und typischen Müll (temporäre Dateien,
Backups, Systemreste, Abhängigkeits- und Cache-Ordner) vom Indexieren
ausschließt. Sie ergänzt die individuellen Ausschlüsse des Nutzers,
ersetzt sie aber nicht.

2. GRUNDREGELN
-------------------------------------------------------------------
- "Ignoriert" bedeutet NICHT INDEXIERT. Ein ignorierter Ordner wird
  nicht betreten (ganzer Teilbaum übersprungen). Es gibt keine Zählung,
  keine Größenmessung und keine Statuszeile "x GB übersprungen".
- Keine Regelliste in der UI. Der Schalter erklärt sich über einen
  kurzen Info-Text (siehe Abschnitt 8).
- Eigene Ausschlüsse und Artefaktregeln addieren sich (Vereinigung).
- Ausnahme-Möglichkeit: ein Pfad kann trotzdem eingeschlossen werden,
  damit ein einmal ignorierter Ordner nicht unauffindbar wird.
- Der Artefaktschalter ist standardmäßig AN.
- Nicht Teil der Regelliste: Systemordner, die die App IMMER auslässt, auch
  bei Artefakte aus und Unsichtbare an (.Spotlight-V100, .fseventsd,
  .Trashes, System Volume Information und weitere, siehe README,
  Abschnitt „Immer ausgeschlossen“).

3. ABGLEICH
-------------------------------------------------------------------
- Case-insensitiv durch Kleinschreibung auf BEIDEN Seiten: Dateiname
  aus dem Dateisystem und Muster aus der Regelliste werden vor dem
  Vergleich in Kleinschreibung umgewandelt.
- Unicode-Kleinschreibung, locale-unabhängig (keine Sprachregeln wie
  türkisches i).
- Folge: Die Regelliste enthält pro Eintrag nur eine Schreibweise
  (kleingeschrieben). Das Verhalten ist auf APFS, HFS+, NTFS, exFAT und
  case-sensitiven Volumes identisch.
- Zwei Regeltypen, in der Liste sichtbar unterschieden:
    EXAKT   Name muss vollständig übereinstimmen   (node_modules)
    MUSTER  Platzhalter * am Anfang ODER Ende      (*.tmp, .git*, ._*)
- Wildcard-Regeln (bewusst minimal):
    * steht für beliebig viele Zeichen, auch null.
    Genau ein * pro Muster, nur ganz am Anfang (Endungs-Muster) oder
    ganz am Ende (Präfix-Muster). Kein * in der Mitte, kein ? und
    keine []-Klassen.
    Verglichen wird nur der Datei-/Ordnername, nie der Pfad.
    Endungs-Muster immer MIT Punkt und OHNE Wildcard dahinter:
    *.part trifft, *.part* NICHT verwenden (würde Split-Archive wie
    archiv.part1.rar mitnehmen).
- Regeln gelten für Datei- UND Ordnernamen. Trifft eine Regel einen
  Ordner, wird der gesamte Teilbaum übersprungen.
- Sonderzeichen: "icon" + Wagenrücklauf (\r) muss das Steuerzeichen
  tatsächlich enthalten. In der Anzeige lesbar darstellen, z. B.
  "Icon (Ordnericon)".

4. VERHÄLTNIS ZUM SCHALTER "UNSICHTBARE DATEIEN"
-------------------------------------------------------------------
Dateien/Ordner mit Punkt am Anfang steuert der eigene Schalter
"Unsichtbare Dateien". Die Kategorie "Unsichtbare Artefakte" ist Teil
des Artefaktschalters und greift auch dann, wenn unsichtbare Dateien
eingeschaltet sind:

  Unsichtbare Dateien | Artefaktdateien | Ergebnis
  --------------------+-----------------+--------------------------------
  aus                 | an oder aus     | alle Punkt-Namen draußen
  an                  | an              | Punkt-Namen drin, außer Sammlung
  an                  | aus             | wirklich alles drin

Klarstellung: zwei unabhängige Filter mit unterschiedlichem Ziel
  - "Unsichtbare Dateien auslassen" zielt auf die EIGENSCHAFT:
    Dateien/Ordner, die unsichtbar sind (Punkt am Anfang). Es ist ein
    pauschaler Filter, der jede Datei dieser Art trifft, unabhängig
    davon, was sie ist.
  - "Artefaktdateien (Müll) auslassen" zielt auf BEKANNTE ARTEFAKTE
    nach Best Practice: eine kuratierte Liste, die sichtbare UND
    unsichtbare Einträge enthält (z. B. .tmp, node_modules, .ds_store,
    .git).
  - Es gibt eine gewollte Überschneidung: unsichtbare Artefakte wie
    .ds_store, .git oder .venv werden von BEIDEN Filtern erfasst. Ein
    Element wird ausgelassen, sobald EIN aktiver Filter es trifft.
  - Praktische Folge: Wer "Unsichtbare Dateien" einschaltet, bekommt
    seine eigenen unsichtbaren Dateien (z. B. .env, .vscode), aber
    nicht den bekannten Müll, solange der Müll-Filter an ist.

5. KATEGORIEN UND REGELN
-------------------------------------------------------------------
Hauptschalter schaltet alle Kategorien zusammen. Einzelne Kategorien
abschaltbar zu machen ist optional (für v1 nicht nötig).
Typ: E = exakt, M = Muster

5.1 Temporäre Dateien
  M  *.tmp
  M  *.temp
  M  *.swp
  M  ~$*              (Office-Lockfiles)
  M  *.crdownload     (Chrome)
  M  *.part           (Firefox, Chrome)
  M  *.partial
  M  *.download       (Safari)
  M  *.opdownload     (Opera)
  M  *.log

5.2 Backup- und Autosave-Dateien
  M  *~               (deckt auch *.psd~ und andere Tilde-Backups ab)
  M  *.bak
  M  *.orig
  M  *.autosave

5.3 System-Müll (nicht unsichtbar benannt)
  E  thumbs.db
  E  ehthumbs.db
  E  desktop.ini
  E  $recycle.bin
  E  icon\r           (macOS-Ordnericon-Datei, Name endet auf \r)

5.4 Abhängigkeitsordner
  E  node_modules
  E  pods
  E  __pycache__
  E  deriveddata
  E  lib-cov

5.5 Unsichtbare Artefakte (Punkt-Namen, immer ignoriert)
  Versionsverwaltung:
  M  .git*            (.git, .gitignore, .gitattributes, .gitmodules,
                       .gitkeep; .github wird mitgetroffen, bewusst)
  E  .svn
  E  .hg
  Build und Cache:
  E  .venv
  E  .cache
  E  .next
  E  .nuxt
  E  .gradle
  E  .parcel-cache
  E  .turbo
  E  .pytest_cache
  E  .mypy_cache
  E  .sass-cache
  macOS:
  E  .ds_store
  M  ._*              (AppleDouble-Reste, v. a. auf exFAT/FAT32)
  E  .appledouble
  E  .lsoverride
  M  .trash-*         (Linux-Laufwerke: .Trash-1000)
  E  .trash
  E  .temporaryitems
  E  .documentrevisions-v100

6. BEWUSST NICHT IN DER LISTE
-------------------------------------------------------------------
- *.csv, *.gz, *.dat, *.out: echte Nutzerdaten.
- logs, results (Ordner): zu generisch bzw. projektabhängig. (*.log
  ist dagegen drin, siehe 5.1; npm-debug.log ist dadurch abgedeckt.)
- build, dist, out, target: zu generisch. Falls später gewünscht, nur
  mit Marker-Check (z. B. dist nur neben package.json).
- .env*: Konfiguration/Zugangsdaten, die man beim Aufräumen finden will.
- .vscode, .idea, .github (als Ziel): Projekt-/Nutzerdaten. .github
  wird nur als Nebeneffekt von .git* getroffen.

7. OFFENE PUNKTE
-------------------------------------------------------------------
- Kategorien einzeln abschaltbar (v1 oder später).
- Marker-Check für build/dist/out/target (v1 weglassen empfohlen).

8. TEXTE FÜR DIE SETTINGS
-------------------------------------------------------------------
Schalter-Titel:
  Artefaktdateien ignorieren

Info-Text (eine Zeile, keine Regelliste in der UI):
  Ignoriert temporäre Dateien (.tmp, .part, .log), Backups (~),
  Systemreste (Thumbs.db) und Ordner wie node_modules oder .git.

```

---

# Datenbank (seit 0.3, Schema eingefroren)

Kurzfassung der früheren `datenbank-konzeption.md` (Volltext: [archiv/datenbank-konzeption-bis-2026-10-14.md](archiv/datenbank-konzeption-bis-2026-10-14.md)). ✓ = gebaut und von Claude abgenommen, ○ = offen (Aufgabe in [TODO.md](TODO.md)).

**Grundsatz (Nutzer 11.10.):** Nach 0.3 wird **keine Tabelle mehr verändert, nur erweitert**: neue Schlüssel in `settings`, `storage_meta`, `item_meta` oder neue Tabellen. Das Schema ist die erste GRDB-Migration `0.3.0-schema`; spätere Versionen hängen nur Migrationen an. Ab 0.4 wird auf fremden Rechnern nie etwas gelöscht (Sicherung vor Erweiterung, Schutz vor Rückschritt ○ `bug.0.4.013`).

**Datei:** `~/Library/Application Support/Disk Archive/archive.sqlite` (eine Datei für alle Medien, WAL, `auto_vacuum` inkrementell, Journal auf 64 MB begrenzt ✓). Die alte `index.sqlite` wird nie geöffnet (kein Übernehmen, keine Sicherung). Kennungen sind `AUTOINCREMENT` (nie wiederverwendet), Zeiten ganze Sekunden seit 1970, Ja/Nein und Aufzählungen kleine Zahlen. Besitz-Verweise löschen mit (`ON DELETE CASCADE`), Nachschlage-Verweise (`extID`, `keyID`) nicht.

| Tabelle | Inhalt |
|---|---|
| `storages` | ein Medium: Kennungen, Name und `slug`, Typ, Dateisystem, Kapazität, Entscheidung, Status, Pause, Zähler, Zeitpunkte |
| `storage_meta` | alles Weitere je Medium als Schlüssel/Wert (abgeschlossene Tiefe, Überwachungsstand, Anzeige absolut/Prozent …); **Einstellungen je Medium immer hier** („Medium-Wert, sonst globaler Wert“) |
| `items` | der Baum: `storageID`, `parentID`, `name`, `slug`, `extID`, `kind`, `isFolder`, `depth`, `status`, `modifiedAt`, `fileID`; nur Ordner: `contentStamp`, `listedAt`, `unreadable`. **Kein gespeicherter Pfad** (Pfad = Kette der Elternordner), **kein Suchindex** |
| `item_details` | Größe, Erstelldatum, Paket ja/nein (nur Detailansicht) |
| `item_meta` | Metadaten je Datei als Schlüssel/Wert mit Herkunft (gelesen / Nutzer / System); angelegt, gefüllt ab 0.5 ○ |
| `item_checksum` | Teil- und volle Prüfsumme; Teil-Prüfsumme für Favoriten ✓, volle ab 0.8 ○ |
| `favorites`, `extensions`, `meta_keys` | Favoriten; Nachschlagelisten Endung und Schlüssel |
| `settings` | Einstellungen und Systemzustand als Schlüssel/Wert ✓ (außer Sprache und Fensterposition) |
| `api_queue` | Aufträge ins Netz (Fehlerberichte, Versions-Check) ✓ |

**Keine Tabelle:** Vorschaubilder (Dateien `Thumbnails/<storageID>/<itemID>` ○ 0.6), Protokoll (Datei), Statistik.

**Suche und Sortierung ✓:** `slug` = Name klein, Umlaute und Akzente zum Stammlaut, ß → ss; der Suchbegriff wird gleich umgewandelt. Teilwortsuche per `LIKE '%…%'` auf `slug` von Dateien, Ordnern und Medien. Trefferliste läuft einzeln und hört nach 500 Treffern auf, die Trefferzahl läuft parallel über Kennungsbereiche. Spalten sortieren wie der Finder (natürlich, Ordner und Dateien gemischt). Filter über Zahlenfelder (`kind`, `extID`, `modifiedAt`, `storageID`, `depth`). Alter-Filter = Änderungsdatum der Datei.

**Status je Eintrag ✓:** 0 sichtbar, 1 zu-löschen (Regel schließt ihn aus), 2 verschwunden (wird am Laufende gelöscht, nachdem Umbenennungen verbunden wurden). Regeländerungen laufen als Warteschlange im Hintergrund; eine Stunde nach der letzten Änderung wird gelöscht („Index jetzt bereinigen“ sofort). Lesewege filtern nur `status = 0` in SQL. Die Suche wartet, die Spalten zeigen „Inhalte werden geladen“; ein Ereignis „Warteschlange leer“ plus Sicherung bei Fehler/Beenden verhindert Hängen. Wartescreen der Suche ○ 0.5.

**Umbenennen und Verschieben erkennen ✓:** Die Kennung bleibt erhalten, damit Favoriten und später Metadaten nicht verloren gehen. APFS/HFS+: `fileID` (FAT/exFAT liefern sie nicht verlässlich: bei Verschieben neu, exFAT in der ersten Sitzung ein Fantasiewert). Live: FSEvents-Ereignispaare „alt → neu“. FAT/exFAT außerhalb der Überwachung: Größe + Änderungsdatum (±1 h wegen Ortszeit) + Erstelldatum + Endung, Ordner über Name und Eltern; nur eindeutige Treffer, bei Mehrdeutigkeit entscheidet die Teil-Prüfsumme (erste und letzte 64 KB), sonst gilt „neu“. Ändern sich Größe oder Datum einer Datei, werden ihre gelesenen Metadaten und Prüfsummen gelöscht (Nutzerwerte bleiben).

**Wartung ✓:** Schadenprüfung (`quick_check`) alle 7 Tage oder nach Absturz, im Hintergrund. Aufräumen und Verkleinern nach N = 10.000 Änderungen im Leerlauf; WAL wird nach Läufen gekürzt. Kein Startbildschirm (Menüleiste bereit nach 0,1–0,25 s). Ein Fenster „Datenbank wird aktualisiert“ gibt es erst bei einer Schema-Erweiterung durch ein Update ○.

**Netz (API) ✓:** Der einzige Weg ins Netz ist die Warteschlange `api_queue`: online sofort leeren (macOS-Netzmeldung), offline Ping alle 60 s. Versions-Check `GET https://diskarchive.app/api/version/` (Antwort heute `{"version":"1.0.0"}`); verglichen wird `n.n`.
- App älter als API → Update-Modal (mit „Dieses Update überspringen“).
- **Beta (0.x) und API ≥ 1.0** → Hinweis und **7 Tage** Frist (`betaExpiryNoticedAt`); auf einer **frischen Installation (keine Datenbank) sofort gesperrt**. Eine gesperrte Version bleibt gesperrt (`lockedVersion`); heraus kommt man nur mit einer neueren App.
- API 1 Monat nicht erreicht → gesperrt; Beta-Verfallsdatum 60 Tage nach dem Build → gesperrt.
- **Gesperrt = 100 % nur ansehen:** kein Indizieren, keine Überwachung, keine neuen Medien, keine Schreibzugriffe (`FeatureAccess`). Uhr des Macs genügt.
- Zählen aktiver Installationen: erst mit der Lizenz (0.9).

**Messung (196 vorher / 238 nachher, 1 Mio. und 8,6 Mio. Einträge) ✓:** Datenbank 54–63 % kleiner; häufige Suche 91–98 % schneller; Filter nach Dateityp von 6,5 s auf 0,13 s; Spaltenansicht mit 50.000 Kindern innerhalb ±10 % (S1 +3,4 %, S2 −9 %). Schwellen bestanden. Berichte: `Werkzeuge/messung/`.

**Noch offen im Konzept:** Metadaten-Durchgang mit Markierung „schon analysiert“ (Zeile `_analyzed`, 0.5); Vorschaubilder löschen mit dem Eintrag (0.6); Duplikate über volle Prüfsumme nach Größe gruppiert (0.8); Export mit vorab geladenen Ordnerpfaden (0.7); Duplikat-Screen und Export dürfen auch im gesperrten Zustand laufen (nur lesen).

---

# Architektur (Stand 14.10.2026)

**Prinzip:** Die App schreibt nie auf Medien. Sie liest Medien, speichert ein Inventar in SQLite und hält es mit Live-Überwachung aktuell. Kein Sandbox, kein iCloud, Netz nur über die API-Warteschlange (Fehlerbericht nur mit Zustimmung, Versions-Check).

| Baustein | Datei(en) | Aufgabe |
|---|---|---|
| Erkennung | `Recognition/MediumMonitor`, `VolumeLookup`, `VolumeCandidateRule`, `DiskArbitrationLookup` | `NSWorkspace` (`didMount`, `willUnmount`, `didUnmount`) und beim Start `mountedVolumeURLs`; Kandidatenregel (lokal, `/Volumes/`, wechselbar/auswerfbar/nicht intern, keine Images, keine Time-Machine-Snapshots) |
| Entscheidung und Lebenszyklus | `Recognition/MediumCoordinator`, `MediumRecognitionStartup` | bekannt/unbekannt (Volume-UUID, sonst Fingerabdruck aus Erstelldatum, Größe, Dateisystem), Erkennungs-Dialog, `decision` Ja/Nein/offen, Start der Läufe |
| Indizieren | `Indexing/IndexingService`, `DirectoryIndexer`, `IgnoreMatcher`, `ArtifactRules` | ebenenweise (Breitensuche), je Ordner lesen, Stapel zu 5.000 Einträgen, `completedDepth`, Fortschritt höchstens 0,99, Pause/Abbruch/Ruhezustand, Ausschlussregeln |
| Live-Überwachung | `Indexing/ChangeWatcher`, `ChangeWatcherEngine` | FSEvents je Medium, gebündelt nach Ruhezeit, liest betroffene Ordner neu; `MustScanSubDirs`/`RootChanged` lösen Vollabgleich aus |
| Speicher | `Storage/V3/` (`IndexStoreV3` Actor, `SchemaV3`, `DirectoryWriterV3`, `IndexStoreV3+Reading`, `SearchPlanV3`), `IndexRecords` | SQLite über GRDB (`DatabasePool`, WAL), Migration `0.3.0-schema`, Schreibwege je Ordner in einer Transaktion, Lesewege für Spalten, Suche, Favoriten; Wartung und `quick_check` im Hintergrund. Siehe Abschnitt „Datenbank“ |
| Lesezugriff der Oberfläche | `Indexing/IndexRepository`, `Models/SearchIndex`, `SearchState` | Ordnerinhalte (Cache, 30 Ordner), Suche, Favoriten |
| Zustand | `App/AppState`, `AppSettings`, `GlobalPause` | ein `@Observable` für Fenster, Medien, Filter, Einstellungen, Pause |
| Oberfläche | `Views/*`, `MenuBar/*`, `DesignSystem/*` | SwiftUI plus AppKit (Panels, Menüleiste); Texte aus `LayoutCopy` (dem Layout entnommen) |
| Fehlerberichte | `App/DiskIndexLog`, `ReportScrubber`, `IssueTracker`, `CrashReportText` | lokales Protokoll, Absturzschreiber (signalsicher, `crash-last.txt`), Bericht schema 2 ohne Namen |
| Start | `App/AppDelegate`, `AppLaunch`, `AppWindowPresenter`, `LaunchAtLogin` | Einzelinstanz (Übergabe per `DistributedNotificationCenter`), Start beim Anmelden per `SMAppService`, Dock-/Hintergrundverhalten |

**Ablauf beim Anschließen:** Ereignis → Kandidat? → bekannt? (Volume-UUID) → unbekannt: Zugriffsprobe, Eintrag `.undecided`, Erkennungs-Dialog → „Indizieren“: Lauf (ebenenweise, jede Ebene wird gespeichert, Abbruch durch Abziehen setzt später fort) **und sofort Live-Überwachung** (Nutzer 09.10.: Änderungen nach dem Erstlauf kamen nicht an) → **bekannt und `indexed`: vollständiger Abgleich** (jeder Ordner wird gelesen, neu/geändert/entfernt) und danach Live-Überwachung. Abziehen: Überwachung stoppen, Stand speichern, Medium „Offline“, Index bleibt durchsuchbar.

**Speicherung:** `~/Library/Application Support/Disk Archive/archive.sqlite` (Tabellen und Regeln: Abschnitt „Datenbank“). Einstellungen liegen in der Tabelle `settings` (Ausnahmen: Sprache und Fensterposition in den Voreinstellungen). Fehlerberichte und Versions-Check laufen über die Warteschlange `api_queue`.

**Scan-Regeln:** Ebene 1 = Inhalt der Wurzel; Tiefe *d* = *d* Ebenen mit Inhalt, die Ordner der letzten Ebene bleiben ungeöffnet (Hinweis „Inhalt wird nicht indiziert“). Pakete (`.app` u. a.) zählen als Datei, Symlinks werden nicht verfolgt. Immer ausgeschlossen: siehe „Regelliste Artefakte“. Ein nicht lesbarer Ordner markiert seinen bisherigen Inhalt **nie** als entfernt. Nur Leseoperationen auf dem Medium.

**Grenzen:** FSEvents sieht nur Änderungen, die dieser Mac macht, solange das Medium hängt (FAT-Sticks haben keinen Verlauf). Deshalb der vollständige Abgleich beim Anschließen. Verschieben/Umbenennen: APFS/HFS+ über die Datei-ID, live über Ereignispaare, FAT/exFAT über Größe, Datum und Teil-Prüfsumme (Abschnitt „Datenbank“); im Zweifel gilt Löschen plus Neu.

**Messwerte und Spike-Ergebnisse:** `archiv/readme-technik-bis-2026-10-04.md`.
