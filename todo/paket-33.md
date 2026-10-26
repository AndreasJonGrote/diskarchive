# Paket 33 — Zielversion 0.4.0 (freigegeben 26.10.2026)

Index: [TODO.md](../TODO.md). Regeln: [todo/regeln.md](regeln.md) (15 Regeln; Invarianten in `konzept/architektur.md`). Maßstab: [konzept/architektur.md](../konzept/architektur.md), Absatz „Speicherung“ (ein Ordner). Volltexte und Abnahme von Paket 32: [archiv/paket-32-abgenommen-2026-10-26.md](../archiv/paket-32-abgenommen-2026-10-26.md).

**Für jede Aufgabe gilt:**
- Der Test ist vor dem Fix rot (im Status belegen) und danach grün.
- **Sabotage als Patch** unter `todo/sabotage/` (Regel 9).
- Selbstprüfung mit den fünf Fragen (Regel 12).
- Zeilenangaben sind Richtwerte (Regel 3).

**Reihenfolge (HALT am Ende):** `bug.0.4.208` a → e. **HALT.**

## Umbau „ein Ordner“ (Nutzer 26.10., über den Supervisor: vor der Abnahmerunde, vor allem anderen)

- **bug.0.4.208 — Alles von Disk Archive in einen Ordner; Tests schreiben nichts nach `~/Library/Preferences` (hoch).**
  - **Anlass:** Jeder Testprozess legt heute eine `UserDefaults`-Suite `app.diskarchive.tests.<pid>[.<Name>-<uuid>]` an (`AppDefaults.current`, `TestDefaults.make`, dazu eigene Suiten in einzelnen Tests). Das läuft über `cfprefsd`. Die Testläufe haben den Einstellungsdienst aller Apps überlastet: WhatsApp, Mail und Finder haben ihre Anzeige-Einstellungen verloren. Außerdem liegt das Protokoll in `~/Library/Logs/Disk Archive/`, und `WriteGuard` erlaubt ganz `~/Library/Preferences` und ganz `~/Library/Caches`.
  - **Ziel** (Konzept „Speicherung“): Alles liegt in `~/Library/Application Support/Disk Archive/`:
    - `archive.sqlite`
    - `app-state.plist`
    - `Logs/` (Protokoll `diskindex.log` und `crash-last.txt`)
    - `outbox/`

    Einzige Ausnahme ist, was macOS in `app.diskarchive.plist` führt: `AppleLanguages` und die Fensterposition.

  - **a) Ein Speicher für den App-Zustand statt `UserDefaults`.**
    - Heute liegen in `AppDefaults.current` diese Schlüssel: `diskindex.globalPause`, `diskindex.failureModalCounts`, `diskindex.noticePermissionAsked`, `lastIntegrityCheck`, `diskindex.pruneAt` und `diskindex.displayLanguage`. Sie kommen in einen eigenen Speicher, z. B. `AppStateStore`. Er hat eine schmale Schnittstelle (`data`, `bool`, `date`, `string`, `set`, `remove`), so viel, wie die heutigen Aufrufer brauchen.
    - Es gibt zwei Ausführungen:
      - **App:** die Datei `app-state.plist` im Datenordner. Sie wird synchron gelesen (sie wird vor der Datenbank gebraucht, z. B. für die Sprache beim Start) und atomar geschrieben, Rechte 600, nur über `WriteGuard`. Lesefehler ergeben einen leeren Zustand und eine Protokollzeile, keinen Absturz.
      - **Tests:** im Speicher, je Instanz.
    - Alle Parameter `defaults: UserDefaults` dieser Aufrufer werden zu diesem Speicher: `AppState+Pause`, `AppState.init`, `StartupSequence`, `StoreLaunchSequence`, `NoticePermission`, `PauseDurationMenu`, `IssueTracker`, `AppLanguagePolicy`, `AppSettingsRuntimeCache`.
    - **`UserDefaults.standard`** steht danach nur noch an **einer** Stelle der App, z. B. `SystemDefaults.swift`: `AppleLanguages` setzen und `NSQuitAlwaysKeepsWindows` registrieren (`register` schreibt keine Datei). Die Fensterposition schreibt macOS selbst. Unter Tests schreibt diese Stelle nichts.
    - **Kein Übernehmen alter Werte** (keine Datenvorsicht bis 1.0, AGENTS.md):
      - Der Legacy-Import aus `UserDefaults` entfällt: `PersistedAppSettings.loadLegacyPersisted`, `IssueConsent.legacyAutoSendKey`, `AppSettings.load(from:)` und `save(to:)`, soweit nur dafür da, samt ihrer Tests.
      - Die App entfernt beim Start **einmal** ihre alten Schlüssel aus `app.diskarchive.plist` (nicht unter Tests). Das sind die sechs oben plus `diskindex.appSettings` und `diskindex.autoSendCrashReports`.
  - **b) Tests ohne `UserDefaults`.**
    - `TestDefaults.make` und alle Tests mit `UserDefaults(suiteName:)` oder `UserDefaults.standard` nehmen den Speicher im Speicher. Betroffen sind u. a.:
      - `AppSettingsPersistenceTests`
      - `AppLanguagePolicyTests`
      - `PauseExpiredAtLaunchTests`
      - `IssueReportRealLogTests`
      - `AppDefaultsTests`
      - `CrashWriterSafetyTests`
      - `IndexPruneTests`
      - `RunLifecycleTests`
      - `StartupSequenceTests`
      - `PauseNoticeTextTests`
      - `IndexFailureReasonTests`
      - `ArchiveDatabaseStartupTests`
    - Tests der Dateiausführung schreiben in einen Ordner unter `$TMPDIR`.
    - `AppDefaults` mit `removeStaleTestDomains`, `testDomainPrefix`, `legacyTestPrefixes` und `AppDefaultsCleanupTests` entfällt. Die Reste löscht der Nutzer einmal (Checkliste „Vorher 1“).
    - Kein Test schreibt in den echten Datenordner.
  - **c) Protokoll in den Datenordner.**
    - `DiskIndexLog.defaultDirectory` wird zu `Disk Archive/Logs/`, dort liegen auch `crash-last.txt` und die Rotation.
    - Alle Stellen, die den Pfad nennen, ziehen mit: Fehlerbericht (`logTail`), Absturzdialog, „Protokoll im Finder zeigen“ (falls vorhanden), Texte.
    - Den alten Ordner `~/Library/Logs/Disk Archive/` fasst die App nicht an (der Nutzer löscht ihn, Checkliste).
  - **d) Schreibschranke enger.**
    - `WriteGuard.allowedRoots` enthält nur noch den Datenordner und `NSTemporaryDirectory()`.
    - `~/Library/Preferences`, `~/Library/Caches` und `~/Library/Logs` fallen weg.
    - Der Ausweichweg der Outbox nach `NSTemporaryDirectory()/diskindex-outbox` bleibt nur, wenn der Datenordner nicht anzulegen ist (Protokollzeile).
  - **e) Wächter-Test über den Quelltext** (wie der Wächter von `todo.0.4.014`), z. B. `OneFolderGuardTests`:
    1. In `diskindexTests/` kommt `UserDefaults` nicht vor (Kommentare ausgenommen).
    2. In `diskindex/` steht `UserDefaults` nur in der einen Ausnahmedatei aus a.
    3. `WriteGuard.permitsWrite` ist falsch für `~/Library/Preferences/x.plist`, `~/Library/Caches/x` und `~/Library/Logs/x`. Für `…/Disk Archive/app-state.plist` und `…/Disk Archive/Logs/diskindex.log` ist es wahr.
    4. Das Standardverzeichnis des Protokolls liegt im Datenordner.

    Dazu ein Rundlauf: Pause setzen, neuen Speicher auf dieselbe Datei öffnen, die Pause ist da. Eine kaputte Datei ergibt einen leeren Zustand. **Gegenprobe zuerst:** Der Rundlauf liest einen gesetzten Wert positiv.
  - **Patches (rot erwartet):**
    1. `bug.0.4.208-a.patch`: Der Testspeicher nimmt wieder `UserDefaults(suiteName:)`. Der Wächter e1 wird rot.
    2. `bug.0.4.208-b.patch`: `WriteGuard` erlaubt wieder `~/Library/Preferences`. e3 wird rot.
    3. `bug.0.4.208-c.patch`: Das Protokoll liegt wieder in `~/Library/Logs/Disk Archive`. e4 wird rot.
    4. `bug.0.4.208-d.patch`: Die Dateiausführung schreibt nicht (`set` ohne Speichern). Der Rundlauf wird rot.
  - **Abnahmekriterium:** Nach dem Gesamtlauf gibt es keine neue Datei `app.diskarchive.tests.*` (und keine `*diskindex*`) in `~/Library/Preferences`. `Werkzeuge/pruefung.sh voll` meldet „Neue Dateien in ~/Library/Preferences seit Start: 0“. Belege das im Status mit deinem eigenen Lauf, gezählt mit `find ~/Library/Preferences -maxdepth 1 -newer <Startmarke> …`.
  - **So lassen:**
    - Gefälschte Medien und Testdatenbanken der Tests bleiben unter `$TMPDIR` (sie sind keine Daten der App).
    - Die Tabelle `settings` bleibt, wie sie ist.
    - `AppleLanguages` bleibt in `app.diskarchive.plist`.
  - **Status:** _(Worker)_

**Paketende:**
- 0 Warnungen in Debug und Release.
- Alle Suites grün, die Suites mit geändertem Speicher 20× parallel grün. Rote Läufe zählen auch, wenn nur das Protokoll sie zeigt.
- Alle Patches unter `todo/sabotage/` rot.
- App des Nutzers gebaut. Kurz von Hand starten:
  - `app-state.plist` und `Logs/diskindex.log` entstehen im Datenordner.
  - In `~/Library/Logs/Disk Archive/` kommt nichts Neues dazu.
- **Gesamtlauf nur auf ruhigem Rechner** (Last < 3, keine Spiele). Sonst weglassen und im Status vermerken, dann macht ihn der Host.
