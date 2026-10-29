# Konzept: Medien: Lebenszyklus, Statusmodell, Fehler-Modal, Pausieren (Abschnitte 2, 2a, 2b, 3)

Teil des Konzepts, ausgelagert aus [README.md](../README.md) am 23.10.2026 (gilt unverändert; bei Widerspruch zum Layout gilt das Konzept, außer reine Optik).

## 2. Medien-Lebenszyklus
1. **Erkennung:** Jedes angeschlossene, lokale, externe Volume (Regel siehe README „Technische Grundlagen“) wird **sofort registriert**, auch wenn noch keine Entscheidung vorliegt. Es erscheint **sofort** in Einstellungen → Speichermedien (Status „Ausstehend“), auch wenn das Fenster dabei schon offen ist. Gleichzeitig öffnet sich der **Erkennungs-Dialog**.
2. **Identität:** UUID des Volumes (DiskArbitration), sonst Fingerabdruck aus Dateisystem, Erstelldatum und Größe. Details im README.
3. **Entscheidung (Erkennungs-Dialog, 02):** **Fokus einmal beim Erscheinen (Nutzer 26.10., `bug.0.4.209`):** Das gilt für den Dialog, für jeden anderen Hinweis, den die App von sich aus zeigt („Ersetzt dieses Medium?“, Absturzbericht), und für die Rückfrage „Ignorieren bestätigen“, die eine Nutzeraktion öffnet.
   - Er springt **beim Erscheinen einmal** nach vorn und nimmt dabei den Fokus.
   - Danach fordert er ihn **nie wieder** an: nicht beim nächsten Medium, nicht nach einer Entscheidung, nicht beim Aushängen.
   - Klickt der Nutzer in ein anderes Fenster, egal ob in der App oder in einer anderen, **verschwindet der Dialog dahinter**. Er schwebt nicht über allem und bleibt offen, bis der Nutzer entscheidet. Holt der Nutzer ihn selbst wieder vor (Menüleiste, Zeile „Entscheidung offen“, Klick auf den Dialog), ist das kein erneutes Anfordern. **„Indizieren“** = Ja, **„Nicht indizieren“** = Nein, **„Für dieses Medium merken“**: der Dialog erscheint dann für dieses Medium nicht mehr; **ohne Haken erscheint er beim nächsten Anschließen wieder** (Nutzer 16.10., `todo.0.4.034`); **eine Änderung der Entscheidung in 05 oder 06 gilt als gemerkt** (Host 18.10., `bug.0.4.075`). Der App-Start zählt als Anschließen; bis zur Antwort im Dialog gilt die letzte Entscheidung weiter. **Neu formatiert (Nutzer 16.10., `todo.0.4.032`):** Ist ein neues Medium erkannt und gibt es genau ein Offline-Medium mit gleichem Namen, fragt die App, ob es das alte ersetzt („Altes vergessen“ / „Behalten“). Nie automatisch vergessen.
   - **Reihenfolge (Nutzer 26.10., `bug.0.4.215`):** Diese Rückfrage kommt **zuerst und allein**, vor dem Erkennungsdialog.
   - **„Altes vergessen“:** Das neue Medium übernimmt die Entscheidung des alten („Indizieren“/„Nicht indizieren“ und „Für dieses Medium merken“). Der Erkennungsdialog entfällt, wenn die alte Entscheidung gemerkt war. War sie nicht gemerkt, folgt er.
   - **„Behalten“:** Der normale Erkennungsdialog folgt. Die Entscheidung ist jederzeit in **06 (Medium-Details)** und **05 (Einstellungen → Speichermedien)** als **„Soll indiziert werden“ / „Indizieren“ Ja | Nein** änderbar.
4. **Nein stoppt, löscht nichts und versteckt nichts.** Ein vorhandener Index bleibt erhalten, sichtbar und durchsuchbar. Es gibt nur keine Aktualisierungen mehr (keine Live-Überwachung, kein Abgleich beim Anschließen). **Ja** nimmt auf (Erstlauf oder Abgleich).
5. **Index vorhanden** heißt: mindestens eine abgeschlossene Ebene oder mindestens ein nicht entferntes Objekt.
6. **Sichtbarkeit (verbindlich):**

   | Ort | Zeigt |
   |---|---|
   | Einstellungen → Speichermedien (05) | **alle registrierten** Medien, auch ohne Entscheidung und ohne Index |
   | Dashboard / Übersicht (04) | nur Medien **mit Index** (Status Online, Offline, x % indiziert, Fehler), nie „Ausstehend“ |
   | Spaltenansicht-Seitenleiste (07), Suche (Medienkacheln, Medien-Auswahl im Filter), Favoriten | nur Medien **mit Index** (und Entscheidung) |
   | Dropdown in der Menüleiste (03) | **angeschlossene** Medien |

7. **Vergessen** ist die Hauptfunktion zum Entfernen (Medium-Details 06, Alle Speichermedien vergessen in Einstellungen → Erweitert; rote Bestätigung mit zwei Klicks). Es löscht die **Registrierung, den Index und die Favoriten** vollständig, sodass das Medium beim **nächsten Anschließen als unbekannt** gilt und der **Erkennungs-Dialog erneut** erscheint. Ist es beim Vergessen angeschlossen, enden Lauf und Überwachung sofort. **Begründung:** Ein vergessenes Medium wird behandelt, als hätte die App es nie gesehen. Es soll nie passieren, dass ein Medium versehentlich nicht mehr indiziert werden kann. Mit der Pause hat das **nichts** zu tun (siehe Abschnitt 3). **Sofort dauerhaft (Host 28.10., `bug.0.4.224`):** Nach dem zweiten Klick gilt das Vergessen auch dann, wenn die App gleich danach beendet wird oder abstürzt. Das Löschen großer Indizes darf im Hintergrund weiterlaufen und setzt nach einem Neustart fort. Bis dahin zeigt die App nichts mehr vom vergessenen Medium, und das Beenden wartet nicht darauf.
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

**Dauerhafte Lücke = Fehler (Nutzer 25.10., `bug.0.4.199`, ersetzt „99 % indiziert“ aus `bug.0.4.151`):** Endet ein Lauf, und Ordner auf dem Medium waren nicht lesbar (nicht die immer ausgeschlossenen Systemordner), ist der Status **Fehler** (bzw. „Fehler, offline“) mit dem Grund „Einige Ordner auf diesem Medium konnten nicht gelesen werden.“ Im Hintergrund bleiben beide Angaben gespeichert: die Lücke (`indexGaps`) und der Fortschritt. Jedes Anschließen liest die Lücke neu; ist sie danach geschlossen, gilt Online. **Details-Modal:** Zeile **„Indiziert“** unter „Zuletzt gesehen“ mit dem Fortschritt nach derselben Definition wie überall (`konzept/indizieren.md`): vollständig **100 %**, während eines Laufs der laufende Wert, mit Lücke z. B. **99 %**.

Weitere Information (Dateizahl, „zuletzt gesehen …“, „Fehler vor 2 Std. · erneut versuchen“) steht als **Textzeile**, nicht als zweiter Chip. **Das Menüleisten-„!“ erscheint nur für angeschlossene Medien mit Fehler** *(bestätigt)*.

- **„Ausstehend“ erscheint nie im Dashboard.** Es bedeutet „kein Index“, und ohne Index gibt es dort nichts zu zeigen. „Ausstehend“ und „Nicht erlaubt“ stehen nur in **Einstellungen → Speichermedien** (und „Ausstehend“/„Neu erkannt“ im Dropdown und im Menüleisten-Symbol).
- **Nein mit vorhandenem Index** (Nein gesetzt, nachdem indiziert wurde): Status ergibt sich aus Verbindung und Index wie in der Tabelle (Online/Offline/x %); **die Entscheidung Nein steht nur in der Auswahl „Indizieren“** (Ja | Nein). „Nicht erlaubt“ als Status gilt nur für Nein **ohne Index** *(bestätigt 01.10.)*. **Nein plus unvollständiger Index, angeschlossen:** Status „x % indiziert“, der Lauf steht still *(bestätigt)*.
- **Vollständig indiziert, App-Neustart oder Anstecken (Nutzer 04.10.: „egal was passiert, es muss immer alles indiziert werden“):** Bei **jedem Anschließen** und **jedem App-Start mit angeschlossenem Medium** läuft ein **vollständiger Abgleich**: **jeder Ordner wird vollständig gelesen** (keine Abkürzung über Ordner-Änderungsdatum oder FSEvents-Verlauf, FAT-Sticks haben keinen), mit dem Index verglichen und **ergänzt, geändert oder als entfernt markiert**. Der Inhaltsstempel eines Ordners (Hash über Namen, Größen, Änderungsdaten) spart nur das **Schreiben**, nie das **Lesen**. Status bleibt **„Online“**, **kein Badge** in der Menüleiste (Layout 01: online und fertig = kein Badge; Nutzer 08.10.: kein blauer Spinner). Danach übernimmt die **Live-Überwachung**. **„Neu indizieren“**: Lauf von Grund auf, Status kann **„x % indiziert“** sein, Spinner grün. Dauert ein Lauf **länger als 59 Sekunden**, geht die **Mitteilung** „Medium vollständig indiziert“ raus *(bestätigt)*. **Passt etwas nicht** (Ereignis für einen Pfad, der im Index fehlt oder nicht stimmt; Zähler weichen ab; Lesefehler), **prüft die App den betroffenen Ordner sofort neu**, bei Zweifel das ganze Medium.
- **Fehler ohne Index:** Ein fehlgeschlagener Erstlauf **ohne** Index erscheint nicht im Dashboard. Das „!“ im Menüleisten-Symbol öffnet das **Indizierungsfehler-Modal** (Abschnitt 2b).

## 2b. Indizierungsfehler-Modal (Layout 14; Nutzer 01.10.)
- **Wann:** Schlägt ein Lauf auf einem **angeschlossenen** Medium fehl, erscheint ein **Modal „<Medium> konnte nicht indiziert werden“**, **aber nur, solange das Hauptfenster geöffnet ist**. Es ist die Antwort auf den Fehler-Status im Menüleisten-Symbol (01), im Dropdown (03) und im Dashboard (04): ein Klick darauf öffnet es.
- **Knöpfe:** **„Schließen“** und **„Erneut versuchen“** (primär). „Erneut versuchen“ startet den Scan neu (setzt das Medium falls nötig auf Ja). „Schließen“ lässt den Fehlerzustand **bestehen** (Chip „Fehler“, „!“ im Menüleisten-Symbol), bis ein Lauf gelingt oder der Nutzer in Einstellungen/Details „Soll indiziert werden“ auf Nein setzt. Esc = Schließen. *(bestätigt 01.10.; der Knopf „Medium ignorieren“ aus dem Layout-Stand 23:09 entfällt.)*
- **Grund, aufbereitet:** Kennt die App den Grund, steht er **in verständlichem Deutsch** im Modal (eine Zeile), sonst keine Grundzeile. Beispiele: Leserechte („Disk Archive darf dieses Medium nicht lesen. Das lässt sich in den Systemeinstellungen unter Datenschutz & Sicherheit ändern.“), Verbindung unterbrochen („Die Verbindung zum Medium wurde unterbrochen.“), Zeitüberschreitung („Das Medium reagiert nicht.“), Speicherplatz („Auf diesem Mac ist nicht genug Speicherplatz frei.“), Datenbank („Der Index konnte nicht gespeichert werden.“), nicht lesbare Ordner („Einige Ordner auf diesem Medium konnten nicht gelesen werden.“, `bug.0.4.199`). Technische Fehlertexte, Pfade und Dateinamen erscheinen **nie** im Modal.
- **Parallel** erscheint eine **macOS-Mitteilung** (Ereignis „Systemmeldungen“, Einstellungen → Allgemein → Mitteilungen): Titel „Disk Archive“, „<Medium> konnte nicht indiziert werden“, darunter der aufbereitete Grund (sonst „Beim Indizieren ist ein Fehler aufgetreten.“). Ein **Klick auf die Mitteilung** öffnet das Hauptfenster **mit diesem Dialog**.
- **Mehrere Fehler gleichzeitig:** Modals **nacheinander**, eins je Medium. **Schlägt „Erneut versuchen“ sofort wieder fehl:** das Modal erscheint erneut, aber **höchstens 3-mal je Medium und Stunde** automatisch, danach nur noch über das „!“. **Ist das Hauptfenster beim Fehler zu:** nur Mitteilung und „!“; beim nächsten Öffnen erscheint das Modal **einmal**, wenn der Fehler noch offen ist. *(alle drei bestätigt)*
- Das **Menüleisten-„!“** erscheint nur für **angeschlossene** Medien mit Fehler (siehe 2a).

## 2c. Medientyp USB, SSD, HDD (Nutzer 29.10., `bug.0.4.230`, ersetzt „wechselbar = USB, sonst HDD“ von 28.09.)
- **Wechselbare Medien** (Sticks, Speicherkarten, macOS „Removable Media: Removable“) sind **USB**.
- **Sonst** entscheidet die macOS-Angabe zum Datenträger (wie „Solid State“ in `diskutil info`): **Solid State = SSD**, **Rotational = HDD**. Fehlt die Angabe, gilt **HDD** wie bisher.
- Der Typ wird **bei jedem Anschließen** neu bestimmt und gespeichert; Medien, die gerade offline sind, behalten den alten Typ bis zum nächsten Anschließen. Er wirkt überall gleich: Icon (Karten, Popover, Seitenleiste, Dialog „Neues Medium“, Details) und Spalte „Typ“ in Einstellungen → Speichermedien.

## 3. Pausieren
- **Begriffe und Aufbau (Nutzer 03.10.):** **Einstiegskachel** = Popover am Menüleisten-Symbol (Layout 03: 340 pt, **Radius 14 pt**, **1-pt-Rand** `divider`, Schatten `--shadow-lg` — **Ruhe und Suche gleich**), **Pausentimer** = das kleine Menü unter „Pausiert“. Die Einstiegskachel **verändert nie ihre Position** (nur die Höhe, Oberkante fest direkt unter dem Symbol). **Suchzustand:** Panel-Höhe = Kopf + Trefferliste + Fuß („Alle N Ergebnisse“); die AppKit-Höhe folgt `MenuBarPopoverLayout` **1:1** der SwiftUI-Messung (sonst schneidet `clipsToBounds` den Fuß ab). Der Pausentimer ist ein **eigenes Kindfenster** (`KeyablePanel`), **rechts bündig mit An/Pausiert**, mit **Nase (Pfeil)** am Schalter (Layout Screen 03: 210 pt, Abrundung 8 pt, Hover/Hand-Cursor auf den Dauer-Optionen); er überdeckt die Kachel teilweise und verändert sie nicht.
- Es gibt **nur eine globale Pause** (Dropdown, 03). **Medien können nicht einzeln pausiert werden.**
- Dauer: **30 Minuten, 1 Stunde, Bis morgen (= nächster Tag 09:00 Uhr), Für immer.** Ist schon pausiert, zeigt das Popover „Pausiert für X, bis HH:MM Uhr“ (aktive Dauer ausgegraut, andere ändern die Pause). „An“ setzt sofort fort.
- **„Pausiert“-Segment:** Klick **toggelt** nur das Pausentimer-Menü (Pause erst nach Dauerwahl); erneuter Klick schließt. Klicks auf An/Pausiert schließen das Menü **nicht** über den Popover-Außenklick-Monitor (sonst Doppel-Umschaltung). Dauerwahl → Menü zu, Segment „Pausiert“ aktiv.
- Die Pause **überlebt einen Neustart** (Enddatum wird gespeichert). Bei Ablauf geht die **Systemmeldung** „Medien werden wieder indiziert.“, wenn Mitteilungen an sind, **auch wenn die Pause bei beendeter App abgelaufen ist (dann beim nächsten Start; Nutzer 16.10., `todo.0.4.035`)**.
- **Die Pause betrifft nur das Indizieren.** Alle anderen Funktionen laufen unverändert weiter: Erkennen neuer Medien, Registrierung, Erkennungs-Dialog, Suche, Anzeige. Während der Pause ruht das Indizieren auf **allen** Medien. Wird ein **unbekanntes Medium angeschlossen**, erscheint der **Dialog trotzdem**; bei „Indizieren“ wartet der Lauf („Ausstehend“) und **startet automatisch, wenn die Pause endet, sofern das Medium dann noch online ist** (sonst beim nächsten Anschließen).
- **Menüleisten-Symbol:** Fehler **„!“** hat Vorrang, sonst bei Pause **„X“**; sonst grüner Spinner (**wird indiziert**: Erstlauf oder „Neu indizieren“), pulsierender Punkt (neu erkannt, Dialog offen). Online und fertig = kein Badge, **auch während Abgleich und Live-Sync** (Nutzer 08.10., Layout 01). Priorität: Fehler, Neu erkannt, Pausiert, Wird indiziert. **Badge-Grundfläche immer weiß (~12 pt);** das **X** (und das „!“ laut Layout 02) in **fester dunkler Tinte `#201E1D`**, nicht an `text`/`neutral-800` gekoppelt — sonst ist das X im Dunkelmodus auf dem weißen Kreis unlesbar.
