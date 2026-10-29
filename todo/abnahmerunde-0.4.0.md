# Checkliste Abnahmerunde 0.4.0 (`todo.0.4.040`, Nutzer)

Erst, wenn alle anderen Kennungen von 0.4.0 abgenommen sind (zuletzt Paket 33, Umbau „ein Ordner“). Geschrieben vom Host 25.10. (`todo.0.4.045`). Funde schreibst du einfach in den Chat, der Host macht daraus `bug.0.4.xxx`.

## Vorher

1. Reste von vor dem Umbau „ein Ordner“ (`bug.0.4.208`) löschen. Seitdem liegt alles in `~/Library/Application Support/Disk Archive/`, und Tests schreiben nichts mehr in die Voreinstellungen.
   - Alte Test-Einstellungen: `rm ~/Library/Preferences/app.diskarchive.tests.*.plist`
   - Alter Protokollordner: `rm -r ~/Library/Logs/Disk\ Archive`
   - Danach **den Mac einmal neu starten**. Dann vergisst der Einstellungsdienst (`cfprefsd`) die gelöschten Test-Domänen.
   - `~/Library/Preferences/app.diskarchive.plist` bleibt. Nach dem ersten Start der neuen App stehen darin nur noch Sprache (`AppleLanguages`) und Fensterposition. Zum Nachsehen: `defaults read app.diskarchive`. Steht dort noch ein Schlüssel mit `diskindex.` oder `lastIntegrityCheck`, schreib es in den Chat.
   - Die App setzt nach dem Umbau Pause, Sprache und „Mitteilungen erfragt“ einmal auf den Anfang. Das ist gewollt, es gibt keine Übernahme.
2. Die App aus `DerivedData/…/Build/Products/Debug/` starten (der Host nennt dir den Stand), Version 0.4.0.
3. **Alle Medien neu indizieren** (Einstellungen → Speichermedien → „Neu indizieren“), damit nichts aus alten Läufen mitspielt.

## 1. Große Platte (rund 2 Mio. HTML-Dateien)

- [ ] Vollständig indizieren. Zeit notieren. Fortschritt steigt stetig, springt nicht zurück, bleibt bis zum Ende unter 100 %.
- [ ] Suchen (Name, Filter), Spaltenansicht in großen Ordnern: flüssig, keine Hänger.
- [ ] Ab- und wieder anstecken: Status Offline, dann Online, kein neuer Volllauf von vorn.
- [ ] Live-Änderung: Datei anlegen, umbenennen, löschen → erscheint bzw. verschwindet.

## 2. Gleichzeitig: SD-Karte, USB-Stick, SSD

- [ ] Alle drei gleichzeitig anstecken: Erkennungsdialoge gestapelt, je Medium einer, ältere nach links oben.
- [ ] Alle drei indizieren lassen, dabei eins abziehen: die anderen laufen weiter, das abgezogene zeigt „x % indiziert, offline“.
- [ ] Großer Ordner auf dem Stick: Pfeiltasten, Mehrfachauswahl, Rechtsklick.
- [ ] Rückfrage „Ersetzt dieses Medium?“ (z. B. Stick neu formatieren, gleicher Name) samt Texten.
- [ ] Ein Volume im Finder umbenennen → Name in der App folgt.
- [ ] **Gegenprobe `bug.0.4.141`:** Datei als Favorit markieren, auf dem Medium in einen anderen Ordner verschieben, während der Abgleich läuft das Medium abziehen, wieder anstecken → Favorit ist noch da.
- [ ] **`bug.0.4.199`:** zuerst im Finder die SSD auswählen → Informationen → unten „Eigentümer auf diesem Volume ignorieren“ **ausschalten** (externe Volumes haben das oft an, dann greift „Keine Rechte“ nicht); dann einen Ordner auf der SSD (APFS oder Mac OS Extended; FAT/exFAT-Sticks kennen keine Rechte) unlesbar machen (Finder → Informationen → Freigabe & Zugriffsrechte: „Keine Rechte“ für alle), neu indizieren → Chip „Fehler“, Grund „Einige Ordner … nicht gelesen“, Details „Indiziert 99 %“; Rechte zurück, abziehen und anstecken → Online, „Indiziert 100 %“; danach „Eigentümer ignorieren“ wieder so einstellen wie vorher.

## 3. Layout-Durchgang

- [x] (27.10., Funde → Paket 36) Alle Ansichten gegen `layout/` hell und dunkel (Dashboard, Spalten, Suche, Favoriten, Einstellungen, Details, Dialoge, Menüleiste). Abweichungen per Screenshot.

## 4. Nachtest nach den Paketen 34–36 (27.10.)

Mit der App vom letzten Gesamtlauf (gebaut 27.10. 13:20) und nach einem Neustart der App.
- [x] **Fortschritt (`bug.0.4.210`):** Nachtest 28.10. bestanden (C1–C3). Nachtest 27.10.: bestanden bis auf 1 % Versatz nach dem Wiedereinstecken → `bug.0.4.222`, abgenommen 27.10. (Paket 37). **Bitte jetzt nachtesten** (App 28.10. 01:35).
  - Stick mitten im Lauf abziehen: kein Sprung auf 100 %, offline derselbe Wert wie zuletzt online.
  - Wieder anstecken: Er beginnt beim gespeicherten Stand, nicht bei 0 %.
  - „Neu indizieren“ beginnt unten, nicht bei 99 %.
- [x] **Dialoge (`209`, `216`):** Nachtest 28.10. bestanden (D1–D6). Nachtest 27.10.: Fokus nicht bestanden → `bug.0.4.221`, Stapel nicht bestanden → `bug.0.4.223`. Beide wurden am 28.10. mit Paket 38 abgenommen. **Bitte jetzt nachtesten** (App 28.10. 01:35, vorher neu starten).
  - Während du in einer anderen App schreibst, ein Medium einstecken: Der Dialog nimmt den Fokus einmal. Ein Klick zurück in die andere App legt ihn dahinter, danach bleibt der Fokus dort.
  - Zwei oder drei Medien kurz nacheinander: Der älteste Dialog liegt hinten links oben, jeder neue nach rechts unten versetzt darüber. Der neueste liegt vorn und hat den Fokus.
  - Das Hauptfenster liegt hinter der anderen App: Es bleibt dort, nur der Dialog kommt nach vorn.
  - Einen Dialog mit X schließen, das Medium auswerfen und wieder einstecken: Der Dialog erscheint wieder.
- [x] **Ersetzen (`215`):** Nachtest 27.10. bestanden. Stick mit gleichem Namen neu formatieren → zuerst nur „Ersetzt dieses Medium?“.
- [x] **Spaltenansicht (`212`–`214`):** Nachtest 27.10. bestanden.
  - Filter offen, Spalte scrollt.
  - → öffnet einen Ordner, ← geht zurück.
  - Eine ausgewählte Datei im Finder verschieben → Auswahl weg, Ansicht bleibt.
- [x] **Layout (`211`, `217`–`220`), hell und dunkel:** Nachtest 27.10. bestanden.
  - Dashboard-Kacheln gleich breit.
  - Nur die gezogene Spalte ändert ihre Breite, ohne Ruckeln.
  - Seitenleiste, Offline-Leiste und Details in einem Grauton.
  - Fußzeilenpfad bündig mit dem Ordner-Icon, auch nach dem Ziehen der Seitenleiste.
  - Spinner klein (12 pt).

- [x] **Vergessen (`224`):** Nachtest 28.10. bestanden (B1–B3). Nachtest 28.10.: „Alle Speichermedien vergessen“, danach Neustart: Alle Medien sind wieder da → `bug.0.4.224` (Paket 39). Nach Paket 39: vergessen, **sofort** beenden und neu starten. Kein Medium ist mehr da, und das Beenden hängt nicht.

## 5. Nachtest nach den Paketen 37–39 (28.10., App 09:41)

**Ergebnis 28.10. (Nutzer):** A1, B1–B3, C1–C3, D1–D6 bestanden. B4 offen bis nach Paket 40.

Reihenfolge: B zuerst, weil nach dem Vergessen jedes Medium neu mit dem Dialog kommt. Das braucht D.

**A Vorher**
- [x] **A1** App beenden und neu öffnen (App von 09:41).

**B Vergessen (`224`)**
- [x] **B1** Nach deinem Vergessen von heute Morgen: Speichermedien leer, Dashboard 0, Suche findet nichts, Favoriten leer.
- [x] **B2** Ein angeschlossenes Medium erscheint nach dem Neustart neu, mit Erkennungsdialog.
- [x] **B3** Ein Medium indizieren, in den Details „Vergessen“ (zwei Klicks), sofort ⌘Q. Das Beenden hängt nicht. Nach dem Neustart ist es weg, und der Dialog kommt wieder.
- [x] **B4** (dauert lange, gern zuletzt) Die große Platte „Daten“ anstecken: Sie gilt als neu, und das Indizieren beginnt von vorn. Mit der App von 29.10. 16:33 (Paket 44).

**C Fortschritt (`222`)**
- [x] **C1** Stick mitten im Lauf abziehen: kein Sprung auf 100 %, offline derselbe Wert wie zuletzt online.
- [x] **C2** Wieder anstecken: Es geht beim gespeicherten Stand weiter, ohne 1 % Versatz.
- [x] **C3** „Neu indizieren“ beginnt unten, nicht bei 99 %.

**D Dialoge (`221`, `223`)**
- [x] **D1** In TextEdit tippen, Medium einstecken: Der Dialog kommt nach vorn, und die Tasten gehen in den Dialog (Return = Indizieren, Esc = schließen).
- [x] **D2** Zurück in TextEdit klicken: TextEdit hat den Fokus, der Dialog liegt dahinter. Eine Minute weitertippen, während etwas indiziert: Der Dialog holt sich den Fokus nicht zurück.
- [x] **D3** Das Hauptfenster offen und hinter TextEdit, Medium einstecken: Nur der Dialog kommt nach vorn, das Hauptfenster bleibt hinten.
- [x] **D4** Zwei oder drei Medien kurz nacheinander: Der älteste liegt hinten links oben, jeder neue nach rechts unten versetzt darüber. Der neueste liegt vorn und hat den Fokus.
- [x] **D5** Einen Dialog mit X oder Esc schließen, das Medium auswerfen und wieder einstecken: Der Dialog erscheint wieder.
- [x] **D6** Ein Dialog liegt hinter einer anderen App: Die Zeile „Entscheidung offen“ in der Menüleiste holt ihn vor.

## 6. Nachtest nach Paket 40 (28.10., App 13:25)

**Ergebnis 29.10. 10:45–10:53 (Nutzer, Host):** E1 und E2 nicht bestanden. „Daten I“ stand bei 15 %, der Dialog von ZOOM_H4E kam spät, „Ja“ blieb minutenlang „Ausstehend“ → `bug.0.4.227` (Paket 43). E1–E5 nach Paket 43 wiederholen, mit der App von 29.10. 12:48 (Paket 43 abgenommen).

**Ergebnis 29.10. 12:55–13:50 (App 12:48, Host aus dem Protokoll):** E1 Erstindex 12:55:56–13:21:19 (4 min Ruhezustand), 283 164 Einträge, ohne Lesefehler. E2 H4-Karte: Dialog sofort, „Ja“ nach 1,8 s, fertig nach 8 s. E3 Ruhezustand 13:06–13:10: Lauf hält an und setzt beim Aufwachen fort. E4 Auswerfen 13:49: Abbruch in 30 ms, offline ohne Hänger. **Offen:** Abgleich nach dem Einstecken/Aufwachen dauert > 30 min bei 99 % → `bug.0.4.228` (Paket 44); E5 noch nicht getestet. 13:27 USB-Fehler der SanDisk (Kernel setzt das Gerät 29× zurück) – Platte bzw. Kabel, nicht die App.

**Paket 44 abgenommen 29.10. (Gesamtlauf 16:01–16:33 grün, App des Nutzers 16:33).** Nachtest offen: „Daten I“ einstecken (Abgleich ohne Änderungen, Ziel deutlich unter 25 min, kein langes Stehen bei 99 %), danach E5 und B4.

**Ergebnis 29.10. 16:45–16:49 (App 16:33, Host aus dem Protokoll):** Nach „Alle vergessen“ Erstindex „Daten I“ 16:47:04–16:48:57 (**1 min 53 s** statt 25 min), 283 164 Einträge, ohne Lesefehler, kein Schreibvorgang über 1 s. **N1 bestanden:** Abgleich nach Wiederanstecken 16:55:18–16:56:32 (**1 min 14 s** statt > 30 min), ohne Lesefehler, parallel zum Erstindex von „Daten“ (B4 läuft). **E5 mit Ordner nicht bestanden (16:56):** Favorit auf den **Ordner** `250714_184701` der H4-Karte (FAT32), in `250714_184641` verschoben, 11 s nach dem Setzen abgezogen; beim Wiederanstecken neue Zeile, Favorit weg. Ursache: Konzept `datenbank.md` erkennt Ordner auf FAT/exFAT außerhalb der Überwachung nur „über Name und Eltern“, ein verschobener Ordner gilt als neu; die Überwachung kam nicht mehr zum Zug (Ruhezeit 2 s, kein Ereignis vor dem Abziehen protokolliert). Nutzer 29.10.: verschobene Ordner wiedererkennen, noch in 0.4.0 → `bug.0.4.229` (Paket 45), **abgenommen 29.10.** (Gesamtlauf 18:03–18:36 grün, App des Nutzers 18:36). Offen: E5 mit Ordner (H4-Karte) und Datei, N2, B4.

**29.10. Nutzer:** Externe SSDs erscheinen als „HDD“ (Icon und Typ in den Einstellungen) → `bug.0.4.230` (Paket 46). Nachtest danach: „Daten I“ und „Daten“ zeigen SSD (Icon und Spalte „Typ“), H4-Karte bleibt USB. **Nachtest 29.10. ~20:50 mit der App von 20:38: bestanden** (S0–S4). Danach Pakete 47–49 (Nutzer „Alles“); Nachtest 47: „Daten I“ neu indizieren und Abgleich messen (Vergleich 1 min 53 s / 1 min 14 s).

**Ergebnis 29.10. 22:07–22:23 (App 20:38, Paket 46; Host aus Protokoll und Datenbank, nur lesend):** Nach „Alle Speichermedien vergessen“ (22:07:47) alle Testmedien neu, **alle indiziert, 0 Lesefehler, keine Fehler- oder Warnzeile im Protokoll, keine Absturzberichte**. **B4 bestanden:** „Daten“ (2 TB, APFS) Erstindex 22:09:27–22:17:20 = **7 min 53 s**, 1 600 311 Dateien. Zugleich „Daten I“ 22:08:55–22:12:33 = 3 min 38 s (266 568 Dateien; allein waren es 1 min 53 s) und H4-Karte in 0,1 s. Danach neu: „Transfer“ (USB-SSD, exFAT), „Volume“ (NTFS-Stick), „EOS_DIGITAL“ (Kamerakarte), „INTENSO“ (Stick) je unter 1 s; Typen richtig (SSD bzw. USB). Zweite Karte „ZOOM_H4E“: Rückfrage „Ersetzt dieses Medium?“ kam, „Behalten“ → eigenes Medium, indiziert in 0,1 s. Ab- und Anstecken 22:22 ohne Hänger. **Offen: E5** (Ordner auf der H4-Karte, Datei auf „Daten I“). **Nachtest E5 29.10. (Nutzer: E0–E6 „passt“):** Datei belegt – Favorit 22:35:04 auf `2016-08_001.NEF` auf „Transfer“ (exFAT), verschoben, abgezogen 23:10:07, Abgleich 23:10:25–23:10:27 (1,8 s), Favorit an derselben Zeile (9032760). **Ordner auf der H4-Karte im Protokoll nicht zu finden** (letzter Ordner-Favorit 16:56, vor Paket 45; seit „Alle vergessen“ 22:07 kein Ordner-Favorit) → Rückfrage an den Nutzer. **Nutzer 29.10.: Ordner auf der H4-Karte „schon geprüft“, passt.** Damit **E5 bestanden** (Ordner nach Angabe des Nutzers, abgesichert durch `MovedFolderFatTests`; Datei im Protokoll belegt). **Abnahmerunde 0.4.0 ohne offenen Punkt;** Release-Kandidat nach Abnahme der Pakete 46–49 (Nutzer „Alles“).

Vorher die App beenden und neu öffnen.
- [ ] **E1** „Daten I“ anstecken und weiter indizieren lassen: Es geht zügig voran und bleibt nicht mehr bei 14 % stehen. Uhrzeit von Start und Ende notieren.
- [ ] **E2** Während „Daten I“ indiziert, ein zweites Medium anstecken: Sein Erkennungsdialog bzw. Abgleich kommt sofort, nicht erst nach „Daten I“.
- [ ] **E3** Mac in den Ruhezustand (Deckel zu), nach einer Minute wecken: Die anderen Medien sind nach wenigen Sekunden still abgeglichen, „Daten I“ läuft weiter.
- [ ] **E4** „Daten I“ während des Laufs im Finder auswerfen: Sie ist nach höchstens 1–2 s offline (vorher 11 s). Die anderen Medien zeigen dabei keinen Sprung auf 99 %. Falls doch: Screenshot.
- [x] **E5** Ein Favorit auf „Daten I“ (oder einem Stick mit exFAT/FAT): Datei im Finder in einen anderen Ordner verschieben, Medium abziehen, wieder anstecken: Der Favorit hängt an der verschobenen Datei.

## Danach

Fehlerbericht über die App senden, falls etwas auffiel. Sind alle Funde behoben und abgenommen, ist 0.4.0 der Release-Kandidat.
