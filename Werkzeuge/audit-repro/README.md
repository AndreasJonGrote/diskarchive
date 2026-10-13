# audit-repro — Repro-Tests zum Zwischen-Audit „claude seitenweise“ (13.10.2026)

`ReproAuditTests.swift` stellt elf Befunde aus [REPORT.md](../../REPORT.md) als ausführbare Tests nach (Abschnitte „Audit 13.10.2026“ und „Zweitprüfung 13.10.2026“). Jeder Test erwartet das **korrekte** Verhalten. Er ist also **rot, solange der Defekt besteht**, und wird grün, sobald er behoben ist.

| Test | REPORT-Nr. | Aufgabe in [todo-audit.md](../../todo-audit.md) |
|---|---|---|
| `nr57_moveIntoFolderWithSameNamedFileNeverFails` | 57 | ZA-06 |
| `nr57_deletedTargetNameBecomesGone` | 57 | ZA-06 |
| `nr58_pendingFinishKeepsGoneRowsAndFavorites` | 58 | ZA-04 |
| `nr59_pausedReconcileDoesNotSkipLayersOnNextRun` | 59 | ZA-04 |
| `nr67_failedBeginIndexingLeavesNoToken` | 67 | ZA-04 |
| `nr56_liveRenameWithUnknownParentLeavesRootAlone` | 56 | ZA-07 |
| `nr70_deleteAndCreateOtherFileDoesNotMoveFavorite` | 70 | ZA-07 |
| `nr69_folderMovedByFileIDShiftsDescendantDepths` | 69 | ZA-06 |
| `nr66_deferredFlushRunsAfterIndexingEnds` | 66 | ZA-09 |
| `nr99_concurrentDirectoryBatchesKeepCountsExact` | 99 | ZA-09 |
| `nr60_yesAfterNoStartsANewRun` | 60 | ZA-17 |

**Stand 13.10.2026, Commit `76b6a71`:** gegen den unveränderten Code 11/11 rot. In einer Kopie mit den vorgeschlagenen Korrekturen 11/11 grün (Gegenprobe).

## Benutzung

- **Diese Datei ist eine Vorlage und liegt absichtlich nicht im Xcode-Projekt.** Sie wird hier nicht geändert.
- **Übernahme durch den Umsetzer, je Aufgabe:** Den passenden Test in eine Suite unter `diskindex/diskindexTests/` übernehmen. Das Testziel nutzt einen synchronisierten Ordner, eine Änderung am pbxproj ist nicht nötig. Den Test **vor** dem Fix laufen lassen (rot = Beleg), danach grün. Die Suite braucht `@Suite(.serialized) @MainActor`, die Tests nutzen die vorhandenen Hilfen (`StoreHarness`, `ScanHarness`, `MemoryVolume`, `watchRig`, `MapAccess`, `TestDatabase`, `waitUntil`).
- **Nur nachstellen, ohne das Projekt zu ändern:** Das Projekt per `rsync` in einen Arbeitsordner außerhalb des Repos kopieren, die Datei nach `diskindexTests/` der Kopie legen und dort ausführen:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project diskindex.xcodeproj -scheme diskindex -destination 'platform=macOS' -derivedDataPath <eigener-Ordner> -only-testing:diskindexTests/ReproAuditTests
```

- **Fehlermeldungen** stehen im Ergebnisbündel, nicht im Konsolenlog: `xcrun xcresulttool get test-results tests --path <…>.xcresult`.
