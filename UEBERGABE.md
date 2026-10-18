# UEBERGABE.md — Übergabe an einen neuen Host (Stand 18.10.2026, 11:45)

**Diese Datei ist flüchtig.** Der neue Host liest sie als Erstes, prüft sie gegen das Repository, übernimmt den Stand und **löscht sie dann** (der Nutzer committet die Löschung). Alles Dauerhafte steht in den festen Dateien (siehe unten). Grund (Nutzer 18.10.): Host und Worker wechseln auf einen anderen Rechner und haben das Wissen der bisherigen Chats nicht; es darf weder Daten- noch Wissensverlust geben.

---

## 1. Was du bist und was du zuerst liest

- Du bist **Host** (Rolle laut [AGENTS.md](AGENTS.md)): Konzept, Aufgaben, Prüfung, Abnahme, Pflege von TODO.md, DONE.md, PROMPT.md, README, ROADMAP. **Du änderst keinen Quellcode im Xcode-Projekt und nutzt Git nur lesend.** Committen tut nur der Nutzer (GitHub Desktop).
- Lesereihenfolge: (1) diese Datei, (2) [AGENTS.md](AGENTS.md), (3) [archiv/abnahme-ablauf.md](archiv/abnahme-ablauf.md) – besonders **Abschnitt 7 „Ablauf je Paket“** (so wird seit dem 17.10. geprüft), (4) [TODO.md](TODO.md): Regeln 1–31 und Abschnitt A, (5) [PROMPT.md](PROMPT.md) (aktueller Auftrag an den Worker), (6) [README.md](README.md) Abschnitte „Roadmap“ und „Datenbank“, (7) Ende von [DONE.md](DONE.md).
- Mit dem Nutzer: **Deutsch, kurz, geordnet**, Tabellen für Prüfergebnisse; jede Antwort, die Dateien ändert, endet mit **einer Commit-Nachricht** im Codeblock. Produktentscheidungen fragt man den Nutzer (mit Empfehlung), technische Fragen des Workers entscheidet der Host selbst und schreibt die Entscheidung in die Aufgabe.

## 2. Wo das Projekt steht

| Version | Stand |
|---|---|
| 0.3.8 | abgenommen (17.10.) |
| 0.3.9 | abgenommen (18.10.); **die App meldet 0.3.9** |
| **0.4.0** | **Release-Kandidat der Open Beta** (Nutzer 18.10.): nur, was die App fehlerfrei macht. Pakete 9 und 10 abgenommen (bis auf `bug.0.4.077`), **Paket 11 freigegeben, noch nicht begonnen**. Danach Abnahmerunde des Nutzers (`todo.0.4.040`). |
| 0.4.1 | Release der Open Beta: Auslieferung (Download-Seite mit Anleitung `todo.0.4.021`, macOS 14 `022`, Update durch Ersetzen `024`, DMG `todo.0.4.1.001`, Tester-Prüfung mit Quarantäne `todo.0.4.1.002`) |
| 1.0 | Signatur mit Developer ID und Notarisierung (`todo.0.4.020`, verschoben) |

**Letzte Host-Prüfung (Paket 10, 18.10. 11:02–11:19):** Debug mit Testziel und Release 0 Warnungen, seriell **866/866**, parallel **3 von 3**, keine neuen `.ips`, Regel 23 erfüllt. Abgenommen: `bug.0.4.072`–`076`, `todo.0.4.023`.

**Der Commit mit dieser Datei enthält:** den abgenommenen Code von Paket 10 und den **gemessenen Zwischenstand von `bug.0.4.077`** (Migration `0.4.0-items_search_natural`, natürliche Sortierung in SQL, Tests `NaturalSearchOrderTests`, Messwerkzeug `NaturalOrderIndexMeasurementTests` nur mit `DISKINDEX_MEASURE=1`). Alle Tests waren damit grün.

## 3. Was als Nächstes passiert

1. **Worker** (neuer Agent auf dem neuen Rechner, Rolle „Worker“ laut AGENTS.md): arbeitet [PROMPT.md](PROMPT.md) ab = **Paket 11** (`bug.0.4.077` Nacharbeit, `078`, `079`, `080`). Der Prompt ist vollständig, der Worker braucht kein weiteres Wissen.
2. **Host (du):** wartet auf „Erledigt (Bereit zur Prüfung)“ in PROMPT.md (15-Minuten-Prüfung, siehe Ablauf Abschnitt 7) und prüft dann nach dem Ablauf. Besonders bei Paket 11:
   - `bug.0.4.077`: **Abnahme nur, wenn die neue Messung höchstens +10 % Indizierzeit zeigt** (Release, ≥ 1 Mio. Einträge, je 3 Läufe im Wechsel, Median). Die Größe (+15 %, ~36 MB je Mio.) hat der Nutzer akzeptiert. Alte Messung: 29,97 → 36,10 s (+20,5 %), 238,0 → 274,6 MB. Bleibt die Zeit über 10 %, dem Nutzer die neuen Zahlen vorlegen und entscheiden lassen (Optionen damals: so übernehmen, alten Index ersetzen, verzichten).
   - `bug.0.4.078` ist Datenschutz (Schwärzung im Fehlerbericht) – vor der Beta zwingend.
3. **Nach Abnahme von Paket 11** ist der Code von 0.4.0 fertig. Dann dem Nutzer eine **kurze Checkliste für seine Abnahmerunde** (`todo.0.4.040`) schreiben: 2-Mio-HTML-Platte (vorher **alle Medien neu indizieren**, siehe 5.), Stick (großer Ordner, Pfeiltasten, Mehrfachauswahl, Rechtsklick, ab- und anstecken, Live-Änderung, Rückfrage „Ersetzt dieses Medium?“ samt Texten, Umbenennen eines Volumes), Layout-Durchgang aller Ansichten gegen `layout/`. **Der Nutzer hat vor dem 21.10. keine Festplatten**; die Runde liegt danach.

## 4. Entscheidungen vom 17./18.10. (alle in den festen Dateien, hier nur zur Orientierung)

- Rollen hängen an der Übergabe (Host/Worker), nicht am Agenten (AGENTS.md). Regel 31: Worker prüft jede Aufgabe mit einem Subagenten und darf am Ende einmal selbst korrigieren (TODO.md).
- Stick-Test je Sprung entfällt; gesammelt in der Abnahmerunde 0.4.0 (`todo.0.4.040`), danach erst Auslieferung (0.4.1).
- Datenbank: **„Erweitern statt aktualisieren“** (README, Abschnitt „Datenbank“) – neue Schlüssel oder neue Tabellen, nie Umbau; kein Fenster „Datenbank wird aktualisiert“ (`todo.0.4.025` entfällt).
- Lizenz 0.9: **Basic (1) / Pro (50) / Max (250) Medien**; ab Pro **Verschlagwortung auf dem Gerät** mit Apples Bordmitteln im Leerlauf, ohne Cloud und ohne API-Schlüssel; Systemvoraussetzungen (Grundfunktion ab macOS 14, Sprachmodell ab macOS 26 mit Apple-Chip) müssen in der Lizenzbeschreibung stehen (ROADMAP 0.9).
- Ideensammlung nach 1.0 in ROADMAP (zurzeit leer).
- Falsche Dateigrößen in alten Indizes (`bug.0.4.055`): keine automatische Umstellung, der Nutzer indiziert neu.

## 5. Neuer Rechner – was zu beachten ist

- **Alles Nötige liegt im Repository** (Code, Tests, Layout, Konzept, Archiv, `Package.resolved` für GRDB). Außerhalb liegt nichts Projektrelevantes (`.claude/` enthält nur eine Sperrdatei; das Gedächtnis des alten Claude-Clients ist für das Projekt ohne Belang).
- **Xcode:** Falls `xcodebuild` nicht aktiv ist: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (nichts am System ändern). Beim ersten Bauen lädt Xcode GRDB nach `Package.resolved`.
- **Signatur:** Das Projekt signiert automatisch mit dem Team `KATFD9R38G` (Apple Development). Auf dem neuen Rechner muss Xcode mit diesem Apple-Account angemeldet sein, sonst Tests mit `CODE_SIGN_IDENTITY="-"` bauen (Regel 29); die App des Nutzers (Regel 23) braucht das Zertifikat.
- **DerivedData-Pfad** ändert sich je Rechner; der Ablauf findet ihn per `ls -d ~/Library/Developer/Xcode/DerivedData/diskindex-*/…`.
- **Daten des Nutzers** (Index unter `~/Library/Application Support/Disk Archive`, Protokoll unter `~/Library/Logs/Disk Archive`) ziehen **nicht** mit um und müssen es nicht: Die Medien werden ohnehin neu indiziert. Die erste gebaute App legt dabei den Index aus `bug.0.4.077` an.
- **Werkzeuge der Agenten:** Gibt es auf dem neuen Client keine geplanten Prüfungen oder Subagenten, dann: der Nutzer meldet „Worker fertig“, und der Host prüft den Code selbst nach den Punkten aus Abschnitt 7.3 (lieber in mehreren Durchgängen je Aufgabe).

## 6. Zum Schluss

Wenn du alles gelesen und gegen das Repository geprüft hast (stimmen Commit, PROMPT.md und TODO.md überein?), **lösche diese Datei** und sage dem Nutzer, dass die Übergabe übernommen ist; gib ihm dafür eine Commit-Nachricht („Übergabe übernommen, UEBERGABE.md gelöscht“). Danach normal weiterarbeiten.
