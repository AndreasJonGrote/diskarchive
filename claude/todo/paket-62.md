# Paket 62 — Zielversion 0.4.3 (vorbereitet 03.11.2026; freigegeben, sobald Paket 61 abgenommen ist)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md). Pfade relativ zu `claude/`; Code, `layout/`, `Werkzeuge/` im Hauptverzeichnis. **Fünftes von sechs Paketen für 0.4.3: Dialoge, Sperren, Update.** Vorlage: Layout 00 („Nur-Lesen-Modus“, „Mitteilungen und Fehler“), 04.03a–04.06, 13, 14, 15, 16, 17, 18. Konzept: `konzept/datenbank.md` „Netz (API)“ (Betaende, Lizenzserver, dringendes Update), Backlog 0.4.3 (`todo.0.4.3.001`, `002`).

**Für dieses Paket gilt:**
- **Texte nur aus `layout/App-Layout 20 Texte.json`**; die 5 Schlüssel mit `pendingPackage = 62` hier erledigen. **Danach ist `pendingPackage` leer** (Ziel von 0.4.3); verbleibende `openQuestions` im Status begründen.
- **Icons** aus `Werkzeuge/phosphor/`, **Schrift** aus `Werkzeuge/fonts/archivo/` (Regel 4a). Begriff überall **„Lizenzserver“**, nie „Versionsserver“.
- **Die Regeln der Sperre bleiben** (`FeatureAccess`, `VersionLockEvaluator`: wann gesperrt wird, Fristen, Uhr). Dieses Paket ändert die **Anzeige** und baut das dringende Update.
- Sabotage-Patch (Regel 9) je Verhaltensänderung. Läufe per `Werkzeuge/pruefung.sh schnell …` (ohne `S=`), kein Git. **Vor „Bereit zur Prüfung“** alle Suites mit `Version`, `Lock`, `Update`, `Banner`, `About`, `Dialog`, `Crash`, `Notice`, `Store`, `Failure`, `Pixel` oder `L10n` im Namen.

**Reihenfolge (HALT am Ende):** `todo.0.4.3.020` → `todo.0.4.3.002` → `todo.0.4.3.001` → `todo.0.4.3.021`. **HALT.**

## Aufgaben

- **todo.0.4.3.020 — Banner im Nur-Lesen-Modus (04.03a–04.06, 00):**
  - Fester Banner zwischen Toolbar und Inhalt in jeder Ansicht (Vorlage 04.06). **Gelb = Hinweis, Rot = Sperre.**
  - **04.03a gelb:** „Die Betaphase von Disk Archive wurde beendet.“ / „Du kannst Disk Archive noch {n} Tage nutzen.“ (Einzahl „noch 1 Tag“), Knopf „Zur neuen Version“ (Startseite). Erscheint nach dem Update-Dialog, solange die 7-Tage-Frist läuft (`betaExpiryNoticedAt`); die Zahl zählt herunter. Ersetzt den Countdown-Text im Update-Dialog (`copy.update.available.beta_countdown` entfällt).
  - **04.03b rot:** „Die Betaphase ist beendet. Du kannst dein Archiv benutzen, aber nicht aktualisieren oder erweitern.“ nach Ablauf; **rot „Diese Version ist abgelaufen.“** (Build abgelaufen / gesperrte Version); beide mit „Zur neuen Version“.
  - **04.04 rot:** „Der Lizenzserver war seit einem Monat nicht erreichbar. …“ mit „Jetzt prüfen“; beim Prüfen Spinner und „Versionsprüfung …“ statt Icon, Text und Knopf (04.05); erreichbar → Banner weg, neue Version meldet der Update-Dialog; weiter nicht erreichbar → zurück zum roten Banner.
  - Mehrere Gründe: der rote Banner gewinnt (04.05). Die drei alten Banner (`copy.version_lock.banner.*`) entfallen.
  - **Test:** je Zustand Farbe, Text, Knopf; Frist zählt; „Jetzt prüfen“ mit beiden Ausgängen. Sabotage-Patch.
  - **Status:**

- **todo.0.4.3.002 — Dringendes Update aus der API** (Backlog 0.4.3, Konzept `datenbank.md` „Netz (API)“): `"urgent-update": true` → Vergleich der ganzen Version `x.x.x`, Update-Dialog sofort, beim Start und alle 24 h, **auch bei „Auf Updates hinweisen: Aus“**, nach „Schließen“ bei jeder Prüfung wieder. Fehlt das Feld oder ist es `false`: Regel `n.n` wie bisher. Texte des Update-Dialogs laut 13/20; „Zur neuen Version“ öffnet die Startseite. Test mit beiden Antworten; Sabotage-Patch.
  - **Status:**

- **todo.0.4.3.001 — „Über Disk Archive“ (17):** eigener Dialog statt des Standardfensters: oben App-Icon und Name auf Verlauf mit Ringen, darunter schwarzer Balken mit Version (immer die aktuelle), Datum und „www.diskarchive.app“ (Link auf die Startseite); hell und dunkel gleich; schließt nur über den roten Punkt. Aufruf aus dem App-Menü. Test: Inhalt und Version aus dem Bundle.
  - **Status:**

- **todo.0.4.3.021 — Fehlerdialoge und Mitteilungen (14, 15, 16, 18):**
  - Fehler ohne eigenen Dialog nutzen Dialog 16 (aus Paket 59): u. a. „Index-Datenbank nicht verfügbar“ beim Start (18: dazu die Mitteilung, braucht nur die macOS-Erlaubnis). Welche Stellen heute eigene Alerts haben, im Status auflisten und auf 16 umstellen.
  - 14 Indizierungsfehler laut 14.01–14.04 (Ort, Drosselung höchstens dreimal pro Stunde und Medium, Schließen-Bedingungen, Grund-Zeile a–h, unbekannter Grund ohne Zeile) gegen die App prüfen und angleichen.
  - 15 Absturzbericht: Icon rot.
  - 18: alle Mitteilungen laut Liste (Titel immer „Disk Archive“ außer Nr. 12, Bedingungen, Schalter); im Status jede Abweichung nennen.
  - **Test:** 16 für Datenbank; 14-Drosselung; Mitteilungstexte gegen 20. Sabotage-Patch, wo Verhalten sich ändert.
  - **Status:**
