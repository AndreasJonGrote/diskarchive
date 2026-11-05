# Paket 62 — Zielversion 0.4.3 (freigegeben 05.11.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). Pfade relativ zu `claude/`; Code, `layout/`, `Werkzeuge/` im Hauptverzeichnis. **Fünftes von sechs Paketen für 0.4.3: Dialoge, Sperren, Update; dazu Erstellungsdatum (`todo.0.4.3.024`).** Vorlage: Layout 00 („Nur-Lesen-Modus“, „Mitteilungen und Fehler“), 04.03a–04.06, 13, 14, 15, 16, 17, 18. Konzept: `konzept/datenbank.md` „Netz (API)“ (Betaende, Lizenzserver, dringendes Update), Backlog 0.4.3 (`todo.0.4.3.001`, `002`).

**Für dieses Paket gilt:**
- **Texte nur aus `layout/App-Layout 20 Texte.json`**; die 5 Schlüssel mit `pendingPackage = 62` hier erledigen. **Danach ist `pendingPackage` leer** (Ziel von 0.4.3); verbleibende `openQuestions` im Status begründen.
- **Icons** aus `Werkzeuge/phosphor/`, **Schrift** aus `Werkzeuge/fonts/archivo/` (Regel 4a). Begriff überall **„Lizenzserver“**, nie „Versionsserver“.
- **Die Regeln der Sperre bleiben** (`FeatureAccess`, `VersionLockEvaluator`: wann gesperrt wird, Fristen, Uhr). Dieses Paket ändert die **Anzeige** und baut das dringende Update.
- Sabotage-Patch (Regel 9) je Verhaltensänderung. Läufe per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Git. **Vor „Bereit zur Prüfung“** alle Suites mit `Version`, `Lock`, `Update`, `Banner`, `About`, `Dialog`, `Crash`, `Notice`, `Store`, `Failure`, `Pixel`, `Column`, `Detail`, `Scan`, `Index` oder `L10n` im Namen; **zum Schluss einmal `Werkzeuge/pruefung.sh voll`** (ohne `S=`) und erst bei Grün „Bereit zur Prüfung“.

**Reihenfolge (HALT am Ende):** `todo.0.4.3.020` → `todo.0.4.3.002` → `todo.0.4.3.001` → `todo.0.4.3.021` → `todo.0.4.3.024`. **HALT.**

## Aufgaben

- **todo.0.4.3.020 — Banner im Nur-Lesen-Modus (04.03a–04.06, 00):**
  - Fester Banner zwischen Toolbar und Inhalt in jeder Ansicht (Vorlage 04.06). **Gelb = Hinweis, Rot = Sperre.**
  - **04.03a gelb:** „Die Betaphase von Disk Archive wurde beendet.“ / „Du kannst Disk Archive noch {n} Tage nutzen.“ (Einzahl „noch 1 Tag“), Knopf „Zur neuen Version“ (Startseite). Erscheint nach dem Update-Dialog, solange die 7-Tage-Frist läuft (`betaExpiryNoticedAt`); die Zahl zählt herunter. Ersetzt den Countdown-Text im Update-Dialog (`copy.update.available.beta_countdown` entfällt).
  - **04.03b rot:** „Die Betaphase ist beendet. Du kannst dein Archiv benutzen, aber nicht aktualisieren oder erweitern.“ nach Ablauf; **rot „Diese Version ist abgelaufen.“** (Build abgelaufen / gesperrte Version); beide mit „Zur neuen Version“.
  - **04.04 rot:** „Der Lizenzserver war seit einem Monat nicht erreichbar. …“ mit „Jetzt prüfen“; beim Prüfen Spinner und „Versionsprüfung …“ statt Icon, Text und Knopf (04.05); erreichbar → Banner weg, neue Version meldet der Update-Dialog; weiter nicht erreichbar → zurück zum roten Banner.
  - Mehrere Gründe: der rote Banner gewinnt (04.05). Die drei alten Banner (`copy.version_lock.banner.*`) entfallen.
  - **Test:** je Zustand Farbe, Text, Knopf; Frist zählt; „Jetzt prüfen“ mit beiden Ausgängen. Sabotage-Patch.
  - **Status:** Banner nach 04.03a–04.06 (`ReadOnlyBannerView`, Modell `ReadOnlyBanner` in `AppState+VersionLock.swift`): gelb mit Frist („noch {n} Tage“/„noch 1 Tag“, zählt minütlich), rot für Beta beendet, Version abgelaufen, Lizenzserver (Knopf „Jetzt prüfen“ → Spinner „Versionsprüfung …“ über `IssueReporter.checkVersionNow`, danach weg oder wieder rot). Rot gewinnt, während des Update-Dialogs kein Banner. Sperrregeln unverändert; der Evaluator meldet nur `betaNoticeDeadline`. Countdown-Text im Update-Dialog und die drei alten Banner-Schlüssel entfallen.
    Icons `IconBannerWarning`, `IconLockSimple`, `IconWifiSlash`. Tests: `ReadOnlyBannerTests` (neu), `VersionCheckTests` angepasst. Patches 020-a/b/c.
    Bereit zur Prüfung.

- **todo.0.4.3.002 — Dringendes Update aus der API** (Backlog 0.4.3, Konzept `datenbank.md` „Netz (API)“): `"urgent-update": true` → Vergleich der ganzen Version `x.x.x`, Update-Dialog sofort, beim Start und alle 24 h, **auch bei „Auf Updates hinweisen: Aus“**, nach „Schließen“ bei jeder Prüfung wieder. Fehlt das Feld oder ist es `false`: Regel `n.n` wie bisher. Texte des Update-Dialogs laut 13/20; „Zur neuen Version“ öffnet die Startseite. Test mit beiden Antworten; Sabotage-Patch.
  - **Status:** `"urgent-update"` gelesen (`VersionCheckClient.response(from:)`); ist es `true`, vergleicht der Evaluator die ganze Version und liefert ein Angebot mit `urgent`. Der Dialog kommt auch bei „Aus“ und nach „Schließen“ bei jeder Prüfung wieder. Die gemeldete Version wird in `settings` gemerkt (`urgentUpdateVersion`, nach jeder Antwort neu), damit der Dialog auch beim Start ohne Antwort erscheint. Ohne Feld gilt `n.n` wie bisher.
    Test: `UrgentUpdateTests` (neu, beide Antworten, Start, Aus, Schließen). Patches 002-a/b/c.
    Bereit zur Prüfung.

- **todo.0.4.3.001 — „Über Disk Archive“ (17):** eigener Dialog statt des Standardfensters: oben App-Icon und Name auf Verlauf mit Ringen, darunter schwarzer Balken mit Version (immer die aktuelle), Datum und „www.diskarchive.app“ (Link auf die Startseite); hell und dunkel gleich; schließt nur über den roten Punkt. Aufruf aus dem App-Menü. Test: Inhalt und Version aus dem Bundle.
  - **Status:** Eigenes Fenster (`AboutPanel.makeWindow`, `AboutView`) statt des Standardfensters: Verlauf mit fünf Ringen, App-Icon 112 pt, Name in Archivo; Balken `#0A0A0A` mit „Version {1} (Beta)“ aus dem Bundle, Build-Datum lang („9. Oktober 2026“) und Link „diskarchive.app“ (wie Layout 17). Hell und dunkel gleich, nur der rote Punkt.
    Test: `AboutAndSettingsMenuTests` (an das neue Fenster angepasst, Standard-Optionen entfallen). Patch 001.
    `copy.menubar.about` steht in `openQuestions`: In 20 ist „Über Disk Archive“ nur Sektionstitel, keine Zeile. `pendingPackage` ist leer.
    Bereit zur Prüfung.

- **todo.0.4.3.021 — Fehlerdialoge und Mitteilungen (14, 15, 16, 18):**
  - Fehler ohne eigenen Dialog nutzen Dialog 16 (aus Paket 59): u. a. „Index-Datenbank nicht verfügbar“ beim Start (18: dazu die Mitteilung, braucht nur die macOS-Erlaubnis). Welche Stellen heute eigene Alerts haben, im Status auflisten und auf 16 umstellen.
  - 14 Indizierungsfehler laut 14.01–14.04 (Ort, Drosselung höchstens dreimal pro Stunde und Medium, Schließen-Bedingungen, Grund-Zeile a–h, unbekannter Grund ohne Zeile) gegen die App prüfen und angleichen.
  - 15 Absturzbericht: Icon rot.
  - 18: alle Mitteilungen laut Liste (Titel immer „Disk Archive“ außer Nr. 12, Bedingungen, Schalter); im Status jede Abweichung nennen.
  - **Test:** 16 für Datenbank; 14-Drosselung; Mitteilungstexte gegen 20. Sabotage-Patch, wo Verhalten sich ändert.
  - **Status:** Eigene Alerts gab es nicht mehr (kein `NSAlert`). Eigener Dialog war nur „Index-Datenbank nicht verfügbar“ (`StoreOpenFailureDialog`); er ist jetzt Dialog 16 mit Text aus 18 und „Erneut versuchen“, die Mitteilung (Nr. 12) bleibt. Das Icon des Absturzberichts (15) ist rot.
    14 geprüft: Drosselung 3×/h je Medium, Mitteilung zusammen mit dem Dialog, Rückzug bei Fehlerende, Grundzeilen a–h, unbekannt ohne Zeile – alles schon so. 18 geprüft: Nr. 1–12 vorhanden, Titel „Disk Archive“ außer Nr. 12, Schalter wie Liste; keine Abweichung. Texte gegen 20: `LayoutCopyTests`.
    Tests: `ErrorDialogsAndNoticesTests` (neu); `ButtonStyleMetricsTests` und `ArchivoFontTests` auf Dialog 16 umgestellt. Patches 021-a/b.
    Bereit zur Prüfung.

- **todo.0.4.3.024 — Erstellungsdatum und Mehrfachauswahl (07, Host 05.11. aus Paket 61):**
  - Der Index erfasst das **Erstellungsdatum** jeder Datei (`creationDate` der Ressourcenwerte) beim Scan; Schema-Erweiterung ist erlaubt (bis 1.0 keine Migration nötig, alte Einträge bleiben ohne Wert). Die Detailspalte zeigt es bei „Erstellt“; ohne Wert bleibt „—“.
  - Bei **Mehrfachauswahl** steht „Im Finder anzeigen“ wie bei einer Datei (nur online), markiert alle gewählten Objekte im Finder.
  - **Test:** Datum nach Scan gespeichert und angezeigt; Altbestand „—“; Mehrfachauswahl mit Link online, ohne offline. Sabotage-Patch.
  - **Status:** Scanner liest `ATTR_CMN_CRTIME` (Bulk) bzw. `creationDate` (Rückfallweg) → `ScannedEntry.createdAt` → `item_details.createdAt` (Spalte gab es schon, keine Migration) → `IndexedItem.createdAt` → „Erstellt“ in der Detailspalte. Ohne Wert „—“. Altbestand ohne Änderung bekommt keinen Wert (Aufgabe). Bei Mehrfachauswahl steht „Im Finder anzeigen“ (nur online) und markiert alle (`revealInFinder(_ targets:)`).
    Tests: `CreationDateTests` (neu, echter Ordner, Index, Detailspalte, online/offline), `BulkRecordParserTests` (Puffer mit CRTIME). Patches 024-a/b/c.
    Läufe: Pflicht-Suites 10:52–10:56 457/457; `voll` 10:56–11:33 grün (seriell 1337/1337, parallel 3× je 1330 + 7 übersprungen, 0 Warnungen Debug/Release, Sabotage 12/12 rot ✓, 0 Absturzberichte, Nutzer-App aktuell).
    Bereit zur Prüfung.

## Korrektur Host 05.11. (Gesamtlauf 12:13–12:49)

Ergebnis: Debug/Release 0 Warnungen, seriell 1337/1337, Parallel 1 und 3 grün, **Parallel 2 rot (1)**, Sabotage 12/12 rot ✓, keine `.ips`, 0 neue Dateien in `~/Library/Preferences`. Diff gelesen, sonst nichts Wesentliches.

- **K1 — `ReadOnlyBannerTests.checkNowShowsSpinnerThenEitherClearsOrReturnsToRed` rot unter Last** (Parallel 2: `waitUntil(timeout: 5) { !app.licenseServerCheckInProgress }`). Eigener Test des Pakets; `waitUntil` prüft nach Ablauf nicht noch einmal, unter Hauptthread-Last reichen 5 s nicht. **Soll:** beide Wartestellen `timeout: 20` (wie Paket 60, K4); Helfer nicht ändern. Alle in diesem Paket neuen oder geänderten Tests auf `waitUntil` mit weniger als 20 s prüfen und ebenso anheben. Verhalten der App unverändert, kein Sabotage-Patch.
- Danach einmal `Werkzeuge/pruefung.sh voll` (ohne `S=`); erst bei Grün „Bereit zur Prüfung“.
- **Status K1:**
