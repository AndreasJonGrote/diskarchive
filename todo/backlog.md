# Backlog (nicht freigegeben, der Worker arbeitet nicht daran)

Ausgelagert aus TODO.md am 23.10.2026, nach Zielversion. Index: [TODO.md](../TODO.md). Versionsplan: README „Roadmap“, ausführlich [ROADMAP.md](../ROADMAP.md).

---

### 0.4.0 / 0.4.1 — Open Beta (Nutzer 18.10.: 0.4.0 Release-Kandidat, 0.4.1 Release)

| Kennung | Inhalt |
|---|---|
| `todo.0.4.020` | **verschoben nach 1.0 (Nutzer 18.10.):** Signatur mit Developer ID und Notarisierung erst zu 1.0. Alle Beta-Versionen gehen ohne Notarisierung (mit Quarantäne-Merkmal) an den kleinen Kreis der Tester; siehe `todo.0.4.021` (Anleitung) und `todo.0.4.040` (Prüfung). |
| `todo.0.4.021` | **Zielversion 0.4.1.** **Download-Seite** auf `https://diskarchive.app/` mit stabilem Link (Nutzer). **Pflicht (Nutzer/Host 18.10.):** kurze Anleitung für die nicht notarisierte Beta: (1) App aus dem Download in „Programme“ ziehen (sonst startet macOS sie von einem zufälligen Pfad, App-Translocation), (2) öffnen, (3) unter Systemeinstellungen → Datenschutz & Sicherheit „Trotzdem öffnen“ (seit macOS 15 reicht Rechtsklick → Öffnen nicht mehr). |
| `todo.0.4.022` | **Zielversion 0.4.1.** **Laufzeittest auf macOS 14** (z. B. VM); `pointerStyle` und `CGSize: Hashable` brauchen einen Ausweichweg. |
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
| `todo.0.4.1.001` | **DMG zum Herunterladen mit Hintergrundbild, ein Befehl (Nutzer 18.10.; verschoben auf 0.4.1, vorher `todo.0.4.041`).** **Auftrag „Erstelle nun das Ausgabe-DMG“** = ein Agent führt `Werkzeuge/dmg-erstellen.sh` aus, sonst nichts. Das Skript: (1) baut die Release-App selbst in einen festen Ordner (kein Suchen in DerivedData), (2) liest die Version aus `CFBundleShortVersionString`, (3) erzeugt das DMG mit **dmgbuild** (schreibt die Fenster-Einstellungen direkt, steuert den Finder nicht, Regel 19/21): App, symbolischer Link auf `/Applications`, Hintergrundbild @1x/@2x, feste Fenstergröße und Symbolpositionen aus `Werkzeuge/dmg/dmg-einstellungen.json`, (4) legt `Disk-Archive-<Version>.dmg` ins Git-Hauptverzeichnis (gleiche Version wird ersetzt), (5) prüft ohne Finder (`hdiutil attach -nobrowse`, Inhalt auflisten, aushängen) und meldet Pfad und Größe. Kein automatischer Lauf nach jedem Build. `*.dmg` in `.gitignore`. **Voraussetzung:** Layout-Seite `layout/DMG.dc.html` vom Nutzer mit Hintergrund (`dmg-background`, z. B. 660 × 400 pt) und zwei markierten Platzhaltern `dmg-app` und `dmg-applications`; der **Host** liest die Mittelpunkte aus und schreibt `dmg-einstellungen.json` (bei Layout-Änderung nachziehen), exportiert das Hintergrundbild als PNG @1x/@2x. Hinweis im Bild: Pfeil „in Programme ziehen“ und „Beim ersten Öffnen: Systemeinstellungen → Datenschutz & Sicherheit → Trotzdem öffnen“ (Beta ohne Notarisierung). Ansicht prüft der Nutzer. Freigabe durch den Host, sobald die Layout-Seite vorliegt. |

| `todo.0.4.1.002` | **Tester-Prüfung mit Quarantäne (aus `todo.0.4.040` gelöst, Nutzer 18.10.):** die nicht notarisierte App mit Quarantäne-Merkmal auf einen Mac bringen, der sie noch nie gesehen hat (oder Benutzerkonto ohne Vorgeschichte); prüfen: Gatekeeper-Freigabe nach Anleitung, Start aus „Programme“ (keine App-Translocation), Einzelinstanz, Start beim Anmelden (`SMAppService`), Update durch Ersetzen (`todo.0.4.024`), Fehlerbericht senden. |

Zu 0.4.1 gehören außerdem `todo.0.4.021` (Download-Seite mit Anleitung), `022` (macOS 14) und `024` (Update durch Ersetzen). Mit 0.4.1 geht die App an die Tester.

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

Entfallen: T2 „Programme als Dateityp“ (erledigt in 233: `.app`, `.dmg`, `.pkg`); Signatur/Notarisierung stand im alten Backlog bei 1.0, gilt laut README aber als Voraussetzung von 0.4 (`todo.0.4.020`).
