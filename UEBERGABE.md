# UEBERGABE.md — Übergabe an einen neuen Host (Stand 19.10.2026)

**Diese Datei ist flüchtig.** Der neue Host liest sie als Erstes, prüft sie gegen das Repository, übernimmt den Stand und **löscht sie dann** (der Nutzer committet die Löschung). Alles Dauerhafte steht in den festen Dateien (siehe 1.). Grund der Übergabe (Nutzer 19.10.): Hostwechsel; der bisherige Host prüft Paket 12 **nicht** mehr, das macht der neue Host.

**Hostwechsel kommen immer wieder vor.** Der Nutzer kommt irgendwann auf den Host zu und bittet um eine Übergabe (anderer Rechner, anderer Client, volle Sitzung). Dann: nichts mehr prüfen, die festen Dateien auf Stand bringen, eine neue `UEBERGABE.md` nach dem Muster dieser Datei schreiben und eine Commit-Nachricht vorschlagen, die auf sie hinweist (AGENTS.md, Abschnitt „Übergabe“).

---

## 1. Rollen und was du zuerst liest

- **Du bist Host** (AGENTS.md): Konzept, Aufgaben, Prüfung, Abnahme; du pflegst `TODO.md`, `DONE.md`, `PROMPT.md`, `README.md`, `ROADMAP.md`, `AGENTS.md`, `archiv/`. **Du änderst keinen Quellcode im Xcode-Projekt** und nutzt Git **nur lesend** (`status`, `log`, `diff`, `show`). Commits macht nur der Nutzer (GitHub Desktop).
- **Der Worker** (ein anderer Agent, Rolle laut Übergabe des Nutzers) setzt nur um, was in `PROMPT.md` steht, füllt nur die Felder „Status“ in `TODO.md` (Regeln 1–31 oben in `TODO.md`) und ersetzt am Ende `PROMPT.md` durch „Erledigt (Bereit zur Prüfung): … Offen/blockiert: … HALT.“. Er nimmt nie selbst ab.
- **Lesereihenfolge:** (1) diese Datei, (2) `AGENTS.md`, (3) `archiv/abnahme-ablauf.md` – vor allem **Abschnitt 7 „Ablauf je Paket“**, **8 „Werkzeuge und Erfahrungen“**, **9 „Schleifen“**, (4) `TODO.md`: Regeln 1–31, Abschnitt A (Stand-Zeile, Paket-Tabelle, Prüfstand-Absätze, Paket 12 mit allen Status-Feldern, Audit-Plan, offene Fragen), (5) `PROMPT.md`, (6) `README.md` Abschnitte „Roadmap“, „5. Suchen, Filtern, Navigieren“, „Spaltenansicht: Scrollen“, „Datenbank“, (7) Ende von `DONE.md`.
- **Mit dem Nutzer:** Deutsch, kurz, geordnet, Tabellen für Prüfergebnisse. Jede Antwort, die Dateien ändert, endet mit **einer** Commit-Nachricht im Codeblock (bei reiner Prüfung ohne Dateiänderung keine). Produktentscheidungen fragt man den Nutzer (Auswahl mit Empfehlung); technische Fragen entscheidet der Host selbst und schreibt die Entscheidung in die Aufgabe. Der Nutzer meldet oft Funde aus der echten App – die gehen vor (Abschnitt 8 im Ablauf).

## 2. Wo das Projekt steht

| Version | Stand |
|---|---|
| 0.3.8, 0.3.9 | abgenommen; **die App meldet 0.3.9** |
| **0.4.0** | **Release-Kandidat der Open Beta.** Pakete 9, 10, 11 abgenommen. **Paket 12 vom Worker fertig, vom Nutzer committet (`027154d`), vom Host noch NICHT geprüft.** Danach: großer Audit, dann Abnahmerunde des Nutzers (`todo.0.4.040`). Außerdem für 0.4.0: `todo.0.4.042` (Wartescreen der Suche, wartet auf Layout des Nutzers), `todo.0.4.043` (Favoriten werden geladen, freigebbar). Versionsnummer 0.4.0 setzen als eigene kleine Aufgabe bei der Abnahme. |
| 0.4.1 | Release der Open Beta (Auslieferung): `todo.0.4.021`, `022`, `024`, `todo.0.4.1.001`, `002` – Backlog, erst nach 0.4.0 freigeben |
| 1.0 | Signatur und Notarisierung (`todo.0.4.020`) |

**Letzte Host-Prüfung:** Paket 11 am 18.10. 16:36–17:04 (Prüfstand-Absatz in `TODO.md`). Nachmessung `bug.0.4.077`: +5,2 % Indizierzeit.

**Paket 12 laut Worker (nicht geprüft!):** Debug mit Testziel und Release je 0 Warnungen, seriell 894/894 grün, parallel dreimal je 938 grün, keine neuen `.ips`, Regel 23 erfüllt (App 02:37:57). Inhalt: `bug.0.4.086` ein Datenbank-Pool je Prozess (`Storage/V3/ArchiveDatabase.swift`), `087` Scrollen zu den Details, `088` Ausblenden an Ort und Stelle, `090` hängender Spaltenzustand (Spaltenkennung je Medium), `089` Trennlinie, `091` Rollbalken-Platz (`DesignSystem/ScrollbarGutter.swift`), `092` Filtersuche ohne Medien-Kacheln, `081` Sortierkopf ganze Breite, `082`/`083` Fehlerbericht, `084` Überwachung nach Fehler, `085` Kleinkram.

## 3. Was als Nächstes passiert (für dich)

1. **Paket 12 prüfen** nach `archiv/abnahme-ablauf.md` Abschnitt 7 (Prüfskript im Hintergrund + drei Prüf-Agenten). Diff: `git show 027154d -- diskindex/` (der Worker-Code ist schon committet; prüfe gegen `35d19bb`). Vorschlag zur Bündelung der Agenten: (A) `086` + `084`, (B) `087`, `088`, `089`, `090`, `091`, `081` (Spaltenansicht und Oberfläche), (C) `092`, `082`, `083`, `085`. **Besonders genau hinsehen:**
   - `086`: Die Ticker-Grenze im Test wurde durch eine Fadenprüfung ersetzt (wie bei `bug.0.3.9.004`) – ist das eine gelockerte Laufzeitgrenze (Regel 14) oder zulässig? Beweist der Test noch, dass die Oberfläche während der Migration bedienbar bleibt?
   - `084`: Der Test ersetzt echte FSEvents durch eine Skript-Quelle (`ChangeWatcher.makeSourceForTesting`) und den Lesefehler durch Schreibfehler – mit Regel 18 vereinbar?
   - `088`: offene niedrige Restpunkte im Status (Treffer unterhalb eines ignorierten Ordners erst nach der Warteschlange, Trefferzahl nur um die Seite verringert, ab 50.000 Einträgen kein Gleiten).
   - `092`: eine Store-Funktion bleibt ungenutzt stehen (toter Code?).
   - `085 e)`: Sabotage „nicht verlässlich rot“ – Begründung prüfen.
   - Funde des Nutzers (`086`–`092`) streng gegen README und Aufgabe; mittlere/niedrige Prüfbefunde als neue Kennungen **ins nächste Paket**, nie ins laufende.
2. **Nach der Abnahme:** Pflege nach Abschnitt 5/7.5 (TODO-Kopie ins Archiv, Prüfstand-Absatz, DONE.md je Kennung, PROMPT.md). Dann den **großen Audit** starten (Plan in `TODO.md` Abschnitt A, „Nach Paket 12: großer Audit“): Bereiche 1–9, Befunde gegenprüfen, Kennungen ab `bug.0.4.093`, `todo.0.4.044`. Daraus ein bis zwei Pakete – zusammen mit `todo.0.4.043` und der Version 0.4.0, falls der Nutzer zustimmt.
3. **Offene Fragen an den Nutzer** stehen in `TODO.md` unter „Offene Fragen an den Nutzer“ (Wartescreen nur aus dem Leerzustand; `043` ins nächste Paket; Schwelle für 0.4.0 nach dem Audit). Beim ersten passenden Moment klären.
4. **Danach** die Abnahmerunde des Nutzers vorbereiten: kurze Checkliste für `todo.0.4.040` (2-Mio-HTML-Platte – vorher alle Medien neu indizieren –, Stick mit allen Punkten aus der Aufgabe, Layout-Durchgang). **Der Nutzer hat vor dem 21.10. keine Festplatten.**

## 4. Schleifen (Loops) – so will der Nutzer es

- **„Starte den 15-Minuten-Loop“:** `CronCreate` mit `*/15 * * * *`. Prompt: PROMPT.md lesen; beginnt sie nicht mit „Erledigt (Bereit zur Prüfung)“, **nur** „Worker arbeitet noch“ melden; sonst den Loop per `CronDelete` beenden und sofort die Paketprüfung starten (Abschnitt 7). Vorlage: `archiv/abnahme-ablauf.md` Abschnitt 9.
- **„Stopp“** heißt: sofort `CronDelete`, keine Rückfrage, kurze Bestätigung.
- **Nur eine Frage** (z. B. „wie ist das Wochen-/Stundenkontingent?“): einmal mit `get_usage` antworten, **keinen** Loop anlegen, außer der Nutzer sagt ausdrücklich „im Loop“ – und auch dann stoppt er ihn oft gleich wieder.
- Loops leben nur in der laufenden Sitzung (höchstens 7 Tage). Ohne Loop-Werkzeug: Der Nutzer schreibt „check“.

## 5. Rechner und Werkzeuge

- macOS 15.7.4, Xcode 26.3. **`xcode-select` zeigt auf die Command Line Tools** → jeder Build/Test mit `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Signatur: Team `KATFD9R38G`, Zertifikat gültig.
- Nutzer-App (Regel 23): `~/Library/Developer/Xcode/DerivedData/diskindex-*/Build/Products/Debug/Disk Archive.app` (Hash je Rechner per `ls -d` suchen).
- Daten des Nutzers: Datenbank `~/Library/Application Support/Disk Archive/archive.sqlite` (710 MB, drei Medien, rund 1,6 Mio. Einträge; Index `items_search_natural` schon angelegt), Protokoll `~/Library/Logs/Disk Archive/diskindex.log`. **Nur lesen** (`sqlite3 -readonly`).
- Scratchpad des Hosts für Prüfskripte und Build-Ordner, nie das Repository; Build-Ordner nach der Prüfung löschen.

## 6. Zum Schluss

Wenn du alles gelesen und gegen das Repository geprüft hast (stimmen `027154d`, `PROMPT.md` = Kurzmeldung des Workers, `TODO.md` Paket 12 mit gefüllten Status-Feldern überein?), **lösche diese Datei** und sage dem Nutzer, dass die Übergabe übernommen ist; gib ihm dafür eine Commit-Nachricht („Übergabe übernommen, UEBERGABE.md gelöscht“). Danach mit Schritt 3.1 (Prüfung Paket 12) beginnen.
