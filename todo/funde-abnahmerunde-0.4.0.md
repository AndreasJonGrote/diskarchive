# Funde der Abnahmerunde 0.4.0 (`todo.0.4.040`, Nutzer 26.10.)

Gesammelt vom Host während der Runde, nach den drei Stufen (AGENTS.md). Der Supervisor hat den Bericht am 27.10. bestätigt.

**Paketschnitt (Supervisor 27.10.):**

| Paket | Inhalt | Stand |
|---|---|---|
| 34 | 210 (schwer, zuerst), 209 + 216 als eine Aufgabe | **abgenommen 27.10.** (Gesamtlauf 01:29–01:58 grün) |
| 35 | 215 (schwer, zuerst), 212, 213, 214 | **abgenommen 27.10.** (Gesamtlauf 09:25–10:12 grün) |
| 36 | 211, 217, 218, 219, 220 und die Funde aus dem Rest des Layout-Durchgangs | erst nach dem Durchgang schneiden; über 8 Kennungen → Paket 37 |

## Stand der Runde (Host, 26.10. 23:05)

**Bestanden ✓:**
- **Vorher:**
  - App-Zustand im Datenordner.
  - In `app.diskarchive.plist` stehen nur noch `AppleLanguages` und die Fensterposition.
  - „Alle vergessen“ hat der Nutzer bewusst gewählt.
- **Große Platte „Daten“ (1,6 Mio. Einträge):**
  - Lauf ab 22:05; Ebenen in der richtigen Reihenfolge.
  - Ab- und wieder anstecken: Sie macht bei Ebene 4 weiter, nicht von vorn.
- **Mehrere Medien gleichzeitig:** SD, Sticks und Karten laufen nebeneinander. Wird eins abgezogen, laufen die anderen weiter.
- **Wiedererkennen über einen Hub:**
  - nach UUID (APFS, FAT mit UUID) und nach Fingerabdruck (FAT ohne UUID);
  - zwei verschiedene Karten mit gleichem Namen werden richtig als zwei Medien erkannt.
- **Umbenennen eines Volumes mitten im Lauf:** sofort erkannt, kein Dialog, der Lauf setzt unter dem neuen Pfad fort.
- **Live-Änderung:** Datei und Ordner anlegen, umbenennen und löschen. Ein geöffneter Ordner bleibt beim Umbenennen offen.
- **Suche** (Name, Endung `cr3`, `nef`) und **Filter**.
- **Spaltenansicht:** Scrollen, Mehrfachauswahl, Rechtsklick.
- **Mitteilungen:** „Medium mit Favoriten angeschlossen“; „vollständig indiziert“ (STICK, 23:01:51, im Mitteilungszentrum gestapelt).
- **Favorit überlebt Verschieben und Abziehen** (Gegenprobe `bug.0.4.141`).
- **„Ersetzt dieses Medium?“:** Altes vergessen, das neue indiziert. Die Reihenfolge ist falsch (`bug.0.4.215`).
- **Große Platte fertig:** 23:14:01, ohne Lesefehler, Mitteilung „vollständig indiziert“ gekommen; etwa 71 Minuten ab 22:03 einschließlich Abziehen und paralleler Läufe (Debug-Fassung).
- **Gestapelte Erkennungsdialoge: nicht bestanden** (`bug.0.4.216`).
- **SSD mit unlesbarem Ordner (`bug.0.4.199`): gilt als bestanden, ohne Handtest** (Nutzer 26.10. 23:20). **Auflage:** Der Host prüft genau diese Funktion noch einmal **gezielt und isoliert im Code**, bevor 0.4.0 Release-Kandidat wird.
  - Prüfen: Ein nicht lesbarer Ordner (keine Rechte) führt nach „Neu indizieren“ zu:
    - Status „Fehler“ mit Grund „Einige Ordner … nicht gelesen“;
    - Details „Indiziert 99 %“;
    - der alte Inhalt des Ordners bleibt (Invariante 1).
  - Nach dem Wiederherstellen der Rechte und Anstecken: „Online“ und 100 %.
  - Ausgeschlossene Systemordner zählen nicht.
  - Dazu Tests und Sabotage-Patches von `bug.0.4.199` lesen (`archiv/paket-26-abgenommen-2026-10-25.md`, `archiv/sabotage/paket-26/`).
  - **Erledigt (Supervisor 27.10.):**
    - Code-Trace vollständig.
    - Ein echter Lesefehler auf dem Mac des Nutzers ist belegt (open errno 13, FileManager 257, kein leeres Lesen).
    - `pruefung.sh schnell` 00:15–00:17: 0 Warnungen, 36 Tests in 4 Suites grün.
    - Nutzer: 199 gilt als geprüft. Der Host-Schritt in Paket 34 entfällt.

**Offen:**
- Layout-Durchgang hell und dunkel: Bis 23:35 sind Dashboard und Spaltenansicht gesehen. Es fehlen Suche, Favoriten, Einstellungen, Medium-Details, Dialoge und Menüleiste.


## bug.0.4.209 — Dialoge der App nehmen den Tastaturfokus (Stufe 1)

- **Nutzer sieht:** Er steckt eine SD-Karte ein und tippt in einer anderen App weiter. Seine Tasten landen im Erkennungsdialog, der Fokus ist weg („das ist scheiße“). Ein Return oder Leerschritt löst den Standardknopf aus, meist „Indizieren“.
- **Wann:** jedes Mal, wenn ein Medium angeschlossen wird, während der Nutzer schreibt. Der Nutzer erlebte es am 26.10. um 22:10 und schrieb „dauernd der Fokus weg“.
- **Ursache im Code:** `AppWindowPresenter` macht seine Panels mit `makeKey()` zum Tastatur-Fenster, obwohl sie `.nonactivatingPanel` sind:
  - `syncNewMediumPanels` (Z. ~185–189); das läuft beim Erscheinen eines Mediums, nach jeder Entscheidung und beim Aushängen;
  - `show(_:placement:)` (Z. ~340–345), gilt für „Ersetzt dieses Medium?“ und Ignorieren bestätigen;
  - Z. ~351–352 und ~381–382.
- **Entscheidung (Nutzer 26.10.):** Beim Erscheinen springt der Dialog einmal nach vorn und nimmt den Fokus. Danach fordert er ihn nie wieder an. Klickt der Nutzer in ein anderes Fenster, verschwindet der Dialog dahinter; er bleibt offen und schwebt nicht. Konzept: `konzept/medien.md`, Punkt 3.
- **Heute falsch im Code:**
  - Jeder Aufruf von `syncNewMediumPanels` holt das vorderste Panel erneut mit `orderFrontRegardless()` und `makeKey()`, auch wenn es schon offen ist, z. B. beim zweiten Medium, nach einer Entscheidung oder beim Aushängen eines anderen.
  - `panel.level = .floating` und `isFloatingPanel = true` halten die Panels über allen Fenstern.
- **Tests (Vorschlag):**
  - Das Panel ist beim ersten Erscheinen Key.
  - Ein zweites `syncNewMediumPanels`, ohne dass ein neues Panel entsteht, macht es nicht erneut Key und holt es nicht nach vorn.
  - `level == .normal`.
  - Gegenprobe: Ein neues Medium bekommt beim Erscheinen wieder den Fokus.

## bug.0.4.210 — Fortschritt: 100 % beim Abbruch, 0 % beim Fortsetzen, 34/33 %, 99 % bei „Neu indizieren“ (Stufe 1)

- **Nutzer sieht:**
  - Er wirft den Stick „NO NAME“ mitten im Lauf aus. Die Anzeige springt kurz auf **100 %** und fällt dann auf **33 %**.
  - Vorher stand online **34 %** da, nach dem Wiederanstecken wieder 34 %.
- **Wann:** bei jedem Abbruch eines Laufs, ob durch Auswerfen, Abziehen oder (vermutlich) Pause. Der Nutzer sah es am 26.10. um 22:25.
- **Ursache im Code:**
  - `IndexProgressDisplay.note` (`AppState+Media.swift` Z. ~418–432) setzt bei **jedem** Wechsel weg von `.indexing` `real = 1` und hält 0,3 s bei 100 % (`holdAtFull`), auch wenn der Lauf nicht fertig ist.
  - Die Regel „mindestens 1 Sekunde sichtbar, 0 → 100 %“ (Konzept `indizieren.md`, Nutzer 08.10.) gilt nur für einen Lauf, der **fertig** wird.
  - Der Unterschied 34 % zu 33 % entsteht, weil die Anzeige im Lauf (`run.real`, Höchstwert) und offline (gespeicherte Einträge ÷ `scanTotal`, hier 15.323 ÷ 45.920 = 33,4 %) verschieden rechnet. Das Konzept verlangt **eine** Definition für jede Anzeige.
- **Dazu (Nutzer 26.10. 22:27):** Nach dem Wiederanstecken stand zuerst 34 %, dann sprang die Anzeige auf **0 %**. Der Lauf ab 22:26:37 zählt erneut, und die Anzeige zeigt dabei 0 %, obwohl `scanTotal` = 45.920 gespeichert ist. Laut Konzept (`indizieren.md`, Fortschritt) dient die gespeicherte Gesamtzahl als Schätzung, „sodass sofort Prozent erscheinen; die Zählphase korrigiert sie“. Das gilt auch für die Fortsetzung eines unvollständigen Laufs.
- **Dazu (d), „Neu indizieren“ steht sofort auf 99 % (Nutzer 26.10. 22:29):**
  - „Neu indizieren“ für „EOS_DIGITAL“ (22:29:16–22:29:22, `scratch=true`) zeigte die ganze Zeit 99 %.
  - Ursache: `DirectoryIndexer.run` (Z. ~83–84) beginnt mit `entriesCompleted = stored.fileCount + stored.folderCount` und `scanTotal = stored.scanTotal`, auch bei `fromScratch`. Der alte Bestand zählt als geschafft, `min(0.99, …)` greift sofort.
  - Bei der großen Platte (1,6 Mio.) stünde die Anzeige den ganzen Lauf über bei 99 %.
- **Dazu (e), Umbenennen mitten im Lauf (Nutzer 26.10. 22:38):** Erkennung, Abbruch und Neustart bei Ebene 4 sind richtig. Die Anzeige sprang danach aber auf **34 %**, obwohl 19.617 von 45.920 = **42 %** gespeichert waren (Ebene 3 fertig um 22:38:00). Nach einem Neustart zeigt sie also einen alten Wert statt gespeichert ÷ Gesamtzahl.
- **Gemeinsame Ursache von (b) und (d), doppelt gezählt (Nutzer 26.10. 22:33, „über 40 %“, „jetzt 43 % auf einmal“):**
  - Der Stick hat in Ebene 2 einen Ordner mit sehr vielen Dateien. Vor dem Abziehen waren 14.611 davon gespeichert, `listedAt` des Ordners war noch leer.
  - Das Fortsetzen liest den Ordner von vorn. `entriesCompleted` beginnt beim gespeicherten Bestand (15.323) und addiert jeden gelesenen Eintrag, auch die schon gespeicherten.
  - Die Anzeige zeigt 39–43 %, die Datenbank hat weiter 15.323 ÷ 45.920 = 33 %. Beim Abziehen fällt die Anzeige auf den gespeicherten Wert zurück.
  - Folge: Die Anzeige kann 99 % erreichen, lange bevor der Lauf fertig ist.
- **Fix-Richtung:**
  - Zähler = Einträge, die wirklich in der Datenbank stehen. Neue Einträge kommen dazu, schon vorhandene, die nur erneut gelesen werden, nicht.
  - Bei „Neu indizieren“ zählt nur, was dieser Lauf geschrieben hat. Die gespeicherte Gesamtzahl bleibt der Nenner.
  - Ist eine Gesamtzahl gespeichert, zeigt auch die Zählphase gespeicherte Einträge ÷ gespeicherte Gesamtzahl, nie 0 %.
  - 100 % nur bei einem Lauf, der mit „indiziert“ endet. Bei Abbruch oder Pause bleibt der letzte Wert stehen.
  - Online und offline zeigen denselben Wert, nämlich gespeicherte Einträge ÷ Gesamtzahl, abgerundet.
- **Tests (Vorschlag):**
  - `note` mit `.indexing` 0,34, danach `.offline` → nie 1.
  - Gegenprobe: ein Lauf, der mit `.indexed` endet, zeigt 1.
  - Gleicher Wert für dasselbe Medium online und offline.
  - Anstecken mit gespeichertem `scanTotal` und unvollständigem Index: In der Zählphase zeigt die Anzeige den gespeicherten Wert, nicht 0.
  - „Neu indizieren“ eines vollständig indizierten Mediums: Der erste gemeldete Fortschritt liegt unter 0,5, nicht bei 0,99.

## bug.0.4.211 — Dashboard-Kacheln kleben aneinander, verschieden breit (Stufe 1)

- **Nutzer sieht:** „krasser Layoutbug, die Elemente kleben alle“ (Screenshot 26.10. ~22:28, Fenster 1134 pt, 5 Kacheln in einer Reihe). Je zwei Kacheln stoßen aneinander, dazwischen größere Lücken. Online-Kacheln (Chip „38 % indiziert“, „Zuletzt indiziert: heute, 22:17“) sind breiter (~218 pt) als offline-Kacheln (~204 pt).
- **Wann:** immer, wenn das Raster eine Zellbreite unter der Inhaltsbreite der Kachel ergibt. Bei 1134 pt Fensterbreite sind das 5 Spalten zu 205 pt.
- **Ursache im Code:**
  - `DashboardGridLayout.minCardWidth = 200` liegt unter der Mindestbreite aus `docs/Komponenten-Masse.md` („Kachel: Breite 240, Mindestbreite 220“).
  - `MediumDashboardCard` hat Zeilen mit `fixedSize(horizontal: true…)` (Chip, Zeitzeile). Die Kachel wird breiter als die vorgeschlagene Zellbreite.
  - `DashboardEqualHeightRowLayout.placeSubviews` rückt trotzdem um `cardWidth + spacing` weiter. Die Kachel ragt in den Abstand.
- **Fix-Richtung:**
  - Mindestbreite nach Katalog.
  - Jede Kachel genau so breit wie ihre Zelle, gleich für alle Zustände: Online, Offline, „x % indiziert“, „Fehler“, lange Namen.
  - Text, der nicht passt, wird gekürzt (…), nie breiter.
  - Abstand immer 16 pt.
- **Tests (Vorschlag):** Fenstertest außerhalb des Bildschirms mit Breiten 900, 1134, 1400 und gemischten Zuständen. Alle Kacheln einer Reihe sind gleich breit, der Abstand ist 16 pt ±0,5, keine Überlappung (Pixel oder Frames).
- **Geklärt:** „Transfer“ fehlte nur, weil der Screenshot älter war (Nutzer 26.10.). Die zweite Reihe erscheint.

## bug.0.4.212 — Bei offenem Filter lässt sich nicht scrollen (Stufe 1)

- **Nutzer sieht:** Er öffnet den Filter (Trichter) und kann in der aktiven Spalte nicht mehr scrollen; dasselbe gilt für alles andere im Fenster.
- **Wann:** immer, solange der Filter offen ist (Nutzer 26.10. ~22:45).
- **Ursache im Code:** `MainWindowScreenScaffold.filterPopover` legt eine fensterfüllende, fast durchsichtige Fläche (`Color.black.opacity(0.001)`, `contentShape`, `onTapGesture`) über alles, damit ein Klick daneben den Filter schließt. Die Fläche schluckt auch das Scrollen.
- **Vorschlag (Host, Nutzer kann widersprechen):**
  - Scrollen geht unter dem offenen Filter durch, sodass man die Ergebnisse beim Filtern ansehen kann.
  - Ein Klick daneben schließt den Filter wie bisher.
  - Escape schließt ihn.
  - Statt der Fläche z. B. ein Ereignis-Monitor für Mausklicks außerhalb des Panels oder ein natives, vorübergehendes Popover.
- **Tests (Vorschlag):** Fenstertest außerhalb des Bildschirms mit offenem Filter und `scrollWheel` über der Spalte → die Spalte scrollt (Pixel oder Scroll-Position). Gegenprobe: Ein Klick daneben schließt den Filter.

## bug.0.4.213 — ← und → in der Spaltenansicht ohne Wirkung (Stufe 1)

- **Nutzer sieht:** ↑ und ↓ bewegen die Auswahl. → öffnet den gewählten Ordner aber nicht als nächste Spalte, und ← führt nicht aus dem Ordner zurück in die Spalte davor (Nutzer 26.10. ~22:50, große Platte).
- **Wann:** immer bei der Bedienung mit der Tastatur.
- **Maßstab:** `konzept/suche-navigation.md`:
  - „Navigation wie im Finder“ (Z. 12).
  - „Öffnet eine Nutzeraktion (… Ordner öffnen, Pfeiltaste) … eine neue Spalte außerhalb der Sicht, springt die Ansicht … nach rechts“ (Z. 28).
- **Code:** Keine Behandlung von ← und → unter `Views/` gefunden.
- **Verhalten wie im Finder:**
  - → auf einem Ordner öffnet ihn und wählt den ersten Eintrag der neuen Spalte; auf einer Datei tut es nichts.
  - ← wählt in der Spalte davor wieder den Elternordner und schließt die Spalten rechts davon.
  - Der Pfad (`pathStack`) und die Fußzeile folgen.
  - Bei Mehrfachauswahl tut → nichts (dort bleiben die Spalten rechts zu, Konzept Z. 14).
- **Tests (Vorschlag):** Fenstertest mit `sendEvent`: →, dann ←, dann → auf einer Datei. Geprüft werden `pathStack`, Auswahl und Fokus-Spalte. Gegenprobe: ↓ bewegt die Auswahl weiter.

## bug.0.4.214 — Ansicht springt mit, wenn eine ausgewählte Datei von außen verschoben wird (Stufe 1)

- **Nutzer sieht:** In einem Ordner mit 251 Dateien ist eine Datei ausgewählt. Er verschiebt sie im Finder in einen anderen Ordner. Disk Archive springt mit: Die Ansicht wechselt in den neuen Ordner, und die Datei bleibt dort ausgewählt. Das ist nicht erwünscht (Nutzer 26.10. ~22:58, EOS_DIGITAL).
- **Wann:** jedes Mal, wenn eine ausgewählte Datei oder ein ausgewählter Ordner außerhalb der App verschoben wird.
- **Entscheidung (Nutzer 26.10.):** Das verschobene Objekt verliert die Auswahl, die Ansicht bleibt im alten Ordner. Konzept: `konzept/suche-navigation.md`, „Live-Änderung an der Auswahl“.
- **Vermutete Ursache (Worker prüfen):** Die Auswahl hängt an der Item-ID. Ein Verschieben behält die ID (Datei-ID, `fileID`), deshalb folgt der Pfad (`pathStack`) dem Objekt an den neuen Ort.
- **Tests (Vorschlag):** Ordner A mit ausgewählter Datei, Live-Verschieben nach B über die Überwachungskette (ohne Nachhilfe, Regel 10). Danach ist A weiter offen, nichts ausgewählt, keine Detailspalte, `pathStack` endet bei A. Gegenprobe: Umbenennen am selben Ort behält die Auswahl.

## bug.0.4.215 — „Ersetzt dieses Medium?“ kommt erst nach dem Erkennungsdialog (Stufe 1)

- **Nutzer sieht:**
  - Er formatiert den Stick „STICK“ neu, mit gleichem Namen. Zuerst kommt „Neues Speichermedium erkannt“. Erst nach „Indizieren“ kommt „Ersetzt dieses Medium „STICK“?“.
  - Er beantwortet also zwei Fragen zu einem Medium, und die erste ist überflüssig, wenn er das alte ersetzt (Nutzer 26.10. 23:05).
- **Wann:** jedes Mal, wenn ein neues Medium den Namen eines Offline-Mediums trägt.
- **Ablauf heute (Protokoll):**
  - 23:05:09 Erkennungsdialog;
  - 23:05:20 „Indizieren“, danach `replace prompt`;
  - 23:05:53 `forgetOld=true`.

  Funktional richtig: Das alte Medium wurde vergessen, das neue indiziert.
- **Entscheidung (Nutzer 26.10., A):** Konzept `konzept/medien.md`, Punkt 3, „Neu formatiert“.
  - Zuerst kommt nur „Ersetzt dieses Medium?“.
  - „Altes vergessen“: Das neue Medium übernimmt die Entscheidung des alten. War sie gemerkt, kommt kein Erkennungsdialog, sonst folgt er.
  - „Behalten“: Der Erkennungsdialog folgt.
- **Tests (Vorschlag):**
  - Offline-Medium „X“, gemerkt „Indizieren“. Ein neues Medium „X“ erscheint: Zuerst kommt nur das Ersetzen-Panel, kein Erkennungspanel. „Altes vergessen“ → das alte ist weg, das neue hat `decision == .index` und läuft, ohne Erkennungspanel.
  - „Behalten“ → danach das Erkennungspanel.
  - Gegenprobe: Ein neues Medium ohne gleichnamiges Offline-Medium bekommt sofort das Erkennungspanel.

## bug.0.4.216 — Erkennungsdialoge liegen übereinander statt gestapelt (Stufe 1)

- **Nutzer sieht:** Er steckt Stick und SD-Karte kurz nacheinander über einen Hub ein (23:12:41 und 23:12:42). Er sieht nur **einen** Dialog, der zweite erscheint erst nach der Antwort. Vorgabe ist ein Stapel, der ältere nach links oben versetzt (Layout 02, `todo.0.4.048`). Nutzer: „nicht bestanden, sollten gestapelt sein, das ist die Vorgabe“.
- **Wann:** immer, wenn ein weiteres Medium erscheint, während ein Erkennungsdialog offen ist.
- **Ursache im Code:**
  - `AppWindowPresenter.openOrUpdateNewMediumPanel` (Z. ~395–413) berechnet die Lage (`placeNewMediumPanel`, `depthFromNewest`) nur beim **Anlegen** eines Panels.
  - Ein schon offenes Panel wird nicht verschoben, wenn ein neueres dazukommt. Beide haben `depthFromNewest = 0` und liegen genau übereinander.
  - Gestapelt wird nur, wenn mehrere Medien im selben `syncNewMediumPanels`-Aufruf ankommen.
- **Fix-Richtung:**
  - Bei jedem `syncNewMediumPanels` alle offenen Panels nach ihrer Lage im Stapel neu setzen: das neueste vorn und mittig, ältere nach links oben versetzt.
  - Wird der vorderste beantwortet, rücken die übrigen nach.
  - Beim Neusetzen den Fokus nicht neu anfordern (`bug.0.4.209`): Nur ein **neu erscheinendes** Panel nimmt ihn einmal.
- **Tests (Vorschlag):**
  - Zwei Medien in **getrennten** Aufrufen nacheinander melden. Danach haben die beiden Panels verschiedene Ursprünge, das ältere nach links oben versetzt (Maß aus Layout 02).
  - Den vorderen beantworten → der übrige rückt in die vordere Lage.
  - Gegenprobe: zwei Medien im selben Aufruf (heute schon richtig).

## bug.0.4.217 — Spinner in der Medienspalte zu groß (Stufe 1, Layout)

- **Nutzer sieht:** In der Spaltenansicht ist der Spinner neben einem Medium, das gerade indiziert wird, größer als im Layout (Nutzer 26.10. ~23:25, Layout-Durchgang).
- **Wann:** bei jedem laufenden Lauf.
- **Maßstab:** Layout `Disk Index App.dc.html`, Spaltenansicht, Zeile „Studio Backup“: Spinner **12 × 12 px, Strich 2 px**, grün `oklch(0.62 0.16 150)` (hell); Layout 15 nennt dazu „Status-Badges … alle gleich groß: Wird indiziert = grüner Spinner-Ring“.
- **Code:** `ColumnBrowserRow.swift` (Z. ~33–37): `IndexingSpinnerRing(lineWidth: 1.5).frame(width: 14, height: 14)` in einer 16er-Box, Farbe `iconColor`.
- **Fix:** 12 × 12 pt, Strich 2 pt, mittig in der 16er-Icon-Box, damit die Zeile nicht springt. Farbe: **schwarz bzw. weiß je nach Erscheinungsbild** (Text-/Icon-Farbe, wie heute; Nutzer 26.10.: nicht grün wie im Layout). Nur die Größe ändert sich.
- **Test:** Messtest ±0,5 pt (Regel 7), hell und dunkel.

## bug.0.4.218 — Spaltenbreite ziehen: ruckelt, beim Loslassen werden alle Spalten so breit (Stufe 1)

- **Nutzer sieht** (26.10. ~23:30):
  1. Beim Ziehen am Rand einer Ordnerspalte ruckelt es.
  2. Beim Loslassen bekommen **alle** Ordnerspalten die neue Breite.
  3. Gewünscht ist, dass sich nur die gezogene Spalte ändert.
- **Wann:** bei jedem Ziehen einer Spaltenbreite.
- **Code:**
  - `ColumnBrowserState.folderColumnWidth` ist **eine** Breite für alle Ordnerspalten (alte Vorgabe, README-Verlauf bis 02.10.: „global für alle Ordner-Spalten“).
  - `ColumnResizeHandle.onEnded` schreibt sie, während des Ziehens gilt nur `columnResizePreview` für die eine Spalte.
  - Ruckeln wurde schon in Runde 5/6 gemeldet (`archiv/prompt-verlauf-bis-2026-09-28.md` Z. ~503, ~535) und offenbar nie ganz behoben.
- **Entscheidung (Nutzer 26.10., ersetzt die alte Vorgabe):** Jede Ordnerspalte hat ihre eigene Breite. Nur die gezogene ändert sich, beim Ziehen und danach. Konzept: `konzept/suche-navigation.md`, „Spaltenbreite“.
- **Offen für den Worker („Frage:“, falls unklar):** Was gilt für eine **neu** geöffnete Spalte? Vorschlag Host: die Standardbreite (230 pt), nicht die zuletzt gezogene. Die Breite gilt je Spaltenposition und wird nicht gespeichert.
- **Ruckeln:** Beim Ziehen ändert sich nur der Frame der einen Spalte. Kein Neuaufbau der anderen Spalten und kein Scroll-Auftrag; die Ursache im Status benennen.
- **Tests (Vorschlag):** Fenstertest mit drei Ordnerspalten: Die mittlere ziehen (`sendEvent`) → nur sie ist breiter, die anderen bleiben (Frames ±0,5). Gegenprobe: die erste Spalte ziehen.

## bug.0.4.219 — Drei Grautöne für Seitenleiste, Offline-Leiste und Detailspalte (Stufe 1, Layout)

- **Nutzer sieht:** Die Hintergründe der Detailspalte und der Leiste „Offline — Inhalt aus dem Index …“ passen nicht zusammen (Screenshot 26.10. ~23:30).
- **Wann:** immer, wenn ein Medium offline ist und Details offen sind; die Seitenleiste immer.
- **Code** (`ColumnBrowserView.swift`):
  - Medien-Seitenleiste `text.opacity(0.06)` (Z. ~300);
  - Offline-Leiste `text.opacity(0.05)` (Z. ~340);
  - Detailspalte `text.opacity(0.04)` (Z. ~909).

  Also drei verschiedene Grautöne, nicht aus dem Komponentenkatalog.
- **Fix-Richtung:** Eine Farbrolle für diese Flächen aus dem Katalog bzw. Layout, z. B. `DesignColor.toolbar` (6 %) oder `surface`. Der Worker nimmt sie aus `docs/Komponenten-Masse.md` bzw. Layout 07. Fehlt sie dort: „Frage:“, und der Host klärt sie mit dem Nutzer. Hell und dunkel.
- **Test:** Pixeltest (`PixelProbe`): Detailspalte und Offline-Leiste haben denselben Farbwert, hell und dunkel.

## bug.0.4.220 — Pfad in der Fußzeile nicht bündig mit dem Icon der Ordnerspalte (Stufe 1, Layout)

- **Nutzer sieht:** Der Pfad „Transfer › raws › 2016-08_001.NEF“ in der Fußzeile beginnt nicht genau am linken Rand des Ordner-Icons der ersten Ordnerspalte darüber. Vorgabe: „zu 100 % aligned mit dem Icon“ (Nutzer 26.10. ~23:35, Screenshot).
- **Wann:** immer; stärker, sobald die Medienliste (Seitenleiste) breiter oder schmaler gezogen ist.
- **Ursache im Code** (`ColumnBrowserPathFooter.swift`):
  - Der linke Teil (Objektzahl) hat die **feste** Breite `DesignSpacing.columnBrowserSidebarWidth` (Z. ~18). Die Seitenleiste ist aber ziehbar (`columnBrowserState.sidebarWidth`, Konzept Z. 9).
  - Der Pfad hat `padding(.horizontal, 8)` (Z. ~25). Das Icon der Ordnerzeile sitzt bei Spalteneinzug + `ColumnBrowserRow` `padding(.horizontal, 10)`.
- **Fix:**
  - Der Pfad beginnt genau bei x = linke Kante des Icons in der ersten Ordnerspalte: aktuelle Seitenleistenbreite + Spalteneinzug + Zeileneinzug.
  - Aus denselben Konstanten berechnet, nicht als zweite Zahl.
  - Folgt dem Ziehen der Seitenleiste.
- **Test:** Fenstertest: Die linke Kante des ersten Pfadzeichens (Glyph-Rahmen bzw. Pixel) ist gleich der linken Kante des Icons der ersten Ordnerspalte, ±0,5 pt. Bei Standardbreite und nach dem Ziehen der Seitenleiste um +60 pt.
