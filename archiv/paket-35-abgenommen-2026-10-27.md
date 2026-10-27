# Paket 35 — Zielversion 0.4.0 (freigegeben 27.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Befunde in drei Stufen, Regel 12; Invarianten in `konzept/architektur.md`). Funde der Abnahmerunde, ausführlich: [todo/funde-abnahmerunde-0.4.0.md](funde-abnahmerunde-0.4.0.md). Paketschnitt: Supervisor 27.10. (Paket 36: Layout 211, 217–220 und Rest des Layout-Durchgangs).

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen und den drei Stufen (Regel 12). Beheben musst du nur Stufe 1.
- Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `bug.0.4.215`, `bug.0.4.212`, `bug.0.4.213`, `bug.0.4.214`. **HALT.**

## Funde aus der Abnahmerunde des Nutzers (26.10., Supervisor 27.10. bestätigt)

- **bug.0.4.215 — „Ersetzt dieses Medium?“ zuerst und allein.**
  - **Nutzer sieht:** Er formatiert einen Stick mit gleichem Namen neu. Zuerst kommt „Neues Speichermedium erkannt“, erst nach „Indizieren“ die Frage „Ersetzt dieses Medium?“. Zwei Fragen zu einem Medium, die erste ist überflüssig. **Wann:** jedes Mal, wenn ein neues Medium den Namen genau eines Offline-Mediums trägt. **Stufe 1.**
  - **Maßstab:** `konzept/medien.md` Punkt 3, „Neu formatiert“ und „Reihenfolge (bug.0.4.215)“:
    - Gibt es genau ein Offline-Medium gleichen Namens (nicht vergessen), kommt **zuerst nur** „Ersetzt dieses Medium?“. Kein Erkennungspanel, solange diese Frage offen ist.
    - **„Altes vergessen“:** Das neue Medium übernimmt die Entscheidung des alten (Indizieren/Nicht indizieren und „Für dieses Medium merken“). War sie gemerkt: kein Erkennungsdialog, bei „Indizieren“ startet der Lauf. War sie nicht gemerkt: der Erkennungsdialog folgt. Danach wird das alte über den bestehenden Vergessen-Weg (`forgetMedium`) vergessen.
    - **„Behalten“:** Der normale Erkennungsdialog folgt.
    - Mehrere Offline-Medien gleichen Namens: keine Rückfrage, sofort Erkennungsdialog (wie heute).
  - **Heute:** `MediumCoordinator` (Z. ~546–550) ruft `appState.offerReplaceMediumPrompt` erst **nach** der Antwort im Erkennungsdialog. `AppState+Media.swift` Z. ~183–206 (`offerReplaceMediumPrompt`, `resolveReplaceMediumPrompt`).
  - **Umbau:** Die Rückfrage gehört an die Stelle, an der ein neues Medium in die Erkennungs-Warteschlange käme (`enqueueNewMediumDecision`). Das Erkennungspanel wartet, bis die Rückfrage beantwortet ist. Der Fokus folgt `konzept/medien.md` („Fokus einmal beim Erscheinen“, Paket 34): Die Rückfrage holt sich den Fokus einmal; das danach erscheinende Erkennungspanel ebenfalls einmal.
  - **Nicht anfassen:** Lebenszyklus in `IndexingService` (`konzept/lauf-lebenszyklus.md`), Stapel und Fokus aus Paket 34.
  - **Tests** (echter Weg über `MediumCoordinator`, Panels außerhalb des Bildschirms, Regel 10):
    1. Offline-Medium „X“, Entscheidung „Indizieren“ gemerkt. Neues Medium „X“ erscheint → nur das Ersetzen-Panel, kein Erkennungspanel. „Altes vergessen“ → altes weg, neues hat `decision == .index`, Lauf angefordert, kein Erkennungspanel.
    2. Wie 1, aber nicht gemerkt → nach „Altes vergessen“ das Erkennungspanel.
    3. „Behalten“ → danach das Erkennungspanel, das alte bleibt.
    4. Gegenprobe: neues Medium ohne gleichnamiges Offline-Medium → sofort das Erkennungspanel.
    5. Gegenprobe: zwei Offline-Medien „X“ → keine Rückfrage.
  - **Sabotage:** 215-a Rückfrage wieder nach der Antwort (Test 1 rot); 215-b Entscheidung nicht übernommen (Test 1 rot); 215-c „Behalten“ ohne Erkennungspanel (Test 3 rot).
  - **Status:** Bereit zur Prüfung. `MediumCoordinator.requestDialog`: ein unentschiedenes Medium mit genau einem Offline-Medium gleichen Namens bekommt zuerst und allein die Rückfrage (alle Wege in die Warteschlange); der Aufruf nach der Antwort in `applyChoice` ist weg. `resolveReplace` (über `AppState.onReplaceMediumResolved`): „Behalten“ → Erkennungsdialog; „Altes vergessen“ → Entscheidung, `allowIndexing` und „merken“ des alten übernommen, dann `forgetMedium`; gemerkt → kein Dialog, bei „Indizieren“ Lauf; nicht gemerkt → Dialog (Lauf bei „Indizieren“ wie beim erneuten Fragen). Selbstprüfung (Stufe 2, behoben, Patch 215-d): umgesteckt oder Menüleistenzeile bei offener Rückfrage öffnete den Erkennungsdialog daneben – jetzt bleibt es bei der Rückfrage, die Zeile holt sie vor (`revealReplaceMediumPrompt`).
    Tests `ReplaceFirstTests` (Fälle 1–5 + Umstecken, echter Coordinator, Panels außerhalb). Rot vor dem Fix nur über Patch 215-a (= alte Reihenfolge, 07:30; Tests nach dem Code geschrieben). `MediumIdentityTests` (2 Tests der alten Reihenfolge) angepasst. Sabotage a–d rot (07:30–07:38).
    Offen (Stufe 2 laut Selbstprüfung, nicht behoben): beim App-Start mit zwei gleichnamigen Medien (eines neu) könnte das bekannte noch als offline zählen, wenn das neue zuerst verarbeitet wird → Rückfrage zu einem angeschlossenen Medium. Nicht beobachtet.

- **bug.0.4.212 — Bei offenem Filter scrollen.**
  - **Nutzer sieht:** Er öffnet den Filter (Trichter) und kann in der aktiven Spalte und überall sonst im Fenster nicht mehr scrollen. **Wann:** immer, solange der Filter offen ist. **Stufe 1.**
  - **Ursache:** `MainWindowScreenScaffold.filterPopover` (Z. ~53–70) legt eine fensterfüllende Fläche (`Color.black.opacity(0.001)`, `contentShape`, `onTapGesture`) über alles; sie schluckt auch das Scrollen.
  - **Soll (Host-Vorschlag, Nutzer hat nicht widersprochen):** Scrollen geht unter dem offenen Filter durch. Ein Klick daneben schließt den Filter wie bisher, Escape ebenso. Der Klick daneben wird **nicht** an das Ziel weitergereicht (wie heute: er schließt nur). Umsetzung frei, z. B. lokaler `NSEvent`-Monitor für Mausklicks außerhalb des Panels statt der Fläche; kein natives `NSPopover`, das Aussehen des Panels bleibt.
  - **Tests:** Fenstertest außerhalb des Bildschirms mit offenem Filter: `scrollWheel` über der Spalte → die Spalte scrollt (Scroll-Position ändert sich). Gegenproben: Klick daneben schließt den Filter, ohne dort etwas auszuwählen; Klick ins Panel schließt nicht; Escape schließt.
  - **Sabotage:** 212-a Fläche wieder einsetzen (Scroll-Test rot); 212-b Klick daneben schließt nicht (Gegenprobe rot).
  - **Status:** Bereit zur Prüfung. Fensterfüllende Fläche entfernt; neu `onClickOutside` (`DesignSystem/OutsideClickMonitor.swift`): lokaler Monitor für Mausklicks im selben Fenster außerhalb des Panels → schließt und verschluckt den Klick; Klick ins Panel und in andere Fenster gehen durch, Escape wie bisher. Offen-Zustand jetzt `AppState.isFilterPopoverShown` (testbar). Aussehen unverändert.
    Tests `FilterPopoverScrollTests` (Hauptfenster-Rahmen + Spaltenansicht, `NSApp.sendEvent`): Klick ins Panel schließt nicht, Klick daneben schließt ohne Auswahl, Escape schließt, Gegenprobe Klick wählt ohne Filter. **Abweichung:** ein synthetisches Mausrad bewegt SwiftUIs `HostingScrollView` außerhalb des Bildschirms auch ohne Filter nicht; geprüft wird deshalb der Zustellweg (Hit-Test unter dem Zeiger landet in der Scrollansicht der Spalte, Gegenprobe ohne Filter) – genau den unterbrach die Fläche.
    Rot vor dem Fix über Patch 212-a (= alte Fläche, 07:30). Sabotage a, b rot (07:30–07:31).

- **bug.0.4.213 — ← und → in der Spaltenansicht.**
  - **Nutzer sieht:** ↑ und ↓ bewegen die Auswahl, → öffnet den gewählten Ordner nicht, ← führt nicht zurück. **Wann:** immer bei Bedienung mit der Tastatur. **Stufe 1.**
  - **Maßstab:** `konzept/suche-navigation.md` „Navigation wie im Finder“ und Z. ~28 (neue Spalte außerhalb der Sicht → Ansicht springt nach rechts).
  - **Heute:** `ColumnBrowserView.swift` Z. ~684 (`onKeyPress`) und ~792 behandeln nur ↑/↓ (`AppState.moveColumnSelection`, `AppState+ColumnSelection.swift` Z. ~75).
  - **Soll (wie im Finder):**
    - → auf einem einzeln gewählten Ordner: öffnet ihn als nächste Spalte, wählt deren ersten sichtbaren Eintrag, die Fokus-Spalte wird die neue. Auf einer Datei, bei leerem Ordner (öffnen, keine Auswahl darin) oder bei Mehrfachauswahl: nichts weiter (bei Mehrfachauswahl bleibt rechts zu, Konzept Z. ~14).
    - ←: wählt in der Spalte davor den Elternordner, schließt die Spalten rechts davon; Fokus-Spalte = die davor. In der ersten Spalte: nichts.
    - `pathStack`, Fußzeile und Detailspalte folgen; die Ansicht scrollt die neue Spalte in Sicht.
    - Shift+←/→ und ⌘ mit Pfeil: nichts Neues (ignoriert).
  - **Tests:** Fenstertest mit echtem Tastenereignis (`sendEvent` oder der Weg, den ↑/↓-Tests heute nutzen): → auf Ordner, dann ←, dann → auf Datei; geprüft werden `pathStack`, Auswahl, Fokus-Spalte. Gegenproben: ↓ bewegt die Auswahl weiter; → bei Mehrfachauswahl ändert nichts.
  - **Sabotage:** 213-a → ignoriert (rot); 213-b ← schließt die rechten Spalten nicht (rot).
  - **Status:** Bereit zur Prüfung. `AppState.openColumnSelection` (→: einzeln gewählter, geöffneter Ordner → erster sichtbarer Eintrag der nächsten Spalte; Datei, Mehrfachauswahl, leer: nichts) und `selectColumnParent` (←: Elternordner in der Spalte davor, Spalten rechts von dessen Inhalt zu; erste Spalte: nichts), beide über `commitColumnSelection` (Pfad, Fußzeile, Scroll-Auftrag). `ColumnBrowserView.handleColumnKey` ruft sie auf und setzt die Fokus-Spalte; ⇧/⌘/⌥/⌃ mit Pfeil ignoriert.
    Tests `ColumnArrowNavigationTests` auf dem Weg der ↑/↓-Tests (`AppState`, echter Store): → / ↓ / → / ← / ← / ← in der ersten Spalte; → auf Datei und bei Mehrfachauswahl ändert nichts. Nicht im Test: die Taste in der Ansicht und der SwiftUI-Fokus der neuen Spalte (bitte in der App prüfen).
    Rot vor dem Fix über Patch 213-a (= → ignoriert, 07:30). Sabotage a, b rot (07:30–07:31).

- **bug.0.4.214 — Ausgewähltes Objekt von außen verschoben: Auswahl weg, Ansicht bleibt.**
  - **Nutzer sieht:** In einem Ordner ist eine Datei ausgewählt; er verschiebt sie im Finder in einen anderen Ordner. Disk Archive springt mit in den neuen Ordner, die Datei bleibt ausgewählt. **Wann:** jedes Mal, wenn eine ausgewählte Datei oder ein ausgewählter Ordner außerhalb der App verschoben wird. **Stufe 1.**
  - **Maßstab:** `konzept/suche-navigation.md` „Live-Änderung an der Auswahl“: verschoben, in einen anderen Ordner umbenannt oder gelöscht → Auswahl weg, Ansicht bleibt im bisherigen Ordner, Spalten rechts davon (Detailspalte, offener Unterordner) schließen, Fußzeile zeigt den Ordner. **Umbenennen am selben Ort behält die Auswahl.**
  - **Vermutete Ursache (prüfen):** Die Auswahl hängt an der Item-ID; ein Verschieben behält sie, `pathStack` folgt dem Objekt. Stellen: `ColumnBrowserState`, `ColumnSelection`, `MediumNavigation.swift`, `AppState+ColumnSelection.swift`.
  - **Gilt auch** für einen ausgewählten **Ordner** in der Mitte des Pfads, der von außen verschoben wird: Der Pfad endet beim bisherigen Elternordner, dieser bleibt offen.
  - **Tests** (über die Überwachungskette ohne Nachhilfe, Regel 10): Ordner A mit ausgewählter Datei, Live-Verschieben nach B → A offen, nichts ausgewählt, keine Detailspalte, `pathStack` endet bei A. Dasselbe mit ausgewähltem Unterordner von A, der geöffnet ist. Gegenproben: Umbenennen am selben Ort behält Auswahl und Pfad; Löschen wirkt wie Verschieben.
  - **Sabotage:** 214-a Pfad folgt wieder dem Objekt (rot); 214-b Umbenennen am selben Ort verliert die Auswahl (Gegenprobe rot).
  - **Status:** Bereit zur Prüfung. Ursache: die Auswahl hängt an der stabilen Zeilen-ID; ein Verschieben behält die Zeile, und die neu gelesene Spalte nahm die Auswahl nicht heraus. Neu `AppState.dropVanishedColumnSelection` (nach `followOpenPathAfterReload` in `onColumnReloaded`): fehlen gewählte Objekte in der neu gelesenen Spalte der Auswahl, verlieren sie die Auswahl; Pfad bleibt, Details schließen. Umbenennen am selben Ort behält die Zeile und damit die Auswahl. Verschobener offener Ordner: Pfad endet beim alten Elternordner (bestehender Weg bug.0.4.131).
    Tests `SelectionMovedAwayTests` (echte Dateien, `applyLiveRename`/`applyDirectory` wie die Überwachung, Spaltenansicht offen): Datei verschoben, offener Unterordner verschoben, Umbenennen (Datei, offener Ordner), Löschen. Rot vor dem Fix 07:25 (Datei verschoben, Datei gelöscht; der Ordnerfall war schon grün).
    Sabotage a, b rot (07:30–07:31).
    Belege aller vier: ganzes Testziel parallel grün 07:32–07:37 (1247 Zeilen, rc 0, vor 215-d); neue Suites + `MediumIdentityTests`, `ReplaceMediumDialogWindowTests` 20× parallel grün 07:49–07:55 (1200 Zeilen, 0 rote; ein Lauf davor 07:39 rot mit „SQLite error 14“ – die neuen Tests ließen ihre Datenbanken offen, jetzt `prepareForTermination`), `ColumnOpenFolderGoneTests` 20× grün 07:55–08:00; Debug clean und Release 0 Warnungen; keine neue `.ips`; App des Nutzers 08:02:27 (0.4.0, Signatur ok). Gesamtlauf weggelassen (Last 3–8).

**Paketende:**
- 0 Warnungen in Debug und Release.
- Die betroffenen Suites grün; die neuen Suites 20× parallel grün. Rote Läufe zählen auch, wenn nur das Protokoll sie zeigt.
- Alle Patches unter `todo/sabotage/` rot.
- App des Nutzers gebaut.
- **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele). Sonst weglassen und im Status vermerken, dann macht ihn der Host.

## Abnahme Host 27.10. (Gesamtlauf 09:25–10:12)

`Werkzeuge/pruefung.sh voll` ergab:
- Debug und Release: 0 Warnungen.
- Seriell **1189/1189** grün.
- Parallel 1–3 **grün** (je 1183 bestanden, 6 übersprungen, Exit 0).
- Keine neuen `.ips`; neue Dateien in `~/Library/Preferences`: 0.
- Sabotage **10/10 rot ✓** (212-a/b, 213-a/b, 214-a/b, 215-a–d).
- App des Nutzers 10:12:08, Signatur gültig, Version 0.4.0.

Den Diff hat der Host gelesen:
- **215:** `MediumCoordinator.requestDialog` fragt bei einem unentschiedenen Medium mit genau einem gleichnamigen Offline-Medium zuerst und allein. `resolveReplace` übernimmt bei „Altes vergessen“ Entscheidung, `allowIndexing` und „merken“, dann `forgetMedium`. „Behalten“ führt zum Erkennungsdialog.
- **212:** Die fensterfüllende Fläche ist weg. `onClickOutside` ist ein lokaler Monitor nur im selben Fenster und wird mit dem Panel entfernt.
- **213:** `openColumnSelection` und `selectColumnParent` gehen über `commitColumnSelection`; Pfeiltasten mit Modifikatoren werden ignoriert.
- **214:** `dropVanishedColumnSelection` nimmt nur Objekte aus der Auswahl, die in der neu gelesenen Spalte fehlen; der Pfad bleibt.

Prüf-Agent (Sonnet, Vorlage 2b): kein Befund der Stufe 1. Einen Befund der Stufe 2 sah weder die echte App noch ein Test, er steht im Backlog.

- **Abgenommen:** `bug.0.4.212`, `bug.0.4.213`, `bug.0.4.214`, `bug.0.4.215`.
- **Im Nutzertest nachsehen** (Rest der Abnahmerunde):
  - → und ← in der echten Spaltenansicht. Taste und Fokus der neuen Spalte sind nicht im Test.
  - Scrollen bei offenem Filter. Der Test prüft nur den Hit-Test, weil ein synthetisches Mausrad außerhalb des Bildschirms nicht scrollt.
  - Stick mit gleichem Namen neu formatieren: Zuerst kommt nur „Ersetzt dieses Medium?“.
  - Eine ausgewählte Datei im Finder verschieben.
- **Stufe 2 (Backlog):**
  - App-Start mit zwei gleichnamigen Medien, eines davon neu.
  - „Behalten“, danach den Erkennungsdialog nicht beantwortet: Beim nächsten Anschließen kommt wieder die Rückfrage.
- **Stufe 3 (keine Aufgabe):**
  - Ein Klick in Titelleiste oder Toolbar bei offenem Filter schließt nur den Filter.
  - Bleibt bei einer Mehrfachauswahl nur ein Ordner übrig, wird er nicht geöffnet.
  - Wird bei offener Rückfrage das alte Medium angeschlossen, bleibt die Rückfrage stehen.
