# TODO.md — offene Aufgaben für Cursor

Einzige Aufgabenliste. Erledigtes steht in [DONE.md](DONE.md), Verlauf und alte Spezifikationen in `archiv/`. Rollen: [AGENTS.md](AGENTS.md). Konzept (maßgeblich): [README.md](README.md). **Komponenten (Maße, Farben, Zustände): [layout/Komponenten.dc.html](layout/Komponenten.dc.html), zusammengefasst in [docs/Komponenten-Masse.md](docs/Komponenten-Masse.md) — einzige Quelle für Größen.** Design: [layout/Disk Index App.dc.html](layout/Disk%20Index%20App.dc.html).

## Regeln für Cursor (verbindlich)

1. **Nur Aufgaben aus „A. Jetzt“**, in der dort stehenden Reihenfolge. „B. Backlog“ und alles andere nicht anfassen, auch nicht „vorbereiten“.
2. **Nach jedem Paket anhalten** (Zeile „HALT“). Erst weiterarbeiten, wenn Claude in A. freigegeben hat.
3. **Nichts erfinden.** Kein Feature, Text, Schalter, Screen ohne Vorgabe in README oder Layout. Fehlt etwas: Frage unter die Aufgabe schreiben („Frage:“), nicht bauen. Nötige Texte ohne Layout-Vorlage nur als rote Vorschläge (`ProposalCopy`).
4. **Layout und README sind schreibgeschützt** für Cursor (auch `AGENTS.md`, `archiv/`). Abweichung gefunden → als „Frage:“ melden, nicht selbst „angleichen“.
5. **Diese Datei:** Cursor ändert nur das Feld „Status“ der jeweiligen Aufgabe (höchstens 5 Zeilen: was, welche Dateien, Abweichung). Keine Reviewblöcke, keine neuen Aufgaben, nichts umsortieren, nichts löschen. Claude räumt auf.
6. **Keine Selbstfreigabe.** Cursor schreibt „Bereit zur Prüfung“, nie „fertig“. Nur Claude verschiebt nach DONE.md.
7. **Belege statt Behauptungen:** „Tests grün“ nur mit Zahl, Uhrzeit, Kommando. Bildschirmfotos nur melden, wenn sie in diesem Lauf neu erzeugt wurden (Zeitstempel prüfen). Build Debug und Release ohne Warnung.
8. **Tests:** nur `-only-testing:diskindexTests`; nach **jeder Aufgabe seriell**, am **Ende des Pakets** zusätzlich einmal parallel. UI-Tests nicht starten (Passwortabfrage). Leistungszahlen nur im Release-Build.
9. **Kein Aufräumen, Verschieben oder Löschen** von Dateien, die nicht in der Aufgabe stehen. Kein Refactoring „nebenbei“.
10. **Echte Fenster testen, nicht nur Bilder.** Das Offscreen-Bildschirmfoto (`ScreenshotRunner`) beweist nicht, dass eine Ansicht im echten Fenster funktioniert (Beispiel: `NSTableView`-Zeilen waren im Foto da, im echten Fenster leer). Bei jeder Aufgabe, die Ansichten, Klickflächen oder `NSViewRepresentable` berührt: Test mit echtem `NSWindow` (`makeKeyAndOrderFront`, Layout abwarten, Zeilen/Knöpfe zählen, Klick per `hitTest` auf Randpunkte).
11. **Regression-Rauchtest** (`RegressionSmokeTests`, Cursor legt ihn bei Aufgabe 122 an und erweitert ihn bei jeder Aufgabe): jede Ansicht, die schon einmal kaputt war, bekommt eine Zeile. Vor „Bereit zur Prüfung“ muss er grün sein. Eine Aufgabe, die etwas Abgenommenes wieder kaputt macht, gilt als nicht erledigt.
12. **Gemeinsame Bausteine nur zentral ändern** (Knopf, Chip, Zeile, Spaltenkopf, Leerzustand): eine Quelle, Änderung wirkt überall, Test an der Quelle. Keine zweite Kopie in einer Ansicht.
13. **Maße nur aus dem Komponentenkatalog** (`docs/Komponenten-Masse.md`, Quelle `layout/Komponenten.dc.html`). Keine eigenen Zahlen für Höhe, Innenabstand, Schrift, Rahmen, Radius. Jede Komponente hat einen Messtest gegen diese Zahlen (±0,5 pt), Hell und Dunkel.
14. **Nach Fehlern zurückrollen statt überbauen:** schlägt ein Test fehl, Ursache beheben, nicht Test abschwächen.
15. **Zeichenpfad sauber halten:** in `body`, `init`, `Binding(get:)`, `@State … = …` und `onAppear` **keine** Systemaufrufe (`SMAppService`, `UNUserNotificationCenter`, Dateisystem, Datenbank) und **keine** Zustandsänderungen. Solche Werte liegen in `AppState` und werden im Hintergrund aktualisiert.
16. **Zeilenangaben sind Richtwerte** („Z. ~“). Gilt eine Zeile nicht mehr, über den genannten **Symbolnamen** suchen; nichts an anderer Stelle „ähnlich“ ändern.

---

## A. Jetzt

**Stand 08.10.:** Abgenommen bis 166 (siehe DONE.md). Offen: 167–170 unten.

## ARBEITSAUFTRAG JETZT (Claude, 08.10. — exakt so umsetzen)

**Lies zuerst diese drei Regeln, sie gelten für jede Aufgabe unten:**
- **R1 Nur die genannten Stellen ändern.** Jede Aufgabe nennt Datei und Zeile. Andere Dateien nur, wenn die Aufgabe es sagt. Keine „Verbesserungen nebenbei“.
- **R2 Beweis = Pixel aus einem echten Fenster.** `hitTest != nil`, `source.contains(…)`, Zahlenvergleiche mit Konstanten und Prüfungen nur am Datenmodell zählen **nicht** als Beweis für Aussehen oder Klickverhalten. Benutze dafür ausschließlich die Hilfe `PixelProbe` (unten, Aufgabe 150 a). Jeder neue Test wird einmal **sabotiert** (die Korrektur zurücknehmen) und muss dann rot sein; im Status: „Sabotage: rot ✓“.
- **R3 Status je Aufgabe:** höchstens 5 Zeilen: geänderte Dateien:Zeilen, Testname, Ergebnis der Sabotage, Pfad der Bildschirmfotos (neu erzeugt in `Werkzeuge/screenshots/<JJJJ-MM-TT>-<aufgabe>/`). Ohne diese vier Angaben gilt die Aufgabe als nicht gemacht.

---

**Claude-Prüfung 08.10. (zweite Runde):** 158–166 **abgenommen**. Claude-Lauf **334 Tests, 81 Suiten seriell grün** (stimmt mit Cursor überein). Fotos geprüft: Sprachschalter 160 × 24,4 mit Pfeil rechts, Warnkreis gelb in der Statusfläche, Vergleichsbogen Icons vorhanden. Volltexte: `archiv/todo-stand-2026-10-08b.md`.

**Nutzerentscheidungen 08.10.:** Icon-Füllung **50 %** bleibt (so wie jetzt). Texte „Mitteilungen sind eingeschaltet./ausgeschaltet.“ sind **feste Konzepttexte**, nicht rot.

**Nutzertest 08.10. — neuer Arbeitsauftrag (R1–R3 gelten):**

**167. Einstellungen: Wechsel zu „Allgemein“, „Dateien & Ordner“, „Erweitert“ verzögert (auch Sprach-Dropdown).**
*Ursache (geprüft im Code 08.10.):* Diese drei Tabs sind **dieselbe** Ansicht `SettingsGeneralTab` (`SettingsView.tabContent`, Z. ~73–84); „Speichermedien“ ist `SettingsMediaRegistryPanel` und ist **nicht** langsam. In `SettingsGeneralTab` läuft `LaunchAtLogin.state` (liest `SMAppService.status`, **synchroner Systemaufruf**) auf dem **Hauptfaden** an drei Stellen:
- Z. 19 `@State private var launchAtLogin = LaunchAtLogin.state` — der Ausdruck wird bei **jedem Erzeugen** der Struktur ausgewertet, also bei **jedem** Neuzeichnen von `SettingsView` (Tabwechsel, jede Einstellungsänderung, Öffnen des Dropdowns);
- Z. 58 `.onAppear { launchAtLogin = LaunchAtLogin.state }`;
- Z. 60 (Aktualisierung bei App-Aktivierung).
(Z. 108/109 laufen bereits in `Task.detached` — dort nichts ändern.)
*Ändern:*
1. `AppState` bekommt `var launchAtLoginState: LaunchAtLogin.State` (beobachtet) und `func refreshLaunchAtLoginState()`: liest `LaunchAtLogin.state` in `Task.detached` und setzt den Wert danach auf dem Hauptfaden. Aufrufen: beim App-Start (`AppDelegate`, nach Aufbau von `AppState`), bei `NSApplication.didBecomeActiveNotification`, nach jedem `setEnabled`.
2. `SettingsGeneralTab`: Z. 19 ersetzen durch Lesen von `appState.launchAtLoginState`; Z. 58 und 60 löschen; der Schalter setzt sofort `appState.launchAtLoginState` (optimistisch, wie jetzt) und ruft danach den Hintergrund-Task wie bisher.
3. **Audit „überall“:** in **allen** Dateien unter `Views/`, `MenuBar/`, `DesignSystem/` suchen nach `LaunchAtLogin.`, `SMAppService`, `UNUserNotificationCenter`, `getNotificationSettings`, `FileManager`, `NSWorkspace`, `resourceValues`, `try await store`/`indexStore` in `body`, `init`, `Binding(get:)`, `onAppear`, `@State … = <Funktionsaufruf>`. Jede Fundstelle im Zeichenpfad wie in 1 in den Zustand verlagern. Liste „Datei:Zeile, Aufruf, Abhilfe“ im Status (auch „keine weiteren Funde“, wenn so).
*Test `SettingsTabSwitchTests`:* Attrappe `LaunchAtLogin.stateProvider` (Funktion, die 300 ms schläft und zählt, auf welchem Faden sie läuft). Alle vier Tabs per Mausereignis nacheinander anklicken: neuer Tabinhalt ist im Bitmap (`PixelProbe`) **≤ 50 ms** nach dem Klick sichtbar; die Attrappe wurde **0-mal auf dem Hauptfaden** aufgerufen. *Sabotage:* Z. 19 wiederherstellen → rot.
*Status:* `LaunchAtLogin.swift` (stateProvider, state), `AppState.swift` (launchAtLoginState, refreshLaunchAtLoginState), `AppDelegate.swift` ~66–74 (Start + didBecomeActive), `SettingsGeneralTab.swift` ~18/57/97–107; Audit: `MenuBarController.swift` ~233 (Kontextmenü las `LaunchAtLogin.isEnabled` synchron) und ~278 (Umschalten) → `appState.launchAtLoginState` + Task.detached; `ProposedCopy.swift` 130–149 nur Klickaktion (Debug-Export), keine weiteren Funde.
Test `SettingsTabSwitchTests` (alle 4 Tabs per Mausklick, ≤ 50 ms, Attrappe 0× Hauptfaden) grün; Sabotage Z. 19: rot ✓ (350 ms, 4× Hauptfaden). `PixelProbe.click` hat Parameter `settle` (Standard 50 ms wie bisher).
Debug/Release ohne Warnung. Seriell 19:46: 335 Tests/82 Suiten, 3 rot: LayoutCopyTests + ProposalCopyTests (neues Layout-HTML, wird in 171.3 behoben); Frage: `ColumnChromeTests.folderColumnHidesScrollTrack` ist auch einzeln rot (odd 242), im Bild ist eine Scrollbalken-Spur zu sehen, Code dort unverändert, vermutlich Systemeinstellung „Rollbalken“. Nicht angefasst (R1).
Fotos: `Werkzeuge/screenshots/2026-10-08-167/`. Bereit zur Prüfung.

**168. „Mitteilungen sind ausgeschaltet.“ erscheint nicht — Reihenfolge von Senden und Abschalten festlegen.**
*Ursache (geprüft):* `NoticeToggle.apply` (`App/SystemNotice.swift` Z. ~21–41) postet die Aus-Meldung und setzt **sofort danach** `settings.notificationsEnabled = false`. Zugestellt wird die Meldung erst später; dann fragt `AppDelegate.userNotificationCenter(_:willPresent:)` (Z. ~354–365) `appSettings.notificationsEnabled` → `false` → `completionHandler([])` → macOS zeigt nichts (die App ist dabei aktiv, Nutzer steht in den Einstellungen).
*Ändern — genau diese Abfolge in einer Funktion `AppState.setNotificationsEnabled(_ enabled: Bool)`; die Ansicht (`SettingsGeneralTab` Z. ~239–254) ruft nur noch diese auf:*
- **Anzeige getrennt vom wirksamen Wert:** `notificationsToggleShown: Bool` (Kästchen + Ausgrauen der Unterpunkte, Z. ~265–271, lesen **diesen** Wert); `appSettings.notificationsEnabled` ist der **wirksame** Wert für alle Meldungen.
- **Ausschalten:** (1) `notificationsToggleShown = false` sofort. (2) Sperre prüfen (`NoticeThrottle`, als Abhängigkeit von `AppState`, nicht `.shared`, damit Tests eine eigene Uhr geben können). (3a) Sperre frei: Meldung „Mitteilungen sind ausgeschaltet.“ über `SystemNotice.submit` mit `kind: "notices-off"` (steht bereits in `userInfo["diskindex.noticeEvent"]`); **erst im Completion-Handler** von `center.add` den wirksamen Wert auf `false` setzen und speichern. (3b) Sperre aktiv: wirksamen Wert sofort auf `false`.
- **Einschalten:** (1) `notificationsToggleShown = true`. (2) Wirksamen Wert `true` setzen und speichern. (3) **Danach** Meldung „Mitteilungen sind eingeschaltet.“ (`kind: "notices-on"`, Sperre prüfen).
- **Schnelles Umschalten:** jede Betätigung bekommt eine fortlaufende Nummer; ein Completion-Handler setzt den wirksamen Wert nur, wenn seine Nummer noch die **letzte** ist. Endzustand = letzter Klick.
- **`willPresent`:** wenn `userInfo["diskindex.noticeEvent"]` `notices-on` oder `notices-off` ist → **immer** `[.banner, .list, .sound]`; alle anderen Meldungen wie bisher.
- Texte `noticesTurnedOn/Off` von `ProposalCopy` nach `LayoutCopy` verschieben (feste Konzepttexte, nicht rot), Eintrag in der Vorschlagsliste entfernen.
- `NoticeToggle.apply` danach löschen (ersetzt).
*Test `NoticeToggleOrderTests`* mit `SystemNotice.center` = Attrappe (`NoticePosting`), die jeden Aufruf mit Zeitstempel in ein Protokoll schreibt und den Completion-Handler **200 ms** später aufruft: (a) Aus: Protokoll `add(notices-off)` **vor** `effective=false`; während der 200 ms ist `effective == true`, `shown == false`. (b) An: `effective=true` **vor** `add(notices-on)`. (c) an → aus → an in 100 ms (eingespeiste Uhr): Endzustand `effective == true`, `shown == true`, höchstens eine Meldung je Art. (d) Delegate-Attrappe: `notices-off` bei `effective == false` → `[.banner, .list, .sound]`; Art `system` bei `effective == false` → `[]`. *Sabotage:* in (a) Wert vor dem Posten setzen → rot.
*Status:* `SystemNotice.swift` (`AppState.setNotificationsEnabled`, `presentationOptions`, `submit(…added:)`, `NoticeToggle`/`.shared` entfernt), `AppState.swift` (`noticeThrottle`, `noticeToggleSequence`, `notificationsToggleShown`), `AppDelegate.swift` `willPresent`, `SettingsGeneralTab.swift` ~231–262, Texte `LayoutCopy.noticesTurnedOn/Off` + `Localizable.xcstrings` (de/en), aus `ProposalCopy` samt Katalog entfernt.
Test `NoticeToggleOrderTests` (a–d) + angepasst `NoticeThrottleTests` grün; Sabotage (a): rot ✓. (d) prüft die von `willPresent` benutzte Funktion `presentationOptions` (eine echte `UNNotification` lässt sich im Test nicht bauen).
Debug/Release ohne Warnung. Seriell 20:01: 339 Tests/83 Suiten, 3 rot wie bei 167 (LayoutCopy/ProposalCopy → 171.3; ColumnChrome-Frage s. 167).
Fotos: `Werkzeuge/screenshots/2026-10-08-168/`. Bereit zur Prüfung.

**169. Fortschritt endet bei 99 % und soll schneller sein.**
*Ursache (geprüft):* `IndexProgressDisplay.displayed(id:indexing:fallback:now:)` (`App/AppState+Media.swift` Z. ~331–346) gibt bei beendetem Lauf und `elapsed ≥ 1` **sofort `nil`** (Endzustand) zurück. Das letzte gezeichnete Bild hatte einen Wert knapp unter 1 (z. B. 0,996), `StatusChip` (Z. ~105) und Popover runden mit `floor` → **99 %**; 100 % wird nie gezeichnet. Außerdem verändert `displayed` beim **Zeichnen** den Zustand (`runs[id] = …`), das Ergebnis hängt damit davon ab, wann gezeichnet wird.
*Ändern:*
1. Konstanten `IndexProgressDisplay.minimumDuration = 0.6` (Sekunden, README §4) und `holdAtFull = 0.3`.
2. `Run` speichert `startedAt`, `real`, `endedAt: Date?`. `note(...)` setzt beim Ende `endedAt = now`, `real = 1`.
3. `displayed` wird **rein** (keine Zuweisung an `runs`): `clock = min(1, (now − startedAt) / minimumDuration)`; laufend: `min(real, clock)`; beendet: `min(1, clock)`; ist beendet **und** `clock == 1`: Anzeige **1,0** bis `max(startedAt + minimumDuration, endedAt) + holdAtFull`, danach `nil`. Aufräumen der beendeten Läufe in `note(...)` oder per Zeitgeber, nicht beim Zeichnen.
4. Prozentzahl in Chip und Popover aus genau diesem Wert (`Int(floor(v * 100))`, ergibt bei 1,0 **100**); Balken ebenso. Die bestehende Obergrenze 0,99 gilt nur für den **echten** Fortschritt während des Laufs (`note`), nicht für die Abschlussbewegung.
*Test `ProgressHoldTests` (anpassen):* Lauf endet nach 0,1 s (eingespeiste Uhr): bei 0,3 s ≈ 50 % (±5), bei 0,6–0,9 s **genau 100** (Chip-Text, Popover-Text „100 %“, Balken voll per `PixelProbe` im Popover), bei 0,95 s Endzustand (`nil`). Langsamer Lauf (echt 0,2 bei 1 s) → Anzeige 0,2. Zweimal mit derselben Uhrzeit abfragen → gleiches Ergebnis (rein). *Sabotage:* `holdAtFull` auf 0 → rot.
*Status:* `AppState+Media.swift` `IndexProgressDisplay` (minimumDuration 0,6, holdAtFull 0,3, `Run.endedAt`/`expiresAt`, `displayed` rein, Aufräumen in `note`); `MenuBarConnectedMediumRow.swift` `indexingProgressLabel` nicht mehr privat (für den Test). Chip/Popover rechnen schon mit `Int(floor(v*100))` → bei 1,0 = 100.
Test `ProgressHoldTests` (0,3 s ≈ 50 %, 0,6/0,75/0,89 s = 100 in Chip und „100 %“ im Popover, 0,95 s nil, Balken voll per `PixelProbe`, rein, langsamer Lauf 0,2) grün; Sabotage holdAtFull 0: rot ✓.
Debug/Release ohne Warnung. Seriell 20:07: 340 Tests/83 Suiten, 3 rot wie bei 167.
Fotos: `Werkzeuge/screenshots/2026-10-08-169/`. Bereit zur Prüfung.

**170. Sprach-Dropdown liegt unter den folgenden Abschnitten.**
*Befund (Nutzerfoto 08.10.):* Trennlinie und „Hell/Dunkel/Automatisch“ des nächsten Abschnitts liegen **über** dem aufgeklappten Feld.
*Ursache (geprüft):* Das Feld ist ein `.overlay(alignment: .topLeading)` am Schalter (`SettingsLanguagePicker` Z. ~46–50). Spätere Geschwister im `VStack` der Einstellungsseite werden danach gezeichnet und liegen oben; `.zIndex(1)` **innerhalb** des Overlays wirkt nur innerhalb des Overlays.
*Ändern:* In `SettingsGeneralTab` dem **ganzen Abschnitt** „Sprache“ (der Zeile, die `SettingsLanguagePicker` enthält, im `VStack` der Seite) `.zIndex(isLanguageMenuOpen ? 10 : 0)` geben; `isLanguageMenuOpen` als `@Binding` vom Picker nach oben reichen. Öffnen und Schließen **ohne Animation** (`Transaction(animation: nil)`). Klick außerhalb schließt (bestehendes Verhalten beibehalten).
*Test `LanguagePickerTests` (erweitern):* Feld per Mausereignis öffnen; `PixelProbe`: an der Stelle, wo die Trennlinie unter dem Abschnitt „Sprache“ durch das Feld liefe, hat das Pixel die **Feldfarbe** (nicht die Linienfarbe ±3); ebenso an der Position des Knopfes „Hell“ unter dem Feld. Feld sichtbar ≤ 50 ms nach dem Klick. *Sabotage:* `.zIndex` entfernen → rot.
*Status:* `SettingsLanguagePicker.swift` (`@Binding isOpen`, `setOpen` mit `Transaction(animation: nil)`), `SettingsGeneralTab.swift` ~21 (`isLanguageMenuOpen`), ~33 (`.zIndex`), ~83. `PixelProbe.Session.color(at:)` neu (1-Punkt-Aufnahme für die Zeitmessung).
Test `LanguagePickerTests.openPanelCoversFollowingSections` (echte Seite, Klick, Trennlinie hat Feldfarbe ±3, ≤ 50 ms) grün, 3×; Sabotage `.zIndex` weg: rot ✓.
Frage: „Hell“ liegt bei 2 Sprachen nicht unter dem Feld (Feld endet bei 108,5 pt, Oberkante „Hell“ ≈ 108 pt, auch bei 1400 pt Breite). Deshalb nur die Trennlinie geprüft. Soll das Feld höher werden, oder genügt das?
Debug/Release ohne Warnung. Seriell 20:20: 341 Tests/83 Suiten, 3 rot wie bei 167. Fotos: `Werkzeuge/screenshots/2026-10-08-170/`. Bereit zur Prüfung.

**171. Layout-Entscheidungen vom 08.10. umsetzen (Nutzer: „Layout gilt“; Claude hat das Layout-HTML angepasst, README ist nachgezogen).**
1. **Bestätigungsknopf** (`DesignSystem/ConfirmButton.swift`): Zurücksetzen in den Ausgangszustand **auch, wenn der Zeiger den Knopf verlässt** (Layout 05), zusätzlich wie bisher nach 3 s. Das Flackern von früher (124) kam vom Schrumpfen; die Breite ist jetzt fest, daher ist das Verlassen wieder sicher. Nicht zurücksetzen, solange „Bestätigt“ (grün) angezeigt wird. *Test:* echtes Mausereignis Klick → Stufe „Bestätigen“; Mausbewegung aus dem Knopf (`mouseExited` per `NSEvent.mouseEvent(.mouseMoved)` außerhalb) → Ausgangszustand; Bewegung innerhalb → bleibt.
2. **Pausen-Mitteilungen nach Layout 03** (`App/GlobalPause.swift` `PauseNoticeCopy`, `LayoutCopy`): Pausieren → „Indizierung pausiert bis HH:MM Uhr.“, bei „Für immer“ → „Indizierung pausiert.“; Ende der Pause (Ablauf, Aufwachen) **und** Klick auf „An“ → „Medien werden wieder indiziert.“ Alte Texte („Automatisches Indizieren ist pausiert …“, „Die Pause ist abgelaufen …“, „… ist wieder an.“) entfernen, auch aus dem Beispielkasten in Erweitert, falls dort verwendet. *Test:* Attrappe für das Posten: drei Fälle, exakter Text.
3. **Texte, die jetzt im Layout stehen** (Claude hat sie dort eingetragen), aus `ProposalCopy` nach `LayoutCopy` (nicht mehr rot): „Systemmeldungen umfassen Hinweise zu Fehlern und zu Pausen.“ (`ProposalCopy.noticesSystemAndPauses`, Z. ~71/109) und der Sprachhinweis **„Sprache der Benutzeroberfläche. Die Änderung gilt sofort.“** (`LayoutCopy.languageText`, Katalogschlüssel `copy.settings.language.text`, auch Englisch anpassen: „Language of the user interface. The change applies immediately.“).
4. **Kein blauer Spinner in der Menüleiste** (Layout 01: online und fertig = kein Badge, auch beim Abgleich): `MenuBar/MenuBarStatusBadgeView.swift` Z. ~26 (Spinner in `DesignColor.filterSearch`) und die Menge `menuBarReconcileSpinnerIDs` (`AppState.swift` Z. ~101, `AppState+Media.swift` Z. ~203–228, `AppState+IndexChanges.swift` Z. ~66) entfernen. Grüner Spinner nur bei Erstlauf und „Neu indizieren“. *Test:* Medium vollständig indiziert, Abgleich läuft → Badge-Zustand „keiner“.
5. **`LayoutCopyTests`** gegen das **neue** Layout-HTML laufen lassen; jede Abweichung beheben (nicht den Test anpassen).
*Status:* (1) `ConfirmButton.swift` `.onHover` → `gate.leave()`. (2) `Localizable.xcstrings` pause_until/forever/resumed neu (de/en), `AppState+Pause.swift` Ablauf nutzt `noticePauseResumedManual`. (3) `LayoutCopy.noticesSystemAndPauses` + Katalog, `languageText` „…gilt sofort.“ (de/en), beide aus `ProposalCopy` raus. (4) `MenuBarStatusBadgeView` `.syncing` = kein Badge, `menuBarReconcileSpinnerIDs`/`noteMenuBarReconcileSpinner` entfernt (AppState, +Media, +IndexChanges, IndexingService), Badge-Abgleich-Zweig weg. (5) `LayoutCopyTests`/`ProposalCopyTests` grün, keine weiteren Abweichungen.
Tests: `ConfirmButtonHoverTests`, `PauseNoticeTextTests` (3 Fälle, exakter Text), `LiveSyncMetaTests.menuBarBadgeStaysEmptyDuringSync` (ersetzt den alten Syncing-Test), `Task86Tests` auf neuen Text. Sabotage (2) und (4): rot ✓. Frage zu (1): Der Test-Host wird nie aktiv (`NSApp.isActive == false`), deshalb liefert SwiftUI kein `onHover`. Das Verlassen ist im Test als `withKnownIssue` markiert, eine Sabotage ist so nicht nachweisbar (Klick → „Bestätigen“ und Bewegung innerhalb sind geprüft). Frage: Der Beispielkasten in Erweitert zeigt laut Layout weiter „Die Pause ist abgelaufen. …“, daher nicht geändert.
Debug/Release ohne Warnung. Seriell 20:35: 345 Tests/85 Suiten, 1 rot (`ColumnChromeTests.folderColumnHidesScrollTrack`, Frage s. 167) + 1 bekanntes Problem. Parallel 20:42: 357 Fälle bestanden, 3 rot: ColumnChrome (s. o.), `SurfaceStoreTests.forgetAllClearsUIAndDatabase` und `ColumnAndSearchTests.aNewBatchAppearsWithoutReopening`; die beiden letzten sind seriell grün (17/17, 20:46), nur parallel unter Last.
Fotos: `Werkzeuge/screenshots/2026-10-08-171/`. Bereit zur Prüfung.

**HALT nach 171.** Reihenfolge 167 → 168 → 169 → 170 → 171.

### Offen, ohne Cursor

- **Nutzer:** (1) Kurztest am Stick für 107: großen Ordner öffnen, Pfeiltasten, Mehrfachauswahl, Rechtsklick. (2) Layout nachziehen: alte Chip-Beschreibungstexte, Menüleisten-Symbol „blauer Spinner (Abgleich)“ (112 Punkt 3), Texte der roten Vorschläge (Debug-App prüfen). (3) Entscheiden: T5 (ausführliches Protokoll) freigeben?
- **Claude:** Layout (Stand 07.10.) gegen README abgleichen; danach neue Aufgaben für Cursor schreiben. Spezifikationen der abgenommenen Aufgaben: `archiv/todo-stand-2026-10-07.md`.

---

## B. Backlog (nicht freigegeben, Cursor arbeitet nicht daran)

- **T1. Ladehinweis erst nach 1 s** (Nutzer 06.10.): gehört zu 107; Suche/Favoriten später.
- **T2. Programme als Dateityp „Programme“** (`.app`-Pakete, dmg, pkg).
- **T3. Erweiterte Dateityp-Icons** (Styleguide Sektion 15).
- Cursor hat T1–T3 vorzeitig gebaut; Claude entscheidet bei der Prüfung, was bleibt.
- **T5 (Vorschlag Claude, wartet auf Nutzer): Ausführliches Protokoll („Diagnose-Modus“).** Es gibt schon `~/Library/Logs/Disk Index/diskindex.log` (Kategorien, `crash-last.txt`, „previous run ended without clean exit“). Lücken: (1) **Beenden wird nicht protokolliert** (`applicationShouldTerminate` schreibt nichts; nur `applicationWillTerminate` „app terminate ok“) → Zeilen „quit requested (Quelle)“, „quit: status item entfernt“, „quit: Indizierung gestoppt“ mit Dauer. (2) **Haupt-Thread-Wächter:** blockiert der Hauptfaden > 2 s, Zeile `hang main ms=…` mit Stack (Release tauglich). (3) **Schalter** „Ausführlich“ (Erweitert, nur Debug oder per `defaults`) für Pegel `debug`: je Medium Dauer von Lesen/Schreiben, Cache-Treffer, Ladezeiten Spalten, Speicher. (4) `crash-last.txt` auch bei Beenden durch Signal. Nicht freigegeben.
