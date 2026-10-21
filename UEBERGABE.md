# UEBERGABE.md — Übergabe an einen neuen Host (Stand 21.10.2026)

**Diese Datei ist flüchtig.** Der neue Host liest sie als Erstes, prüft sie gegen das Repository, übernimmt den Stand und **löscht sie dann** (der Nutzer committet die Löschung). Alles Dauerhafte steht in den festen Dateien. Grund (Nutzer 21.10.): Der Nutzer hat keine Zeit mehr; der bisherige Host prüft Paket 13 **nicht**, das macht der neue Host.

**Hostwechsel kommen immer wieder vor.** Bittet der Nutzer um eine Übergabe: nichts mehr prüfen, die festen Dateien auf Stand bringen, eine neue `UEBERGABE.md` nach diesem Muster schreiben und eine Commit-Nachricht vorschlagen, die auf sie hinweist (AGENTS.md, „Übergabe“).

---

## 1. Rollen und was du zuerst liest

- **Du bist Host** (AGENTS.md): Konzept, Aufgaben, Prüfung, Abnahme; du pflegst `TODO.md`, `DONE.md`, `PROMPT.md`, `README.md`, `ROADMAP.md`, `AGENTS.md`, `archiv/`. **Kein Quellcode im Xcode-Projekt**, Git **nur lesend**. Commits macht nur der Nutzer.
- **Lesereihenfolge:** (1) diese Datei, (2) `AGENTS.md`, (3) `archiv/abnahme-ablauf.md` Abschnitte 7, 8 (neu: mehrere Rechner, Audit mit sechs Agenten), 9, (4) `TODO.md`: Regeln 1–31, Abschnitt A (Stand-Zeile, Paket-Tabelle, Prüfstand Paket 12, „Prüfbefunde 12“, „Audit 20.10.“ mit Paket 13 und 14, Entscheidungen des Nutzers 20.10.), (5) `PROMPT.md`, (6) README „Roadmap“, „Spaltenansicht: Scrollen“, „Datenbank“, (7) Ende von `DONE.md`.
- **Mit dem Nutzer:** Deutsch, kurz, Tabellen für Prüfergebnisse, jede Antwort mit Dateiänderung endet mit **einer** Commit-Nachricht. Produktfragen als Auswahl mit Empfehlung; technische Fragen entscheidet der Host und schreibt sie in die Aufgabe.

## 2. Wo das Projekt steht

| Version | Stand |
|---|---|
| 0.3.8, 0.3.9 | abgenommen; **App meldet 0.3.9** |
| **0.4.0** | Pakete 9–12 abgenommen (Paket 12 am 20.10.: seriell 894/894, parallel 3/3, 0 Warnungen). Großer Audit 20.10. erledigt → `bug.0.4.103`–`140`. **Paket 13 vom Worker fertig, vom Nutzer committet (`4f783f8`), vom Host NICHT geprüft.** Danach Paket 14 (geplant), dann Abnahmerunde des Nutzers `todo.0.4.040`. |
| 0.4.1 | Auslieferung der Open Beta (Backlog) |
| 1.0 | Signatur, Notarisierung; neu: `bug.0.4.106` Sicherungskopie vor Migration (Nutzer 20.10.) |

**Entscheidungen des Nutzers 20.10.** (stehen in TODO.md/README): keine Schwelle – jeder bestätigte Befund kommt in 0.4.0 („wir beenden fehlerfrei die 0.4.0-Runde“); Wartescreen der Suche nur aus dem Leerzustand; `todo.0.4.043` mit in Paket 14; Rollbalken-Platz ohne leere Leiste (`bug.0.4.100 c`); Sicherungskopie erst zu 1.0; eingereihte Berichte gehen auch nach Ausschalten von „automatisch senden“ raus.

**Paket 13 laut Worker (nicht geprüft!):** `bug.0.4.116`, `117`, `105`, `104`, `103`, `126`–`129`, `137`, `138`, `109`, `093`, `095`–`097`, `131`–`133`, `100`; Commit-Text nennt seriell 929, parallel 3/3. `PROMPT.md` = Kurzmeldung des Workers: **Fragen unter `096`, `103`, `105`, `127`, `128`, `132`, `137`; Testreste unter `095`, `097`, `100`, `131`.**

## 3. Was als Nächstes passiert (für dich)

1. **Paket 13 prüfen** nach `archiv/abnahme-ablauf.md` Abschnitt 7: Prüfskript im Hintergrund (Build mit Testziel, seriell, dreimal parallel mit `-resultBundlePath`, Release, neue `.ips`, Nutzer-App Regel 23, Version) + drei Prüf-Agenten auf `git show 4f783f8 -- diskindex/` (Basis `a1ba268`). Bündelung-Vorschlag: (A) `116`, `117`, `093`, `137`, `109` (Tests/Fenster, Haupt-Thread, Netz); (B) `105`, `104`, `103`, `126`–`129`, `138`, `095` (Datenbank, Status der Medien, Live); (C) `096`, `097`, `131`–`133`, `100` (Oberfläche). **Zuerst die Fragen des Workers lesen** (oben genannte Kennungen) und beantworten: technische selbst, Produktfragen an den Nutzer. Besonders: `126` (neue Spalte/Merker „vollständig“? Regel 27 nur erweitern), `127` (Test nach README geändert – zulässig laut Host-Entscheidung), `116`/`117` (wirklich kein Fenster/Panel mehr im sichtbaren Bereich? Grep-Wächter vorhanden?), `105` (nie überschreiben bei Lesefehler).
2. **Nach der Abnahme:** Pflege nach Abschnitt 7.5 (TODO-Kopie ins Archiv, Prüfstand-Absatz, DONE.md je Kennung). Mittlere/niedrige Prüfbefunde 13 → neue Kennungen ab `bug.0.4.141` **in Paket 14**. Paket 14 in TODO.md ausformulieren (Texte dort knapp) und freigeben; `todo.0.4.044` (Version 0.4.0) als letzte Aufgabe.
3. **8.642 leere Test-`.plist` in `~/Library/Preferences`** (Rechner des Hosts 20.10., siehe `bug.0.4.124`): nach Paket 14 dem Nutzer einen Löschbefehl geben (nichts selbst außerhalb des Projekts löschen).
4. Danach Checkliste für die Abnahmerunde des Nutzers `todo.0.4.040` (2-Mio-Platte – vorher alle Medien neu indizieren –, Stick, Layout).

## 4. Schleifen

Wie bisher (`archiv/abnahme-ablauf.md` Abschnitt 9): „Starte den 15-Minuten-Loop“ → `CronCreate */15`; „Stopp“ → sofort `CronDelete`; reine Fragen nur einmal beantworten, keinen Loop.

## 5. Rechner

- Der Host vom 20./21.10. lief auf einem **MacBook Air, macOS 15.7.3**, Xcode 26.3; dort ist `archive.sqlite` fast leer (120 KB). Die echte Datenbank (710 MB, drei Medien) liegt auf dem Rechner des Nutzers. Zu Beginn `sw_vers` und Größe von `~/Library/Application Support/Disk Archive/archive.sqlite` prüfen.
- Immer `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Nutzer-App per `ls -d ~/Library/Developer/Xcode/DerivedData/diskindex-*/Build/Products/Debug/"Disk Archive.app"`. Prüfskript und Build-Ordner im Scratchpad, nie im Repository; danach löschen.

## 6. Zum Schluss

Wenn alles gelesen und gegen das Repository geprüft ist (stimmen `4f783f8`, `PROMPT.md` = Kurzmeldung des Workers, Status-Felder von Paket 13 gefüllt?), **diese Datei löschen**, dem Nutzer die Übernahme melden und mit Schritt 3.1 beginnen.
