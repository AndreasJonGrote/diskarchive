# Backlog (nicht freigegeben, der Worker arbeitet nicht daran)

Ausgelagert aus TODO.md am 23.10.2026, nach Zielversion. Index: [TODO.md](../TODO.md). Versionsplan: README „Roadmap“, ausführlich [ROADMAP.md](../ROADMAP.md).

---

### Sammeleintrag Stufe 2 und 3 (Nutzer 26.10., AGENTS.md „Befunde: drei Stufen“)

Befunde, die der Nutzer nur bei seltener Ereignisfolge merkt (Stufe 2, ohne Nachweis in der echten App oder in einem realistischen Test) oder nie merkt (Stufe 3). Je Befund eine Zeile: Datum, Paket, Stelle, „Nutzer sieht / Wann“. Daraus wird keine Aufgabe, es sei denn, die echte App zeigt den Fehler; dann Stufe 1.

| Datum | Paket | Stufe | Stelle | Nutzer sieht / Wann |
|---|---|---|---|---|
| 26.10. | 32 | 3 | `ChangeWatcher.handleStreamUnmount`, Prüfung am Anfang | nichts; Schutzprüfung ohne Test, praktisch unerreichbar |
| 26.10. | 33 | 3 | `FilePrivacy`, erstes Anlegen von `Logs/` | nichts; 755/644 bis zum nächsten Start, danach 700/600 (schon vorher so) |
| 26.10. | 33 | 3 | `AppStateStore`, Doppelstart im selben Moment | nichts; die zweite Instanz übergibt und beendet sich |
| 27.10. | Abnahmerunde (Supervisor) | 2 | `DirectoryIndexer`, `parentsFor` + `readFolderWithRetry` | Wird ein schon indizierter Ordner nachträglich gesperrt, liest jeder Lauf auch alle alten Unterordner einzeln, mit je ~14 s Wartezeit. Der Lauf dauert dann lange; nur bei nachträglich gesperrten Ordnern → **Paket 49, `bug.0.4.235` (Nutzer 29.10.)** |
| 27.10. | 35 | 2 | `MediumCoordinator`, App-Start mit zwei gleichnamigen Medien (eines neu) | Wird das neue vor dem bekannten verarbeitet, zählt das bekannte noch als offline: Rückfrage „Ersetzt …?“ zu einem angeschlossenen Medium. Nur beim Start mit beiden Medien zugleich, nicht beobachtet → **Paket 48, `bug.0.4.233`** |
| 27.10. | 35 | 2 | `MediumCoordinator.requestDialog`, „Behalten“ nicht gemerkt | Nach „Behalten“ und ohne Antwort im Erkennungsdialog kommt beim nächsten Anschließen wieder die Rückfrage statt des Erkennungsdialogs. Nur, wenn der Nutzer den Erkennungsdialog offen lässt → **Paket 48, `bug.0.4.232`** |
| 27.10. | 36 | 2 | `ColumnBrowserState.pathStack.didSet` (Breite je Spalte nach Namen) | Benennt der Nutzer einen geöffneten Ordner im Finder um, fällt die gezogene Breite der Spalte rechts davon weg (wieder 230 pt). Nur nach Ziehen und Umbenennen von außen → **Paket 48, `bug.0.4.234`** |
| 28.10. | 38 | 3 | `PromptFocusStackTests`, drei Reihenfolge-Tests (`newestInFront…`, `newestStays…`) | nichts; beim Worker einmal parallel rot (00:14), nicht nachstellbar (20× parallel grün, Host-Lauf 01:05–01:35 grün) |
| 28.10. | 39 (außerhalb des Diffs) | 2 | `IndexFailureReasonTests/serviceRunPassesTheUnconfirmedReasonToTheDialog` hing einmal 120 s (Parallel 1, Host-Lauf 09:20) | Ein Lauf, dessen Medium sich am Ende nicht bestätigen lässt, hängt vielleicht, statt den Fehlerdialog zu zeigen. Nur wenn das Medium am Ende des Laufs nicht zu bestätigen ist; sonst 2 s, nie in der echten App gesehen |
| 26.10. | Abnahmerunde | 3 | `IssueTracker.noteError` bei Abbruch eines Laufs (Auswerfen, Umbenennen) | nichts; `CancellationError` steht als „app error index error category=store“ im Protokoll |
| 28.10. | 40 (Host) | 3 | `PartialChecksum.computeOffActor` gibt nach 5 s auf, das Lesen läuft im Hintergrund weiter; auf „Daten I“ stapelten sich Lese-Threads (Invariante 3) | nach `bug.0.4.225` nichts, weil kaum noch gelesen wird; Favorit auf einer hängenden Platte |
| 28.10. | 40 (außerhalb des Diffs) | 2 | `SlowVolumeMountTests/mountWithNonStandardPathIsAbandonedByStandardUnmount` rot in Parallel 3 (Rechner belastet, 12 statt 5,5 min) | nichts in der App nachgewiesen; Zeittest mit 0,3 s/8 s unter Last |
| 29.10. | 45 | 2 | `IndexStoreV3.goneNamesMovedOutDuringRun` (nur im Speicher) | Bricht ein Lauf mitten im Lesen eines verschobenen Ordners ab (Abziehen), kennt der Folgelauf die schon einzeln geholten Namen nicht: Ordner gilt als neu, Favorit darauf weg (vor Paket 45 immer so) |
| 29.10. | 46 | 3 | `IndexingVolumeTuning.isRotational` | Liest „Media Solid State“ aus DiskArbitration, den es dort nicht gibt; USB-SSDs wie „Daten I“ werden deshalb mit 1 statt 4 parallelen Lesevorgängen gelesen. Kein Fehler (Abgleich 1 min 14 s); auf die neue Angabe aus `bug.0.4.230` umstellen frühestens 0.4.1, mit Messung → **Paket 47, `todo.0.4.051` (Nutzer 29.10.)** |
| 29.10. | 46 | 2 | `MediumCoordinator`, Zweig `denied` (bekanntes Medium ohne Zugriff) | Zeigt bis zur Freigabe noch den alten Typ (z. B. HDD statt SSD). Nur bei Medien ohne Zugriffsrecht, erstes Anstecken nach dem Update → **Paket 47, `bug.0.4.231`** |
| 30.10. | 48 | 3 | `AppState.keptReplaceMediumPairs` | nichts; je „Behalten“ eine Zeile im App-Zustand, nie aufgeräumt (auch nach dem Vergessen eines der beiden Medien) |
| 29.10. | Audit (Host) | 3 | `Assets.xcassets`: `NavCaretRight`, `NavHouseLineDuotone`, `IconCircleDashed` ungenutzt (laut `Resources/Icons/ICON_STRATEGY.md` Vorrat für später) | nichts; einige KB im Bundle. Sonst: alle Testhaken unter `#if DEBUG`, kein `print`, keine liegengebliebenen Dateien, Prüfordner 3 × zusammen 7 MB |

---

### 0.4.0 / 0.4.1 — Open Beta (Nutzer 18.10.: 0.4.0 Release-Kandidat, 0.4.1 Release)

| Kennung | Inhalt |
|---|---|
| `todo.0.4.020` | **verschoben nach 1.0 (Nutzer 18.10.):** Signatur mit Developer ID und Notarisierung erst zu 1.0. Alle Beta-Versionen gehen ohne Notarisierung (mit Quarantäne-Merkmal) an den kleinen Kreis der Tester; siehe `todo.0.4.021` (Anleitung) und `todo.0.4.040` (Prüfung). |
| `todo.0.4.021` | **Zielversion 0.4.1.** **Download-Seite** auf `https://diskarchive.app/` mit stabilem Link (Nutzer). **Pflicht (Nutzer/Host 18.10.):** kurze Anleitung für die nicht notarisierte Beta: (1) App aus dem Download in „Programme“ ziehen (sonst startet macOS sie von einem zufälligen Pfad, App-Translocation), (2) öffnen, (3) unter Systemeinstellungen → Datenschutz & Sicherheit „Dennoch öffnen“ (seit macOS 15 reicht Rechtsklick → Öffnen nicht mehr). |
| `todo.0.4.022` | **Entfällt (Nutzer 27.10.):** Mindest-macOS ist 15 (`todo.0.4.1.003`, Paket 41). Stattdessen Aufwärtstest auf dem zweiten Mac des Nutzers (macOS 27) mit dem DMG. **Prüfpunkte (Host 29.10., Release Notes macOS 27):** (1) „Beim Anmelden starten“ mit dem **heruntergeladenen** DMG (Quarantäne-Merkmal): `launchd` lädt seit macOS 27 keine plist mit Quarantäne-Merkmal mehr (166415497), unser Launch Agent liegt in `Contents/Library/LaunchAgents/app.diskarchive.plist`; abmelden, anmelden, startet die App? (2) Kontextmenüs zeigen auf 27 keine Symbole mehr (System, 170477566), kein Fehler. Sonst nichts Betroffenes: Build mit SDK 26.2 ohne Warnungen, Release universal (arm64 + x86_64), kein `UIDesignRequiresCompatibility`, kein `FileDocument`/`NSOpenPanel`/eigene `NSGestureRecognizer`. |
| `todo.0.4.023` | → Paket 10 (Abschnitt A, freigegeben 18.10.) |
| `todo.0.4.024` | **Zielversion 0.4.1 (aus Paket 10 genommen, Nutzer 18.10.).** → Paket 10 (Abschnitt A, freigegeben 18.10.) |
| `todo.0.4.040` | **Abnahmerunde des Release-Kandidaten 0.4.0 (Nutzer 17./18.10.):** erst, wenn **alles andere von 0.4.0 abgenommen** ist; nicht vorziehen. Inhalt: (1) Lauf über die große Platte des Nutzers (rund 2 Mio. HTML-Dateien): vollständig indizieren, suchen, Spaltenansicht in großen Ordnern, ab- und anstecken, Live-Änderung; Zeiten (Release-Build) und Protokoll festhalten. (2) Test am echten Stick (großer Ordner, Pfeiltasten, Mehrfachauswahl, Rechtsklick, Medium ab- und anstecken, Live-Änderung, Rückfrage „Ersetzt dieses Medium?“ samt Texten, Umbenennen eines Volumes). (3) Layout-Durchgang aller Ansichten gegen `layout/` (einschließlich `todo.0.3.2.001`).  Funde als `bug.0.4.xxx`; nach ihrer Behebung und Abnahme ist 0.4.0 der Release-Kandidat. An die Tester geht die App mit 0.4.1. Ersetzt das Kriterium 7 der Sprünge 0.3.8 und 0.3.9. |
| `todo.0.4.042` | **Erledigt (Paket 23, abgenommen 25.10.).** Alter Text: **Zielversion 0.4.0, wartet auf Layout (Nutzer 18.10.; vorher „Wartescreen der Suche“ in 0.5).** Solange eine Suche läuft (`searchState.isSearchInProgress`, auch während die Suche auf die Warteschlange nach einer Regeländerung wartet), zeigt die Suchansicht **die ganze Fläche aus Layout 10.1** (`SearchIdlePlaceholder`/`EmptyStateView`, „Suchbegriff eingeben oder Filter verwenden“) in gleicher Größe und Position, aber mit **Spinner** statt der zwei Icons und dem Titel **„Suche läuft“** (de/en; Text und genaue Darstellung laut Layout des Nutzers). Die heutige kleine Zeile mit Spinner in der leeren Tabelle (`SearchView.swift`, `placeholder`, `LayoutCopy.searchInProgress`) entfällt. Ladehinweis erst nach Verzögerung wie überall (`DelayedLoadingState`), damit schnelle Suchen nicht flackern. Bleiben Treffer der vorigen Suche stehen, bis die neuen da sind, oder zeigt jede neue Suche den Wartescreen? → im Layout entscheiden (Empfehlung Host: Wartescreen nur, wenn noch keine Treffer sichtbar sind). Fenstertest: laufende Suche → Wartescreen, danach Treffer; Pixel hell/dunkel. **Freigabe durch den Host, sobald das Layout vorliegt** (siehe „Nutzer und Host“). |
| `todo.0.4.025` | **entfällt (Nutzer/Host 18.10.):** Ein Fenster „Datenbank wird aktualisiert“ braucht es nicht. Nach dem Datenbank-Konzept wird nur erweitert (neue Schlüssel oder neue Tabellen, angelegt in Millisekunden), nie umgebaut (README, Abschnitt „Datenbank“, „Erweitern statt aktualisieren“). |
| `todo.0.4.026` | → Paket 9 (Abschnitt A, freigegeben 18.10.) |
| `todo.0.4.027` | → Paket 9 (Abschnitt A, freigegeben 18.10.) |
| `todo.0.4.028` | → Paket 9 (Abschnitt A, freigegeben 18.10.) |
| `bug.0.4.063` | → Paket 9 (Abschnitt A, freigegeben 18.10.) |
| `todo.0.4.029` | → Paket 9 (Abschnitt A, freigegeben 18.10.) |

### 0.4.1 — Release der Open Beta: Auslieferung (Nutzer 18.10.)

| Kennung | Inhalt |
|---|---|
| `todo.0.4.1.001` | **→ Paket 41 (freigegeben 28.10.; Festlegungen dort gehen vor).** **DMG zum Herunterladen mit Hintergrundbild, ein Befehl (Nutzer 18.10.; verschoben auf 0.4.1, vorher `todo.0.4.041`).** **Auftrag „Erstelle nun das Ausgabe-DMG“** = ein Agent führt `Werkzeuge/dmg-erstellen.sh` aus, sonst nichts. Das Skript: (1) baut die Release-App selbst in einen festen Ordner (kein Suchen in DerivedData), (2) liest die Version aus `CFBundleShortVersionString`, (3) erzeugt das DMG mit **dmgbuild** (schreibt die Fenster-Einstellungen direkt, steuert den Finder nicht, Regel 19/21): App, symbolischer Link auf `/Applications`, Hintergrundbild @1x/@2x, feste Fenstergröße und Symbolpositionen aus `Werkzeuge/dmg/dmg-einstellungen.json`, (4) legt `Disk-Archive-<Version>.dmg` ins Git-Hauptverzeichnis (gleiche Version wird ersetzt), (5) prüft ohne Finder (`hdiutil attach -nobrowse`, Inhalt auflisten, aushängen) und meldet Pfad und Größe. Kein automatischer Lauf nach jedem Build. `*.dmg` in `.gitignore`. **Voraussetzung:** Layout-Seite `layout/ab 0.4.2/DMG Hintergrund.dc.html` vom Nutzer mit Hintergrund (`dmg-background`, z. B. 660 × 400 pt) und zwei markierten Platzhaltern `dmg-app` und `dmg-applications`; der **Host** liest die Mittelpunkte aus und schreibt `dmg-einstellungen.json` (bei Layout-Änderung nachziehen), exportiert das Hintergrundbild als PNG @1x/@2x. Hinweis im Bild: Pfeil „in Programme ziehen“ und „Beim ersten Öffnen: Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen“ (Beta ohne Notarisierung). Ansicht prüft der Nutzer. Freigabe durch den Host, sobald die Layout-Seite vorliegt. |

| `todo.0.4.1.002` | **Tester-Prüfung mit Quarantäne (aus `todo.0.4.040` gelöst, Nutzer 18.10.):** die nicht notarisierte App mit Quarantäne-Merkmal auf einen Mac bringen, der sie noch nie gesehen hat (oder Benutzerkonto ohne Vorgeschichte); prüfen: Gatekeeper-Freigabe nach Anleitung, Start aus „Programme“ (keine App-Translocation), Einzelinstanz, Start beim Anmelden (`SMAppService`), Update durch Ersetzen (`todo.0.4.024`), Fehlerbericht senden. **Festgelegt 28.10.:** erst wenn der Nutzer 0.4.0 als Release-Kandidat bestätigt hat, setzt der Host 0.4.1 und baut das DMG; der Nutzer lädt es auf seinem zweiten Mac (macOS 27) über den Browser herunter (Quarantäne-Merkmal wie bei den Testern). Am selben Mac zugleich der Aufwärtstest: App starten, Grundfunktionen, kurzer Blick aufs Layout (Liquid Glass seit macOS 26), heißt der Knopf auch dort „Dennoch öffnen“. Checkliste wie bei `todo.0.4.040`. **Prüfpunkt Signatur (Supervisor 28.10.):** Die App ist mit „Apple Development“ signiert und trägt `get-task-allow`; im Schlüsselbund gibt es keine Developer ID. Ob „Dennoch öffnen“ damit auf einem fremden Mac (macOS 27, mit Quarantäne) überhaupt angeboten wird und die App danach startet, zeigt erst dieser Test. Klappt es nicht: Frage an den Nutzer (Ad-hoc-Signatur im Release oder Developer ID vorziehen), bevor das DMG an Tester geht. |

Zu 0.4.1 gehören außerdem `todo.0.4.021` (Download-Seite mit Anleitung), der Aufwärtstest auf macOS 27 und `024` (Update durch Ersetzen). Mit 0.4.1 geht die App an die Tester.

### Neues Layout (nach 0.4.1, Nutzer 26.10.)

| Kennung | Inhalt |
|---|---|
| `todo.0.5.003` | **Leere Spalte bei aktivem Filter (Nutzer 26.10., Abnahmerunde):** Ein Ordner, in dem der aktive Filter alles ausblendet, zeigt in der Spaltenansicht weder Inhalt noch Ladeanzeige noch Hinweis (Beispiel: großer Ordner auf „Daten“, Filter aktiv). Kein Fehler, das Verhalten ist richtig. Im neuen Layout einen Hinweis vorsehen, etwa „Filter aktiv – n Einträge ausgeblendet“ mit „Filter zurücksetzen“. Text und Gestaltung im Layout. |

### 0.5 bis 1.0 (Entwürfe, jede Funktion vor dem Start einzeln besprechen; Details ROADMAP)

- **bug.0.4.106 — Zielversion 1.0 (Nutzer 20.10.): Sicherungskopie vor einer Schema-Erweiterung.** Heute keine (`SchemaV3.swift` Z. ~102, `migrator.migrate(pool)` direkt). Jede Migration ist eine eigene Transaktion, ein Abbruch rollt zurück; die Kopie schützt nur vor einer fehlerhaften, aber erfolgreichen Migration. Vor 1.0 (nur zwei Rechner des Nutzers, keine Kunden) nicht nötig. Zu 1.0: Kopie vor jeder Migration (z. B. `VACUUM INTO` im selben Ordner, nur die letzte behalten).

| Kennung | Inhalt |
|---|---|
| `todo.0.5.001` | **Metadaten und EXIF** (Video, Foto/RAW, Audio, PDF; zweiter Durchgang nach dem Index, Markierung `_analyzed`), neue Layouts (Wartescreen der Suche → `todo.0.4.042`, vorgezogen nach 0.4.0) |
| `todo.0.5.002` | **vorgezogen als `bug.0.4.077` (Paket 10, Nutzer 18.10.).** |
| `todo.0.6.001` | **Vorschaubilder** 250 px, Abschalter global und je Medium, Dateien `Thumbnails/<storageID>/<itemID>` |
| `todo.0.7.001` | **CSV-Export** (Umfang, Spalten, Kodierung offen) |
| `todo.0.8.001` | **Duplikate** über volle Prüfsumme, nach Größe gruppiert, nur im Hintergrund |
| `todo.0.9.001` | **Lizenz** (1 / 50 / 250 Medien als Lizenzgrenze; Fragen siehe README) |
| `todo.1.0.001` | Ladehinweis erst nach 1 s (früher T1; prüfen, ob durch `DelayedLoadingState` erledigt) |
| `todo.1.0.002` | Erweiterte Dateityp-Icons (früher T3, Styleguide 15) |
| `todo.1.0.003` | Ausführliches Protokoll / Diagnose-Modus (früher T5, Vorschlag Claude, nicht freigegeben) |

Entfallen: T2 „Programme als Dateityp“ (erledigt in 233: `.app`, `.dmg`, `.pkg`); Signatur/Notarisierung: zu 1.0 (Nutzer 18.10., `todo.0.4.020`), nicht Voraussetzung von 0.4.
