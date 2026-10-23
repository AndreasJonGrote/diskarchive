# Konzept: Architektur (Aufbau der Software)

Teil des Konzepts, ausgelagert aus [README.md](../README.md) am 23.10.2026 (gilt unverändert; bei Widerspruch zum Layout gilt das Konzept, außer reine Optik).

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

## Invarianten (Host 23.10.2026, aus den Fehlern der Pakete 13–16)

Gelten für jeden neuen Code; eine Vorgabe, die dagegen verstößt, ist ein Fehler im Auftrag („Frage:“).

1. **Im Zweifel behalten.** Gelöscht oder als entfernt markiert wird nur mit positivem Beleg. Nicht gelesen, Lesefehler, Zeitüberschreitung oder fehlender Vorab-Wert heißt: den alten Eintrag (samt Favorit) bis zum nächsten Lauf behalten. Davon unberührt: Eine *unklare Zuordnung* wird nicht verknüpft („im Zweifel Löschen plus Neu“ oben betrifft nur das Verknüpfen).
2. **Kein Medienzugriff in einer Schreibtransaktion.** Erst lesen, dann schreiben. Was außerhalb gelesen wurde, ist nur ein Vorschlag; die Transaktion prüft gegen den aktuellen Stand und behandelt Fehlendes nach 1.
3. **Jeder Medienzugriff hat eine Zeitgrenze.** Nach der ersten Zeitüberschreitung überspringt der Lauf weitere Zugriffe auf dieses Medium; es bleiben keine blockierten Threads zurück.
4. **Lauf-Zustand erst nach dem letzten Schreiben freigeben** (Token, Merker, eingefügte IDs). Ein zweiter Lauf desselben Mediums startet nicht, solange der erste noch schreibt.
5. **Nur auf eigene Ereignisse reagieren.** Ansichten und Aufträge reagieren auf Ereignisse ihres Mediums und Ordners, nie auf globale Zähler; eine Nutzeraktion (Scrollen, Auswahl) wird nur durch den Nutzer oder eine Änderung genau ihres Ziels beendet.
6. **Gespeicherte Daten enthalten Reste.** Protokoll, Absturzdatei, Merker und Caches enthalten frühere Läufe und andere Medien; jede Auswertung grenzt auf den richtigen Lauf bzw. das richtige Medium ein.
7. **Protokoll und Bericht ohne Namen, Pfade und Fehlertexte** (`DiskIndexLog.errorSummary`).

**Messwerte und Spike-Ergebnisse:** `archiv/readme-technik-bis-2026-10-04.md`.
